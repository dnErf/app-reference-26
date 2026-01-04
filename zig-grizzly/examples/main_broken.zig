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

    var stdout_buf: [8192]u8 = undefined;
    var stdin_buf: [8192]u8 = undefined;
    const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    var stdout_writer = stdout_file.writer(&stdout_buf);
    const writer = &stdout_writer.interface;
    const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };
    var stdin_reader = stdin_file.reader(&stdin_buf);
    const reader = &stdin_reader.interface;

    try writer.print("╔══════════════════════════════════════════╗\n", .{});
    try writer.print("║   Grizzly DB - Fast Columnar Database   ║\n", .{});
    try writer.print("║   AI-Friendly • Parallel • Embedded      ║\n", .{});
    try writer.print("╚══════════════════════════════════════════╝\n\n", .{});

    // Check command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // Skip program name

    const command = args.next();

    if (command) |cmd| {
        if (std.mem.eql(u8, cmd, "demo")) {
            try runDemo(allocator, writer);
            return;
        } else if (std.mem.eql(u8, cmd, "benchmark")) {
            try runBenchmark(allocator, writer);
            return;
        } else if (std.mem.eql(u8, cmd, "repl")) {
            try runREPL(allocator, writer, reader);
            return;
        } else if (std.mem.eql(u8, cmd, "help")) {
            try printHelp(writer);
            return;
        }
    }

    // Default: run demo
    try runDemo(allocator, writer);
}

fn printHelp(writer: anytype) !void {
    try writer.print("Usage: zig_grizzly [command]\n\n", .{});
    try writer.print("Commands:\n", .{});
    try writer.print("  demo       - Run a demonstration of Grizzly DB features\n", .{});
    try writer.print("  benchmark  - Run performance benchmarks\n", .{});
    try writer.print("  repl       - Start an interactive SQL REPL\n", .{});
    try writer.print("  help       - Show this help message\n", .{});
}

fn runDemo(allocator: std.mem.Allocator, writer: anytype) !void {
    try writer.print("🐻 Running Grizzly DB Demo...\n\n", .{});

    // Create database
    var db = try Database.init(allocator, "demo_db");
    defer db.deinit();

    try writer.print("✓ Created database 'demo_db'\n", .{});

    // Create users table
    const users_schema = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "age", .data_type = .int32 },
        .{ .name = "salary", .data_type = .float64 },
    };

    try db.createTable("users", &users_schema);
    try writer.print("✓ Created table 'users'\n", .{});

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

    try writer.print("✓ Inserted 4 rows\n\n", .{});

    // Display table
    try writer.print("═══ Table Contents ═══\n", .{});
    try users_table.print(writer);

    // Perform aggregations
    try writer.print("\n═══ Aggregations ═══\n", .{});

    const avg_age = try users_table.aggregate(allocator, "age", .avg);
    try writer.print("Average Age: {d:.1}\n", .{avg_age.value.float64});

    const max_salary = try users_table.aggregate(allocator, "salary", .max);
    try writer.print("Max Salary: ${d:.2}\n", .{max_salary.value.float64});

    const min_salary = try users_table.aggregate(allocator, "salary", .min);
    try writer.print("Min Salary: ${d:.2}\n", .{min_salary.value.float64});

    const total_salary = try users_table.aggregate(allocator, "salary", .sum);
    try writer.print("Total Salary: ${d:.2}\n", .{total_salary.value.float64});

    // Export to different formats
    try writer.print("\n═══ Export Formats ═══\n", .{});

    // JSON export
    var json_buffer = std.ArrayList(u8){};
    defer json_buffer.deinit(allocator);
    try export_mod.exportJSON(users_table.*, json_buffer.writer(allocator));
    try writer.print("✓ JSON export ({d} bytes)\n", .{json_buffer.items.len});

    // JSONL export
    var jsonl_buffer = std.ArrayList(u8){};
    defer jsonl_buffer.deinit(allocator);
    try export_mod.exportJSONL(users_table.*, jsonl_buffer.writer(allocator));
    try writer.print("✓ JSONL export ({d} bytes)\n", .{jsonl_buffer.items.len});

    // CSV export
    var csv_buffer = std.ArrayList(u8){};
    defer csv_buffer.deinit(allocator);
    try export_mod.exportCSV(users_table.*, csv_buffer.writer(allocator));
    try writer.print("✓ CSV export ({d} bytes)\n", .{csv_buffer.items.len});

    // Binary export
    var binary_buffer = std.ArrayList(u8){};
    defer binary_buffer.deinit(allocator);
    try export_mod.exportBinary(users_table.*, binary_buffer.writer(allocator));
    try writer.print("✓ Binary export ({d} bytes)\n", .{binary_buffer.items.len});

    // Save JSON to file
    const cwd = std.fs.cwd();
    const json_file = try cwd.createFile("users_export.json", .{});
    defer json_file.close();
    try json_file.writeAll(json_buffer.items);
    try writer.print("\n✓ Saved JSON to users_export.json\n", .{});

    // SQL Query Demo
    try writer.print("\n═══ SQL Query Demo ═══\n", .{});

    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    const sql = "SELECT * FROM users";
    try writer.print("SQL: {s}\n", .{sql});

    var result = try engine.execute(sql);
    defer result.deinit();

    switch (result) {
        .table => |t| {
            try writer.print("\nQuery Result:\n", .{});
            try t.print(writer);
        },
        .message => |msg| try writer.print("{s}\n", .{msg}),
    }

    // Persistence demo
    try writer.print("\n═══ Persistence Demo ═══\n", .{});
    try db.save("demo_data");
    try writer.print("✓ Database saved to ./demo_data/\n", .{});

    try writer.print("\n🎉 Demo completed successfully!\n", .{});
}

