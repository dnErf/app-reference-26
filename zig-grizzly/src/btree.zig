const std = @import("std");
const types = @import("types.zig");

const Value = types.Value;
const DataType = types.DataType;

/// B+Tree node types
const NodeType = enum {
    internal, // Internal node with keys and child pointers
    leaf, // Leaf node with keys and values
};

/// B+Tree configuration
const ORDER = 32; // Max children per node (should be power of 2 for cache efficiency)
const MIN_KEYS = ORDER / 2 - 1;
const MAX_KEYS = ORDER - 1;

/// B+Tree node
pub const BTreeNode = struct {
    node_type: NodeType,
    allocator: std.mem.Allocator,

    // Keys are always sorted
    keys: std.ArrayList(Value),

    // For internal nodes: pointers to children
    children: ?std.ArrayList(*BTreeNode) = null,

    // For leaf nodes: pointers to row indices
    row_indices: ?std.ArrayList(usize) = null,

    // Leaf nodes form a linked list for range scans
    next_leaf: ?*BTreeNode = null,

    parent: ?*BTreeNode = null,

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType) !*BTreeNode {
        const node = try allocator.create(BTreeNode);
        node.* = .{
            .node_type = node_type,
            .allocator = allocator,
            .keys = std.ArrayList(Value){},
        };

        switch (node_type) {
            .internal => {
                node.children = std.ArrayList(*BTreeNode){};
            },
            .leaf => {
                node.row_indices = std.ArrayList(usize){};
            },
        }

        return node;
    }

    pub fn deinit(self: *BTreeNode) void {
        self.keys.deinit(self.allocator);

        if (self.children) |*children| {
            for (children.items) |child| {
                child.deinit();
                self.allocator.destroy(child);
            }
            children.deinit(self.allocator);
        }

        if (self.row_indices) |*indices| {
            indices.deinit(self.allocator);
        }
    }

    fn isFull(self: *const BTreeNode) bool {
        return self.keys.items.len >= MAX_KEYS;
    }

    fn isUnderflow(self: *const BTreeNode) bool {
        return self.keys.items.len < MIN_KEYS;
    }

    /// Find position where key should be inserted
    fn findPosition(self: *const BTreeNode, key: Value) usize {
        var pos: usize = 0;
        for (self.keys.items) |k| {
            if (key.lessThan(k)) break;
            pos += 1;
        }
        return pos;
    }
};

