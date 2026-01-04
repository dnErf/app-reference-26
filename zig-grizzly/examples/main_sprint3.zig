const std = @import("std");
const gz = @import("root.zig");

const SaveState = struct {
    flag: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    err: ?anyerror = null,
};

var save_state = SaveState{};
var load_state = SaveState{};
var loaded_db_result: ?gz.Database = null;

fn onSaveComplete(_: *gz.Database, err: ?anyerror) void {
    save_state.err = err;
    save_state.flag.store(true, .release);
}

fn onLoadComplete(db: gz.Database, err: ?anyerror) void {
    load_state.err = err;
    if (err == null) {
        loaded_db_result = db; // transfer ownership to main thread
    } else {
        var doomed = db;
        doomed.deinit();
    }
    load_state.flag.store(true, .release);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== SPRINT 3: Optimizer + Indexes + Async Lakehouse ===\n\n", .{});

    // Build synthetic orders dataset
    var db = try gz.Database.init(allocator, "orders_db");
    defer db.deinit();

    const orders_schema = [_]gz.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "user_id", .data_type = .int32 },
        .{ .name = "product", .data_type = .string },
        .{ .name = "region", .data_type = .string },
        .{ .name = "amount", .data_type = .float64 },
    };

    try db.createTable("orders", &orders_schema);
    const orders = try db.getTable("orders");

    const regions = [_][]const u8{ "us-east", "us-west", "eu-central", "ap-south" };
    const products = [_][]const u8{ "AI GPU", "Vector DB", "LLM Credits", "Inference Box" };

    const total_orders: usize = 4000;
    var row: usize = 0;
    while (row < total_orders) : (row += 1) {
        const user_id: i32 = @intCast((row % 250) + 1);
        const product = products[row % products.len];
        const region = regions[(row / 7) % regions.len];
        const amount = 400.0 + @as(f64, @floatFromInt((row % 40) * 25));

        try orders.insertRow(&[_]gz.Value{
            gz.Value{ .int32 = @intCast(row + 1) },
            gz.Value{ .int32 = user_id },
            gz.Value{ .string = product },
            gz.Value{ .string = region },
            gz.Value{ .float64 = amount },
        });
    }

    std.debug.print("✓ Loaded {d} synthetic orders across {d} users\n", .{ orders.row_count, 250 });

    // Create B+Tree indexes
    try orders.createIndex("idx_orders_user", "user_id");
    try orders.createIndex("idx_orders_region", "region");
    std.debug.print("✓ Built indexes on user_id and region\n", .{});

    if (orders.indexes.get("idx_orders_user")) |idx_ptr| {
        const stats = idx_ptr.getStats();
        std.debug.print("  ↳ user_id index height={d}, keys={d}\n", .{ stats.height, stats.key_count });
    }

    // Run indexed query via SQL engine
    var engine = gz.QueryEngine.init(allocator, &db);
    defer engine.deinit();

    const sql = "SELECT id, user_id, amount FROM orders WHERE user_id = 42 AND region = 'us-east'";
    var result = try engine.execute(sql);
    defer result.deinit();

    switch (result) {
        .table => |t| {
            std.debug.print("✓ Optimized query matched {d} rows\n", .{t.row_count});
        },
        .message => |msg| std.debug.print("Unexpected message: {s}\n", .{msg}),
    }

    // Demonstrate optimizer rewriting plan to index scan
    var optimizer = gz.Optimizer.init(allocator);
    defer optimizer.deinit();
    try optimizer.registerTable(orders);

    const col_expr = try gz.Expr.columnRef(allocator, "user_id");
    const lit_expr = try gz.Expr.literal(allocator, gz.Value{ .int32 = 42 });
    const plan_expr = try gz.Expr.binary(allocator, .equal, col_expr, lit_expr);
    defer plan_expr.deinit();

    const scan = try gz.PlanNode.init(allocator, .scan);
    scan.table_name = "orders";
    scan.estimated_rows = orders.row_count;

    const filter = try gz.PlanNode.init(allocator, .filter);
    filter.child = scan;
    filter.predicate = plan_expr;
    filter.estimated_rows = orders.row_count;

    var plan = gz.QueryPlan.init(allocator, filter);
    defer plan.deinit();

    try optimizer.optimize(&plan);
    std.debug.print("\nEXPLAIN plan after optimization:\n", .{});
    const explain_json = try plan.explainJSON();
    std.debug.print("{s}\n", .{explain_json});

    // Async lakehouse save/load
    var async_lakehouse = try gz.AsyncLakehouse.init(allocator, null);
    defer async_lakehouse.deinit();

    save_state = SaveState{};
    try async_lakehouse.saveAsync(&db, "orders_db.griz", onSaveComplete);
    std.debug.print("\nSaving lakehouse snapshot asynchronously...\n", .{});
    while (!save_state.flag.load(.acquire)) {
        std.time.sleep(1 * std.time.ns_per_ms * 5);
    }
    if (save_state.err) |e| {
        std.debug.print("✗ Async save failed: {}\n", .{e});
    } else {
        std.debug.print("✓ Async save finished on worker thread\n", .{});
    }

    load_state = SaveState{};
    try async_lakehouse.loadAsync("orders_db.griz", onLoadComplete);
    std.debug.print("Loading snapshot on background thread...\n", .{});
    while (!load_state.flag.load(.acquire)) {
        std.time.sleep(1 * std.time.ns_per_ms * 5);
    }

    if (load_state.err) |e| {
        std.debug.print("✗ Async load failed: {}\n", .{e});
    } else if (loaded_db_result) |db_copy| {
        loaded_db_result = null;
        var loaded_db = db_copy;
        defer loaded_db.deinit();
        const loaded_orders = try loaded_db.getTable("orders");
        std.debug.print("✓ Loaded copy with {d} rows\n", .{loaded_orders.row_count});
        var loaded_engine = gz.QueryEngine.init(allocator, loaded_db);
        defer loaded_engine.deinit();
        var loaded_query = try loaded_engine.execute("SELECT id FROM orders WHERE region = 'eu-central' AND user_id = 10");
        defer loaded_query.deinit();
        switch (loaded_query) {
            .table => |t| std.debug.print("  ↳ Verification rows returned: {d}\n", .{t.row_count}),
            .message => |msg| std.debug.print("  ↳ Message: {s}\n", .{msg}),
        }
    }

    // Clean up snapshot artifacts
    std.fs.cwd().deleteFile("orders_db.griz") catch {};
    std.fs.cwd().deleteTree("orders_db.lakehouse") catch {};

    std.debug.print("\n🎯 Sprint 3 demo complete\n", .{});
}
