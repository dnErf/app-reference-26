const std = @import("std");
const gz = @import("src/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try gz.Database.init(allocator, "test_lakehouse");
    defer db.deinit();

    const schema_def = [_]gz.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "score", .data_type = .float64 },
    };

    try db.createTable("users", &schema_def);
    const table = try db.getTable("users");

    try table.insertRow(&[_]gz.Value{
        gz.Value{ .int32 = 1 },
        gz.Value{ .string = "Alice" },
        gz.Value{ .float64 = 95.5 },
    });

    try table.insertRow(&[_]gz.Value{
        gz.Value{ .int32 = 2 },
        gz.Value{ .string = "Bob" },
        gz.Value{ .float64 = 87.3 },
    });

    const lakehouse = gz.Lakehouse.init(allocator);
    try lakehouse.save(&db, "test_lakehouse.griz", gz.format.CompressionType.none);

    std.debug.print("Saved database\n", .{});

    var loaded_db = try lakehouse.load("test_lakehouse.griz");
    defer loaded_db.deinit();

    std.debug.print("Loaded database: {s}\n", .{loaded_db.name});
    std.debug.print("Table count: {d}\n", .{loaded_db.tables.count()});

    var it = loaded_db.tables.keyIterator();
    while (it.next()) |key| {
        std.debug.print("Table: '{s}'\n", .{key.*});
    }

    const loaded_table = loaded_db.getTable("users") catch |err| {
        std.debug.print("Error getting table: {}\n", .{err});
        return err;
    };
    std.debug.print("Loaded table row count: {d}\n", .{loaded_table.row_count});
}
