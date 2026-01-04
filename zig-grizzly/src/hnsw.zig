const std = @import("std");
const vector = @import("vector.zig");

const VectorOps = vector.VectorOps;
const DistanceMetric = vector.DistanceMetric;

/// Simplified HNSW implementation for Sprint 8.5
/// Full HNSW with hierarchical layers will be implemented in future sprints
pub const HNSWIndex = struct {
    allocator: std.mem.Allocator,
    vectors: std.ArrayList([]const f32),
    metric: DistanceMetric,

    pub fn init(allocator: std.mem.Allocator, metric: DistanceMetric) !HNSWIndex {
        return HNSWIndex{
            .allocator = allocator,
            .vectors = try std.ArrayList([]const f32).initCapacity(allocator, 16),
            .metric = metric,
        };
    }

    pub fn deinit(self: *HNSWIndex) void {
        for (self.vectors.items) |vec| {
            self.allocator.free(vec);
        }
        self.vectors.deinit(self.allocator);
    }

    /// Add a vector to the index (simplified - no graph construction yet)
    pub fn addVector(self: *HNSWIndex, vec: []const f32) !void {
        const copy = try self.allocator.dupe(f32, vec);
        try self.vectors.append(self.allocator, copy);
    }

    /// Linear search for k nearest neighbors (placeholder for full HNSW)
    pub fn searchKNN(self: *HNSWIndex, query: []const f32, k: usize) !std.ArrayList(usize) {
        var results = try std.ArrayList(usize).initCapacity(self.allocator, k);
        var distances = try std.ArrayList(f32).initCapacity(self.allocator, self.vectors.items.len);
        defer distances.deinit(self.allocator);

        // Calculate distances to all vectors
        for (self.vectors.items, 0..) |vec, i| {
            _ = vec; // We'll use the index
            const dist = try self.metric.calculate(query, self.vectors.items[i]);
            try distances.append(self.allocator, dist);
        }

        // Simple selection sort to find k smallest distances
        for (0..@min(k, distances.items.len)) |_| {
            var min_idx: usize = 0;
            var min_dist = distances.items[0];

            for (1..distances.items.len) |i| {
                if (distances.items[i] < min_dist) {
                    min_dist = distances.items[i];
                    min_idx = i;
                }
            }

            try results.append(self.allocator, min_idx);
            // Mark as processed by setting to max
            distances.items[min_idx] = std.math.floatMax(f32);
        }

        return results;
    }
};

test "HNSW basic operations" {
    const allocator = std.testing.allocator;

    var index = try HNSWIndex.init(allocator, .euclidean);
    defer index.deinit();

    // Add some test vectors
    const vec1 = [_]f32{ 1.0, 0.0 };
    const vec2 = [_]f32{ 0.0, 1.0 };
    const vec3 = [_]f32{ 1.0, 1.0 };

    try index.addVector(&vec1);
    try index.addVector(&vec2);
    try index.addVector(&vec3);

    // Search for nearest neighbor
    const query = [_]f32{ 0.9, 0.1 };
    var results = try index.searchKNN(&query, 1);
    defer results.deinit(allocator);

    try std.testing.expect(results.items.len == 1);
    // Should find vec1 (index 0) as closest to query
    try std.testing.expect(results.items[0] == 0);
}
