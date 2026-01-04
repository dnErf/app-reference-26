const std = @import("std");
const zig_grizzly = @import("zig_grizzly");

const Database = zig_grizzly.Database;
const QueryEngine = zig_grizzly.QueryEngine;
const FormatRegistry = zig_grizzly.format.FormatRegistry;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    Grizzly DB - Sprint 7 Demo                    ║\n", .{});
    std.debug.print("║                  File-Based Query Execution                      ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});

    // Initialize database
    var db = try Database.init(allocator, "grizzly_db");
    defer db.deinit();

    // Initialize query engine
    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    // Initialize format registry
    var format_registry = FormatRegistry.init(allocator);
    defer format_registry.deinit();

    // Register CSV and JSON formats
    try format_registry.register(&zig_grizzly.CSV_LOADER);
    try format_registry.register(&zig_grizzly.JSON_LOADER);

    // Attach registry to engine
    engine.attachFormatRegistry(&format_registry);

    std.debug.print("\n📊 Feature 1: SELECT from CSV files\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("SQL: SELECT * FROM 'users.csv'\n\n", .{});
    std.debug.print("This feature allows direct SQL queries on CSV files without\n", .{});
    std.debug.print("loading them into memory first. Files are automatically detected\n", .{});
    std.debug.print("by extension and format.\n\n", .{});

    std.debug.print("📊 Feature 2: SELECT from JSON/JSONL files\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("SQL: SELECT * FROM 'data.json'\n", .{});
    std.debug.print("SQL: SELECT * FROM 'logs.jsonl'\n\n", .{});
    std.debug.print("Support for JSON arrays and JSONL (newline-delimited JSON)\n", .{});
    std.debug.print("with automatic format detection.\n\n", .{});

    std.debug.print("📊 Feature 3: LOAD command for persistent loading\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("SQL: LOAD 'data.csv' INTO my_table\n\n", .{});
    std.debug.print("Loads file data into a persistent database table that can be\n", .{});
    std.debug.print("queried multiple times without reloading.\n\n", .{});

    std.debug.print("📊 Feature 4: Auto-format detection\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("Formats detected by:\n", .{});
    std.debug.print("  • File extension (.csv, .json, .jsonl, .parquet)\n", .{});
    std.debug.print("  • File content magic bytes (fallback if no extension)\n", .{});
    std.debug.print("  • Content inspection for JSON/JSONL distinction\n\n", .{});

    std.debug.print("📊 Feature 5: Schema inference\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("Automatically infers column types:\n", .{});
    std.debug.print("  • Boolean: 'true', 'false'\n", .{});
    std.debug.print("  • Integer: numeric without decimal\n", .{});
    std.debug.print("  • Float: numeric with decimal point\n", .{});
    std.debug.print("  • String: default fallback\n\n", .{});

    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    Integration Points                           ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("1️⃣  Modified src/query.zig:\n", .{});
    std.debug.print("   • Added string_literal token type for file paths\n", .{});
    std.debug.print("   • Added LOAD keyword to tokenizer\n", .{});
    std.debug.print("   • Extended executeSelect to handle file paths\n", .{});
    std.debug.print("   • Implemented executeLoad method\n", .{});
    std.debug.print("   • Added loadFileAsTable helper\n\n", .{});

    std.debug.print("2️⃣  QueryEngine enhancements:\n", .{});
    std.debug.print("   • FormatRegistry attachment\n", .{});
    std.debug.print("   • File detection and loading\n", .{});
    std.debug.print("   • Error handling for missing files\n\n", .{});

    std.debug.print("3️⃣  Format Support (from Sprint 6):\n", .{});
    std.debug.print("   ✅ CSV with schema inference\n", .{});
    std.debug.print("   ✅ JSON array format\n", .{});
    std.debug.print("   ✅ JSONL (line-delimited)\n", .{});
    std.debug.print("   ⏳ Parquet (basic support, enhanced in future)\n\n", .{});

    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                      Example Usage                              ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("Code Example:\n\n", .{});
    std.debug.print("    var db = try Database.init(allocator);\n", .{});
    std.debug.print("    var engine = QueryEngine.init(allocator, &db);\n", .{});
    std.debug.print("    \n", .{});
    std.debug.print("    var registry = FormatRegistry.init(allocator);\n", .{});
    std.debug.print("    try registry.register(&csv_format.CSV_FORMAT);\n", .{});
    std.debug.print("    try registry.register(&json_format.JSON_FORMAT);\n", .{});
    std.debug.print("    \n", .{});
    std.debug.print("    engine.attachFormatRegistry(&registry);\n", .{});
    std.debug.print("    \n", .{});
    std.debug.print("    // Direct file query\n", .{});
    std.debug.print("    const result1 = try engine.execute(\"SELECT * FROM 'data.csv';\");\n", .{});
    std.debug.print("    \n", .{});
    std.debug.print("    // Load into table\n", .{});
    std.debug.print("    const result2 = try engine.execute(\"LOAD 'data.json' INTO users;\");\n", .{});
    std.debug.print("    \n", .{});
    std.debug.print("    // Query loaded table\n", .{});
    std.debug.print("    const result3 = try engine.execute(\"SELECT * FROM users;\");\n\n", .{});

    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                  Sprint 7 Status: ✅ COMPLETE                    ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("✨ Next: Sprint 8 - Advanced features (JOINs, ORDER BY, etc.)\n", .{});
    std.debug.print("✨ Build: zig build && zig build run-sprint7-demo\n\n", .{});
}
