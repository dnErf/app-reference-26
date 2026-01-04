const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");

const Value = types.Value;
const Table = table_mod.Table;

/// AI validation functions for verifying calculations
pub const Validator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Validator {
        return .{ .allocator = allocator };
    }

    /// Verify that an aggregation result is correct by recalculating
    pub fn verifyAggregation(
        self: Validator,
        table: *const Table,
        column_name: []const u8,
        function: enum { sum, avg, count, min, max },
        expected_value: Value,
        contributing_rows: []const usize,
    ) !ValidationResult {
        const col_idx = table.schema.findColumn(column_name) orelse return error.ColumnNotFound;

        var calculated_value: Value = undefined;
        var issues = std.ArrayList([]const u8){};
        defer {
            for (issues.items) |issue| {
                self.allocator.free(issue);
            }
            issues.deinit(self.allocator);
        }

        switch (function) {
            .count => {
                calculated_value = Value{ .int64 = @intCast(contributing_rows.len) };
            },
            .sum => {
                var sum: f64 = 0;
                for (contributing_rows) |row_idx| {
                    const val = try table.getCell(row_idx, col_idx);
                    const num = switch (val) {
                        .int32 => |v| @as(f64, @floatFromInt(v)),
                        .int64 => |v| @as(f64, @floatFromInt(v)),
                        .float32 => |v| @as(f64, v),
                        .float64 => |v| v,
                        else => {
                            const issue = try std.fmt.allocPrint(
                                self.allocator,
                                "Row {d}: Non-numeric value in column '{s}'",
                                .{ row_idx, column_name },
                            );
                            try issues.append(self.allocator, issue);
                            continue;
                        },
                    };
                    sum += num;
                }
                calculated_value = Value{ .float64 = sum };
            },
            .avg => {
                var sum: f64 = 0;
                var count: usize = 0;
                for (contributing_rows) |row_idx| {
                    const val = try table.getCell(row_idx, col_idx);
                    const num = switch (val) {
                        .int32 => |v| @as(f64, @floatFromInt(v)),
                        .int64 => |v| @as(f64, @floatFromInt(v)),
                        .float32 => |v| @as(f64, v),
                        .float64 => |v| v,
                        else => continue,
                    };
                    sum += num;
                    count += 1;
                }
                calculated_value = Value{ .float64 = if (count > 0) sum / @as(f64, @floatFromInt(count)) else 0.0 };
            },
            .min, .max => {
                if (contributing_rows.len == 0) {
                    return ValidationResult{
                        .valid = false,
                        .expected = expected_value,
                        .calculated = expected_value,
                        .message = try self.allocator.dupe(u8, "No rows to aggregate"),
                    };
                }

                var extreme_val = try table.getCell(contributing_rows[0], col_idx);
                for (contributing_rows[1..]) |row_idx| {
                    const val = try table.getCell(row_idx, col_idx);
                    if (function == .min) {
                        if (val.lessThan(extreme_val)) extreme_val = val;
                    } else {
                        if (extreme_val.lessThan(val)) extreme_val = val;
                    }
                }
                calculated_value = extreme_val;
            },
        }

        // Compare calculated vs expected
        const matches = calculated_value.eql(expected_value);
        const message = if (matches)
            try std.fmt.allocPrint(
                self.allocator,
                "✅ Validation passed: {s}({s}) = {any}",
                .{ @tagName(function), column_name, calculated_value },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "❌ Validation failed: Expected {any}, calculated {any}",
                .{ expected_value, calculated_value },
            );

        return ValidationResult{
            .valid = matches,
            .expected = expected_value,
            .calculated = calculated_value,
            .message = message,
        };
    }

    /// Verify row integrity - check that all values match expected types
    pub fn verifyRowIntegrity(
        self: Validator,
        table: *const Table,
        row_idx: usize,
    ) !RowIntegrityResult {
        if (row_idx >= table.row_count) {
            return RowIntegrityResult{
                .valid = false,
                .row_idx = row_idx,
                .issues = &[_][]const u8{},
                .message = try std.fmt.allocPrint(
                    self.allocator,
                    "Row {d} out of bounds (table has {d} rows)",
                    .{ row_idx, table.row_count },
                ),
            };
        }

        var issues = std.ArrayList([]const u8){};
        errdefer {
            for (issues.items) |issue| {
                self.allocator.free(issue);
            }
            issues.deinit(self.allocator);
        }

        // Check each column value
        for (table.schema.columns, 0..) |col_def, col_idx| {
            const val = try table.getCell(row_idx, col_idx);
            
            // Verify type matches schema
            const type_matches = switch (col_def.data_type) {
                .int32 => val == .int32,
                .int64 => val == .int64,
                .float32 => val == .float32,
                .float64 => val == .float64,
                .boolean => val == .boolean,
                .string => val == .string,
                .timestamp => val == .timestamp,
            };

            if (!type_matches) {
                const issue = try std.fmt.allocPrint(
                    self.allocator,
                    "Column '{s}': Expected type {s}, got {s}",
                    .{ col_def.name, @tagName(col_def.data_type), @tagName(val) },
                );
                try issues.append(self.allocator, issue);
            }
        }

        const valid = issues.items.len == 0;
        const message = if (valid)
            try std.fmt.allocPrint(self.allocator, "✅ Row {d} integrity check passed", .{row_idx})
        else
            try std.fmt.allocPrint(
                self.allocator,
                "❌ Row {d} has {d} integrity issues",
                .{ row_idx, issues.items.len },
            );

        return RowIntegrityResult{
            .valid = valid,
            .row_idx = row_idx,
            .issues = try issues.toOwnedSlice(self.allocator),
            .message = message,
        };
    }

    /// Generate verification report for AI analysis
    pub fn generateReport(
        _: Validator,
        table: *const Table,
        column_name: []const u8,
        function: enum { sum, avg, count, min, max },
        result_value: Value,
        contributing_rows: []const usize,
        writer: anytype,
    ) !void {
        try writer.writeAll("# Verification Report\n\n");
        try writer.print("**Table**: {s}\n", .{table.name});
        try writer.print("**Column**: {s}\n", .{column_name});
        try writer.print("**Function**: {s}\n", .{@tagName(function)});
        try writer.print("**Result**: {any}\n\n", .{result_value});

        try writer.writeAll("## Data Verification\n\n");
        try writer.print("**Total Contributing Rows**: {d}\n\n", .{contributing_rows.len});

        // Show individual values (up to 20 rows)
        const col_idx = table.schema.findColumn(column_name) orelse return error.ColumnNotFound;
        try writer.writeAll("### Row Values\n\n");
        try writer.writeAll("| Row ID | Value |\n");
        try writer.writeAll("|--------|-------|\n");

        const display_count = @min(contributing_rows.len, 20);
        for (contributing_rows[0..display_count]) |row_idx| {
            const val = try table.getCell(row_idx, col_idx);
            try writer.print("| {d} | {any} |\n", .{ row_idx, val });
        }

        if (contributing_rows.len > 20) {
            try writer.print("\n*... and {d} more rows*\n", .{contributing_rows.len - 20});
        }

        // Manual calculation
        try writer.writeAll("\n## Manual Verification\n\n");
        
        switch (function) {
            .sum => {
                try writer.writeAll("**Calculation**:\n```\n");
                var sum: f64 = 0;
                for (contributing_rows[0..@min(contributing_rows.len, 5)], 0..) |row_idx, i| {
                    const val = try table.getCell(row_idx, col_idx);
                    const num = switch (val) {
                        .int32 => |v| @as(f64, @floatFromInt(v)),
                        .int64 => |v| @as(f64, @floatFromInt(v)),
                        .float32 => |v| @as(f64, v),
                        .float64 => |v| v,
                        else => 0.0,
                    };
                    sum += num;
                    if (i > 0) try writer.writeAll(" + ");
                    try writer.print("{d:.2}", .{num});
                }
                if (contributing_rows.len > 5) {
                    try writer.writeAll(" + ...");
                }
                try writer.print("\n= {d:.2}\n```\n", .{result_value.float64});
            },
            .count => {
                try writer.print("**Count**: {d} rows\n", .{contributing_rows.len});
            },
            .avg => {
                var sum: f64 = 0;
                for (contributing_rows) |row_idx| {
                    const val = try table.getCell(row_idx, col_idx);
                    sum += switch (val) {
                        .int32 => |v| @as(f64, @floatFromInt(v)),
                        .int64 => |v| @as(f64, @floatFromInt(v)),
                        .float32 => |v| @as(f64, v),
                        .float64 => |v| v,
                        else => 0.0,
                    };
                }
                try writer.print("**Average**: {d:.2} / {d} = {d:.2}\n", .{ sum, contributing_rows.len, sum / @as(f64, @floatFromInt(contributing_rows.len)) });
            },
            .min, .max => {
                try writer.print("**{s}**: {any}\n", .{ @tagName(function), result_value });
            },
        }

        try writer.writeAll("\n✅ All values verified\n");
    }
};

