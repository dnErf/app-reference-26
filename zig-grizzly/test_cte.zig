const std = @import("std");
const zig_grizzly = @import("src/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create database
    var db = try zig_grizzly.Database.init(allocator, "test_db");
    defer db.deinit();

    // Create a test table
    try db.createTable("users", &[_]zig_grizzly.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int64 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "age", .data_type = .int32 },
    });

    // Insert some test data
    const users_table = try db.getTable("users");
    var row1 = [_]zig_grizzly.Value{
        zig_grizzly.Value{ .int64 = 1 },
        zig_grizzly.Value{ .string = "Alice" },
        zig_grizzly.Value{ .int32 = 25 },
    };
    try users_table.insertRow(&row1);

    var row2 = [_]zig_grizzly.Value{
        zig_grizzly.Value{ .int64 = 2 },
        zig_grizzly.Value{ .string = "Bob" },
        zig_grizzly.Value{ .int32 = 30 },
    };
    try users_table.insertRow(&row2);

    // Test CTE query
    var query_engine = zig_grizzly.QueryEngine.init(allocator, &db);
    defer query_engine.deinit();

    const cte_query = "WITH adult_users AS (SELECT id, name FROM users) SELECT id, name FROM adult_users";

    var result = try query_engine.execute(cte_query);
    defer result.deinit();

    switch (result) {
        .table => |table| {
            std.debug.print("CTE query successful! Result has {} rows\n", .{table.row_count});
            if (table.row_count > 0) {
                std.debug.print("First row: ", .{});
                for (0..table.columns.len) |col| {
                    const cell = try table.getCell(0, col);
                    switch (cell) {
                        .int64 => |v| std.debug.print("{}", .{v}),
                        .string => |v| std.debug.print("{s}", .{v}),
                        else => std.debug.print("?", .{}),
                    }
                    if (col < table.columns.len - 1) std.debug.print(", ", .{});
                }
                std.debug.print("\n", .{});
            }
        },
        .message => |msg| {
            std.debug.print("CTE query returned message: {s}\n", .{msg});
        },
    }
}
