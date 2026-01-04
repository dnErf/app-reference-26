const std = @import("std");
const Column = @import("column.zig").Column;
const cardinality_mod = @import("cardinality.zig");
const types = @import("types.zig");
const Value = types.Value;
const DataType = types.DataType;

pub const CompressionCodec = enum(u8) {
    none = 0,
    rle = 1,
    dictionary = 2,
    bitpack = 3,
};

pub fn codecName(codec: CompressionCodec) []const u8 {
    return switch (codec) {
        .none => "none",
        .rle => "rle",
        .dictionary => "dictionary",
        .bitpack => "bitpack",
    };
}

// Heuristic codec chooser with real cardinality statistics
pub fn chooseCodec(column: *const Column) CompressionCodec {
    if (column.len == 0) return .none;
    return switch (column.data_type) {
        .boolean => .rle,
        .string => {
            // Use real cardinality estimation for better codec selection
            const stats = column.countDistinctExact() catch {
                // Fallback to sampling if exact counting fails
                return chooseCodecStringSampling(column);
            };

            const uniqueness = stats.uniqueness();

            // Use dictionary compression for low uniqueness (<= 20%)
            // or if cardinality is very small relative to size
            if (uniqueness <= 0.20 or stats.distinct_count < 100) {
                return .dictionary;
            }

            // For medium uniqueness, use dictionary if dataset is large enough
            if (column.len >= 1024 and uniqueness <= 0.50) {
                return .dictionary;
            }

            return .none;
        },
        .int32 => {
            var min: i32 = @as(i32, std.math.maxInt(i32));
            var max: i32 = @as(i32, std.math.minInt(i32));
            var i: usize = 0;
            while (i < column.len) : (i += 1) {
                const v = column.asSlice(i32)[i];
                if (v < min) min = v;
                if (v > max) max = v;
            }
            if (max < min) {
                const t = max;
                max = min;
                min = t;
            }
            const diff_i64: i64 = @as(i64, max) - @as(i64, min);
            var bits: u8 = 0;
            var r_i64 = diff_i64;
            while (r_i64 != 0) : (r_i64 >>= 1) {
                bits += 1;
            }
            if (bits != 0 and bits < 28) return .bitpack; // threshold
            return .none;
        },
        .int64 => {
            var min: i64 = @as(i64, std.math.maxInt(i64));
            var max: i64 = @as(i64, std.math.minInt(i64));
            var i: usize = 0;
            while (i < column.len) : (i += 1) {
                const v = column.asSlice(i64)[i];
                if (v < min) min = v;
                if (v > max) max = v;
            }
            if (max < min) {
                const t = max;
                max = min;
                min = t;
            }
            const diff_i128: i128 = @as(i128, max) - @as(i128, min);
            var bits: u8 = 0;
            var r_i128 = diff_i128;
            while (r_i128 != 0) : (r_i128 >>= 1) {
                bits += 1;
            }
            if (bits != 0 and bits < 48) return .bitpack;
            return .none;
        },

        else => .none,
    };
}

// Fallback sampling-based codec selection for strings (if cardinality fails)
fn chooseCodecStringSampling(column: *const Column) CompressionCodec {
    // sample up to 256 rows to estimate cardinality (simple n^2 search — small sample)
    // Use a small fixed buffer to avoid allocations when sampling
    var uniques_arr: [256][]const u8 = undefined;
    var uniques_count: usize = 0;
    var sampled: usize = 0;
    var i: usize = 0;
    while (i < column.len and sampled < 256) : (i += 1) {
        const val = column.get(i) catch continue;
        sampled += 1;
        var found = false;
        var j: usize = 0;
        while (j < uniques_count) : (j += 1) {
            if (std.mem.eql(u8, uniques_arr[j], val.string)) {
                found = true;
                break;
            }
        }
        if (!found) {
            uniques_arr[uniques_count] = val.string;
            uniques_count += 1;
        }
    }
    if (sampled == 0) return .none;
    const unique = uniques_count;
    // If low cardinality percentage, use dictionary
    if (unique * 100 <= sampled * 20) {
        return .dictionary;
    }
    return if (column.len >= 1024) .dictionary else .none;
}

