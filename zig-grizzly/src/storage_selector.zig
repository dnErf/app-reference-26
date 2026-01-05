const std = @import("std");
const storage_engine = @import("storage_engine.zig");
const StorageType = storage_engine.StorageType;
const StorageRecommendation = storage_engine.StorageRecommendation;
const StorageCapabilities = storage_engine.StorageCapabilities;

/// Workload characteristics for storage selection
pub const WorkloadProfile = struct {
    read_heavy: bool = false,
    write_heavy: bool = false,
    analytical_queries: bool = false,
    point_lookups: bool = false,
    complex_joins: bool = false,
    graph_traversals: bool = false,
    real_time: bool = false,
    batch_processing: bool = false,
    data_size_gb: f32 = 0.0,
    query_complexity: f32 = 0.0, // 0.0 to 1.0
};

/// Storage selector for automatic engine recommendation
pub const StorageSelector = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StorageSelector {
        return StorageSelector{
            .allocator = allocator,
        };
    }

    /// Analyze workload and recommend optimal storage
    pub fn recommendStorage(self: StorageSelector, workload: WorkloadProfile) !StorageRecommendation {
        // Score each storage type based on workload characteristics
        var scores = std.StringHashMap(f32).init(self.allocator);
        defer scores.deinit();

        // Memory Store scoring
        const memory_score = self.scoreMemoryStore(workload);
        try scores.put("memory", memory_score);

        // Column Store scoring
        const column_score = self.scoreColumnStore(workload);
        try scores.put("column", column_score);

        // Row Store scoring
        const row_score = self.scoreRowStore(workload);
        try scores.put("row", row_score);

        // Graph Store scoring
        const graph_score = self.scoreGraphStore(workload);
        try scores.put("graph", graph_score);

        // Find the highest scoring storage type
        var best_type: StorageType = .memory;
        var best_score: f32 = 0.0;
        var reasoning = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer reasoning.deinit(self.allocator);

        var iter = scores.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* > best_score) {
                best_score = entry.value_ptr.*;
                if (std.mem.eql(u8, entry.key_ptr.*, "memory")) {
                    best_type = .memory;
                } else if (std.mem.eql(u8, entry.key_ptr.*, "column")) {
                    best_type = .column;
                } else if (std.mem.eql(u8, entry.key_ptr.*, "row")) {
                    best_type = .row;
                } else if (std.mem.eql(u8, entry.key_ptr.*, "graph")) {
                    best_type = .graph;
                }
            }
        }

        // Generate reasoning
        try reasoning.writer(self.allocator).print("Selected {s} storage (score: {d:.2}) based on workload: ", .{
            @tagName(best_type),
            best_score,
        });

        if (workload.read_heavy) try reasoning.appendSlice(self.allocator, "read-heavy, ");
        if (workload.write_heavy) try reasoning.appendSlice(self.allocator, "write-heavy, ");
        if (workload.analytical_queries) try reasoning.appendSlice(self.allocator, "analytical, ");
        if (workload.point_lookups) try reasoning.appendSlice(self.allocator, "point-lookups, ");
        if (workload.graph_traversals) try reasoning.appendSlice(self.allocator, "graph-traversals, ");
        if (workload.real_time) try reasoning.appendSlice(self.allocator, "real-time, ");
        if (workload.batch_processing) try reasoning.appendSlice(self.allocator, "batch-processing, ");

        const reasoning_slice = try reasoning.toOwnedSlice(self.allocator);

        return StorageRecommendation{
            .storage_type = best_type,
            .confidence = best_score,
            .reasoning = reasoning_slice,
        };
    }

    fn scoreMemoryStore(_: StorageSelector, workload: WorkloadProfile) f32 {
        var score: f32 = 0.0;

        if (workload.real_time) score += 0.3;
        if (workload.point_lookups) score += 0.2;
        if (workload.read_heavy) score += 0.2;
        if (workload.data_size_gb < 10.0) score += 0.2; // Small datasets
        if (!workload.batch_processing) score += 0.1;

        // Penalties
        if (workload.data_size_gb > 100.0) score -= 0.3; // Too big for memory
        if (workload.write_heavy) score -= 0.1; // Memory writes are expensive

        return std.math.clamp(score, 0.0, 1.0);
    }

    fn scoreColumnStore(_: StorageSelector, workload: WorkloadProfile) f32 {
        var score: f32 = 0.0;

        if (workload.analytical_queries) score += 0.4;
        if (workload.batch_processing) score += 0.3;
        if (workload.read_heavy) score += 0.2;
        if (workload.complex_joins) score += 0.1;

        // Penalties
        if (workload.point_lookups) score -= 0.2; // Not optimized for single row access
        if (workload.real_time) score -= 0.1; // Column stores can be slower for real-time

        return std.math.clamp(score, 0.0, 1.0);
    }

    fn scoreRowStore(_: StorageSelector, workload: WorkloadProfile) f32 {
        var score: f32 = 0.0;

        if (workload.write_heavy) score += 0.3;
        if (workload.point_lookups) score += 0.3;
        if (workload.real_time) score += 0.2;
        if (workload.complex_joins) score += 0.2;

        // Penalties
        if (workload.analytical_queries) score -= 0.2; // Row stores less efficient for analytics
        if (workload.batch_processing) score -= 0.1;

        return std.math.clamp(score, 0.0, 1.0);
    }

    fn scoreGraphStore(_: StorageSelector, workload: WorkloadProfile) f32 {
        var score: f32 = 0.0;

        if (workload.graph_traversals) score += 0.5;
        if (workload.complex_joins) score += 0.3;
        if (workload.read_heavy) score += 0.2;

        // Only recommend graph store if graph operations are significant
        if (score < 0.3) score = 0.0;

        return std.math.clamp(score, 0.0, 1.0);
    }

    /// Analyze query patterns to build workload profile
    pub fn analyzeQueries(self: StorageSelector, queries: []const []const u8) !WorkloadProfile {
        var profile = WorkloadProfile{};

        for (queries) |query| {
            const query_upper = try std.ascii.allocUpperString(self.allocator, query);
            defer self.allocator.free(query_upper);

            // Analyze query patterns
            if (std.mem.indexOf(u8, query_upper, "SELECT") != null) {
                profile.read_heavy = true;

                if (std.mem.indexOf(u8, query_upper, "COUNT(") != null or
                    std.mem.indexOf(u8, query_upper, "SUM(") != null or
                    std.mem.indexOf(u8, query_upper, "AVG(") != null)
                {
                    profile.analytical_queries = true;
                }

                if (std.mem.indexOf(u8, query_upper, "WHERE") != null and
                    !std.mem.containsAtLeast(u8, query_upper, 1, "JOIN"))
                {
                    profile.point_lookups = true;
                }

                if (std.mem.indexOf(u8, query_upper, "JOIN") != null) {
                    profile.complex_joins = true;
                }
            }

            if (std.mem.indexOf(u8, query_upper, "INSERT") != null or
                std.mem.indexOf(u8, query_upper, "UPDATE") != null or
                std.mem.indexOf(u8, query_upper, "DELETE") != null)
            {
                profile.write_heavy = true;
            }

            // Estimate query complexity (simplified)
            const join_count = std.mem.count(u8, query_upper, "JOIN");
            const where_count = std.mem.count(u8, query_upper, "WHERE");
            profile.query_complexity = @min(1.0, (join_count + where_count) / 10.0);
        }

        return profile;
    }
};
