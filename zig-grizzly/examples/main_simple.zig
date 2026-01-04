const std = @import("std");
const grizzly = @import("zig_grizzly");

const Database = grizzly.Database;
const Table = grizzly.Table;
const Value = grizzly.Value;
const Schema = grizzly.Schema;
const QueryEngine = grizzly.QueryEngine;
const export_mod = grizzly.export_mod;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("╔══════════════════════════════════════════╗\n", .{});
    std.debug.print("║   Grizzly DB - Fast Columnar Database   ║\n", .{});
    std.debug.print("║   AI-Friendly • Parallel • Embedded      ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════╝\n\n", .{});

    // Check command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    
    _ = args.skip(); // Skip program name

    const command = args.next();
    
    if (command) |cmd| {
        if (std.mem.eql(u8, cmd, "benchmark")) {
            try runBenchmark(allocator);
            return;
        } else if (std.mem.eql(u8, cmd, "help")) {
            try printHelp();
            return;
        }
    }

    // Default: run demo
    try runDemo(allocator);
}

fn printHelp() !void {
    std.debug.print("Usage: zig_grizzly [command]\n\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  demo       - Run a demonstration of Grizzly DB features (default)\n", .{});
    std.debug.print("  benchmark  - Run performance benchmarks\n", .{});
    std.debug.print("  help       - Show this help message\n", .{});
}

fn runDemo(allocator: std.mem.Allocator) !void {
    std.debug.print("🐻 Running Grizzly DB Demo...\n\n", .{});

    // Create database
    var db = try Database.init(allocator, "demo_db");
    defer db.deinit();

    std.debug.print("✓ Created database 'demo_db'\n", .{});

    // Create users table
    const users_schema = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "age", .data_type = .int32 },
        .{ .name = "salary", .data_type = .float64 },
    };

    try db.createTable("users", &users_schema);
    std.debug.print("✓ Created table 'users'\n", .{});

    // Insert sample data
    const users_table = try db.getTable("users");
    
    try users_table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice Johnson" },
        Value{ .int32 = 30 },
        Value{ .float64 = 75000.0 },
    });

    try users_table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .string = "Bob Smith" },
        Value{ .int32 = 25 },
        Value{ .float64 = 65000.0 },
    });

    try users_table.insertRow(&[_]Value{
        Value{ .int32 = 3 },
        Value{ .string = "Carol Davis" },
        Value{ .int32 = 35 },
        Value{ .float64 = 85000.0 },
    });

    try users_table.insertRow(&[_]Value{
        Value{ .int32 = 4 },
        Value{ .string = "David Wilson" },
        Value{ .int32 = 28 },
        Value{ .float64 = 70000.0 },
    });

    std.debug.print("✓ Inserted 4 rows\n\n", .{});

    // Display table
    std.debug.print("═══ Table Contents ═══\n", .{});
    std.debug.print("Table: {s}\n", .{users_table.name});
    std.debug.print("Rows: {d}\n", .{users_table.row_count});
    std.debug.print("Columns: {d}\n\n", .{users_table.schema.columns.len});
    
    var row: usize = 0;
    while (row < users_table.row_count) : (row += 1) {
        std.debug.print("Row {d}: ", .{row});
        for (0..users_table.columns.len) |col| {
            const val = try users_table.getCell(row, col);
            std.debug.print("{any} ", .{val});
        }
        std.debug.print("\n", .{});
    }

    // Perform aggregations
    std.debug.print("\n═══ Aggregations ═══\n", .{});
    
    const avg_age = try users_table.aggregate(allocator, "age", .avg);
    std.debug.print("Average Age: {d:.1}\n", .{avg_age.value.float64});

    const max_salary = try users_table.aggregate(allocator, "salary", .max);
    std.debug.print("Max Salary: ${d:.2}\n", .{max_salary.value.float64});

    const min_salary = try users_table.aggregate(allocator, "salary", .min);
    std.debug.print("Min Salary: ${d:.2}\n", .{min_salary.value.float64});

    const total_salary = try users_table.aggregate(allocator, "salary", .sum);
    std.debug.print("Total Salary: ${d:.2}\n", .{total_salary.value.float64});

    // Export to different formats
    std.debug.print("\n═══ Export Formats ═══\n", .{});

    // JSON export
    var json_buffer = std.ArrayList(u8){};
    defer json_buffer.deinit(allocator);
    var json_writer = json_buffer.writer(allocator);
    try export_mod.exportJSON(users_table.*, json_writer);
    std.debug.print("✓ JSON export ({d} bytes)\n", .{json_buffer.items.len});

    // JSONL export
    var jsonl_buffer = std.ArrayList(u8){};
    defer jsonl_buffer.deinit(allocator);
    var jsonl_writer = jsonl_buffer.writer(allocator);
    try export_mod.exportJSONL(users_table.*, jsonl_writer);
    std.debug.print("✓ JSONL export ({d} bytes)\n", .{jsonl_buffer.items.len});

    // CSV export
    var csv_buffer = std.ArrayList(u8){};
    defer csv_buffer.deinit(allocator);
    var csv_writer = csv_buffer.writer(allocator);
    try export_mod.exportCSV(users_table.*, csv_writer);
    std.debug.print("✓ CSV export ({d} bytes)\n", .{csv_buffer.items.len});

    // Binary export
    var binary_buffer = std.ArrayList(u8){};
    defer binary_buffer.deinit(allocator);
    var binary_writer = binary_buffer.writer(allocator);
    try export_mod.exportBinary(users_table.*, binary_writer);
    std.debug.print("✓ Binary export ({d} bytes)\n", .{binary_buffer.items.len});

    // Save JSON to file
    const cwd = std.fs.cwd();
    const json_file = try cwd.createFile("users_export.json", .{});
    defer json_file.close();
    try json_file.writeAll(json_buffer.items);
    std.debug.print("\n✓ Saved JSON to users_export.json\n", .{});

    std.debug.print("\n🎉 Demo completed successfully!\n", .{});
}

