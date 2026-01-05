const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");
const btree_mod = @import("btree.zig");

const Value = types.Value;
const Table = table_mod.Table;
const BTreeIndex = btree_mod.BTreeIndex;

/// Index types supported by the row store
pub const IndexType = enum {
    btree,
    hash,
};

/// Generic index interface for fast lookups
pub const Index = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    table: *Table,
    column_name: []const u8,
    index_type: IndexType,
    btree: ?*BTreeIndex,
    hash_map: ?std.StringHashMap(usize),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, table: *Table, column_name: []const u8, index_type: IndexType) !Index {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const column_copy = try allocator.dupe(u8, column_name);
        errdefer allocator.free(column_copy);

        var index = Index{
            .allocator = allocator,
            .name = name_copy,
            .table = table,
            .column_name = column_copy,
            .index_type = index_type,
            .btree = null,
            .hash_map = null,
        };

        // Initialize the appropriate index structure
        switch (index_type) {
            .btree => {
                index.btree = try allocator.create(BTreeIndex);
                index.btree.?.* = BTreeIndex{
                    .allocator = allocator,
                    .root = null,
                    .key_type = .int32, // Simplified
                    .height = 0,
                    .name = try allocator.dupe(u8, name_copy),
                    .table_name = try allocator.dupe(u8, table.name),
                    .column_name = try allocator.dupe(u8, column_copy),
                };
            },
            .hash => {
                index.hash_map = std.StringHashMap(usize).init(allocator);
            },
        }

        // Build initial index from existing table data
        try index.buildFromTable();

        return index;
    }

    pub fn deinit(self: *Index) void {
        self.allocator.free(self.name);
        self.allocator.free(self.column_name);

        if (self.btree) |btree| {
            btree.deinit();
            self.allocator.destroy(btree);
        }

        if (self.hash_map) |*hash_map| {
            hash_map.deinit();
        }
    }

    /// Build index from existing table data
    pub fn buildFromTable(self: *Index) !void {
        for (self.table.rows.items, 0..) |row, row_id| {
            if (row.len > 0) { // Skip deleted rows
                try self.insert(row_id, row);
            }
        }
    }

    /// Insert a row ID into the index
    pub fn insert(self: *Index, row_id: usize, row_data: []const Value) !void {
        const column_index = self.findColumnIndex() catch return error.ColumnNotFound;
        if (column_index >= row_data.len) return;

        const value = row_data[column_index];

        switch (self.index_type) {
            .btree => {
                if (self.btree) |btree| {
                    try btree.insert(value, row_id);
                }
            },
            .hash => {
                if (self.hash_map) |*hash_map| {
                    const key_str = try std.fmt.allocPrint(self.allocator, "{any}", .{value});
                    defer self.allocator.free(key_str);
                    try hash_map.put(key_str, row_id);
                }
            },
        }
    }

    /// Remove a row ID from the index
    pub fn remove(self: *Index, _: usize) !void {
        // For simplicity, we'll rebuild the index when removing
        // In a production system, we'd track keys per row ID
        switch (self.index_type) {
            .btree => {
                if (self.btree) |btree| {
                    // B-tree removal would require knowing the key
                    // For now, rebuild the entire index
                    // Clear the tree by resetting root and height
                    if (btree.root) |root| {
                        root.deinit();
                        btree.allocator.destroy(root);
                    }
                    btree.root = null;
                    btree.height = 0;
                    try self.buildFromTable();
                }
            },
            .hash => {
                if (self.hash_map) |*hash_map| {
                    // Hash map removal would require knowing the key
                    // For now, rebuild the entire index
                    hash_map.clearRetainingCapacity();
                    try self.buildFromTable();
                }
            },
        }
    }

    /// Search for row IDs matching a value
    pub fn search(self: *Index, search_value: Value) !?usize {
        switch (self.index_type) {
            .btree => {
                if (self.btree) |btree| {
                    const result = try btree.search(self.allocator, search_value);
                    defer if (result.owned) self.allocator.free(result.rows);
                    return if (result.rows.len > 0) result.rows[0] else null;
                }
            },
            .hash => {
                if (self.hash_map) |hash_map| {
                    const key_str = try std.fmt.allocPrint(self.allocator, "{}", .{search_value});
                    defer self.allocator.free(key_str);
                    return hash_map.get(key_str);
                }
            },
        }

        return null;
    }

    /// Find the column index in the table schema
    fn findColumnIndex(self: *Index) !usize {
        for (self.table.schema.columns, 0..) |column, i| {
            if (std.mem.eql(u8, column.name, self.column_name)) {
                return i;
            }
        }
        return error.ColumnNotFound;
    }
};

/// Hash index for exact match lookups
pub const HashIndex = struct {
    map: std.StringHashMap(usize),

    pub fn init(allocator: std.mem.Allocator) HashIndex {
        return HashIndex{
            .map = std.StringHashMap(usize).init(allocator),
        };
    }

    pub fn deinit(self: *HashIndex) void {
        self.map.deinit();
    }

    /// Insert key-value pair
    pub fn insert(self: *HashIndex, key: []const u8, value: usize) !void {
        const key_copy = try self.map.allocator.dupe(u8, key);
        errdefer self.map.allocator.free(key_copy);
        try self.map.put(key_copy, value);
    }

    /// Search for a key
    pub fn search(self: *HashIndex, key: []const u8) ?usize {
        return self.map.get(key);
    }

    /// Remove a key
    pub fn remove(self: *HashIndex, key: []const u8) bool {
        return self.map.remove(key);
    }
};

/// Composite index for multiple columns
pub const CompositeIndex = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    columns: std.ArrayList([]const u8),
    index_type: IndexType,
    btree: ?BTreeIndex,
    hash: ?HashIndex,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, columns: []const []const u8, index_type: IndexType) !CompositeIndex {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        var columns_copy = std.ArrayList([]const u8).init(allocator);
        errdefer columns_copy.deinit();

        for (columns) |col| {
            try columns_copy.append(try allocator.dupe(u8, col));
        }

        var index = CompositeIndex{
            .allocator = allocator,
            .name = name_copy,
            .columns = columns_copy,
            .index_type = index_type,
            .btree = null,
            .hash = null,
        };

        // Initialize the appropriate index structure
        switch (index_type) {
            .btree => {
                index.btree = try BTreeIndex.init(allocator, 32);
            },
            .hash => {
                index.hash = HashIndex.init(allocator);
            },
        }

        return index;
    }

    pub fn deinit(self: *CompositeIndex) void {
        self.allocator.free(self.name);
        for (self.columns.items) |col| {
            self.allocator.free(col);
        }
        self.columns.deinit();

        if (self.btree) |*btree| btree.deinit();
        if (self.hash) |*hash| hash.deinit();
    }

    /// Create composite key from row data
    pub fn createCompositeKey(self: *CompositeIndex, row_data: []const Value, table: *Table) ![]const u8 {
        var key_parts = std.ArrayList([]const u8).init(self.allocator);
        defer key_parts.deinit();
        defer for (key_parts.items) |part| self.allocator.free(part);

        for (self.columns.items) |col_name| {
            // Find column index
            var col_index: usize = 0;
            for (table.schema.columns.items, 0..) |col, i| {
                if (std.mem.eql(u8, col.name, col_name)) {
                    col_index = i;
                    break;
                }
            } else continue;

            if (col_index >= row_data.len) continue;

            const part = try std.fmt.allocPrint(self.allocator, "{}", .{row_data[col_index]});
            try key_parts.append(part);
        }

        // Join with separator
        return std.mem.join(self.allocator, "|", key_parts.items);
    }
};
