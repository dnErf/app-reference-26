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

    // Test CREATE FUNCTION with pipes (basic test)
    const query = "CREATE FUNCTION test_pipe(x int64) RETURNS int64 { x }";
    var result = try query_engine.execute(query);
    defer result.deinit();

    std.debug.print("Function created: {s}\n", .{result.message});

    // Test calling the function
    const call_query = "SELECT test_pipe(42) as result";
    var call_result = try query_engine.execute(call_query);
    defer call_result.deinit();

    std.debug.print("Function call result type: {}\n", .{call_result});
    if (call_result == .table) {
        std.debug.print("Table has {} rows, {} columns\n", .{ call_result.table.row_count, call_result.table.schema.columns.len });
        if (call_result.table.row_count > 0) {
            // Get the first row, first column
            var value = try call_result.table.getCell(0, 0);
            defer value.deinit(call_result.table.allocator);
            std.debug.print("Result value: {any}\n", .{value});
        }
    } else {
        std.debug.print("Function call result: {s}\n", .{call_result.message});
    }
}
