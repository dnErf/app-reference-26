const std = @import("std");
const types = @import("types.zig");
const schema_mod = @import("schema.zig");
const column_mod = @import("column.zig");
const btree = @import("btree.zig");

const DataType = types.DataType;
const Value = types.Value;
const Schema = schema_mod.Schema;
const Column = column_mod.Column;
const BTreeIndex = btree.BTreeIndex;
const BTreeSearchResult = btree.SearchResult;

const IndexRef = struct {
    index: *BTreeIndex,
    column_index: usize,
};

/// Table represents a collection of columns with a schema
pub const Table = struct {
    pub const IndexLookupResult = struct {
        rows: []usize,
        owned: bool,
    };

    name: []const u8,
    schema: Schema,
    columns: []Column,
    rows: std.ArrayList([]Value), // For row store: store complete rows
    row_count: usize,
    allocator: std.mem.Allocator,
    indexes: std.StringHashMap(*BTreeIndex),
    column_indexes: std.StringHashMap(IndexRef),
    composite_indexes: std.StringHashMap(*CompositeHashIndex),
    composite_signature_map: std.StringHashMap(*CompositeHashIndex),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, schema_def: []const Schema.ColumnDef) !Table {
        const owned_name = try allocator.dupe(u8, name);
        const schema = try Schema.init(allocator, schema_def);

        const columns = try allocator.alloc(Column, schema.columns.len);
        errdefer allocator.free(columns);

        for (schema.columns, 0..) |col_def, i| {
            columns[i] = try Column.init(allocator, col_def.data_type, 16, .{ .vector_dim = col_def.vector_dim });
        }

        return Table{
            .name = owned_name,
            .schema = schema,
            .columns = columns,
            .rows = try std.ArrayList([]Value).initCapacity(allocator, 0),
            .row_count = 0,
            .allocator = allocator,
            .indexes = std.StringHashMap(*BTreeIndex).init(allocator),
            .column_indexes = std.StringHashMap(IndexRef).init(allocator),
            .composite_indexes = std.StringHashMap(*CompositeHashIndex).init(allocator),
            .composite_signature_map = std.StringHashMap(*CompositeHashIndex).init(allocator),
        };
    }

    pub fn deinit(self: *Table) void {
        for (self.columns) |*col| {
            col.deinit();
        }
        self.allocator.free(self.columns);
        self.schema.deinit();

        var idx_it = self.indexes.iterator();
        while (idx_it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.indexes.deinit();
        self.column_indexes.deinit();

        var comp_it = self.composite_indexes.iterator();
        while (comp_it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.composite_indexes.deinit();

        var sig_it = self.composite_signature_map.iterator();
        while (sig_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.composite_signature_map.deinit();

        // Clean up rows for row store
        for (self.rows.items) |row| {
            self.allocator.free(row);
        }
        self.rows.deinit(self.allocator);

        self.allocator.free(self.name);
    }

    /// Insert a row of values
    pub fn insertRow(self: *Table, values: []const Value) !void {
        if (values.len != self.columns.len) {
            return error.ColumnCountMismatch;
        }

        for (values, 0..) |value, i| {
            try self.columns[i].append(value);
        }
        self.row_count += 1;

        if (self.column_indexes.count() > 0 or self.composite_indexes.count() > 0) {
            try self.backfillIndexesForRow(self.row_count - 1);
        }
    }

    /// Get a specific cell value
    pub fn getCell(self: Table, row: usize, col: usize) !Value {
        if (col >= self.columns.len) return error.ColumnOutOfBounds;
        return try self.columns[col].get(row);
    }

    /// Print table to writer
    pub fn print(self: Table, writer: anytype) !void {
        // Print header
        try writer.print("Table: {s}\n", .{self.name});
        for (self.schema.columns, 0..) |col, i| {
            if (i > 0) try writer.print(" | ", .{});
            try writer.print("{s:12}", .{col.name});
        }
        try writer.print("\n", .{});

        // Print separator
        for (self.schema.columns, 0..) |_, i| {
            if (i > 0) try writer.print("-+-", .{});
            try writer.print("{s:-<12}", .{""});
        }
        try writer.print("\n", .{});

        // Print rows
        var row: usize = 0;
        while (row < self.row_count) : (row += 1) {
            for (0..self.columns.len) |col| {
                if (col > 0) try writer.print(" | ", .{});
                const val = try self.getCell(row, col);
                try writer.print("{any:12}", .{val});
            }
            try writer.print("\n", .{});
        }
        try writer.print("\n({d} rows)\n", .{self.row_count});
    }

    /// Filter rows based on a predicate function
    pub fn filter(self: Table, allocator: std.mem.Allocator, predicate: *const fn ([]const Value) bool) !Table {
        var result = try Table.init(allocator, self.name, self.schema.columns);
        errdefer result.deinit();

        var row_values = try allocator.alloc(Value, self.columns.len);
        defer allocator.free(row_values);

        var row: usize = 0;
        while (row < self.row_count) : (row += 1) {
            for (0..self.columns.len) |col| {
                row_values[col] = try self.getCell(row, col);
            }

            if (predicate(row_values)) {
                try result.insertRow(row_values);
            }
        }

        return result;
    }

    /// Select specific columns
    pub fn select(self: Table, allocator: std.mem.Allocator, column_names: []const []const u8) !Table {
        var selected_cols = try allocator.alloc(Schema.ColumnDef, column_names.len);
        defer allocator.free(selected_cols);

        var col_indices = try allocator.alloc(usize, column_names.len);
        defer allocator.free(col_indices);

        for (column_names, 0..) |name, i| {
            const idx = self.schema.findColumn(name) orelse return error.ColumnNotFound;
            col_indices[i] = idx;
            selected_cols[i] = self.schema.columns[idx];
        }

        var result = try Table.init(allocator, self.name, selected_cols);
        errdefer result.deinit();

        var row_values = try allocator.alloc(Value, column_names.len);
        defer allocator.free(row_values);

        var row: usize = 0;
        while (row < self.row_count) : (row += 1) {
            for (col_indices, 0..) |col_idx, i| {
                row_values[i] = try self.getCell(row, col_idx);
            }
            try result.insertRow(row_values);
        }

        return result;
    }

    /// Aggregate function results with lineage tracking
    pub const AggregateResult = struct {
        column_name: []const u8,
        function: []const u8,
        value: Value,
        contributing_rows: ?[]usize, // Track which rows contributed to result
        row_count: usize, // Total rows examined
        allocator: ?std.mem.Allocator,

        pub fn deinit(self: AggregateResult, allocator: std.mem.Allocator) void {
            if (self.contributing_rows) |rows| {
                allocator.free(rows);
            }
        }
    };

    /// Perform aggregation on a column with lineage tracking
    pub fn aggregate(self: Table, allocator: std.mem.Allocator, column_name: []const u8, function: enum { sum, avg, count, min, max }) !AggregateResult {
        const col_idx = self.schema.findColumn(column_name) orelse return error.ColumnNotFound;
        const col = self.columns[col_idx];

        const value = switch (function) {
            .sum => try col.sum(),
            .avg => try col.avg(),
            .count => Value{ .int64 = @intCast(col.count()) },
            .min => try col.min(),
            .max => try col.max(),
        };

        // Track all contributing rows for full audit trail
        var contributing = try allocator.alloc(usize, self.row_count);
        for (0..self.row_count) |i| {
            contributing[i] = i;
        }

        return AggregateResult{
            .column_name = column_name,
            .function = @tagName(function),
            .value = value,
            .contributing_rows = contributing,
            .row_count = self.row_count,
            .allocator = allocator,
        };
    }

    /// Perform aggregation with filter (only aggregate matching rows)
    pub fn aggregateFiltered(
        self: Table,
        allocator: std.mem.Allocator,
        column_name: []const u8,
        function: enum { sum, avg, count, min, max },
        predicate: *const fn ([]const Value) bool,
    ) !AggregateResult {
        const col_idx = self.schema.findColumn(column_name) orelse return error.ColumnNotFound;

        var row_values = try allocator.alloc(Value, self.columns.len);
        defer allocator.free(row_values);

        var contributing_rows = std.ArrayList(usize){};
        defer contributing_rows.deinit(allocator);

        // Collect matching rows
        var row: usize = 0;
        while (row < self.row_count) : (row += 1) {
            for (0..self.columns.len) |col| {
                row_values[col] = try self.getCell(row, col);
            }

            if (predicate(row_values)) {
                try contributing_rows.append(allocator, row);
            }
        }

        // Calculate aggregate on filtered rows only
        var result_value: Value = undefined;
        const matching_count = contributing_rows.items.len;

        if (matching_count == 0) {
            return AggregateResult{
                .column_name = column_name,
                .function = @tagName(function),
                .value = Value{ .int64 = 0 },
                .contributing_rows = null,
                .row_count = 0,
                .allocator = allocator,
            };
        }

        switch (function) {
            .count => {
                result_value = Value{ .int64 = @intCast(matching_count) };
            },
            .sum => {
                var sum: f64 = 0;
                for (contributing_rows.items) |row_idx| {
                    const val = try self.getCell(row_idx, col_idx);
                    sum += switch (val) {
                        .int32 => |v| @floatFromInt(v),
                        .int64 => |v| @floatFromInt(v),
                        .float32 => |v| v,
                        .float64 => |v| v,
                        else => return error.TypeMismatch,
                    };
                }
                result_value = Value{ .float64 = sum };
            },
            .avg => {
                var sum: f64 = 0;
                for (contributing_rows.items) |row_idx| {
                    const val = try self.getCell(row_idx, col_idx);
                    sum += switch (val) {
                        .int32 => |v| @floatFromInt(v),
                        .int64 => |v| @floatFromInt(v),
                        .float32 => |v| v,
                        .float64 => |v| v,
                        else => return error.TypeMismatch,
                    };
                }
                result_value = Value{ .float64 = sum / @as(f64, @floatFromInt(matching_count)) };
            },
            .min, .max => {
                var extreme_val = try self.getCell(contributing_rows.items[0], col_idx);
                for (contributing_rows.items[1..]) |row_idx| {
                    const val = try self.getCell(row_idx, col_idx);
                    if (function == .min) {
                        if (val.lessThan(extreme_val)) extreme_val = val;
                    } else {
                        if (extreme_val.lessThan(val)) extreme_val = val;
                    }
                }
                result_value = extreme_val;
            },
        }

        return AggregateResult{
            .column_name = column_name,
            .function = @tagName(function),
            .value = result_value,
            .contributing_rows = try allocator.dupe(usize, contributing_rows.items),
            .row_count = matching_count,
            .allocator = allocator,
        };
    }

    /// Sort table by a column
    pub fn sortBy(self: *Table, column_name: []const u8, ascending: bool) !void {
        const col_idx = self.schema.findColumn(column_name) orelse return error.ColumnNotFound;

        // Create index array
        const indices = try self.allocator.alloc(usize, self.row_count);
        defer self.allocator.free(indices);

        for (indices, 0..) |*idx, i| {
            idx.* = i;
        }

        // Sort indices based on column values
        const Context = struct {
            table: *const Table,
            col_idx: usize,
            ascending: bool,

            pub fn lessThan(ctx: @This(), a_idx: usize, b_idx: usize) bool {
                const a = ctx.table.getCell(a_idx, ctx.col_idx) catch unreachable;
                const b = ctx.table.getCell(b_idx, ctx.col_idx) catch unreachable;
                return if (ctx.ascending) a.lessThan(b) else b.lessThan(a);
            }
        };

        const ctx = Context{ .table = self, .col_idx = col_idx, .ascending = ascending };
        std.mem.sort(usize, indices, ctx, Context.lessThan);

        // Reorder all columns based on sorted indices
        for (self.columns) |*col| {
            try reorderColumn(col, indices, self.allocator);
        }
    }

    fn reorderColumn(col: *Column, indices: []const usize, allocator: std.mem.Allocator) !void {
        // Create temporary storage for reordered data
        var temp_col = try Column.init(allocator, col.data_type, col.capacity, .{ .vector_dim = col.vector_dim });
        defer temp_col.deinit();

        for (indices) |idx| {
            const val = try col.get(idx);
            try temp_col.append(val);
        }

        // Swap the data
        std.mem.swap([]u8, &col.data, &temp_col.data);
        std.mem.swap(std.ArrayList([]u8), &col.string_pool, &temp_col.string_pool);
        col.len = temp_col.len;
    }

    fn backfillIndexesForRow(self: *Table, row_index: usize) !void {
        var it = self.column_indexes.iterator();
        while (it.next()) |entry| {
            const descriptor = entry.value_ptr.*;
            const value = try self.getCell(row_index, descriptor.column_index);
            try descriptor.index.insert(value, row_index);
        }

        var comp_it = self.composite_indexes.iterator();
        while (comp_it.next()) |entry| {
            try entry.value_ptr.*.insertRow(self, row_index);
        }
    }

    pub fn createIndex(self: *Table, index_name: []const u8, column_name: []const u8) !void {
        if (self.indexes.contains(index_name)) {
            return error.IndexAlreadyExists;
        }
        if (self.column_indexes.contains(column_name)) {
            return error.IndexAlreadyExists;
        }

        const column_idx = self.schema.findColumn(column_name) orelse return error.ColumnNotFound;

        var index_ptr = try self.allocator.create(BTreeIndex);
        errdefer self.allocator.destroy(index_ptr);

        index_ptr.* = try BTreeIndex.init(self.allocator, index_name, self.name, column_name, self.schema.columns[column_idx].data_type);
        errdefer index_ptr.deinit();

        var row: usize = 0;
        while (row < self.row_count) : (row += 1) {
            const value = try self.getCell(row, column_idx);
            try index_ptr.insert(value, row);
        }

        try self.indexes.put(index_name, index_ptr);
        errdefer {
            _ = self.indexes.fetchRemove(index_name);
        }

        try self.column_indexes.put(column_name, .{ .index = index_ptr, .column_index = column_idx });
    }

    pub fn lookupIndex(self: *Table, allocator: std.mem.Allocator, column_name: []const u8, value: Value) !IndexLookupResult {
        const descriptor = self.column_indexes.get(column_name) orelse return error.IndexNotFound;
        const result = try descriptor.index.search(allocator, value);
        return .{ .rows = result.rows, .owned = result.owned };
    }

    pub fn createCompositeIndex(self: *Table, index_name: []const u8, column_names: [][]const u8) !void {
        if (column_names.len < 2) return error.CompositeIndexNeedsColumns;
        if (self.composite_indexes.contains(index_name)) return error.IndexAlreadyExists;

        const signature = try CompositeHashIndex.buildSignature(self.allocator, column_names);
        defer self.allocator.free(signature);

        if (self.composite_signature_map.contains(signature)) {
            return error.IndexAlreadyExists;
        }

        const column_count = column_names.len;
        var column_indices = try self.allocator.alloc(usize, column_count);
        defer self.allocator.free(column_indices);
        for (column_names, 0..) |col_name, i| {
            column_indices[i] = self.schema.findColumn(col_name) orelse return error.ColumnNotFound;
        }

        var index_ptr = try self.allocator.create(CompositeHashIndex);
        errdefer self.allocator.destroy(index_ptr);

        index_ptr.* = try CompositeHashIndex.init(self.allocator, index_name, self.name, signature, column_names, column_indices);
        errdefer index_ptr.deinit();

        var row: usize = 0;
        while (row < self.row_count) : (row += 1) {
            try index_ptr.insertRow(self, row);
        }

        try self.composite_indexes.put(index_name, index_ptr);
        errdefer {
            _ = self.composite_indexes.fetchRemove(index_name);
        }

        const signature_copy = try self.allocator.dupe(u8, signature);
        errdefer self.allocator.free(signature_copy);
        try self.composite_signature_map.put(signature_copy, index_ptr);
    }

    pub fn lookupCompositeIndexByName(
        self: *Table,
        allocator: std.mem.Allocator,
        index_name: []const u8,
        values: []const Value,
    ) !IndexLookupResult {
        const index_ptr = self.composite_indexes.get(index_name) orelse return error.IndexNotFound;
        return try index_ptr.lookup(allocator, self, values);
    }

    pub const CompositeIndexInfo = struct {
        name: []const u8,
        columns: [][]const u8,
    };

    pub fn listCompositeIndexes(self: *const Table, allocator: std.mem.Allocator) ![]CompositeIndexInfo {
        var infos = std.ArrayList(CompositeIndexInfo){};
        defer infos.deinit(allocator);

        var it = self.composite_indexes.iterator();
        while (it.next()) |entry| {
            try infos.append(allocator, .{
                .name = entry.key_ptr.*, // map keeps key alive
                .columns = entry.value_ptr.*.column_names,
            });
        }

        return try infos.toOwnedSlice(allocator);
    }
};

const CompositeHashIndex = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    table_name: []const u8,
    signature: []const u8,
    column_names: [][]const u8,
    column_indices: []usize,
    buckets: std.AutoHashMap(u64, std.ArrayList(usize)),

    pub fn buildSignature(allocator: std.mem.Allocator, column_names: [][]const u8) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(allocator);
        for (column_names, 0..) |col, i| {
            if (i > 0) try buffer.append(allocator, '|');
            try buffer.appendSlice(allocator, col);
        }
        return try buffer.toOwnedSlice(allocator);
    }

    pub fn init(
        allocator: std.mem.Allocator,
        index_name: []const u8,
        table_name: []const u8,
        signature: []const u8,
        column_names: [][]const u8,
        column_indices: []const usize,
    ) !CompositeHashIndex {
        const owned_name = try allocator.dupe(u8, index_name);
        const owned_table = try allocator.dupe(u8, table_name);
        const owned_signature = try allocator.dupe(u8, signature);

        const names = try allocator.alloc([]const u8, column_names.len);
        errdefer allocator.free(names);
        for (column_names, 0..) |col, i| {
            names[i] = try allocator.dupe(u8, col);
        }

        const indices = try allocator.alloc(usize, column_indices.len);
        errdefer allocator.free(indices);
        @memcpy(indices, column_indices);

        return .{
            .allocator = allocator,
            .name = owned_name,
            .table_name = owned_table,
            .signature = owned_signature,
            .column_names = names,
            .column_indices = indices,
            .buckets = std.AutoHashMap(u64, std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *CompositeHashIndex) void {
        var it = self.buckets.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.buckets.deinit();

        for (self.column_names) |name| {
            self.allocator.free(name);
        }
        self.allocator.free(self.column_names);
        self.allocator.free(self.column_indices);
        self.allocator.free(self.name);
        self.allocator.free(self.table_name);
        self.allocator.free(self.signature);
    }

    fn hashRow(self: *CompositeHashIndex, table: *Table, row_index: usize) !u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (self.column_indices) |col_idx| {
            const value = try table.getCell(row_index, col_idx);
            const h = value.hash();
            hasher.update(std.mem.asBytes(&h));
        }
        return hasher.final();
    }

    fn hashValues(self: *CompositeHashIndex, values: []const Value) u64 {
        _ = self;
        var hasher = std.hash.Wyhash.init(0);
        for (values) |value| {
            const h = value.hash();
            hasher.update(std.mem.asBytes(&h));
        }
        return hasher.final();
    }

    fn valueMatches(self: *CompositeHashIndex, table: *const Table, row_index: usize, values: []const Value) bool {
        var i: usize = 0;
        while (i < self.column_indices.len) : (i += 1) {
            const col_idx = self.column_indices[i];
            const cell = table.getCell(row_index, col_idx) catch return false;
            if (!cell.eql(values[i])) return false;
        }
        return true;
    }

    pub fn insertRow(self: *CompositeHashIndex, table: *Table, row_index: usize) !void {
        const hash_value = try self.hashRow(table, row_index);
        var entry = try self.buckets.getOrPut(hash_value);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(usize){};
        }
        try entry.value_ptr.append(self.allocator, row_index);
    }

    pub fn lookup(
        self: *CompositeHashIndex,
        allocator: std.mem.Allocator,
        table: *const Table,
        values: []const Value,
    ) !Table.IndexLookupResult {
        if (values.len != self.column_indices.len) return error.ColumnCountMismatch;
        const hash_value = self.hashValues(values);
        const entry = self.buckets.get(hash_value) orelse
            return Table.IndexLookupResult{ .rows = &[_]usize{}, .owned = false };

        var matches = std.ArrayList(usize){};
        defer matches.deinit(allocator);
        for (entry.items) |row_index| {
            if (self.valueMatches(table, row_index, values)) {
                try matches.append(allocator, row_index);
            }
        }

        if (matches.items.len == 0) {
            return Table.IndexLookupResult{ .rows = &[_]usize{}, .owned = false };
        }

        return Table.IndexLookupResult{ .rows = try matches.toOwnedSlice(allocator), .owned = true };
    }
};

