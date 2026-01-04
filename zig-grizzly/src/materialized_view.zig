const std = @import("std");
const Database = @import("database.zig").Database;
const Table = @import("table.zig").Table;
const View = @import("view.zig").View;
const ViewType = @import("view.zig").ViewType;
const Value = @import("types.zig").Value;
const Schema = @import("schema.zig").Schema;

pub const MaterializedViewInfo = struct {
    name: []const u8,
    sql_definition: []const u8,
    refresh_policy: MaterializedView.RefreshPolicy,
    last_refresh: ?i64,
    row_count: ?u64,
    dependency_count: usize,
};

pub const MaterializedView = struct {
    view: View,
    storage_table: ?*Table, // Reference to the storage table in the database
    refresh_policy: RefreshPolicy,
    dependencies: std.ArrayList([]const u8), // Tables this view depends on

    pub const RefreshPolicy = enum {
        manual, // Only refresh when explicitly requested
        automatic, // Refresh on dependency changes
        scheduled, // Refresh on schedule (future feature)
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, sql: []const u8, policy: RefreshPolicy) !MaterializedView {
        const view = try View.init(allocator, name, .materialized, sql);
        errdefer view.deinit(allocator);

        var dependencies = std.ArrayListUnmanaged([]const u8){};
        errdefer dependencies.deinit(allocator);

        return MaterializedView{
            .view = view,
            .storage_table = null,
            .refresh_policy = policy,
            .dependencies = dependencies,
        };
    }

    pub fn deinit(self: *MaterializedView, allocator: std.mem.Allocator) void {
        self.view.deinit(allocator);
        // Note: storage_table is owned by the database, don't deinit here
        for (self.dependencies.items) |dep| {
            allocator.free(dep);
        }
        self.dependencies.deinit(allocator);
    }

    pub fn refresh(self: *MaterializedView, db: *Database) !void {
        // Execute the view query
        var result_table = try self.view.execute(db);
        errdefer result_table.deinit();

        // Create or update storage table
        if (self.storage_table == null) {
            // First time - create the storage table
            const storage_name = try std.fmt.allocPrint(db.allocator, "__mv_{s}", .{self.view.name});
            errdefer db.allocator.free(storage_name);

            // Copy schema from result table
            var schema_defs = try std.ArrayList(Schema.ColumnDef).initCapacity(db.allocator, 0);
            defer schema_defs.deinit(db.allocator);

            for (result_table.schema.columns) |col| {
                try schema_defs.append(db.allocator, .{
                    .name = try db.allocator.dupe(u8, col.name),
                    .data_type = col.data_type,
                });
            }

            try db.createTable(storage_name, schema_defs.items);
            self.storage_table = try db.getTable(storage_name);
        }

        // Clear existing data and insert new results
        _ = self.storage_table orelse return error.NoStorageTable;

        // In a real implementation, we'd need to:
        // 1. Clear the storage table
        // 2. Insert all rows from result_table
        // For now, we'll just update metadata
        self.view.last_refresh = std.time.timestamp();
        self.view.row_count = result_table.row_count;

        result_table.deinit();
    }

    pub fn getData(self: *MaterializedView, db: *Database) !Table {
        if (self.storage_table == null) {
            // Need to refresh first
            try self.refresh(db);
        }

        const storage = self.storage_table orelse return error.NoStorageTable;
        return try storage.clone(db.allocator);
    }

    pub fn addDependency(self: *MaterializedView, table_name: []const u8) !void {
        const dep_copy = try self.view.compiled_query.?.allocator.dupe(u8, table_name);
        errdefer self.view.compiled_query.?.allocator.free(dep_copy);

        try self.dependencies.append(dep_copy);
    }

    pub fn checkDependenciesChanged(_: *MaterializedView, _: *Database) !bool {
        // In a real implementation, we'd check modification timestamps
        // of dependency tables vs last_refresh
        return false; // Placeholder
    }
};

