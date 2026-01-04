const std = @import("std");
const CustomValue = @import("types_custom.zig").CustomValue;

/// Data types supported by Grizzly DB
pub const DataType = enum {
    int32,
    int64,
    float32,
    float64,
    boolean,
    string,
    timestamp,
    vector,
    custom,

    pub fn size(self: DataType) usize {
        return switch (self) {
            .int32 => @sizeOf(i32),
            .int64 => @sizeOf(i64),
            .float32 => @sizeOf(f32),
            .float64 => @sizeOf(f64),
            .boolean => @sizeOf(bool),
            .string => @sizeOf(usize), // pointer size
            .timestamp => @sizeOf(i64),
            .vector => @sizeOf(VectorValue),
            .custom => @sizeOf(CustomValue),
        };
    }

    pub fn name(self: DataType) []const u8 {
        return switch (self) {
            .int32 => "int32",
            .int64 => "int64",
            .float32 => "float32",
            .float64 => "float64",
            .boolean => "boolean",
            .string => "string",
            .timestamp => "timestamp",
            .vector => "vector",
            .custom => "custom",
        };
    }
};

pub const VectorValue = struct {
    values: []const f32,

    pub fn len(self: VectorValue) usize {
        return self.values.len;
    }
};

/// Value represents a single data element
pub const Value = union(DataType) {
    int32: i32,
    int64: i64,
    float32: f32,
    float64: f64,
    boolean: bool,
    string: []const u8,
    timestamp: i64,
    vector: VectorValue,
    custom: CustomValue,

    pub fn format(
        self: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .int32 => |v| try writer.print("{d}", .{v}),
            .int64 => |v| try writer.print("{d}", .{v}),
            .float32 => |v| try writer.print("{d:.2}", .{v}),
            .float64 => |v| try writer.print("{d:.2}", .{v}),
            .boolean => |v| try writer.print("{}", .{v}),
            .string => |v| try writer.print("\"{s}\"", .{v}),
            .timestamp => |v| try writer.print("{d}", .{v}),
            .vector => |vec| {
                try writer.writeAll("[");
                for (vec.values, 0..) |item, idx| {
                    if (idx > 0) try writer.writeAll(", ");
                    try writer.print("{d:.4}", .{item});
                }
                try writer.writeAll("]");
            },
            .custom => |cv| {
                switch (cv) {
                    .enum_value => |ev| try writer.print("{s}({s})", .{ ev.type_name, ev.value }),
                    .struct_value => |sv| {
                        try writer.print("{s}{{", .{sv.type_name});
                        var first = true;
                        var it = sv.fields.iterator();
                        while (it.next()) |entry| {
                            if (!first) try writer.writeAll(", ");
                            try writer.print("{s}: ", .{entry.key_ptr.*});
                            try entry.value_ptr.format(fmt, options, writer);
                            first = false;
                        }
                        try writer.writeAll("}");
                    },
                }
            },
        }
    }

    pub fn eql(self: Value, other: Value) bool {
        if (@as(DataType, self) != @as(DataType, other)) return false;
        return switch (self) {
            .int32 => |v| v == other.int32,
            .int64 => |v| v == other.int64,
            .float32 => |v| v == other.float32,
            .float64 => |v| v == other.float64,
            .boolean => |v| v == other.boolean,
            .string => |v| std.mem.eql(u8, v, other.string),
            .timestamp => |v| v == other.timestamp,
            .vector => |v| blk: {
                const other_vec = other.vector;
                if (v.values.len != other_vec.values.len) break :blk false;
                break :blk std.mem.eql(f32, v.values, other_vec.values);
            },
            .custom => |cv| blk: {
                const other_cv = other.custom;
                if (@as(std.meta.Tag(CustomValue), cv) != @as(std.meta.Tag(CustomValue), other_cv)) break :blk false;
                break :blk switch (cv) {
                    .enum_value => |ev| std.mem.eql(u8, ev.value, other_cv.enum_value.value),
                    .struct_value => |sv| blk2: {
                        const other_sv = other_cv.struct_value;
                        if (sv.fields.count() != other_sv.fields.count()) break :blk2 false;
                        var it = sv.fields.iterator();
                        while (it.next()) |entry| {
                            const other_value = other_sv.fields.get(entry.key_ptr.*) orelse break :blk2 false;
                            if (!entry.value_ptr.eql(other_value)) break :blk2 false;
                        }
                        break :blk2 true;
                    },
                };
            },
        };
    }

    pub fn lessThan(self: Value, other: Value) bool {
        if (@as(DataType, self) != @as(DataType, other)) return false;
        return switch (self) {
            .int32 => |v| v < other.int32,
            .int64 => |v| v < other.int64,
            .float32 => |v| v < other.float32,
            .float64 => |v| v < other.float64,
            .boolean => |v| @intFromBool(v) < @intFromBool(other.boolean),
            .string => |v| std.mem.order(u8, v, other.string) == .lt,
            .timestamp => |v| v < other.timestamp,
            .vector => |v| blk: {
                const other_vec = other.vector;
                const len = @min(v.values.len, other_vec.values.len);
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    if (v.values[i] == other_vec.values[i]) continue;
                    break :blk v.values[i] < other_vec.values[i];
                }
                break :blk v.values.len < other_vec.values.len;
            },
            .custom => |cv| blk: {
                const other_cv = other.custom;
                if (@as(std.meta.Tag(CustomValue), cv) != @as(std.meta.Tag(CustomValue), other_cv)) break :blk false;
                break :blk switch (cv) {
                    .enum_value => |ev| ev.index < other_cv.enum_value.index,
                    .struct_value => |sv| blk2: {
                        // Compare by field count first, then lexicographically by field names
                        const other_sv = other_cv.struct_value;
                        if (sv.fields.count() != other_sv.fields.count()) break :blk2 sv.fields.count() < other_sv.fields.count();

                        // Compare field names lexicographically
                        var sv_keys = std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, sv.fields.count()) catch break :blk2 false;
                        defer sv_keys.deinit(std.heap.page_allocator);
                        var sv_it = sv.fields.keyIterator();
                        while (sv_it.next()) |key| sv_keys.append(std.heap.page_allocator, key.*) catch break :blk2 false;
                        std.mem.sort([]const u8, sv_keys.items, {}, struct {
                            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                                return std.mem.order(u8, a, b) == .lt;
                            }
                        }.lessThan);

                        var other_keys = std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, other_sv.fields.count()) catch break :blk2 false;
                        defer other_keys.deinit(std.heap.page_allocator);
                        var other_it = other_sv.fields.keyIterator();
                        while (other_it.next()) |key| other_keys.append(std.heap.page_allocator, key.*) catch break :blk2 false;
                        std.mem.sort([]const u8, other_keys.items, {}, struct {
                            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                                return std.mem.order(u8, a, b) == .lt;
                            }
                        }.lessThan);

                        for (sv_keys.items, other_keys.items) |sv_key, other_key| {
                            const order = std.mem.order(u8, sv_key, other_key);
                            if (order != .eq) break :blk2 order == .lt;
                        }
                        break :blk2 false; // All keys equal
                    },
                };
            },
        };
    }

    pub fn hash(self: Value) u64 {
        var hasher = std.hash.Wyhash.init(0);
        const tag: u8 = @intFromEnum(@as(DataType, self));
        hasher.update(&[_]u8{tag});
        switch (self) {
            .int32 => |v| hasher.update(std.mem.asBytes(&v)),
            .int64 => |v| hasher.update(std.mem.asBytes(&v)),
            .float32 => |v| {
                const bits: u32 = @bitCast(v);
                hasher.update(std.mem.asBytes(&bits));
            },
            .float64 => |v| {
                const bits: u64 = @bitCast(v);
                hasher.update(std.mem.asBytes(&bits));
            },
            .boolean => |v| hasher.update(&[_]u8{@intFromBool(v)}),
            .string => |v| hasher.update(v),
            .timestamp => |v| hasher.update(std.mem.asBytes(&v)),
            .vector => |v| hasher.update(std.mem.sliceAsBytes(v.values)),
            .custom => |cv| {
                const cv_tag: u8 = @intFromEnum(@as(std.meta.Tag(CustomValue), cv));
                hasher.update(&[_]u8{cv_tag});
                switch (cv) {
                    .enum_value => |ev| {
                        hasher.update(ev.type_name);
                        hasher.update(ev.value);
                        hasher.update(std.mem.asBytes(&ev.index));
                    },
                    .struct_value => |sv| {
                        hasher.update(sv.type_name);
                        // Hash fields in sorted order for consistency
                        var keys = std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, sv.fields.count()) catch {
                            // Fallback: hash field count only
                            hasher.update(std.mem.asBytes(&sv.fields.count()));
                            return hasher.final();
                        };
                        defer keys.deinit(std.heap.page_allocator);
                        var it = sv.fields.keyIterator();
                        while (it.next()) |key| keys.append(std.heap.page_allocator, key.*) catch break;
                        std.mem.sort([]const u8, keys.items, {}, struct {
                            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                                return std.mem.order(u8, a, b) == .lt;
                            }
                        }.lessThan);
                        for (keys.items) |key| {
                            hasher.update(key);
                            if (sv.fields.get(key)) |value| {
                                hasher.update(std.mem.asBytes(&@as(u64, @intFromEnum(@as(DataType, value)))));
                                hasher.update(std.mem.asBytes(&value.hash()));
                            }
                        }
                    },
                }
            },
        }
        return hasher.final();
    }

    /// Deinitialize a Value, freeing any owned memory
    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .vector => |v| allocator.free(v.values),
            .custom => |*cv| cv.deinit(allocator),
            else => {}, // Other types don't own memory
        }
    }

    /// Clone a Value, creating a deep copy
    pub fn clone(self: Value, allocator: std.mem.Allocator) !Value {
        return switch (self) {
            .int32 => |v| Value{ .int32 = v },
            .int64 => |v| Value{ .int64 = v },
            .float32 => |v| Value{ .float32 = v },
            .float64 => |v| Value{ .float64 = v },
            .boolean => |v| Value{ .boolean = v },
            .string => |s| Value{ .string = try allocator.dupe(u8, s) },
            .timestamp => |v| Value{ .timestamp = v },
            .vector => |v| blk: {
                const values_copy = try allocator.dupe(f32, v.values);
                break :blk Value{ .vector = VectorValue{ .values = values_copy } };
            },
            .custom => |cv| Value{ .custom = try cv.clone(allocator) },
        };
    }
};

test "DataType size" {
    try std.testing.expectEqual(@as(usize, 4), DataType.int32.size());
    try std.testing.expectEqual(@as(usize, 8), DataType.int64.size());
}

test "Value equality" {
    const v1 = Value{ .int32 = 42 };
    const v2 = Value{ .int32 = 42 };
    const v3 = Value{ .int32 = 43 };

    try std.testing.expect(v1.eql(v2));
    try std.testing.expect(!v1.eql(v3));
}
