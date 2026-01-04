const std = @import("std");
const database_mod = @import("src/database.zig");
const query_mod = @import("src/query.zig");
const schema_mod = @import("src/schema.zig");
const types = @import("src/types.zig");

test "debug WHERE + ORDER BY" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try database_mod.Database.init(allocator, "test_db");
    defer db.deinit();

    try db.createTable("users", &[_]schema_mod.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "age", .data_type = .int32 },
    });

    var table = try db.getTable("users");
    try table.insertRow(&[_]types.Value{
        types.Value{ .int32 = 1 },
        types.Value{ .int32 = 25 },
    });
    try table.insertRow(&[_]types.Value{
        types.Value{ .int32 = 2 },
        types.Value{ .int32 = 35 },
    });

    var engine = query_mod.QueryEngine.init(allocator, &db);
    defer engine.deinit();

    // Test just WHERE first
    std.debug.print("\n=== Testing WHERE alone ===\n", .{});
    var result1 = try engine.execute("SELECT * FROM users WHERE age > 26;");
    defer result1.table.deinit();
    std.debug.print("WHERE alone result: {} rows\n", .{result1.table.row_count});

    // Test just ORDER BY
    std.debug.print("\n=== Testing ORDER BY alone ===\n", .{});
    var result2 = try engine.execute("SELECT * FROM users ORDER BY age ASC;");
    defer result2.table.deinit();
    std.debug.print("ORDER BY alone result: {} rows\n", .{result2.table.row_count});

    // Test WHERE + ORDER BY
    std.debug.print("\n=== Testing WHERE + ORDER BY ===\n", .{});
    var result3 = try engine.execute("SELECT * FROM users WHERE age > 26 ORDER BY age ASC;");
    defer result3.table.deinit();
    std.debug.print("WHERE + ORDER BY result: {} rows\n", .{result3.table.row_count});
}
