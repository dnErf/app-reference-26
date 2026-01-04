const std = @import("std");
const types = @import("types.zig");
const where_mod = @import("where.zig");
const Table = @import("table.zig").Table;
const audit_mod = @import("audit.zig");

const Value = types.Value;
const DataType = types.DataType;
const Expr = where_mod.Expr;

/// Column specification for SELECT clauses
pub const ColumnSpec = union(enum) {
    column: []const u8, // Simple column name
    function_call: struct {
        name: []const u8,
        args: []ColumnSpec, // Arguments can be columns or nested function calls
    },

    pub fn deinit(self: *ColumnSpec, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .column => {},
            .function_call => |*fc| {
                allocator.free(fc.name);
                for (fc.args) |*arg| {
                    arg.deinit(allocator);
                }
                allocator.free(fc.args);
            },
        }
    }
};

/// Logical query plan operators
pub const PlanNodeType = enum {
    scan, // Full table scan
    index_scan, // B+Tree index scan
    filter, // WHERE clause application
    project, // Column selection
    aggregate, // GROUP BY + aggregations
    sort, // ORDER BY
    limit, // LIMIT/OFFSET
    join, // JOIN operations (future)
};

pub const JoinType = enum {
    inner,
    left,
    right,
    full,
};

pub const IndexStrategy = enum {
    btree,
    composite_hash,
};

/// Query plan node - forms a tree of operations
pub const PlanNode = struct {
    node_type: PlanNodeType,
    allocator: std.mem.Allocator,

    // Common fields
    table_name: ?[]const u8 = null,
    columns: ?[]ColumnSpec = null, // For project/select
    owns_columns: bool = false,

    // Filter specific
    predicate: ?*Expr = null,

    // Aggregate specific
    agg_column: ?[]const u8 = null,
    agg_function: ?enum { sum, avg, count, min, max } = null,
    group_columns: ?[][]const u8 = null,
    owns_group_columns: bool = false,
    having_predicate: ?*Expr = null,

    // Sort specific
    sort_column: ?[]const u8 = null,
    sort_desc: bool = false,

    // Limit specific
    limit_count: ?usize = null,
    limit_offset: ?usize = null,

    // Index scan specific
    index_name: ?[]const u8 = null,
    index_key: ?Value = null,
    index_column: ?[]const u8 = null,
    index_columns_multi: ?[][]const u8 = null,
    index_values_multi: ?[]Value = null,
    owns_index_values: bool = false,
    index_strategy: IndexStrategy = .btree,

    // Child nodes (for pipeline)
    child: ?*PlanNode = null,
    right_child: ?*PlanNode = null,

    // Join specific
    join_type: ?JoinType = null,
    join_right_table: ?[]const u8 = null,
    join_left_column: ?[]const u8 = null,
    join_right_column: ?[]const u8 = null,

    // Estimated cost (for optimizer)
    estimated_cost: f64 = 0.0,
    estimated_rows: usize = 0,

    pub fn init(allocator: std.mem.Allocator, node_type: PlanNodeType) !*PlanNode {
        const node = try allocator.create(PlanNode);
        node.* = .{
            .node_type = node_type,
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(self: *PlanNode) void {
        if (self.columns) |cols| {
            if (self.owns_columns) {
                for (cols) |*col| {
                    col.deinit(self.allocator);
                }
                self.allocator.free(cols);
            }
        }

        if (self.group_columns) |cols| {
            if (self.owns_group_columns) {
                self.allocator.free(cols);
            }
        }

        if (self.index_values_multi) |values| {
            if (self.owns_index_values) {
                self.allocator.free(values);
            }
        }

        if (self.child) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }

        if (self.right_child) |right| {
            right.deinit();
            self.allocator.destroy(right);
        }

        // Note: predicate is owned by caller, don't free here
    }

    /// Format plan node as string for EXPLAIN
    pub fn format(
        self: PlanNode,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}", .{@tagName(self.node_type)});

        switch (self.node_type) {
            .scan => {
                if (self.table_name) |name| {
                    try writer.print(" table={s}", .{name});
                }
            },
            .index_scan => {
                if (self.index_name) |name| {
                    try writer.print(" index={s}", .{name});
                }
                if (self.index_column) |col| {
                    try writer.print(" column={s}", .{col});
                }
                if (self.index_strategy == .composite_hash and self.index_columns_multi) |cols| {
                    try writer.print(" columns=", .{});
                    try writer.print("[", .{});
                    for (cols, 0..) |col, i| {
                        if (i > 0) try writer.print(", ", .{});
                        try writer.print("{s}", .{col});
                    }
                    try writer.print("]", .{});
                }
                try writer.print(" strategy={s}", .{@tagName(self.index_strategy)});
            },
            .filter => {
                try writer.print(" predicate=<expr>", .{});
            },
            .project => {
                if (self.columns) |cols| {
                    try writer.print(" columns=[", .{});
                    for (cols, 0..) |col, i| {
                        if (i > 0) try writer.print(", ", .{});
                        try writer.print("{s}", .{col});
                    }
                    try writer.print("]", .{});
                }
            },
            .aggregate => {
                if (self.group_columns) |cols| {
                    try writer.print(" group_by=[", .{});
                    for (cols, 0..) |col, i| {
                        if (i > 0) try writer.print(",", .{});
                        try writer.print("{s}", .{col});
                    }
                    try writer.print("]", .{});
                }
                if (self.agg_function) |func| {
                    try writer.print(" {s}({s})", .{ @tagName(func), self.agg_column orelse "?" });
                }
            },
            .sort => {
                if (self.sort_column) |col| {
                    try writer.print(" by={s} {s}", .{ col, if (self.sort_desc) "DESC" else "ASC" });
                }
            },
            .limit => {
                if (self.limit_count) |count| {
                    try writer.print(" count={d}", .{count});
                }
                if (self.limit_offset) |offset| {
                    try writer.print(" offset={d}", .{offset});
                }
            },
            .join => {
                try writer.print(" type={s}", .{@tagName(self.join_type orelse .inner)});
                if (self.table_name) |lt| {
                    try writer.print(" left={s}", .{lt});
                }
                if (self.join_right_table) |rt| {
                    try writer.print(" right={s}", .{rt});
                }
                if (self.join_left_column != null and self.join_right_column != null) {
                    try writer.print(" on {s}={s}", .{ self.join_left_column.?, self.join_right_column.? });
                }
            },
        }

        try writer.print(" (cost={d:.2}, rows={d})", .{ self.estimated_cost, self.estimated_rows });
    }
};

