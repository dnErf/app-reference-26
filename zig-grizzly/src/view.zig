const std = @import("std");
const Database = @import("database.zig").Database;
const QueryEngine = @import("query.zig").QueryEngine;
const Table = @import("table.zig").Table;
const Value = @import("types.zig").Value;

pub const ViewType = enum {
    virtual, // Computed on demand
    materialized, // Cached results
};

pub const ViewInfo = struct {
    name: []const u8,
    view_type: ViewType,
    sql_definition: []const u8,
    last_refresh: ?i64,
    row_count: ?u64,
};

pub const View = struct {
    name: []const u8,
    view_type: ViewType,
    sql_definition: []const u8,
    compiled_query: ?QueryEngine,
    last_refresh: ?i64, // Timestamp for materialized views
    row_count: ?u64, // For materialized views

    pub fn init(allocator: std.mem.Allocator, name: []const u8, view_type: ViewType, sql: []const u8) !View {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const sql_copy = try allocator.dupe(u8, sql);
        errdefer allocator.free(sql_copy);

        return View{
            .name = name_copy,
            .view_type = view_type,
            .sql_definition = sql_copy,
            .compiled_query = null,
            .last_refresh = null,
            .row_count = null,
        };
    }

    pub fn deinit(self: *View, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.sql_definition);
        // QueryEngine doesn't need deinit
    }

    pub fn compileQuery(self: *View, db: *Database) !void {
        if (self.compiled_query != null) return;

        const query_engine = QueryEngine.init(db.allocator, db, &db.functions);
        self.compiled_query = query_engine;
    }

    pub fn execute(self: *View, db: *Database) !Table {
        if (self.compiled_query == null) {
            try self.compileQuery(db);
        }

        var query_engine = self.compiled_query orelse return error.ViewNotCompiled;
        const result = try query_engine.execute(self.sql_definition);

        switch (result) {
            .table => |t| return t,
            .message => return error.ViewReturnedMessage,
        }
    }

    pub fn refresh(self: *View, db: *Database) !void {
        if (self.view_type != .materialized) return error.NotMaterializedView;

        const result_table = try self.execute(db);
        defer result_table.deinit(db.allocator);

        // For materialized views, we'd store the result table
        // This is a simplified implementation - in reality we'd need
        // to persist the materialized data
        self.last_refresh = std.time.timestamp();
        self.row_count = result_table.row_count;
    }
};

pub const ViewRegistry = struct {
    allocator: std.mem.Allocator,
    views: std.StringHashMap(View),

    pub fn init(allocator: std.mem.Allocator) ViewRegistry {
        return ViewRegistry{
            .allocator = allocator,
            .views = std.StringHashMap(View).init(allocator),
        };
    }

    pub fn deinit(self: *ViewRegistry) void {
        var it = self.views.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.views.deinit();
    }

    pub fn createView(self: *ViewRegistry, name: []const u8, view_type: ViewType, sql: []const u8) !void {
        if (self.views.contains(name)) return error.ViewAlreadyExists;

        var view = try View.init(self.allocator, name, view_type, sql);
        errdefer view.deinit(self.allocator);

        try self.views.put(name, view);
    }

    pub fn getView(self: *ViewRegistry, name: []const u8) ?View {
        return self.views.get(name);
    }

    pub fn dropView(self: *ViewRegistry, name: []const u8) !void {
        const entry = self.views.fetchRemove(name) orelse return error.ViewNotFound;
        var mutable_view = entry.value;
        mutable_view.deinit(self.allocator);
    }

    pub fn refreshMaterializedView(self: *ViewRegistry, name: []const u8, db: *Database) !void {
        const view_ptr = self.views.getPtr(name) orelse return error.ViewNotFound;
        try view_ptr.refresh(db);
    }

    pub fn listViews(self: *ViewRegistry, allocator: std.mem.Allocator) ![][]const u8 {
        var result = std.ArrayListUnmanaged([]const u8){};
        defer result.deinit(allocator);

        var it = self.views.iterator();
        while (it.next()) |entry| {
            try result.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn getViewInfo(self: *ViewRegistry, name: []const u8, allocator: std.mem.Allocator) !?ViewInfo {
        const view = self.views.get(name) orelse return null;
        return ViewInfo{
            .name = try allocator.dupe(u8, view.name),
            .view_type = view.view_type,
            .sql_definition = try allocator.dupe(u8, view.sql_definition),
            .last_refresh = view.last_refresh,
            .row_count = view.row_count,
        };
    }

    pub fn listViewInfos(self: *ViewRegistry, allocator: std.mem.Allocator) ![]ViewInfo {
        var result = std.ArrayListUnmanaged(ViewInfo){};
        defer result.deinit(allocator);

        var it = self.views.iterator();
        while (it.next()) |entry| {
            const view = entry.value_ptr.*;
            try result.append(allocator, ViewInfo{
                .name = try allocator.dupe(u8, view.name),
                .view_type = view.view_type,
                .sql_definition = try allocator.dupe(u8, view.sql_definition),
                .last_refresh = view.last_refresh,
                .row_count = view.row_count,
            });
        }

        return result.toOwnedSlice(allocator);
    }
};

test "View creation and execution" {
    const allocator = std.testing.allocator;

    var registry = ViewRegistry.init(allocator);
    defer registry.deinit();

    // Create a simple view
    try registry.createView("test_view", .virtual, "SELECT 1 as id, 'test' as name");

    const view = registry.getView("test_view").?;
    try std.testing.expectEqualStrings("test_view", view.name);
    try std.testing.expectEqual(ViewType.virtual, view.view_type);
    try std.testing.expectEqualStrings("SELECT 1 as id, 'test' as name", view.sql_definition);
}

test "View registry operations" {
    const allocator = std.testing.allocator;

    var registry = ViewRegistry.init(allocator);
    defer registry.deinit();

    // Create view
    try registry.createView("my_view", .virtual, "SELECT * FROM users");

    // Check it exists
    try std.testing.expect(registry.getView("my_view") != null);

    // List views
    const views = try registry.listViews(allocator);
    defer {
        for (views) |view_name| {
            allocator.free(view_name);
        }
        allocator.free(views);
    }
    try std.testing.expectEqual(@as(usize, 1), views.len);
    try std.testing.expectEqualStrings("my_view", views[0]);

    // Drop view
    try registry.dropView("my_view");
    try std.testing.expect(registry.getView("my_view") == null);
}
