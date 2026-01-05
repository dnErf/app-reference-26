const std = @import("std");
const zig_grizzly = @import("zig_grizzly");

const RowStore = zig_grizzly.RowStore;
const Value = zig_grizzly.Value;
const Schema = zig_grizzly.Schema;

/// Demo showcasing Phase 4: Row Store Implementation
/// Features: Avro-based storage, OLTP operations, indexing, ACID transactions
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 Grizzly DB - Phase 4: Row Store Implementation Demo\n", .{});
    std.debug.print("=====================================================\n\n", .{});

    // Initialize row store
    const base_path = "test_row_output";
    std.fs.cwd().makeDir(base_path) catch {}; // Ignore if already exists

    var store = try RowStore.init(allocator, base_path);
    defer store.deinit();

    // Create a sample table schema for orders (OLTP workload)
    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "order_id", .data_type = .int32 },
        .{ .name = "customer_id", .data_type = .int32 },
        .{ .name = "product_name", .data_type = .string },
        .{ .name = "quantity", .data_type = .int32 },
        .{ .name = "unit_price", .data_type = .float32 },
        .{ .name = "order_date", .data_type = .timestamp },
        .{ .name = "status", .data_type = .string },
    };

    var schema = try Schema.init(allocator, &schema_def);
    defer schema.deinit();

    // Create table
    try store.createTable("orders", schema);
    std.debug.print("✅ Created table 'orders' with row-based storage\n", .{});

    // Insert sample orders
    std.debug.print("\n📝 Inserting sample orders...\n", .{});

    const sample_orders = [_][]const Value{
        &[_]Value{
            Value{ .int32 = 1 },
            Value{ .int32 = 101 },
            Value{ .string = try allocator.dupe(u8, "Laptop") },
            Value{ .int32 = 1 },
            Value{ .float32 = 1299.99 },
            Value{ .timestamp = 1704067200 }, // 2024-01-01
            Value{ .string = try allocator.dupe(u8, "pending") },
        },
        &[_]Value{
            Value{ .int32 = 2 },
            Value{ .int32 = 102 },
            Value{ .string = try allocator.dupe(u8, "Mouse") },
            Value{ .int32 = 2 },
            Value{ .float32 = 29.99 },
            Value{ .timestamp = 1704153600 }, // 2024-01-02
            Value{ .string = try allocator.dupe(u8, "shipped") },
        },
        &[_]Value{
            Value{ .int32 = 3 },
            Value{ .int32 = 101 },
            Value{ .string = try allocator.dupe(u8, "Keyboard") },
            Value{ .int32 = 1 },
            Value{ .float32 = 89.99 },
            Value{ .timestamp = 1704240000 }, // 2024-01-03
            Value{ .string = try allocator.dupe(u8, "delivered") },
        },
    };

    var total_insert_time: i64 = 0;
    for (sample_orders, 0..) |order, i| {
        const start_time = std.time.milliTimestamp();
        try store.insertRow("orders", order);
        const insert_time = std.time.milliTimestamp() - start_time;
        total_insert_time += insert_time;
        std.debug.print("  ✅ Inserted order {d} in {d}ms\n", .{ i + 1, insert_time });

        // Clean up the temporary allocated strings
        for (order) |value| {
            if (value == .string) {
                allocator.free(value.string);
            }
        }
    }

    const avg_insert_time = @as(f32, @floatFromInt(total_insert_time)) / @as(f32, @floatFromInt(sample_orders.len));
    std.debug.print("📊 Average insert time: {d:.2}ms\n", .{avg_insert_time});

    // Query orders
    std.debug.print("\n🔍 Querying orders...\n", .{});

    // Query all orders
    const start_query_time = std.time.milliTimestamp();
    const all_orders = try store.queryTable("orders", null, allocator);
    defer {
        for (all_orders) |row| {
            allocator.free(row);
        }
        allocator.free(all_orders);
    }

    const query_time = std.time.milliTimestamp() - start_query_time;
    std.debug.print("  ✅ Queried {d} orders in {d}ms\n", .{ all_orders.len, query_time });

    // Display results
    std.debug.print("\n📋 Order Results:\n", .{});
    std.debug.print("----------------\n", .{});
    for (all_orders, 0..) |order, i| {
        if (i >= 3) break; // Show first 3 results
        std.debug.print("Order {d}: ", .{i + 1});
        for (order, 0..) |value, j| {
            if (j > 0) std.debug.print(", ", .{});
            switch (value) {
                .int32 => |v| std.debug.print("{}", .{v}),
                .int64 => |v| std.debug.print("{}", .{v}),
                .float32 => |v| std.debug.print("{d:.2}", .{v}),
                .float64 => |v| std.debug.print("{d:.2}", .{v}),
                .boolean => |v| std.debug.print("{}", .{v}),
                .string => |v| std.debug.print("'{s}'", .{v}),
                .timestamp => |v| std.debug.print("{}", .{v}),
                else => std.debug.print("...", .{}),
            }
        }
        std.debug.print("\n", .{});
    }

    // Test indexed lookup
    std.debug.print("\n🔎 Testing indexed lookup (order_id = 2)...\n", .{});
    const indexed_start = std.time.milliTimestamp();
    const indexed_orders = try store.queryTable("orders", "id = 2", allocator);
    defer {
        for (indexed_orders) |row| {
            allocator.free(row);
        }
        allocator.free(indexed_orders);
    }
    const indexed_time = std.time.milliTimestamp() - indexed_start;

    std.debug.print("  ✅ Found {d} orders in {d}ms\n", .{ indexed_orders.len, indexed_time });

    // Update an order (simulate status change)
    std.debug.print("\n✏️  Updating order status...\n", .{});
    const update_start = std.time.milliTimestamp();

    // Update order 1 status to 'shipped'
    const updated_order = [_]Value{
        Value{ .int32 = 1 },
        Value{ .int32 = 101 },
        Value{ .string = try allocator.dupe(u8, "Laptop") },
        Value{ .int32 = 1 },
        Value{ .float32 = 1299.99 },
        Value{ .timestamp = 1704067200 },
        Value{ .string = try allocator.dupe(u8, "shipped") }, // Changed from 'pending'
    };
    defer allocator.free(updated_order[2].string);
    defer allocator.free(updated_order[6].string);

    try store.updateRow("orders", 0, &updated_order);
    const update_time = std.time.milliTimestamp() - update_start;
    std.debug.print("  ✅ Updated order 1 in {d}ms\n", .{update_time});

    // Delete an order
    std.debug.print("\n🗑️  Deleting order 3...\n", .{});
    const delete_start = std.time.milliTimestamp();
    try store.deleteRow("orders", 2);
    const delete_time = std.time.milliTimestamp() - delete_start;
    std.debug.print("  ✅ Deleted order 3 in {d}ms\n", .{delete_time});

    // Show final performance metrics
    const metrics = store.getPerformanceMetrics();
    std.debug.print("\n📊 Performance Metrics:\n", .{});
    std.debug.print("----------------------\n", .{});
    std.debug.print("Read Latency:  {d:.2}ms\n", .{metrics.read_latency_ms});
    std.debug.print("Write Latency: {d:.2}ms\n", .{metrics.write_latency_ms});
    std.debug.print("Throughput:    {d:.2} MB/s\n", .{metrics.throughput_mbps});
    std.debug.print("Compression:   {d:.1}x\n", .{metrics.compression_ratio});

    // Show transaction log
    std.debug.print("\n📝 Transaction Log:\n", .{});
    std.debug.print("------------------\n", .{});
    for (store.transaction_log.items, 0..) |entry, i| {
        std.debug.print("{d}. {s} on table '{s}', row {d}\n", .{
            i + 1,
            @tagName(entry.operation),
            entry.table_name,
            entry.row_id,
        });
    }

    std.debug.print("\n🎉 Row Store demo completed successfully!\n", .{});
    std.debug.print("Features demonstrated:\n", .{});
    std.debug.print("  ✅ Avro-based row storage\n", .{});
    std.debug.print("  ✅ ACID transaction logging\n", .{});
    std.debug.print("  ✅ B-tree indexing\n", .{});
    std.debug.print("  ✅ OLTP operations (insert/update/delete)\n", .{});
    std.debug.print("  ✅ Fast point lookups\n", .{});
}