/// B+Tree index for fast lookups
pub const BTreeIndex = struct {
    allocator: std.mem.Allocator,
    root: ?*BTreeNode,
    key_type: DataType,
    height: usize,

    // Metadata
    name: []const u8,
    table_name: []const u8,
    column_name: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        table_name: []const u8,
        column_name: []const u8,
        key_type: DataType,
    ) !BTreeIndex {
        return .{
            .allocator = allocator,
            .root = null,
            .key_type = key_type,
            .height = 0,
            .name = try allocator.dupe(u8, name),
            .table_name = try allocator.dupe(u8, table_name),
            .column_name = try allocator.dupe(u8, column_name),
        };
    }

    pub fn deinit(self: *BTreeIndex) void {
        if (self.root) |root| {
            root.deinit();
            self.allocator.destroy(root);
        }
        self.allocator.free(self.name);
        self.allocator.free(self.table_name);
        self.allocator.free(self.column_name);
    }

    /// Insert a key-value pair
    pub fn insert(self: *BTreeIndex, key: Value, row_index: usize) !void {
        // Create root if tree is empty
        if (self.root == null) {
            self.root = try BTreeNode.init(self.allocator, .leaf);
            self.height = 1;
        }

        // If root is full, split it
        if (self.root.?.isFull()) {
            const new_root = try BTreeNode.init(self.allocator, .internal);
            new_root.children = std.ArrayList(*BTreeNode){};
            try new_root.children.?.append(self.allocator, self.root.?);
            self.root.?.parent = new_root;

            try self.splitChild(new_root, 0);
            self.root = new_root;
            self.height += 1;
        }

        try self.insertNonFull(self.root.?, key, row_index);
    }

    /// Insert into a non-full node
    fn insertNonFull(self: *BTreeIndex, node: *BTreeNode, key: Value, row_index: usize) !void {
        if (node.node_type == .leaf) {
            // Insert into leaf node in sorted order
            const pos = node.findPosition(key);
            try node.keys.insert(node.allocator, pos, key);
            try node.row_indices.?.insert(node.allocator, pos, row_index);
        } else {
            // Find child to insert into
            var pos = node.findPosition(key);

            // Navigate to child
            const child = node.children.?.items[pos];

            // If child is full, split it first
            if (child.isFull()) {
                try self.splitChild(node, pos);

                // After split, decide which child to go to
                if (node.keys.items[pos].lessThan(key)) {
                    pos += 1;
                }
            }

            try self.insertNonFull(node.children.?.items[pos], key, row_index);
        }
    }

    /// Split a full child node
    fn splitChild(self: *BTreeIndex, parent: *BTreeNode, child_index: usize) !void {
        const full_child = parent.children.?.items[child_index];
        const mid = MAX_KEYS / 2;

        // Create new node for right half
        const new_node = try BTreeNode.init(self.allocator, full_child.node_type);

        // Move keys from middle to end to new node
        try new_node.keys.appendSlice(new_node.allocator, full_child.keys.items[mid + 1 ..]);

        if (full_child.node_type == .leaf) {
            // Move row indices
            try new_node.row_indices.?.appendSlice(new_node.allocator, full_child.row_indices.?.items[mid + 1 ..]);

            // Update leaf linked list
            new_node.next_leaf = full_child.next_leaf;
            full_child.next_leaf = new_node;
        } else {
            // Move children
            try new_node.children.?.appendSlice(new_node.allocator, full_child.children.?.items[mid + 1 ..]);

            // Update parent pointers
            for (new_node.children.?.items) |child| {
                child.parent = new_node;
            }
        }

        // Promote middle key to parent
        const promoted_key = full_child.keys.items[mid];
        try parent.keys.insert(parent.allocator, child_index, promoted_key);
        try parent.children.?.insert(parent.allocator, child_index + 1, new_node);
        new_node.parent = parent;

        // Truncate full_child's keys
        if (full_child.node_type == .leaf) {
            full_child.keys.shrinkRetainingCapacity(mid + 1); // Keep mid key in leaf
            full_child.row_indices.?.shrinkRetainingCapacity(mid + 1);
        } else {
            full_child.keys.shrinkRetainingCapacity(mid);
            full_child.children.?.shrinkRetainingCapacity(mid + 1);
        }
    }

    /// Search for a key and return matching row indices
    pub fn search(self: *const BTreeIndex, allocator: std.mem.Allocator, key: Value) !SearchResult {
        if (self.root == null) {
            return SearchResult{ .rows = &[_]usize{}, .owned = false };
        }

        var leaf = self.findLeaf(self.root.?, key);
        var matches = std.ArrayList(usize){};
        defer matches.deinit(allocator);

        while (true) {
            for (leaf.keys.items, 0..) |k, i| {
                const is_equal = valuesEqual(key, k);
                if (is_equal) {
                    try matches.append(allocator, leaf.row_indices.?.items[i]);
                } else if (matches.items.len > 0) {
                    return SearchResult{
                        .rows = try matches.toOwnedSlice(allocator),
                        .owned = true,
                    };
                }
            }

            if (matches.items.len == 0 or leaf.next_leaf == null) {
                break;
            }

            leaf = leaf.next_leaf.?;
        }

        if (matches.items.len == 0) {
            return SearchResult{ .rows = &[_]usize{}, .owned = false };
        }

        return SearchResult{ .rows = try matches.toOwnedSlice(allocator), .owned = true };
    }

    fn findLeaf(self: *const BTreeIndex, node: *BTreeNode, key: Value) *BTreeNode {
        _ = self;
        var current = node;
        while (current.node_type != .leaf) {
            const pos = current.findPosition(key);
            current = current.children.?.items[pos];
        }
        return current;
    }

    /// Range scan - find all keys between start and end (inclusive)
    pub fn rangeScan(
        self: *const BTreeIndex,
        allocator: std.mem.Allocator,
        start_key: ?Value,
        end_key: ?Value,
    ) !std.ArrayList(usize) {
        var results = std.ArrayList(usize){};

        if (self.root == null) {
            return results;
        }

        // Find the leftmost leaf
        var leaf = self.root.?;
        while (leaf.node_type != .leaf) {
            leaf = leaf.children.?.items[0];
        }

        // Scan through leaves
        while (true) {
            for (leaf.keys.items, 0..) |key, i| {
                const in_range = blk: {
                    if (start_key) |start| {
                        if (key.lessThan(start)) break :blk false;
                    }
                    if (end_key) |end| {
                        if (end.lessThan(key)) break :blk false;
                    }
                    break :blk true;
                };

                if (in_range) {
                    try results.append(allocator, leaf.row_indices.?.items[i]);
                }
            }

            if (leaf.next_leaf) |next| {
                leaf = next;
            } else {
                break;
            }
        }

        return results;
    }

    /// Get statistics about the index
    pub fn getStats(self: *const BTreeIndex) IndexStats {
        if (self.root == null) {
            return .{
                .height = 0,
                .node_count = 0,
                .key_count = 0,
                .avg_keys_per_node = 0,
            };
        }

        const stats = self.collectStats(self.root.?);
        return .{
            .height = self.height,
            .node_count = stats.nodes,
            .key_count = stats.keys,
            .avg_keys_per_node = if (stats.nodes > 0)
                @as(f64, @floatFromInt(stats.keys)) / @as(f64, @floatFromInt(stats.nodes))
            else
                0,
        };
    }

    const StatsResult = struct { nodes: usize, keys: usize };

    fn collectStats(self: *const BTreeIndex, node: *BTreeNode) StatsResult {
        var result = StatsResult{ .nodes = 1, .keys = node.keys.items.len };

        if (node.children) |children| {
            for (children.items) |child| {
                const child_stats = self.collectStats(child);
                result.nodes += child_stats.nodes;
                result.keys += child_stats.keys;
            }
        }

        return result;
    }
};

