const std = @import("std");
const zig_grizzly = @import("zig_grizzly");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create database
    var db = try zig_grizzly.Database.init(allocator, "test_db");
    defer db.deinit();

    // Create query engine
    var query_engine = zig_grizzly.QueryEngine.init(allocator, &db, &db.functions);

    // Test CREATE FUNCTION
    const create_query = "CREATE FUNCTION test_func(x int64) RETURNS int64 { x }";
    var create_result = try query_engine.execute(create_query);
    defer create_result.deinit();

    std.debug.print("Create Result: {s}\n", .{create_result.message});

    // Test ATTACH SQL file (Sprint 17)
    const attach_query = "ATTACH 'test_functions.sql' AS mylib;";
    var attach_result = try query_engine.execute(attach_query);
    defer attach_result.deinit();

    std.debug.print("Attach Result: {s}\n", .{attach_result.message});

    // Test using the attached function
    const select_query = "SELECT greet('World') AS greeting";
    var select_result = try query_engine.execute(select_query);
    defer select_result.deinit();

    std.debug.print("Select Result: {s}\n", .{select_result.message});
}
