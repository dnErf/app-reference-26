const std = @import("std");
const types = @import("types.zig");

const VectorValue = types.VectorValue;

/// Vector similarity and distance functions for AI/ML workloads
pub const VectorOps = struct {
    /// Calculate cosine similarity between two vectors
    /// Returns value between -1.0 and 1.0 (1.0 = identical, -1.0 = opposite)
    pub fn cosineSimilarity(a: []const f32, b: []const f32) !f32 {
        if (a.len != b.len) return error.VectorDimensionMismatch;

        var dot_product: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;

        for (a, 0..) |val_a, i| {
            const val_b = b[i];
            dot_product += val_a * val_b;
            norm_a += val_a * val_a;
            norm_b += val_b * val_b;
        }

        if (norm_a == 0.0 or norm_b == 0.0) return 0.0;

        norm_a = std.math.sqrt(norm_a);
        norm_b = std.math.sqrt(norm_b);

        return dot_product / (norm_a * norm_b);
    }

    /// Calculate cosine distance (1 - cosine similarity)
    /// Returns value between 0.0 and 2.0 (0.0 = identical, 2.0 = opposite)
    pub fn cosineDistance(a: []const f32, b: []const f32) !f32 {
        const similarity = try cosineSimilarity(a, b);
        return 1.0 - similarity;
    }

    /// Calculate Euclidean distance between two vectors
    /// Returns non-negative distance value
    pub fn euclideanDistance(a: []const f32, b: []const f32) !f32 {
        if (a.len != b.len) return error.VectorDimensionMismatch;

        var sum_squared: f32 = 0.0;
        for (a, 0..) |val_a, i| {
            const val_b = b[i];
            const diff = val_a - val_b;
            sum_squared += diff * diff;
        }

        return std.math.sqrt(sum_squared);
    }

    /// Calculate squared Euclidean distance (faster, no sqrt)
    /// Returns non-negative squared distance value
    pub fn euclideanDistanceSquared(a: []const f32, b: []const f32) !f32 {
        if (a.len != b.len) return error.VectorDimensionMismatch;

        var sum_squared: f32 = 0.0;
        for (a, 0..) |val_a, i| {
            const val_b = b[i];
            const diff = val_a - val_b;
            sum_squared += diff * diff;
        }

        return sum_squared;
    }

    /// Calculate dot product similarity
    /// Returns unbounded similarity score (higher = more similar)
    pub fn dotProduct(a: []const f32, b: []const f32) !f32 {
        if (a.len != b.len) return error.VectorDimensionMismatch;

        var result: f32 = 0.0;
        for (a, 0..) |val_a, i| {
            result += val_a * b[i];
        }

        return result;
    }

    /// Calculate Manhattan (L1) distance
    /// Returns non-negative distance value
    pub fn manhattanDistance(a: []const f32, b: []const f32) !f32 {
        if (a.len != b.len) return error.VectorDimensionMismatch;

        var sum: f32 = 0.0;
        for (a, 0..) |val_a, i| {
            sum += @abs(val_a - b[i]);
        }

        return sum;
    }

    /// Normalize a vector to unit length (L2 normalization)
    pub fn normalize(allocator: std.mem.Allocator, vector: []const f32) ![]f32 {
        var norm: f32 = 0.0;
        for (vector) |val| {
            norm += val * val;
        }

        if (norm == 0.0) {
            // Return zero vector of same dimension
            return try allocator.dupe(f32, vector);
        }

        norm = std.math.sqrt(norm);
        const normalized = try allocator.alloc(f32, vector.len);
        for (vector, 0..) |val, i| {
            normalized[i] = val / norm;
        }

        return normalized;
    }

    /// Calculate vector magnitude (L2 norm)
    pub fn magnitude(vector: []const f32) f32 {
        var sum: f32 = 0.0;
        for (vector) |val| {
            sum += val * val;
        }
        return std.math.sqrt(sum);
    }
};