pub fn compress(
    allocator: std.mem.Allocator,
    column: *const Column,
    codec: CompressionCodec,
) ![]u8 {
    return switch (codec) {
        .none => try copyRaw(allocator, column),
        .rle => try compressRLE(allocator, column),
        .dictionary => try compressDictionary(allocator, column),
        .bitpack => try compressBitpack(allocator, column),
    };
}

fn copyRaw(allocator: std.mem.Allocator, column: *const Column) ![]u8 {
    const bytes = column.len * column.row_stride;
    const buf = try allocator.alloc(u8, bytes);
    @memcpy(buf, column.data[0..bytes]);
    return buf;
}

fn compressRLE(allocator: std.mem.Allocator, column: *const Column) ![]u8 {
    if (column.data_type != .boolean) {
        return try copyRaw(allocator, column);
    }

    var output = std.ArrayList(u8){};
    defer output.deinit(allocator);

    const values = column.asSlice(bool)[0..column.len];
    if (values.len == 0) return try allocator.alloc(u8, 0);

    var i: usize = 0;
    while (i < values.len) {
        const current = values[i];
        var run: u32 = 1;
        while (i + run < values.len and values[i + run] == current and run < std.math.maxInt(u32)) {
            run += 1;
        }
        try output.writer(allocator).writeInt(u32, run, .little);
        try output.append(allocator, @intFromBool(current));
        i += run;
    }

    return try output.toOwnedSlice(allocator);
}

fn compressDictionary(allocator: std.mem.Allocator, column: *const Column) ![]u8 {
    if (column.data_type != .string) {
        return try copyRaw(allocator, column);
    }

    var dict_map = std.StringHashMap(u32).init(allocator);
    defer dict_map.deinit();
    var dict = std.ArrayList([]u8){};
    defer {
        for (dict.items) |entry| allocator.free(entry);
        dict.deinit(allocator);
    }
    var indexes = std.ArrayList(u32){};
    defer indexes.deinit(allocator);

    var row: usize = 0;
    while (row < column.len) : (row += 1) {
        const val = column.get(row) catch continue;
        if (val != .string) continue;
        const existing = dict_map.get(val.string);
        const idx = existing orelse blk: {
            const owned = try allocator.dupe(u8, val.string);
            const id = @as(u32, @intCast(dict.items.len));
            try dict.append(allocator, owned);
            try dict_map.put(owned, id);
            break :blk id;
        };
        try indexes.append(allocator, existing orelse idx);
    }

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);
    const writer = buffer.writer(allocator);

    try writer.writeInt(u32, @intCast(dict.items.len), .little);
    for (dict.items) |entry| {
        try writer.writeInt(u32, @intCast(entry.len), .little);
        try writer.writeAll(entry);
    }

    try writer.writeInt(u32, @intCast(indexes.items.len), .little);
    for (indexes.items) |idx| {
        try writer.writeInt(u32, idx, .little);
    }

    return try buffer.toOwnedSlice(allocator);
}

