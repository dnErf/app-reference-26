const std = @import("std");
const database_mod = @import("src/database.zig");
const query_mod = @import("src/query.zig");

test "CREATE MODEL token recognition" {
    // Test that the MODEL keyword is properly recognized
    const sql = "CREATE MODEL test AS SELECT 1";
    var tokenizer = query_mod.Tokenizer.init(sql);

    // Skip CREATE
    _ = try tokenizer.next();
    // Check MODEL token
    const model_token = try tokenizer.next();
    try std.testing.expect(model_token.?.type == .model);
}

test "Database model registry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create database
    var db = try database_mod.Database.init(allocator, "test_db");
    defer db.deinit();

    // Test direct model creation
    try db.createModel("direct_model", "SELECT * FROM test_table");

    // Verify model exists
    const model = db.models.getModel("direct_model");
    try std.testing.expect(model != null);
    try std.testing.expect(std.mem.eql(u8, model.?.name, "direct_model"));
    try std.testing.expect(std.mem.eql(u8, model.?.sql_definition, "SELECT * FROM test_table"));
}

test "Model registry multiple models" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create database
    var db = try database_mod.Database.init(allocator, "test_db");
    defer db.deinit();

    // Create multiple models
    try db.createModel("model1", "SELECT 1");
    try db.createModel("model2", "SELECT 2");
    try db.createModel("model3", "SELECT 3");

    // Verify all models exist
    try std.testing.expect(db.models.getModel("model1") != null);
    try std.testing.expect(db.models.getModel("model2") != null);
    try std.testing.expect(db.models.getModel("model3") != null);

    // Verify non-existent model returns null
    try std.testing.expect(db.models.getModel("nonexistent") == null);
}

test "CREATE INCREMENTAL MODEL token recognition" {
    // Test that INCREMENTAL and PARTITION keywords are properly recognized
    const sql = "CREATE INCREMENTAL MODEL test PARTITION BY DATE(created_at) AS SELECT 1";
    var tokenizer = query_mod.Tokenizer.init(sql);

    // Skip CREATE
    _ = try tokenizer.next();
    // Check INCREMENTAL token
    const incremental_token = try tokenizer.next();
    try std.testing.expect(incremental_token.?.type == .incremental);

    // Skip MODEL
    _ = try tokenizer.next();
    // Skip identifier
    _ = try tokenizer.next();
    // Check PARTITION token
    const partition_token = try tokenizer.next();
    try std.testing.expect(partition_token.?.type == .partition);
}

test "Database incremental model creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create database
    var db = try database_mod.Database.init(allocator, "test_db");
    defer db.deinit();

    // Test incremental model creation
    try db.createIncrementalModel("incremental_model", "SELECT * FROM test_table", "created_at");

    // Verify model exists
    const model = db.models.getModel("incremental_model");
    try std.testing.expect(model != null);
    try std.testing.expect(std.mem.eql(u8, model.?.name, "incremental_model"));
    try std.testing.expect(std.mem.eql(u8, model.?.sql_definition, "SELECT * FROM test_table"));
    try std.testing.expect(model.?.is_incremental);
    try std.testing.expect(model.?.partition_column != null);
    try std.testing.expect(std.mem.eql(u8, model.?.partition_column.?, "created_at"));
}
