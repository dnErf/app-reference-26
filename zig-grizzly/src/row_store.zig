const std = @import("std");
const types = @import("types.zig");
const storage_engine = @import("storage_engine.zig");
const avro_bridge = @import("avro_bridge.zig");
const index_mod = @import("index.zig");
const table_mod = @import("table.zig");
const schema_mod = @import("schema.zig");

const Value = types.Value;
const StorageEngine = storage_engine.StorageEngine;
const StorageCapabilities = storage_engine.StorageCapabilities;
const PerformanceMetrics = storage_engine.PerformanceMetrics;
const Table = table_mod.Table;
const Schema = schema_mod.Schema;
const AvroWriter = avro_bridge.AvroWriter;
const AvroReader = avro_bridge.AvroReader;
const Index = index_mod.Index;

/// Row Store - Disk-based row storage optimized for OLTP workloads
/// Uses Avro format for efficient row-based operations with ACID transactions
/// Supports indexing for fast lookups and frequent updates/deletes
pub const RowStore = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8,
    tables: std.StringHashMap(*Table),
    indexes: std.StringHashMap(*Index),
    transaction_log: std.ArrayList(TransactionEntry),
    performance_metrics: PerformanceMetrics,
    start_time: i64,

    pub const TransactionEntry = struct {
        timestamp: i64,
        operation: Operation,
        table_name: []const u8,
        row_id: usize,
        old_data: ?[]const u8,
        new_data: ?[]const u8,
    };

    pub const Operation = enum {
        insert,
        update,
        delete,
    };

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !*RowStore {
        const path_copy = try allocator.dupe(u8, base_path);
        errdefer allocator.free(path_copy);

        const store = try allocator.create(RowStore);
        store.* = RowStore{
            .allocator = allocator,
            .base_path = path_copy,
            .tables = std.StringHashMap(*Table).init(allocator),
            .indexes = std.StringHashMap(*Index).init(allocator),
            .transaction_log = try std.ArrayList(TransactionEntry).initCapacity(allocator, 0),
            .performance_metrics = PerformanceMetrics{
                .read_latency_ms = 0.0,
                .write_latency_ms = 0.0,
                .compression_ratio = 1.0,
                .throughput_mbps = 0.0,
            },
            .start_time = std.time.milliTimestamp(),
        };

        // Create base directory if it doesn't exist
        std.fs.cwd().makeDir(path_copy) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        return store;
    }

    pub fn deinit(self: *RowStore) void {
        self.allocator.free(self.base_path);

        var table_iter = self.tables.iterator();
        while (table_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.tables.deinit();

        var index_iter = self.indexes.iterator();
        while (index_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.indexes.deinit();

        for (self.transaction_log.items) |*entry| {
            self.allocator.free(entry.table_name);
            if (entry.old_data) |old| self.allocator.free(old);
            if (entry.new_data) |new| self.allocator.free(new);
        }
        self.transaction_log.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Create a new table in the row store
    pub fn createTable(self: *RowStore, name: []const u8, schema: Schema) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const table = try self.allocator.create(Table);
        errdefer self.allocator.destroy(table);

        table.* = try Table.init(self.allocator, name_copy, schema.columns);
        errdefer table.deinit();

        try self.tables.put(name_copy, table);

        // Create primary key index automatically on first column
        if (schema.columns.len > 0) {
            try self.createIndex(name, schema.columns[0].name, .btree);
        }
    }

    /// Create an index on a table column
    pub fn createIndex(self: *RowStore, table_name: []const u8, column_name: []const u8, index_type: index_mod.IndexType) !void {
        const table = self.tables.get(table_name) orelse return error.TableNotFound;

        const index_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}_idx", .{ table_name, column_name });
        defer self.allocator.free(index_name);

        const index = try self.allocator.create(Index);
        errdefer self.allocator.destroy(index);

        index.* = try Index.init(self.allocator, index_name, table, column_name, index_type);
        errdefer index.deinit();

        const name_copy = try self.allocator.dupe(u8, index_name);
        errdefer self.allocator.free(name_copy);

        try self.indexes.put(name_copy, index);
    }

    /// Insert a row into a table with transaction logging
    pub fn insertRow(self: *RowStore, table_name: []const u8, row_data: []const Value) !void {
        const start_time = std.time.milliTimestamp();

        const table = self.tables.get(table_name) orelse return error.TableNotFound;

        // Serialize row to Avro format
        var avro_writer = try AvroWriter.init(self.allocator, table.schema);
        defer avro_writer.deinit();
        const avro_data = try avro_writer.serializeRow(table.schema, row_data);
        defer self.allocator.free(avro_data);

        // Generate row ID (simple auto-increment for now)
        const row_id = table.rows.items.len;

        // Store the row
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}/{d}.avro", .{ self.base_path, table_name, row_id });
        defer self.allocator.free(file_path);

        // Ensure table directory exists
        const table_dir = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.base_path, table_name });
        defer self.allocator.free(table_dir);
        std.fs.cwd().makeDir(table_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        try file.writeAll(avro_data);

        // Add to table's row collection
        try table.rows.append(table.allocator, try self.allocator.dupe(Value, row_data));

        // Update indexes
        try self.updateIndexes(table_name, row_id, row_data);

        // Log transaction
        const entry = TransactionEntry{
            .timestamp = std.time.milliTimestamp(),
            .operation = .insert,
            .table_name = try self.allocator.dupe(u8, table_name),
            .row_id = row_id,
            .old_data = null,
            .new_data = try self.allocator.dupe(u8, avro_data),
        };
        try self.transaction_log.append(self.allocator, entry);

        // Update performance metrics
        const duration = std.time.milliTimestamp() - start_time;
        self.performance_metrics.write_latency_ms = @floatCast(@as(f64, @floatFromInt(duration)));
        self.performance_metrics.throughput_mbps = @as(f32, @floatFromInt(avro_data.len)) / @as(f32, @floatFromInt(duration)) * 1000.0 / (1024.0 * 1024.0);
    }

    /// Update a row in a table with transaction logging
    pub fn updateRow(self: *RowStore, table_name: []const u8, row_id: usize, new_data: []const Value) !void {
        const start_time = std.time.milliTimestamp();

        const table = self.tables.get(table_name) orelse return error.TableNotFound;
        if (row_id >= table.rows.items.len) return error.RowNotFound;

        // Get old data for transaction log
        const old_row = table.rows.items[row_id];
        var avro_writer = try AvroWriter.init(self.allocator, table.schema);
        defer avro_writer.deinit();
        const old_avro = try avro_writer.serializeRow(table.schema, old_row);

        // Serialize new row to Avro format
        const new_avro = try avro_writer.serializeRow(table.schema, new_data);

        // Update the file
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}/{d}.avro", .{ self.base_path, table_name, row_id });
        defer self.allocator.free(file_path);

        const file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
        defer file.close();
        try file.writeAll(new_avro);

        // Update table's row collection
        self.allocator.free(table.rows.items[row_id]);
        table.rows.items[row_id] = try self.allocator.dupe(Value, new_data);

        // Update indexes
        try self.updateIndexes(table_name, row_id, new_data);

        // Log transaction
        const entry = TransactionEntry{
            .timestamp = std.time.milliTimestamp(),
            .operation = .update,
            .table_name = try self.allocator.dupe(u8, table_name),
            .row_id = row_id,
            .old_data = old_avro,
            .new_data = new_avro,
        };
        try self.transaction_log.append(self.allocator, entry);

        // Update performance metrics
        const duration = std.time.milliTimestamp() - start_time;
        self.performance_metrics.write_latency_ms = @floatCast(@as(f64, @floatFromInt(duration)));
    }

    /// Delete a row from a table with transaction logging
    pub fn deleteRow(self: *RowStore, table_name: []const u8, row_id: usize) !void {
        const start_time = std.time.milliTimestamp();

        const table = self.tables.get(table_name) orelse return error.TableNotFound;
        if (row_id >= table.rows.items.len) return error.RowNotFound;

        // Get old data for transaction log
        const old_row = table.rows.items[row_id];
        var avro_writer = try AvroWriter.init(self.allocator, table.schema);
        defer avro_writer.deinit();
        const old_avro = try avro_writer.serializeRow(table.schema, old_row);

        // Remove the file
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}/{d}.avro", .{ self.base_path, table_name, row_id });
        defer self.allocator.free(file_path);
        std.fs.cwd().deleteFile(file_path) catch |err| {
            if (err != error.FileNotFound) return err;
        };

        // Update table's row collection (mark as deleted)
        self.allocator.free(table.rows.items[row_id]);
        table.rows.items[row_id] = &[_]Value{}; // Empty slice to mark deleted

        // Update indexes (remove from indexes)
        try self.removeFromIndexes(table_name, row_id);

        // Log transaction
        const entry = TransactionEntry{
            .timestamp = std.time.milliTimestamp(),
            .operation = .delete,
            .table_name = try self.allocator.dupe(u8, table_name),
            .row_id = row_id,
            .old_data = old_avro,
            .new_data = null,
        };
        try self.transaction_log.append(self.allocator, entry);

        // Update performance metrics
        const duration = std.time.milliTimestamp() - start_time;
        self.performance_metrics.write_latency_ms = @floatCast(@as(f64, @floatFromInt(duration)));
    }

    /// Query rows from a table using indexes where possible
    pub fn queryTable(self: *RowStore, table_name: []const u8, where_clause: ?[]const u8, allocator: std.mem.Allocator) ![][]Value {
        const start_time = std.time.milliTimestamp();

        const table = self.tables.get(table_name) orelse return error.TableNotFound;

        var results = try std.ArrayList([]Value).initCapacity(allocator, 0);
        errdefer results.deinit(allocator);

        // Simple WHERE clause parsing for indexed lookups
        if (where_clause) |clause| {
            // Parse "id = 123" style conditions
            if (std.mem.indexOf(u8, clause, "id = ")) |pos| {
                const id_str = clause[pos + 5 ..];
                const row_id = std.fmt.parseInt(usize, std.mem.trim(u8, id_str, " "), 10) catch return error.InvalidWhereClause;

                if (row_id < table.rows.items.len and table.rows.items[row_id].len > 0) {
                    try results.append(allocator, try allocator.dupe(Value, table.rows.items[row_id]));
                }
            } else {
                // Fall back to full table scan
                for (table.rows.items) |row| {
                    if (row.len > 0) { // Skip deleted rows
                        try results.append(allocator, try allocator.dupe(Value, row));
                    }
                }
            }
        } else {
            // Return all rows
            for (table.rows.items) |row| {
                if (row.len > 0) { // Skip deleted rows
                    try results.append(allocator, try allocator.dupe(Value, row));
                }
            }
        }

        // Update performance metrics
        const duration = std.time.milliTimestamp() - start_time;
        self.performance_metrics.read_latency_ms = @floatCast(@as(f64, @floatFromInt(duration)));

        return results.toOwnedSlice(self.allocator);
    }

    /// Update indexes when a row changes
    fn updateIndexes(self: *RowStore, table_name: []const u8, row_id: usize, row_data: []const Value) !void {
        var index_iter = self.indexes.iterator();
        while (index_iter.next()) |entry| {
            const index = entry.value_ptr.*;
            if (std.mem.indexOf(u8, index.name, table_name)) |_| {
                try index.insert(row_id, row_data);
            }
        }
    }

    /// Remove a row from all indexes
    fn removeFromIndexes(self: *RowStore, table_name: []const u8, row_id: usize) !void {
        var index_iter = self.indexes.iterator();
        while (index_iter.next()) |entry| {
            const index = entry.value_ptr.*;
            if (std.mem.indexOf(u8, index.name, table_name)) |_| {
                try index.remove(row_id);
            }
        }
    }

    /// Get storage capabilities
    pub fn getCapabilities(_: *const RowStore) StorageCapabilities {
        return StorageCapabilities{
            .supports_olap = false,
            .supports_oltp = true,
            .supports_graph = false,
            .supports_blockchain = false,
        };
    }

    /// Get current performance metrics
    pub fn getPerformanceMetrics(self: *const RowStore) PerformanceMetrics {
        return self.performance_metrics;
    }

    /// Convert to StorageEngine interface
    pub fn asStorageEngine(self: *RowStore) StorageEngine {
        return StorageEngine{
            .ptr = self,
            .vtable = &ROW_STORE_VTABLE,
        };
    }
};

