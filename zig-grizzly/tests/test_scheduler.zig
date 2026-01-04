const std = @import("std");
const root = @import("src/root.zig");
const Database = root.Database;
const Scheduler = root.Scheduler;

test "scheduler basic functionality" {
    const allocator = std.testing.allocator;

    // Create database
    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create a simple table and model
    const schema_def = [_]root.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "value", .data_type = .int32 },
    };
    try db.createTable("test_table", &schema_def);

    // Insert some data
    const table = try db.getTable("test_table");
    var row1 = std.ArrayList(root.Value){};
    defer row1.deinit(allocator);
    try row1.append(allocator, root.Value{ .int32 = 1 });
    try row1.append(allocator, root.Value{ .int32 = 100 });
    try table.insertRow(row1.items);

    // Create a model
    try db.createModel("test_model", "SELECT * FROM test_table");

    // Create a schedule
    try db.createSchedule("daily_schedule", "test_model", "0 2 * * *", 3);

    // Check schedules
    const schedules = db.getSchedules();
    try std.testing.expectEqual(@as(usize, 1), schedules.len);
    try std.testing.expectEqualStrings("daily_schedule", schedules[0].id);
    try std.testing.expectEqualStrings("test_model", schedules[0].model_name);
    try std.testing.expectEqual(@as(u32, 3), schedules[0].max_retries);

    // Test manual execution
    try db.checkSchedules();

    // Drop schedule
    try db.dropSchedule("daily_schedule");
    try std.testing.expectEqual(@as(usize, 0), db.getSchedules().len);
}
