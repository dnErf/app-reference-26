const std = @import("std");
const root = @import("root.zig");
const format = root.format;
const csv_format = root.csv_format;
const json_format = root.json_format;
const types = root.types;
const schema_mod = root.schema;
const table_mod = root.table;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Format Loader Test Suite ===\n\n", .{});

    // Test 1: CSV round-trip
    std.debug.print("Test 1: CSV Load and Save\n", .{});
    try testCSVLoadSave(allocator);
    std.debug.print("✓ CSV test passed\n\n", .{});

    // Test 2: JSON array format
    std.debug.print("Test 2: JSON Array Format\n", .{});
    try testJSONArray(allocator);
    std.debug.print("✓ JSON array test passed\n\n", .{});

    // Test 3: JSONL format
    std.debug.print("Test 3: JSONL Format\n", .{});
    try testJSONL(allocator);
    std.debug.print("✓ JSONL test passed\n\n", .{});

    // Test 4: Format registry
    std.debug.print("Test 4: Format Registry\n", .{});
    try testFormatRegistry(allocator);
    std.debug.print("✓ Format registry test passed\n\n", .{});

    // Test 5: Schema inference
    std.debug.print("Test 5: Schema Inference\n", .{});
    try testSchemaInference(allocator);
    std.debug.print("✓ Schema inference test passed\n\n", .{});

    std.debug.print("=== All Format Tests Passed! ===\n", .{});
}

fn testCSVLoadSave(allocator: std.mem.Allocator) !void {
    // Create test CSV file
    const test_csv = "id,name,age,salary\n1,Alice,30,75000\n2,Bob,25,65000\n3,Carol,35,85000\n";

    const csv_file = "test_format.csv";
    var file = try std.fs.cwd().createFile(csv_file, .{});
    try file.writeAll(test_csv);
    file.close();

    defer std.fs.cwd().deleteFile(csv_file) catch {};

    // Load CSV
    const opts = format.LoadOptions{
        .table_name = "people",
    };

    const table = try csv_format.loadCSV(allocator, csv_file, opts);
    defer table.deinit(allocator);

    std.testing.expect(table.row_count == 3) catch |err| {
        std.debug.print("  ✗ Expected 3 rows, got {}\n", .{table.row_count});
        return err;
    };

    std.testing.expect(table.schema.columns.items.len == 4) catch |err| {
        std.debug.print("  ✗ Expected 4 columns, got {}\n", .{table.schema.columns.items.len});
        return err;
    };

    std.debug.print("  Loaded {} rows with {} columns\n", .{ table.row_count, table.schema.columns.items.len });
}

fn testJSONArray(allocator: std.mem.Allocator) !void {
    // Create test JSON array file
    const test_json =
        \\[
        \\  {"id": 1, "name": "Alice", "active": true},
        \\  {"id": 2, "name": "Bob", "active": false},
        \\  {"id": 3, "name": "Carol", "active": true}
        \\]
    ;

    const json_file = "test_format.json";
    var file = try std.fs.cwd().createFile(json_file, .{});
    try file.writeAll(test_json);
    file.close();

    defer std.fs.cwd().deleteFile(json_file) catch {};

    // Load JSON
    const opts = format.LoadOptions{
        .table_name = "people",
    };

    const table = try json_format.loadJSON(allocator, json_file, opts);
    defer table.deinit(allocator);

    std.testing.expect(table.row_count == 3) catch |err| {
        std.debug.print("  ✗ Expected 3 rows, got {}\n", .{table.row_count});
        return err;
    };

    std.debug.print("  Loaded {} rows from JSON array\n", .{table.row_count});
}

fn testJSONL(allocator: std.mem.Allocator) !void {
    // Create test JSONL file
    const test_jsonl =
        \\{"id": 1, "name": "Alice", "score": 95.5}
        \\{"id": 2, "name": "Bob", "score": 87.3}
        \\{"id": 3, "name": "Carol", "score": 92.1}
    ;

    const jsonl_file = "test_format.jsonl";
    var file = try std.fs.cwd().createFile(jsonl_file, .{});
    try file.writeAll(test_jsonl);
    file.close();

    defer std.fs.cwd().deleteFile(jsonl_file) catch {};

    // Load JSONL
    const opts = format.LoadOptions{
        .table_name = "scores",
    };

    const table = try json_format.loadJSON(allocator, jsonl_file, opts);
    defer table.deinit(allocator);

    std.testing.expect(table.row_count == 3) catch |err| {
        std.debug.print("  ✗ Expected 3 rows, got {}\n", .{table.row_count});
        return err;
    };

    std.debug.print("  Loaded {} rows from JSONL\n", .{table.row_count});
}

fn testFormatRegistry(allocator: std.mem.Allocator) !void {
    var registry = format.FormatRegistry.init(allocator);
    defer registry.deinit();

    // Register loaders
    try registry.register(&csv_format.CSV_LOADER);
    try registry.register(&json_format.JSON_LOADER);

    // Test extension detection
    if (registry.detectByExtension("data.csv")) |loader| {
        std.testing.expectEqualStrings("CSV", loader.name) catch |err| {
            std.debug.print("  ✗ Expected CSV loader, got {s}\n", .{loader.name});
            return err;
        };
        std.debug.print("  ✓ Detected CSV from .csv extension\n", .{});
    } else {
        std.debug.print("  ✗ Failed to detect CSV loader\n", .{});
        return error.NoLoader;
    }

    if (registry.detectByExtension("data.json")) |loader| {
        std.testing.expectEqualStrings("JSON", loader.name) catch |err| {
            std.debug.print("  ✗ Expected JSON loader, got {s}\n", .{loader.name});
            return err;
        };
        std.debug.print("  ✓ Detected JSON from .json extension\n", .{});
    } else {
        std.debug.print("  ✗ Failed to detect JSON loader\n", .{});
        return error.NoLoader;
    }
}

fn testSchemaInference(allocator: std.mem.Allocator) !void {
    // Create test CSV with mixed types
    const test_csv = "id,name,score,active\n1,Alice,95.5,true\n2,Bob,87.3,false\n";

    const csv_file = "test_schema.csv";
    var file = try std.fs.cwd().createFile(csv_file, .{});
    try file.writeAll(test_csv);
    file.close();

    defer std.fs.cwd().deleteFile(csv_file) catch {};

    const opts = format.LoadOptions{
        .infer_types = true,
    };

    const schema = try csv_format.inferCSVSchema(csv_file, opts, allocator);
    defer schema.deinit();

    std.testing.expect(schema.columns.items.len == 4) catch |err| {
        std.debug.print("  ✗ Expected 4 columns, got {}\n", .{schema.columns.items.len});
        return err;
    };

    std.debug.print("  Inferred schema with {} columns:\n", .{schema.columns.items.len});
    for (schema.columns.items) |col| {
        std.debug.print("    - {s}: {s}\n", .{ col.name, col.data_type.name() });
    }
}
