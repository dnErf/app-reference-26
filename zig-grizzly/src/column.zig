const std = @import("std");
const types = @import("types.zig");
const cardinality_mod = @import("cardinality.zig");
const DataType = types.DataType;
const Value = types.Value;

/// Columnar storage for a single column of data
pub const Column = struct {
    data_type: DataType,
    len: usize,
    capacity: usize,
    data: []u8,
    allocator: std.mem.Allocator,
    string_pool: std.ArrayList([]u8),
    vector_dim: usize = 0,
    row_stride: usize,
    vector_storage: ?[]f32 = null,

    pub const InitOptions = struct {
        vector_dim: usize = 0,
    };

    pub fn init(allocator: std.mem.Allocator, data_type: DataType, capacity: usize, options: InitOptions) !Column {
        const stride: usize = switch (data_type) {
            .vector => blk: {
                if (options.vector_dim == 0) return error.MissingVectorDimension;
                break :blk options.vector_dim * @sizeOf(f32);
            },
            else => data_type.size(),
        };

        const byte_capacity = capacity * stride;
        var data: []u8 = &[_]u8{};
        var vector_storage: ?[]f32 = null;

        if (data_type == .vector) {
            const floats = try allocator.alloc(f32, capacity * options.vector_dim);
            @memset(floats, 0);
            data = std.mem.sliceAsBytes(floats);
            vector_storage = floats;
        } else {
            data = try allocator.alloc(u8, byte_capacity);
            @memset(data, 0);
        }

        return Column{
            .data_type = data_type,
            .len = 0,
            .capacity = capacity,
            .data = data,
            .allocator = allocator,
            .string_pool = std.ArrayList([]u8){},
            .vector_dim = if (data_type == .vector) options.vector_dim else 0,
            .row_stride = stride,
            .vector_storage = vector_storage,
        };
    }

    pub fn deinit(self: *Column) void {
        if (self.data_type == .string) {
            for (self.string_pool.items) |str| {
                self.allocator.free(str);
            }
            self.string_pool.deinit(self.allocator);
        }
        if (self.data_type == .vector) {
            if (self.vector_storage) |storage| {
                self.allocator.free(storage);
            }
        } else {
            self.allocator.free(self.data);
        }
    }

    pub fn append(self: *Column, value: Value) !void {
        if (self.len >= self.capacity) {
            try self.grow();
        }

        const idx = self.len;
        switch (value) {
            .int32 => |v| self.asSlice(i32)[idx] = v,
            .int64, .timestamp => |v| self.asSlice(i64)[idx] = v,
            .float32 => |v| self.asSlice(f32)[idx] = v,
            .float64 => |v| self.asSlice(f64)[idx] = v,
            .boolean => |v| self.asSlice(bool)[idx] = v,
            .string => |v| {
                const owned = try self.allocator.dupe(u8, v);
                try self.string_pool.append(self.allocator, owned);
                self.asSlice(usize)[idx] = self.string_pool.items.len - 1;
            },
            .vector => |vec| {
                if (self.vector_dim == 0 or vec.values.len != self.vector_dim) {
                    return error.VectorDimensionMismatch;
                }
                const storage = self.vector_storage.?;
                const start = idx * self.vector_dim;
                std.mem.copyForwards(f32, storage[start .. start + self.vector_dim], vec.values);
            },
            .custom => |_| {
                // For now, store custom values in a separate storage
                // This is a placeholder - custom types may need special column handling
                return error.CustomTypeNotSupported;
            },
        }
        self.len += 1;
    }

    pub fn get(self: Column, idx: usize) !Value {
        if (idx >= self.len) return error.IndexOutOfBounds;

        return switch (self.data_type) {
            .int32 => Value{ .int32 = self.asSlice(i32)[idx] },
            .int64 => Value{ .int64 = self.asSlice(i64)[idx] },
            .float32 => Value{ .float32 = self.asSlice(f32)[idx] },
            .float64 => Value{ .float64 = self.asSlice(f64)[idx] },
            .boolean => Value{ .boolean = self.asSlice(bool)[idx] },
            .timestamp => Value{ .timestamp = self.asSlice(i64)[idx] },
            .string => blk: {
                const pool_idx = self.asSlice(usize)[idx];
                break :blk Value{ .string = self.string_pool.items[pool_idx] };
            },
            .vector => blk: {
                const slice = self.vectorSlice(idx);
                break :blk Value{ .vector = .{ .values = slice } };
            },
            .custom => {
                // Custom types not yet supported in columns
                return error.CustomTypeNotSupported;
            },
        };
    }

    fn vectorSlice(self: Column, idx: usize) []const f32 {
        const storage = self.vector_storage.?;
        const start = idx * self.vector_dim;
        return storage[start .. start + self.vector_dim];
    }

    pub fn asSlice(self: Column, comptime T: type) []T {
        const ptr: [*]T = @ptrCast(@alignCast(self.data.ptr));
        return ptr[0..self.capacity];
    }

    fn grow(self: *Column) !void {
        const new_capacity = self.capacity * 2;
        if (self.data_type == .vector) {
            const float_count = new_capacity * self.vector_dim;
            const new_storage = try self.allocator.alloc(f32, float_count);
            @memset(new_storage, 0);
            const used = self.len * self.vector_dim;
            const old_storage = self.vector_storage.?;
            std.mem.copyForwards(f32, new_storage[0..used], old_storage[0..used]);
            self.allocator.free(old_storage);
            self.vector_storage = new_storage;
            self.data = std.mem.sliceAsBytes(new_storage);
        } else {
            const new_byte_capacity = new_capacity * self.row_stride;
            const new_data = try self.allocator.alloc(u8, new_byte_capacity);
            const used_bytes = self.len * self.row_stride;
            @memcpy(new_data[0..used_bytes], self.data[0..used_bytes]);
            @memset(new_data[used_bytes..new_byte_capacity], 0);

            self.allocator.free(self.data);
            self.data = new_data;
        }
        self.capacity = new_capacity;
    }

    /// Sum all numeric values in the column
    pub fn sum(self: Column) !Value {
        return switch (self.data_type) {
            .int32 => blk: {
                var total: i64 = 0;
                const slice = self.asSlice(i32);
                for (slice[0..self.len]) |v| total += v;
                break :blk Value{ .int64 = total };
            },
            .int64, .timestamp => blk: {
                var total: i64 = 0;
                const slice = self.asSlice(i64);
                for (slice[0..self.len]) |v| total += v;
                break :blk Value{ .int64 = total };
            },
            .float32 => blk: {
                var total: f64 = 0;
                const slice = self.asSlice(f32);
                for (slice[0..self.len]) |v| total += v;
                break :blk Value{ .float64 = total };
            },
            .float64 => blk: {
                var total: f64 = 0;
                const slice = self.asSlice(f64);
                for (slice[0..self.len]) |v| total += v;
                break :blk Value{ .float64 = total };
            },
            else => error.UnsupportedOperation,
        };
    }

    /// Calculate average of numeric values
    pub fn avg(self: Column) !Value {
        if (self.len == 0) return error.EmptyColumn;
        const total = try self.sum();
        return switch (total) {
            .int64 => |v| Value{ .float64 = @as(f64, @floatFromInt(v)) / @as(f64, @floatFromInt(self.len)) },
            .float64 => |v| Value{ .float64 = v / @as(f64, @floatFromInt(self.len)) },
            else => error.UnsupportedOperation,
        };
    }

    /// Count non-null values
    pub fn count(self: Column) usize {
        return self.len;
    }

    /// Find minimum value
    pub fn min(self: Column) !Value {
        if (self.len == 0) return error.EmptyColumn;

        var min_val = try self.get(0);
        var i: usize = 1;
        while (i < self.len) : (i += 1) {
            const val = try self.get(i);
            if (val.lessThan(min_val)) {
                min_val = val;
            }
        }
        return min_val;
    }

    /// Find maximum value
    pub fn max(self: Column) !Value {
        if (self.len == 0) return error.EmptyColumn;

        var max_val = try self.get(0);
        var i: usize = 1;
        while (i < self.len) : (i += 1) {
            const val = try self.get(i);
            if (max_val.lessThan(val)) {
                max_val = val;
            }
        }
        return max_val;
    }

    /// Count exact distinct values (for small datasets or when precision is critical)
    /// Uses a hash set to track unique values
    /// Threshold: Use this for row_count < 10,000
    pub fn countDistinctExact(self: Column) !cardinality_mod.CardinalityStats {
        var seen = std.AutoHashMap(u64, void).init(self.allocator);
        defer seen.deinit();

        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const val = try self.get(i);
            const hash = try hashValueForCardinality(val);
            try seen.put(hash, {});
        }

        return cardinality_mod.CardinalityStats{
            .distinct_count = seen.count(),
            .total_count = self.len,
            .is_exact = true,
            .sample_rate = 1.0,
        };
    }

    /// Estimate distinct values using HyperLogLog (for large datasets)
    /// More memory efficient than exact counting, with ~0.8% error rate
    /// Threshold: Use this for row_count >= 10,000
    pub fn countDistinctApprox(self: Column) !cardinality_mod.CardinalityStats {
        var hll = try cardinality_mod.HyperLogLog.init(self.allocator);
        defer hll.deinit();

        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const val = try self.get(i);
            try hll.add(val);
        }

        return cardinality_mod.CardinalityStats{
            .distinct_count = hll.estimate(),
            .total_count = self.len,
            .is_exact = false,
            .sample_rate = 1.0,
        };
    }

    /// Estimate distinct values with checkpoint support (for very large datasets)
    /// Saves progress every CHECKPOINT_INTERVAL rows to handle interruptions
    pub fn countDistinctWithCheckpoint(
        self: Column,
        column_name: []const u8,
    ) !cardinality_mod.CardinalityStats {
        const CHECKPOINT_INTERVAL = 10000; // Save every 10k rows

        var hll = try cardinality_mod.HyperLogLog.init(self.allocator);
        defer hll.deinit();

        // Try to resume from checkpoint
        var start_row: usize = 0;
        const checkpoint_result = cardinality_mod.CardinalityCheckpoint.load(self.allocator) catch null;
        if (checkpoint_result) |checkpoint| {
            defer self.allocator.free(checkpoint.column_name);
            if (std.mem.eql(u8, checkpoint.column_name, column_name)) {
                start_row = checkpoint.rows_processed;
                hll.registers = checkpoint.hll_registers;
            }
        }

        var i: usize = start_row;
        while (i < self.len) : (i += 1) {
            const val = try self.get(i);
            try hll.add(val);

            // Save checkpoint periodically
            if ((i + 1) % CHECKPOINT_INTERVAL == 0) {
                const checkpoint = cardinality_mod.CardinalityCheckpoint{
                    .column_name = column_name,
                    .rows_processed = i + 1,
                    .hll_registers = hll.registers,
                    .timestamp = std.time.timestamp(),
                };
                try checkpoint.save(self.allocator);
            }
        }

        // Clear checkpoint on completion
        const checkpoint_module = @import("checkpoint.zig");
        checkpoint_module.clear();

        return cardinality_mod.CardinalityStats{
            .distinct_count = hll.estimate(),
            .total_count = self.len,
            .is_exact = false,
            .sample_rate = 1.0,
        };
    }

    /// Smart cardinality estimation: chooses method based on data size
    /// - Small datasets (< 10k rows): Exact counting
    /// - Medium datasets (10k-100k): Approximate HLL
    /// - Large datasets (>100k): HLL with checkpointing
    pub fn estimateCardinality(
        self: Column,
        column_name: []const u8,
    ) !cardinality_mod.CardinalityStats {
        if (self.len < 10_000) {
            return self.countDistinctExact();
        } else if (self.len < 100_000) {
            return self.countDistinctApprox();
        } else {
            return self.countDistinctWithCheckpoint(column_name);
        }
    }

    /// Hash a value for cardinality tracking
    fn hashValueForCardinality(value: Value) !u64 {
        var hasher = std.hash.Wyhash.init(0);

        switch (value) {
            .int32 => |v| {
                const bytes = std.mem.asBytes(&v);
                hasher.update(bytes);
            },
            .int64, .timestamp => |v| {
                const bytes = std.mem.asBytes(&v);
                hasher.update(bytes);
            },
            .float32 => |v| {
                const bytes = std.mem.asBytes(&v);
                hasher.update(bytes);
            },
            .float64 => |v| {
                const bytes = std.mem.asBytes(&v);
                hasher.update(bytes);
            },
            .boolean => |v| {
                const byte: u8 = if (v) 1 else 0;
                hasher.update(&[_]u8{byte});
            },
            .string => |v| {
                hasher.update(v);
            },
            .vector => |v| {
                const bytes = std.mem.sliceAsBytes(v.values);
                hasher.update(bytes);
            },
            .custom => |_| {
                // Custom types not supported for cardinality tracking yet
                return error.CustomTypeNotSupported;
            },
        }

        return hasher.final();
    }
};