/// Complete query plan with optimization metadata
pub const QueryPlan = struct {
    allocator: std.mem.Allocator,
    root: *PlanNode,

    // Optimization metadata
    optimized: bool = false,
    total_cost: f64 = 0.0,

    pub fn init(allocator: std.mem.Allocator, root: *PlanNode) QueryPlan {
        return .{
            .allocator = allocator,
            .root = root,
        };
    }

    pub fn deinit(self: *QueryPlan) void {
        self.root.deinit();
        self.allocator.destroy(self.root);
    }

    /// Print query plan tree
    pub fn explain(self: QueryPlan, writer: anytype) !void {
        try writer.print("Query Plan (optimized={}):\n", .{self.optimized});
        try self.explainNode(writer, self.root, 0);
        try writer.print("Total Cost: {d:.2}\n", .{self.total_cost});
    }

    /// Return a JSON document describing the query plan tree
    pub fn explainJSON(self: QueryPlan) ![]const u8 {
        var buf = std.ArrayList(u8){};
        defer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);
        try writer.writeAll("{\n");
        try writer.print("  \"optimized\": {},\n", .{self.optimized});
        try writer.print("  \"total_cost\": {d:.2},\n", .{self.total_cost});
        try writer.writeAll("  \"plan\": ");
        try self.explainNodeJSON(writer, self.root, 1);
        try writer.writeAll("\n}\n");

        return try buf.toOwnedSlice(self.allocator);
    }

    /// Render a Mermaid graph for documentation/visual debugging
    pub fn explainMermaid(self: QueryPlan) ![]const u8 {
        var buf = std.ArrayList(u8){};
        defer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);
        try writer.writeAll("graph TD\n");
        var counter: usize = 0;
        _ = try self.emitMermaidNode(writer, self.root, &counter);

        return try buf.toOwnedSlice(self.allocator);
    }

    fn explainNode(self: QueryPlan, writer: anytype, node: *PlanNode, depth: usize) !void {
        var i: usize = 0;
        while (i < depth) : (i += 1) {
            try writer.print("  ", .{});
        }
        try writer.print("→ {any}\n", .{node.*});

        if (node.child) |child| {
            try self.explainNode(writer, child, depth + 1);
        }

        if (node.right_child) |right| {
            try self.explainNode(writer, right, depth + 1);
        }
    }

    fn explainNodeJSON(self: QueryPlan, writer: anytype, node: *PlanNode, depth: usize) !void {
        try self.writeIndent(writer, depth);
        try writer.writeAll("{\n");

        try self.writeIndent(writer, depth + 1);
        try writer.print("\"type\": \"{s}\",\n", .{@tagName(node.node_type)});

        try self.writeIndent(writer, depth + 1);
        try writer.print("\"cost\": {d:.2},\n", .{node.estimated_cost});

        try self.writeIndent(writer, depth + 1);
        try writer.print("\"rows\": {d}", .{node.estimated_rows});

        if (node.table_name) |table_name| {
            try writer.writeAll(",\n");
            try self.writeIndent(writer, depth + 1);
            try writer.print("\"table\": \"{s}\"", .{table_name});
        }

        if (node.index_name) |index_name| {
            try writer.writeAll(",\n");
            try self.writeIndent(writer, depth + 1);
            try writer.print("\"index\": \"{s}\"", .{index_name});
        }

        if (node.join_right_table) |right_name| {
            try writer.writeAll(",\n");
            try self.writeIndent(writer, depth + 1);
            const join_type = @tagName(node.join_type orelse .inner);
            try writer.writeAll("\"join\": {\n");
            try self.writeIndent(writer, depth + 2);
            try writer.print("\"type\": \"{s}\",\n", .{join_type});
            try self.writeIndent(writer, depth + 2);
            try writer.print("\"right\": \"{s}\"\n", .{right_name});
            try self.writeIndent(writer, depth + 1);
            try writer.writeAll("}");
        }

        try writer.writeAll(",\n");
        try self.writeIndent(writer, depth + 1);
        try writer.writeAll("\"children\": ");

        const has_children = node.child != null or node.right_child != null;
        if (!has_children) {
            try writer.writeAll("[]\n");
        } else {
            try writer.writeAll("[\n");
            var first = true;
            if (node.child) |child| {
                if (!first) {
                    try writer.writeAll(",\n");
                }
                try self.explainNodeJSON(writer, child, depth + 2);
                first = false;
            }
            if (node.right_child) |right| {
                if (!first) {
                    try writer.writeAll(",\n");
                }
                try self.explainNodeJSON(writer, right, depth + 2);
            }
            try writer.writeAll("\n");
            try self.writeIndent(writer, depth + 1);
            try writer.writeAll("]\n");
        }

        try self.writeIndent(writer, depth);
        try writer.writeAll("}\n");
    }

    fn writeIndent(self: QueryPlan, writer: anytype, depth: usize) !void {
        _ = self;
        if (depth == 0) return;
        try writer.writeByteNTimes(' ', depth * 2);
    }

    fn emitMermaidNode(self: QueryPlan, writer: anytype, node: *PlanNode, counter: *usize) !usize {
        const current_id = counter.*;
        counter.* += 1;

        var label_buf: [160]u8 = undefined;
        const label = try self.formatNodeLabel(node, &label_buf);
        try writer.print("    node{d}[\"{s}\"]\n", .{ current_id, label });

        if (node.child) |child| {
            const child_id = try self.emitMermaidNode(writer, child, counter);
            try writer.print("    node{d} --> node{d}\n", .{ current_id, child_id });
        }

        if (node.right_child) |right| {
            const right_id = try self.emitMermaidNode(writer, right, counter);
            try writer.print("    node{d} -.-> node{d}\n", .{ current_id, right_id });
        }

        return current_id;
    }

    fn formatNodeLabel(self: QueryPlan, node: *PlanNode, buffer: []u8) ![]const u8 {
        _ = self;
        return switch (node.node_type) {
            .scan => blk: {
                const table = node.table_name orelse "?";
                break :blk try std.fmt.bufPrint(buffer, "scan<br/>{s}", .{table});
            },
            .index_scan => blk: {
                const idx = node.index_name orelse "idx";
                break :blk try std.fmt.bufPrint(buffer, "index_scan<br/>{s}", .{idx});
            },
            .filter => try std.fmt.bufPrint(buffer, "filter<br/>rows={d}", .{node.estimated_rows}),
            .project => try std.fmt.bufPrint(buffer, "project<br/>cols={d}", .{if (node.columns) |cols| cols.len else 0}),
            .join => blk: {
                const right = node.join_right_table orelse "?";
                break :blk try std.fmt.bufPrint(buffer, "join<br/>→ {s}", .{right});
            },
            .limit => try std.fmt.bufPrint(buffer, "limit<br/>count={d}", .{node.limit_count orelse 0}),
            .sort => blk: {
                const col = node.sort_column orelse "?";
                break :blk try std.fmt.bufPrint(buffer, "sort<br/>{s}", .{col});
            },
            .aggregate => blk: {
                const col = node.agg_column orelse "?";
                break :blk try std.fmt.bufPrint(buffer, "aggregate<br/>{s}", .{col});
            },
        };
    }
};