fn runBenchmark(allocator: std.mem.Allocator, writer: anytype) !void {
    try writer.print("🐻 Running Grizzly DB Benchmarks...\n\n", .{});

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
    try writer.print("Inserting {d} rows...\n", .{row_count});

    var timer = try std.time.Timer.start();

    var i: i32 = 0;
    while (i < row_count) : (i += 1) {
        try table.insertRow(&[_]Value{
            Value{ .int32 = i },
            Value{ .float64 = @as(f64, @floatFromInt(i)) * 1.5 },
        });
    }

    const insert_time = timer.read();
    try writer.print("✓ Inserted {d} rows in {d:.2}ms\n", .{ row_count, @as(f64, @floatFromInt(insert_time)) / 1_000_000.0 });
    try writer.print("  Throughput: {d:.0} rows/sec\n\n", .{@as(f64, @floatFromInt(row_count)) / (@as(f64, @floatFromInt(insert_time)) / 1_000_000_000.0)});

    // Benchmark: Aggregation
    try writer.print("Running aggregations...\n", .{});
    timer.reset();

    const sum_result = try table.aggregate(allocator, "value", .sum);
    const sum_time = timer.read();

    try writer.print("✓ SUM computed in {d:.2}ms\n", .{@as(f64, @floatFromInt(sum_time)) / 1_000_000.0});
    try writer.print("  Result: {d:.2}\n", .{sum_result.value.float64});

    timer.reset();
    const avg_result = try table.aggregate(allocator, "value", .avg);
    const avg_time = timer.read();

    try writer.print("✓ AVG computed in {d:.2}ms\n", .{@as(f64, @floatFromInt(avg_time)) / 1_000_000.0});
    try writer.print("  Result: {d:.2}\n", .{avg_result.value.float64});

    timer.reset();
    const max_result = try table.aggregate(allocator, "value", .max);
    const max_time = timer.read();

    try writer.print("✓ MAX computed in {d:.2}ms\n\n", .{@as(f64, @floatFromInt(max_time)) / 1_000_000.0});
    try writer.print("  Result: {d:.2}\n", .{max_result.value.float64});

    // Benchmark: Export
    try writer.print("Exporting data...\n", .{});

    var json_buffer = std.ArrayList(u8){};
    defer json_buffer.deinit(allocator);

    timer.reset();
    try export_mod.exportJSON(table.*, json_buffer.writer(allocator));
    const json_time = timer.read();

    try writer.print("✓ JSON export in {d:.2}ms ({d} bytes)\n", .{ @as(f64, @floatFromInt(json_time)) / 1_000_000.0, json_buffer.items.len });

    var binary_buffer = std.ArrayList(u8){};
    defer binary_buffer.deinit(allocator);

    timer.reset();
    try export_mod.exportBinary(table.*, binary_buffer.writer(allocator));
    const binary_time = timer.read();

    try writer.print("✓ Binary export in {d:.2}ms ({d} bytes)\n", .{ @as(f64, @floatFromInt(binary_time)) / 1_000_000.0, binary_buffer.items.len });
    try writer.print("  Compression ratio: {d:.1}x\n\n", .{@as(f64, @floatFromInt(json_buffer.items.len)) / @as(f64, @floatFromInt(binary_buffer.items.len))});

    try writer.print("🎉 Benchmark completed!\n", .{});
}

fn runREPL(allocator: std.mem.Allocator, writer: anytype, reader: anytype) !void {
    try writer.print("🐻 Grizzly DB Interactive REPL\n", .{});
    try writer.print("Type SQL queries or commands. Use 'exit' or 'quit' to exit.\n\n", .{});

    var db = try Database.init(allocator, "repl_db");
    defer db.deinit();

    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    // Create a sample table
    const schema = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "value", .data_type = .float64 },
    };
    try db.createTable("sample", &schema);

    try writer.print("Created sample table with columns: id (int32), name (string), value (float64)\n", .{});
    try writer.print("Example: INSERT INTO sample VALUES (1, 'test', 42.0)\n\n", .{});

    var buffer: [4096]u8 = undefined;

    while (true) {
        try writer.print("grizzly> ", .{});

        const input = (try reader.readUntilDelimiterOrEof(&buffer, '\n')) orelse break;
        const trimmed = std.mem.trim(u8, input, " \t\r\n");

        if (trimmed.len == 0) continue;

        if (std.mem.eql(u8, trimmed, "exit") or std.mem.eql(u8, trimmed, "quit")) {
            try writer.print("Goodbye! 🐻\n", .{});
            break;
        }

        if (std.mem.eql(u8, trimmed, "help")) {
            try writer.print("Commands:\n", .{});
            try writer.print("  CREATE TABLE name (col1 type1, col2 type2, ...)\n", .{});
            try writer.print("  INSERT INTO table VALUES (val1, val2, ...)\n", .{});
            try writer.print("  SELECT * FROM table\n", .{});
            try writer.print("  exit/quit - Exit the REPL\n\n", .{});
            continue;
        }

        var result = engine.execute(trimmed) catch |err| {
            try writer.print("Error: {}\n\n", .{err});
            continue;
        };
        defer result.deinit();

        switch (result) {
            .table => |t| {
                try t.print(writer);
            },
            .message => |msg| {
                try writer.print("{s}\n\n", .{msg});
            },
        }
    }
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