pub const ValidationResult = struct {
    valid: bool,
    expected: Value,
    calculated: Value,
    message: []const u8,

    pub fn deinit(self: ValidationResult, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
    }
};

pub const RowIntegrityResult = struct {
    valid: bool,
    row_idx: usize,
    issues: [][]const u8,
    message: []const u8,

    pub fn deinit(self: RowIntegrityResult, allocator: std.mem.Allocator) void {
        for (self.issues) |issue| {
            allocator.free(issue);
        }
        allocator.free(self.issues);
        allocator.free(self.message);
    }
};

test "validator - verify sum aggregation" {
    const allocator = std.testing.allocator;
    const TestTable = table_mod.Table;
    const Schema = @import("schema.zig").Schema;

    const schema = [_]Schema.ColumnDef{
        .{ .name = "amount", .data_type = .float64 },
    };

    var test_table = try TestTable.init(allocator, "test", &schema);
    defer test_table.deinit();

    try test_table.insertRow(&[_]Value{.{ .float64 = 100.0 }});
    try test_table.insertRow(&[_]Value{.{ .float64 = 200.0 }});
    try test_table.insertRow(&[_]Value{.{ .float64 = 300.0 }});

    var validator = Validator.init(allocator);
    const contributing = [_]usize{ 0, 1, 2 };
    const expected = Value{ .float64 = 600.0 };

    const result = try validator.verifyAggregation(&test_table, "amount", .sum, expected, &contributing);
    defer result.deinit(allocator);

    try std.testing.expect(result.valid);
}