test "Column operations" {
    const allocator = std.testing.allocator;

    var col = try Column.init(allocator, .int32, 4, .{});
    defer col.deinit();

    try col.append(Value{ .int32 = 10 });
    try col.append(Value{ .int32 = 20 });
    try col.append(Value{ .int32 = 30 });

    try std.testing.expectEqual(@as(usize, 3), col.len);

    const val = try col.get(1);
    try std.testing.expectEqual(@as(i32, 20), val.int32);

    const total = try col.sum();
    try std.testing.expectEqual(@as(i64, 60), total.int64);

    const average = try col.avg();
    try std.testing.expectEqual(@as(f64, 20.0), average.float64);
}

test "Column string storage" {
    const allocator = std.testing.allocator;

    var col = try Column.init(allocator, .string, 4, .{});
    defer col.deinit();

    try col.append(Value{ .string = "hello" });
    try col.append(Value{ .string = "world" });

    const val1 = try col.get(0);
    const val2 = try col.get(1);

    try std.testing.expectEqualStrings("hello", val1.string);
    try std.testing.expectEqualStrings("world", val2.string);
}

test "Column vector storage" {
    const allocator = std.testing.allocator;

    var col = try Column.init(allocator, .vector, 2, .{ .vector_dim = 3 });
    defer col.deinit();

    try col.append(Value{ .vector = .{ .values = &[_]f32{ 0.1, 0.2, 0.3 } } });
    try col.append(Value{ .vector = .{ .values = &[_]f32{ 1.0, 2.0, 3.0 } } });

    const first = try col.get(0);
    try std.testing.expectApproxEqAbs(0.2, first.vector.values[1], 1e-6);
    const second = try col.get(1);
    try std.testing.expectApproxEqAbs(3.0, second.vector.values[2], 1e-6);
}

