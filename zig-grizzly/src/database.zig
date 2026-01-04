const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");
const schema_mod = @import("schema.zig");
const view_mod = @import("view.zig");
const materialized_view_mod = @import("materialized_view.zig");
const model_mod = @import("model.zig");
const audit_mod = @import("audit.zig");
const dag_mod = @import("dag.zig");
const dependency_mod = @import("dependency.zig");
const scheduler_mod = @import("scheduler.zig");
const type_registry_mod = @import("type_registry.zig");
const function_mod = @import("function.zig");

const Value = types.Value;
const Table = table_mod.Table;
const Schema = schema_mod.Schema;
const ViewRegistry = view_mod.ViewRegistry;
const MaterializedViewManager = materialized_view_mod.MaterializedViewManager;
const ModelRegistry = model_mod.ModelRegistry;
const DependencyGraph = dag_mod.DependencyGraph;
const DependencyAnalyzer = dependency_mod.DependencyAnalyzer;
const Scheduler = scheduler_mod.Scheduler;
const TypeRegistry = type_registry_mod.TypeRegistry;
const FunctionRegistry = function_mod.FunctionRegistry;

/// Database manages multiple tables
pub const Database = struct {
    name: []const u8,
    tables: std.StringHashMap(*Table),
    views: ViewRegistry,
    materialized_views: MaterializedViewManager,
    models: ModelRegistry,
    functions: FunctionRegistry,
    dependency_graph: DependencyGraph,
    dependency_analyzer: DependencyAnalyzer,
    scheduler: Scheduler,
    type_registry: TypeRegistry,
    audit_log: ?*audit_mod.AuditLog,
    attached_databases: std.StringHashMap(*Database),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Database {
        const owned_name = try allocator.dupe(u8, name);
        return Database{
            .name = owned_name,
            .tables = std.StringHashMap(*Table).init(allocator),
            .views = ViewRegistry.init(allocator),
            .materialized_views = MaterializedViewManager.init(allocator),
            .models = ModelRegistry.init(allocator),
            .functions = FunctionRegistry.init(allocator),
            .dependency_graph = DependencyGraph.init(allocator),
            .dependency_analyzer = DependencyAnalyzer.init(allocator),
            .scheduler = try Scheduler.init(allocator),
            .type_registry = TypeRegistry.init(allocator),
            .audit_log = null,
            .attached_databases = std.StringHashMap(*Database).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Database) void {
        var it = self.tables.valueIterator();
        while (it.next()) |table_ptr| {
            table_ptr.*.deinit();
            self.allocator.destroy(table_ptr.*);
        }
        self.tables.deinit();
        self.views.deinit();
        self.materialized_views.deinit();
        self.models.deinit();
        self.functions.deinit();
        self.dependency_graph.deinit();
        self.scheduler.deinit();
        self.type_registry.deinit();
        self.attached_databases.deinit();
        self.allocator.free(self.name);
    }

    /// Create a new table
    pub fn createTable(self: *Database, table_name: []const u8, schema_def: []const Schema.ColumnDef) !void {
        if (self.tables.contains(table_name)) {
            return error.TableAlreadyExists;
        }

        const table = try self.allocator.create(Table);
        table.* = try Table.init(self.allocator, table_name, schema_def);
        try self.tables.put(table.name, table); // Use the owned name from table
    }

    /// Create a table from a query result
    pub fn createTableFromQuery(self: *Database, table_name: []const u8, result_table: *const Table) !void {
        if (self.tables.contains(table_name)) {
            return error.TableAlreadyExists;
        }

        // Create new table with same schema as result
        const table = try self.allocator.create(Table);
        table.* = try Table.init(self.allocator, table_name, result_table.schema.columns);
        try self.tables.put(table.name, table); // Use the owned name from table

        // Copy all rows from result table
        var row: usize = 0;
        while (row < result_table.row_count) : (row += 1) {
            var values = std.ArrayList(Value){};
            defer values.deinit(self.allocator);

            // Get all column values for this row
            for (0..result_table.columns.len) |col| {
                const value = try result_table.getCell(row, col);
                try values.append(self.allocator, value);
            }

            // Insert row into new table
            try table.insertRow(values.items);
        }
    }

    /// Get a table by name
    pub fn getTable(self: *Database, table_name: []const u8) !*Table {
        return self.tables.get(table_name) orelse error.TableNotFound;
    }

    /// Drop a table
    pub fn dropTable(self: *Database, table_name: []const u8) !void {
        if (self.tables.fetchRemove(table_name)) |kv| {
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        } else {
            return error.TableNotFound;
        }
    }

    /// List all table names
    pub fn listTables(self: Database, allocator: std.mem.Allocator) ![][]const u8 {
        var list = std.ArrayList([]const u8){};
        errdefer list.deinit(allocator);

        var it = self.tables.keyIterator();
        while (it.next()) |key| {
            try list.append(allocator, key.*);
        }

        return list.toOwnedSlice(allocator);
    }

    /// Create a view
    pub fn createView(self: *Database, view_name: []const u8, sql: []const u8) !void {
        try self.views.createView(view_name, .virtual, sql);
        if (self.audit_log) |log| {
            try log.log(.create_view, view_name, "Created virtual view", 0, null);
        }
    }

    /// Create a materialized view
    pub fn createMaterializedView(self: *Database, view_name: []const u8, sql: []const u8) !void {
        try self.materialized_views.createMaterializedView(view_name, sql, .manual);
        if (self.audit_log) |log| {
            try log.log(.create_materialized_view, view_name, "Created materialized view", 0, null);
        }
    }

    /// Create a model
    pub fn createModel(self: *Database, model_name: []const u8, sql: []const u8) !void {
        try self.models.createModel(model_name, sql);
        // try self.rebuildDependencyGraph(); // Temporarily disabled due to crash
        if (self.audit_log) |log| {
            try log.log(.create_model, model_name, "Created model", 0, null);
        }
    }

    /// Create an incremental model
    pub fn createIncrementalModel(self: *Database, model_name: []const u8, sql: []const u8, partition_column: ?[]const u8) !void {
        try self.models.createIncrementalModel(model_name, sql, partition_column);
        // try self.rebuildDependencyGraph(); // Temporarily disabled due to crash
        if (self.audit_log) |log| {
            try log.log(.create_model, model_name, "Created incremental model", 0, null);
        }
    }

    /// Drop a model
    pub fn dropModel(self: *Database, model_name: []const u8) !void {
        try self.models.dropModel(model_name);
        try self.dependency_graph.removeNode(model_name);
        if (self.audit_log) |log| {
            try log.log(.drop_model, model_name, "Dropped model", 0, null);
        }
    }

    /// Thread function for parallel model refresh
    fn refreshModelThread(db: *Database, model_id: []const u8, result: *?anyerror) void {
        db.models.refreshModel(model_id, db) catch |err| {
            result.* = err;
        };
    }

    /// Refresh a model and its dependencies
    pub fn refreshModel(self: *Database, model_name: []const u8) !void {
        // Get all dependencies that need to be refreshed
        var all_deps = try self.dependency_graph.getAllDependencies(model_name, self.allocator);
        defer all_deps.deinit();

        // Get execution order using topological sort
        var nodes_to_refresh = std.ArrayListUnmanaged([]const u8){};
        defer nodes_to_refresh.deinit(self.allocator);

        var it = all_deps.iterator();
        while (it.next()) |entry| {
            try nodes_to_refresh.append(self.allocator, try self.allocator.dupe(u8, entry.key_ptr.*));
        }

        // Add the target model itself
        try nodes_to_refresh.append(self.allocator, try self.allocator.dupe(u8, model_name));

        // Get parallel execution groups
        var executed_nodes = std.StringHashMap(void).init(self.allocator);
        defer executed_nodes.deinit();

        const execution_groups = try self.dependency_graph.getParallelExecutionGroups(&executed_nodes, self.allocator);
        defer {
            for (execution_groups) |group| {
                self.allocator.free(group);
            }
            self.allocator.free(execution_groups);
        }

        // Filter groups to only include models we need to refresh
        for (execution_groups) |group| {
            var filtered_group = std.ArrayListUnmanaged([]const u8){};
            defer filtered_group.deinit(self.allocator);

            for (group) |node_id| {
                for (nodes_to_refresh.items) |needed| {
                    if (std.mem.eql(u8, node_id, needed)) {
                        try filtered_group.append(self.allocator, try self.allocator.dupe(u8, node_id));
                        break;
                    }
                }
            }

            if (filtered_group.items.len > 0) {
                // Execute models in this group in parallel
                if (filtered_group.items.len == 1) {
                    // Single model - execute directly
                    try self.models.refreshModel(filtered_group.items[0], self);
                    try executed_nodes.put(filtered_group.items[0], {});
                } else {
                    // Multiple models - execute in parallel using threads
                    var threads = try self.allocator.alloc(std.Thread, filtered_group.items.len);
                    defer self.allocator.free(threads);

                    var thread_results = try self.allocator.alloc(?anyerror, filtered_group.items.len);
                    defer self.allocator.free(thread_results);

                    // Initialize results
                    for (thread_results) |*result| {
                        result.* = null;
                    }

                    // Spawn threads
                    for (filtered_group.items, 0..) |model_id, i| {
                        threads[i] = try std.Thread.spawn(.{}, refreshModelThread, .{ self, model_id, &thread_results[i] });
                    }

                    // Wait for all threads to complete
                    for (threads) |thread| {
                        thread.join();
                    }

                    // Check for errors and update executed_nodes
                    for (filtered_group.items, 0..) |model_id, i| {
                        if (thread_results[i]) |err| {
                            return err;
                        }
                        try executed_nodes.put(model_id, {});
                    }
                }
            }
        }
    }

    /// Refresh model with performance metrics
    pub fn refreshModelWithMetrics(self: *Database, model_name: []const u8) !RefreshMetrics {
        const start_time = std.time.milliTimestamp();

        var metrics = RefreshMetrics{
            .total_models_refreshed = 0,
            .execution_groups = 0,
            .total_execution_time_ms = 0,
        };

        // Get all dependencies that need to be refreshed
        var all_deps = try self.dependency_graph.getAllDependencies(model_name, self.allocator);
        defer all_deps.deinit();

        // Get execution order using topological sort
        var nodes_to_refresh = std.ArrayListUnmanaged([]const u8){};
        defer nodes_to_refresh.deinit(self.allocator);

        var it = all_deps.iterator();
        while (it.next()) |entry| {
            try nodes_to_refresh.append(self.allocator, try self.allocator.dupe(u8, entry.key_ptr.*));
        }

        // Add the target model itself
        try nodes_to_refresh.append(self.allocator, try self.allocator.dupe(u8, model_name));

        // Get parallel execution groups
        var executed_nodes = std.StringHashMap(void).init(self.allocator);
        defer executed_nodes.deinit();

        const execution_groups = try self.dependency_graph.getParallelExecutionGroups(&executed_nodes, self.allocator);
        defer {
            for (execution_groups) |group| {
                self.allocator.free(group);
            }
            self.allocator.free(execution_groups);
        }

        metrics.execution_groups = execution_groups.len;

        // Filter groups to only include models we need to refresh
        for (execution_groups) |group| {
            var filtered_group = std.ArrayListUnmanaged([]const u8){};
            defer filtered_group.deinit(self.allocator);

            for (group) |node_id| {
                for (nodes_to_refresh.items) |needed| {
                    if (std.mem.eql(u8, node_id, needed)) {
                        try filtered_group.append(self.allocator, try self.allocator.dupe(u8, node_id));
                        break;
                    }
                }
            }

            if (filtered_group.items.len > 0) {
                // Execute models in this group
                if (filtered_group.items.len == 1) {
                    // Single model - execute directly
                    const model_start = std.time.milliTimestamp();
                    try self.models.refreshModel(filtered_group.items[0], self);
                    const model_time = std.time.milliTimestamp() - model_start;
                    _ = model_time; // TODO: Track individual model times

                    try executed_nodes.put(filtered_group.items[0], {});
                    metrics.total_models_refreshed += 1;
                } else {
                    // Multiple models - execute in parallel
                    const group_start = std.time.milliTimestamp();

                    var threads = try self.allocator.alloc(std.Thread, filtered_group.items.len);
                    defer self.allocator.free(threads);

                    var thread_results = try self.allocator.alloc(?anyerror, filtered_group.items.len);
                    defer self.allocator.free(thread_results);

                    // Initialize results
                    for (thread_results) |*result| {
                        result.* = null;
                    }

                    // Spawn threads
                    for (filtered_group.items, 0..) |model_id, i| {
                        threads[i] = try std.Thread.spawn(.{}, refreshModelThread, .{ self, model_id, &thread_results[i] });
                    }

                    // Wait for all threads to complete
                    for (threads) |thread| {
                        thread.join();
                    }

                    const group_time = std.time.milliTimestamp() - group_start;
                    _ = group_time; // TODO: Track group execution times

                    // Check for errors and update executed_nodes
                    for (filtered_group.items, 0..) |model_id, i| {
                        if (thread_results[i]) |err| {
                            return err;
                        }
                        try executed_nodes.put(model_id, {});
                        metrics.total_models_refreshed += 1;
                    }
                }
            }
        }

        metrics.total_execution_time_ms = std.time.milliTimestamp() - start_time;
        return metrics;
    }

    pub const RefreshMetrics = struct {
        total_models_refreshed: usize,
        execution_groups: usize,
        total_execution_time_ms: i64,
    };
    pub fn rebuildDependencyGraph(self: *Database) !void {
        // Clear existing graph
        self.dependency_graph.deinit();
        self.dependency_graph = DependencyGraph.init(self.allocator);

        // Build new graph from model dependencies
        var model_deps = try self.dependency_analyzer.buildModelDependencyGraph(self);
        defer {
            var it = model_deps.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
                self.allocator.free(entry.key_ptr.*);
            }
            model_deps.deinit();
        }

        // Add all models as nodes
        var it = model_deps.iterator();
        while (it.next()) |entry| {
            try self.dependency_graph.addNode(entry.key_ptr.*);
        }

        // Add dependencies
        it = model_deps.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.items) |dep| {
                try self.dependency_graph.addDependency(entry.key_ptr.*, dep);
            }
        }
    }

    /// Get dependency graph as DOT format
    pub fn getDependencyGraphDot(self: *Database) ![]u8 {
        return try self.dependency_graph.toDot(self.allocator);
    }

    /// Get lineage for a model (all upstream dependencies)
    pub fn getModelLineage(self: *Database, model_name: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
        var lineage = std.ArrayListUnmanaged([]const u8){};
        defer lineage.deinit(allocator);

        var deps = try self.dependency_graph.getAllDependencies(model_name, allocator);
        defer deps.deinit();

        var it = deps.iterator();
        while (it.next()) |entry| {
            try lineage.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
        }

        return lineage.toOwnedSlice(allocator);
    }

    /// Get a view by name
    pub fn getView(self: *Database, view_name: []const u8) ?view_mod.View {
        return self.views.getView(view_name);
    }

    /// Get a materialized view by name
    pub fn getMaterializedView(self: *Database, view_name: []const u8) ?materialized_view_mod.MaterializedView {
        return self.materialized_views.getMaterializedView(view_name);
    }

    /// Drop a view
    pub fn dropView(self: *Database, view_name: []const u8) !void {
        try self.views.dropView(view_name);
        if (self.audit_log) |log| {
            try log.log(.drop_view, view_name, "Dropped virtual view", 0, null);
        }
    }

    /// Drop a materialized view
    pub fn dropMaterializedView(self: *Database, view_name: []const u8) !void {
        try self.materialized_views.dropMaterializedView(view_name);
        if (self.audit_log) |log| {
            try log.log(.drop_materialized_view, view_name, "Dropped materialized view", 0, null);
        }
    }

    /// Refresh a materialized view
    pub fn refreshMaterializedView(self: *Database, view_name: []const u8) !void {
        try self.materialized_views.refreshMaterializedView(view_name, self);
        if (self.audit_log) |log| {
            // Get the refreshed view to log row count
            if (self.materialized_views.getMaterializedView(view_name)) |mv| {
                try log.log(.refresh_materialized_view, view_name, "Refreshed materialized view", mv.view.row_count orelse 0, null);
            } else {
                try log.log(.refresh_materialized_view, view_name, "Refreshed materialized view", 0, null);
            }
        }
    }

    /// Attach an audit log for tracking operations
    pub fn attachAuditLog(self: *Database, log: *audit_mod.AuditLog) void {
        self.audit_log = log;
    }

    /// Get information about a specific view
    pub fn getViewInfo(self: *Database, view_name: []const u8, allocator: std.mem.Allocator) !?view_mod.ViewInfo {
        return try self.views.getViewInfo(view_name, allocator);
    }

    /// Get information about a specific materialized view
    pub fn getMaterializedViewInfo(self: *Database, view_name: []const u8, allocator: std.mem.Allocator) !?materialized_view_mod.MaterializedViewInfo {
        return try self.materialized_views.getMaterializedViewInfo(view_name, allocator);
    }

    /// List all view information (virtual and materialized)
    pub fn listAllViewInfos(self: *Database, allocator: std.mem.Allocator) !struct { virtual: []view_mod.ViewInfo, materialized: []materialized_view_mod.MaterializedViewInfo } {
        const virtual_views = try self.views.listViewInfos(allocator);
        errdefer {
            for (virtual_views) |info| {
                allocator.free(info.name);
                allocator.free(info.sql_definition);
            }
            allocator.free(virtual_views);
        }

        const materialized_views = try self.materialized_views.listMaterializedViewInfos(allocator);
        errdefer {
            for (materialized_views) |info| {
                allocator.free(info.name);
                allocator.free(info.sql_definition);
            }
            allocator.free(materialized_views);
        }

        return .{
            .virtual = virtual_views,
            .materialized = materialized_views,
        };
    }

    /// Save incremental state for all models to disk
    pub fn saveIncrementalState(self: *Database, directory: []const u8) !void {
        // Create directory if it doesn't exist
        std.fs.cwd().makeDir(directory) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        var it = self.models.models.iterator();
        while (it.next()) |entry| {
            const model = entry.value_ptr;
            if (model.is_incremental) {
                var path_buf = try std.ArrayList(u8).initCapacity(self.allocator, 0);
                defer path_buf.deinit(self.allocator);

                try path_buf.writer(self.allocator).print("{s}/{s}.state.json", .{ directory, model.name });
                try @import("incremental.zig").IncrementalState.saveState(model, path_buf.items);
            }
        }
    }

    /// Load incremental state for all models from disk
    pub fn loadIncrementalState(self: *Database, directory: []const u8) !void {
        var it = self.models.models.iterator();
        while (it.next()) |entry| {
            const model = entry.value_ptr;
            if (model.is_incremental) {
                var path_buf = try std.ArrayList(u8).initCapacity(self.allocator, 0);
                defer path_buf.deinit(self.allocator);

                try path_buf.writer(self.allocator).print("{s}/{s}.state.json", .{ directory, model.name });

                // Try to load state, ignore if file doesn't exist
                @import("incremental.zig").IncrementalState.loadState(self.allocator, model, path_buf.items) catch |err| {
                    if (err != error.FileNotFound) return err;
                };
            }
        }
    }

    // ===== TYPE METHODS =====

    /// Create an enum type
    pub fn createEnumType(self: *Database, type_name: []const u8, values: []const []const u8) !void {
        try self.type_registry.createEnum(type_name, values);
        if (self.audit_log) |log| {
            try log.log(.create_type, type_name, "Created enum type", 0, null);
        }
    }

    /// Create a struct type
    pub fn createStructType(self: *Database, type_name: []const u8, fields: []const @import("types_custom.zig").StructField) !void {
        try self.type_registry.createStruct(type_name, fields);
        if (self.audit_log) |log| {
            try log.log(.create_type, type_name, "Created struct type", 0, null);
        }
    }

    /// Create a type alias
    pub fn createTypeAlias(self: *Database, alias: []const u8, target_type: []const u8) !void {
        try self.type_registry.createAlias(alias, target_type);
        if (self.audit_log) |log| {
            try log.log(.create_type, alias, "Created type alias", 0, null);
        }
    }

    /// Drop a type
    pub fn dropType(self: *Database, type_name: []const u8, cascade: bool) !void {
        try self.type_registry.dropType(type_name, cascade);
        if (self.audit_log) |log| {
            const action = if (cascade) "Dropped type (CASCADE)" else "Dropped type";
            try log.log(.drop, type_name, action, 0, null);
        }
    }

    /// List all custom types
    pub fn listTypes(self: *Database, allocator: std.mem.Allocator) ![][]const u8 {
        return try self.type_registry.listTypes(allocator);
    }

    /// List all type aliases
    pub fn listAliases(self: *Database, allocator: std.mem.Allocator) ![][]const u8 {
        return try self.type_registry.listAliases(allocator);
    }

    /// Get type information for DESCRIBE TYPE
    pub fn describeType(self: *Database, allocator: std.mem.Allocator, type_name: []const u8) !?[]const u8 {
        // Check if it's a custom type
        if (self.type_registry.getType(type_name)) |custom_type| {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            errdefer result.deinit(allocator);

            try result.writer(allocator).print("Type: {s}\n", .{type_name});

            switch (custom_type) {
                .enum_type => |et| {
                    try result.writer(allocator).print("Kind: ENUM\n", .{});
                    try result.writer(allocator).print("Values: ", .{});
                    for (et.values, 0..) |value, i| {
                        if (i > 0) try result.writer(allocator).writeAll(", ");
                        try result.writer(allocator).print("'{s}'", .{value});
                    }
                    try result.writer(allocator).writeAll("\n");
                },
                .struct_type => |st| {
                    try result.writer(allocator).print("Kind: STRUCT\n", .{});
                    try result.writer(allocator).print("Fields:\n", .{});
                    for (st.fields) |field| {
                        try result.writer(allocator).print("  {s} {s}\n", .{ field.name, field.type_ref.name() });
                    }
                },
                .alias => {
                    // Should not happen for custom types
                    try result.writer(allocator).print("Kind: ALIAS\n", .{});
                },
            }

            return try result.toOwnedSlice(allocator);
        }

        // Check if it's an alias
        if (self.type_registry.getAlias(type_name)) |target| {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            errdefer result.deinit(allocator);

            try result.writer(allocator).print("Type: {s}\n", .{type_name});
            try result.writer(allocator).print("Kind: ALIAS\n", .{});
            try result.writer(allocator).print("Target: {s}\n", .{target});

            return try result.toOwnedSlice(allocator);
        }

        return null;
    }

    // ===== SCHEDULER METHODS =====

    /// Create a schedule for model refresh
    pub fn createSchedule(self: *Database, schedule_id: []const u8, model_name: []const u8, cron_expr: []const u8, max_retries: u32) !void {
        // Verify model exists
        if (self.models.getModel(model_name) == null) {
            return error.ModelNotFound;
        }

        const schedule = try scheduler_mod.Schedule.init(self.allocator, schedule_id, model_name, cron_expr, max_retries);
        try self.scheduler.addSchedule(schedule);
    }

    /// Drop a schedule
    pub fn dropSchedule(self: *Database, schedule_id: []const u8) !void {
        if (!self.scheduler.removeSchedule(schedule_id)) {
            return error.ScheduleNotFound;
        }
    }

    /// Get all schedules
    pub fn getSchedules(self: *Database) []scheduler_mod.Schedule {
        return self.scheduler.schedules.items;
    }

    /// Start the scheduler
    pub fn startScheduler(self: *Database) !void {
        try self.scheduler.start();
    }

    /// Stop the scheduler
    pub fn stopScheduler(self: *Database) void {
        self.scheduler.stop();
    }

    /// Check and execute pending schedules
    pub fn checkSchedules(self: *Database) !void {
        try self.scheduler.checkAndExecute(self);
    }

    /// Attach a database with an alias (read-only)
    pub fn attachDatabase(self: *Database, alias: []const u8, db: *Database) !void {
        if (self.attached_databases.contains(alias)) {
            return error.DatabaseAlreadyAttached;
        }
        try self.attached_databases.put(try self.allocator.dupe(u8, alias), db);
    }

    /// Detach a database by alias
    pub fn detachDatabase(self: *Database, alias: []const u8) !void {
        if (!self.attached_databases.contains(alias)) {
            return error.DatabaseNotAttached;
        }
        const key = self.attached_databases.getKey(alias).?;
        self.allocator.free(key);
        _ = self.attached_databases.remove(alias);
    }

    /// Get an attached database by alias
    pub fn getAttachedDatabase(self: *Database, alias: []const u8) ?*Database {
        return self.attached_databases.get(alias);
    }

    /// List all attached database aliases
    pub fn listAttachedDatabases(self: *Database, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
        var list = try std.ArrayList([]const u8).initCapacity(allocator, 0);
        var it = self.attached_databases.keyIterator();
        while (it.next()) |key| {
            try list.append(allocator, try allocator.dupe(u8, key.*));
        }
        return list;
    }
};

test "Database operations" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };

    try db.createTable("users", &schema_def);

    const table = try db.getTable("users");
    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
    });

    try std.testing.expectEqual(@as(usize, 1), table.row_count);
}
