const std = @import("std");
const format = @import("../format.zig");
const types = @import("../types.zig");
const schema_mod = @import("../schema.zig");
const table_mod = @import("../table.zig");

const FormatLoader = format.FormatLoader;
const LoadOptions = format.LoadOptions;
const SaveOptions = format.SaveOptions;
const DataType = types.DataType;
const Value = types.Value;
const Schema = schema_mod.Schema;
const Table = table_mod.Table;

/// CSV Format Loader
pub const CSV_LOADER = FormatLoader{
    .name = "CSV",
    .extensions = &[_][]const u8{ "csv", "tsv", "txt" },
    .detectFn = detectCSV,
    .inferSchemaFn = inferCSVSchema,
    .loadFn = loadCSV,
    .saveFn = saveCSV,
};

fn detectCSV(file_path: []const u8, allocator: std.mem.Allocator) bool {
    _ = allocator;
    const ext = format.getExtension(file_path);
    for (CSV_LOADER.extensions) |e| {
        if (std.mem.eql(u8, ext, e)) return true;
    }
    return false;
}

fn inferCSVSchema(file_path: []const u8, opts: LoadOptions, allocator: std.mem.Allocator) !Schema {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(content);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    var row_idx: usize = 0;

    var column_names = std.ArrayList([]const u8){};
    defer {
        for (column_names.items) |name| {
            allocator.free(name);
        }
        column_names.deinit(allocator);
    }

    var column_types = std.ArrayList(DataType){};
    defer column_types.deinit(allocator);

    var sample_values = std.ArrayList(std.ArrayList([]const u8)){};
    defer {
        for (sample_values.items) |*col_samples| {
            for (col_samples.items) |val| {
                allocator.free(val);
            }
            col_samples.deinit(allocator);
        }
        sample_values.deinit(allocator);
    }

    // Read header
    if (opts.header) {
        if (line_iter.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0) return error.EmptyHeader;

            var col_iter = std.mem.splitScalar(u8, trimmed, opts.delimiter);
            while (col_iter.next()) |col_name| {
                const name_trimmed = std.mem.trim(u8, col_name, &std.ascii.whitespace);
                const name_unquoted = unquoteCSV(name_trimmed, opts.quote_char);
                const name_copy = try allocator.dupe(u8, name_unquoted);
                try column_names.append(allocator, name_copy);
                try sample_values.append(allocator, std.ArrayList([]const u8){});
            }
            row_idx += 1;
        } else {
            return error.EmptyFile;
        }
    }

    // Sample data rows
    const sample_count = @min(opts.sample_size, 100);
    while (row_idx < sample_count + 1) : (row_idx += 1) {
        const line = line_iter.next() orelse break;
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        var col_idx: usize = 0;
        var col_iter = std.mem.splitScalar(u8, trimmed, opts.delimiter);
        while (col_iter.next()) |cell| : (col_idx += 1) {
            if (col_idx >= sample_values.items.len) break;

            const cell_trimmed = std.mem.trim(u8, cell, &std.ascii.whitespace);
            const cell_unquoted = unquoteCSV(cell_trimmed, opts.quote_char);
            const cell_copy = try allocator.dupe(u8, cell_unquoted);
            try sample_values.items[col_idx].append(allocator, cell_copy);
        }

        // If no header, infer column count from first row
        if (!opts.header and row_idx == 0) {
            col_idx = 0;
            var temp_iter = std.mem.splitScalar(u8, trimmed, opts.delimiter);
            while (temp_iter.next()) |_| : (col_idx += 1) {
                const col_name = try std.fmt.allocPrint(allocator, "column{d}", .{col_idx});
                try column_names.append(allocator, col_name);
                try sample_values.append(allocator, std.ArrayList([]const u8){});
            }
        }
    }

    // Infer types
    for (sample_values.items) |col_samples| {
        const inferred_type = inferColumnType(col_samples.items);
        try column_types.append(allocator, inferred_type);
    }

    // Build schema
    const column_defs = try allocator.alloc(Schema.ColumnDef, column_names.items.len);
    errdefer allocator.free(column_defs);
    for (column_names.items, column_types.items, 0..) |name, dtype, i| {
        column_defs[i] = .{ .name = name, .data_type = dtype };
    }

    const schema = try Schema.init(allocator, column_defs);

    // Clean up temporary column_defs - Schema.init makes its own copy
    allocator.free(column_defs);

    return schema;
}

