const std = @import("std");
const types = @import("types.zig");
const database_mod = @import("database.zig");
const table_mod = @import("table.zig");
const schema_mod = @import("schema.zig");
const column_mod = @import("column.zig");

const compression = @import("compression.zig");
const checkpoint = @import("checkpoint.zig");
const format_mod = @import("format.zig");

const Database = database_mod.Database;
const Table = table_mod.Table;
const Schema = schema_mod.Schema;
const Column = column_mod.Column;
const DataType = types.DataType;
const Value = types.Value;
const VectorValue = types.VectorValue;

const SnapshotType = enum { full, incremental };

const DeltaEntry = struct {
    path: []const u8,
    timestamp: i64,
};

const SnapshotManifest = struct {
    allocator: std.mem.Allocator,
    version: u16,
    snapshot_type: SnapshotType,
    timestamp: i64,
    table_counts: std.StringHashMap(usize),
    delta_history: std.ArrayList(DeltaEntry),

    fn deinit(self: *SnapshotManifest) void {
        var it = self.table_counts.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.table_counts.deinit();
        for (self.delta_history.items) |entry| {
            self.allocator.free(entry.path);
        }
        self.delta_history.deinit(self.allocator);
    }
};

/// Lakehouse manages persistence for structured and unstructured data
/// Inspired by Databricks Lakehouse architecture
pub const Lakehouse = struct {
    /// Magic bytes for Grizzly database files
    pub const MAGIC: [4]u8 = .{ 'G', 'R', 'I', 'Z' };
    pub const VERSION: u16 = 4; // Lakehouse format with vector + compression metadata
    pub const MAX_DELTA_CHAIN: usize = 5;

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Lakehouse {
        return .{ .allocator = allocator };
    }

    pub const ColumnCompressionInfo = struct {
        name: []const u8,
        codec: compression.CompressionCodec,
        original_size: usize,
        compressed_size: usize,
        min: ?i64 = null,
        max: ?i64 = null,
        cardinality: ?usize = null,
    };

    /// Helper to write integer to file
    fn writeInt(file: std.fs.File, comptime T: type, value: T, endian: std.builtin.Endian) !void {
        var buf: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &buf, value, endian);
        try file.writeAll(&buf);
    }

    /// Save database to lakehouse format
    /// Creates:
    /// - database.griz (main file with metadata and small tables)
    /// - database.lakehouse/ (directory for large data)
    ///   - metadata/ (schemas, indexes, stats)
    ///   - data/ (columnar data files per table)
    ///   - unstructured/ (external files, JSON, blobs)
    pub fn save(self: Lakehouse, db: *Database, path: []const u8, file_compression: format_mod.CompressionType) !void {
        // TODO: Implement file-level compression (lz4, zstd, etc.)
        _ = file_compression;
        // Create main .griz file
        const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();

        // Write header
        try file.writeAll(&MAGIC);
        try writeInt(file, u16, VERSION, .little);

        // Write database name length and name
        const name_len = @as(u32, @intCast(db.name.len));
        try writeInt(file, u32, name_len, .little);
        try file.writeAll(db.name);

        // Write number of tables
        const table_count = @as(u32, @intCast(db.tables.count()));
        try writeInt(file, u32, table_count, .little);

        // Attempt to resume from an existing AI checkpoint if present
        const cp = checkpoint.read(self.allocator) catch null;
        defer if (cp) |c| c.deinit(self.allocator);
        var resume_from: ?[]const u8 = null;
        if (cp) |c| {
            if (std.mem.eql(u8, c.task, "save") and std.mem.eql(u8, c.step, "writeTable") and std.mem.eql(u8, c.status, "in-progress")) {
                resume_from = c.table;
            }
        }

        // Write each table and collect compression metadata
        var comp_map = std.StringHashMap(std.ArrayList(ColumnCompressionInfo)).init(self.allocator);
        defer {
            var it_cleanup = comp_map.iterator();
            while (it_cleanup.next()) |entry| {
                // free key copies and inner lists
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.*.deinit(self.allocator);
            }
            comp_map.deinit();
        }
        errdefer {
            var it_cleanup = comp_map.iterator();
            while (it_cleanup.next()) |entry| {
                // free key copies and inner lists
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.*.deinit(self.allocator);
            }
            comp_map.deinit();
        }

        var it = db.tables.iterator();
        var skipping: bool = resume_from != null;
        while (it.next()) |entry| {
            if (skipping) {
                // Skip until we find the checkpointed table, then resume AFTER it.
                if (std.mem.eql(u8, entry.key_ptr.*, resume_from.?)) {
                    skipping = false;
                    continue;
                }
                continue;
            }

            var comp_list = std.ArrayList(ColumnCompressionInfo){};

            // AI_CHECKPOINT: task=save step=writeTable table={s}
            // Record checkpoint before starting work on this table so AI agents
            // interrupted by rate limits or external errors can resume here.
            const pre_cp: checkpoint.Checkpoint = .{
                .task = "save",
                .step = "writeTable",
                .table = entry.key_ptr.*,
                .column_index = null,
                .status = "in-progress",
                .timestamp = std.time.timestamp(),
            };
            try checkpoint.write(self.allocator, pre_cp);

            // writeTable will append per-column compression info into comp_list
            try self.writeTable(file, entry.key_ptr.*, entry.value_ptr.*, &comp_list);

            // After successful write, persist the compression info and advance
            const name_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            try comp_map.put(name_copy, comp_list);

            // Update checkpoint to mark this table done (so resume skips it next time)
            const done_cp: checkpoint.Checkpoint = .{
                .task = "save",
                .step = "writeTable",
                .table = entry.key_ptr.*,
                .column_index = null,
                .status = "completed",
                .timestamp = std.time.timestamp(),
            };
            try checkpoint.write(self.allocator, done_cp);
        }

        // Clear checkpoint on success
        checkpoint.clear();

        // Create lakehouse directory structure
        const lakehouse_dir = try self.deriveLakehouseDir(path);
        defer self.allocator.free(lakehouse_dir);

        std.fs.cwd().makeDir(lakehouse_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Create subdirectories
        const metadata_dir = try std.fmt.allocPrint(self.allocator, "{s}/metadata", .{lakehouse_dir});
        defer self.allocator.free(metadata_dir);
        std.fs.cwd().makeDir(metadata_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const data_dir = try std.fmt.allocPrint(self.allocator, "{s}/data", .{lakehouse_dir});
        defer self.allocator.free(data_dir);
        std.fs.cwd().makeDir(data_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const unstructured_dir = try std.fmt.allocPrint(self.allocator, "{s}/unstructured", .{lakehouse_dir});
        defer self.allocator.free(unstructured_dir);
        std.fs.cwd().makeDir(unstructured_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Write metadata files for each table that was written (in comp_map)
        var meta_it = comp_map.iterator();
        while (meta_it.next()) |entry| {
            const table_ptr = db.tables.get(entry.key_ptr.*) orelse return error.InternalError;
            try self.writeTableMetadata(metadata_dir, entry.key_ptr.*, table_ptr, &entry.value_ptr.*);
        }

        try self.writeSnapshotManifest(path, db, .full, &[_]DeltaEntry{});
    }

    /// Load database from lakehouse format
    pub fn load(self: Lakehouse, path: []const u8) !Database {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        // Read entire file into memory
        const file_size = (try file.stat()).size;
        const file_data = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(file_data);
        const bytes_read = try file.readAll(file_data);
        if (bytes_read != file_size) return error.IncompleteRead;

        var pos: usize = 0;

        // Read and verify header
        var magic: [4]u8 = undefined;
        @memcpy(&magic, file_data[pos .. pos + 4]);
        pos += 4;
        if (!std.mem.eql(u8, &magic, &MAGIC)) {
            return error.InvalidFileFormat;
        }

        const version = std.mem.readInt(u16, file_data[pos..][0..2], .little);
        pos += 2;
        if (version > VERSION) {
            return error.UnsupportedVersion;
        }

        // Read database name
        const name_len = std.mem.readInt(u32, file_data[pos..][0..4], .little);
        pos += 4;
        const name = try self.allocator.alloc(u8, name_len);
        errdefer self.allocator.free(name);
        @memcpy(name, file_data[pos .. pos + name_len]);
        pos += name_len;

        var db = try Database.init(self.allocator, name);
        errdefer db.deinit();
        self.allocator.free(name); // Database made its own copy

        // Read tables
        const table_count = std.mem.readInt(u32, file_data[pos..][0..4], .little);
        pos += 4;
        var i: u32 = 0;
        while (i < table_count) : (i += 1) {
            pos = try self.readTable(version, file_data, pos, &db);
        }

        return db;
    }

    /// Persist only new rows relative to the last snapshot manifest
    pub fn saveIncremental(self: Lakehouse, db: *Database, base_snapshot: []const u8, delta_path: []const u8) !void {
        var manifest = try self.loadSnapshotManifest(base_snapshot);
        defer manifest.deinit();

        const TableChange = struct {
            name: []const u8,
            table: *Table,
            start_row: usize,
        };

        var changes = std.ArrayList(TableChange){};
        defer changes.deinit(self.allocator);

        var it = db.tables.iterator();
        while (it.next()) |entry| {
            const table_name = entry.key_ptr.*;
            const table_ptr = entry.value_ptr.*;
            const previous = manifest.table_counts.get(table_name) orelse 0;
            if (table_ptr.row_count > previous) {
                try changes.append(self.allocator, .{
                    .name = table_name,
                    .table = table_ptr,
                    .start_row = previous,
                });
            }
        }

        if (changes.items.len == 0) {
            return error.NoChanges;
        }

        const file = try std.fs.cwd().createFile(delta_path, .{ .truncate = true });
        defer file.close();

        try file.writeAll(&.{ 'G', 'R', 'Z', 'D' });
        try writeInt(file, u16, 1, .little);

        const base_len = @as(u32, @intCast(base_snapshot.len));
        try writeInt(file, u32, base_len, .little);
        try file.writeAll(base_snapshot);

        try writeInt(file, u32, @intCast(changes.items.len), .little);
        for (changes.items) |change| {
            try self.writeDeltaTable(file, change.name, change.table, change.start_row);
        }

        const delta_ts = std.time.timestamp();
        try self.appendDeltaEntry(&manifest, delta_path, delta_ts);

        if (try self.maybeCompactDeltas(base_snapshot, db, &manifest)) {
            return;
        }

        try self.writeSnapshotManifest(base_snapshot, db, .incremental, manifest.delta_history.items);
    }

    /// Apply a delta file on top of a base snapshot
    pub fn applyIncremental(self: Lakehouse, db: *Database, base_snapshot: []const u8, delta_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(delta_path, .{});
        defer file.close();

        const size = (try file.stat()).size;
        const data = try self.allocator.alloc(u8, size);
        defer self.allocator.free(data);
        const read_bytes = try file.readAll(data);
        if (read_bytes != size) return error.IncompleteRead;

        var pos: usize = 0;
        if (size < 4 or !std.mem.eql(u8, data[0..4], &.{ 'G', 'R', 'Z', 'D' })) {
            return error.InvalidDeltaFormat;
        }
        pos += 4;

        const version = std.mem.readInt(u16, data[pos..][0..2], .little);
        pos += 2;
        if (version != 1) return error.UnsupportedVersion;

        const base_len = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        const recorded_base = data[pos .. pos + base_len];
        pos += base_len;
        if (!std.mem.eql(u8, recorded_base, base_snapshot)) {
            return error.SnapshotMismatch;
        }

        var manifest = try self.loadSnapshotManifest(base_snapshot);
        defer manifest.deinit();

        const table_count = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        var idx: u32 = 0;
        while (idx < table_count) : (idx += 1) {
            pos = try self.applyDeltaTable(data, pos, db);
        }

        try self.writeSnapshotManifest(base_snapshot, db, .incremental, manifest.delta_history.items);
    }

    /// Write table to binary format and collect per-column compression metadata
    fn writeTable(self: Lakehouse, file: std.fs.File, name: []const u8, table: *Table, comp_list: *std.ArrayList(ColumnCompressionInfo)) !void {
        // Write table name
        const name_len = @as(u32, @intCast(name.len));
        try writeInt(file, u32, name_len, .little);
        try file.writeAll(name);

        // Write schema
        const col_count = @as(u32, @intCast(table.schema.columns.len));
        try writeInt(file, u32, col_count, .little);

        for (table.schema.columns) |col| {
            // Column name
            const col_name_len = @as(u32, @intCast(col.name.len));
            try writeInt(file, u32, col_name_len, .little);
            try file.writeAll(col.name);

            // Column type
            const type_tag = @as(u8, @intFromEnum(col.data_type));
            var buf: [1]u8 = .{type_tag};
            try file.writeAll(&buf);

            const vector_dim: u16 = @intCast(if (col.data_type == .vector) col.vector_dim else 0);
            try writeInt(file, u16, vector_dim, .little);
        }

        // Write row count
        try writeInt(file, u64, table.row_count, .little);

        // Write column data and capture compression stats
        for (0..table.columns.len) |col_idx| {
            const column = &table.columns[col_idx];
            const codec = compression.chooseCodec(column);
            const blob = try compression.compress(self.allocator, column, codec);
            defer self.allocator.free(blob);

            try file.writeAll(&[_]u8{@intFromEnum(codec)});
            try writeInt(file, u32, @intCast(blob.len), .little);
            try file.writeAll(blob);

            const original_size = column.len * column.row_stride;
            var min: ?i64 = null;
            var max: ?i64 = null;
            if (column.data_type == .int32) {
                const s = column.asSlice(i32)[0..column.len];
                if (s.len > 0) {
                    var mn: i32 = s[0];
                    var mx: i32 = s[0];
                    for (s) |v| {
                        if (v < mn) mn = v;
                        if (v > mx) mx = v;
                    }
                    min = @as(i64, mn);
                    max = @as(i64, mx);
                }
            } else if (column.data_type == .int64) {
                const s = column.asSlice(i64)[0..column.len];
                if (s.len > 0) {
                    var mn: i64 = s[0];
                    var mx: i64 = s[0];
                    for (s) |v| {
                        if (v < mn) mn = v;
                        if (v > mx) mx = v;
                    }
                    min = mn;
                    max = mx;
                }
            }

            try comp_list.append(self.allocator, ColumnCompressionInfo{
                .name = table.schema.columns[col_idx].name,
                .codec = codec,
                .original_size = original_size,
                .compressed_size = blob.len,
                .min = min,
                .max = max,
                .cardinality = null,
            });
        }

        const index_count = @as(u32, @intCast(table.indexes.count()));
        try writeInt(file, u32, index_count, .little);

        var idx_it = table.indexes.iterator();
        while (idx_it.next()) |entry| {
            const index = entry.value_ptr.*;

            const index_name_len = @as(u32, @intCast(index.name.len));
            try writeInt(file, u32, index_name_len, .little);
            try file.writeAll(index.name);

            const column_len = @as(u32, @intCast(index.column_name.len));
            try writeInt(file, u32, column_len, .little);
            try file.writeAll(index.column_name);
        }
    }

    /// Write column data with compression metadata
    fn writeColumn(self: Lakehouse, file: std.fs.File, table: *Table, col_idx: usize) !void {
        const column = &table.columns[col_idx];
        const codec = compression.chooseCodec(column);
        const blob = try compression.compress(self.allocator, column, codec);
        defer self.allocator.free(blob);

        try file.writeAll(&[_]u8{@intFromEnum(codec)});
        try writeInt(file, u32, @intCast(blob.len), .little);
        try file.writeAll(blob);
    }

    /// Read table from binary format
    fn readTable(self: Lakehouse, version: u16, data: []const u8, start_pos: usize, db: *Database) !usize {
        var pos = start_pos;

        // Read table name
        const name_len = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        const name_slice = data[pos .. pos + name_len];
        pos += name_len;

        // Allocate copy of name for Database
        const name = try self.allocator.alloc(u8, name_len);
        defer self.allocator.free(name); // Table will make its own copy
        @memcpy(name, name_slice);

        // Read schema
        const col_count = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        const schema_def = try self.allocator.alloc(Schema.ColumnDef, col_count);
        defer self.allocator.free(schema_def);

        for (schema_def) |*col| {
            // Column name
            const col_name_len = std.mem.readInt(u32, data[pos..][0..4], .little);
            pos += 4;
            const col_name = try self.allocator.alloc(u8, col_name_len);
            errdefer self.allocator.free(col_name);
            @memcpy(col_name, data[pos .. pos + col_name_len]);
            pos += col_name_len;
            col.name = col_name;

            // Column type
            const type_tag = data[pos];
            pos += 1;
            col.data_type = @enumFromInt(type_tag);
            if (version >= 4) {
                const vec_dim = std.mem.readInt(u16, data[pos..][0..2], .little);
                pos += 2;
                col.vector_dim = vec_dim;
            } else {
                col.vector_dim = 0;
            }
        }

        // Create table
        try db.createTable(name, schema_def);
        const table = try db.getTable(name);

        // Clean up schema column names (they were copied by createTable)
        for (schema_def) |col| {
            self.allocator.free(col.name);
        }

        // Read row count
        const row_count = std.mem.readInt(u64, data[pos..][0..8], .little);
        pos += 8;

        // Read column data
        for (0..table.columns.len) |col_idx| {
            if (version >= 4) {
                pos = try self.readColumnV4(data, pos, &table.columns[col_idx], row_count);
            } else {
                pos = try self.readColumnLegacy(data, pos, &table.columns[col_idx], row_count);
            }
        }

        table.row_count = row_count;

        if (version >= 3) {
            const index_count = std.mem.readInt(u32, data[pos..][0..4], .little);
            pos += 4;

            var idx: u32 = 0;
            while (idx < index_count) : (idx += 1) {
                const index_name_len = std.mem.readInt(u32, data[pos..][0..4], .little);
                pos += 4;
                const index_name = data[pos .. pos + index_name_len];
                pos += index_name_len;

                const index_column_len = std.mem.readInt(u32, data[pos..][0..4], .little);
                pos += 4;
                const column_name = data[pos .. pos + index_column_len];
                pos += index_column_len;

                try table.createIndex(index_name, column_name);
            }
        }

        return pos;
    }

    /// Read column data based on type
    fn readColumnLegacy(self: Lakehouse, data: []const u8, start_pos: usize, col: *Column, row_count: u64) !usize {
        _ = self;
        var pos = start_pos;
        var i: u64 = 0;
        while (i < row_count) : (i += 1) {
            const value = switch (col.data_type) {
                .int32 => blk: {
                    const val = std.mem.readInt(i32, data[pos..][0..4], .little);
                    pos += 4;
                    break :blk Value{ .int32 = val };
                },
                .int64 => blk: {
                    const val = std.mem.readInt(i64, data[pos..][0..8], .little);
                    pos += 8;
                    break :blk Value{ .int64 = val };
                },
                .float32 => blk: {
                    const bits = std.mem.readInt(u32, data[pos..][0..4], .little);
                    pos += 4;
                    const val: f32 = @bitCast(bits);
                    break :blk Value{ .float32 = val };
                },
                .float64 => blk: {
                    const bits = std.mem.readInt(u64, data[pos..][0..8], .little);
                    pos += 8;
                    const val: f64 = @bitCast(bits);
                    break :blk Value{ .float64 = val };
                },
                .boolean => blk: {
                    const byte = data[pos];
                    pos += 1;
                    break :blk Value{ .boolean = byte != 0 };
                },
                .string => blk: {
                    const str_len = std.mem.readInt(u32, data[pos..][0..4], .little);
                    pos += 4;
                    const str = data[pos .. pos + str_len];
                    pos += str_len;
                    break :blk Value{ .string = str };
                },
                .timestamp => blk: {
                    const val = std.mem.readInt(i64, data[pos..][0..8], .little);
                    pos += 8;
                    break :blk Value{ .timestamp = val };
                },
                .vector => return error.UnsupportedOperation,
                .custom => return error.UnsupportedOperation,
                .exception => return error.UnsupportedOperation,
            };
            try col.append(value);
        }
        return pos;
    }

    fn readColumnV4(self: Lakehouse, data: []const u8, start_pos: usize, col: *Column, row_count: u64) !usize {
        var pos = start_pos;
        const codec_tag = data[pos];
        pos += 1;
        const codec: compression.CompressionCodec = @enumFromInt(codec_tag);
        const blob_len = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        const blob = data[pos .. pos + blob_len];
        pos += blob_len;
        try compression.decompress(self.allocator, col, codec, blob, @intCast(row_count));
        return pos;
    }

    /// Write table metadata to JSON file for AI/human readability
    fn writeTableMetadata(self: Lakehouse, metadata_dir: []const u8, table_name: []const u8, table: *Table, comp_list: *const std.ArrayList(ColumnCompressionInfo)) !void {
        const meta_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.json",
            .{ metadata_dir, table_name },
        );
        defer self.allocator.free(meta_path);

        // Build JSON string
        var json = std.ArrayList(u8){};
        defer json.deinit(self.allocator);

        const writer = json.writer(self.allocator);

        try writer.writeAll("{\n");
        try writer.print("  \"table_name\": \"{s}\",\n", .{table_name});
        try writer.print("  \"row_count\": {d},\n", .{table.row_count});
        try writer.writeAll("  \"schema\": [\n");

        for (table.schema.columns, 0..) |col, i| {
            try writer.writeAll("    {\n");
            const info = comp_list.*.items[i];
            try writer.print("      \"name\": \"{s}\",\n", .{col.name});
            if (col.data_type == .vector) {
                try writer.print("      \"type\": \"vector\",\n", .{});
                try writer.print("      \"vector_dim\": {d},\n", .{col.vector_dim});
            } else {
                try writer.print("      \"type\": \"{s}\",\n", .{col.data_type.name()});
            }
            try writer.writeAll("      \"compression\": {\n");
            try writer.print("        \"codec\": \"{s}\",\n", .{compression.codecName(info.codec)});
            try writer.print("        \"original_size\": {d},\n", .{info.original_size});
            try writer.print("        \"compressed_size\": {d},\n", .{info.compressed_size});
            var ratio: f64 = 0.0;
            if (info.original_size > 0) ratio = @as(f64, @floatFromInt(info.compressed_size)) / @as(f64, @floatFromInt(info.original_size));
            try writer.print("        \"ratio\": {d:.2}\n", .{ratio});
            try writer.writeAll("      }\n");

            if (i < table.schema.columns.len - 1) {
                try writer.writeAll("    },\n");
            } else {
                try writer.writeAll("    }\n");
            }
        }

        try writer.writeAll("  ],\n");

        try writer.writeAll("  \"indexes\": [\n");
        const index_total = table.indexes.count();
        if (index_total == 0) {
            try writer.writeAll("  ],\n");
        } else {
            var idx_it = table.indexes.iterator();
            var idx_written: usize = 0;
            while (idx_it.next()) |entry| {
                const index = entry.value_ptr.*;
                try writer.writeAll("    {\n");
                try writer.print("      \"name\": \"{s}\",\n", .{index.name});
                try writer.print("      \"column\": \"{s}\"\n", .{index.column_name});
                if (idx_written < index_total - 1) {
                    try writer.writeAll("    },\n");
                } else {
                    try writer.writeAll("    }\n");
                }
                idx_written += 1;
            }
            try writer.writeAll("  ],\n");
        }

        try writer.print("  \"created_at\": {d}\n", .{std.time.timestamp()});
        try writer.writeAll("}\n");

        // Write to file
        const file = try std.fs.cwd().createFile(meta_path, .{});
        defer file.close();
        try file.writeAll(json.items);
    }

    /// Store external file reference for unstructured data
    pub fn storeExternalFile(self: Lakehouse, db_path: []const u8, source_path: []const u8, reference_name: []const u8) ![]const u8 {
        const lakehouse_dir = try self.deriveLakehouseDir(db_path);
        defer self.allocator.free(lakehouse_dir);

        const unstructured_dir = try std.fmt.allocPrint(
            self.allocator,
            "{s}/unstructured",
            .{lakehouse_dir},
        );
        defer self.allocator.free(unstructured_dir);

        const dest_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ unstructured_dir, reference_name },
        );

        // Copy file to lakehouse
        try std.fs.cwd().copyFile(source_path, std.fs.cwd(), dest_path, .{});

        return dest_path;
    }

    fn deriveLakehouseDir(self: Lakehouse, snapshot_path: []const u8) ![]u8 {
        if (snapshot_path.len < 5 or !std.mem.endsWith(u8, snapshot_path, ".griz")) {
            return error.InvalidSnapshotPath;
        }
        return try std.fmt.allocPrint(self.allocator, "{s}.lakehouse", .{snapshot_path[0 .. snapshot_path.len - 5]});
    }

    fn manifestPath(self: Lakehouse, snapshot_path: []const u8) ![]u8 {
        const lakehouse_dir = try self.deriveLakehouseDir(snapshot_path);
        defer self.allocator.free(lakehouse_dir);
        return try std.fmt.allocPrint(self.allocator, "{s}/manifest.json", .{lakehouse_dir});
    }

    fn writeSnapshotManifest(
        self: Lakehouse,
        snapshot_path: []const u8,
        db: *Database,
        snap_type: SnapshotType,
        delta_history: []const DeltaEntry,
    ) !void {
        const manifest_path = try self.manifestPath(snapshot_path);
        defer self.allocator.free(manifest_path);

        var buf = std.ArrayList(u8){};
        defer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);

        try writer.writeAll("{\n");
        try writer.print("  \"version\": {d},\n", .{VERSION});
        try writer.print("  \"snapshot_type\": \"{s}\",\n", .{@tagName(snap_type)});
        try writer.print("  \"timestamp\": {d},\n", .{std.time.timestamp()});
        try writer.writeAll("  \"tables\": [\n");

        var first = true;
        var it = db.tables.iterator();
        while (it.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;
            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{entry.key_ptr.*});
            try writer.print("      \"row_count\": {d}\n", .{entry.value_ptr.*.row_count});
            try writer.writeAll("    }");
        }
        if (!first) try writer.writeAll("\n");

        try writer.writeAll("  ],\n");
        try writer.writeAll("  \"deltas\": [\n");
        var wrote_delta = false;
        for (delta_history, 0..) |delta, idx| {
            _ = idx;
            if (wrote_delta) try writer.writeAll(",\n");
            wrote_delta = true;
            try writer.writeAll("    {\n");
            try writer.print("      \"path\": \"{s}\",\n", .{delta.path});
            try writer.print("      \"timestamp\": {d}\n", .{delta.timestamp});
            try writer.writeAll("    }");
        }
        if (wrote_delta) try writer.writeAll("\n");
        try writer.writeAll("  ]\n}\n");

        const manifest_file = try std.fs.cwd().createFile(manifest_path, .{ .truncate = true });
        defer manifest_file.close();
        try manifest_file.writeAll(buf.items);
    }

    fn loadSnapshotManifest(self: Lakehouse, snapshot_path: []const u8) !SnapshotManifest {
        const manifest_path = try self.manifestPath(snapshot_path);
        defer self.allocator.free(manifest_path);

        const file = std.fs.cwd().openFile(manifest_path, .{}) catch return error.SnapshotManifestMissing;
        defer file.close();

        const size = (try file.stat()).size;
        const data = try self.allocator.alloc(u8, size);
        defer self.allocator.free(data);
        const read_bytes = try file.readAll(data);
        if (read_bytes != size) return error.IncompleteRead;

        const TableEntry = struct {
            name: []const u8,
            row_count: usize,
        };

        const DeltaDoc = struct {
            path: []const u8,
            timestamp: i64,
        };

        const ManifestDoc = struct {
            version: u16,
            snapshot_type: []const u8,
            timestamp: i64,
            tables: []TableEntry,
            deltas: ?[]DeltaDoc = null,
        };

        var parsed = try std.json.parseFromSlice(ManifestDoc, self.allocator, data, .{});
        defer parsed.deinit();

        var counts = std.StringHashMap(usize).init(self.allocator);
        errdefer {
            var it_counts = counts.iterator();
            while (it_counts.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            counts.deinit();
        }

        for (parsed.value.tables) |entry| {
            const copy = try self.allocator.dupe(u8, entry.name);
            try counts.put(copy, entry.row_count);
        }

        var deltas = std.ArrayList(DeltaEntry){};
        errdefer {
            for (deltas.items) |delta| {
                self.allocator.free(delta.path);
            }
            deltas.deinit(self.allocator);
        }
        if (parsed.value.deltas) |records| {
            for (records) |delta| {
                const copy = try self.allocator.dupe(u8, delta.path);
                try deltas.append(self.allocator, .{ .path = copy, .timestamp = delta.timestamp });
            }
        }

        const snap_type = if (std.mem.eql(u8, parsed.value.snapshot_type, "full")) SnapshotType.full else SnapshotType.incremental;

        return SnapshotManifest{
            .allocator = self.allocator,
            .version = parsed.value.version,
            .snapshot_type = snap_type,
            .timestamp = parsed.value.timestamp,
            .table_counts = counts,
            .delta_history = deltas,
        };
    }

    fn appendDeltaEntry(self: Lakehouse, manifest: *SnapshotManifest, delta_path: []const u8, delta_ts: i64) !void {
        const copy = try self.allocator.dupe(u8, delta_path);
        errdefer self.allocator.free(copy);
        try manifest.delta_history.append(self.allocator, .{ .path = copy, .timestamp = delta_ts });
    }

    fn maybeCompactDeltas(self: Lakehouse, snapshot_path: []const u8, db: *Database, manifest: *SnapshotManifest) !bool {
        if (manifest.delta_history.items.len < MAX_DELTA_CHAIN) return false;

        try self.save(db, snapshot_path, format_mod.CompressionType.none);

        for (manifest.delta_history.items) |entry| {
            std.fs.cwd().deleteFile(entry.path) catch {};
            self.allocator.free(entry.path);
        }
        manifest.delta_history.clearRetainingCapacity();
        manifest.snapshot_type = .full;
        return true;
    }

    fn writeDeltaTable(self: Lakehouse, file: std.fs.File, table_name: []const u8, table: *Table, start_row: usize) !void {
        const name_len = @as(u32, @intCast(table_name.len));
        try writeInt(file, u32, name_len, .little);
        try file.writeAll(table_name);

        try writeInt(file, u64, start_row, .little);

        const column_count = table.schema.columns.len;
        try writeInt(file, u32, @intCast(column_count), .little);
        for (table.schema.columns) |col| {
            const col_len = @as(u32, @intCast(col.name.len));
            try writeInt(file, u32, col_len, .little);
            try file.writeAll(col.name);
            try file.writeAll(&[_]u8{@intFromEnum(col.data_type)});
        }

        const new_rows = table.row_count - start_row;
        try writeInt(file, u64, new_rows, .little);

        var row_values = try self.allocator.alloc(Value, column_count);
        defer self.allocator.free(row_values);

        var row = start_row;
        while (row < table.row_count) : (row += 1) {
            var col_idx: usize = 0;
            while (col_idx < column_count) : (col_idx += 1) {
                row_values[col_idx] = try table.getCell(row, col_idx);
                try self.writeValue(file, row_values[col_idx]);
            }
        }
    }

    fn writeValue(self: Lakehouse, file: std.fs.File, value: Value) !void {
        _ = self;
        switch (value) {
            .int32 => |v| try writeInt(file, i32, v, .little),
            .int64 => |v| try writeInt(file, i64, v, .little),
            .float32 => |v| try writeInt(file, u32, @bitCast(v), .little),
            .float64 => |v| try writeInt(file, u64, @bitCast(v), .little),
            .boolean => |v| try file.writeAll(&[_]u8{@intFromBool(v)}),
            .timestamp => |v| try writeInt(file, i64, v, .little),
            .string => |v| {
                const len = @as(u32, @intCast(v.len));
                try writeInt(file, u32, len, .little);
                try file.writeAll(v);
            },
            .vector => |v| {
                // Write vector length
                const len = @as(u32, @intCast(v.values.len));
                try writeInt(file, u32, len, .little);
                // Write vector values
                for (v.values) |val| {
                    try writeInt(file, u32, @bitCast(val), .little);
                }
            },
            .custom => return error.UnsupportedOperation,
        }
    }

    fn applyDeltaTable(self: Lakehouse, data: []const u8, start_pos: usize, db: *Database) !usize {
        var pos = start_pos;

        const name_len = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        const table_name = data[pos .. pos + name_len];
        pos += name_len;

        var table = try db.getTable(table_name);

        const start_row = std.mem.readInt(u64, data[pos..][0..8], .little);
        pos += 8;
        if (@as(u64, @intCast(table.row_count)) != start_row) {
            return error.SnapshotOutOfDate;
        }

        const column_count = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;
        if (column_count != table.schema.columns.len) {
            return error.SchemaMismatch;
        }

        var column_types = try self.allocator.alloc(DataType, column_count);
        defer self.allocator.free(column_types);

        var col_idx: usize = 0;
        while (col_idx < column_count) : (col_idx += 1) {
            const col_name_len = std.mem.readInt(u32, data[pos..][0..4], .little);
            pos += 4;
            const col_name = data[pos .. pos + col_name_len];
            pos += col_name_len;
            const dtype_tag = data[pos];
            pos += 1;
            const dtype: DataType = @enumFromInt(dtype_tag);
            const expected = table.schema.columns[col_idx];
            if (!std.mem.eql(u8, expected.name, col_name) or expected.data_type != dtype) {
                return error.SchemaMismatch;
            }
            column_types[col_idx] = dtype;
        }

        const new_rows = std.mem.readInt(u64, data[pos..][0..8], .little);
        pos += 8;

        var row_values = try self.allocator.alloc(Value, column_count);
        defer self.allocator.free(row_values);

        var row_counter: u64 = 0;
        while (row_counter < new_rows) : (row_counter += 1) {
            var inner_idx: usize = 0;
            while (inner_idx < column_count) : (inner_idx += 1) {
                row_values[inner_idx] = try self.readDeltaValue(data, &pos, column_types[inner_idx]);
            }
            try table.insertRow(row_values);
            self.cleanupRowValues(row_values, column_types);
        }

        return pos;
    }

    fn readDeltaValue(self: Lakehouse, data: []const u8, pos_ptr: *usize, dtype: DataType) !Value {
        var pos = pos_ptr.*;
        defer pos_ptr.* = pos;

        return switch (dtype) {
            .int32 => blk: {
                const val = std.mem.readInt(i32, data[pos..][0..4], .little);
                pos += 4;
                break :blk Value{ .int32 = val };
            },
            .int64 => blk: {
                const val = std.mem.readInt(i64, data[pos..][0..8], .little);
                pos += 8;
                break :blk Value{ .int64 = val };
            },
            .float32 => blk: {
                const bits = std.mem.readInt(u32, data[pos..][0..4], .little);
                pos += 4;
                const val: f32 = @bitCast(bits);
                break :blk Value{ .float32 = val };
            },
            .float64 => blk: {
                const bits = std.mem.readInt(u64, data[pos..][0..8], .little);
                pos += 8;
                const val: f64 = @bitCast(bits);
                break :blk Value{ .float64 = val };
            },
            .boolean => blk: {
                const byte = data[pos];
                pos += 1;
                break :blk Value{ .boolean = byte != 0 };
            },
            .timestamp => blk: {
                const val = std.mem.readInt(i64, data[pos..][0..8], .little);
                pos += 8;
                break :blk Value{ .timestamp = val };
            },
            .string => blk: {
                const len = std.mem.readInt(u32, data[pos..][0..4], .little);
                pos += 4;
                const slice = data[pos .. pos + len];
                pos += len;
                const owned = try self.allocator.dupe(u8, slice);
                break :blk Value{ .string = owned };
            },
            .vector => blk: {
                const len = std.mem.readInt(u32, data[pos..][0..4], .little);
                pos += 4;
                const values = try self.allocator.alloc(f32, len);
                for (0..len) |i| {
                    const bits = std.mem.readInt(u32, data[pos..][0..4], .little);
                    pos += 4;
                    values[i] = @bitCast(bits);
                }
                break :blk Value{ .vector = VectorValue{ .values = values } };
            },
            .custom => return error.UnsupportedOperation,
        };
    }

    fn cleanupRowValues(self: Lakehouse, row_values: []Value, column_types: []const DataType) void {
        for (row_values, 0..) |value, idx| {
            switch (column_types[idx]) {
                .string => self.allocator.free(value.string),
                .vector => self.allocator.free(value.vector.values),
                else => {},
            }
        }
    }
};

