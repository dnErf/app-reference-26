const std = @import("std");
const test_mod = @import("../src/test.zig");
const database_mod = @import("../src/database.zig");
const query_mod = @import("../src/query.zig");

test "TestEngine not_null test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create database and table with some test data
    var db = try database_mod.Database.init(allocator, "test_db");
    defer db.deinit();

    // Create a table with some null values
    try db.executeSQL("CREATE TABLE test_table (id INTEGER, name TEXT, value INTEGER);");
    try db.executeSQL("INSERT INTO test_table VALUES (1, 'Alice', 100);");
    try db.executeSQL("INSERT INTO test_table VALUES (2, NULL, 200);");
    try db.executeSQL("INSERT INTO test_table VALUES (3, 'Charlie', NULL);");

    // Create test engine
    var test_engine = test_mod.TestEngine.init(allocator, &db);

    // Create a not_null test
    const test_def = test_mod.TestEngine.TestDefinition{
        .name = "name_not_null",
        .model_name = "test_table",
        .test_type = .not_null,
        .config = .{ .not_null = .{ .column = "name" } },
    };

    // Run the test
    const result = try test_engine.runTest(test_def);
    defer result.deinit(allocator);

    // Should fail because there's a NULL in the name column
    try std.testing.expect(!result.passed);
    try std.testing.expectEqual(@as(u64, 1), result.failure_count);
    try std.testing.expect(result.error_message != null);
    try std.testing.expect(std.mem.indexOf(u8, result.error_message.?, "null values") != null);
}

test "TestEngine unique test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create database and table
    var db = try database_mod.Database.init(allocator, "test_db");
    defer db.deinit();

    try db.executeSQL("CREATE TABLE test_table (id INTEGER, category TEXT);");
    try db.executeSQL("INSERT INTO test_table VALUES (1, 'A');");
    try db.executeSQL("INSERT INTO test_table VALUES (2, 'A');");
    try db.executeSQL("INSERT INTO test_table VALUES (3, 'B');");

    // Create test engine
    var test_engine = test_mod.TestEngine.init(allocator, &db);

    // Create a unique test on category
    const columns = try allocator.dupe([]const u8, &[_][]const u8{"category"});
    defer allocator.free(columns);

    const test_def = test_mod.TestEngine.TestDefinition{
        .name = "category_unique",
        .model_name = "test_table",
        .test_type = .unique,
        .config = .{ .unique = .{ .columns = columns } },
    };

    // Run the test
    const result = try test_engine.runTest(test_def);
    defer result.deinit(allocator);

    // Should fail because 'A' appears twice
    try std.testing.expect(!result.passed);
    try std.testing.expectEqual(@as(u64, 1), result.failure_count);
}

test "TestEngine accepted_values test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create database and table
    var db = try database_mod.Database.init(allocator, "test_db");
    defer db.deinit();

    try db.executeSQL("CREATE TABLE test_table (status TEXT);");
    try db.executeSQL("INSERT INTO test_table VALUES ('active');");
    try db.executeSQL("INSERT INTO test_table VALUES ('inactive');");
    try db.executeSQL("INSERT INTO test_table VALUES ('pending');");

    // Create test engine
    var test_engine = test_mod.TestEngine.init(allocator, &db);

    // Create accepted_values test
    const values = try allocator.dupe(@import("../src/types.zig").Value, &[_]@import("../src/types.zig").Value{
        .{ .string = "active" },
        .{ .string = "inactive" },
    });
    defer allocator.free(values);

    const test_def = test_mod.TestEngine.TestDefinition{
        .name = "status_accepted",
        .model_name = "test_table",
        .test_type = .accepted_values,
        .config = .{ .accepted_values = .{
            .column = "status",
            .values = values,
        } },
    };

    // Run the test
    const result = try test_engine.runTest(test_def);
    defer result.deinit(allocator);

    // Should fail because 'pending' is not in accepted values
    try std.testing.expect(!result.passed);
    try std.testing.expectEqual(@as(u64, 1), result.failure_count);
}
