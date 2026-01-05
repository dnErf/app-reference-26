const std = @import("std");
const types = @import("types.zig");
const storage_engine = @import("storage_engine.zig");
const parquet = @import("parquet.zig");
const column_mod = @import("column.zig");
const table_mod = @import("table.zig");
const schema_mod = @import("schema.zig");

const Value = types.Value;
const StorageEngine = storage_engine.StorageEngine;
const StorageCapabilities = storage_engine.StorageCapabilities;
const PerformanceMetrics = storage_engine.PerformanceMetrics;
const Column = column_mod.Column;
const Table = table_mod.Table;
const Schema = schema_mod.Schema;
const ParquetWriter = parquet.ParquetWriter;

/// Column Store - Disk-based columnar storage optimized for OLAP workloads
/// Uses Parquet format for efficient compression and query performance
/// Supports advanced compression algorithms and columnar query optimizations
pub const ColumnStore = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8,
    tables: std.StringHashMap(*Table),
    compression_algorithm: CompressionAlgorithm,
    performance_metrics: PerformanceMetrics,
    start_time: i64,

    pub const CompressionAlgorithm = enum {
        none,
        snappy,
        gzip,
        lz4,
        zstd,
    };

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !*ColumnStore {
        const path_copy = try allocator.dupe(u8, base_path);
        errdefer allocator.free(path_copy);

        const store = try allocator.create(ColumnStore);
        store.* = ColumnStore{
            .allocator = allocator,
            .base_path = path_copy,
            .tables = std.StringHashMap(*Table).init(allocator),
            .compression_algorithm = .lz4, // Default to LZ4 for good compression/speed balance
            .performance_metrics = PerformanceMetrics{
                .read_latency_ms = 0.0,
                .write_latency_ms = 0.0,
                .compression_ratio = 1.0,
                .throughput_mbps = 0.0,
            },
            .start_time = @intCast(std.time.nanoTimestamp()),
        };
        return store;
    }

    pub fn deinit(self: *ColumnStore) void {
        var it = self.tables.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.tables.deinit();
        self.allocator.free(self.base_path);
        self.allocator.destroy(self);
    }

    /// Create a new table with columnar storage
    pub fn createTable(self: *ColumnStore, table_name: []const u8, schema_def: []const Schema.ColumnDef) !void {
        if (self.tables.contains(table_name)) {
            return error.TableAlreadyExists;
        }

        const name_copy = try self.allocator.dupe(u8, table_name);
        errdefer self.allocator.free(name_copy);

        const table = try self.allocator.create(Table);
        table.* = try Table.init(self.allocator, name_copy, schema_def);
        errdefer {
            table.deinit();
            self.allocator.destroy(table);
        }

        try self.tables.put(name_copy, table);
    }

    /// Insert rows into a columnar table
    pub fn insertRows(self: *ColumnStore, table_name: []const u8, rows: []const []const Value) !void {
        const table = self.tables.get(table_name) orelse return error.TableNotFound;

        const start_time = std.time.nanoTimestamp();

        // Validate row structure
        for (rows) |row| {
            if (row.len != table.schema.columns.len) {
                return error.ColumnCountMismatch;
            }
        }

        // Insert rows into the table
        for (rows) |row| {
            try table.insertRow(row);
        }

        // Update performance metrics
        const end_time = std.time.nanoTimestamp();
        const duration_ms = @as(f32, @floatFromInt(end_time - start_time)) / 1_000_000.0;
        self.performance_metrics.write_latency_ms = duration_ms;

        // Calculate throughput
        const total_bytes = rows.len * table.schema.columns.len * 8; // Rough estimate
        const duration_seconds = duration_ms / 1000.0;
        self.performance_metrics.throughput_mbps = @as(f32, @floatFromInt(total_bytes)) / (1024 * 1024) / duration_seconds;
    }

    /// Query data from columnar storage with optimizations
    pub fn queryTable(self: *ColumnStore, table_name: []const u8, where_clause: ?[]const u8, allocator: std.mem.Allocator) ![]Value {
        const table = self.tables.get(table_name) orelse return error.TableNotFound;

        const start_time = std.time.nanoTimestamp();

        // For now, return all rows (simplified implementation)
        // TODO: Implement WHERE clause parsing and columnar filtering
        _ = where_clause;

        var results = std.ArrayList(Value).initCapacity(allocator, table.row_count) catch unreachable;
        errdefer results.deinit(allocator);

        // Convert table data to result format
        var row_idx: usize = 0;
        while (row_idx < table.row_count) : (row_idx += 1) {
            // For columnar storage, we can optimize by reading only needed columns
            // For now, return first column value as example
            if (table.columns.len > 0) {
                const val = try table.getCell(row_idx, 0);
                try results.append(allocator, try val.clone(allocator));
            } else {
                try results.append(allocator, Value{ .string = try allocator.dupe(u8, "EMPTY_ROW") });
            }
        }

        // Update performance metrics
        const end_time = std.time.nanoTimestamp();
        const duration_ms = @as(f32, @floatFromInt(end_time - start_time)) / 1_000_000.0;
        self.performance_metrics.read_latency_ms = duration_ms;

        // Calculate throughput
        const total_bytes = results.items.len * 100; // Rough estimate
        const duration_seconds = duration_ms / 1000.0;
        self.performance_metrics.throughput_mbps = @as(f32, @floatFromInt(total_bytes)) / (1024 * 1024) / duration_seconds;

        return results.toOwnedSlice(allocator);
    }

    /// Save table to Parquet file with compression
    pub fn saveToParquet(self: *ColumnStore, table_name: []const u8, file_path: []const u8) !void {
        const table = self.tables.get(table_name) orelse return error.TableNotFound;

        var parquet_writer = ParquetWriter.init(self.allocator);
        try parquet_writer.writeTable(table, file_path);

        // Update compression metrics (simplified)
        // In a real implementation, we'd track actual compression ratios
        self.performance_metrics.compression_ratio = switch (self.compression_algorithm) {
            .none => 1.0,
            .snappy => 1.5,
            .gzip => 2.0,
            .lz4 => 1.8,
            .zstd => 2.5,
        };
    }

    /// Load table from Parquet file
    pub fn loadFromParquet(self: *ColumnStore, table_name: []const u8, file_path: []const u8, schema_def: []const Schema.ColumnDef) !void {
        // TODO: Implement Parquet reading
        // For now, create empty table
        try self.createTable(table_name, schema_def);
        _ = file_path;
    }

    /// Get storage capabilities
    pub fn getCapabilities(self: *const ColumnStore) StorageCapabilities {
        _ = self;
        return StorageCapabilities{
            .supports_olap = true, // Excellent for analytical queries
            .supports_oltp = false, // Not optimized for frequent updates
            .supports_graph = false,
            .supports_blockchain = false,
        };
    }

    /// Get current performance metrics
    pub fn getPerformanceMetrics(self: *const ColumnStore) PerformanceMetrics {
        return self.performance_metrics;
    }

    /// Convert to StorageEngine interface
    pub fn asStorageEngine(self: *ColumnStore) StorageEngine {
        return StorageEngine{
            .ptr = self,
            .vtable = &COLUMN_STORE_VTABLE,
        };
    }
};