/// Query optimizer - transforms query plan for better performance
pub const Optimizer = struct {
    allocator: std.mem.Allocator,

    // Optimizer statistics (updated as queries run)
    table_stats: std.StringHashMap(TableStats),
    decision_log: ?*audit_mod.AuditLog = null,

    pub const TableStats = struct {
        row_count: usize,
        column_cardinality: std.StringHashMap(usize), // Distinct values per column
        index_available: std.StringHashMap([]const u8), // Available indexes mapped to names
        composite_indexes: []Table.CompositeIndexInfo,
        avg_row_size: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Optimizer {
        return .{
            .allocator = allocator,
            .table_stats = std.StringHashMap(TableStats).init(allocator),
            .decision_log = null,
        };
    }

    pub fn setDecisionLogger(self: *Optimizer, log: ?*audit_mod.AuditLog) void {
        self.decision_log = log;
    }

    pub fn deinit(self: *Optimizer) void {
        var it = self.table_stats.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.column_cardinality.deinit();
            entry.value_ptr.index_available.deinit();
            self.allocator.free(entry.value_ptr.composite_indexes);
        }
        self.table_stats.deinit();
    }

    /// Register table statistics for cost estimation
    pub fn registerTable(self: *Optimizer, table: *const Table) !void {
        var col_card = std.StringHashMap(usize).init(self.allocator);
        errdefer col_card.deinit();

        var index_map = std.StringHashMap([]const u8).init(self.allocator);
        errdefer index_map.deinit();

        // Calculate real cardinality for each column using smart estimation
        for (table.schema.columns, 0..) |col_def, idx| {
            const column = &table.columns[idx];

            const cardinality_mod = @import("cardinality.zig");

            // Use smart cardinality estimation (exact for small, HLL for large)
            const stats: cardinality_mod.CardinalityStats = column.estimateCardinality(col_def.name) catch cardinality_mod.CardinalityStats{
                .distinct_count = table.row_count,
                .total_count = table.row_count,
                .is_exact = false,
                .sample_rate = 1.0,
            };

            try col_card.put(col_def.name, stats.distinct_count);

            // Log cardinality stats to audit log if available
            if (self.decision_log) |log| {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Column {s}.{s}: cardinality={d}, uniqueness={d:.2}%, method={s}",
                    .{
                        table.name,
                        col_def.name,
                        stats.distinct_count,
                        stats.uniqueness() * 100.0,
                        if (stats.is_exact) "exact" else "HyperLogLog",
                    },
                );
                defer self.allocator.free(msg);
                try log.log(.optimizer, table.name, msg, 0, null);
            }
        }

        var idx_iter = table.indexes.iterator();
        while (idx_iter.next()) |entry| {
            try index_map.put(entry.value_ptr.*.column_name, entry.value_ptr.*.name);
        }

        const composite_info = try table.listCompositeIndexes(self.allocator);
        errdefer self.allocator.free(composite_info);

        const stats = TableStats{
            .row_count = table.row_count,
            .column_cardinality = col_card,
            .index_available = index_map,
            .composite_indexes = composite_info,
            .avg_row_size = 100, // Approximate
        };

        try self.replaceTableStats(table.name, stats);
    }

    fn replaceTableStats(self: *Optimizer, table_name: []const u8, stats: TableStats) !void {
        if (self.table_stats.fetchRemove(table_name)) |existing| {
            // fetchRemove returns a KV whose fields are const — cast to mutable to
            // be able to deinitialize owned heap structures safely.
            // Move the value into a mutable local so we can deinitialize
            // owned members safely.
            var removed = existing.value;
            removed.column_cardinality.deinit();
            removed.index_available.deinit();
            self.allocator.free(removed.composite_indexes);
        }
        try self.table_stats.put(table_name, stats);
    }

    /// Optimize query plan using various strategies
    pub fn optimize(self: *Optimizer, plan: *QueryPlan) !void {
        // 1. Predicate pushdown - move filters closer to scans
        try self.pushdownPredicates(plan.root);

        // 2. Projection pushdown - only read needed columns
        try self.pushdownProjections(plan.root);

        // 3. Index selection - use indexes when available
        try self.selectIndexes(plan.root);

        // 4. Cost estimation - calculate expected cost
        self.estimateCost(plan.root);

        plan.optimized = true;
        plan.total_cost = plan.root.estimated_cost;
    }

    /// Predicate pushdown: Move filters before projects/aggregates
    fn pushdownPredicates(self: *Optimizer, node: *PlanNode) !void {
        if (node.child) |child| {
            // If this is a project and child is a scan, check if we can push filter down
            if (node.node_type == .project and child.node_type == .scan) {
                // Look for filter above this project
                // For now, just recurse
            }

            try self.pushdownPredicates(child);
        }
    }

    /// Projection pushdown: Only scan needed columns from lakehouse
    fn pushdownProjections(self: *Optimizer, node: *PlanNode) !void {
        if (node.child) |child| {
            if (node.node_type == .project and node.columns != null) {
                var current = child;
                while (true) {
                    if (current.node_type == .scan or current.node_type == .index_scan) {
                        current.columns = node.columns;
                        current.owns_columns = false;
                        break;
                    }

                    if (current.child) |next| {
                        current = next;
                    } else {
                        break;
                    }
                }
            }

            try self.pushdownProjections(child);
        }
    }

    /// Index selection: Replace table scan with index scan when beneficial
    fn selectIndexes(self: *Optimizer, node: *PlanNode) !void {
        if (node.child) |child| {
            try self.selectIndexes(child);
        }

        if (node.right_child) |right| {
            try self.selectIndexes(right);
        }

        if (node.node_type != .filter or node.child == null) {
            return;
        }

        const child = node.child.?;
        if (child.table_name == null) return;
        if (child.node_type != .scan and child.node_type != .index_scan) return;

        const table_name = child.table_name.?;
        const stats = self.table_stats.get(table_name) orelse return;
        if (node.predicate == null) return;

        var eq_map = std.StringHashMap(Value).init(self.allocator);
        defer eq_map.deinit();
        try self.collectEqualityPredicates(node.predicate.?, &eq_map);
        if (eq_map.count() == 0) return;

        if (try self.tryCompositeIndex(child, stats, &eq_map, table_name)) return;
        try self.trySingleColumnIndex(child, stats, &eq_map, table_name);
    }

    const IndexedPredicate = struct {
        column: []const u8,
        value: Value,
    };

    fn collectEqualityPredicates(self: *Optimizer, expr: *Expr, map: *std.StringHashMap(Value)) !void {
        switch (expr.type) {
            .equal => {
                if (matchColumnLiteral(expr.left, expr.right)) |pred| {
                    try map.put(pred.column, pred.value);
                }
            },
            .and_op => {
                try self.collectEqualityPredicates(expr.left.?, map);
                try self.collectEqualityPredicates(expr.right.?, map);
            },
            else => {},
        }
    }

    fn matchColumnLiteral(left_opt: ?*Expr, right_opt: ?*Expr) ?IndexedPredicate {
        const left = left_opt orelse return null;
        const right = right_opt orelse return null;

        if (left.type == .column_ref and right.type == .literal and right.value != null) {
            return IndexedPredicate{ .column = left.column_name.?, .value = right.value.? };
        }

        if (right.type == .column_ref and left.type == .literal and left.value != null) {
            return IndexedPredicate{ .column = right.column_name.?, .value = left.value.? };
        }

        return null;
    }

    fn trySingleColumnIndex(
        self: *Optimizer,
        child: *PlanNode,
        stats: TableStats,
        eq_map: *std.StringHashMap(Value),
        table_name: []const u8,
    ) !void {
        var it = eq_map.iterator();
        while (it.next()) |entry| {
            const col_name = entry.key_ptr.*;
            const index_name = stats.index_available.get(col_name) orelse continue;

            child.node_type = .index_scan;
            child.index_name = index_name;
            child.index_column = col_name;
            child.index_key = entry.value_ptr.*;
            child.index_strategy = .btree;

            if (child.estimated_rows == 0) {
                child.estimated_rows = @max(stats.row_count / 10, 1);
            }

            if (self.decision_log) |_| {
                const msg = try std.fmt.allocPrint(self.allocator, "Selected B+Tree index {s} for column {s}", .{ index_name, col_name });
                defer self.allocator.free(msg);
                self.emitDecision(table_name, msg);
            }
            return;
        }
    }

    fn tryCompositeIndex(
        self: *Optimizer,
        child: *PlanNode,
        stats: TableStats,
        eq_map: *std.StringHashMap(Value),
        table_name: []const u8,
    ) !bool {
        for (stats.composite_indexes) |info| {
            var values = std.ArrayList(Value){};
            defer values.deinit(self.allocator);

            var missing = false;
            for (info.columns) |col_name| {
                if (eq_map.get(col_name)) |val| {
                    try values.append(self.allocator, val);
                } else {
                    missing = true;
                    break;
                }
            }

            if (missing) continue;

            child.node_type = .index_scan;
            child.index_strategy = .composite_hash;
            child.index_name = info.name;
            child.index_column = null;
            child.index_columns_multi = info.columns;
            child.index_values_multi = try values.toOwnedSlice(self.allocator);
            child.owns_index_values = true;

            if (child.estimated_rows == 0) {
                child.estimated_rows = @max(stats.row_count / 20, 1);
            }

            if (self.decision_log) |_| {
                const msg = try std.fmt.allocPrint(self.allocator, "Selected composite index {s} across {d} columns", .{ info.name, info.columns.len });
                defer self.allocator.free(msg);
                self.emitDecision(table_name, msg);
            }

            return true;
        }

        return false;
    }

    /// Cost estimation using simple heuristics
    fn estimateCost(self: *Optimizer, node: *PlanNode) void {
        // Estimate rows first (bottom-up)
        if (node.child) |child| {
            self.estimateCost(child);
            node.estimated_rows = child.estimated_rows;
        }

        if (node.right_child) |right| {
            self.estimateCost(right);
        }

        // Base cost depends on operation type
        node.estimated_cost = switch (node.node_type) {
            .scan => blk: {
                // Full table scan cost
                const table_name = node.table_name orelse break :blk 1000.0;
                const stats = self.table_stats.get(table_name) orelse break :blk 1000.0;
                node.estimated_rows = stats.row_count;

                // Cost = rows * avg_row_size / page_size
                const cost = @as(f64, @floatFromInt(stats.row_count)) *
                    @as(f64, @floatFromInt(stats.avg_row_size)) / 4096.0;
                break :blk cost;
            },
            .index_scan => blk: {
                var estimated = node.estimated_rows;
                if (estimated == 0) {
                    if (node.table_name) |table_name| {
                        if (self.table_stats.get(table_name)) |stats| {
                            estimated = @max(stats.row_count / 10, 1);
                            node.estimated_rows = estimated;
                        }
                    }
                }

                if (estimated == 0) estimated = 1;
                const log_cost = @log(@as(f64, @floatFromInt(estimated))) + 1.0;
                break :blk log_cost + @as(f64, @floatFromInt(estimated));
            },
            .filter => blk: {
                // Filter cost = child_cost + rows * filter_complexity
                const child_cost = if (node.child) |child| child.estimated_cost else 0.0;
                const filter_cost = @as(f64, @floatFromInt(node.estimated_rows)) * 0.1;

                // Estimate selectivity (assume 10% pass filter)
                node.estimated_rows = node.estimated_rows / 10;
                if (node.estimated_rows == 0) node.estimated_rows = 1;

                break :blk child_cost + filter_cost;
            },
            .project => blk: {
                // Project cost = child_cost + rows * column_count * 0.01
                const child_cost = if (node.child) |child| child.estimated_cost else 0.0;
                const col_count = if (node.columns) |cols| cols.len else 1;
                const proj_cost = @as(f64, @floatFromInt(node.estimated_rows)) *
                    @as(f64, @floatFromInt(col_count)) * 0.01;
                break :blk child_cost + proj_cost;
            },
            .aggregate => blk: {
                // Aggregate cost = child_cost + rows * log(rows)
                const child_cost = if (node.child) |child| child.estimated_cost else 0.0;
                const agg_cost = @as(f64, @floatFromInt(node.estimated_rows)) *
                    @log(@as(f64, @floatFromInt(node.estimated_rows)));
                node.estimated_rows = 1; // Aggregates return 1 row
                break :blk child_cost + agg_cost;
            },
            .sort => blk: {
                // Sort cost = child_cost + rows * log(rows)
                const child_cost = if (node.child) |child| child.estimated_cost else 0.0;
                const sort_cost = @as(f64, @floatFromInt(node.estimated_rows)) *
                    @log(@as(f64, @floatFromInt(node.estimated_rows)));
                break :blk child_cost + sort_cost;
            },
            .limit => blk: {
                // Limit cost = child_cost (mostly)
                const child_cost = if (node.child) |child| child.estimated_cost else 0.0;
                if (node.limit_count) |count| {
                    node.estimated_rows = @min(node.estimated_rows, count);
                }
                break :blk child_cost;
            },
            .join => blk: {
                if (node.child == null or node.right_child == null) break :blk 0.0;
                const left_rows = node.child.?.estimated_rows;
                const right_rows = node.right_child.?.estimated_rows;
                const selectivity = @max((left_rows * right_rows) / 10, 1);
                node.estimated_rows = selectivity;
                const left_cost = node.child.?.estimated_cost;
                const right_cost = node.right_child.?.estimated_cost;
                const combined = left_cost + right_cost +
                    @as(f64, @floatFromInt(selectivity)) * 0.05;

                if (self.decision_log) |_| {
                    const left_name = node.table_name orelse "unknown";
                    const right_name = node.join_right_table orelse "unknown";
                    if (std.fmt.allocPrint(
                        self.allocator,
                        "Planned hash join between {s} and {s} (rows≈{d})",
                        .{ left_name, right_name, node.estimated_rows },
                    ) catch null) |msg| {
                        defer self.allocator.free(msg);
                        self.emitDecision(left_name, msg);
                    }
                }

                break :blk combined;
            },
        };
    }

    fn emitDecision(self: *Optimizer, table_name: []const u8, message: []const u8) void {
        if (self.decision_log) |log| {
            log.log(audit_mod.AuditEntry.Operation.optimizer, table_name, message, 0, null) catch {};
        }
    }
};

