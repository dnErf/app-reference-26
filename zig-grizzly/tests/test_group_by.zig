const std = @import("std");
const types = @import("src/types.zig");
const database_mod = @import("src/database.zig");
const query_mod = @import("src/query.zig");
const schema_mod = @import("src/schema.zig");

const Database = database_mod.Database;
const QueryEngine = query_mod.QueryEngine;
const Value = types.Value;
const Schema = schema_mod.Schema;

// Test GROUP BY SUM
test "GROUP BY SUM" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    try db.createTable("staff", &[_]Schema.ColumnDef{
        .{ .name = "dept", .data_type = .string },
        .{ .name = "name", .data_type = .string },
        .{ .name = "salary", .data_type = .int32 },
    });

    var table = try db.getTable("staff");

    try table.insertRow(&[_]Value{ Value{ .string = "IT" }, Value{ .string = "Alice" }, Value{ .int32 = 80000 } });
    try table.insertRow(&[_]Value{ Value{ .string = "IT" }, Value{ .string = "Bob" }, Value{ .int32 = 90000 } });
    try table.insertRow(&[_]Value{ Value{ .string = "HR" }, Value{ .string = "Carol" }, Value{ .int32 = 70000 } });

    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var result = try engine.execute("SELECT dept, SUM(salary) FROM staff GROUP BY dept;");
    defer result.table.deinit();

    // Expect 2 groups
    try std.testing.expectEqual(@as(usize, 2), result.table.row_count);

    const dept_col = result.table.schema.findColumn("dept").?;
    const sum_col = result.table.schema.findColumn("salary").?; // agg named after column

    // Find HR row
    var found_hr = false;
    var found_it = false;
    for (0..result.table.row_count) |i| {
        const d = try result.table.columns[dept_col].get(i);
        const s = try result.table.columns[sum_col].get(i);
        if (std.mem.eql(u8, d.string, "HR")) {
            found_hr = true;
            try std.testing.expectEqual(@as(f64, 70000), s.float64);
        }
        if (std.mem.eql(u8, d.string, "IT")) {
            found_it = true;
            try std.testing.expectEqual(@as(f64, 170000), s.float64);
        }
    }
    try std.testing.expect(found_hr and found_it);
}

// Test COUNT(*)
test "COUNT star" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    try db.createTable("users", &[_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
    });

    var table = try db.getTable("users");
    try table.insertRow(&[_]Value{Value{ .int32 = 1 }});
    try table.insertRow(&[_]Value{Value{ .int32 = 2 }});

    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var result = try engine.execute("SELECT COUNT(*) FROM users;");
    defer result.table.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.table.row_count);
    const cnt = try result.table.columns[0].get(0);
    try std.testing.expectEqual(@as(i64, 2), cnt.int64);
}

// Test GROUP BY with HAVING
test "GROUP BY with HAVING" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    try db.createTable("staff", &[_]Schema.ColumnDef{
        .{ .name = "dept", .data_type = .string },
        .{ .name = "name", .data_type = .string },
        .{ .name = "salary", .data_type = .int32 },
    });

    var table = try db.getTable("staff");

    try table.insertRow(&[_]Value{ Value{ .string = "IT" }, Value{ .string = "Alice" }, Value{ .int32 = 80000 } });
    try table.insertRow(&[_]Value{ Value{ .string = "IT" }, Value{ .string = "Bob" }, Value{ .int32 = 90000 } });
    try table.insertRow(&[_]Value{ Value{ .string = "HR" }, Value{ .string = "Carol" }, Value{ .int32 = 70000 } });
    try table.insertRow(&[_]Value{ Value{ .string = "HR" }, Value{ .string = "Dave" }, Value{ .int32 = 75000 } });

    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var result = try engine.execute("SELECT dept, SUM(salary) FROM staff GROUP BY dept HAVING SUM(salary) > 140000;");
    defer result.table.deinit();

    // Should only return IT department (80000 + 90000 = 170000 > 140000)
    try std.testing.expectEqual(@as(usize, 1), result.table.row_count);

    const dept_col = result.table.schema.findColumn("dept").?;
    const sum_col = result.table.schema.findColumn("salary").?; // agg named after column

    const d = try result.table.columns[dept_col].get(0);
    const s = try result.table.columns[sum_col].get(0);

    try std.testing.expect(std.mem.eql(u8, "IT", d.string));
    try std.testing.expectEqual(@as(f64, 170000.0), s.float64);
}