fn compressBitpack(allocator: std.mem.Allocator, column: *const Column) ![]u8 {
    if (!(column.data_type == .int32 or column.data_type == .int64)) {
        return try copyRaw(allocator, column);
    }

    if (column.len == 0) return try allocator.alloc(u8, 0);

    // Calculate min/max and bit width
    var min: i64 = undefined;
    var max: i64 = undefined;
    if (column.data_type == .int32) {
        const slice = column.asSlice(i32);
        min = slice[0];
        max = slice[0];
        for (slice[1..]) |v| {
            if (v < min) min = v;
            if (v > max) max = v;
        }
    } else {
        const slice = column.asSlice(i64);
        min = slice[0];
        max = slice[0];
        for (slice[1..]) |v| {
            if (v < min) min = v;
            if (v > max) max = v;
        }
    }

    const range_i128: i128 = @as(i128, max) - @as(i128, min);
    var bits: u8 = 0;
    var r = range_i128;
    while (r != 0) : (r >>= 1) {
        bits += 1;
    }
    if (bits == 0) bits = 1; // At least 1 bit for same values

    // Encode: 1 byte (bits) + 8 bytes (min) + packed data
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    try buffer.append(allocator, bits);
    try buffer.writer(allocator).writeInt(i64, min, .little);

    // Pack values
    var acc: u128 = 0;
    var acc_bits: u8 = 0;
    var i: usize = 0;
    while (i < column.len) : (i += 1) {
        const val = if (column.data_type == .int32)
            @as(i64, column.asSlice(i32)[i])
        else
            column.asSlice(i64)[i];
        const delta: u128 = @intCast(@as(i128, val) - @as(i128, min));
        acc |= (delta << @as(u7, @intCast(acc_bits)));
        acc_bits += bits;
        while (acc_bits >= 8) {
            try buffer.append(allocator, @truncate(acc & 0xFF));
            acc >>= 8;
            acc_bits -= 8;
        }
    }
    // Flush remaining bits
    if (acc_bits > 0) {
        try buffer.append(allocator, @truncate(acc & 0xFF));
    }

    return try buffer.toOwnedSlice(allocator);
}

pub fn decompress(
    allocator: std.mem.Allocator,
    column: *Column,
    codec: CompressionCodec,
    data: []const u8,
    row_count: usize,
) !void {
    switch (codec) {
        .none => try decompressRaw(allocator, column, data, row_count),
        .rle => try decompressRLE(column, data),
        .dictionary => try decompressDictionary(allocator, column, data),
        .bitpack => try decompressBitpack(column, data, row_count),
    }
}

fn decompressBitpack(column: *Column, data: []const u8, row_count: usize) !void {
    if (!(column.data_type == .int32 or column.data_type == .int64)) return error.UnsupportedOperation;
    if (data.len == 0) return error.IncompleteRead;

    var pos: usize = 0;
    const bits = data[pos];
    pos += 1;
    const min = std.mem.readInt(i64, data[pos..][0..8], .little);
    pos += 8;

    var acc: u128 = 0;
    var acc_bits: u8 = 0;
    var i: usize = 0;
    while (i < row_count) : (i += 1) {
        while (acc_bits < bits) {
            if (pos >= data.len) return error.IncompleteRead;
            acc |= @as(u128, data[pos]) << @as(u7, @intCast(acc_bits));
            pos += 1;
            acc_bits += 8;
        }
        const mask: u128 = ((@as(u128, 1) << @as(u7, @intCast(bits))) - 1);
        const val_u = acc & mask;
        acc >>= @as(u7, @intCast(bits));
        acc_bits -= bits;
        const delta_i128: i128 = @intCast(val_u);
        const val_i128 = delta_i128 + @as(i128, min);
        if (column.data_type == .int32) {
            const v: i32 = @intCast(val_i128);
            try column.append(Value{ .int32 = v });
        } else {
            const v: i64 = @intCast(val_i128);
            try column.append(Value{ .int64 = v });
        }
    }
}

