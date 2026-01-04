const std = @import("std");
const Database = @import("database.zig").Database;
const DependencyGraph = @import("dag.zig").DependencyGraph;
const DependencyAnalyzer = @import("dependency.zig").DependencyAnalyzer;

test "DAG node operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var graph = DependencyGraph.init(allocator);
    defer graph.deinit();

    // Add nodes
    try graph.addNode("model_a");
    try graph.addNode("model_b");
    try graph.addNode("model_c");

    // Add dependencies
    try graph.addDependency("model_b", "model_a"); // model_b depends on model_a
    try graph.addDependency("model_c", "model_b"); // model_c depends on model_b

    // Check dependencies
    const node_b = graph.getNode("model_b").?;
    try std.testing.expect(node_b.hasDependency("model_a"));
    try std.testing.expect(!node_b.hasDependency("model_c"));

    const node_c = graph.getNode("model_c").?;
    try std.testing.expect(node_c.hasDependency("model_b"));
}

test "DAG topological sort" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var graph = DependencyGraph.init(allocator);
    defer graph.deinit();

    // Add nodes
    try graph.addNode("base_table");
    try graph.addNode("model_a");
    try graph.addNode("model_b");
    try graph.addNode("model_c");

    // Add dependencies: model_c -> model_b -> model_a -> base_table
    try graph.addDependency("model_a", "base_table");
    try graph.addDependency("model_b", "model_a");
    try graph.addDependency("model_c", "model_b");

    // Get topological sort
    const order = try graph.topologicalSort(allocator);
    defer allocator.free(order);

    // Verify order: base_table, model_a, model_b, model_c
    try std.testing.expectEqual(@as(usize, 4), order.len);
    try std.testing.expect(std.mem.eql(u8, order[0], "base_table"));
    try std.testing.expect(std.mem.eql(u8, order[1], "model_a"));
    try std.testing.expect(std.mem.eql(u8, order[2], "model_b"));
    try std.testing.expect(std.mem.eql(u8, order[3], "model_c"));
}

test "DAG cycle detection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var graph = DependencyGraph.init(allocator);
    defer graph.deinit();

    // Add nodes
    try graph.addNode("model_a");
    try graph.addNode("model_b");
    try graph.addNode("model_c");

    // Create a cycle: a -> b -> c -> a
    try graph.addDependency("model_a", "model_c");
    try graph.addDependency("model_b", "model_a");
    try graph.addDependency("model_c", "model_b");

    // Should detect cycle
    try std.testing.expect(try graph.hasCycles());
}

test "Dependency analyzer" {
    var analyzer = DependencyAnalyzer.init(std.heap.page_allocator);

    // Test SQL with table reference
    const sql = "SELECT * FROM users WHERE id > 10";
    var deps = try analyzer.extractDependencies(sql, undefined);
    defer {
        var it = deps.iterator();
        while (it.next()) |entry| {
            std.heap.page_allocator.free(entry.key_ptr.*);
        }
        deps.deinit();
    }

    try std.testing.expect(deps.contains("users"));
}

test "Model dependency graph building" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create test table
    const schema_def = [_]@import("schema.zig").Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };
    try db.createTable("users", &schema_def);

    // Create models
    try db.createModel("model_a", "SELECT * FROM users");
    try db.createModel("model_b", "SELECT * FROM model_a WHERE id > 10");
    try db.createModel("model_c", "SELECT COUNT(*) FROM model_b");

    var analyzer = DependencyAnalyzer.init(allocator);
    var model_deps = try analyzer.buildModelDependencyGraph(&db);
    defer {
        var it = model_deps.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        model_deps.deinit();
    }

    // Check dependencies
    const model_b_deps = model_deps.get("model_b").?;
    try std.testing.expectEqual(@as(usize, 1), model_b_deps.items.len);
    try std.testing.expect(std.mem.eql(u8, model_b_deps.items[0], "model_a"));

    const model_c_deps = model_deps.get("model_c").?;
    try std.testing.expectEqual(@as(usize, 1), model_c_deps.items.len);
    try std.testing.expect(std.mem.eql(u8, model_c_deps.items[0], "model_b"));
}

test "Database dependency graph integration" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create test table
    const schema_def = [_]@import("schema.zig").Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };
    try db.createTable("users", &schema_def);

    // Create models
    try db.createModel("model_a", "SELECT * FROM users");
    try db.createModel("model_b", "SELECT * FROM model_a WHERE id > 10");

    // Check that dependency graph was built
    const node_a = db.dependency_graph.getNode("model_a");
    try std.testing.expect(node_a != null);

    const node_b = db.dependency_graph.getNode("model_b");
    try std.testing.expect(node_b != null);
    try std.testing.expect(node_b.?.hasDependency("model_a"));
}
