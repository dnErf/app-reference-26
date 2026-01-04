const std = @import("std");
const grizzly = @import("zig_grizzly");

const Schema = grizzly.Schema;
const Table = grizzly.Table;
const Database = grizzly.Database;
const Value = grizzly.Value;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Grizzly DB: Cardinality Estimation Demo ===\n\n", .{});

    // Create database and table
    var db = try Database.init(allocator, "cardinality_demo");
    defer db.deinit();

    const cols = [_]Schema.ColumnDef{
        .{ .name = "product_id", .data_type = .int32 },
        .{ .name = "category", .data_type = .string },
        .{ .name = "region", .data_type = .string },
        .{ .name = "price", .data_type = .int32 },
    };
    var schema = try Schema.init(allocator, &cols);
    defer schema.deinit();

    try db.createTable("sales", schema.columns);
    const table = try db.getTable("sales");

    std.debug.print("📊 Inserting diverse dataset...\n", .{});

    // Insert data with different cardinality patterns
    // product_id: High cardinality (mostly unique)
    // category: Low cardinality (5 categories)
    // region: Medium cardinality (20 regions)
    // price: Medium cardinality

    const categories = [_][]const u8{ "Electronics", "Clothing", "Food", "Books", "Home" };
    const regions = [_][]const u8{
        "North",         "South",        "East",         "West",      "Central",
        "Northeast",     "Northwest",    "Southeast",    "Southwest", "North-Central",
        "South-Central", "East-Central", "West-Central", "Urban",     "Suburban",
        "Rural",         "Coastal",      "Inland",       "Mountain",  "Valley",
    };

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const product_id = @as(i32, @intCast(i + 1000)); // High cardinality
        const category_idx = i % categories.len;
        const region_idx = i % regions.len;
        const price = 10 + @as(i32, @intCast(i % 200)); // 200 distinct prices

        try table.insertRow(&[_]Value{
            Value{ .int32 = product_id },
            Value{ .string = categories[category_idx] },
            Value{ .string = regions[region_idx] },
            Value{ .int32 = price },
        });
    }

    std.debug.print("✅ Inserted 1,000 rows\n\n", .{});

    // Analyze cardinality for each column
    std.debug.print("🔍 Analyzing cardinality with AI-friendly exports:\n\n", .{});

    var cardinality_report = std.ArrayList(u8){};
    defer cardinality_report.deinit(allocator);
    const writer = cardinality_report.writer(allocator);

    try writer.writeAll("{\n  \"table\": \"sales\",\n");
    try writer.writeAll("  \"total_rows\": ");
    try writer.print("{d},\n", .{table.row_count});
    try writer.writeAll("  \"columns\": [\n");

    for (table.schema.columns, 0..) |col_def, col_idx| {
        const column = &table.columns[col_idx];

        // Get cardinality stats
        const stats = column.estimateCardinality(col_def.name) catch continue;

        // Print to console
        std.debug.print("Column: {s}\n", .{col_def.name});
        std.debug.print("  - Distinct values: {d}\n", .{stats.distinct_count});
        std.debug.print("  - Total values: {d}\n", .{stats.total_count});
        std.debug.print("  - Uniqueness: {d:.2}%\n", .{stats.uniqueness() * 100});
        std.debug.print("  - Method: {s}\n", .{if (stats.is_exact) "Exact" else "HyperLogLog"});

        // Compression recommendation
        const recommendation = if (stats.uniqueness() <= 0.10)
            "Dictionary (very low cardinality)"
        else if (stats.uniqueness() <= 0.30)
            "Dictionary (low cardinality)"
        else if (stats.uniqueness() >= 0.90)
            "None (high cardinality)"
        else
            "Bit-packing or RLE";
        std.debug.print("  - Compression: {s}\n\n", .{recommendation});

        // Add to JSON report
        if (col_idx > 0) try writer.writeAll(",\n");
        try writer.writeAll("    {\n");
        try writer.print("      \"name\": \"{s}\",\n", .{col_def.name});
        try writer.print("      \"type\": \"{s}\",\n", .{@tagName(col_def.data_type)});
        try writer.print("      \"distinct_count\": {d},\n", .{stats.distinct_count});
        try writer.print("      \"total_count\": {d},\n", .{stats.total_count});
        try writer.print("      \"uniqueness\": {d:.4},\n", .{stats.uniqueness()});
        try writer.print("      \"is_exact\": {},\n", .{stats.is_exact});
        try writer.print("      \"sample_rate\": {d:.4},\n", .{stats.sample_rate});
        try writer.print("      \"compression_recommendation\": \"{s}\"\n", .{recommendation});
        try writer.writeAll("    }");
    }

    try writer.writeAll("\n  ]\n}\n");

    // Save AI-friendly JSON report
    const report = try cardinality_report.toOwnedSlice(allocator);
    defer allocator.free(report);

    const file = try std.fs.cwd().createFile("cardinality_report.json", .{});
    defer file.close();
    try file.writeAll(report);

    std.debug.print("📄 AI-friendly report saved to: cardinality_report.json\n\n", .{});

    std.debug.print("✅ Cardinality estimation complete!\n", .{});
    std.debug.print("✅ Compression heuristics updated with accurate uniqueness data\n", .{});

    std.debug.print("\n🎉 Demo complete! Check cardinality_report.json for AI-readable stats.\n", .{});
}