fn decompressRaw(allocator: std.mem.Allocator, column: *Column, data: []const u8, row_count: usize) !void {
    var pos: usize = 0;
    var scratch: []f32 = &[_]f32{};
    defer {
        if (scratch.len != 0) allocator.free(scratch);
    }
    if (column.data_type == .vector and column.vector_dim > 0) {
        scratch = try allocator.alloc(f32, column.vector_dim);
    }
    var row: usize = 0;
    while (row < row_count) : (row += 1) {
        const value = switch (column.data_type) {
            .int32 => blk: {
                const v = std.mem.readInt(i32, data[pos..][0..4], .little);
                pos += 4;
                break :blk Value{ .int32 = v };
            },
            .int64 => blk: {
                const v = std.mem.readInt(i64, data[pos..][0..8], .little);
                pos += 8;
                break :blk Value{ .int64 = v };
            },
            .float32 => blk: {
                const bits = std.mem.readInt(u32, data[pos..][0..4], .little);
                pos += 4;
                break :blk Value{ .float32 = @bitCast(bits) };
            },
            .float64 => blk: {
                const bits = std.mem.readInt(u64, data[pos..][0..8], .little);
                pos += 8;
                break :blk Value{ .float64 = @bitCast(bits) };
            },
            .boolean => blk: {
                const byte = data[pos];
                pos += 1;
                break :blk Value{ .boolean = byte != 0 };
            },
            .timestamp => blk: {
                const v = std.mem.readInt(i64, data[pos..][0..8], .little);
                pos += 8;
                break :blk Value{ .timestamp = v };
            },
            .string => blk: {
                const len = std.mem.readInt(u32, data[pos..][0..4], .little);
                pos += 4;
                const slice = data[pos .. pos + len];
                pos += len;
                break :blk Value{ .string = slice };
            },
            .vector => blk: {
                var idx: usize = 0;
                while (idx < column.vector_dim) : (idx += 1) {
                    const bits = std.mem.readInt(u32, data[pos..][0..4], .little);
                    pos += 4;
                    scratch[idx] = @bitCast(bits);
                }
                break :blk Value{ .vector = .{ .values = scratch } };
            },
            .custom => {
                // Custom types not supported for decompression yet
                return error.CustomTypeNotSupported;
            },
            .exception => {
                // Exception types not supported for decompression
                return error.ExceptionTypeNotSupported;
            },
        };
        try column.append(value);
    }
}

fn decompressRLE(column: *Column, data: []const u8) !void {
    if (column.data_type != .boolean) return error.UnsupportedOperation;
    var pos: usize = 0;
    while (pos < data.len) {
        const run = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        const value = data[pos] != 0;
        pos += 1;
        var i: u32 = 0;
        while (i < run) : (i += 1) {
            try column.append(Value{ .boolean = value });
        }
    }
}

fn decompressDictionary(
    allocator: std.mem.Allocator,
    column: *Column,
    data: []const u8,
) !void {
    var pos: usize = 0;
    const dict_len = std.mem.readInt(u32, data[pos..][0..4], .little);
    pos += 4;
    var dict = try allocator.alloc([]const u8, dict_len);
    defer allocator.free(dict);
    var i: usize = 0;
    while (i < dict_len) : (i += 1) {
        const len = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        const slice = data[pos .. pos + len];
        pos += len;
        dict[i] = slice;
    }

    const index_count = std.mem.readInt(u32, data[pos..][0..4], .little);
    pos += 4;
    var idx: u32 = 0;
    while (idx < index_count) : (idx += 1) {
        const entry = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        if (entry >= dict_len) return error.InvalidDictionaryIndex;
        try column.append(Value{ .string = dict[entry] });
    }
}

// Tests
test "chooseCodec picks bitpack for small int32 ranges" {
    const allocator = std.testing.allocator;
    var col = try Column.init(allocator, .int32, 16, .{});
    defer col.deinit();
    var idx: i32 = 0;
    while (idx < 10) : (idx += 1) {
        try col.append(Value{ .int32 = @as(i32, 1000 + idx) });
    }
    const codec = chooseCodec(&col);
    try std.testing.expect(codec == .bitpack);
}

test "bitpack compress/decompress roundtrip int32" {
    const allocator = std.testing.allocator;
    var src = try Column.init(allocator, .int32, 32, .{});
    defer src.deinit();
    try src.append(Value{ .int32 = 1000 });
    try src.append(Value{ .int32 = 1010 });
    try src.append(Value{ .int32 = 1020 });

    const blob = try compress(allocator, &src, .bitpack);
    defer allocator.free(blob);

    var dst = try Column.init(allocator, .int32, 32, .{});
    defer dst.deinit();
    try decompress(allocator, &dst, .bitpack, blob, src.len);

    try std.testing.expectEqual(@as(usize, 3), dst.len);
    try std.testing.expectEqual(@as(i32, 1000), dst.asSlice(i32)[0]);
    try std.testing.expectEqual(@as(i32, 1010), dst.asSlice(i32)[1]);
    try std.testing.expectEqual(@as(i32, 1020), dst.asSlice(i32)[2]);
}

