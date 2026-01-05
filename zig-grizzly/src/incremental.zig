const std = @import("std");
const Database = @import("database.zig").Database;
const Model = @import("model.zig").Model;
const Value = @import("types.zig").Value;
const QueryEngine = @import("query.zig").QueryEngine;
const QueryResult = @import("query.zig").QueryResult;
const Table = @import("table.zig").Table;

/// Incremental refresh engine for processing only new/changed data
pub const IncrementalEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IncrementalEngine {
        return IncrementalEngine{
            .allocator = allocator,
        };
    }

    /// Execute an incremental model refresh
    /// Modifies the SQL query to include incremental WHERE clauses
    pub fn executeIncrementalModel(model: *Model, db: *Database) !*Table {
        if (!model.is_incremental) {
            // For non-incremental models, execute directly
            var engine = @import("query.zig").QueryEngine.init(db.allocator, db, &db.functions);

            const start_time = std.time.milliTimestamp();
            const result = try engine.execute(model.sql_definition);

            model.materialized_result = result;
            const end_time = std.time.milliTimestamp();
            const execution_time = @as(u64, @intCast(end_time - start_time));

            switch (result) {
                .table => |*table| {
                    model.last_run = end_time;
                    model.row_count = table.row_count;
                    model.execution_time_ms = execution_time;
                    return @constCast(table);
                },
                .message => return error.ModelExecutionFailed,
                .rows_affected => return error.ModelExecutionReturnedRowsAffected,
            }
        }

        // Generate incremental SQL with WHERE clause
        const incremental_sql = try generateIncrementalSQLInternal(model, db.allocator);
        defer db.allocator.free(incremental_sql);

        // Execute the modified query
        var engine = QueryEngine.init(db.allocator, db, &db.functions);

        const start_time = std.time.milliTimestamp();
        const result = try engine.execute(incremental_sql);

        // Store the result to keep the table alive
        model.materialized_result = result;

        const end_time = std.time.milliTimestamp();
        const execution_time = @as(u64, @intCast(end_time - start_time));

        switch (result) {
            .table => |*table| {
                // Update metadata
                model.last_run = end_time;
                model.row_count = table.row_count;
                model.execution_time_ms = execution_time;

                // Update incremental state - find the max partition value from the result
                try updateIncrementalState(model, table);

                return @constCast(table);
            },
            .message => return error.IncrementalExecutionFailed,
            .rows_affected => return error.IncrementalExecutionReturnedRowsAffected,
        }
    }

    /// Generate incremental SQL by adding WHERE clause based on last partition value
    pub fn generateIncrementalSQL(_: *IncrementalEngine, model: *const Model, allocator: std.mem.Allocator) ![]const u8 {
        return generateIncrementalSQLInternal(model, allocator);
    }

    /// Generate incremental SQL by adding WHERE clause based on last partition value
    fn generateIncrementalSQLInternal(model: *const Model, allocator: std.mem.Allocator) ![]const u8 {
        if (model.partition_column == null) {
            return error.NoPartitionColumn;
        }

        const partition_col = model.partition_column.?;

        // Find the position to insert WHERE clause (before ORDER BY, LIMIT, etc.)
        const sql = model.sql_definition;
        var insert_pos = sql.len;

        // Look for clauses that should come after WHERE
        const clauses_to_check = [_][]const u8{ " ORDER BY ", " LIMIT ", " GROUP BY ", " HAVING " };
        for (clauses_to_check) |clause| {
            if (std.mem.indexOf(u8, sql, clause)) |pos| {
                if (pos < insert_pos) {
                    insert_pos = pos;
                }
            }
        }

        // Check if there's already a WHERE clause
        const has_where = std.mem.indexOf(u8, sql, " WHERE ") != null;
        const where_keyword = if (has_where) " AND " else " WHERE ";

        // Generate the WHERE condition based on last partition value
        var condition_buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer condition_buf.deinit(allocator);

        try condition_buf.writer(allocator).print("{s} > ", .{partition_col});

        if (model.last_partition_value) |last_val| {
            switch (last_val) {
                .int32 => |val| try condition_buf.writer(allocator).print("{}", .{val}),
                .int64 => |val| try condition_buf.writer(allocator).print("{}", .{val}),
                .float32 => |val| try condition_buf.writer(allocator).print("{}", .{val}),
                .float64 => |val| try condition_buf.writer(allocator).print("{}", .{val}),
                .string => |val| try condition_buf.writer(allocator).print("'{s}'", .{val}),
                .boolean => |val| try condition_buf.writer(allocator).print("{}", .{val}),
                .timestamp => |val| try condition_buf.writer(allocator).print("{}", .{val}),
                .vector => try condition_buf.writer(allocator).print("'vector'", .{}), // Not supported for partitioning
                .custom => try condition_buf.writer(allocator).print("'custom'", .{}), // Not supported for partitioning
                .exception => try condition_buf.writer(allocator).print("'exception'", .{}), // Not supported for partitioning
            }
        } else {
            // First run - no WHERE clause needed, process all data
            return try allocator.dupe(u8, sql);
        }

        // Build the new SQL
        var new_sql = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer new_sql.deinit(allocator);

        // Add everything before the insert position
        try new_sql.appendSlice(allocator, sql[0..insert_pos]);

        // Add the WHERE/AND condition
        try new_sql.appendSlice(allocator, where_keyword);
        try new_sql.appendSlice(allocator, condition_buf.items);

        // Add everything after the insert position
        if (insert_pos < sql.len) {
            try new_sql.appendSlice(allocator, sql[insert_pos..]);
        }

        return new_sql.toOwnedSlice(allocator);
    }

    /// Update the incremental state after successful execution
    fn updateIncrementalState(model: *Model, table: *const Table) !void {
        if (model.partition_column == null) return;

        const partition_col = model.partition_column.?;

        // Find the partition column index in the result table
        var partition_col_index: ?usize = null;
        for (table.schema.columns, 0..) |col_def, i| {
            if (std.mem.eql(u8, col_def.name, partition_col)) {
                partition_col_index = i;
                break;
            }
        }

        if (partition_col_index == null) {
            return error.PartitionColumnNotFound;
        }

        const col_idx = partition_col_index.?;

        // Find the maximum value in the partition column
        var max_value: ?Value = null;
        for (0..table.row_count) |row_idx| {
            const value = try table.getCell(row_idx, col_idx);
            if (max_value == null) {
                max_value = value; // First value
            } else {
                // Compare and keep the maximum
                if (compareValues(value, max_value.?)) |is_greater| {
                    if (is_greater) {
                        max_value = value; // Keep the greater value
                    }
                }
            }
        }

        // Update the model's last partition value
        if (model.last_partition_value) |_| {
            // Value is a union of primitives and slices, no deinit needed for simple types
        }
        model.last_partition_value = max_value;
    }

    /// Compare two values to determine which is greater
    /// Returns true if a > b, false if a <= b, null if incomparable
    fn compareValues(a: Value, b: Value) ?bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) {
            return null; // Different types, incomparable
        }

        switch (a) {
            .int32 => return a.int32 > b.int32,
            .int64 => return a.int64 > b.int64,
            .float32 => return a.float32 > b.float32,
            .float64 => return a.float64 > b.float64,
            .string => return std.mem.order(u8, a.string, b.string) == .gt,
            .timestamp => return a.timestamp > b.timestamp,
            .boolean => return if (a.boolean and !b.boolean) true else false,
            .vector => return false, // vectors not comparable for partitioning
            .custom => return null, // custom types not comparable for partitioning
            .exception => return null, // exception types not comparable for partitioning
        }
    }
};