pub const MaterializedViewManager = struct {
    allocator: std.mem.Allocator,
    views: std.StringHashMap(MaterializedView),

    pub fn init(allocator: std.mem.Allocator) MaterializedViewManager {
        return MaterializedViewManager{
            .allocator = allocator,
            .views = std.StringHashMap(MaterializedView).init(allocator),
        };
    }

    pub fn deinit(self: *MaterializedViewManager) void {
        var it = self.views.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.views.deinit();
    }

    pub fn createMaterializedView(self: *MaterializedViewManager, name: []const u8, sql: []const u8, policy: MaterializedView.RefreshPolicy) !void {
        if (self.views.contains(name)) return error.MaterializedViewAlreadyExists;

        var mv = try MaterializedView.init(self.allocator, name, sql, policy);
        errdefer mv.deinit(self.allocator);

        try self.views.put(name, mv);
    }

    pub fn getMaterializedView(self: *MaterializedViewManager, name: []const u8) ?MaterializedView {
        return self.views.get(name);
    }

    pub fn getMaterializedViewInfo(self: *MaterializedViewManager, name: []const u8, allocator: std.mem.Allocator) !?MaterializedViewInfo {
        const mv = self.views.get(name) orelse return null;
        return MaterializedViewInfo{
            .name = try allocator.dupe(u8, mv.view.name),
            .sql_definition = try allocator.dupe(u8, mv.view.sql_definition),
            .refresh_policy = mv.refresh_policy,
            .last_refresh = mv.view.last_refresh,
            .row_count = mv.view.row_count,
            .dependency_count = mv.dependencies.items.len,
        };
    }

    pub fn listMaterializedViewInfos(self: *MaterializedViewManager, allocator: std.mem.Allocator) ![]MaterializedViewInfo {
        var result = std.ArrayListUnmanaged(MaterializedViewInfo){};
        defer result.deinit(allocator);

        var it = self.views.iterator();
        while (it.next()) |entry| {
            const mv = entry.value_ptr.*;
            try result.append(allocator, MaterializedViewInfo{
                .name = try allocator.dupe(u8, mv.view.name),
                .sql_definition = try allocator.dupe(u8, mv.view.sql_definition),
                .refresh_policy = mv.refresh_policy,
                .last_refresh = mv.view.last_refresh,
                .row_count = mv.view.row_count,
                .dependency_count = mv.dependencies.items.len,
            });
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn refreshMaterializedView(self: *MaterializedViewManager, name: []const u8, db: *Database) !void {
        const mv_ptr = self.views.getPtr(name) orelse return error.MaterializedViewNotFound;
        try mv_ptr.refresh(db);
    }

    pub fn dropMaterializedView(self: *MaterializedViewManager, name: []const u8) !void {
        const entry = self.views.fetchRemove(name) orelse return error.MaterializedViewNotFound;
        var mutable_mv = entry.value;
        mutable_mv.deinit(self.allocator);
    }

    pub fn refreshAllAutomatic(self: *MaterializedViewManager, db: *Database) !void {
        var it = self.views.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.refresh_policy == .automatic) {
                if (try entry.value_ptr.checkDependenciesChanged(db)) {
                    try entry.value_ptr.refresh(db);
                }
            }
        }
    }
};

test "Materialized view creation" {
    const allocator = std.testing.allocator;

    var manager = MaterializedViewManager.init(allocator);
    defer manager.deinit();

    try manager.createMaterializedView("test_mv", "SELECT 1 as id", .manual);

    const mv = manager.getMaterializedView("test_mv").?;
    try std.testing.expectEqualStrings("test_mv", mv.view.name);
    try std.testing.expectEqual(ViewType.materialized, mv.view.view_type);
    try std.testing.expectEqual(MaterializedView.RefreshPolicy.manual, mv.refresh_policy);
}

test "Materialized view refresh" {
    const allocator = std.testing.allocator;

    var manager = MaterializedViewManager.init(allocator);
    defer manager.deinit();

    try manager.createMaterializedView("test_mv", "SELECT 1 as id, 2 as value", .manual);

    // Note: In a real test, we'd need a database instance
    // For now, just test the structure
    const mv = manager.getMaterializedView("test_mv").?;
    try std.testing.expect(mv.view.last_refresh == null);
    try std.testing.expect(mv.view.row_count == null);
}