test "Lakehouse save and load" {
    const allocator = std.testing.allocator;

    // Create database
    var db = try Database.init(allocator, "test_lakehouse");
    defer db.deinit();

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "score", .data_type = .float64 },
    };

    try db.createTable("users", &schema_def);
    const table = try db.getTable("users");

    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
        Value{ .float64 = 95.5 },
    });

    try table.insertRow(&[_]Value{
        Value{ .int32 = 2 },
        Value{ .string = "Bob" },
        Value{ .float64 = 87.3 },
    });

    // Save to file
    const lakehouse = Lakehouse.init(allocator);
    try lakehouse.save(&db, "test_lakehouse.griz", format_mod.CompressionType.none);
    defer std.fs.cwd().deleteFile("test_lakehouse.griz") catch {};
    defer std.fs.cwd().deleteTree("test_lakehouse.lakehouse") catch {};

    // Load from file
    var loaded_db = try lakehouse.load("test_lakehouse.griz");
    defer loaded_db.deinit();

    const loaded_table = try loaded_db.getTable("users");
    try std.testing.expectEqual(@as(u64, 2), loaded_table.row_count);
    try std.testing.expectEqual(@as(usize, 3), loaded_table.schema.columns.len);
}

test "Lakehouse incremental snapshots" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, "incremental_db");
    defer db.deinit();

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "value", .data_type = .string },
    };

    try db.createTable("metrics", &schema_def);
    const table = try db.getTable("metrics");

    try table.insertRow(&[_]Value{ Value{ .int32 = 1 }, Value{ .string = "alpha" } });
    try table.insertRow(&[_]Value{ Value{ .int32 = 2 }, Value{ .string = "beta" } });

    const lakehouse = Lakehouse.init(allocator);
    try lakehouse.save(&db, "incremental.griz", format_mod.CompressionType.none);
    defer std.fs.cwd().deleteFile("incremental.griz") catch {};
    defer std.fs.cwd().deleteTree("incremental.lakehouse") catch {};

    try table.insertRow(&[_]Value{ Value{ .int32 = 3 }, Value{ .string = "gamma" } });

    try lakehouse.saveIncremental(&db, "incremental.griz", "incremental.delta");
    defer std.fs.cwd().deleteFile("incremental.delta") catch {};

    var loaded_db = try lakehouse.load("incremental.griz");
    defer loaded_db.deinit();

    try lakehouse.applyIncremental(&loaded_db, "incremental.griz", "incremental.delta");
    const loaded_table = try loaded_db.getTable("metrics");
    try std.testing.expectEqual(@as(u64, 3), loaded_table.row_count);
}

