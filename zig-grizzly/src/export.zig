const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");

const Value = types.Value;
const Table = table_mod.Table;

/// Export table to JSON format (AI-friendly)
pub fn exportJSON(table: Table, writer: anytype) !void {
    try writer.print("{{\n", .{});
    try writer.print("  \"table\": \"{s}\",\n", .{table.name});
    try writer.print("  \"schema\": [\n", .{});

    for (table.schema.columns, 0..) |col, i| {
        try writer.print("    {{\"name\": \"{s}\", \"type\": \"{s}\"}}", .{ col.name, col.data_type.name() });
        if (i < table.schema.columns.len - 1) try writer.print(",", .{});
        try writer.print("\n", .{});
    }

    try writer.print("  ],\n", .{});
    try writer.print("  \"rows\": [\n", .{});

    var row: usize = 0;
    while (row < table.row_count) : (row += 1) {
        try writer.print("    {{", .{});

        for (table.schema.columns, 0..) |col, col_idx| {
            if (col_idx > 0) try writer.print(", ", .{});
            try writer.print("\"{s}\": ", .{col.name});

            const val = try table.getCell(row, col_idx);
            try writeJSONValue(writer, val);
        }

        try writer.print("}}", .{});
        if (row < table.row_count - 1) try writer.print(",", .{});
        try writer.print("\n", .{});
    }

    try writer.print("  ],\n", .{});
    try writer.print("  \"row_count\": {d}\n", .{table.row_count});
    try writer.print("}}\n", .{});
}

/// Export table to JSONL format (AI-friendly, streaming)
pub fn exportJSONL(table: Table, writer: anytype) !void {
    var row: usize = 0;
    while (row < table.row_count) : (row += 1) {
        try writer.print("{{", .{});

        for (table.schema.columns, 0..) |col, col_idx| {
            if (col_idx > 0) try writer.print(", ", .{});
            try writer.print("\"{s}\": ", .{col.name});

            const val = try table.getCell(row, col_idx);
            try writeJSONValue(writer, val);
        }

        try writer.print("}}\n", .{});
    }
}

/// Export table to CSV format
pub fn exportCSV(table: Table, writer: anytype) !void {
    // Write header
    for (table.schema.columns, 0..) |col, i| {
        if (i > 0) try writer.print(",", .{});
        try writer.print("{s}", .{col.name});
    }
    try writer.print("\n", .{});

    // Write rows
    var row: usize = 0;
    while (row < table.row_count) : (row += 1) {
        for (0..table.columns.len) |col_idx| {
            if (col_idx > 0) try writer.print(",", .{});

            const val = try table.getCell(row, col_idx);
            try writeCsvCell(writer, val);
        }
        try writer.print("\n", .{});
    }
}

/// Export table to binary format (compact, fast)
pub fn exportBinary(table: Table, writer: anytype) !void {
    // Write magic bytes
    try writer.writeAll("GRIZ");

    // Write version
    try writer.writeByte(1);

    // Write table name length and name
    try writer.writeInt(u32, @intCast(table.name.len), .little);
    try writer.writeAll(table.name);

    // Write column count
    try writer.writeInt(u32, @intCast(table.schema.columns.len), .little);

    // Write column definitions
    for (table.schema.columns) |col| {
        try writer.writeInt(u32, @intCast(col.name.len), .little);
        try writer.writeAll(col.name);
        try writer.writeByte(@intFromEnum(col.data_type));
    }

    // Write row count
    try writer.writeInt(u64, @intCast(table.row_count), .little);

    // Write data column by column (true columnar format)
    for (table.columns, 0..) |_, col_idx| {
        const col_def = table.schema.columns[col_idx];
        const data_type = col_def.data_type;

        var row: usize = 0;
        while (row < table.row_count) : (row += 1) {
            const val = try table.getCell(row, col_idx);

            switch (data_type) {
                .int32 => try writer.writeInt(i32, val.int32, .little),
                .int64, .timestamp => try writer.writeInt(i64, val.int64, .little),
                .float32 => try writer.writeInt(u32, @bitCast(val.float32), .little),
                .float64 => try writer.writeInt(u64, @bitCast(val.float64), .little),
                .boolean => try writer.writeByte(@intFromBool(val.boolean)),
                .string => {
                    const str = val.string;
                    try writer.writeInt(u32, @intCast(str.len), .little);
                    try writer.writeAll(str);
                },
                .vector => {
                    for (val.vector.values) |component| {
                        try writer.writeInt(u32, @bitCast(component), .little);
                    }
                },
                .custom => {
                    // Custom types not supported for binary export yet
                    return error.CustomTypeNotSupported;
                },
            }
        }
    }
}