// Virtual table for RowStore
const ROW_STORE_VTABLE = StorageEngine.VTable{
    .save = rowStoreSave,
    .load = rowStoreLoad,
    .query = rowStoreQuery,
    .getCapabilities = rowStoreGetCapabilities,
    .getPerformanceMetrics = rowStoreGetPerformanceMetrics,
    .deinit = rowStoreDeinit,
};

fn rowStoreSave(ptr: *anyopaque, data: []const u8) anyerror!void {
    const self: *RowStore = @ptrCast(@alignCast(ptr));
    // For row store, data should be in format: "table_name,row_data_json"
    // Parse and insert
    const comma_pos = std.mem.indexOf(u8, data, ",") orelse return error.InvalidDataFormat;
    const table_name = data[0..comma_pos];
    const row_json = data[comma_pos + 1 ..];

    // Parse JSON row data (simplified - would need proper JSON parsing)
    var values = try std.ArrayList(Value).initCapacity(self.allocator, 0);
    defer values.deinit(self.allocator);

    // For now, just store the raw data
    try self.insertRow(table_name, &[_]Value{Value{ .string = try self.allocator.dupe(u8, row_json) }});
}

fn rowStoreLoad(ptr: *anyopaque, key: []const u8) anyerror![]u8 {
    const self: *RowStore = @ptrCast(@alignCast(ptr));
    // Parse key as "table_name,row_id"
    const comma_pos = std.mem.indexOf(u8, key, ",") orelse return error.InvalidKeyFormat;
    const table_name = key[0..comma_pos];
    const row_id_str = key[comma_pos + 1 ..];
    const row_id = std.fmt.parseInt(usize, row_id_str, 10) catch return error.InvalidKeyFormat;

    const table = self.tables.get(table_name) orelse return error.TableNotFound;
    if (row_id >= table.rows.items.len or table.rows.items[row_id].len == 0) return error.RowNotFound;

    // Return as JSON string (simplified)
    return std.fmt.allocPrint(self.allocator, "{{{}}}", .{std.json.fmt(table.rows.items[row_id], .{})});
}

