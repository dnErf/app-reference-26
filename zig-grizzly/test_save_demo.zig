const std = @import("std");
const grizzly = @import("src/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create database
    var db = try grizzly.Database.init(allocator, "test_db");
    // defer db.deinit(); // Move this to the end

    // Create a simple table
    const columns = [_]grizzly.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };

    var schema = try grizzly.Schema.init(allocator, &columns);
    defer schema.deinit();

    var table = try grizzly.Table.init(allocator, "users", &columns);
    defer table.deinit();

    // Insert some data
    try table.insertRow(&.{ .{ .int32 = 1 }, .{ .string = "Alice" } });
    try table.insertRow(&.{ .{ .int32 = 2 }, .{ .string = "Bob" } });

    try db.tables.put("users", &table);

    // Create query engine
    var engine = grizzly.QueryEngine.init(allocator, &db);
    defer engine.deinit();

    // Test SAVE DATABASE WITH COMPRESSION
    const result = try engine.execute("SAVE DATABASE TO 'test_save_lz4.griz' WITH COMPRESSION lz4;");

    std.debug.print("Result: {s}\n", .{result.message});

    // Check if file was created
    if (std.fs.cwd().openFile("test_save_lz4.griz", .{})) |file| {
        std.debug.print("✅ Database file 'test_save_lz4.griz' was created successfully!\n", .{});
        file.close();
    } else |_| {
        std.debug.print("❌ Database file was not created\n", .{});
    }

    // Test file overwrite protection
    const result2 = engine.execute("SAVE DATABASE TO 'test_save_lz4.griz' WITH COMPRESSION zstd;");
    if (result2) |_| {
        std.debug.print("❌ Expected error for file overwrite, but save succeeded\n", .{});
    } else |err| {
        std.debug.print("✅ File overwrite protection working: {}\n", .{err});
    }

    // Clean up results
    allocator.free(result.message);

    db.deinit();
}
