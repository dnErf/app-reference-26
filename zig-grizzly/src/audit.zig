const std = @import("std");
const types = @import("types.zig");
const Value = types.Value;

/// Audit log entry for database operations
pub const AuditEntry = struct {
    timestamp: i64,
    operation: Operation,
    table_name: []const u8,
    details: []const u8,
    affected_rows: usize,
    user_context: ?[]const u8,

    pub const Operation = enum {
        create_table,
        insert,
        select,
        aggregate,
        filter,
        data_export,
        optimizer,
        create_view,
        create_materialized_view,
        create_model,
        create_type,
        refresh_materialized_view,
        drop_view,
        drop_materialized_view,
        drop_model,
    };

    pub fn format(
        self: AuditEntry,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "[{d}] {s} on '{s}': {s} (rows: {d})",
            .{ self.timestamp, @tagName(self.operation), self.table_name, self.details, self.affected_rows },
        );
    }
};

/// Audit log for tracking all database operations
pub const AuditLog = struct {
    entries: std.ArrayList(AuditEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AuditLog {
        return .{
            .entries = std.ArrayList(AuditEntry){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AuditLog) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.table_name);
            self.allocator.free(entry.details);
            if (entry.user_context) |ctx| {
                self.allocator.free(ctx);
            }
        }
        self.entries.deinit(self.allocator);
    }

    pub fn log(
        self: *AuditLog,
        operation: AuditEntry.Operation,
        table_name: []const u8,
        details: []const u8,
        affected_rows: usize,
        user_context: ?[]const u8,
    ) !void {
        const entry = AuditEntry{
            .timestamp = std.time.timestamp(),
            .operation = operation,
            .table_name = try self.allocator.dupe(u8, table_name),
            .details = try self.allocator.dupe(u8, details),
            .affected_rows = affected_rows,
            .user_context = if (user_context) |ctx| try self.allocator.dupe(u8, ctx) else null,
        };
        try self.entries.append(self.allocator, entry);
    }

    /// Export audit log to JSON for AI analysis
    pub fn exportJSON(self: AuditLog, writer: anytype) !void {
        try writer.writeAll("{\n  \"audit_entries\": [\n");
        for (self.entries.items, 0..) |entry, i| {
            try writer.writeAll("    {\n");
            try writer.print("      \"timestamp\": {d},\n", .{entry.timestamp});
            try writer.print("      \"operation\": \"{s}\",\n", .{@tagName(entry.operation)});
            try writer.print("      \"table\": \"{s}\",\n", .{entry.table_name});
            try writer.print("      \"details\": \"{s}\",\n", .{entry.details});
            try writer.print("      \"affected_rows\": {d}", .{entry.affected_rows});
            if (entry.user_context) |ctx| {
                try writer.print(",\n      \"context\": \"{s}\"\n", .{ctx});
            } else {
                try writer.writeAll("\n");
            }
            if (i < self.entries.items.len - 1) {
                try writer.writeAll("    },\n");
            } else {
                try writer.writeAll("    }\n");
            }
        }
        try writer.writeAll("  ]\n}\n");
    }

    /// Get operations for a specific table
    pub fn getTableHistory(self: AuditLog, table_name: []const u8, allocator: std.mem.Allocator) ![]AuditEntry {
        var result = std.ArrayList(AuditEntry){};
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.table_name, table_name)) {
                try result.append(allocator, entry);
            }
        }
        return result.toOwnedSlice(allocator);
    }
};

