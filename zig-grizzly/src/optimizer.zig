const std = @import("std");
const storage_selector = @import("storage_selector.zig");
const workload_analyzer = @import("workload_analyzer.zig");
const migration = @import("migration.zig");
const storage_engine = @import("storage_engine.zig");
const database_mod = @import("database.zig");
const table_mod = @import("table.zig");
const types = @import("types.zig");

const StorageSelector = storage_selector.StorageSelector;
const WorkloadAnalyzer = workload_analyzer.WorkloadAnalyzer;
const MigrationEngine = migration.MigrationEngine;
const StorageEngine = storage_engine.StorageEngine;
const StorageType = storage_engine.StorageType;
const StorageRecommendation = storage_engine.StorageRecommendation;
const MigrationResult = storage_engine.MigrationResult;
const Database = database_mod.Database;
const Table = table_mod.Table;

/// Automatic storage optimization engine
pub const StorageOptimizer = struct {
    allocator: std.mem.Allocator,
    selector: StorageSelector,
    analyzer: WorkloadAnalyzer,
    migrator: MigrationEngine,
    database: *Database,
    optimization_interval_ms: u64,
    last_optimization: u64,

    /// Optimization recommendation for a table
    pub const OptimizationRecommendation = struct {
        table_name: []const u8,
        current_storage: StorageType,
        recommended_storage: StorageType,
        confidence: f32,
        reasoning: []const u8,
        estimated_benefit: f32, // Performance improvement percentage
        migration_cost: migration.MigrationEstimate,
    };

    /// Optimization result
    pub const OptimizationResult = struct {
        recommendations: std.ArrayList(OptimizationRecommendation),
        applied_changes: std.ArrayList(AppliedChange),
        total_benefit: f32,
        total_migration_time_ms: f32,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !OptimizationResult {
            return OptimizationResult{
                .recommendations = try std.ArrayList(OptimizationRecommendation).initCapacity(allocator, 0),
                .applied_changes = try std.ArrayList(AppliedChange).initCapacity(allocator, 0),
                .total_benefit = 0.0,
                .total_migration_time_ms = 0.0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *OptimizationResult) void {
            for (self.recommendations.items) |*rec| {
                self.allocator.free(rec.table_name);
                self.allocator.free(rec.reasoning);
            }
            self.recommendations.deinit(self.allocator);
            self.applied_changes.deinit(self.allocator);
        }
    };

    /// Applied optimization change
    pub const AppliedChange = struct {
        table_name: []const u8,
        old_storage: StorageType,
        new_storage: StorageType,
        migration_result: MigrationResult,
    };

    pub fn init(allocator: std.mem.Allocator, database: *Database, optimization_interval_ms: u64) !StorageOptimizer {
        const analyzer = try WorkloadAnalyzer.init(allocator, 24 * 60 * 60 * 1000); // 24 hours window

        return StorageOptimizer{
            .allocator = allocator,
            .selector = StorageSelector.init(allocator),
            .analyzer = analyzer,
            .migrator = MigrationEngine.init(allocator),
            .database = database,
            .optimization_interval_ms = optimization_interval_ms,
            .last_optimization = 0,
        };
    }

    pub fn deinit(self: *StorageOptimizer) void {
        self.analyzer.deinit();
    }

    /// Record a query execution for workload analysis
    pub fn recordQuery(self: *StorageOptimizer, query_str: []const u8, execution_time_ms: u64, rows_affected: usize) !void {
        try self.analyzer.recordQuery(query_str, execution_time_ms, rows_affected);
    }

    /// Analyze current workload and generate optimization recommendations
    pub fn analyzeWorkload(self: *StorageOptimizer) !OptimizationResult {
        var result = try OptimizationResult.init(self.allocator);

        // Get current workload profile
        const workload = try self.analyzer.generateWorkloadProfile();

        // Get all tables from database
        const tables = try self.database.getTables(self.allocator);
        defer self.allocator.free(tables);

        // Analyze each table
        for (tables) |table| {
            const recommendation = try self.analyzeTable(table, workload);
            if (recommendation.confidence > 0.7) { // Only recommend if confidence is high
                try result.recommendations.append(self.allocator, recommendation);
            }
        }

        // Sort recommendations by benefit (highest first)
        std.sort.heap(OptimizationRecommendation, result.recommendations.items, {}, compareRecommendations);

        return result;
    }

    /// Apply optimization recommendations automatically
    pub fn applyOptimizations(self: *StorageOptimizer, recommendations: []OptimizationRecommendation, auto_apply: bool) !OptimizationResult {
        var result = try OptimizationResult.init(self.allocator);

        for (recommendations) |rec| {
            if (auto_apply or try self.shouldApplyRecommendation(rec)) {
                const applied = try self.applyRecommendation(rec);
                try result.applied_changes.append(self.allocator, applied);
                result.total_benefit += rec.estimated_benefit;
                result.total_migration_time_ms += @as(f32, @floatFromInt(applied.migration_result.duration_ms));
            } else {
                try result.recommendations.append(self.allocator, rec);
            }
        }

        // Update last optimization timestamp
        self.last_optimization = @as(u64, @intCast(std.time.milliTimestamp()));

        return result;
    }

    /// Run full optimization cycle (analyze + apply)
    pub fn runOptimizationCycle(self: *StorageOptimizer, auto_apply: bool) !OptimizationResult {
        const now = std.time.milliTimestamp();

        // Check if it's time for optimization
        if (now - self.last_optimization < self.optimization_interval_ms) {
            return try OptimizationResult.init(self.allocator);
        }

        // Analyze workload
        var analysis_result = try self.analyzeWorkload();
        defer analysis_result.deinit();

        // Apply optimizations
        const apply_result = try self.applyOptimizations(analysis_result.recommendations.items, auto_apply);

        return apply_result;
    }

    /// Get optimization statistics
    pub fn getOptimizationStats(self: *StorageOptimizer) struct {
        workload_stats: *workload_analyzer.WorkloadAnalyzer,
        last_optimization: u64,
        time_since_last_optimization: u64,
        recommendations_pending: usize,
    } {
        const now = std.time.milliTimestamp();
        return .{
            .workload_stats = &self.analyzer,
            .last_optimization = self.last_optimization,
            .time_since_last_optimization = @as(u64, @intCast(now)) -% self.last_optimization,
            .recommendations_pending = 0, // TODO: track pending recommendations
        };
    }

    fn analyzeTable(self: *StorageOptimizer, table: Table, workload: storage_selector.WorkloadProfile) !OptimizationRecommendation {
        // Get current storage type for table
        const current_storage = try self.getTableStorageType(table);

        // Generate recommendation for this workload
        const recommendation = try self.selector.recommendStorage(workload);

        // Calculate estimated benefit
        const benefit = try self.calculateBenefit(table, current_storage, recommendation.storage_type, workload);

        // Estimate migration cost
        const migration_cost = try self.estimateMigrationCost(table, current_storage, recommendation.storage_type);

        return OptimizationRecommendation{
            .table_name = try self.allocator.dupe(u8, table.name),
            .current_storage = current_storage,
            .recommended_storage = recommendation.storage_type,
            .confidence = recommendation.confidence,
            .reasoning = try self.allocator.dupe(u8, recommendation.reasoning),
            .estimated_benefit = benefit,
            .migration_cost = migration_cost,
        };
    }

    fn getTableStorageType(self: *StorageOptimizer, table: Table) !StorageType {
        _ = self;
        // This would need to be implemented in the database/table structure
        // For now, return a default
        _ = table;
        return .memory; // TODO: implement actual storage type retrieval
    }

    fn calculateBenefit(self: *StorageOptimizer, table: Table, current: StorageType, recommended: StorageType, workload: storage_selector.WorkloadProfile) !f32 {
        _ = self;
        _ = table;
        if (current == recommended) return 0.0;

        // Calculate performance improvement based on workload characteristics
        var benefit: f32 = 0.0;

        switch (recommended) {
            .memory => {
                if (workload.real_time) benefit += 0.3;
                if (workload.point_lookups) benefit += 0.2;
                if (workload.data_size_gb < 10.0) benefit += 0.2;
            },
            .column => {
                if (workload.analytical_queries) benefit += 0.4;
                if (workload.batch_processing) benefit += 0.3;
                if (workload.read_heavy) benefit += 0.2;
            },
            .row => {
                if (workload.write_heavy) benefit += 0.3;
                if (workload.point_lookups) benefit += 0.3;
                if (workload.real_time) benefit += 0.2;
            },
            .graph => {
                if (workload.graph_traversals) benefit += 0.5;
                if (workload.complex_joins) benefit += 0.3;
            },
        }

        // Penalize based on data size for memory store
        if (recommended == .memory and workload.data_size_gb > 50.0) {
            benefit *= 0.5;
        }

        // Factor in table size
        const table_size_factor = std.math.clamp(workload.data_size_gb / 100.0, 0.1, 1.0);
        benefit *= table_size_factor;

        return benefit;
    }

    fn estimateMigrationCost(self: *StorageOptimizer, table: Table, from_type: StorageType, to_type: StorageType) !migration.MigrationEstimate {
        // Create temporary engines for estimation
        var from_engine = try self.createStorageEngine(from_type, table.name);
        defer from_engine.deinit();

        var to_engine = try self.createStorageEngine(to_type, table.name);
        defer to_engine.deinit();

        return try self.migrator.estimateMigrationCost(&from_engine, &to_engine, table.name);
    }

    fn createStorageEngine(self: *StorageOptimizer, storage_type: StorageType, base_path: []const u8) !StorageEngine {
        return switch (storage_type) {
            .memory => storage_engine.createMemoryStore(self.allocator),
            .column => storage_engine.createColumnStore(self.allocator, base_path),
            .row => storage_engine.createRowStore(self.allocator, base_path),
            .graph => storage_engine.createGraphStore(self.allocator, base_path),
        };
    }

    fn shouldApplyRecommendation(self: *StorageOptimizer, rec: OptimizationRecommendation) !bool {
        _ = self;
        // Auto-apply if benefit is significant and migration cost is reasonable
        const benefit_threshold = 0.2; // 20% improvement
        const cost_threshold_ms = 5000; // 5 seconds max

        return rec.estimated_benefit > benefit_threshold and
            rec.migration_cost.estimated_time_ms < cost_threshold_ms;
    }

    fn applyRecommendation(self: *StorageOptimizer, rec: OptimizationRecommendation) !AppliedChange {
        // Get table
        const table = try self.database.getTable(rec.table_name);

        // Create engines
        var from_engine = try self.createStorageEngine(rec.current_storage, table.name);
        defer from_engine.deinit();

        var to_engine = try self.createStorageEngine(rec.recommended_storage, table.name);
        defer to_engine.deinit();

        // Perform migration
        const migration_result = try self.migrator.migrateData(&from_engine, &to_engine, table.name);

        // Update table storage type (this would need database API changes)
        // try self.database.updateTableStorage(table.name, rec.recommended_storage);

        return AppliedChange{
            .table_name = try self.allocator.dupe(u8, rec.table_name),
            .old_storage = rec.current_storage,
            .new_storage = rec.recommended_storage,
            .migration_result = migration_result,
        };
    }

    fn compareRecommendations(_: void, a: OptimizationRecommendation, b: OptimizationRecommendation) bool {
        return a.estimated_benefit > b.estimated_benefit;
    }
};