/// Generate schema documentation for AI context
pub fn exportSchemaDoc(table: Table, writer: anytype) !void {
    try writer.print("# Table: {s}\n\n", .{table.name});
    try writer.print("**Rows**: {d}\n\n", .{table.row_count});
    try writer.print("## Schema\n\n", .{});
    try writer.print("| Column | Type | Sample Values |\n", .{});
    try writer.print("|--------|------|---------------|\n", .{});

    for (table.schema.columns, 0..) |col, col_idx| {
        if (col.data_type == .vector) {
            try writer.print("| {s} | vector[{d}] | ", .{ col.name, col.vector_dim });
        } else {
            try writer.print("| {s} | {s} | ", .{ col.name, col.data_type.name() });
        }

        // Show first 3 sample values
        const sample_count = @min(3, table.row_count);
        var i: usize = 0;
        while (i < sample_count) : (i += 1) {
            if (i > 0) try writer.print(", ", .{});
            const val = try table.getCell(i, col_idx);
            try writer.print("{any}", .{val});
        }
        try writer.print(" |\n", .{});
    }

    try writer.print("\n## Statistics\n\n", .{});

    // Compute basic statistics for numeric columns
    for (table.schema.columns, 0..) |col, col_idx| {
        const is_numeric = switch (col.data_type) {
            .int32, .int64, .float32, .float64 => true,
            else => false,
        };

        if (is_numeric and table.row_count > 0) {
            const column = table.columns[col_idx];
            const min_val = try column.min();
            const max_val = try column.max();
            const avg_val = try column.avg();

            try writer.print("- **{s}**: min={}, max={}, avg={}\n", .{ col.name, min_val, max_val, avg_val });
        }
    }
}

fn writeJSONValue(writer: anytype, val: Value) !void {
    switch (val) {
        .vector => |vec| try writeVectorJSON(writer, vec.values),
        else => try writer.print("{any}", .{val}),
    }
}

fn writeVectorJSON(writer: anytype, values: []const f32) !void {
    try writer.writeAll("[");
    for (values, 0..) |component, idx| {
        if (idx > 0) try writer.writeAll(", ");
        try writer.print("{d:.4}", .{component});
    }
    try writer.writeAll("]");
}

fn writeCsvCell(writer: anytype, val: Value) !void {
    switch (val) {
        .string => |s| try writeCsvEscaped(writer, s),
        .vector => |vec| try writeCsvVector(writer, vec.values),
        else => try writer.print("{any}", .{val}),
    }
}

fn writeCsvEscaped(writer: anytype, text: []const u8) !void {
    if (std.mem.indexOfAny(u8, text, ",\"\n") == null) {
        try writer.print("{s}", .{text});
        return;
    }

    try writer.writeByte('"');
    for (text) |c| {
        if (c == '"') {
            try writer.writeAll("\"\"");
        } else {
            try writer.writeByte(c);
        }
    }
    try writer.writeByte('"');
}

fn writeCsvVector(writer: anytype, values: []const f32) !void {
    try writer.writeByte('"');
    try writer.writeAll("[");
    for (values, 0..) |component, idx| {
        if (idx > 0) try writer.writeAll(", ");
        try writer.print("{d:.4}", .{component});
    }
    try writer.writeAll("]");
    try writer.writeByte('"');
}

test "Export JSON" {
    const allocator = std.testing.allocator;
    const schema_mod = @import("schema.zig");

    const schema_def = [_]schema_mod.Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };

    var table = try Table.init(allocator, "users", &schema_def);
    defer table.deinit();

    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
    });

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    try exportJSON(table, buffer.writer(allocator));

    try std.testing.expect(buffer.items.len > 0);
}
