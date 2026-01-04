const std = @import("std");
const types = @import("src/types.zig");
const database_mod = @import("src/database.zig");
const query_mod = @import("src/query.zig");
const schema_mod = @import("src/schema.zig");

const Database = database_mod.Database;
const QueryEngine = query_mod.QueryEngine;
const Value = types.Value;
const DataType = types.DataType;
const Schema = schema_mod.Schema;

test "ORDER BY single column ascending" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create table with sample data
    try db.createTable("employees", &[_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "salary", .data_type = .int32 },
    });

    var table = try db.getTable("employees");

    // Insert test data (deliberately out of order)
    try table.insertRow(&[_]Value{
        Value{ .int32 = 3 },
        Value{ .string = "Charlie" },
        Value{ .int32 = 75000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
        Value{ .int32 = 50000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .string = "Bob" },
        Value{ .int32 = 60000 },
    });

    // Test ORDER BY id ASC
    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var result = try engine.execute("SELECT * FROM employees ORDER BY id ASC;");
    defer result.table.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.table.row_count);

    // Verify sorted order (id should be 1, 2, 3)
    const id_col = result.table.schema.findColumn("id").?;
    const id0 = try result.table.columns[id_col].get(0);
    const id1 = try result.table.columns[id_col].get(1);
    const id2 = try result.table.columns[id_col].get(2);
    try std.testing.expectEqual(@as(i32, 1), id0.int32);
    try std.testing.expectEqual(@as(i32, 2), id1.int32);
    try std.testing.expectEqual(@as(i32, 3), id2.int32);
}

test "ORDER BY single column descending" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create table
    try db.createTable("products", &[_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "price", .data_type = .int32 },
    });

    var table = try db.getTable("products");

    // Insert test data
    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Widget" },
        Value{ .int32 = 100 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .string = "Gadget" },
        Value{ .int32 = 200 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 3 },
        Value{ .string = "Doohickey" },
        Value{ .int32 = 150 },
    });

    // Test ORDER BY price DESC
    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var result = try engine.execute("SELECT * FROM products ORDER BY price DESC;");
    defer result.table.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.table.row_count);

    // Verify sorted order (price should be 200, 150, 100)
    const price_col = result.table.schema.findColumn("price").?;
    const price0 = try result.table.columns[price_col].get(0);
    const price1 = try result.table.columns[price_col].get(1);
    const price2 = try result.table.columns[price_col].get(2);
    try std.testing.expectEqual(@as(i32, 200), price0.int32);
    try std.testing.expectEqual(@as(i32, 150), price1.int32);
    try std.testing.expectEqual(@as(i32, 100), price2.int32);
}

test "ORDER BY multiple columns" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create table
    try db.createTable("staff", &[_]Schema.ColumnDef{
        .{ .name = "dept", .data_type = .string },
        .{ .name = "name", .data_type = .string },
        .{ .name = "salary", .data_type = .int32 },
    });

    var table = try db.getTable("staff");

    // Insert test data
    try table.insertRow(&[_]Value{
        Value{ .string = "IT" },
        Value{ .string = "Charlie" },
        Value{ .int32 = 80000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .string = "HR" },
        Value{ .string = "Alice" },
        Value{ .int32 = 60000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .string = "IT" },
        Value{ .string = "Bob" },
        Value{ .int32 = 90000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .string = "HR" },
        Value{ .string = "Diana" },
        Value{ .int32 = 70000 },
    });

    // Test ORDER BY dept ASC, salary DESC
    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var result = try engine.execute("SELECT * FROM staff ORDER BY dept ASC, salary DESC;");
    defer result.table.deinit();

    try std.testing.expectEqual(@as(usize, 4), result.table.row_count);

    // Verify sorted order
    // HR dept: Diana (70000), Alice (60000)
    // IT dept: Bob (90000), Charlie (80000)
    const dept_col = result.table.schema.findColumn("dept").?;
    const name_col = result.table.schema.findColumn("name").?;
    const salary_col = result.table.schema.findColumn("salary").?;

    // Row 0: HR, Diana, 70000
    const dept0 = try result.table.columns[dept_col].get(0);
    const name0 = try result.table.columns[name_col].get(0);
    const salary0 = try result.table.columns[salary_col].get(0);
    try std.testing.expectEqualStrings("HR", dept0.string);
    try std.testing.expectEqualStrings("Diana", name0.string);
    try std.testing.expectEqual(@as(i32, 70000), salary0.int32);

    // Row 1: HR, Alice, 60000
    const dept1 = try result.table.columns[dept_col].get(1);
    const name1 = try result.table.columns[name_col].get(1);
    const salary1 = try result.table.columns[salary_col].get(1);
    try std.testing.expectEqualStrings("HR", dept1.string);
    try std.testing.expectEqualStrings("Alice", name1.string);
    try std.testing.expectEqual(@as(i32, 60000), salary1.int32);

    // Row 2: IT, Bob, 90000
    const dept2 = try result.table.columns[dept_col].get(2);
    const name2 = try result.table.columns[name_col].get(2);
    const salary2 = try result.table.columns[salary_col].get(2);
    try std.testing.expectEqualStrings("IT", dept2.string);
    try std.testing.expectEqualStrings("Bob", name2.string);
    try std.testing.expectEqual(@as(i32, 90000), salary2.int32);

    // Row 3: IT, Charlie, 80000
    const dept3 = try result.table.columns[dept_col].get(3);
    const name3 = try result.table.columns[name_col].get(3);
    const salary3 = try result.table.columns[salary_col].get(3);
    try std.testing.expectEqualStrings("IT", dept3.string);
    try std.testing.expectEqualStrings("Charlie", name3.string);
    try std.testing.expectEqual(@as(i32, 80000), salary3.int32);
}

test "ORDER BY with WHERE clause" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    // Create table
    try db.createTable("users", &[_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "age", .data_type = .int32 },
    });

    var table = try db.getTable("users");

    // Insert test data
    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
        Value{ .int32 = 25 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .string = "Bob" },
        Value{ .int32 = 35 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 3 },
        Value{ .string = "Charlie" },
        Value{ .int32 = 30 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 4 },
        Value{ .string = "Diana" },
        Value{ .int32 = 28 },
    });

    // Test WHERE + ORDER BY
    var engine = QueryEngine.init(allocator, &db);
    defer engine.deinit();

    var result = try engine.execute("SELECT * FROM users WHERE age > 26 ORDER BY age ASC;");
    defer result.table.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.table.row_count);

    // Verify: Diana (28), Charlie (30), Bob (35)
    const age_col = result.table.schema.findColumn("age").?;
    const age0 = try result.table.columns[age_col].get(0);
    const age1 = try result.table.columns[age_col].get(1);
    const age2 = try result.table.columns[age_col].get(2);
    try std.testing.expectEqual(@as(i32, 28), age0.int32);
    try std.testing.expectEqual(@as(i32, 30), age1.int32);
    try std.testing.expectEqual(@as(i32, 35), age2.int32);
}
