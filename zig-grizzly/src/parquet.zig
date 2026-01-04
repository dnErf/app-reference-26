const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");
const Value = types.Value;
const Table = table_mod.Table;

/// Basic Parquet file writer for Grizzly tables
/// Supports single row group, uncompressed data, basic schema
pub const ParquetWriter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ParquetWriter {
        return .{ .allocator = allocator };
    }

    /// Write table to Parquet format
    /// Creates a minimal Parquet file with one row group
    pub fn writeTable(self: ParquetWriter, table: *Table, file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        // Parquet magic number
        try file.writeAll("PAR1");

        // Write file metadata (simplified)
        const metadata_offset = try self.writeRowGroup(file, table);

        // Write footer
        try self.writeFooter(file, metadata_offset, table);
    }

    fn writeRowGroup(self: ParquetWriter, file: std.fs.File, table: *Table) !u64 {
        const start_pos = try file.getPos();

        // Row group header (simplified)
        try file.writeAll("RG"); // Row group marker

        // Write each column chunk
        for (table.schema.columns, 0..) |col, col_idx| {
            try self.writeColumnChunk(file, table, col_idx);
        }

        return start_pos;
    }

    fn writeColumnChunk(self: ParquetWriter, file: std.fs.File, table: *Table, col_idx: usize) !void {
        const column = &table.columns[col_idx];
        const col_def = table.schema.columns[col_idx];

        // Column chunk header
        try file.writeAll("CC"); // Column chunk marker

        // Page header
        try file.writeAll("PG"); // Page marker

        // Write column data as uncompressed plain encoding
        var i: usize = 0;
        while (i < column.len) : (i += 1) {
            const val = try table.getCell(i, col_idx);
            try self.writeValue(file, val, col_def.data_type);
        }
    }

    fn writeValue(self: ParquetWriter, file: std.fs.File, value: Value, data_type: types.DataType) !void {
        switch (value) {
            .int32 => |v| try file.writeInt(i32, v, .little),
            .int64 => |v| try file.writeInt(i64, v, .little),
            .float32 => |v| try file.writeInt(u32, @bitCast(v), .little),
            .float64 => |v| try file.writeInt(u64, @bitCast(v), .little),
            .boolean => |v| try file.writeAll(&[_]u8{@intFromBool(v)}),
            .string => |v| {
                try file.writeInt(u32, @intCast(v.len), .little);
                try file.writeAll(v);
            },
            .timestamp => |v| try file.writeInt(i64, v, .little),
            .vector => |vec| {
                try file.writeInt(u32, @intCast(vec.values.len), .little);
                for (vec.values) |f| {
                    try file.writeInt(u32, @bitCast(f), .little);
                }
            },
        }
    }

    fn writeFooter(self: ParquetWriter, file: std.fs.File, metadata_offset: u64, table: *Table) !void {
        // Footer metadata (highly simplified)
        try file.writeAll("FT"); // Footer marker
        try file.writeInt(u64, metadata_offset, .little);
        try file.writeInt(u32, @intCast(table.schema.columns.len), .little);
        try file.writeInt(u64, table.row_count, .little);

        // Parquet magic end
        try file.writeAll("PAR1");
    }
};