test "bitpack compress/decompress roundtrip int64" {
    const allocator = std.testing.allocator;
    var src = try Column.init(allocator, .int64, 32, .{});
    defer src.deinit();
    try src.append(Value{ .int64 = 1000000 });
    try src.append(Value{ .int64 = 1000100 });
    try src.append(Value{ .int64 = 1000200 });
    try src.append(Value{ .int64 = 1000050 });

    const blob = try compress(allocator, &src, .bitpack);
    defer allocator.free(blob);

    var dst = try Column.init(allocator, .int64, 32, .{});
    defer dst.deinit();
    try decompress(allocator, &dst, .bitpack, blob, src.len);

    try std.testing.expectEqual(@as(usize, 4), dst.len);
    try std.testing.expectEqual(@as(i64, 1000000), dst.asSlice(i64)[0]);
    try std.testing.expectEqual(@as(i64, 1000100), dst.asSlice(i64)[1]);
    try std.testing.expectEqual(@as(i64, 1000200), dst.asSlice(i64)[2]);
    try std.testing.expectEqual(@as(i64, 1000050), dst.asSlice(i64)[3]);
}

test "RLE compress/decompress roundtrip boolean" {
    const allocator = std.testing.allocator;
    var src = try Column.init(allocator, .boolean, 32, .{});
    defer src.deinit();
    try src.append(Value{ .boolean = true });
    try src.append(Value{ .boolean = true });
    try src.append(Value{ .boolean = true });
    try src.append(Value{ .boolean = false });
    try src.append(Value{ .boolean = false });
    try src.append(Value{ .boolean = true });

    const blob = try compress(allocator, &src, .rle);
    defer allocator.free(blob);

    var dst = try Column.init(allocator, .boolean, 32, .{});
    defer dst.deinit();
    try decompress(allocator, &dst, .rle, blob, src.len);

    try std.testing.expectEqual(@as(usize, 6), dst.len);
    try std.testing.expectEqual(true, dst.asSlice(bool)[0]);
    try std.testing.expectEqual(true, dst.asSlice(bool)[1]);
    try std.testing.expectEqual(true, dst.asSlice(bool)[2]);
    try std.testing.expectEqual(false, dst.asSlice(bool)[3]);
    try std.testing.expectEqual(false, dst.asSlice(bool)[4]);
    try std.testing.expectEqual(true, dst.asSlice(bool)[5]);
}

test "dictionary compress/decompress roundtrip string" {
    const allocator = std.testing.allocator;
    var src = try Column.init(allocator, .string, 32, .{});
    defer src.deinit();
    try src.append(Value{ .string = "apple" });
    try src.append(Value{ .string = "banana" });
    try src.append(Value{ .string = "apple" });
    try src.append(Value{ .string = "cherry" });
    try src.append(Value{ .string = "banana" });

    const blob = try compress(allocator, &src, .dictionary);
    defer allocator.free(blob);

    var dst = try Column.init(allocator, .string, 32, .{});
    defer dst.deinit();
    try decompress(allocator, &dst, .dictionary, blob, src.len);

    try std.testing.expectEqual(@as(usize, 5), dst.len);
    try std.testing.expectEqualStrings("apple", (try dst.get(0)).string);
    try std.testing.expectEqualStrings("banana", (try dst.get(1)).string);
    try std.testing.expectEqualStrings("apple", (try dst.get(2)).string);
    try std.testing.expectEqualStrings("cherry", (try dst.get(3)).string);
    try std.testing.expectEqualStrings("banana", (try dst.get(4)).string);
}

test "compression ratio verification" {
    const allocator = std.testing.allocator;

    // Test bitpack compression ratio
    var col = try Column.init(allocator, .int32, 128, .{});
    defer col.deinit();
    var i: i32 = 100;
    while (i < 120) : (i += 1) {
        try col.append(Value{ .int32 = i });
    }

    const raw_size = col.len * 4; // 4 bytes per int32
    const compressed = try compress(allocator, &col, .bitpack);
    defer allocator.free(compressed);

    // Should be significantly smaller for tight range
    try std.testing.expect(compressed.len < raw_size);
}