/// Query execution trace for explainability
pub const QueryTrace = struct {
    query: []const u8,
    steps: std.ArrayList(Step),
    final_result: ?Result,
    allocator: std.mem.Allocator,

    pub const Step = struct {
        step_num: usize,
        operation: []const u8,
        input_rows: usize,
        output_rows: usize,
        duration_ms: f64,
        details: []const u8,
    };

    pub const Result = struct {
        row_count: usize,
        aggregation_value: ?Value,
        contributing_rows: ?[]usize, // Which rows contributed to result
    };

    pub fn init(allocator: std.mem.Allocator, query: []const u8) !QueryTrace {
        return .{
            .query = try allocator.dupe(u8, query),
            .steps = std.ArrayList(Step){},
            .final_result = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QueryTrace) void {
        self.allocator.free(self.query);
        for (self.steps.items) |step| {
            self.allocator.free(step.operation);
            self.allocator.free(step.details);
        }
        self.steps.deinit(self.allocator);
        if (self.final_result) |result| {
            if (result.contributing_rows) |rows| {
                self.allocator.free(rows);
            }
        }
    }

    pub fn addStep(
        self: *QueryTrace,
        operation: []const u8,
        input_rows: usize,
        output_rows: usize,
        duration_ms: f64,
        details: []const u8,
    ) !void {
        const step = Step{
            .step_num = self.steps.items.len + 1,
            .operation = try self.allocator.dupe(u8, operation),
            .input_rows = input_rows,
            .output_rows = output_rows,
            .duration_ms = duration_ms,
            .details = try self.allocator.dupe(u8, details),
        };
        try self.steps.append(self.allocator, step);
    }

    pub fn setResult(
        self: *QueryTrace,
        row_count: usize,
        aggregation_value: ?Value,
        contributing_rows: ?[]const usize,
    ) !void {
        self.final_result = Result{
            .row_count = row_count,
            .aggregation_value = aggregation_value,
            .contributing_rows = if (contributing_rows) |rows| try self.allocator.dupe(usize, rows) else null,
        };
    }

    /// Export trace to JSON for AI analysis
    pub fn exportJSON(self: QueryTrace, writer: anytype) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"query\": \"{s}\",\n", .{self.query});
        try writer.writeAll("  \"execution_steps\": [\n");

        for (self.steps.items, 0..) |step, i| {
            try writer.writeAll("    {\n");
            try writer.print("      \"step\": {d},\n", .{step.step_num});
            try writer.print("      \"operation\": \"{s}\",\n", .{step.operation});
            try writer.print("      \"input_rows\": {d},\n", .{step.input_rows});
            try writer.print("      \"output_rows\": {d},\n", .{step.output_rows});
            try writer.print("      \"duration_ms\": {d:.2},\n", .{step.duration_ms});
            try writer.print("      \"details\": \"{s}\"\n", .{step.details});
            if (i < self.steps.items.len - 1) {
                try writer.writeAll("    },\n");
            } else {
                try writer.writeAll("    }\n");
            }
        }

        try writer.writeAll("  ]");

        if (self.final_result) |result| {
            try writer.writeAll(",\n  \"result\": {\n");
            try writer.print("    \"row_count\": {d}", .{result.row_count});
            if (result.aggregation_value) |val| {
                try writer.writeAll(",\n    \"value\": ");
                switch (val) {
                    .int32 => |v| try writer.print("{d}", .{v}),
                    .int64 => |v| try writer.print("{d}", .{v}),
                    .float32 => |v| try writer.print("{d:.2}", .{v}),
                    .float64 => |v| try writer.print("{d:.2}", .{v}),
                    .boolean => |v| try writer.print("{}", .{v}),
                    .string => |v| try writer.print("\"{s}\"", .{v}),
                    .timestamp => |v| try writer.print("{d}", .{v}),
                }
            }
            if (result.contributing_rows) |rows| {
                try writer.writeAll(",\n    \"contributing_rows\": [");
                for (rows, 0..) |row_id, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try writer.print("{d}", .{row_id});
                }
                try writer.writeAll("]");
            }
            try writer.writeAll("\n  }");
        }

        try writer.writeAll("\n}\n");
    }

    /// Generate human-readable explanation for AI
    pub fn explain(self: QueryTrace, writer: anytype) !void {
        try writer.print("# Query Execution Explanation\n\n", .{});
        try writer.print("**Query**: `{s}`\n\n", .{self.query});
        try writer.writeAll("## Execution Steps\n\n");

        for (self.steps.items) |step| {
            try writer.print(
                "{d}. **{s}**: Processed {d} rows → {d} rows ({d:.2}ms)\n   - {s}\n\n",
                .{ step.step_num, step.operation, step.input_rows, step.output_rows, step.duration_ms, step.details },
            );
        }

        if (self.final_result) |result| {
            try writer.writeAll("## Final Result\n\n");
            try writer.print("- **Total Rows**: {d}\n", .{result.row_count});
            if (result.aggregation_value) |val| {
                try writer.writeAll("- **Value**: ");
                switch (val) {
                    .int32 => |v| try writer.print("{d}\n", .{v}),
                    .int64 => |v| try writer.print("{d}\n", .{v}),
                    .float32 => |v| try writer.print("{d:.2}\n", .{v}),
                    .float64 => |v| try writer.print("{d:.2}\n", .{v}),
                    .boolean => |v| try writer.print("{}\n", .{v}),
                    .string => |v| try writer.print("\"{s}\"\n", .{v}),
                    .timestamp => |v| try writer.print("{d}\n", .{v}),
                }
            }
            if (result.contributing_rows) |rows| {
                try writer.print("- **Based on rows**: {} rows contributed to this result\n", .{rows.len});
                if (rows.len <= 10) {
                    try writer.writeAll("- **Row IDs**: ");
                    for (rows, 0..) |row_id, i| {
                        if (i > 0) try writer.writeAll(", ");
                        try writer.print("{d}", .{row_id});
                    }
                    try writer.writeAll("\n");
                }
            }
        }
    }
};

test "audit log basic operations" {
    const allocator = std.testing.allocator;
    var audit_log = AuditLog.init(allocator);
    defer audit_log.deinit();

    try audit_log.log(.create_table, "sales", "Created sales table with 5 columns", 0, "admin");
    try audit_log.log(.insert, "sales", "Bulk insert", 100, "etl_job");
    try audit_log.log(.aggregate, "sales", "SUM(amount)", 100, "ceo_dashboard");

    try std.testing.expectEqual(@as(usize, 3), audit_log.entries.items.len);
    try std.testing.expectEqual(AuditEntry.Operation.create_table, audit_log.entries.items[0].operation);
}

test "query trace" {
    const allocator = std.testing.allocator;
    var trace = try QueryTrace.init(allocator, "SELECT SUM(amount) FROM sales WHERE year = 2024");
    defer trace.deinit();

    try trace.addStep("Table Scan", 10000, 10000, 5.2, "Read sales table");
    try trace.addStep("Filter", 10000, 3500, 2.1, "year = 2024");
    try trace.addStep("Aggregate", 3500, 1, 0.8, "SUM(amount)");

    const contributing = [_]usize{ 0, 1, 2, 3, 4 };
    try trace.setResult(1, Value{ .float64 = 1250000.50 }, &contributing);

    try std.testing.expectEqual(@as(usize, 3), trace.steps.items.len);
    try std.testing.expect(trace.final_result != null);
}