test "Table creation and insertion" {
    const allocator = std.testing.allocator;

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "age", .data_type = .int32 },
    };

    var table = try Table.init(allocator, "users", &schema_def);
    defer table.deinit();

    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
        Value{ .int32 = 30 },
    });

    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .string = "Bob" },
        Value{ .int32 = 25 },
    });

    try std.testing.expectEqual(@as(usize, 2), table.row_count);

    const cell = try table.getCell(0, 1);
    try std.testing.expectEqualStrings("Alice", cell.string);
}

test "Table aggregation" {
    const allocator = std.testing.allocator;

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "value", .data_type = .int32 },
    };

    var table = try Table.init(allocator, "numbers", &schema_def);
    defer table.deinit();

    try table.insertRow(&[_]Value{Value{ .int32 = 10 }});
    try table.insertRow(&[_]Value{Value{ .int32 = 20 }});
    try table.insertRow(&[_]Value{Value{ .int32 = 30 }});

    const sum_result = try table.aggregate(allocator, "value", .sum);
    defer sum_result.deinit(allocator);
    try std.testing.expectEqual(@as(i64, 60), sum_result.value.int64);

    const avg_result = try table.aggregate(allocator, "value", .avg);
    defer avg_result.deinit(allocator);
    try std.testing.expectEqual(@as(f64, 20.0), avg_result.value.float64);
}

