const std = @import("std");
const storage_selector = @import("storage_selector.zig");
const query = @import("query.zig");
const types = @import("types.zig");

const WorkloadProfile = storage_selector.WorkloadProfile;
const Query = query.Query;

/// Query pattern analyzer for workload characterization
pub const WorkloadAnalyzer = struct {
    allocator: std.mem.Allocator,
    query_history: std.ArrayList(QueryPattern),
    time_window_ms: u64, // Analysis window in milliseconds

    /// Individual query pattern with metadata
    pub const QueryPattern = struct {
        query_type: QueryType,
        table_accessed: []const u8,
        columns_accessed: std.ArrayList([]const u8),
        predicates: std.ArrayList(Predicate),
        joins: std.ArrayList(Join),
        aggregations: std.ArrayList(Aggregation),
        timestamp: u64, // When query was executed
        execution_time_ms: u64,
        rows_affected: usize,
    };

    pub const QueryType = enum {
        select,
        insert,
        update,
        delete,
        create,
        drop,
        alter,
    };

    pub const Predicate = struct {
        column: []const u8,
        operator: []const u8, // =, >, <, LIKE, etc.
        value_type: types.DataType, // Type of the value being compared
        selectivity: f32, // Estimated selectivity (0.0 to 1.0)
    };

    pub const Join = struct {
        left_table: []const u8,
        right_table: []const u8,
        join_type: JoinType,
        condition: []const u8,
    };

    pub const JoinType = enum {
        inner,
        left,
        right,
        full,
        cross,
    };

    pub const Aggregation = struct {
        function: []const u8, // COUNT, SUM, AVG, etc.
        column: []const u8,
        distinct: bool,
    };

    pub fn init(allocator: std.mem.Allocator, time_window_ms: u64) !WorkloadAnalyzer {
        return WorkloadAnalyzer{
            .allocator = allocator,
            .query_history = try std.ArrayList(QueryPattern).initCapacity(allocator, 0),
            .time_window_ms = time_window_ms,
        };
    }

    pub fn deinit(self: *WorkloadAnalyzer) void {
        for (self.query_history.items) |*pattern| {
            self.allocator.free(pattern.table_accessed);
            for (pattern.columns_accessed.items) |col| {
                self.allocator.free(col);
            }
            pattern.columns_accessed.deinit(self.allocator);
            for (pattern.predicates.items) |*pred| {
                self.allocator.free(pred.column);
                self.allocator.free(pred.operator);
            }
            pattern.predicates.deinit(self.allocator);
            for (pattern.joins.items) |*join| {
                self.allocator.free(join.left_table);
                self.allocator.free(join.right_table);
                self.allocator.free(join.condition);
            }
            pattern.joins.deinit(self.allocator);
            for (pattern.aggregations.items) |*agg| {
                self.allocator.free(agg.function);
                self.allocator.free(agg.column);
            }
            pattern.aggregations.deinit(self.allocator);
        }
        self.query_history.deinit(self.allocator);
    }

    /// Record a query execution for analysis
    pub fn recordQuery(self: *WorkloadAnalyzer, query_str: []const u8, execution_time_ms: u64, rows_affected: usize) !void {
        const now = std.time.milliTimestamp();
        const pattern = try self.analyzeQuery(query_str, now, execution_time_ms, rows_affected);
        try self.query_history.append(pattern);

        // Clean up old patterns outside time window
        const cutoff = now - self.time_window_ms;
        var i: usize = 0;
        while (i < self.query_history.items.len) {
            if (self.query_history.items[i].timestamp < cutoff) {
                var pattern_to_remove = self.query_history.orderedRemove(i);
                self.deinitPattern(&pattern_to_remove);
            } else {
                i += 1;
            }
        }
    }

    /// Analyze a query string and extract patterns
    pub fn analyzeQuery(self: *WorkloadAnalyzer, query_str: []const u8, timestamp: u64, execution_time_ms: u64, rows_affected: usize) !QueryPattern {
        const query_upper = try std.ascii.allocUpperString(self.allocator, query_str);
        defer self.allocator.free(query_upper);

        var pattern = QueryPattern{
            .query_type = .select,
            .table_accessed = try self.allocator.dupe(u8, ""),
            .columns_accessed = std.ArrayList([]const u8).init(self.allocator),
            .predicates = std.ArrayList(Predicate).init(self.allocator),
            .joins = std.ArrayList(Join).init(self.allocator),
            .aggregations = std.ArrayList(Aggregation).init(self.allocator),
            .timestamp = timestamp,
            .execution_time_ms = execution_time_ms,
            .rows_affected = rows_affected,
        };

        // Determine query type
        if (std.mem.indexOf(u8, query_upper, "SELECT") != null) {
            pattern.query_type = .select;
        } else if (std.mem.indexOf(u8, query_upper, "INSERT") != null) {
            pattern.query_type = .insert;
        } else if (std.mem.indexOf(u8, query_upper, "UPDATE") != null) {
            pattern.query_type = .update;
        } else if (std.mem.indexOf(u8, query_upper, "DELETE") != null) {
            pattern.query_type = .delete;
        } else if (std.mem.indexOf(u8, query_upper, "CREATE") != null) {
            pattern.query_type = .create;
        } else if (std.mem.indexOf(u8, query_upper, "DROP") != null) {
            pattern.query_type = .drop;
        } else if (std.mem.indexOf(u8, query_upper, "ALTER") != null) {
            pattern.query_type = .alter;
        }

        // Extract table name (simplified - assumes single table)
        if (std.mem.indexOf(u8, query_upper, "FROM") != null) {
            const from_pos = std.mem.indexOf(u8, query_upper, "FROM").? + 4;
            const table_start = std.mem.indexOfPos(u8, query_upper, from_pos, " ").? + 1;
            const table_end = std.mem.indexOfPos(u8, query_upper, table_start, " ") orelse query_upper.len;
            pattern.table_accessed = try self.allocator.dupe(u8, std.mem.trim(u8, query_upper[table_start..table_end], " \t\n\r"));
        }

        // Extract columns (simplified)
        if (std.mem.indexOf(u8, query_upper, "SELECT") != null) {
            const select_pos = std.mem.indexOf(u8, query_upper, "SELECT").? + 6;
            const from_pos = std.mem.indexOf(u8, query_upper, "FROM") orelse query_upper.len;
            const select_clause = std.mem.trim(u8, query_upper[select_pos..from_pos], " \t\n\r");

            if (!std.mem.eql(u8, select_clause, "*")) {
                var col_iter = std.mem.split(u8, select_clause, ",");
                while (col_iter.next()) |col| {
                    const trimmed_col = std.mem.trim(u8, col, " \t\n\r");
                    if (trimmed_col.len > 0) {
                        try pattern.columns_accessed.append(try self.allocator.dupe(u8, trimmed_col));
                    }
                }
            }
        }

        // Extract JOINs
        var join_pos: usize = 0;
        while (std.mem.indexOfPos(u8, query_upper, join_pos, "JOIN") != null) {
            const current_join_pos = std.mem.indexOfPos(u8, query_upper, join_pos, "JOIN").?;
            const join_type_end = current_join_pos;
            const table_start = current_join_pos + 4;
            const table_end = std.mem.indexOfPos(u8, query_upper, table_start, " ") orelse std.mem.indexOfPos(u8, query_upper, table_start, "\n") orelse query_upper.len;

            const table_name = std.mem.trim(u8, query_upper[table_start..table_end], " \t\n\r");
            const join_type_str = std.mem.trim(u8, query_upper[join_pos..join_type_end], " \t\n\r");

            var join_type = JoinType.inner;
            if (std.mem.indexOf(u8, join_type_str, "LEFT") != null) join_type = .left;
            if (std.mem.indexOf(u8, join_type_str, "RIGHT") != null) join_type = .right;
            if (std.mem.indexOf(u8, join_type_str, "FULL") != null) join_type = .full;
            if (std.mem.indexOf(u8, join_type_str, "CROSS") != null) join_type = .cross;

            try pattern.joins.append(Join{
                .left_table = try self.allocator.dupe(u8, pattern.table_accessed),
                .right_table = try self.allocator.dupe(u8, table_name),
                .join_type = join_type,
                .condition = try self.allocator.dupe(u8, ""),
            });

            join_pos = table_end;
        }

        // Extract aggregations
        const agg_functions = [_][]const u8{ "COUNT(", "SUM(", "AVG(", "MIN(", "MAX(" };
        for (agg_functions) |func| {
            if (std.mem.indexOf(u8, query_upper, func) != null) {
                const func_name = func[0 .. func.len - 1];
                try pattern.aggregations.append(Aggregation{
                    .function = try self.allocator.dupe(u8, func_name),
                    .column = try self.allocator.dupe(u8, "*"),
                    .distinct = std.mem.indexOf(u8, query_upper, "DISTINCT") != null,
                });
            }
        }

        return pattern;
    }

    /// Generate workload profile from query history
    pub fn generateWorkloadProfile(self: *WorkloadAnalyzer) !WorkloadProfile {
        var profile = WorkloadProfile{};
        var total_queries: usize = 0;
        var total_execution_time: u64 = 0;
        var total_rows_affected: usize = 0;

        // Count query types and patterns
        var select_count: usize = 0;
        var write_count: usize = 0;
        var join_count: usize = 0;
        var aggregation_count: usize = 0;
        var point_lookup_count: usize = 0;

        for (self.query_history.items) |pattern| {
            total_queries += 1;
            total_execution_time += pattern.execution_time_ms;
            total_rows_affected += pattern.rows_affected;

            switch (pattern.query_type) {
                .select => {
                    select_count += 1;
                    if (pattern.predicates.items.len > 0 and pattern.joins.items.len == 0) {
                        point_lookup_count += 1;
                    }
                    if (pattern.joins.items.len > 0) {
                        join_count += 1;
                    }
                    if (pattern.aggregations.items.len > 0) {
                        aggregation_count += 1;
                    }
                },
                .insert, .update, .delete => write_count += 1,
                else => {},
            }
        }

        if (total_queries == 0) return profile;

        // Calculate workload characteristics
        const read_ratio = @as(f32, @floatFromInt(select_count)) / @as(f32, @floatFromInt(total_queries));
        const write_ratio = @as(f32, @floatFromInt(write_count)) / @as(f32, @floatFromInt(total_queries));

        profile.read_heavy = read_ratio > 0.7;
        profile.write_heavy = write_ratio > 0.3;
        profile.analytical_queries = @as(f32, @floatFromInt(aggregation_count)) / @as(f32, @floatFromInt(select_count)) > 0.3;
        profile.point_lookups = @as(f32, @floatFromInt(point_lookup_count)) / @as(f32, @floatFromInt(select_count)) > 0.5;
        profile.complex_joins = @as(f32, @floatFromInt(join_count)) / @as(f32, @floatFromInt(select_count)) > 0.2;

        // Estimate data size based on rows affected (rough heuristic)
        profile.data_size_gb = @as(f32, @floatFromInt(total_rows_affected)) * 0.001; // Assume ~1KB per row

        // Calculate query complexity
        var total_complexity: f32 = 0.0;
        for (self.query_history.items) |pattern| {
            const complexity = @as(f32, @floatFromInt(pattern.joins.items.len + pattern.predicates.items.len + pattern.aggregations.items.len)) / 10.0;
            total_complexity += std.math.clamp(complexity, 0.0, 1.0);
        }
        profile.query_complexity = total_complexity / @as(f32, @floatFromInt(total_queries));

        return profile;
    }

    /// Get query performance statistics
    pub fn getPerformanceStats(self: *WorkloadAnalyzer) struct {
        total_queries: usize,
        avg_execution_time_ms: f32,
        total_rows_affected: usize,
        queries_per_second: f32,
    } {
        const total_queries = self.query_history.items.len;
        if (total_queries == 0) {
            return .{
                .total_queries = 0,
                .avg_execution_time_ms = 0.0,
                .total_rows_affected = 0,
                .queries_per_second = 0.0,
            };
        }

        var total_time: u64 = 0;
        var total_rows: usize = 0;
        var earliest: u64 = std.math.maxInt(u64);
        var latest: u64 = 0;

        for (self.query_history.items) |pattern| {
            total_time += pattern.execution_time_ms;
            total_rows += pattern.rows_affected;
            earliest = @min(earliest, pattern.timestamp);
            latest = @max(latest, pattern.timestamp);
        }

        const time_span_ms = latest - earliest;
        const queries_per_second = if (time_span_ms > 0) @as(f32, @floatFromInt(total_queries)) / (@as(f32, @floatFromInt(time_span_ms)) / 1000.0) else 0.0;

        return .{
            .total_queries = total_queries,
            .avg_execution_time_ms = @as(f32, @floatFromInt(total_time)) / @as(f32, @floatFromInt(total_queries)),
            .total_rows_affected = total_rows,
            .queries_per_second = queries_per_second,
        };
    }

    fn deinitPattern(self: *WorkloadAnalyzer, pattern: *QueryPattern) void {
        self.allocator.free(pattern.table_accessed);
        for (pattern.columns_accessed.items) |col| {
            self.allocator.free(col);
        }
        pattern.columns_accessed.deinit();
        for (pattern.predicates.items) |*pred| {
            self.allocator.free(pred.column);
            self.allocator.free(pred.operator);
        }
        pattern.predicates.deinit();
        for (pattern.joins.items) |*join| {
            self.allocator.free(join.left_table);
            self.allocator.free(join.right_table);
            self.allocator.free(join.condition);
        }
        pattern.joins.deinit();
        for (pattern.aggregations.items) |*agg| {
            self.allocator.free(agg.function);
            self.allocator.free(agg.column);
        }
        pattern.aggregations.deinit();
    }
};