test "Column exact cardinality counting" {
    const allocator = std.testing.allocator;

    var col = try Column.init(allocator, .int32, 10, .{});
    defer col.deinit();

    // Add 10 values with 5 distinct
    try col.append(Value{ .int32 = 1 });
    try col.append(Value{ .int32 = 2 });
    try col.append(Value{ .int32 = 3 });
    try col.append(Value{ .int32 = 2 }); // Duplicate
    try col.append(Value{ .int32 = 4 });
    try col.append(Value{ .int32 = 1 }); // Duplicate
    try col.append(Value{ .int32 = 5 });
    try col.append(Value{ .int32 = 3 }); // Duplicate

    const stats = try col.countDistinctExact();

    try std.testing.expectEqual(@as(u64, 5), stats.distinct_count);
    try std.testing.expectEqual(@as(usize, 8), stats.total_count);
    try std.testing.expect(stats.is_exact);
    try std.testing.expectApproxEqAbs(0.625, stats.uniqueness(), 0.001);
}

test "Column approximate cardinality with HLL" {
    const allocator = std.testing.allocator;

    var col = try Column.init(allocator, .int32, 1000, .{});
    defer col.deinit();

    // Add 500 distinct values
    var i: i32 = 0;
    while (i < 500) : (i += 1) {
        try col.append(Value{ .int32 = i });
    }

    const stats = try col.countDistinctApprox();

    // HLL should estimate close to 500 (allow 10% error)
    const error_margin = @as(f64, @floatFromInt(stats.distinct_count)) * 0.1;
    try std.testing.expect(@abs(@as(f64, @floatFromInt(stats.distinct_count)) - 500.0) < error_margin);
    try std.testing.expectEqual(@as(usize, 500), stats.total_count);
    try std.testing.expect(!stats.is_exact);
}

test "Column smart cardinality estimation" {
    const allocator = std.testing.allocator;

    // Small dataset - should use exact counting
    var small_col = try Column.init(allocator, .int32, 100, .{});
    defer small_col.deinit();

    var i: i32 = 0;
    while (i < 50) : (i += 1) {
        try small_col.append(Value{ .int32 = i });
    }

    const small_stats = try small_col.estimateCardinality("test_column");
    try std.testing.expectEqual(@as(u64, 50), small_stats.distinct_count);
    try std.testing.expect(small_stats.is_exact);
}

test "Column cardinality for strings" {
    const allocator = std.testing.allocator;

    var col = try Column.init(allocator, .string, 10, .{});
    defer col.deinit();

    try col.append(Value{ .string = "apple" });
    try col.append(Value{ .string = "banana" });
    try col.append(Value{ .string = "apple" }); // Duplicate
    try col.append(Value{ .string = "cherry" });
    try col.append(Value{ .string = "banana" }); // Duplicate

    const stats = try col.countDistinctExact();

    try std.testing.expectEqual(@as(u64, 3), stats.distinct_count);
    try std.testing.expectApproxEqAbs(0.6, stats.uniqueness(), 0.001);
}
