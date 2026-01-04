const std = @import("std");
const zig_grizzly = @import("zig_grizzly");
const Database = zig_grizzly.Database;
const QueryEngine = zig_grizzly.QueryEngine;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create database
    var db = try Database.init(allocator, "scheduler_demo");
    defer db.deinit();

    // Create query engine
    var query_engine = QueryEngine.init(allocator, &db, &db.functions);

    // Create a table
    var result1 = try query_engine.execute(
        \\CREATE TABLE events (
        \\  id INT,
        \\  user_id INT,
        \\  amount FLOAT,
        \\  created_at STRING
        \\);
    );
    defer result1.deinit();
    std.debug.print("{s}\n", .{result1.message});

    // Create an incremental model
    var result2 = try query_engine.execute(
        \\CREATE INCREMENTAL MODEL daily_revenue
        \\  PARTITION BY DATE(created_at)
        \\AS
        \\  SELECT
        \\    DATE(created_at) as date,
        \\    SUM(amount) as total_revenue,
        \\    COUNT(*) as event_count
        \\  FROM events;
    );
    defer result2.deinit();
    std.debug.print("{s}\n", .{result2.message});

    // Create a schedule
    var result3 = try query_engine.execute(
        \\CREATE SCHEDULE daily_refresh FOR MODEL daily_revenue
        \\  CRON '0 2 * * *'
        \\  ON FAILURE RETRY 3;
    );
    defer result3.deinit();
    std.debug.print("{s}\n", .{result3.message});

    // Show schedules
    var result4 = try query_engine.execute("SHOW SCHEDULES;");
    defer result4.deinit();
    std.debug.print("{s}\n", .{result4.message});

    // Manually trigger schedule execution
    try db.checkSchedules();

    // Drop schedule
    var result5 = try query_engine.execute("DROP SCHEDULE daily_refresh;");
    defer result5.deinit();
    std.debug.print("{s}\n", .{result5.message});

    std.debug.print("\nScheduler demo completed successfully!\n", .{});
}
