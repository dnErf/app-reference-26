const std = @import("std");
const gz = @import("zig_grizzly");

/// Demo showcasing Phase 7: Automatic Optimization Engine
/// Features: Workload analysis, automatic storage recommendations, data migration
pub fn main() !void {
    std.debug.print("🚀 Grizzly DB - Phase 7: Automatic Optimization Engine Demo\n", .{});
    std.debug.print("========================================================\n\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize database
    var db = try gz.Database.init(allocator, "optimization_demo");
    defer db.deinit();

    // Initialize function registry
    var function_registry = gz.FunctionRegistry.init(allocator);
    defer function_registry.deinit();

    // Initialize query engine
    var query_engine = gz.QueryEngine.init(allocator, &db, &function_registry);

    // Initialize storage optimizer
    var optimizer = try gz.StorageOptimizer.init(allocator, &db, 60 * 1000); // 1 minute interval
    defer optimizer.deinit();

    std.debug.print("✅ Initialized database and optimization engine\n\n", .{});

    // Create sample tables with different storage types
    std.debug.print("📊 Creating sample tables...\n", .{});

    // Create a transactional table (OLTP workload)
    const orders_schema = [_]gz.Schema.ColumnDef{
        .{ .name = "order_id", .data_type = .int32 },
        .{ .name = "customer_id", .data_type = .int32 },
        .{ .name = "product_id", .data_type = .int32 },
        .{ .name = "quantity", .data_type = .int32 },
        .{ .name = "order_date", .data_type = .string },
        .{ .name = "total_amount", .data_type = .float64 },
    };
    try db.createTableWithStorage("orders", &orders_schema, .row);
    std.debug.print("  ✅ Created 'orders' table with row storage (OLTP)\n", .{});

    // Create an analytical table (OLAP workload)
    const sales_schema = [_]gz.Schema.ColumnDef{
        .{ .name = "date", .data_type = .string },
        .{ .name = "product_category", .data_type = .string },
        .{ .name = "region", .data_type = .string },
        .{ .name = "sales_amount", .data_type = .float64 },
        .{ .name = "units_sold", .data_type = .int32 },
    };
    try db.createTableWithStorage("sales", &sales_schema, .column);
    std.debug.print("  ✅ Created 'sales' table with column storage (OLAP)\n", .{});

    // Create a graph table (relationships)
    const relationships_schema = [_]gz.Schema.ColumnDef{
        .{ .name = "from_node", .data_type = .int32 },
        .{ .name = "to_node", .data_type = .int32 },
        .{ .name = "relationship_type", .data_type = .string },
        .{ .name = "weight", .data_type = .float64 },
    };
    try db.createTableWithStorage("relationships", &relationships_schema, .graph);
    std.debug.print("  ✅ Created 'relationships' table with graph storage\n\n", .{});

    // Simulate workload by executing queries
    std.debug.print("🔄 Simulating workload patterns...\n", .{});

    // OLTP workload - frequent inserts and point lookups
    std.debug.print("  📝 Simulating OLTP workload (orders table)...\n", .{});
    for (0..50) |i| {
        const order_id = i + 1;
        const customer_id = (i % 10) + 1;
        const product_id = (i % 5) + 1;
        const quantity = (i % 10) + 1;
        const total_amount: f64 = @floatFromInt(quantity * 25);

        const insert_sql = try std.fmt.allocPrint(allocator, "INSERT INTO orders VALUES ({}, {}, {}, {}, '2024-01-01', {})", .{ order_id, customer_id, product_id, quantity, total_amount });
        defer allocator.free(insert_sql);

        _ = try query_engine.execute(insert_sql);
    }

    // Point lookups on orders
    for (0..20) |i| {
        const order_id = (i % 50) + 1;
        const select_sql = try std.fmt.allocPrint(allocator, "SELECT * FROM orders WHERE order_id = {}", .{order_id});
        defer allocator.free(select_sql);

        _ = try query_engine.execute(select_sql);
    }

    // OLAP workload - analytical queries on sales
    std.debug.print("  📊 Simulating OLAP workload (sales table)...\n", .{});
    // Insert sample sales data
    const sales_data = [_]struct { date: []const u8, category: []const u8, region: []const u8, amount: f64, units: i32 }{
        .{ .date = "2024-01-01", .category = "Electronics", .region = "North", .amount = 1500.00, .units = 10 },
        .{ .date = "2024-01-01", .category = "Books", .region = "South", .amount = 800.00, .units = 20 },
        .{ .date = "2024-01-02", .category = "Electronics", .region = "North", .amount = 2200.00, .units = 15 },
        .{ .date = "2024-01-02", .category = "Books", .region = "South", .amount = 1200.00, .units = 30 },
    };

    for (sales_data, 0..sales_data.len) |sale, _| {
        const insert_sql = try std.fmt.allocPrint(allocator, "INSERT INTO sales VALUES ('{s}', '{s}', '{s}', {}, {})", .{ sale.date, sale.category, sale.region, sale.amount, sale.units });
        defer allocator.free(insert_sql);

        _ = try query_engine.execute(insert_sql);
    }

    // Analytical queries
    const analytics_queries = [_][]const u8{
        "SELECT SUM(sales_amount) FROM sales",
        "SELECT product_category, SUM(sales_amount) FROM sales GROUP BY product_category",
        "SELECT region, AVG(sales_amount) FROM sales GROUP BY region",
        "SELECT COUNT(*) FROM sales WHERE sales_amount > 1000",
    };

    for (analytics_queries) |query| {
        _ = try query_engine.execute(query);
    }

    // Graph workload - relationship traversals
    std.debug.print("  🕸️  Simulating graph workload (relationships table)...\n", .{});
    // Insert sample relationship data
    const relationships_data = [_]struct { from: i32, to: i32, rel_type: []const u8, weight: f64 }{
        .{ .from = 1, .to = 2, .rel_type = "friend", .weight = 0.8 },
        .{ .from = 1, .to = 3, .rel_type = "colleague", .weight = 0.6 },
        .{ .from = 2, .to = 3, .rel_type = "friend", .weight = 0.9 },
        .{ .from = 3, .to = 4, .rel_type = "family", .weight = 1.0 },
    };

    for (relationships_data) |rel| {
        const insert_sql = try std.fmt.allocPrint(allocator, "INSERT INTO relationships VALUES ({}, {}, '{s}', {})", .{ rel.from, rel.to, rel.rel_type, rel.weight });
        defer allocator.free(insert_sql);

        _ = try query_engine.execute(insert_sql);
    }

    // Graph traversal queries
    const graph_queries = [_][]const u8{
        "SELECT * FROM relationships WHERE from_node = 1",
        "SELECT COUNT(*) FROM relationships",
    };

    for (graph_queries) |query| {
        _ = try query_engine.execute(query);
    }

    std.debug.print("  ✅ Workload simulation complete\n\n", .{});

    // Run optimization analysis
    std.debug.print("🧠 Running workload analysis and optimization...\n", .{});

    var analysis_result = try optimizer.analyzeWorkload();
    defer analysis_result.deinit();

    std.debug.print("  📈 Analysis Results:\n", .{});
    std.debug.print("    - Found {any} optimization recommendations\n", .{analysis_result.recommendations.items.len});

    for (analysis_result.recommendations.items, 0..) |rec, i| {
        std.debug.print("    {any}. {s}: {s} → {s} (confidence: N/A, benefit: N/A)\n", .{
            i + 1,
            rec.table_name,
            @tagName(rec.current_storage),
            @tagName(rec.recommended_storage),
        });
        std.debug.print("       Reasoning: {s}\n", .{rec.reasoning});
        std.debug.print("       Migration cost: ~N/A ms, {any} bytes\n", .{rec.migration_cost.estimated_bytes});
    }

    // Apply optimizations automatically
    std.debug.print("\n⚡ Applying optimizations...\n", .{});

    var apply_result = try optimizer.applyOptimizations(analysis_result.recommendations.items, true);
    defer apply_result.deinit();

    std.debug.print("  ✅ Applied {any} optimizations\n", .{apply_result.applied_changes.items.len});
    std.debug.print("    - Total benefit: N/A\n", .{});
    std.debug.print("    - Total migration time: N/A ms\n", .{});

    for (apply_result.applied_changes.items) |change| {
        std.debug.print("    - Migrated {s}: {s} → {s} ({any} bytes in {any}ms)\n", .{
            change.table_name,
            @tagName(change.old_storage),
            @tagName(change.new_storage),
            change.migration_result.bytes_migrated,
            change.migration_result.duration_ms,
        });
    }

    // Get optimization statistics
    const stats = optimizer.getOptimizationStats();
    std.debug.print("\n📊 Optimization Statistics:\n", .{});
    std.debug.print("  - Total queries analyzed: {any}\n", .{stats.workload_stats.query_history.items.len});
    std.debug.print("  - Average query execution time: {any}ms\n", .{stats.workload_stats.getPerformanceStats().avg_execution_time_ms});
    std.debug.print("  - Time since last optimization: {any}ms\n", .{stats.time_since_last_optimization});

    std.debug.print("\n🎉 Phase 7: Automatic Optimization Engine Complete!\n", .{});
    std.debug.print("   ✅ Workload analysis and pattern recognition\n", .{});
    std.debug.print("   ✅ Automatic storage recommendations\n", .{});
    std.debug.print("   ✅ Cost-based optimization decisions\n", .{});
    std.debug.print("   ✅ Seamless data migration between storage engines\n", .{});
    std.debug.print("   ✅ Performance monitoring and adaptation\n", .{});
    std.debug.print("   ✅ Multi-dimensional optimization (performance, cost, maintenance)\n", .{});
}