test "Lakehouse delta compaction" {
    const allocator = std.testing.allocator;

    var db = try Database.init(allocator, "compact_db");
    defer db.deinit();

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "note", .data_type = .string },
    };

    try db.createTable("events", &schema_def);
    const table = try db.getTable("events");

    try table.insertRow(&[_]Value{ Value{ .int32 = 1 }, Value{ .string = "seed" } });

    const lakehouse = Lakehouse.init(allocator);
    try lakehouse.save(&db, "compact.griz", format_mod.CompressionType.none);
    defer std.fs.cwd().deleteFile("compact.griz") catch {};
    defer std.fs.cwd().deleteTree("compact.lakehouse") catch {};

    var next_id: i32 = 2;

    try table.insertRow(&[_]Value{ Value{ .int32 = next_id }, Value{ .string = "delta-0" } });
    next_id += 1;
    try lakehouse.saveIncremental(&db, "compact.griz", "compact-0.delta");

    {
        var manifest = try lakehouse.loadSnapshotManifest("compact.griz");
        defer manifest.deinit();
        try std.testing.expectEqual(SnapshotType.incremental, manifest.snapshot_type);
        try std.testing.expectEqual(@as(usize, 1), manifest.delta_history.items.len);
    }

    var iteration: usize = 1;
    while (iteration < Lakehouse.MAX_DELTA_CHAIN) : (iteration += 1) {
        try table.insertRow(&[_]Value{
            Value{ .int32 = next_id },
            Value{ .string = "delta" },
        });
        next_id += 1;

        {
            const delta_path = try std.fmt.allocPrint(allocator, "compact-{d}.delta", .{iteration});
            defer allocator.free(delta_path);
            try lakehouse.saveIncremental(&db, "compact.griz", delta_path);
            std.fs.cwd().deleteFile(delta_path) catch {};
        }
    }

    var compact_manifest = try lakehouse.loadSnapshotManifest("compact.griz");
    defer compact_manifest.deinit();
    try std.testing.expectEqual(SnapshotType.full, compact_manifest.snapshot_type);
    try std.testing.expectEqual(@as(usize, 0), compact_manifest.delta_history.items.len);

    try std.testing.expectError(error.FileNotFound, std.fs.cwd().openFile("compact-0.delta", .{}));
}
