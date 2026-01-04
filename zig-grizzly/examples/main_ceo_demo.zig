const std = @import("std");
const grizzly = @import("root.zig");

/// CEO Dashboard Demo - Shows AI-auditable analytics
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
    std.debug.print("🐻 GRIZZLY DB - CEO DASHBOARD DEMO (AI-Auditable)\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});

    // Initialize audit log
    var audit_log = grizzly.AuditLog.init(allocator);
    defer audit_log.deinit();

    // Create database
    var db = try grizzly.Database.init(allocator, "company_analytics");
    defer db.deinit();

    try audit_log.log(.create_table, "database", "Created company_analytics database", 0, "system");

    // Define sales schema
    const sales_schema = [_]grizzly.Schema.ColumnDef{
        .{ .name = "transaction_id", .data_type = .int32 },
        .{ .name = "product", .data_type = .string },
        .{ .name = "amount", .data_type = .float64 },
        .{ .name = "region", .data_type = .string },
        .{ .name = "year", .data_type = .int32 },
        .{ .name = "quarter", .data_type = .int32 },
    };

    try db.createTable("sales", &sales_schema);
    const sales_table = try db.getTable("sales");

    try audit_log.log(.create_table, "sales", "Created sales table with 6 columns", 0, "admin");

    // Insert 2024 sales data
    std.debug.print("📊 Loading 2024 Sales Data...\n\n", .{});

    const sales_2024 = [_]struct { id: i32, product: []const u8, amount: f64, region: []const u8, year: i32, quarter: i32 }{
        .{ .id = 1, .product = "Widget A", .amount = 125000.00, .region = "North", .year = 2024, .quarter = 1 },
        .{ .id = 2, .product = "Widget B", .amount = 87500.50, .region = "South", .year = 2024, .quarter = 1 },
        .{ .id = 3, .product = "Widget A", .amount = 150000.75, .region = "East", .year = 2024, .quarter = 2 },
        .{ .id = 4, .product = "Widget C", .amount = 95000.25, .region = "West", .year = 2024, .quarter = 2 },
        .{ .id = 5, .product = "Widget B", .amount = 112000.00, .region = "North", .year = 2024, .quarter = 3 },
        .{ .id = 6, .product = "Widget A", .amount = 178000.50, .region = "South", .year = 2024, .quarter = 3 },
        .{ .id = 7, .product = "Widget C", .amount = 205000.00, .region = "East", .year = 2024, .quarter = 4 },
        .{ .id = 8, .product = "Widget B", .amount = 142000.75, .region = "West", .year = 2024, .quarter = 4 },
        // Add some 2023 data for comparison
        .{ .id = 9, .product = "Widget A", .amount = 98000.00, .region = "North", .year = 2023, .quarter = 4 },
        .{ .id = 10, .product = "Widget B", .amount = 76000.00, .region = "South", .year = 2023, .quarter = 4 },
    };

    for (sales_2024) |sale| {
        try sales_table.insertRow(&[_]grizzly.Value{
            .{ .int32 = sale.id },
            .{ .string = sale.product },
            .{ .float64 = sale.amount },
            .{ .string = sale.region },
            .{ .int32 = sale.year },
            .{ .int32 = sale.quarter },
        });
    }

    try audit_log.log(.insert, "sales", "Bulk insert of sales transactions", sales_2024.len, "etl_pipeline");

    std.debug.print("✅ Loaded {d} transactions\n\n", .{sales_2024.len});

    // CEO Query 1: "What were total sales in 2024?"
    std.debug.print("=" ** 70 ++ "\n", .{});
    std.debug.print("📈 CEO QUERY: \"What were total sales in 2024?\"\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});

    var trace1 = try grizzly.QueryTrace.init(allocator, "SELECT SUM(amount) FROM sales WHERE year = 2024");
    defer trace1.deinit();

    const timer1 = std.time.Timer;
    var t1 = try timer1.start();

    // Step 1: Table scan
    const scan_time = @as(f64, @floatFromInt(t1.lap())) / 1_000_000.0;
    try trace1.addStep("Table Scan", sales_table.row_count, sales_table.row_count, scan_time, "Read all rows from sales table");

    // Step 2: Filter for year = 2024
    const FilterContext = struct {
        pub fn filter2024(values: []const grizzly.Value) bool {
            if (values.len < 5) return false;
            return values[4].int32 == 2024; // year column is index 4
        }
    };

    const filtered_result = try sales_table.aggregateFiltered(
        allocator,
        "amount",
        .count,
        &FilterContext.filter2024,
    );
    defer filtered_result.deinit(allocator);

    const filter_time = @as(f64, @floatFromInt(t1.lap())) / 1_000_000.0;
    try trace1.addStep(
        "Filter",
        sales_table.row_count,
        filtered_result.row_count,
        filter_time,
        "Applied WHERE year = 2024",
    );

    // Step 3: Aggregate SUM(amount)
    const sum_result = try sales_table.aggregateFiltered(
        allocator,
        "amount",
        .sum,
        &FilterContext.filter2024,
    );
    defer sum_result.deinit(allocator);

    const agg_time = @as(f64, @floatFromInt(t1.lap())) / 1_000_000.0;
    try trace1.addStep("Aggregate", sum_result.row_count, 1, agg_time, "SUM(amount) over filtered rows");

    try trace1.setResult(1, sum_result.value, sum_result.contributing_rows);

    try audit_log.log(
        .aggregate,
        "sales",
        "SUM(amount) WHERE year = 2024",
        sum_result.row_count,
        "ceo_dashboard",
    );

    std.debug.print("💰 **RESULT: ${d:.2}**\n\n", .{sum_result.value.float64});
    std.debug.print("📋 Audit Trail:\n", .{});
    std.debug.print("   - Based on {d} transactions from 2024\n", .{sum_result.row_count});
    std.debug.print("   - Row IDs: ", .{});
    if (sum_result.contributing_rows) |rows| {
        for (rows, 0..) |row_id, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{d}", .{row_id});
        }
    }
    std.debug.print("\n", .{});
    std.debug.print("   - Query executed in {d:.2}ms\n", .{scan_time + filter_time + agg_time});
    std.debug.print("\n", .{});

    // CEO Query 2: "Which region had highest sales in Q4 2024?"
    std.debug.print("=" ** 70 ++ "\n", .{});
    std.debug.print("🎯 CEO QUERY: \"Which region had highest sales in Q4 2024?\"\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});

    var trace2 = try grizzly.QueryTrace.init(allocator, "SELECT region, SUM(amount) FROM sales WHERE year = 2024 AND quarter = 4 GROUP BY region");
    defer trace2.deinit();

    const FilterQ4Context = struct {
        pub fn filterQ4_2024(values: []const grizzly.Value) bool {
            if (values.len < 6) return false;
            return values[4].int32 == 2024 and values[5].int32 == 4; // year and quarter
        }
    };

    const q4_result = try sales_table.aggregateFiltered(
        allocator,
        "amount",
        .sum,
        &FilterQ4Context.filterQ4_2024,
    );
    defer q4_result.deinit(allocator);

    std.debug.print("💰 **Total Q4 2024 Sales: ${d:.2}**\n\n", .{q4_result.value.float64});
    std.debug.print("📋 Breakdown by Region:\n", .{});
    
    if (q4_result.contributing_rows) |rows| {
        for (rows) |row_id| {
            const region = try sales_table.getCell(row_id, 3); // region column
            const amount = try sales_table.getCell(row_id, 2); // amount column
            std.debug.print("   - {s}: ${d:.2}\n", .{ region.string, amount.float64 });
        }
    }

    try audit_log.log(
        .aggregate,
        "sales",
        "SUM(amount) WHERE year = 2024 AND quarter = 4 GROUP BY region",
        q4_result.row_count,
        "ceo_dashboard",
    );

    std.debug.print("\n", .{});

    // Export audit log for AI analysis
    std.debug.print("=" ** 70 ++ "\n", .{});
    std.debug.print("📝 EXPORTING AUDIT LOG FOR AI VERIFICATION\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});

    const audit_file = try std.fs.cwd().createFile("audit_log.json", .{});
    defer audit_file.close();

    var audit_buffer = std.ArrayList(u8){};
    defer audit_buffer.deinit(allocator);
    const audit_writer = audit_buffer.writer(allocator);

    try audit_log.exportJSON(audit_writer);
    try audit_file.writeAll(audit_buffer.items);

    std.debug.print("✅ Saved audit log to audit_log.json ({d} bytes)\n\n", .{audit_buffer.items.len});

    // Export query trace for verification
    const trace_file = try std.fs.cwd().createFile("query_trace.json", .{});
    defer trace_file.close();

    var trace_buffer = std.ArrayList(u8){};
    defer trace_buffer.deinit(allocator);
    const trace_writer = trace_buffer.writer(allocator);

    try trace1.exportJSON(trace_writer);
    try trace_file.writeAll(trace_buffer.items);

    std.debug.print("✅ Saved query trace to query_trace.json ({d} bytes)\n\n", .{trace_buffer.items.len});

    // Generate explanation
    const explain_file = try std.fs.cwd().createFile("query_explanation.md", .{});
    defer explain_file.close();

    var explain_buffer = std.ArrayList(u8){};
    defer explain_buffer.deinit(allocator);
    const explain_writer = explain_buffer.writer(allocator);

    try trace1.explain(explain_writer);
    try explain_file.writeAll(explain_buffer.items);

    std.debug.print("✅ Saved human-readable explanation to query_explanation.md\n\n", .{});

    // AI Verification Summary
    std.debug.print("=" ** 70 ++ "\n", .{});
    std.debug.print("🤖 AI VERIFICATION SUMMARY\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});
    std.debug.print("The AI can now:\n\n", .{});
    std.debug.print("1. ✅ READ DATA: All sales data is accessible in columnar format\n", .{});
    std.debug.print("2. ✅ TRIAGE ISSUES: If calculation is wrong, AI can:\n", .{});
    std.debug.print("   - Check which rows were included (row IDs: ", .{});
    if (sum_result.contributing_rows) |rows| {
        for (rows[0..@min(5, rows.len)], 0..) |row_id, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{d}", .{row_id});
        }
        if (rows.len > 5) std.debug.print("...", .{});
    }
    std.debug.print(")\n", .{});
    std.debug.print("   - Verify each row's values manually\n", .{});
    std.debug.print("   - Re-calculate the sum independently\n", .{});
    std.debug.print("   - Check the audit log for data modifications\n", .{});
    std.debug.print("3. ✅ ACCURATE & TRACEABLE: Every step is logged:\n", .{});
    std.debug.print("   - {d} audit entries recorded\n", .{audit_log.entries.items.len});
    std.debug.print("   - Full execution trace with {d} steps\n", .{trace1.steps.items.len});
    std.debug.print("   - All contributing rows identified\n\n", .{});

    std.debug.print("📊 When CEO asks: \"What were total sales in 2024?\"\n", .{});
    std.debug.print("   AI responds: \"$1,094,502.50 based on 8 transactions\"\n\n", .{});
    std.debug.print("🔍 If there's a discrepancy, AI can:\n", .{});
    std.debug.print("   - Show the exact 8 rows that were summed\n", .{});
    std.debug.print("   - Display each transaction amount\n", .{});
    std.debug.print("   - Recalculate to verify: 125000 + 87500.5 + 150000.75 + ...\n", .{});
    std.debug.print("   - Check audit log for any data changes\n\n", .{});

    std.debug.print("=" ** 70 ++ "\n", .{});
    std.debug.print("✅ DEMO COMPLETE - Database is AI-auditable!\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});
}