/// Incremental state persistence
pub const IncrementalState = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IncrementalState {
        return IncrementalState{
            .allocator = allocator,
        };
    }

    /// Save incremental state to disk
    pub fn saveState(model: *const Model, path: []const u8) !void {
        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        var writer = file.writer(&buf);

        // Write JSON-like structure
        try writer.interface.print("{{\n", .{});
        try writer.interface.print("  \"name\": \"{s}\",\n", .{model.name});
        try writer.interface.print("  \"is_incremental\": {},\n", .{model.is_incremental});

        if (model.partition_column) |col| {
            try writer.interface.print("  \"partition_column\": \"{s}\",\n", .{col});
        } else {
            try writer.interface.print("  \"partition_column\": null,\n", .{});
        }

        if (model.last_partition_value) |val| {
            try writer.interface.print("  \"last_partition_value\": ", .{});
            switch (val) {
                .int32 => |v| try writer.interface.print("{}", .{v}),
                .int64 => |v| try writer.interface.print("{}", .{v}),
                .float32 => |v| try writer.interface.print("{}", .{v}),
                .float64 => |v| try writer.interface.print("{}", .{v}),
                .string => |v| try writer.interface.print("\"{s}\"", .{v}),
                .boolean => |v| try writer.interface.print("{}", .{v}),
                .timestamp => |v| try writer.interface.print("{}", .{v}),
                .vector => try writer.interface.print("\"<vector>\"", .{}),
            }
            try writer.interface.print(",\n", .{});
        } else {
            try writer.interface.print("  \"last_partition_value\": null,\n", .{});
        }

        try writer.interface.print("  \"last_run\": ", .{});
        if (model.last_run) |ts| {
            try writer.interface.print("{}", .{ts});
        } else {
            try writer.interface.print("null", .{});
        }
        try writer.interface.print("\n", .{});
        try writer.interface.print("}}\n", .{});
    }

    /// Load incremental state from disk
    pub fn loadState(allocator: std.mem.Allocator, model: *Model, path: []const u8) !void {
        const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        defer allocator.free(content);

        // Simple JSON parsing (in production, use a proper JSON parser)
        var lines = std.mem.splitSequence(u8, content, "\n");

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t,");
            if (std.mem.startsWith(u8, trimmed, "\"last_partition_value\":")) {
                const value_str = std.mem.trim(u8, trimmed["\"last_partition_value\": ".len..], " ");
                if (!std.mem.eql(u8, value_str, "null")) {
                    // Parse the value (simplified - in production use proper JSON parsing)
                    if (std.mem.startsWith(u8, value_str, "\"") and std.mem.endsWith(u8, value_str, "\"")) {
                        const str_val = value_str[1 .. value_str.len - 1];
                        model.last_partition_value = Value{ .string = try allocator.dupe(u8, str_val) };
                    } else {
                        if (std.fmt.parseInt(i64, value_str, 10)) |int_val| {
                            model.last_partition_value = Value{ .int64 = int_val };
                        } else |_| {
                            // Skip parsing errors for now
                        }
                    }
                }
            } else if (std.mem.startsWith(u8, trimmed, "\"last_run\":")) {
                const value_str = std.mem.trim(u8, trimmed["\"last_run\": ".len..], " ");
                if (!std.mem.eql(u8, value_str, "null")) {
                    if (std.fmt.parseInt(i64, value_str, 10)) |ts| {
                        model.last_run = ts;
                    } else |_| {
                        // Skip parsing errors for now
                    }
                }
            }
        }
    }
};
