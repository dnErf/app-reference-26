const std = @import("std");
const gz = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a sample database for demonstration
    var db = try gz.Database.init(allocator, "explain_demo");
    defer db.deinit();

    // Define schemas
    const user_schema = [_]gz.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "department_id", .data_type = .int32 },
    };

    const dept_schema = [_]gz.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };

    // Create tables
    try db.createTable("users", &user_schema);
    try db.createTable("departments", &dept_schema);

    // Create indexes
    const user_table = try db.getTable("users");
    try user_table.createIndex("idx_users_dept", "department_id");

    // Create query engine
    var engine = gz.QueryEngine.init(allocator, &db);
    defer engine.deinit();

    // Insert some sample data
    const users_table = try db.getTable("users");
    try users_table.insertRow(&[_]gz.Value{
        gz.Value{ .int32 = 1 },
        gz.Value{ .string = "Alice" },
        gz.Value{ .int32 = 1 },
    });
    try users_table.insertRow(&[_]gz.Value{
        gz.Value{ .int32 = 2 },
        gz.Value{ .string = "Bob" },
        gz.Value{ .int32 = 2 },
    });

    const dept_table = try db.getTable("departments");
    try dept_table.insertRow(&[_]gz.Value{
        gz.Value{ .int32 = 1 },
        gz.Value{ .string = "Engineering" },
    });
    try dept_table.insertRow(&[_]gz.Value{
        gz.Value{ .int32 = 2 },
        gz.Value{ .string = "Sales" },
    });

    // Test CTAS
    std.debug.print("\n=== Testing CTAS ===\n", .{});
    const ctas_sql = "CREATE TABLE user_dept_summary AS SELECT u.name, d.name as dept FROM users u JOIN departments d ON u.department_id = d.id";
    var ctas_result = try engine.execute(ctas_sql);
    defer ctas_result.deinit();

    switch (ctas_result) {
        .message => |msg| std.debug.print("CTAS Result: {s}\n", .{msg}),
        .table => std.debug.print("CTAS returned unexpected table\n", .{}),
    }

    // Verify the new table was created
    const summary_table = try db.getTable("user_dept_summary");
    std.debug.print("Created table with {d} rows and {d} columns\n", .{ summary_table.row_count, summary_table.schema.columns.len });

    // Display the CTAS result
    std.debug.print("CTAS Table Contents:\n", .{});
    var row: usize = 0;
    while (row < summary_table.row_count) : (row += 1) {
        std.debug.print("Row {d}: ", .{row});
        for (0..summary_table.columns.len) |col| {
            const val = try summary_table.getCell(row, col);
            std.debug.print("{any} ", .{val});
        }
        std.debug.print("\n", .{});
    }

    // Parse and plan the query
    const sql = "SELECT u.name, d.name FROM users u JOIN departments d ON u.department_id = d.id WHERE u.id > 5";

    // Parse and plan the query
    var result = try engine.execute(sql);
    defer result.deinit();

    // Get the plan (assuming we can access it)
    // For demo, we'll create a sample plan
    var plan = try gz.QueryPlan.init(allocator, .{
        .node_type = .join,
        .join_type = .hash,
        .join_left_column = "department_id",
        .join_right_column = "id",
        .estimated_rows = 100,
        .estimated_cost = 50.0,
    });
    defer plan.deinit();

    // Add children
    var left_child = try gz.PlanNode.init(allocator, .filter);
    left_child.filter_column = "id";
    left_child.filter_value = gz.Value{ .int32 = 5 };
    left_child.filter_op = .gt;

    var right_child = try gz.PlanNode.init(allocator, .scan);
    right_child.table_name = "departments";

    plan.left = left_child;
    plan.right = right_child;

    // Output Mermaid diagram
    const mermaid = try plan.explainMermaid();
    defer allocator.free(mermaid);

    std.debug.print("Query Plan Mermaid Diagram:\n{s}\n", .{mermaid});

    // Also output JSON for comparison
    const json = try plan.explainJSON();
    defer allocator.free(json);

    std.debug.print("\nQuery Plan JSON:\n{s}\n", .{json});
}
