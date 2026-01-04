const std = @import("std");
const grizzly = @import("src/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new empty database
    var db = try grizzly.Database.init(allocator, "load_test_db");
    defer db.deinit();

    // Create query engine
    var engine = grizzly.QueryEngine.init(allocator, &db);
    defer engine.deinit();

    // Test LOAD DATABASE
    const result = try engine.execute("LOAD DATABASE FROM 'test_save_lz4.griz';");

    std.debug.print("Result: {s}\n", .{result.message});

    // Check if the loaded database has the table
    if (db.tables.get("users")) |table| {
        std.debug.print("✅ Table 'users' found with {d} rows\n", .{table.row_count});
        std.debug.print("Columns: ", .{});
        for (table.schema.columns) |col| {
            std.debug.print("{s} ", .{col.name});
        }
        std.debug.print("\n", .{});
    } else {
        std.debug.print("❌ Table 'users' not found\n", .{});
    }

    // Try a query on the loaded data
    const query_result = try engine.execute("SELECT * FROM users;");
    switch (query_result) {
        .table => |*table| {
            std.debug.print("Query returned table with {d} rows\n", .{table.row_count});
            @constCast(table).deinit();
        },
        .message => |msg| {
            std.debug.print("Query result: {s}\n", .{msg});
        },
    }
}
