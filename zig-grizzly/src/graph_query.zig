const std = @import("std");
const types = @import("types.zig");
const graph_store = @import("graph_store.zig");

const Value = types.Value;
const GraphNode = graph_store.GraphStore.GraphNode;

/// Graph Query - SQL-based graph query language for traversals and pattern matching
/// Supports Cypher-like syntax for graph database operations
pub const GraphQuery = struct {
    allocator: std.mem.Allocator,
    query_type: QueryType,
    node_patterns: std.ArrayList(NodePattern),
    edge_patterns: std.ArrayList(EdgePattern),
    where_conditions: std.ArrayList(WhereCondition),
    return_expressions: std.ArrayList([]const u8),

    pub const QueryType = enum {
        match,
        create,
        delete,
    };

    pub const NodePattern = struct {
        variable: []const u8,
        labels: std.ArrayList([]const u8),
        properties: std.StringHashMap(Value),
    };

    pub const EdgePattern = struct {
        variable: []const u8,
        relationship_type: []const u8,
        direction: Direction,
        properties: std.StringHashMap(Value),
    };

    pub const Direction = enum {
        outgoing,
        incoming,
        bidirectional,
    };

    pub const WhereCondition = struct {
        left_expr: []const u8,
        operator: []const u8,
        right_expr: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) !GraphQuery {
        return GraphQuery{
            .allocator = allocator,
            .query_type = .match,
            .node_patterns = try std.ArrayList(NodePattern).initCapacity(allocator, 0),
            .edge_patterns = try std.ArrayList(EdgePattern).initCapacity(allocator, 0),
            .where_conditions = try std.ArrayList(WhereCondition).initCapacity(allocator, 0),
            .return_expressions = try std.ArrayList([]const u8).initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *GraphQuery) void {
        for (self.node_patterns.items) |*pattern| {
            self.allocator.free(pattern.variable);
            for (pattern.labels.items) |label| {
                self.allocator.free(label);
            }
            pattern.labels.deinit(self.allocator);

            var prop_iter = pattern.properties.iterator();
            while (prop_iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            pattern.properties.deinit();
        }
        self.node_patterns.deinit(self.allocator);

        for (self.edge_patterns.items) |*pattern| {
            self.allocator.free(pattern.variable);
            self.allocator.free(pattern.relationship_type);

            var prop_iter = pattern.properties.iterator();
            while (prop_iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            pattern.properties.deinit();
        }
        self.edge_patterns.deinit(self.allocator);

        for (self.where_conditions.items) |*condition| {
            self.allocator.free(condition.left_expr);
            self.allocator.free(condition.operator);
            self.allocator.free(condition.right_expr);
        }
        self.where_conditions.deinit(self.allocator);

        for (self.return_expressions.items) |expr| {
            self.allocator.free(expr);
        }
        self.return_expressions.deinit(self.allocator);
    }

    pub fn parse(self: *GraphQuery, query_str: []const u8) !void {
        // Simple parser for basic MATCH queries
        // TODO: Implement full Cypher-like parser

        if (std.mem.startsWith(u8, query_str, "MATCH")) {
            self.query_type = .match;
            try self.parseMatchClause(query_str["MATCH ".len..]);
        } else if (std.mem.startsWith(u8, query_str, "CREATE")) {
            self.query_type = .create;
            // TODO: Parse CREATE
            return error.NotImplemented;
        } else {
            return error.InvalidQuery;
        }
    }

    fn parseMatchClause(self: *GraphQuery, clause: []const u8) !void {
        // Very basic parser: MATCH (n:Person) RETURN n.name
        var parts = std.mem.splitSequence(u8, clause, "RETURN");

        const pattern_part = std.mem.trim(u8, parts.next() orelse return error.InvalidQuery, " ");
        const return_part = std.mem.trim(u8, parts.next() orelse return error.InvalidQuery, " ");

        // Parse pattern (simplified)
        if (std.mem.startsWith(u8, pattern_part, "(")) {
            if (std.mem.indexOf(u8, pattern_part, ")")) |end_pos| {
                const node_pattern = pattern_part[1..end_pos];
                try self.parseNodePattern(node_pattern);
            }
        }

        // Parse return
        try self.parseReturnClause(return_part);
    }

    fn parseNodePattern(self: *GraphQuery, pattern: []const u8) !void {
        // Parse (variable:Label {prop: value})
        var parts = std.mem.splitSequence(u8, pattern, ":");

        const variable = std.mem.trim(u8, parts.next() orelse "n", " ");
        const label_part = parts.next() orelse "";

        var node_pattern = NodePattern{
            .variable = try self.allocator.dupe(u8, variable),
            .labels = try std.ArrayList([]const u8).initCapacity(self.allocator, 1),
            .properties = std.StringHashMap(Value).init(self.allocator),
        };

        if (label_part.len > 0) {
            const label = std.mem.trim(u8, label_part, " {}");
            try node_pattern.labels.append(self.allocator, try self.allocator.dupe(u8, label));
        }

        try self.node_patterns.append(self.allocator, node_pattern);
    }

    fn parseReturnClause(self: *GraphQuery, clause: []const u8) !void {
        var parts = std.mem.splitSequence(u8, clause, ",");

        while (parts.next()) |part| {
            const expr = std.mem.trim(u8, part, " ");
            try self.return_expressions.append(self.allocator, try self.allocator.dupe(u8, expr));
        }
    }

    pub fn matchesNode(self: *const GraphQuery, node: *const GraphNode) bool {
        // Check if node matches any pattern
        for (self.node_patterns.items) |pattern| {
            if (self.nodeMatchesPattern(node, pattern)) {
                return true;
            }
        }
        return false;
    }

    fn nodeMatchesPattern(_: *const GraphQuery, node: *const GraphNode, pattern: NodePattern) bool {
        // Check labels
        if (pattern.labels.items.len > 0) {
            var has_matching_label = false;
            for (pattern.labels.items) |pattern_label| {
                for (node.labels.items) |node_label| {
                    if (std.mem.eql(u8, pattern_label, node_label)) {
                        has_matching_label = true;
                        break;
                    }
                }
                if (has_matching_label) break;
            }
            if (!has_matching_label) return false;
        }

        // Check properties
        var prop_iter = pattern.properties.iterator();
        while (prop_iter.next()) |entry| {
            const node_value = node.properties.get(entry.key_ptr.*) orelse return false;
            if (!valuesEqual(node_value, entry.value_ptr.*)) {
                return false;
            }
        }

        return true;
    }

    fn valuesEqual(a: Value, b: Value) bool {
        return switch (a) {
            .string => |str| b == .string and std.mem.eql(u8, str, b.string),
            .int32 => |val| b == .int32 and val == b.int32,
            .int64 => |val| b == .int64 and val == b.int64,
            .float32 => |val| b == .float32 and val == b.float32,
            .float64 => |val| b == .float64 and val == b.float64,
            .boolean => |val| b == .boolean and val == b.boolean,
            else => false,
        };
    }

    pub fn execute(self: *GraphQuery, store: *graph_store.GraphStore) !std.ArrayList(*GraphNode) {
        return switch (self.query_type) {
            .match => store.queryGraph(self.*),
            .create => error.NotImplemented,
            .delete => error.NotImplemented,
        };
    }
};