/// Distance metrics for vector search
pub const DistanceMetric = enum {
    cosine,
    euclidean,
    euclidean_squared,
    dot_product,
    manhattan,

    pub fn name(self: DistanceMetric) []const u8 {
        return switch (self) {
            .cosine => "cosine",
            .euclidean => "euclidean",
            .euclidean_squared => "euclidean_squared",
            .dot_product => "dot_product",
            .manhattan => "manhattan",
        };
    }

    pub fn calculate(self: DistanceMetric, a: []const f32, b: []const f32) !f32 {
        return switch (self) {
            .cosine => VectorOps.cosineDistance(a, b),
            .euclidean => VectorOps.euclideanDistance(a, b),
            .euclidean_squared => VectorOps.euclideanDistanceSquared(a, b),
            .dot_product => blk: {
                const dp = try VectorOps.dotProduct(a, b);
                // For distance, we want smaller values for more similar vectors
                // Dot product gives higher values for more similar, so negate
                break :blk -dp;
            },
            .manhattan => VectorOps.manhattanDistance(a, b),
        };
    }

    /// Returns true if smaller distance values indicate higher similarity
    pub fn smallerIsBetter(self: DistanceMetric) bool {
        return switch (self) {
            .cosine => true,
            .euclidean => true,
            .euclidean_squared => true,
            .dot_product => false, // Higher dot product = more similar
            .manhattan => true,
        };
    }
};

test "cosine similarity" {
    // Identical vectors
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 1.0, 2.0, 3.0 };
    const similarity = try VectorOps.cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), similarity, 0.0001);

    // Orthogonal vectors
    const c = [_]f32{ 1.0, 0.0 };
    const d = [_]f32{ 0.0, 1.0 };
    const similarity2 = try VectorOps.cosineSimilarity(&c, &d);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), similarity2, 0.0001);

    // Opposite vectors
    const e = [_]f32{ 1.0, 2.0 };
    const f = [_]f32{ -1.0, -2.0 };
    const similarity3 = try VectorOps.cosineSimilarity(&e, &f);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), similarity3, 0.0001);
}

test "euclidean distance" {
    // Same vectors
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 1.0, 2.0, 3.0 };
    const distance = try VectorOps.euclideanDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), distance, 0.0001);

    // Unit vectors
    const c = [_]f32{ 1.0, 0.0 };
    const d = [_]f32{ 0.0, 1.0 };
    const distance2 = try VectorOps.euclideanDistance(&c, &d);
    try std.testing.expectApproxEqAbs(std.math.sqrt(2.0), distance2, 0.0001);
}

test "dot product" {
    // Basic dot product
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };
    const result = try VectorOps.dotProduct(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), result, 0.0001); // 1*4 + 2*5 + 3*6 = 32

    // Orthogonal vectors
    const c = [_]f32{ 1.0, 0.0 };
    const d = [_]f32{ 0.0, 1.0 };
    const result2 = try VectorOps.dotProduct(&c, &d);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result2, 0.0001);
}

test "vector normalization" {
    const allocator = std.testing.allocator;

    // Normalize a vector
    const input = [_]f32{ 3.0, 4.0 }; // Magnitude = 5
    const normalized = try VectorOps.normalize(allocator, &input);
    defer allocator.free(normalized);

    try std.testing.expectApproxEqAbs(@as(f32, 0.6), normalized[0], 0.0001); // 3/5
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), normalized[1], 0.0001); // 4/5

    const mag = VectorOps.magnitude(normalized);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mag, 0.0001);
}

test "distance metrics" {
    const a = [_]f32{ 1.0, 2.0 };
    const b = [_]f32{ 4.0, 6.0 };

    // Test each metric
    const cosine_dist = try DistanceMetric.cosine.calculate(&a, &b);
    try std.testing.expect(cosine_dist >= 0.0);

    const euclidean_dist = try DistanceMetric.euclidean.calculate(&a, &b);
    try std.testing.expect(euclidean_dist >= 0.0);

    const dot_dist = try DistanceMetric.dot_product.calculate(&a, &b);
    _ = dot_dist; // Just verify it doesn't error

    const manhattan_dist = try DistanceMetric.manhattan.calculate(&a, &b);
    try std.testing.expect(manhattan_dist >= 0.0);
}

test "dimension mismatch error" {
    const a = [_]f32{ 1.0, 2.0 };
    const b = [_]f32{ 1.0, 2.0, 3.0 };

    try std.testing.expectError(error.VectorDimensionMismatch, VectorOps.cosineSimilarity(&a, &b));
    try std.testing.expectError(error.VectorDimensionMismatch, VectorOps.euclideanDistance(&a, &b));
    try std.testing.expectError(error.VectorDimensionMismatch, VectorOps.dotProduct(&a, &b));
}
