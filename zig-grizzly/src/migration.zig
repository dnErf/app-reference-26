const std = @import("std");
const storage_engine = @import("storage_engine.zig");
const types = @import("types.zig");
const query_mod = @import("query.zig");

const StorageEngine = storage_engine.StorageEngine;
const MigrationResult = storage_engine.MigrationResult;
const Value = types.Value;

/// Data migration engine for moving data between storage engines
pub const MigrationEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MigrationEngine {
        return MigrationEngine{
            .allocator = allocator,
        };
    }

    /// Migrate data from one storage engine to another
    pub fn migrateData(self: MigrationEngine, from_engine: *StorageEngine, to_engine: *StorageEngine, table_name: []const u8) !MigrationResult {
        const start_time = std.time.milliTimestamp();

        var result = MigrationResult{
            .success = false,
            .bytes_migrated = 0,
            .duration_ms = 0,
            .error_message = null,
        };

        // Step 1: Extract data from source engine
        const extract_query = try std.fmt.allocPrint(self.allocator, "SELECT * FROM {s}", .{table_name});
        defer self.allocator.free(extract_query);

        const data = try from_engine.query(extract_query, self.allocator);
        defer {
            for (data) |*value| {
                value.deinit(self.allocator);
            }
            self.allocator.free(data);
        }

        if (data.len == 0) {
            result.success = true;
            result.duration_ms = @intCast(std.time.milliTimestamp() - start_time);
            return result;
        }

        // Step 2: Transform data to insert format
        const insert_query = try self.buildInsertQuery(table_name, data);
        defer self.allocator.free(insert_query);

        // Step 3: Load data into target engine
        try to_engine.save(insert_query);

        // Step 4: Verify migration
        const verify_query = try std.fmt.allocPrint(self.allocator, "SELECT COUNT(*) FROM {s}", .{table_name});
        defer self.allocator.free(verify_query);

        const verify_result = try to_engine.query(verify_query, self.allocator);
        defer {
            for (verify_result) |*value| {
                value.deinit(self.allocator);
            }
            self.allocator.free(verify_result);
        }

        if (verify_result.len > 0) {
            // Assume first result is count
            const migrated_count = switch (verify_result[0]) {
                .int64 => |v| @as(usize, @intCast(v)),
                else => 0,
            };

            if (migrated_count == data.len) {
                result.success = true;
            } else {
                result.error_message = try std.fmt.allocPrint(self.allocator, "Migration verification failed: expected {} rows, got {}", .{ data.len, migrated_count });
            }
        }

        result.bytes_migrated = try estimateBytes(data);
        result.duration_ms = @intCast(std.time.milliTimestamp() - start_time);

        return result;
    }

    /// Migrate table schema and metadata
    pub fn migrateSchema(self: MigrationEngine, from_engine: *StorageEngine, to_engine: *StorageEngine, table_name: []const u8, schema: []const types.Column) !MigrationResult {
        _ = from_engine;
        const start_time = std.time.milliTimestamp();

        var result = MigrationResult{
            .success = false,
            .bytes_migrated = 0,
            .duration_ms = 0,
            .error_message = null,
        };

        // Build CREATE TABLE statement
        const create_query = try self.buildCreateTableQuery(table_name, schema);
        defer self.allocator.free(create_query);

        // Execute CREATE TABLE on target engine
        try to_engine.save(create_query);

        result.success = true;
        result.duration_ms = @intCast(std.time.milliTimestamp() - start_time);

        return result;
    }

    /// Perform incremental migration (only new/changed data)
    pub fn migrateIncremental(self: MigrationEngine, from_engine: *StorageEngine, to_engine: *StorageEngine, table_name: []const u8, last_sync_timestamp: u64) !MigrationResult {
        const start_time = std.time.milliTimestamp();

        var result = MigrationResult{
            .success = false,
            .bytes_migrated = 0,
            .duration_ms = 0,
            .error_message = null,
        };

        // Query for data modified since last sync
        const extract_query = try std.fmt.allocPrint(self.allocator, "SELECT * FROM {s} WHERE updated_at > {}", .{ table_name, last_sync_timestamp });
        defer self.allocator.free(extract_query);

        const data = try from_engine.query(extract_query, self.allocator);
        defer {
            for (data) |*value| {
                value.deinit(self.allocator);
            }
            self.allocator.free(data);
        }

        if (data.len == 0) {
            result.success = true;
            result.duration_ms = @intCast(std.time.milliTimestamp() - start_time);
            return result;
        }

        // Insert new data (assume UPSERT semantics)
        const upsert_query = try self.buildUpsertQuery(table_name, data);
        defer self.allocator.free(upsert_query);

        try to_engine.save(upsert_query);

        result.success = true;
        result.bytes_migrated = try estimateBytes(data);
        result.duration_ms = @intCast(std.time.milliTimestamp() - start_time);

        return result;
    }

    /// Validate data integrity after migration
    pub fn validateMigration(self: MigrationEngine, source_engine: *StorageEngine, target_engine: *StorageEngine, table_name: []const u8) !bool {
        // Compare row counts
        const source_count_query = try std.fmt.allocPrint(self.allocator, "SELECT COUNT(*) FROM {s}", .{table_name});
        defer self.allocator.free(source_count_query);

        const target_count_query = try std.fmt.allocPrint(self.allocator, "SELECT COUNT(*) FROM {s}", .{table_name});
        defer self.allocator.free(target_count_query);

        const source_count_result = try source_engine.query(source_count_query, self.allocator);
        defer {
            for (source_count_result) |value| {
                value.deinit(self.allocator);
            }
            self.allocator.free(source_count_result);
        }

        const target_count_result = try target_engine.query(target_count_query, self.allocator);
        defer {
            for (target_count_result) |value| {
                value.deinit(self.allocator);
            }
            self.allocator.free(target_count_result);
        }

        if (source_count_result.len == 0 or target_count_result.len == 0) {
            return false;
        }

        const source_count = switch (source_count_result[0]) {
            .int64 => |v| @as(usize, @intCast(v)),
            else => 0,
        };

        const target_count = switch (target_count_result[0]) {
            .int64 => |v| @as(usize, @intCast(v)),
            else => 0,
        };

        return source_count == target_count;
    }

    /// Estimate migration cost and time
    pub fn estimateMigrationCost(self: MigrationEngine, from_engine: *StorageEngine, to_engine: *StorageEngine, table_name: []const u8) !MigrationEstimate {
        // Get source data size
        const count_query = try std.fmt.allocPrint(self.allocator, "SELECT COUNT(*) FROM {s}", .{table_name});
        defer self.allocator.free(count_query);

        const count_result = try from_engine.query(count_query, self.allocator);
        defer {
            for (count_result) |*value| {
                value.deinit(self.allocator);
            }
            self.allocator.free(count_result);
        }

        const row_count = if (count_result.len > 0) switch (count_result[0]) {
            .int32 => |v| @as(usize, @intCast(v)),
            .int64 => |v| @as(usize, @intCast(v)),
            else => 0,
        } else 0;

        // Estimate bytes (rough heuristic: 1KB per row)
        const estimated_bytes = row_count * 1024;

        // Get performance metrics from engines
        const source_perf = from_engine.getPerformanceMetrics();
        const target_perf = to_engine.getPerformanceMetrics();

        // Estimate time based on throughput
        const read_time_ms = @as(f32, @floatFromInt(estimated_bytes)) / (source_perf.throughput_mbps * 1024 * 1024 / 1000);
        const write_time_ms = @as(f32, @floatFromInt(estimated_bytes)) / (target_perf.throughput_mbps * 1024 * 1024 / 1000);
        const estimated_time_ms = read_time_ms + write_time_ms;

        return MigrationEstimate{
            .row_count = row_count,
            .estimated_bytes = estimated_bytes,
            .estimated_time_ms = estimated_time_ms,
            .source_throughput_mbps = source_perf.throughput_mbps,
            .target_throughput_mbps = target_perf.throughput_mbps,
        };
    }

    fn buildInsertQuery(self: MigrationEngine, table_name: []const u8, data: []const Value) ![]u8 {
        var query = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer query.deinit(self.allocator);

        try query.writer(self.allocator).print("INSERT INTO {s} VALUES ", .{table_name});

        for (data, 0..) |value, i| {
            if (i > 0) try query.appendSlice(self.allocator, ", ");
            try query.append(self.allocator, '(');
            try appendValue(self.allocator, &query, value);
            try query.append(self.allocator, ')');
        }

        return query.toOwnedSlice(self.allocator);
    }

    fn buildUpsertQuery(self: MigrationEngine, table_name: []const u8, data: []const Value) ![]u8 {
        var query = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer query.deinit(self.allocator);

        try query.writer(self.allocator).print("INSERT OR REPLACE INTO {s} VALUES ", .{table_name});

        for (data, 0..) |value, i| {
            if (i > 0) try query.appendSlice(self.allocator, ", ");
            try query.append(self.allocator, '(');
            try appendValue(self.allocator, &query, value);
            try query.append(self.allocator, ')');
        }

        return query.toOwnedSlice(self.allocator);
    }

    fn buildCreateTableQuery(self: MigrationEngine, table_name: []const u8, schema: []const types.Column) ![]u8 {
        var query = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer query.deinit(self.allocator);

        try query.writer(self.allocator).print("CREATE TABLE {s} (", .{table_name});

        for (schema, 0..) |column, i| {
            if (i > 0) try query.appendSlice(self.allocator, ", ");
            try query.writer(self.allocator).print("{s} {s}", .{ column.name, @tagName(column.type) });
            if (column.primary_key) {
                try query.appendSlice(self.allocator, " PRIMARY KEY");
            }
            if (column.not_null) {
                try query.appendSlice(self.allocator, " NOT NULL");
            }
        }

        try query.append(self.allocator, ')');
        return query.toOwnedSlice();
    }

    fn appendValue(allocator: std.mem.Allocator, query_list: *std.ArrayList(u8), value: Value) !void {
        switch (value) {
            .int32 => |v| try query_list.writer(allocator).print("{}", .{v}),
            .int64 => |v| try query_list.writer(allocator).print("{}", .{v}),
            .float32 => |v| try query_list.writer(allocator).print("{}", .{v}),
            .float64 => |v| try query_list.writer(allocator).print("{}", .{v}),
            .boolean => |v| try query_list.writer(allocator).print("{}", .{v}),
            .string => |v| try query_list.writer(allocator).print("'{s}'", .{v}),
            .timestamp => |v| try query_list.writer(allocator).print("{}", .{v}),
            .vector => try query_list.appendSlice(allocator, "'<vector>'"),
            .custom => try query_list.appendSlice(allocator, "'<custom>'"),
            .exception => |e| try query_list.writer(allocator).print("'EXCEPTION: {s}'", .{e.message}),
        }
    }

    fn estimateBytes(data: []const Value) !usize {
        var total_bytes: usize = 0;
        for (data) |value| {
            total_bytes += switch (value) {
                .int32 => 4,
                .int64 => 8,
                .float32 => 4,
                .float64 => 8,
                .boolean => 1,
                .string => |v| v.len,
                .timestamp => 8,
                .vector => 16, // Rough estimate
                .custom => 16, // Rough estimate
                .exception => 16, // Rough estimate
            };
        }
        return total_bytes;
    }
};

/// Migration cost and time estimate
pub const MigrationEstimate = struct {
    row_count: usize,
    estimated_bytes: usize,
    estimated_time_ms: f32,
    source_throughput_mbps: f32,
    target_throughput_mbps: f32,
};
