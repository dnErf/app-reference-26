const std = @import("std");
const Database = @import("database.zig").Database;
const QueryEngine = @import("query.zig").QueryEngine;
const QueryResult = @import("query.zig").QueryResult;
const Table = @import("table.zig").Table;
const Value = @import("types.zig").Value;

pub const ModelInfo = struct {
    name: []const u8,
    sql_definition: []const u8,
    dependencies: [][]const u8, // Tables/models this model depends on
    last_run: ?i64, // Timestamp
    row_count: ?u64,
    execution_time_ms: ?u64,
    is_incremental: bool,
    partition_column: ?[]const u8,
    last_partition_value: ?Value,
};

pub const Model = struct {
    name: []const u8,
    sql_definition: []const u8,
    dependencies: std.ArrayListUnmanaged([]const u8),
    last_run: ?i64,
    row_count: ?u64,
    execution_time_ms: ?u64,
    materialized_result: ?QueryResult = null,
    is_incremental: bool = false,
    partition_column: ?[]const u8 = null,
    last_partition_value: ?Value = null,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, sql: []const u8) !Model {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const sql_copy = try allocator.dupe(u8, sql);
        errdefer allocator.free(sql_copy);

        return Model{
            .name = name_copy,
            .sql_definition = sql_copy,
            .dependencies = std.ArrayListUnmanaged([]const u8){},
            .last_run = null,
            .row_count = null,
            .execution_time_ms = null,
            .is_incremental = false,
            .partition_column = null,
            .last_partition_value = null,
        };
    }

    pub fn initIncremental(allocator: std.mem.Allocator, name: []const u8, sql: []const u8, partition_column: ?[]const u8) !Model {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const sql_copy = try allocator.dupe(u8, sql);
        errdefer allocator.free(sql_copy);

        var partition_column_copy: ?[]const u8 = null;
        if (partition_column) |col| {
            partition_column_copy = try allocator.dupe(u8, col);
        }

        return Model{
            .name = name_copy,
            .sql_definition = sql_copy,
            .dependencies = std.ArrayListUnmanaged([]const u8){},
            .last_run = null,
            .row_count = null,
            .execution_time_ms = null,
            .is_incremental = true,
            .partition_column = partition_column_copy,
            .last_partition_value = null,
        };
    }

    pub fn deinit(self: *Model, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.sql_definition);

        if (self.materialized_result) |*result| {
            result.deinit();
        }

        if (self.partition_column) |col| {
            allocator.free(col);
        }

        if (self.last_partition_value) |_| {
            // Value is a union of primitives and slices, no deinit needed
        }

        for (self.dependencies.items) |dep| {
            allocator.free(dep);
        }
        self.dependencies.deinit(allocator);
    }

    /// Execute the model and return the result table
    /// For incremental models, only processes new/changed data
    pub fn execute(self: *Model, db: *Database) !*Table {
        if (self.is_incremental) {
            return try @import("incremental.zig").IncrementalEngine.executeIncrementalModel(self, db);
        }

        var engine = QueryEngine.init(db.allocator, db, &db.functions);

        const start_time = std.time.milliTimestamp();

        const result = try engine.execute(self.sql_definition);
        // Store the result to keep the table alive
        self.materialized_result = result;

        const end_time = std.time.milliTimestamp();
        const execution_time = @as(u64, @intCast(end_time - start_time));

        switch (result) {
            .table => |*table| {
                // Update metadata
                self.last_run = end_time;
                self.row_count = table.row_count;
                self.execution_time_ms = execution_time;

                // Return pointer to the stored table
                return @constCast(table);
            },
            .message => return error.ModelExecutionFailed,
        }
    }

    /// Analyze dependencies by parsing the SQL
    pub fn analyzeDependencies(self: *Model, allocator: std.mem.Allocator) !void {
        // Simple dependency analysis - look for FROM/JOIN clauses
        // This is a basic implementation; a full parser would be more robust

        var deps = std.ArrayListUnmanaged([]const u8){};
        defer deps.deinit(allocator);

        // Convert to lowercase for case-insensitive matching
        var sql_lower = std.ArrayListUnmanaged(u8){};
        defer sql_lower.deinit(allocator);

        for (self.sql_definition) |c| {
            try sql_lower.append(allocator, std.ascii.toLower(c));
        }

        // Look for table references after FROM and JOIN
        var i: usize = 0;
        while (i < sql_lower.items.len) {
            // Check for "from "
            if (i + 5 <= sql_lower.items.len and std.mem.eql(u8, sql_lower.items[i .. i + 5], "from ")) {
                i += 5;
                // Skip whitespace
                while (i < sql_lower.items.len and std.ascii.isWhitespace(sql_lower.items[i])) i += 1;
                // Read table name
                if (i < sql_lower.items.len) {
                    const start = i;
                    while (i < sql_lower.items.len and (std.ascii.isAlphanumeric(sql_lower.items[i]) or sql_lower.items[i] == '_')) i += 1;
                    if (start < i) {
                        const table_name = try allocator.dupe(u8, self.sql_definition[start..i]);
                        try deps.append(allocator, table_name);
                    }
                }
            }
            // Check for "join "
            else if (i + 5 <= sql_lower.items.len and std.mem.eql(u8, sql_lower.items[i .. i + 5], "join ")) {
                i += 5;
                // Skip whitespace
                while (i < sql_lower.items.len and std.ascii.isWhitespace(sql_lower.items[i])) i += 1;
                // Read table name
                if (i < sql_lower.items.len) {
                    const start = i;
                    while (i < sql_lower.items.len and (std.ascii.isAlphanumeric(sql_lower.items[i]) or sql_lower.items[i] == '_')) i += 1;
                    if (start < i) {
                        const table_name = try allocator.dupe(u8, self.sql_definition[start..i]);
                        try deps.append(allocator, table_name);
                    }
                }
            } else {
                i += 1;
            }
        }

        // Clear existing dependencies and set new ones
        for (self.dependencies.items) |dep| {
            allocator.free(dep);
        }
        self.dependencies.clearRetainingCapacity();

        try self.dependencies.appendSlice(allocator, deps.items);
        // Ownership transferred to self.dependencies
        deps.items.len = 0;
    }

    pub fn getInfo(self: *const Model, allocator: std.mem.Allocator) !ModelInfo {
        var deps_copy = std.ArrayListUnmanaged([]const u8){};
        defer deps_copy.deinit(allocator);

        for (self.dependencies.items) |dep| {
            try deps_copy.append(allocator, try allocator.dupe(u8, dep));
        }

        var partition_column_copy: ?[]const u8 = null;
        if (self.partition_column) |col| {
            partition_column_copy = try allocator.dupe(u8, col);
        }

        var last_partition_value_copy: ?Value = null;
        if (self.last_partition_value) |val| {
            last_partition_value_copy = try val.clone(allocator);
        }

        return ModelInfo{
            .name = try allocator.dupe(u8, self.name),
            .sql_definition = try allocator.dupe(u8, self.sql_definition),
            .dependencies = try deps_copy.toOwnedSlice(allocator),
            .last_run = self.last_run,
            .row_count = self.row_count,
            .execution_time_ms = self.execution_time_ms,
            .is_incremental = self.is_incremental,
            .partition_column = partition_column_copy,
            .last_partition_value = last_partition_value_copy,
        };
    }
};