fn inferColumnType(samples: []const []const u8) DataType {
    if (samples.len == 0) return .string;

    var all_int32 = true;
    var all_int64 = true;
    var all_float = true;
    var all_bool = true;

    for (samples) |sample| {
        if (sample.len == 0) continue;

        // Check bool
        if (all_bool) {
            var lower_buf: [32]u8 = undefined;
            if (sample.len <= lower_buf.len) {
                const lower = std.ascii.lowerString(lower_buf[0..sample.len], sample);
                if (!std.mem.eql(u8, lower, "true") and !std.mem.eql(u8, lower, "false")) {
                    all_bool = false;
                }
            } else {
                all_bool = false;
            }
        }

        // Check numeric
        if (all_int32 or all_int64) {
            if (std.fmt.parseInt(i64, sample, 10)) |parsed_int| {
                if (all_int32) {
                    if (parsed_int < std.math.minInt(i32) or parsed_int > std.math.maxInt(i32)) {
                        all_int32 = false;
                    }
                }
            } else |_| {
                all_int32 = false;
                all_int64 = false;
            }
        }

        // Check float
        if (all_float and !all_int64) {
            _ = std.fmt.parseFloat(f64, sample) catch {
                all_float = false;
            };
        }
    }

    if (all_bool) return .boolean;
    if (all_int32) return .int32;
    if (all_int64) return .int64;
    if (all_float) return .float64;
    return .string;
}

fn loadCSV(file_path: []const u8, schema: Schema, opts: LoadOptions, allocator: std.mem.Allocator) !Table {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(content);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    var row_idx: usize = 0;

    // Skip header if needed
    if (opts.header) {
        _ = line_iter.next() orelse return error.EmptyFile;
        row_idx += 1;
    }

    // Skip rows if requested
    var skip_count: usize = 0;
    while (skip_count < opts.skip_rows) : (skip_count += 1) {
        _ = line_iter.next() orelse break;
        row_idx += 1;
    }

    // Count rows first
    var row_count: usize = 0;
    var temp_iter = line_iter;
    while (temp_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;
        row_count += 1;
        if (opts.max_rows != null and row_count >= opts.max_rows.?) break;
    }

    var table = try Table.init(allocator, "csv_table", schema.columns);
    errdefer table.deinit();

    // Parse rows
    line_iter = std.mem.splitScalar(u8, content, '\n');
    var parsed_rows: usize = 0;

    // Skip again to get back to data start
    skip_count = 0;
    while (skip_count < row_idx) : (skip_count += 1) {
        _ = line_iter.next();
    }

    while (line_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        var values = try allocator.alloc(Value, schema.columns.len);
        defer allocator.free(values);

        var col_idx: usize = 0;
        var col_iter = std.mem.splitScalar(u8, trimmed, opts.delimiter);
        while (col_iter.next()) |cell| : (col_idx += 1) {
            if (col_idx >= schema.columns.len) break;

            const cell_trimmed = std.mem.trim(u8, cell, &std.ascii.whitespace);
            const cell_unquoted = unquoteCSV(cell_trimmed, opts.quote_char);

            if (cell_unquoted.len == 0) {
                values[col_idx] = getDefaultValue(schema.columns[col_idx].data_type);
            } else {
                values[col_idx] = try parseValue(cell_unquoted, schema.columns[col_idx].data_type, allocator);
            }
        }

        // Fill remaining columns with defaults
        while (col_idx < schema.columns.len) : (col_idx += 1) {
            values[col_idx] = getDefaultValue(schema.columns[col_idx].data_type);
        }

        try table.insertRow(values);
        parsed_rows += 1;
        if (opts.max_rows != null and parsed_rows >= opts.max_rows.?) break;
    }

    return table;
}

fn saveCSV(table: Table, file_path: []const u8, opts: SaveOptions, allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    // Write header
    if (opts.include_header) {
        for (table.schema.columns, 0..) |col, i| {
            if (i > 0) try buffer.append(allocator, ',');
            try writeCSVValueToBuffer(&buffer, allocator, col.name);
        }
        try buffer.append(allocator, '\n');
    }

    // Write rows
    var row: usize = 0;
    while (row < table.row_count) : (row += 1) {
        for (table.schema.columns, 0..) |_, col_idx| {
            if (col_idx > 0) try buffer.append(allocator, ',');

            const val = try table.getCell(row, col_idx);
            switch (val) {
                .int32 => |v| {
                    var buf: [32]u8 = undefined;
                    const s = try std.fmt.bufPrint(&buf, "{d}", .{v});
                    try buffer.appendSlice(allocator, s);
                },
                .int64 => |v| {
                    var buf: [32]u8 = undefined;
                    const s = try std.fmt.bufPrint(&buf, "{d}", .{v});
                    try buffer.appendSlice(allocator, s);
                },
                .float32 => |v| {
                    var buf: [32]u8 = undefined;
                    const s = try std.fmt.bufPrint(&buf, "{d}", .{v});
                    try buffer.appendSlice(allocator, s);
                },
                .float64 => |v| {
                    var buf: [32]u8 = undefined;
                    const s = try std.fmt.bufPrint(&buf, "{d}", .{v});
                    try buffer.appendSlice(allocator, s);
                },
                .boolean => |v| try buffer.appendSlice(allocator, if (v) "true" else "false"),
                .string => |v| try writeCSVValueToBuffer(&buffer, allocator, v),
                .timestamp => |v| {
                    var buf: [32]u8 = undefined;
                    const s = try std.fmt.bufPrint(&buf, "{d}", .{v});
                    try buffer.appendSlice(allocator, s);
                },
                .vector => |_| {}, // TODO: Implement vector serialization
                .custom => |_| {}, // TODO: Implement custom type serialization
                .exception => |_| {}, // Exception values not serialized to CSV
            }
        }
        try buffer.append(allocator, '\n');
    }

    try file.writeAll(buffer.items);
}

