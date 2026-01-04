const std = @import("std");
const grizzly = @import("zig_grizzly");

const Database = grizzly.Database;
const QueryEngine = grizzly.QueryEngine;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Creating database...\n", .{});

    // Create database
    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    std.debug.print("Creating function registry...\n", .{});

    // Create function registry
    var function_registry = grizzly.FunctionRegistry.init(allocator);
    defer function_registry.deinit();

    std.debug.print("Creating query engine...\n", .{});

    // Create query engine
    var query_engine = QueryEngine.init(allocator, &db, &function_registry);

    std.debug.print("Testing ATTACH SQL...\n", .{});

    // Test ATTACH SQL
    _ = try query_engine.execute("ATTACH 'test_functions.sql' AS mylib;");
    std.debug.print("ATTACH completed\n", .{});

    // Note: SELECT queries are not implemented yet
    // const result2 = try query_engine.execute("SELECT greet('World');");
    // std.debug.print("SELECT Result: {s}\n", .{result2.message});
}
