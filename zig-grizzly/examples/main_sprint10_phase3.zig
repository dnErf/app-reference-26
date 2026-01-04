const std = @import("std");
const zig_grizzly = @import("zig_grizzly");
const Database = zig_grizzly.Database;
const QueryEngine = zig_grizzly.QueryEngine;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create database
    var db = try Database.init(allocator, "demo_db");
    defer db.deinit();

    // Create test table
    const schema_def = [_]zig_grizzly.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "age", .data_type = .int32 },
    };
    try db.createTable("users", &schema_def);

    // Insert some data
    const table = try db.getTable("users");
    try table.insertRow(&[_]zig_grizzly.Value{
        zig_grizzly.Value{ .int32 = 1 },
        zig_grizzly.Value{ .string = "Alice" },
        zig_grizzly.Value{ .int32 = 25 },
    });
    try table.insertRow(&[_]zig_grizzly.Value{
        zig_grizzly.Value{ .int32 = 2 },
        zig_grizzly.Value{ .string = "Bob" },
        zig_grizzly.Value{ .int32 = 30 },
    });

    // Create models with dependencies
    std.debug.print("Creating models...\n", .{});

    try db.createModel("active_users", "SELECT * FROM users WHERE age >= 18");
    try db.createModel("young_users", "SELECT * FROM active_users WHERE age < 30");
    try db.createModel("user_summary", "SELECT COUNT(*) as total, AVG(age) as avg_age FROM young_users");

    // Show dependency graph
    std.debug.print("\nDependency Graph (DOT format):\n", .{});
    const dot = try db.getDependencyGraphDot();
    defer allocator.free(dot);
    std.debug.print("{s}\n", .{dot});

    // Test REFRESH MODEL
    std.debug.print("\nRefreshing model 'user_summary'...\n", .{});

    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var refresh_result = try engine.execute("REFRESH MODEL user_summary;");
    defer refresh_result.deinit();

    switch (refresh_result) {
        .message => |msg| std.debug.print("Result: {s}\n", .{msg}),
        else => std.debug.print("Unexpected result type\n", .{}),
    }

    // Show lineage
    std.debug.print("\nShowing lineage for 'user_summary'...\n", .{});
    var lineage_result = try engine.execute("SHOW LINEAGE FOR MODEL user_summary;");
    defer lineage_result.deinit();

    switch (lineage_result) {
        .message => |msg| std.debug.print("{s}\n", .{msg}),
        else => std.debug.print("Unexpected result type\n", .{}),
    }

    // Show dependencies
    std.debug.print("\nShowing dependencies for 'young_users'...\n", .{});
    var deps_result = try engine.execute("SHOW DEPENDENCIES FOR MODEL young_users;");
    defer deps_result.deinit();

    switch (deps_result) {
        .message => |msg| std.debug.print("{s}\n", .{msg}),
        else => std.debug.print("Unexpected result type\n", .{}),
    }

    // Test column lineage (Phase 4)
    std.debug.print("\nTesting column lineage (Phase 4)...\n", .{});

    var col_lineage_result1 = try engine.execute("SHOW LINEAGE FOR COLUMN user_summary.total;");
    defer col_lineage_result1.deinit();
    switch (col_lineage_result1) {
        .message => |msg| std.debug.print("Column lineage for user_summary.total:\n{s}\n", .{msg}),
        else => std.debug.print("Unexpected result type\n", .{}),
    }

    var col_lineage_result2 = try engine.execute("SHOW LINEAGE FOR COLUMN user_summary.avg_age;");
    defer col_lineage_result2.deinit();
    switch (col_lineage_result2) {
        .message => |msg| std.debug.print("Column lineage for user_summary.avg_age:\n{s}\n", .{msg}),
        else => std.debug.print("Unexpected result type\n", .{}),
    }

    std.debug.print("\nPhase 4 - Column-Level Lineage implementation complete!\n", .{});
}
