const std = @import("std");
const types = @import("types.zig");
const checkpoint_mod = @import("checkpoint.zig");
const Value = types.Value;

/// HyperLogLog for approximate cardinality estimation
/// Uses 2^14 = 16,384 registers (precision = 14) for ~0.8% standard error
pub const HyperLogLog = struct {
    const PRECISION: u6 = 14;
    const NUM_REGISTERS: usize = 1 << PRECISION; // 16,384
    const REGISTER_MASK: u64 = NUM_REGISTERS - 1;
    const ALPHA_16: f64 = 0.673; // Alpha constant for m=16,384

    registers: [NUM_REGISTERS]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*HyperLogLog {
        const hll = try allocator.create(HyperLogLog);
        hll.* = .{
            .registers = [_]u8{0} ** NUM_REGISTERS,
            .allocator = allocator,
        };
        return hll;
    }

    pub fn deinit(self: *HyperLogLog) void {
        self.allocator.destroy(self);
    }

    /// Add a value to the HLL sketch
    pub fn add(self: *HyperLogLog, value: Value) !void {
        const hash = try hashValue(value);
        self.addHash(hash);
    }

    /// Add a pre-hashed value
    pub fn addHash(self: *HyperLogLog, hash: u64) void {
        // Use first PRECISION bits as register index
        const register_idx = hash & REGISTER_MASK;

        // Count leading zeros in remaining bits + 1
        const remaining = hash >> PRECISION;
        const lz_temp = if (remaining == 0)
            50 // Approximate: 64 - 14 + 1 = 51
        else
            @as(u8, @clz(remaining) + 1);
        const leading_zeros: u8 = lz_temp;

        // Update register with maximum leading zeros seen
        if (leading_zeros > self.registers[register_idx]) {
            self.registers[register_idx] = leading_zeros;
        }
    }

    /// Estimate cardinality using harmonic mean
    pub fn estimate(self: *const HyperLogLog) u64 {
        var sum: f64 = 0.0;
        var zero_count: usize = 0;

        for (self.registers) |reg| {
            if (reg == 0) {
                zero_count += 1;
            }
            sum += std.math.pow(f64, 2.0, -@as(f64, @floatFromInt(reg)));
        }

        const raw_estimate = ALPHA_16 * @as(f64, @floatFromInt(NUM_REGISTERS)) *
            @as(f64, @floatFromInt(NUM_REGISTERS)) / sum;

        // Apply bias corrections for small and large cardinalities
        if (raw_estimate <= 2.5 * @as(f64, @floatFromInt(NUM_REGISTERS))) {
            // Small range correction
            if (zero_count > 0) {
                const m_f = @as(f64, @floatFromInt(NUM_REGISTERS));
                const z_f = @as(f64, @floatFromInt(zero_count));
                return @intFromFloat(m_f * @log(m_f / z_f));
            }
        } else if (raw_estimate > (1.0 / 30.0) * std.math.pow(f64, 2.0, 32.0)) {
            // Large range correction
            return @intFromFloat(-std.math.pow(f64, 2.0, 32.0) *
                @log(1.0 - raw_estimate / std.math.pow(f64, 2.0, 32.0)));
        }

        return @intFromFloat(raw_estimate);
    }

    /// Merge another HLL into this one (union operation)
    pub fn merge(self: *HyperLogLog, other: *const HyperLogLog) void {
        for (self.registers, 0..) |*reg, i| {
            if (other.registers[i] > reg.*) {
                reg.* = other.registers[i];
            }
        }
    }
};

/// Hash a Value to u64 for cardinality estimation
fn hashValue(value: Value) !u64 {
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
            // Custom types not supported for cardinality estimation yet
            return error.CustomTypeNotSupported;
        },
    }

    return hasher.final();
}