fn parseValue(str: []const u8, dtype: DataType, allocator: std.mem.Allocator) !Value {
    return switch (dtype) {
        .int32 => Value{ .int32 = try std.fmt.parseInt(i32, str, 10) },
        .int64 => Value{ .int64 = try std.fmt.parseInt(i64, str, 10) },
        .float32 => Value{ .float32 = try std.fmt.parseFloat(f32, str) },
        .float64 => Value{ .float64 = try std.fmt.parseFloat(f64, str) },
        .boolean => blk: {
            var lower_buf: [8]u8 = undefined;
            if (str.len <= lower_buf.len) {
                const lower = std.ascii.lowerString(lower_buf[0..str.len], str);
                break :blk Value{ .boolean = std.mem.eql(u8, lower, "true") };
            }
            break :blk Value{ .boolean = false };
        },
        .string => Value{ .string = try allocator.dupe(u8, str) },
        .timestamp, .vector, .custom, .exception => return error.UnsupportedType,
    };
}

fn getDefaultValue(dtype: DataType) Value {
    return switch (dtype) {
        .int32 => Value{ .int32 = 0 },
        .int64 => Value{ .int64 = 0 },
        .float32 => Value{ .float32 = 0.0 },
        .float64 => Value{ .float64 = 0.0 },
        .boolean => Value{ .boolean = false },
        .string, .timestamp, .vector, .custom, .exception => Value{ .string = "" },
    };
}

fn unquoteCSV(str: []const u8, quote_char: u8) []const u8 {
    if (str.len < 2) return str;
    if (str[0] == quote_char and str[str.len - 1] == quote_char) {
        return str[1 .. str.len - 1];
    }
    return str;
}

fn writeCSVValueToBuffer(buffer: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    const needs_quote = std.mem.indexOfAny(u8, value, ",\"\n") != null;

    if (needs_quote) {
        try buffer.append(allocator, '"');
        for (value) |c| {
            if (c == '"') {
                try buffer.appendSlice(allocator, "\"\"");
            } else {
                try buffer.append(allocator, c);
            }
        }
        try buffer.append(allocator, '"');
    } else {
        try buffer.appendSlice(allocator, value);
    }
}

// Tests
test "CSV schema inference" {
    const allocator = std.testing.allocator;

    const test_file = "test_infer.csv";
    {
        const file = try std.fs.cwd().createFile(test_file, .{});
        defer file.close();
        try file.writeAll("id,name,age,score,active\n");
        try file.writeAll("1,Alice,30,95.5,true\n");
        try file.writeAll("2,Bob,25,87.3,false\n");
        try file.writeAll("3,Carol,35,92.1,true\n");
    }
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const opts = LoadOptions{ .header = true, .delimiter = ',', .quote_char = '"', .skip_rows = 0, .max_rows = null, .sample_size = 100 };
    var schema = try inferCSVSchema(test_file, opts, allocator);
    defer schema.deinit();

    try std.testing.expectEqual(@as(usize, 5), schema.columns.len);
    try std.testing.expectEqualStrings("id", schema.columns[0].name);
    try std.testing.expectEqual(DataType.int32, schema.columns[0].data_type);
    try std.testing.expectEqualStrings("name", schema.columns[1].name);
    try std.testing.expectEqual(DataType.string, schema.columns[1].data_type);
    try std.testing.expectEqualStrings("age", schema.columns[2].name);
    try std.testing.expectEqual(DataType.int32, schema.columns[2].data_type);
    try std.testing.expectEqualStrings("score", schema.columns[3].name);
    try std.testing.expectEqual(DataType.float64, schema.columns[3].data_type);
    try std.testing.expectEqualStrings("active", schema.columns[4].name);
    try std.testing.expectEqual(DataType.boolean, schema.columns[4].data_type);
}

test "CSV load and save" {
    const allocator = std.testing.allocator;

    const test_file = "test_roundtrip.csv";
    {
        const file = try std.fs.cwd().createFile(test_file, .{});
        defer file.close();
        try file.writeAll("id,value\n");
        try file.writeAll("1,100\n");
        try file.writeAll("2,200\n");
    }
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const opts = LoadOptions{ .header = true, .delimiter = ',', .quote_char = '"', .skip_rows = 0, .max_rows = null, .sample_size = 100 };
    var schema = try inferCSVSchema(test_file, opts, allocator);
    defer schema.deinit();

    var table = try loadCSV(test_file, schema, opts, allocator);
    defer table.deinit();

    try std.testing.expectEqual(@as(usize, 2), table.row_count);

    const output_file = "test_output.csv";
    defer std.fs.cwd().deleteFile(output_file) catch {};

    const save_opts = SaveOptions{ .compression = .none, .row_group_size = 1000, .include_metadata = false, .include_header = true };
    try saveCSV(table, output_file, save_opts, allocator);

    const file_exists = format.fileExists(output_file);
    try std.testing.expect(file_exists);
}
