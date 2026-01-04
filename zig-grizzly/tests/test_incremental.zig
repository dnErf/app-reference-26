const std = @import("std");
const Database = @import("src/database.zig").Database;
const Value = @import("src/types.zig").Value;
const IncrementalEngine = @import("src/incremental.zig").IncrementalEngine;
const IncrementalState = @import("src/incremental.zig").IncrementalState;

test "incremental model execution" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create a base table with events
    const schema_def = [_]@import("src/schema.zig").Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "created_at", .data_type = .timestamp },
        .{ .name = "amount", .data_type = .float64 },
    };

    try db.createTable("events", &schema_def);

    const table = try db.getTable("events");

    // Insert some test data
    const now = std.time.milliTimestamp();
    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .timestamp = now - 2000 },
        Value{ .float64 = 100.0 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .timestamp = now - 1000 },
        Value{ .float64 = 200.0 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 3 },
        Value{ .timestamp = now },
        Value{ .float64 = 300.0 },
    });

    // Create an incremental model
    const sql =
        \\CREATE INCREMENTAL MODEL daily_metrics
        \\PARTITION BY created_at
        \\AS
        \\SELECT
        \\  created_at,
        \\  COUNT(*) as event_count,
        \\  SUM(amount) as total_amount
        \\FROM events
        \\GROUP BY created_at
    ;

    var engine = @import("src/query.zig").QueryEngine.init(allocator, &db);
    defer engine.deinit();

    const result = try engine.execute(sql);
    try std.testing.expect(std.mem.eql(u8, result.message, "Incremental model created successfully"));

    // First execution should process all data
    const model_result1 = try db.models.executeModel("daily_metrics", &db);
    try std.testing.expectEqual(@as(usize, 3), model_result1.row_count);

    // Second execution should process only new data (none in this case)
    const model_result2 = try db.models.executeModel("daily_metrics", &db);
    try std.testing.expectEqual(@as(usize, 0), model_result2.row_count); // No new data

    // Add more data with newer timestamp
    try table.insertRow(&[_]Value{
        Value{ .int32 = 4 },
        Value{ .timestamp = now + 1000 },
        Value{ .float64 = 400.0 },
    });

    // Third execution should process the new data
    const model_result3 = try db.models.executeModel("daily_metrics", &db);
    try std.testing.expectEqual(@as(usize, 1), model_result3.row_count);
}

test "incremental state persistence" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create an incremental model
    try db.createIncrementalModel("test_model", "SELECT 1 as id", "id");

    // Get the model and set some state
    const model_ptr = db.models.models.getPtr("test_model").?;
    model_ptr.last_partition_value = Value{ .int64 = 100 };
    model_ptr.last_run = 123456789;

    // Save state
    try db.saveIncrementalState("test_states");

    // Create new database and load state
    var db2 = try Database.init(allocator, "test_db2");
    defer db2.deinit();

    try db2.createIncrementalModel("test_model", "SELECT 1 as id", "id");
    try db2.loadIncrementalState("test_states");

    // Check that state was loaded
    const loaded_model = db2.models.models.get("test_model").?;
    try std.testing.expect(loaded_model.last_run != null);
    try std.testing.expectEqual(@as(i64, 123456789), loaded_model.last_run.?);

    if (loaded_model.last_partition_value) |val| {
        try std.testing.expectEqual(@as(i64, 100), val.int64);
    } else {
        try std.testing.expect(false); // Should have loaded the value
    }

    // Clean up
    std.fs.cwd().deleteFile("test_states/test_model.state.json") catch {};
    std.fs.cwd().deleteDir("test_states") catch {};
}

test "incremental SQL generation" {
    const allocator = std.testing.allocator;

    var engine = IncrementalEngine.init(allocator);

    // Create a mock model
    var model = @import("src/model.zig").Model{
        .name = "test",
        .sql_definition = "SELECT * FROM events WHERE status = 'active' ORDER BY id",
        .dependencies = std.ArrayListUnmanaged([]const u8){},
        .last_run = null,
        .row_count = null,
        .execution_time_ms = null,
        .is_incremental = true,
        .partition_column = "created_at",
        .last_partition_value = Value{ .int64 = 100 },
        .materialized_result = null,
    };
    defer model.deinit(allocator);

    // Generate incremental SQL
    const incremental_sql = try engine.generateIncrementalSQL(&model, allocator);
    defer allocator.free(incremental_sql);

    // Should have added WHERE clause
    try std.testing.expect(std.mem.indexOf(u8, incremental_sql, "WHERE") != null);
    try std.testing.expect(std.mem.indexOf(u8, incremental_sql, "created_at > 100") != null);
    try std.testing.expect(std.mem.indexOf(u8, incremental_sql, "ORDER BY id") != null);
}