test "QueryPlan creation and explain" {
    const allocator = std.testing.allocator;

    // Create simple plan: Scan → Filter → Project
    const scan = try PlanNode.init(allocator, .scan);
    scan.table_name = "users";
    scan.estimated_rows = 1000;

    const filter = try PlanNode.init(allocator, .filter);
    filter.child = scan;
    filter.estimated_rows = 100;

    const project = try PlanNode.init(allocator, .project);
    project.child = filter;
    project.estimated_rows = 100;

    var plan = QueryPlan.init(allocator, project);
    defer plan.deinit();

    // Test explain
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);

    try plan.explain(buf.writer(allocator));

    const output = buf.items;
    try std.testing.expect(std.mem.indexOf(u8, output, "Query Plan") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "scan") != null);
}

test "Optimizer cost estimation" {
    const allocator = std.testing.allocator;

    var optimizer = Optimizer.init(allocator);
    defer optimizer.deinit();

    // Create simple plan
    const scan = try PlanNode.init(allocator, .scan);
    scan.table_name = "test_table";

    var plan = QueryPlan.init(allocator, scan);
    defer plan.deinit();

    // Estimate cost without stats
    optimizer.estimateCost(scan);

    try std.testing.expect(scan.estimated_cost > 0);
}

test "Optimizer selects index predicate" {
    const allocator = std.testing.allocator;

    var optimizer = Optimizer.init(allocator);
    defer optimizer.deinit();

    var col_card = std.StringHashMap(usize).init(allocator);
    try col_card.put("id", 100);

    var index_map = std.StringHashMap([]const u8).init(allocator);
    try index_map.put("id", "idx_users_id");

    const composites = try allocator.alloc(Table.CompositeIndexInfo, 0);

    try optimizer.table_stats.put("users", .{
        .row_count = 100,
        .column_cardinality = col_card,
        .index_available = index_map,
        .composite_indexes = composites,
        .avg_row_size = 16,
    });

    const scan = try PlanNode.init(allocator, .scan);
    scan.table_name = "users";

    const filter = try PlanNode.init(allocator, .filter);
    filter.child = scan;
    defer {
        filter.deinit();
        allocator.destroy(filter);
    }

    const col_expr = try Expr.columnRef(allocator, "id");
    const lit_expr = try Expr.literal(allocator, Value{ .int64 = 42 });
    const predicate_expr = try Expr.binary(allocator, .equal, col_expr, lit_expr);
    defer predicate_expr.deinit();
    filter.predicate = predicate_expr;

    try optimizer.selectIndexes(filter);

    try std.testing.expectEqual(PlanNodeType.index_scan, scan.node_type);
    try std.testing.expect(scan.index_name != null);
}

