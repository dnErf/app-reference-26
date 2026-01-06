const std = @import("std");
const Database = @import("database.zig").Database;
const QueryEngine = @import("query.zig").QueryEngine;
const QueryResult = @import("query.zig").QueryResult;
const Value = @import("types.zig").Value;

/// Data quality test framework inspired by dbt tests
pub const TestEngine = struct {
    allocator: std.mem.Allocator,
    db: *Database,

    pub const TestResult = struct {
        test_name: []const u8,
        model_name: []const u8,
        passed: bool,
        failure_count: u64,
        total_count: u64,
        error_message: ?[]const u8,
        executed_at: i64,

        pub fn deinit(self: *TestResult, allocator: std.mem.Allocator) void {
            allocator.free(self.test_name);
            allocator.free(self.model_name);
            if (self.error_message) |msg| {
                allocator.free(msg);
            }
        }
    };

    pub const TestDefinition = struct {
        name: []const u8,
        model_name: []const u8,
        test_type: TestType,
        config: TestConfig,

        pub const TestType = enum {
            not_null,
            unique,
            accepted_values,
            relationships,
            custom,
        };

        pub const TestConfig = union(TestType) {
            not_null: struct {
                column: []const u8,
            },
            unique: struct {
                columns: [][]const u8,
            },
            accepted_values: struct {
                column: []const u8,
                values: []Value,
            },
            relationships: struct {
                column: []const u8,
                ref_model: []const u8,
                ref_column: []const u8,
            },
            custom: struct {
                sql: []const u8,
            },
        };

        pub fn deinit(self: *TestDefinition, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.model_name);
            switch (self.config) {
                .not_null => |config| allocator.free(config.column),
                .unique => |config| {
                    for (config.columns) |col| allocator.free(col);
                    allocator.free(config.columns);
                },
                .accepted_values => |config| {
                    allocator.free(config.column);
                    allocator.free(config.values);
                },
                .relationships => |config| {
                    allocator.free(config.column);
                    allocator.free(config.ref_model);
                    allocator.free(config.ref_column);
                },
                .custom => |config| allocator.free(config.sql),
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator, db: *Database) TestEngine {
        return TestEngine{
            .allocator = allocator,
            .db = db,
        };
    }

    /// Run a single test definition
    pub fn runTest(self: *TestEngine, test_def: TestDefinition) !TestResult {
        const result = switch (test_def.test_type) {
            .not_null => try self.runNotNullTest(test_def),
            .unique => try self.runUniqueTest(test_def),
            .accepted_values => try self.runAcceptedValuesTest(test_def),
            .relationships => try self.runRelationshipsTest(test_def),
            .custom => try self.runCustomTest(test_def),
        };

        return result;
    }

    /// Run all tests for a specific model
    pub fn runModelTests(self: *TestEngine, model_name: []const u8, tests: []const TestDefinition) ![]TestResult {
        var results = try std.ArrayList(TestResult).initCapacity(self.allocator, tests.len);
        errdefer {
            for (results.items) |*result| {
                result.deinit(self.allocator);
            }
            results.deinit();
        }

        for (tests) |test_def| {
            if (std.mem.eql(u8, test_def.model_name, model_name)) {
                const result = try self.runTest(test_def);
                try results.append(result);
            }
        }

        return results.toOwnedSlice();
    }

    fn runNotNullTest(self: *TestEngine, test_def: TestDefinition) !TestResult {
        const config = test_def.config.not_null;
        const sql = try std.fmt.allocPrint(self.allocator,
            \\SELECT COUNT(*) as null_count
            \\FROM {} WHERE {} IS NULL
        , .{ std.zig.fmtId(test_def.model_name), std.zig.fmtId(config.column) });
        defer self.allocator.free(sql);

        var query_engine = QueryEngine.init(self.allocator, self.db);
        defer query_engine.deinit();

        const result = try query_engine.execute(sql);
        const null_count = switch (result) {
            .rows => |rows| if (rows.len > 0) blk: {
                const count_val = rows[0].getColumn(0) orelse break :blk 0;
                break :blk switch (count_val) {
                    .int32 => |v| @as(u64, @intCast(v)),
                    .int64 => |v| @as(u64, @intCast(v)),
                    else => 0,
                };
            } else 0,
            else => 0,
        };

        const passed = null_count == 0;
        const error_msg = if (!passed)
            try std.fmt.allocPrint(self.allocator, "Found {} null values in column {}", .{ null_count, config.column })
        else
            null;

        return TestResult{
            .test_name = try self.allocator.dupe(u8, test_def.name),
            .model_name = try self.allocator.dupe(u8, test_def.model_name),
            .passed = passed,
            .failure_count = null_count,
            .total_count = null_count, // For not_null, total_count is the null count
            .error_message = error_msg,
            .executed_at = std.time.timestamp(),
        };
    }

    fn runUniqueTest(self: *TestEngine, test_def: TestDefinition) !TestResult {
        const config = test_def.config.unique;
        var sql_builder = std.ArrayList(u8).init(self.allocator);
        defer sql_builder.deinit();

        try sql_builder.writer().print("SELECT ", .{});
        for (config.columns, 0..) |col, i| {
            if (i > 0) try sql_builder.writer().print(", ", .{});
            try sql_builder.writer().print("{}", .{std.zig.fmtId(col)});
        }
        try sql_builder.writer().print(", COUNT(*) as cnt FROM {} GROUP BY ", .{std.zig.fmtId(test_def.model_name)});
        for (config.columns, 0..) |col, i| {
            if (i > 0) try sql_builder.writer().print(", ", .{});
            try sql_builder.writer().print("{}", .{std.zig.fmtId(col)});
        }
        try sql_builder.writer().print(" HAVING COUNT(*) > 1", .{});

        const sql = try sql_builder.toOwnedSlice();
        defer self.allocator.free(sql);

        var query_engine = QueryEngine.init(self.allocator, self.db);
        defer query_engine.deinit();

        const result = try query_engine.execute(sql);
        const duplicate_count = switch (result) {
            .rows => |rows| @as(u64, rows.len),
            else => 0,
        };

        const passed = duplicate_count == 0;
        const error_msg = if (!passed)
            try std.fmt.allocPrint(self.allocator, "Found {} duplicate combinations", .{duplicate_count})
        else
            null;

        return TestResult{
            .test_name = try self.allocator.dupe(u8, test_def.name),
            .model_name = try self.allocator.dupe(u8, test_def.model_name),
            .passed = passed,
            .failure_count = duplicate_count,
            .total_count = duplicate_count,
            .error_message = error_msg,
            .executed_at = std.time.timestamp(),
        };
    }

    fn runAcceptedValuesTest(self: *TestEngine, test_def: TestDefinition) !TestResult {
        const config = test_def.config.accepted_values;
        var sql_builder = std.ArrayList(u8).init(self.allocator);
        defer sql_builder.deinit();

        try sql_builder.writer().print("SELECT COUNT(*) as invalid_count FROM {} WHERE {} NOT IN (", .{ std.zig.fmtId(test_def.model_name), std.zig.fmtId(config.column) });

        for (config.values, 0..) |val, i| {
            if (i > 0) try sql_builder.writer().print(", ", .{});
            switch (val) {
                .string => |s| try sql_builder.writer().print("'{}'", .{std.zig.fmtEscapes(s)}),
                .int32 => |v| try sql_builder.writer().print("{}", .{v}),
                .int64 => |v| try sql_builder.writer().print("{}", .{v}),
                .float32 => |v| try sql_builder.writer().print("{d}", .{v}),
                .float64 => |v| try sql_builder.writer().print("{d}", .{v}),
                .bool => |v| try sql_builder.writer().print("{}", .{v}),
                else => try sql_builder.writer().print("NULL", .{}),
            }
        }
        try sql_builder.writer().print(")", .{});

        const sql = try sql_builder.toOwnedSlice();
        defer self.allocator.free(sql);

        var query_engine = QueryEngine.init(self.allocator, self.db);
        defer query_engine.deinit();

        const result = try query_engine.execute(sql);
        const invalid_count = switch (result) {
            .rows => |rows| if (rows.len > 0) blk: {
                const count_val = rows[0].getColumn(0) orelse break :blk 0;
                break :blk switch (count_val) {
                    .int32 => |v| @as(u64, @intCast(v)),
                    .int64 => |v| @as(u64, @intCast(v)),
                    else => 0,
                };
            } else 0,
            else => 0,
        };

        const passed = invalid_count == 0;
        const error_msg = if (!passed)
            try std.fmt.allocPrint(self.allocator, "Found {} values not in accepted list", .{invalid_count})
        else
            null;

        return TestResult{
            .test_name = try self.allocator.dupe(u8, test_def.name),
            .model_name = try self.allocator.dupe(u8, test_def.model_name),
            .passed = passed,
            .failure_count = invalid_count,
            .total_count = invalid_count,
            .error_message = error_msg,
            .executed_at = std.time.timestamp(),
        };
    }

    fn runRelationshipsTest(self: *TestEngine, test_def: TestDefinition) !TestResult {
        const config = test_def.config.relationships;
        const sql = try std.fmt.allocPrint(self.allocator,
            \\SELECT COUNT(*) as orphan_count
            \\FROM {} m
            \\LEFT JOIN {} r ON m.{} = r.{}
            \\WHERE r.{} IS NULL
        , .{
            std.zig.fmtId(test_def.model_name),
            std.zig.fmtId(config.ref_model),
            std.zig.fmtId(config.column),
            std.zig.fmtId(config.ref_column),
            std.zig.fmtId(config.ref_column),
        });
        defer self.allocator.free(sql);

        var query_engine = QueryEngine.init(self.allocator, self.db);
        defer query_engine.deinit();

        const result = try query_engine.execute(sql);
        const orphan_count = switch (result) {
            .rows => |rows| if (rows.len > 0) blk: {
                const count_val = rows[0].getColumn(0) orelse break :blk 0;
                break :blk switch (count_val) {
                    .int32 => |v| @as(u64, @intCast(v)),
                    .int64 => |v| @as(u64, @intCast(v)),
                    else => 0,
                };
            } else 0,
            else => 0,
        };

        const passed = orphan_count == 0;
        const error_msg = if (!passed)
            try std.fmt.allocPrint(self.allocator, "Found {} orphaned records", .{orphan_count})
        else
            null;

        return TestResult{
            .test_name = try self.allocator.dupe(u8, test_def.name),
            .model_name = try self.allocator.dupe(u8, test_def.model_name),
            .passed = passed,
            .failure_count = orphan_count,
            .total_count = orphan_count,
            .error_message = error_msg,
            .executed_at = std.time.timestamp(),
        };
    }

    fn runCustomTest(self: *TestEngine, test_def: TestDefinition) !TestResult {
        const config = test_def.config.custom;

        var query_engine = QueryEngine.init(self.allocator, self.db);
        defer query_engine.deinit();

        const result = try query_engine.execute(config.sql);
        const failure_count = switch (result) {
            .rows => |rows| if (rows.len > 0) blk: {
                const count_val = rows[0].getColumn(0) orelse break :blk 0;
                break :blk switch (count_val) {
                    .int32 => |v| @as(u64, @intCast(v)),
                    .int64 => |v| @as(u64, @intCast(v)),
                    else => 0,
                };
            } else 0,
            else => 0,
        };

        const passed = failure_count == 0;
        const error_msg = if (!passed)
            try std.fmt.allocPrint(self.allocator, "Custom test failed with {} violations", .{failure_count})
        else
            null;

        return TestResult{
            .test_name = try self.allocator.dupe(u8, test_def.name),
            .model_name = try self.allocator.dupe(u8, test_def.model_name),
            .passed = passed,
            .failure_count = failure_count,
            .total_count = failure_count,
            .error_message = error_msg,
            .executed_at = std.time.timestamp(),
        };
    }
};
