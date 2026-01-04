const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");
const query = @import("query.zig");

const Value = types.Value;
const DataType = types.DataType;
const Table = table_mod.Table;
const OrderByClause = query.OrderByClause;
const OrderByColumn = query.OrderByColumn;
const SortDirection = query.SortDirection;

/// Sorter handles ORDER BY clause execution
pub const Sorter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Sorter {
        return .{ .allocator = allocator };
    }

    /// Sort a table in-place according to ORDER BY clause
    pub fn sortTable(self: *Sorter, table: *Table, order_by: OrderByClause) !void {
        if (table.row_count == 0) return;
        if (order_by.columns.len == 0) return;

        // Create array of row indices
        const row_indices = try self.allocator.alloc(usize, table.row_count);
        defer self.allocator.free(row_indices);

        for (row_indices, 0..) |*idx, i| {
            idx.* = i;
        }

        // Create sort context
        const context = SortContext{
            .table = table,
            .order_by = order_by,
        };

        // Sort the indices
        std.mem.sort(usize, row_indices, context, compareRows);

        // Reorder table columns based on sorted indices
        try self.reorderTable(table, row_indices);
    }

    /// Compare two rows according to ORDER BY clause
    fn compareRows(context: SortContext, row_a_idx: usize, row_b_idx: usize) bool {
        // Compare by each ORDER BY column in sequence
        for (context.order_by.columns) |order_col| {
            const col_idx = context.table.schema.findColumn(order_col.column_name) orelse {
                // Column not found, treat as equal
                continue;
            };

            const comparison = compareValues(
                context.table,
                col_idx,
                row_a_idx,
                row_b_idx,
            );

            if (comparison == .eq) {
                // Values equal, check next column
                continue;
            }

            // Apply sort direction
            return switch (order_col.direction) {
                .asc => comparison == .lt,
                .desc => comparison == .gt,
            };
        }

        // All columns equal, maintain original order (stable sort)
        return row_a_idx < row_b_idx;
    }

    /// Compare two values from a column
    fn compareValues(
        table: *Table,
        col_idx: usize,
        row_a: usize,
        row_b: usize,
    ) std.math.Order {
        const column = &table.columns[col_idx];
        const value_a = column.get(row_a) catch return .eq;
        const value_b = column.get(row_b) catch return .eq;

        return switch (column.data_type) {
            .int32 => std.math.order(value_a.int32, value_b.int32),
            .int64 => std.math.order(value_a.int64, value_b.int64),
            .float32 => blk: {
                if (std.math.isNan(value_a.float32) and std.math.isNan(value_b.float32)) {
                    break :blk .eq;
                }
                if (std.math.isNan(value_a.float32)) break :blk .gt; // NaN sorts last
                if (std.math.isNan(value_b.float32)) break :blk .lt;
                break :blk std.math.order(value_a.float32, value_b.float32);
            },
            .float64 => blk: {
                if (std.math.isNan(value_a.float64) and std.math.isNan(value_b.float64)) {
                    break :blk .eq;
                }
                if (std.math.isNan(value_a.float64)) break :blk .gt;
                if (std.math.isNan(value_b.float64)) break :blk .lt;
                break :blk std.math.order(value_a.float64, value_b.float64);
            },
            .boolean => blk: {
                // false < true
                if (value_a.boolean == value_b.boolean) break :blk .eq;
                if (!value_a.boolean and value_b.boolean) break :blk .lt;
                break :blk .gt;
            },
            .string => blk: {
                const cmp = std.mem.order(u8, value_a.string, value_b.string);
                break :blk cmp;
            },
            .timestamp => std.math.order(value_a.timestamp, value_b.timestamp),
            .vector => blk: {
                // Vector comparison not well-defined, compare by first element
                if (value_a.vector.len() == 0 and value_b.vector.len() == 0) break :blk .eq;
                if (value_a.vector.len() == 0) break :blk .lt;
                if (value_b.vector.len() == 0) break :blk .gt;
                break :blk std.math.order(value_a.vector.values[0], value_b.vector.values[0]);
            },
            .custom => .eq, // Custom types not comparable for sorting, treat as equal
            .exception => .eq, // Exception types not comparable for sorting, treat as equal
        };
    }

    /// Reorder table columns according to sorted row indices
    fn reorderTable(self: *Sorter, table: *Table, sorted_indices: []const usize) !void {
        // For each column, create new data array in sorted order
        for (table.columns) |*column| {
            // Create temporary buffer for reordered data
            const new_data = try self.allocator.alloc(u8, column.data.len);
            errdefer self.allocator.free(new_data);

            // Copy data in sorted order
            for (sorted_indices, 0..) |src_row, dest_row| {
                const src_offset = src_row * column.row_stride;
                const dest_offset = dest_row * column.row_stride;
                const src_slice = column.data[src_offset .. src_offset + column.row_stride];
                const dest_slice = new_data[dest_offset .. dest_offset + column.row_stride];
                @memcpy(dest_slice, src_slice);
            }

            // Replace old data with sorted data
            self.allocator.free(column.data);
            column.data = new_data;

            // For string columns, handle string pool
            if (column.data_type == .string) {
                // String pool references are already in the data,
                // just need to ensure they're valid
                // (no need to reorder pool since we copied indices)
            }
        }
    }
};

const SortContext = struct {
    table: *Table,
    order_by: OrderByClause,
};