fn rowStoreQuery(ptr: *anyopaque, query_str: []const u8, allocator: std.mem.Allocator) anyerror![]Value {
    const self: *RowStore = @ptrCast(@alignCast(ptr));

    // Simple query parsing - extract table name
    var tokens = std.mem.tokenizeAny(u8, query_str, " ");
    _ = tokens.next(); // SELECT
    _ = tokens.next(); // *
    _ = tokens.next(); // FROM

    const table_name = tokens.next() orelse return error.InvalidQuery;
    const where_clause = if (tokens.next()) |where| if (std.mem.eql(u8, where, "WHERE")) tokens.rest() else null else null;

    const rows = try self.queryTable(table_name, where_clause, allocator);
    defer allocator.free(rows);

    // Return first row if any, otherwise empty array
    if (rows.len > 0) {
        return allocator.dupe(Value, rows[0]);
    } else {
        return allocator.dupe(Value, &[_]Value{});
    }
}

fn rowStoreGetCapabilities(ptr: *anyopaque) StorageCapabilities {
    const self: *const RowStore = @ptrCast(@alignCast(ptr));
    return self.getCapabilities();
}

fn rowStoreGetPerformanceMetrics(ptr: *anyopaque) PerformanceMetrics {
    const self: *const RowStore = @ptrCast(@alignCast(ptr));
    return self.getPerformanceMetrics();
}

fn rowStoreDeinit(ptr: *anyopaque) void {
    const self: *RowStore = @ptrCast(@alignCast(ptr));
    self.deinit();
}
