const std = @import("std");
const root = @import("root");

const Database = root.Database;
const QueryEngine = root.QueryEngine;
const Schema = root.Schema;
const DataType = root.DataType;
const FormatRegistry = root.FormatRegistry;
const LoadOptions = root.LoadOptions;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           Sprint 7: File-Based Query Execution Test              ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize database and query engine
    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    // Initialize format registry
    var format_registry = FormatRegistry.init(allocator);
    defer format_registry.deinit();

    // Register CSV and JSON formats
    try format_registry.register(&root.CSV_LOADER);
    try format_registry.register(&root.JSON_LOADER);

    // Attach registry to query engine
    engine.attachFormatRegistry(&format_registry);

    std.debug.print("✅ Database and FormatRegistry initialized\n\n", .{});

    // Test 1: Create test CSV file
    std.debug.print("Test 1: Creating sample test files...\n", .{});
    try createTestCSV(allocator);
    try createTestJSON(allocator);
    std.debug.print("✅ Test CSV and JSON files created\n\n", .{});

    // Test 2: SELECT from CSV file
    std.debug.print("Test 2: SELECT from CSV file\n", .{});
    const query1 = "SELECT * FROM 'test_data.csv';";
    std.debug.print("Query: {s}\n", .{query1});

    const result1 = engine.execute(query1) catch |err| {
        std.debug.print("❌ Error executing query: {any}\n", .{err});
        return;
    };

    switch (result1) {
        .table => |table| {
            std.debug.print("✅ Loaded table: {s}\n", .{table.name});
            std.debug.print("   Rows: {d}\n", .{table.row_count});
            std.debug.print("   Columns: {d}\n", .{table.columns.len});
            for (table.columns) |col| {
                std.debug.print("     - {s} ({s})\n", .{ col.name, @tagName(col.data_type) });
            }
        },
        .message => |msg| {
            std.debug.print("Message: {s}\n", .{msg});
        },
    }
    std.debug.print("\n", .{});

    // Test 3: SELECT from JSON file
    std.debug.print("Test 3: SELECT from JSON file\n", .{});
    const query2 = "SELECT * FROM 'test_data.json';";
    std.debug.print("Query: {s}\n", .{query2});

    const result2 = engine.execute(query2) catch |err| {
        std.debug.print("❌ Error executing query: {any}\n", .{err});
        return;
    };

    switch (result2) {
        .table => |table| {
            std.debug.print("✅ Loaded table: {s}\n", .{table.name});
            std.debug.print("   Rows: {d}\n", .{table.row_count});
            std.debug.print("   Columns: {d}\n", .{table.columns.len});
        },
        .message => |msg| {
            std.debug.print("Message: {s}\n", .{msg});
        },
    }
    std.debug.print("\n", .{});

    // Test 4: LOAD command
    std.debug.print("Test 4: LOAD command - loading CSV into database\n", .{});
    const query3 = "LOAD 'test_data.csv' INTO users;";
    std.debug.print("Query: {s}\n", .{query3});

    const result3 = engine.execute(query3) catch |err| {
        std.debug.print("❌ Error executing query: {any}\n", .{err});
        return;
    };

    switch (result3) {
        .table => |table| {
            std.debug.print("Loaded table: {s}\n", .{table.name});
        },
        .message => |msg| {
            std.debug.print("✅ {s}\n", .{msg});
        },
    }
    std.debug.print("\n", .{});

    // Test 5: SELECT from newly loaded table
    std.debug.print("Test 5: SELECT from loaded table\n", .{});
    const query4 = "SELECT * FROM users;";
    std.debug.print("Query: {s}\n", .{query4});

    const result4 = engine.execute(query4) catch |err| {
        std.debug.print("❌ Error executing query: {any}\n", .{err});
        return;
    };

    switch (result4) {
        .table => |table| {
            std.debug.print("✅ Query result: {d} rows\n", .{table.row_count});
        },
        .message => |msg| {
            std.debug.print("Message: {s}\n", .{msg});
        },
    }
    std.debug.print("\n", .{});

    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║            ✅ Sprint 7 Tests Complete - File Loading Works!    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});
}

fn createTestCSV(allocator: std.mem.Allocator) !void {
    const csv_content =
        \\id,name,age,salary
        \\1,Alice,28,65000
        \\2,Bob,32,75000
        \\3,Carol,29,70000
        \\4,David,35,85000
    ;

    const file = try std.fs.cwd().createFile("test_data.csv", .{});
    defer file.close();

    try file.writeAll(csv_content);
    std.debug.print("   Created test_data.csv\n", .{});
}

fn createTestJSON(allocator: std.mem.Allocator) !void {
    const json_content =
        \\[
        \\  {"id": 1, "name": "Alice", "age": 28, "salary": 65000},
        \\  {"id": 2, "name": "Bob", "age": 32, "salary": 75000},
        \\  {"id": 3, "name": "Carol", "age": 29, "salary": 70000},
        \\  {"id": 4, "name": "David", "age": 35, "salary": 85000}
        \\]
    ;

    const file = try std.fs.cwd().createFile("test_data.json", .{});
    defer file.close();

    try file.writeAll(json_content);
    std.debug.print("   Created test_data.json\n", .{});
}