fn valuesEqual(a: Value, b: Value) bool {
    return !a.lessThan(b) and !b.lessThan(a);
}

pub const IndexStats = struct {
    height: usize,
    node_count: usize,
    key_count: usize,
    avg_keys_per_node: f64,
};

pub const SearchResult = struct {
    rows: []usize,
    owned: bool,
};

test "BTreeIndex creation" {
    const allocator = std.testing.allocator;

    var index = try BTreeIndex.init(allocator, "idx_users_age", "users", "age", .int32);
    defer index.deinit();

    try std.testing.expectEqualStrings("idx_users_age", index.name);
    try std.testing.expectEqualStrings("users", index.table_name);
    try std.testing.expectEqualStrings("age", index.column_name);
    try std.testing.expectEqual(@as(usize, 0), index.height);
}

test "BTreeIndex insert and search" {
    const allocator = std.testing.allocator;

    var index = try BTreeIndex.init(allocator, "test_idx", "test", "id", .int32);
    defer index.deinit();

    // Insert some values
    try index.insert(Value{ .int32 = 10 }, 0);
    try index.insert(Value{ .int32 = 20 }, 1);
    try index.insert(Value{ .int32 = 5 }, 2);
    try index.insert(Value{ .int32 = 15 }, 3);

    // Search for values
    const result1 = try index.search(allocator, Value{ .int32 = 10 });
    defer if (result1.owned and result1.rows.len > 0) allocator.free(result1.rows);
    try std.testing.expectEqual(@as(usize, 1), result1.rows.len);
    try std.testing.expectEqual(@as(usize, 0), result1.rows[0]);

    const result2 = try index.search(allocator, Value{ .int32 = 20 });
    defer if (result2.owned and result2.rows.len > 0) allocator.free(result2.rows);
    try std.testing.expectEqual(@as(usize, 1), result2.rows.len);
    try std.testing.expectEqual(@as(usize, 1), result2.rows[0]);

    // Search for non-existent value
    const result3 = try index.search(allocator, Value{ .int32 = 99 });
    try std.testing.expectEqual(@as(usize, 0), result3.rows.len);
}

test "BTreeIndex stats" {
    const allocator = std.testing.allocator;

    var index = try BTreeIndex.init(allocator, "test_idx", "test", "id", .int32);
    defer index.deinit();

    // Insert many values to create multiple nodes
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        try index.insert(Value{ .int32 = i }, @intCast(i));
    }

    const stats = index.getStats();
    try std.testing.expect(stats.key_count >= 100); // May have more due to promoted keys in internal nodes
    try std.testing.expect(stats.node_count > 1); // Should have split
    try std.testing.expect(stats.height > 1);
}