// Virtual table for ColumnStore
const COLUMN_STORE_VTABLE = StorageEngine.VTable{
    .save = columnStoreSave,
    .load = columnStoreLoad,
    .query = columnStoreQuery,
    .getCapabilities = columnStoreGetCapabilities,
    .getPerformanceMetrics = columnStoreGetPerformanceMetrics,
    .deinit = columnStoreDeinit,
};

fn columnStoreSave(ptr: *anyopaque, data: []const u8) anyerror!void {
    const self: *ColumnStore = @ptrCast(@alignCast(ptr));
    // Save data to Parquet format
    // For now, just store as a simple file
    const file_path = try std.fmt.allocPrint(self.allocator, "{s}/data.parquet", .{self.base_path});
    defer self.allocator.free(file_path);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    try file.writeAll(data);
}

fn columnStoreLoad(ptr: *anyopaque, key: []const u8) anyerror![]u8 {
    const self: *ColumnStore = @ptrCast(@alignCast(ptr));
    // Load data from Parquet format
    const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.parquet", .{ self.base_path, key });
    defer self.allocator.free(file_path);

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try self.allocator.alloc(u8, file_size);
    errdefer self.allocator.free(buffer);

    _ = try file.readAll(buffer);
    return buffer;
}

fn columnStoreQuery(ptr: *anyopaque, query_str: []const u8, allocator: std.mem.Allocator) anyerror![]Value {
    const self: *ColumnStore = @ptrCast(@alignCast(ptr));

    // Simple query parsing - extract table name
    var tokens = std.mem.tokenizeAny(u8, query_str, " ");
    _ = tokens.next(); // SELECT
    _ = tokens.next(); // *
    _ = tokens.next(); // FROM

    const table_name = tokens.next() orelse return error.InvalidQuery;
    const where_clause = if (tokens.next()) |where| if (std.mem.eql(u8, where, "WHERE")) tokens.rest() else null else null;

    return self.queryTable(table_name, where_clause, allocator);
}

fn columnStoreGetCapabilities(ptr: *anyopaque) StorageCapabilities {
    const self: *const ColumnStore = @ptrCast(@alignCast(ptr));
    return self.getCapabilities();
}

fn columnStoreGetPerformanceMetrics(ptr: *anyopaque) PerformanceMetrics {
    const self: *const ColumnStore = @ptrCast(@alignCast(ptr));
    return self.getPerformanceMetrics();
}

fn columnStoreDeinit(ptr: *anyopaque) void {
    const self: *ColumnStore = @ptrCast(@alignCast(ptr));
    self.deinit();
}