pub const ModelRegistry = struct {
    allocator: std.mem.Allocator,
    models: std.StringHashMap(Model),

    pub fn init(allocator: std.mem.Allocator) ModelRegistry {
        return ModelRegistry{
            .allocator = allocator,
            .models = std.StringHashMap(Model).init(allocator),
        };
    }

    pub fn deinit(self: *ModelRegistry) void {
        var it = self.models.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.models.deinit();
    }

    pub fn createModel(self: *ModelRegistry, name: []const u8, sql: []const u8) !void {
        if (self.models.contains(name)) return error.ModelAlreadyExists;

        var model = try Model.init(self.allocator, name, sql);
        errdefer model.deinit(self.allocator);

        // Analyze dependencies
        try model.analyzeDependencies(self.allocator);

        try self.models.put(name, model);
    }

    pub fn createIncrementalModel(self: *ModelRegistry, name: []const u8, sql: []const u8, partition_column: ?[]const u8) !void {
        if (self.models.contains(name)) return error.ModelAlreadyExists;

        var model = try Model.initIncremental(self.allocator, name, sql, partition_column);
        errdefer model.deinit(self.allocator);

        // Analyze dependencies
        try model.analyzeDependencies(self.allocator);

        try self.models.put(name, model);
    }

    pub fn getModel(self: *ModelRegistry, name: []const u8) ?Model {
        return self.models.get(name);
    }

    pub fn dropModel(self: *ModelRegistry, name: []const u8) !void {
        const entry = self.models.fetchRemove(name) orelse return error.ModelNotFound;
        var mutable_model = entry.value;
        mutable_model.deinit(self.allocator);
    }

    pub fn executeModel(self: *ModelRegistry, name: []const u8, db: *Database) !*Table {
        const model_ptr = self.models.getPtr(name) orelse return error.ModelNotFound;
        return try model_ptr.execute(db);
    }

    pub fn refreshModel(self: *ModelRegistry, name: []const u8, db: *Database) !void {
        const model_ptr = self.models.getPtr(name) orelse return error.ModelNotFound;
        const table = try model_ptr.execute(db);
        // We don't need the table, just the side effect of execution
        _ = table;
    }

    pub fn listModels(self: *ModelRegistry, allocator: std.mem.Allocator) ![][]const u8 {
        var result = std.ArrayListUnmanaged([]const u8){};
        defer result.deinit(allocator);

        var it = self.models.iterator();
        while (it.next()) |entry| {
            try result.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn getModelInfo(self: *ModelRegistry, name: []const u8, allocator: std.mem.Allocator) !?ModelInfo {
        const model = self.models.get(name) orelse return null;
        return try model.getInfo(allocator);
    }

    pub fn listAllModelInfos(self: *ModelRegistry, allocator: std.mem.Allocator) ![]ModelInfo {
        var result = std.ArrayListUnmanaged(ModelInfo){};
        defer result.deinit(allocator);

        var it = self.models.iterator();
        while (it.next()) |entry| {
            const info = try entry.value_ptr.getInfo(allocator);
            try result.append(allocator, info);
        }

        return result.toOwnedSlice(allocator);
    }
};