test "Table indexes support point lookup" {
    const allocator = std.testing.allocator;

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };

    var table = try Table.init(allocator, "users", &schema_def);
    defer table.deinit();

    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
    });

    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .string = "Bob" },
    });

    try table.createIndex("idx_users_id", "id");

    const lookup = try table.lookupIndex(allocator, "id", Value{ .int32 = 2 });
    defer if (lookup.owned and lookup.rows.len > 0) allocator.free(lookup.rows);

    try std.testing.expectEqual(@as(usize, 1), lookup.rows.len);
    try std.testing.expectEqual(@as(usize, 1), lookup.rows[0]);
}

test "Composite hash index lookup" {
    const allocator = std.testing.allocator;

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "user_id", .data_type = .int32 },
        .{ .name = "region", .data_type = .string },
        .{ .name = "amount", .data_type = .float64 },
    };

    var table = try Table.init(allocator, "orders", &schema_def);
    defer table.deinit();

    try table.insertRow(&[_]Value{
        Value{ .int32 = 42 },
        Value{ .string = "us-east" },
        Value{ .float64 = 100.0 },
    });
    try table.insertRow(&[_]Value{
        Value{ .int32 = 42 },
        Value{ .string = "eu" },
        Value{ .float64 = 55.0 },
    });

    var composite_cols = [_][]const u8{ "user_id", "region" };
    try table.createCompositeIndex("idx_orders_user_region", composite_cols[0..]);

    const lookup_vals = [_]Value{ Value{ .int32 = 42 }, Value{ .string = "us-east" } };
    const lookup = try table.lookupCompositeIndexByName(allocator, "idx_orders_user_region", &lookup_vals);
    defer if (lookup.owned and lookup.rows.len > 0) allocator.free(lookup.rows);

    try std.testing.expectEqual(@as(usize, 1), lookup.rows.len);
    try std.testing.expectEqual(@as(usize, 0), lookup.rows[0]);
}