// Tests
test "Sorter - single column ascending" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create test table
    var db = try @import("database.zig").Database.init(allocator, "test_db");
    defer db.deinit();

    const schema = [_]@import("schema.zig").Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32, .vector_dim = 0 },
        .{ .name = "age", .data_type = .int32, .vector_dim = 0 },
        .{ .name = "name", .data_type = .string, .vector_dim = 0 },
    };

    var table = try Table.init(allocator, "users", &schema);
    defer table.deinit();

    // Insert unsorted data
    try table.insertRow(&[_]Value{
        Value{ .int32 = 3 },
        Value{ .int32 = 30 },
        Value{ .string = "Charlie" },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .int32 = 25 },
        Value{ .string = "Alice" },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .int32 = 35 },
        Value{ .string = "Bob" },
    });

    // Create ORDER BY clause: ORDER BY age ASC
    const order_cols = try allocator.alloc(OrderByColumn, 1);
    defer allocator.free(order_cols);
    order_cols[0] = OrderByColumn{
        .column_name = "age",
        .direction = .asc,
    };

    const order_by = OrderByClause{
        .columns = order_cols,
        .allocator = allocator,
    };

    // Sort table
    var sorter = Sorter.init(allocator);
    try sorter.sortTable(&table, order_by);

    // Verify order: Alice (25), Charlie (30), Bob (35)
    const age_col = &table.columns[1];
    const age1 = try age_col.get(0);
    const age2 = try age_col.get(1);
    const age3 = try age_col.get(2);

    try testing.expectEqual(@as(i32, 25), age1.int32);
    try testing.expectEqual(@as(i32, 30), age2.int32);
    try testing.expectEqual(@as(i32, 35), age3.int32);
}

test "Sorter - single column descending" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var db = try @import("database.zig").Database.init(allocator, "test_db");
    defer db.deinit();

    const schema = [_]@import("schema.zig").Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32, .vector_dim = 0 },
        .{ .name = "score", .data_type = .float64, .vector_dim = 0 },
    };

    var table = try Table.init(allocator, "scores", &schema);
    defer table.deinit();

    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .float64 = 85.5 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .float64 = 92.3 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 3 },
        Value{ .float64 = 78.9 },
    });

    const order_cols = try allocator.alloc(OrderByColumn, 1);
    defer allocator.free(order_cols);
    order_cols[0] = OrderByColumn{
        .column_name = "score",
        .direction = .desc,
    };

    const order_by = OrderByClause{
        .columns = order_cols,
        .allocator = allocator,
    };

    var sorter = Sorter.init(allocator);
    try sorter.sortTable(&table, order_by);

    // Verify order: 92.3, 85.5, 78.9
    const score_col = &table.columns[1];
    const score1 = try score_col.get(0);
    const score2 = try score_col.get(1);
    const score3 = try score_col.get(2);

    try testing.expectEqual(@as(f64, 92.3), score1.float64);
    try testing.expectEqual(@as(f64, 85.5), score2.float64);
    try testing.expectEqual(@as(f64, 78.9), score3.float64);
}

test "Sorter - multiple columns" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var db = try @import("database.zig").Database.init(allocator, "test_db");
    defer db.deinit();

    const schema = [_]@import("schema.zig").Schema.ColumnDef{
        .{ .name = "dept", .data_type = .string, .vector_dim = 0 },
        .{ .name = "salary", .data_type = .int32, .vector_dim = 0 },
    };

    var table = try Table.init(allocator, "employees", &schema);
    defer table.deinit();

    try table.insertRow(&[_]Value{
        Value{ .string = "Sales" },
        Value{ .int32 = 50000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .string = "Engineering" },
        Value{ .int32 = 80000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .string = "Sales" },
        Value{ .int32 = 60000 },
    });
    try table.insertRow(&[_]Value{
        Value{ .string = "Engineering" },
        Value{ .int32 = 75000 },
    });

    // ORDER BY dept ASC, salary DESC
    const order_cols = try allocator.alloc(OrderByColumn, 2);
    defer allocator.free(order_cols);
    order_cols[0] = OrderByColumn{
        .column_name = "dept",
        .direction = .asc,
    };
    order_cols[1] = OrderByColumn{
        .column_name = "salary",
        .direction = .desc,
    };

    const order_by = OrderByClause{
        .columns = order_cols,
        .allocator = allocator,
    };

    var sorter = Sorter.init(allocator);
    try sorter.sortTable(&table, order_by);

    // Verify order:
    // Engineering 80000
    // Engineering 75000
    // Sales 60000
    // Sales 50000
    const dept_col = &table.columns[0];
    const salary_col = &table.columns[1];

    const dept1 = try dept_col.get(0);
    const sal1 = try salary_col.get(0);
    try testing.expectEqualStrings("Engineering", dept1.string);
    try testing.expectEqual(@as(i32, 80000), sal1.int32);

    const dept2 = try dept_col.get(1);
    const sal2 = try salary_col.get(1);
    try testing.expectEqualStrings("Engineering", dept2.string);
    try testing.expectEqual(@as(i32, 75000), sal2.int32);

    const dept3 = try dept_col.get(2);
    const sal3 = try salary_col.get(2);
    try testing.expectEqualStrings("Sales", dept3.string);
    try testing.expectEqual(@as(i32, 60000), sal3.int32);

    const dept4 = try dept_col.get(3);
    const sal4 = try salary_col.get(3);
    try testing.expectEqualStrings("Sales", dept4.string);
    try testing.expectEqual(@as(i32, 50000), sal4.int32);
}