fn runBenchmark(allocator: std.mem.Allocator) !void {
    std.debug.print("🐻 Running Grizzly DB Benchmarks...\n\n", .{});

    var db = try Database.init(allocator, "bench_db");
    defer db.deinit();

    // Create a table with numeric data
    const schema = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "value", .data_type = .float64 },
    };

    try db.createTable("numbers", &schema);
    const table = try db.getTable("numbers");

    // Benchmark: Insert 100,000 rows
    const row_count = 100_000;
    std.debug.print("Inserting {d} rows...\n", .{row_count});
    
    var timer = try std.time.Timer.start();
    
    var i: i32 = 0;
    while (i < row_count) : (i += 1) {
        try table.insertRow(&[_]Value{
            Value{ .int32 = i },
            Value{ .float64 = @as(f64, @floatFromInt(i)) * 1.5 },
        });
    }
    
    const insert_time = timer.read();
    std.debug.print("✓ Inserted {d} rows in {d:.2}ms\n", .{ row_count, @as(f64, @floatFromInt(insert_time)) / 1_000_000.0 });
    std.debug.print("  Throughput: {d:.0} rows/sec\n\n", .{@as(f64, @floatFromInt(row_count)) / (@as(f64, @floatFromInt(insert_time)) / 1_000_000_000.0)});

    // Benchmark: Aggregation
    std.debug.print("Running aggregations...\n", .{});
    timer.reset();
    
    const sum_result = try table.aggregate(allocator, "value", .sum);
    const sum_time = timer.read();
    
    std.debug.print("✓ SUM computed in {d:.2}ms\n", .{@as(f64, @floatFromInt(sum_time)) / 1_000_000.0});
    std.debug.print("  Result: {d:.2}\n", .{sum_result.value.float64});
    
    timer.reset();
    const avg_result = try table.aggregate(allocator, "value", .avg);
    const avg_time = timer.read();
    
    std.debug.print("✓ AVG computed in {d:.2}ms\n", .{@as(f64, @floatFromInt(avg_time)) / 1_000_000.0});
    std.debug.print("  Result: {d:.2}\n", .{avg_result.value.float64});

    timer.reset();
    const max_result = try table.aggregate(allocator, "value", .max);
    const max_time = timer.read();
    
    std.debug.print("✓ MAX computed in {d:.2}ms\n\n", .{@as(f64, @floatFromInt(max_time)) / 1_000_000.0});
    std.debug.print("  Result: {d:.2}\n", .{max_result.value.float64});

    // Benchmark: Export
    std.debug.print("Exporting data...\n", .{});
    
    var json_buffer = std.ArrayList(u8){};
    defer json_buffer.deinit(allocator);
    var json_writer = json_buffer.writer(allocator);
    
    timer.reset();
    try export_mod.exportJSON(table.*, json_writer);
    const json_time = timer.read();
    
    std.debug.print("✓ JSON export in {d:.2}ms ({d} bytes)\n", .{ @as(f64, @floatFromInt(json_time)) / 1_000_000.0, json_buffer.items.len });

    var binary_buffer = std.ArrayList(u8){};
    defer binary_buffer.deinit(allocator);
    var binary_writer = binary_buffer.writer(allocator);
    
    timer.reset();
    try export_mod.exportBinary(table.*, binary_writer);
    const binary_time = timer.read();
    
    std.debug.print("✓ Binary export in {d:.2}ms ({d} bytes)\n", .{ @as(f64, @floatFromInt(binary_time)) / 1_000_000.0, binary_buffer.items.len });
    std.debug.print("  Compression ratio: {d:.1}x\n\n", .{@as(f64, @floatFromInt(json_buffer.items.len)) / @as(f64, @floatFromInt(binary_buffer.items.len))});

    std.debug.print("🎉 Benchmark completed!\n", .{});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
