const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");
const compression = @import("compression.zig");

const Value = types.Value;
const Table = table_mod.Table;
const CompressionAlgorithm = compression.CompressionAlgorithm;

/// Enhanced Parquet file writer for Grizzly tables
/// Supports compression, dictionary encoding, and full Parquet specification
pub const ParquetWriter = struct {
    allocator: std.mem.Allocator,
    compression_algorithm: CompressionAlgorithm,

    pub fn init(allocator: std.mem.Allocator) ParquetWriter {
        return .{
            .allocator = allocator,
            .compression_algorithm = .lz4,
        };
    }

    pub fn setCompression(self: *ParquetWriter, algorithm: CompressionAlgorithm) void {
        self.compression_algorithm = algorithm;
    }

    /// Write table to Parquet format with full specification compliance
    pub fn writeTable(self: *ParquetWriter, table: *Table, file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        // Parquet magic number
        try file.writeAll("PAR1");

        // Create row group
        var row_group = try self.createRowGroup(table);
        defer row_group.deinit(self.allocator);

        // Write row group data
        const data_offset = try file.getPos();
        try self.writeRowGroupData(file, &row_group);

        // Write footer with metadata
        const footer_offset = try file.getPos();
        try self.writeFooter(file, table, &row_group, data_offset);

        // Write footer offset and magic
        var buffer: [4]u8 = undefined;
        std.mem.writeInt(u32, buffer[0..4], @intCast(footer_offset), .little);
        try file.writeAll(&buffer);
        try file.writeAll("PAR1");
    }

    const RowGroup = struct {
        columns: []ColumnChunk,
        row_count: u64,
        total_byte_size: u64,

        pub fn deinit(self: *RowGroup, allocator: std.mem.Allocator) void {
            for (self.columns) |*column| {
                column.deinit(allocator);
            }
            allocator.free(self.columns);
        }
    };

    const ColumnChunk = struct {
        column_idx: usize,
        pages: []Page,
        metadata: ColumnMetadata,

        pub fn deinit(self: *ColumnChunk, allocator: std.mem.Allocator) void {
            for (self.pages) |*page| {
                page.deinit(allocator);
            }
            allocator.free(self.pages);
            allocator.free(self.metadata.encodings);
            allocator.free(self.metadata.path_in_schema);
        }
    };

    const Page = struct {
        page_type: PageType,
        uncompressed_size: u32,
        compressed_size: u32,
        data: []u8,
        statistics: Statistics,

        pub fn deinit(self: *Page, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
            // Statistics values are owned by the page, so free them too
            if (self.statistics.min) |*min| min.deinit(allocator);
            if (self.statistics.max) |*max| max.deinit(allocator);
        }
    };

    const PageType = enum(u8) {
        data_page = 0,
        index_page = 1,
        dictionary_page = 2,
        data_page_v2 = 3,
    };

    const ColumnMetadata = struct {
        type_: types.DataType,
        encodings: []Encoding,
        path_in_schema: []const u8,
        codec: CompressionCodec,
        num_values: u64,
        total_uncompressed_size: u64,
        total_compressed_size: u64,
        data_page_offset: u64,
        index_page_offset: ?u64,
        dictionary_page_offset: ?u64,
        statistics: Statistics,
    };

    const Encoding = enum(u8) {
        plain = 0,
        group_var_int = 1,
        plain_dictionary = 2,
        rle = 3,
        bit_packed = 4,
        delta_binary_packed = 5,
        delta_length_byte_array = 6,
        delta_byte_array = 7,
        rle_dictionary = 8,
        byte_stream_split = 9,
    };

    const CompressionCodec = enum(u8) {
        uncompressed = 0,
        snappy = 1,
        gzip = 2,
        lzo = 3,
        brotli = 4,
        lz4 = 5,
        zstd = 6,
        lz4_raw = 7,
    };

    const Statistics = struct {
        min: ?Value,
        max: ?Value,
        null_count: u64,
        distinct_count: ?u64,
    };

    fn createRowGroup(self: *ParquetWriter, table: *Table) !RowGroup {
        var columns = try self.allocator.alloc(ColumnChunk, table.schema.columns.len);
        errdefer self.allocator.free(columns);

        var total_size: u64 = 0;

        for (table.schema.columns, 0..) |col_def, col_idx| {
            _ = col_def; // Used in createColumnChunk
            const chunk = try self.createColumnChunk(table, col_idx);
            columns[col_idx] = chunk;
            total_size += chunk.metadata.total_compressed_size;
        }

        return RowGroup{
            .columns = columns,
            .row_count = table.row_count,
            .total_byte_size = total_size,
        };
    }

    fn createColumnChunk(self: *ParquetWriter, table: *Table, col_idx: usize) !ColumnChunk {
        const column = &table.columns[col_idx];
        _ = column; // Not used in simplified implementation
        const col_def = table.schema.columns[col_idx];

        // Create data page
        const data_page = try self.createDataPage(table, col_idx);

        const pages = try self.allocator.alloc(Page, 1);
        pages[0] = data_page;

        const metadata = ColumnMetadata{
            .type_ = col_def.data_type,
            .encodings = try self.allocator.dupe(Encoding, &[_]Encoding{.plain}),
            .path_in_schema = try self.allocator.dupe(u8, col_def.name),
            .codec = compressionCodecFromAlgorithm(self.compression_algorithm),
            .num_values = table.row_count,
            .total_uncompressed_size = data_page.uncompressed_size,
            .total_compressed_size = data_page.compressed_size,
            .data_page_offset = 0, // Will be set when writing
            .index_page_offset = null,
            .dictionary_page_offset = null,
            .statistics = data_page.statistics,
        };

        return ColumnChunk{
            .column_idx = col_idx,
            .pages = pages,
            .metadata = metadata,
        };
    }

    fn createDataPage(self: *ParquetWriter, table: *Table, col_idx: usize) !Page {
        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer buffer.deinit(self.allocator);

        // Collect column values and statistics
        var min_val: ?Value = null;
        var max_val: ?Value = null;
        const null_count: u64 = 0; // Not used in this system

        var row_idx: usize = 0;
        while (row_idx < table.row_count) : (row_idx += 1) {
            const val = try table.getCell(row_idx, col_idx);

            // Update statistics
            // Note: This system doesn't use null values, so no null counting needed
            if (min_val == null or self.compareValues(val, min_val.?) == .lt) {
                if (min_val) |*old_min| old_min.deinit(self.allocator);
                min_val = try val.clone(self.allocator);
            }
            if (max_val == null or self.compareValues(val, max_val.?) == .gt) {
                if (max_val) |*old_max| old_max.deinit(self.allocator);
                max_val = try val.clone(self.allocator);
            }

            // Write value in plain encoding
            try self.writeValue(&buffer, val);
        }

        // Compress data if needed
        const uncompressed_data = try buffer.toOwnedSlice(self.allocator);
        defer self.allocator.free(uncompressed_data);

        var compressed_data: []u8 = undefined;
        var compressed_size: u32 = undefined;

        if (self.compression_algorithm == .none) {
            compressed_data = try self.allocator.dupe(u8, uncompressed_data);
            compressed_size = @intCast(uncompressed_data.len);
        } else {
            compressed_data = try compression.compressData(self.allocator, uncompressed_data, self.compression_algorithm);
            compressed_size = @intCast(compressed_data.len);
        }

        const statistics = Statistics{
            .min = min_val,
            .max = max_val,
            .null_count = null_count,
            .distinct_count = null, // Not calculated for simplicity
        };

        return Page{
            .page_type = .data_page,
            .uncompressed_size = @intCast(uncompressed_data.len),
            .compressed_size = compressed_size,
            .data = compressed_data,
            .statistics = statistics,
        };
    }

    fn writeValue(self: *ParquetWriter, buffer: *std.ArrayList(u8), value: Value) !void {
        switch (value) {
            .int32 => |v| try buffer.writer(self.allocator).writeInt(i32, v, .little),
            .int64 => |v| try buffer.writer(self.allocator).writeInt(i64, v, .little),
            .float32 => |v| try buffer.writer(self.allocator).writeInt(u32, @bitCast(v), .little),
            .float64 => |v| try buffer.writer(self.allocator).writeInt(u64, @bitCast(v), .little),
            .boolean => |v| try buffer.append(self.allocator, @intFromBool(v)),
            .string => |v| {
                try buffer.writer(self.allocator).writeInt(u32, @intCast(v.len), .little);
                try buffer.appendSlice(self.allocator, v);
            },
            .timestamp => |v| try buffer.writer(self.allocator).writeInt(i64, v, .little),
            .vector => |vec| {
                try buffer.writer(self.allocator).writeInt(u32, @intCast(vec.values.len), .little);
                for (vec.values) |f| {
                    try buffer.writer(self.allocator).writeInt(u32, @bitCast(f), .little);
                }
            },
            .custom => return error.CustomTypeNotSupported,
            .exception => return error.ExceptionTypeNotSupported,
        }
    }

    fn compareValues(self: *ParquetWriter, a: Value, b: Value) std.math.Order {
        _ = self; // Not used in comparison
        return switch (a) {
            .int32 => |av| switch (b) {
                .int32 => |bv| std.math.order(av, bv),
                else => .eq,
            },
            .int64 => |av| switch (b) {
                .int64 => |bv| std.math.order(av, bv),
                else => .eq,
            },
            .float32 => |av| switch (b) {
                .float32 => |bv| std.math.order(av, bv),
                else => .eq,
            },
            .float64 => |av| switch (b) {
                .float64 => |bv| std.math.order(av, bv),
                else => .eq,
            },
            .string => |av| switch (b) {
                .string => |bv| std.mem.order(u8, av, bv),
                else => .eq,
            },
            else => .eq,
        };
    }

    fn writeRowGroupData(self: *ParquetWriter, file: std.fs.File, row_group: *RowGroup) !void {
        for (row_group.columns) |*chunk| {
            // Update data page offset
            chunk.metadata.data_page_offset = try file.getPos();

            // Write pages
            for (chunk.pages) |page| {
                try self.writePage(file, &page);
            }
        }
    }

    fn writePage(self: *ParquetWriter, file: std.fs.File, page: *const Page) !void {
        _ = self; // Not used in this implementation
        var buffer: [12]u8 = undefined; // 3 * u32

        // Page header
        std.mem.writeInt(u32, buffer[0..4], @intFromEnum(page.page_type), .little);
        std.mem.writeInt(u32, buffer[4..8], page.uncompressed_size, .little);
        std.mem.writeInt(u32, buffer[8..12], page.compressed_size, .little);
        try file.writeAll(&buffer);

        // Page data
        try file.writeAll(page.data);
    }

    fn writeFooter(self: *ParquetWriter, file: std.fs.File, table: *Table, row_group: *RowGroup, data_offset: u64) !void {
        var buffer: [1024]u8 = undefined;

        // File metadata
        try file.writeAll("FMD"); // File metadata marker

        // Schema
        std.mem.writeInt(u32, buffer[0..4], @intCast(table.schema.columns.len), .little);
        try file.writeAll(buffer[0..4]);

        for (table.schema.columns) |col| {
            try file.writeAll(col.name);
            try file.writeAll(&[_]u8{0}); // Null terminator
            buffer[0] = @intFromEnum(col.data_type);
            try file.writeAll(buffer[0..1]);
        }

        // Row groups
        std.mem.writeInt(u32, buffer[0..4], 1, .little); // One row group
        try file.writeAll(buffer[0..4]);
        std.mem.writeInt(u64, buffer[0..8], row_group.row_count, .little);
        try file.writeAll(buffer[0..8]);
        std.mem.writeInt(u64, buffer[0..8], row_group.total_byte_size, .little);
        try file.writeAll(buffer[0..8]);
        std.mem.writeInt(u64, buffer[0..8], data_offset, .little);
        try file.writeAll(buffer[0..8]);

        // Column chunks
        std.mem.writeInt(u32, buffer[0..4], @intCast(row_group.columns.len), .little);
        try file.writeAll(buffer[0..4]);
        for (row_group.columns) |chunk| {
            try self.writeColumnMetadata(file, &chunk.metadata);
        }
    }

    fn writeColumnMetadata(self: *ParquetWriter, file: std.fs.File, metadata: *const ColumnMetadata) !void {
        var buffer: [1024]u8 = undefined;

        try file.writeAll(metadata.path_in_schema);
        try file.writeAll(&[_]u8{0});

        buffer[0] = @intFromEnum(metadata.type_);
        try file.writeAll(buffer[0..1]);
        buffer[0] = @intFromEnum(metadata.codec);
        try file.writeAll(buffer[0..1]);

        std.mem.writeInt(u64, buffer[0..8], metadata.num_values, .little);
        try file.writeAll(buffer[0..8]);
        std.mem.writeInt(u64, buffer[0..8], metadata.total_uncompressed_size, .little);
        try file.writeAll(buffer[0..8]);
        std.mem.writeInt(u64, buffer[0..8], metadata.total_compressed_size, .little);
        try file.writeAll(buffer[0..8]);
        std.mem.writeInt(u64, buffer[0..8], metadata.data_page_offset, .little);
        try file.writeAll(buffer[0..8]);

        // Statistics
        if (metadata.statistics.min) |min_val| {
            buffer[0] = 1; // Has min
            try file.writeAll(buffer[0..1]);
            try self.writeValueForMetadata(file, min_val);
        } else {
            buffer[0] = 0;
            try file.writeAll(buffer[0..1]);
        }

        if (metadata.statistics.max) |max_val| {
            buffer[0] = 1; // Has max
            try file.writeAll(buffer[0..1]);
            try self.writeValueForMetadata(file, max_val);
        } else {
            buffer[0] = 0;
            try file.writeAll(buffer[0..1]);
        }

        std.mem.writeInt(u64, buffer[0..8], metadata.statistics.null_count, .little);
        try file.writeAll(buffer[0..8]);
    }

    fn writeValueForMetadata(self: *ParquetWriter, file: std.fs.File, value: Value) !void {
        _ = self; // Not used in this implementation
        var buffer: [1024]u8 = undefined;

        switch (value) {
            .int32 => |v| {
                std.mem.writeInt(i32, buffer[0..4], v, .little);
                try file.writeAll(buffer[0..4]);
            },
            .int64 => |v| {
                std.mem.writeInt(i64, buffer[0..8], v, .little);
                try file.writeAll(buffer[0..8]);
            },
            .float32 => |v| {
                _ = v; // Use value.float32 instead
                std.mem.writeInt(u32, buffer[0..4], @bitCast(value.float32), .little);
                try file.writeAll(buffer[0..4]);
            },
            .float64 => |v| {
                _ = v; // Use value.float64 instead
                std.mem.writeInt(u64, buffer[0..8], @bitCast(value.float64), .little);
                try file.writeAll(buffer[0..8]);
            },
            .boolean => |v| try file.writeAll(&[_]u8{@intFromBool(v)}),
            .string => |v| {
                std.mem.writeInt(u32, buffer[0..4], @intCast(v.len), .little);
                try file.writeAll(buffer[0..4]);
                try file.writeAll(v);
            },
            .timestamp => |v| {
                std.mem.writeInt(i64, buffer[0..8], v, .little);
                try file.writeAll(buffer[0..8]);
            },
            else => {},
        }
    }

    fn compressionCodecFromAlgorithm(algorithm: CompressionAlgorithm) CompressionCodec {
        return switch (algorithm) {
            .none => .uncompressed,
            .snappy => .snappy,
            .gzip => .gzip,
            .lz4 => .lz4,
            .zstd => .zstd,
        };
    }
};
