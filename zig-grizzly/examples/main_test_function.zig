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
    const query = "CREATE FUNCTION test_func(x int64) RETURNS int64 { x }";
    var result = try query_engine.execute(query);
    defer result.deinit();

    std.debug.print("Result: {s}\n", .{result.message});
}
