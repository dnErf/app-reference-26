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
        try reasoning.writer(self.allocator).print("Selected {s} storage (score: {}) based on workload: ", .{
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

    /// Advanced workload analysis with historical data
    pub fn analyzeWorkloadTrends(_: StorageSelector, recent_queries: []const QueryStats, historical_window_ms: u64) !WorkloadProfile {
        var profile = WorkloadProfile{};
        const now = std.time.milliTimestamp();

        // Separate recent vs historical queries
        var recent_reads: usize = 0;
        var recent_writes: usize = 0;
        var historical_reads: usize = 0;
        var historical_writes: usize = 0;

        var total_recent_time: u64 = 0;
        var total_historical_time: u64 = 0;

        for (recent_queries) |stats| {
            const is_recent = (now - stats.timestamp) < historical_window_ms;

            if (stats.is_read) {
                if (is_recent) recent_reads += 1 else historical_reads += 1;
            } else {
                if (is_recent) recent_writes += 1 else historical_writes += 1;
            }

            if (is_recent) {
                total_recent_time += stats.execution_time_ms;
            } else {
                total_historical_time += stats.execution_time_ms;
            }

            // Analyze query patterns
            if (stats.is_analytical) profile.analytical_queries = true;
            if (stats.is_point_lookup) profile.point_lookups = true;
            if (stats.has_complex_joins) profile.complex_joins = true;
            if (stats.is_graph_query) profile.graph_traversals = true;
            if (stats.is_batch) profile.batch_processing = true;
            if (stats.is_real_time) profile.real_time = true;
        }

        // Calculate workload characteristics
        const total_recent = recent_reads + recent_writes;
        const total_historical = historical_reads + historical_writes;

        if (total_recent > 0) {
            profile.read_heavy = @as(f32, @floatFromInt(recent_reads)) / @as(f32, @floatFromInt(total_recent)) > 0.6;
            profile.write_heavy = @as(f32, @floatFromInt(recent_writes)) / @as(f32, @floatFromInt(total_recent)) > 0.4;
        }

        // Detect workload changes (trending analysis)
        if (total_historical > 0) {
            const recent_read_ratio = @as(f32, @floatFromInt(recent_reads)) / @as(f32, @floatFromInt(total_recent));
            const historical_read_ratio = @as(f32, @floatFromInt(historical_reads)) / @as(f32, @floatFromInt(total_historical));

            // If read ratio increased significantly, might need different storage
            if (recent_read_ratio > historical_read_ratio + 0.2) {
                profile.read_heavy = true;
            }
        }

        // Estimate data size based on query patterns (rough heuristic)
        profile.data_size_gb = @as(f32, @floatFromInt(recent_queries.len)) * 0.01; // Assume ~10MB per query pattern

        // Calculate average query complexity
        var total_complexity: f32 = 0.0;
        for (recent_queries) |stats| {
            total_complexity += stats.complexity_score;
        }
        profile.query_complexity = if (recent_queries.len > 0) total_complexity / @as(f32, @floatFromInt(recent_queries.len)) else 0.0;

        return profile;
    }

    /// Cost-based storage selection
    pub fn selectOptimalStorage(self: StorageSelector, profile: WorkloadProfile, available_storages: []const StorageType, cost_weights: CostWeights) !StorageRecommendation {
        var best_storage = available_storages[0];
        var best_score: f32 = 0.0;
        var reasoning = std.ArrayList(u8).init(self.allocator);
        defer reasoning.deinit();

        for (available_storages) |storage_type| {
            const score = self.calculateCostBasedScore(storage_type, profile, cost_weights);

            if (score > best_score) {
                best_score = score;
                best_storage = storage_type;
            }
        }

        // Generate reasoning
        try reasoning.writer(self.allocator).print("Cost-based selection: {s} (score: {}) with weights - perf: {}, cost: {}, maint: {}", .{
            @tagName(best_storage),
            best_score,
            cost_weights.performance_weight,
            cost_weights.cost_weight,
            cost_weights.maintenance_weight,
        });

        const reasoning_slice = try reasoning.toOwnedSlice(self.allocator);

        return StorageRecommendation{
            .storage_type = best_storage,
            .confidence = std.math.clamp(best_score / 10.0, 0.0, 1.0), // Normalize to 0-1
            .reasoning = reasoning_slice,
        };
    }

    fn calculateCostBasedScore(_: StorageSelector, storage_type: StorageType, profile: WorkloadProfile, weights: CostWeights) f32 {
        var performance_score: f32 = 0.0;
        var cost_score: f32 = 0.0;
        var maintenance_score: f32 = 0.0;

        switch (storage_type) {
            .memory => {
                performance_score = 9.0; // Excellent performance
                cost_score = 3.0; // High memory cost
                maintenance_score = 7.0; // Low maintenance

                if (profile.data_size_gb > 100.0) performance_score -= 3.0; // Penalize for large datasets
                if (profile.write_heavy) performance_score -= 1.0; // Memory writes are expensive
            },
            .column => {
                performance_score = if (profile.analytical_queries) 8.0 else 5.0;
                cost_score = 7.0; // Moderate storage cost
                maintenance_score = 6.0; // Moderate maintenance

                if (profile.batch_processing) performance_score += 1.0;
                if (profile.point_lookups) performance_score -= 2.0; // Not optimized for lookups
            },
            .row => {
                performance_score = if (profile.write_heavy or profile.point_lookups) 8.0 else 5.0;
                cost_score = 6.0; // Balanced cost
                maintenance_score = 5.0; // Moderate maintenance

                if (profile.analytical_queries) performance_score -= 2.0; // Less efficient for analytics
                if (profile.complex_joins) performance_score += 1.0;
            },
            .graph => {
                performance_score = if (profile.graph_traversals) 9.0 else 2.0;
                cost_score = 5.0; // Lower cost for specialized use
                maintenance_score = 4.0; // Higher maintenance for complex structure

                if (!profile.graph_traversals and !profile.complex_joins) performance_score = 1.0;
            },
        }

        // Apply workload-specific adjustments
        if (profile.real_time) performance_score += 1.0;
        if (profile.batch_processing and storage_type == .column) performance_score += 1.0;

        return (performance_score * weights.performance_weight +
            cost_score * weights.cost_weight +
            maintenance_score * weights.maintenance_weight) / (weights.performance_weight + weights.cost_weight + weights.maintenance_weight);
    }
};

/// Query execution statistics for advanced analysis
pub const QueryStats = struct {
    timestamp: u64,
    execution_time_ms: u64,
    is_read: bool,
    is_write: bool,
    is_analytical: bool,
    is_point_lookup: bool,
    has_complex_joins: bool,
    is_graph_query: bool,
    is_batch: bool,
    is_real_time: bool,
    complexity_score: f32,
};

/// Cost weights for storage selection
pub const CostWeights = struct {
    performance_weight: f32 = 0.7,
    cost_weight: f32 = 0.2,
    maintenance_weight: f32 = 0.1,
};