test "QueryPlan explain JSON and Mermaid" {
    const allocator = std.testing.allocator;

    const scan = try PlanNode.init(allocator, .scan);
    scan.table_name = "users";
    scan.estimated_rows = 42;

    var plan = QueryPlan.init(allocator, scan);
    defer plan.deinit();

    const json = try plan.explainJSON();
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"plan\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "users") != null);

    const mermaid = try plan.explainMermaid();
    defer allocator.free(mermaid);
    try std.testing.expect(std.mem.indexOf(u8, mermaid, "graph TD") != null);
}

test "Optimizer logs decisions to audit" {
    const allocator = std.testing.allocator;

    var optimizer = Optimizer.init(allocator);
    defer optimizer.deinit();

    var audit_log = audit_mod.AuditLog.init(allocator);
    defer audit_log.deinit();
    optimizer.setDecisionLogger(&audit_log);

    var col_card = std.StringHashMap(usize).init(allocator);
    try col_card.put("id", 100);

    var index_map = std.StringHashMap([]const u8).init(allocator);
    try index_map.put("id", "idx_users_id");

    const composites = try allocator.alloc(Table.CompositeIndexInfo, 0);

    try optimizer.table_stats.put("users", .{
        .row_count = 100,
        .column_cardinality = col_card,
        .index_available = index_map,
        .composite_indexes = composites,
        .avg_row_size = 16,
    });

    const scan = try PlanNode.init(allocator, .scan);
    scan.table_name = "users";

    const filter = try PlanNode.init(allocator, .filter);
    defer {
        filter.deinit();
        allocator.destroy(filter);
    }
    filter.child = scan;

    const col_expr = try Expr.columnRef(allocator, "id");
    const lit_expr = try Expr.literal(allocator, Value{ .int64 = 7 });
    const predicate_expr = try Expr.binary(allocator, .equal, col_expr, lit_expr);
    defer predicate_expr.deinit();
    filter.predicate = predicate_expr;

    try optimizer.selectIndexes(filter);
    try std.testing.expectEqual(PlanNodeType.index_scan, scan.node_type);
    try std.testing.expect(audit_log.entries.items.len >= 1);
    try std.testing.expectEqual(audit_mod.AuditEntry.Operation.optimizer, audit_log.entries.items[0].operation);
}