/// Cardinality statistics for a column
pub const CardinalityStats = struct {
    distinct_count: u64,
    total_count: usize,
    is_exact: bool,
    sample_rate: f64,

    pub fn uniqueness(self: CardinalityStats) f64 {
        if (self.total_count == 0) return 0.0;
        return @as(f64, @floatFromInt(self.distinct_count)) /
            @as(f64, @floatFromInt(self.total_count));
    }

    /// Export stats in AI-friendly JSON format
    pub fn toJSON(self: CardinalityStats, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{
            \\  "distinct_count": {d},
            \\  "total_count": {d},
            \\  "is_exact": {},
            \\  "sample_rate": {d:.4},
            \\  "uniqueness": {d:.4}
            \\}}
        , .{
            self.distinct_count,
            self.total_count,
            self.is_exact,
            self.sample_rate,
            self.uniqueness(),
        });
    }
};

/// Checkpoint for cardinality calculation (for interruption recovery)
pub const CardinalityCheckpoint = struct {
    column_name: []const u8,
    rows_processed: usize,
    hll_registers: [HyperLogLog.NUM_REGISTERS]u8,
    timestamp: i64,

    pub fn save(self: CardinalityCheckpoint, allocator: std.mem.Allocator) !void {
        const checkpoint = checkpoint_mod.Checkpoint{
            .task = "cardinality_estimation",
            .step = "calculating",
            .table = self.column_name,
            .column_index = null,
            .status = "in_progress",
            .timestamp = self.timestamp,
            .error_msg = null,
        };

        try checkpoint_mod.write(allocator, checkpoint);
    }

    pub fn load(allocator: std.mem.Allocator) !?CardinalityCheckpoint {
        const checkpoint_opt = try checkpoint_mod.read(allocator);
        if (checkpoint_opt == null) return null;

        const checkpoint = checkpoint_opt.?;
        defer checkpoint.deinit(allocator);

        if (!std.mem.eql(u8, checkpoint.task, "cardinality_estimation")) {
            return null;
        }

        // For now, return basic checkpoint info without HLL state
        // Full HLL restoration would require serializing registers
        const result = CardinalityCheckpoint{
            .column_name = try allocator.dupe(u8, checkpoint.table orelse "unknown"),
            .rows_processed = 0, // Would need to store this in metadata
            .hll_registers = [_]u8{0} ** HyperLogLog.NUM_REGISTERS,
            .timestamp = checkpoint.timestamp,
        };

        return result;
    }
};

test "HyperLogLog basic usage" {
    const allocator = std.testing.allocator;

    var hll = try HyperLogLog.init(allocator);
    defer hll.deinit();

    // Add some distinct values
    try hll.add(Value{ .int32 = 1 });
    try hll.add(Value{ .int32 = 2 });
    try hll.add(Value{ .int32 = 3 });
    try hll.add(Value{ .int32 = 1 }); // Duplicate

    const estimate = hll.estimate();

    // Should estimate around 3 distinct values (with some error tolerance)
    try std.testing.expect(estimate >= 2 and estimate <= 5);
}

test "HyperLogLog accuracy" {
    const allocator = std.testing.allocator;

    var hll = try HyperLogLog.init(allocator);
    defer hll.deinit();

    // Add 10,000 distinct values
    var i: i32 = 0;
    while (i < 10000) : (i += 1) {
        try hll.add(Value{ .int32 = i });
    }

    const estimate = hll.estimate();
    const actual: f64 = 10000.0;
    const error_rate = @abs(@as(f64, @floatFromInt(estimate)) - actual) / actual;

    // HyperLogLog with precision=14 should have <1% error
    try std.testing.expect(error_rate < 0.02); // Allow 2% margin
}

test "CardinalityStats uniqueness" {
    const stats = CardinalityStats{
        .distinct_count = 25,
        .total_count = 100,
        .is_exact = true,
        .sample_rate = 1.0,
    };

    try std.testing.expectApproxEqAbs(0.25, stats.uniqueness(), 0.001);
}

test "CardinalityStats JSON export" {
    const allocator = std.testing.allocator;

    const stats = CardinalityStats{
        .distinct_count = 500,
        .total_count = 1000,
        .is_exact = false,
        .sample_rate = 0.5,
    };

    const json = try stats.toJSON(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"distinct_count\": 500") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"is_exact\": false") != null);
}
