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

/// JSON Format Loader - handles both JSON arrays and JSONL (line-delimited)
pub const JSON_LOADER = FormatLoader{
    .name = "JSON",
    .extensions = &[_][]const u8{ "json", "jsonl", "ndjson" },
    .detectFn = detectJSON,
    .inferSchemaFn = inferJSONSchema,
    .loadFn = loadJSON,
    .saveFn = saveJSON,
};

fn detectJSON(file_path: []const u8) bool {
    const ext = format.getExtension(file_path) orelse return false;
    for (JSON_LOADER.extensions) |e| {
        if (std.mem.eql(u8, ext, e)) return true;
    }
    return false;
}

fn isJSONL(content: []const u8) bool {
    // Check if content looks like JSONL (each line is valid JSON object)
    var lines = std.mem.splitScalar(u8, content, '\n');
    var valid_json_lines: usize = 0;
    var total_lines: usize = 0;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        total_lines += 1;
        // Simple check: starts with { and ends with }
        if (std.mem.startsWith(u8, trimmed, "{") and std.mem.endsWith(u8, trimmed, "}")) {
            valid_json_lines += 1;
        }
    }

    return total_lines > 0 and valid_json_lines == total_lines;
}

fn inferJSONSchema(allocator: std.mem.Allocator, file_path: []const u8, opts: LoadOptions) !Schema {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(content);

    var column_names = std.ArrayList([]const u8){};
    defer {
        for (column_names.items) |name| {
            allocator.free(name);
        }
        column_names.deinit(allocator);
    }

    var column_types = std.ArrayList(DataType){};
    defer column_types.deinit(allocator);

    // Check if JSONL or JSON array
    const is_jsonl = isJSONL(content);

    if (is_jsonl) {
        // Parse JSONL format
        var lines = std.mem.splitScalar(u8, content, '\n');
        var line_count: usize = 0;
        const sample_limit = opts.sample_size;

        while (lines.next()) |line| {
            if (line_count >= sample_limit) break;

            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            // Simple JSON object parsing (basic extraction)
            try parseJSONObject(allocator, trimmed, &column_names, &column_types);
            line_count += 1;
        }
    } else {
        // Try to parse as JSON array
        const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);
        if (std.mem.startsWith(u8, trimmed, "[")) {
            // Extract objects from array
            var brace_count: usize = 0;
            var obj_start: usize = 0;
            var in_string = false;
            var line_count: usize = 0;
            const sample_limit = opts.sample_size;

            for (trimmed, 0..) |ch, i| {
                if (ch == '"' and (i == 0 or trimmed[i - 1] != '\\')) {
                    in_string = !in_string;
                }
                if (!in_string) {
                    if (ch == '{') {
                        if (brace_count == 0) obj_start = i;
                        brace_count += 1;
                    } else if (ch == '}') {
                        brace_count -= 1;
                        if (brace_count == 0 and line_count < sample_limit) {
                            const obj_str = trimmed[obj_start .. i + 1];
                            try parseJSONObject(allocator, obj_str, &column_names, &column_types);
                            line_count += 1;
                        }
                    }
                }
            }
        }
    }

    // Build final schema with most common types
    var columns = std.ArrayList(schema_mod.Column){};
    defer columns.deinit(allocator);

    for (column_names.items, 0..) |name, i| {
        if (i < column_types.items.len) {
            try columns.append(allocator, .{
                .name = name,
                .data_type = column_types.items[i],
                .nullable = true,
                .is_indexed = false,
            });
        }
    }

    return try Schema.init(allocator, columns.items);
}

fn parseJSONObject(allocator: std.mem.Allocator, obj_str: []const u8, column_names: *std.ArrayList([]const u8), column_types: *std.ArrayList(DataType)) !void {
    // Simple JSON object key-value parser
    var i: usize = 1; // Skip opening {
    var in_string = false;
    var in_key = true;
    var key_start: usize = 0;
    var key_end: usize = 0;
    var val_start: usize = 0;

    while (i < obj_str.len) : (i += 1) {
        const ch = obj_str[i];

        if (ch == '"' and (i == 0 or obj_str[i - 1] != '\\')) {
            if (!in_string) {
                in_string = true;
                if (in_key) {
                    key_start = i + 1;
                } else {
                    val_start = i + 1;
                }
            } else {
                in_string = false;
                if (in_key) {
                    key_end = i;
                    in_key = false;
                    // Skip to value
                    while (i < obj_str.len and (obj_str[i] == ':' or obj_str[i] == ' ' or obj_str[i] == '"')) : (i += 1) {}
                    if (i < obj_str.len) {
                        i -= 1;
                        val_start = i + 1;
                    }
                } else {
                    const key = obj_str[key_start..key_end];
                    const val = obj_str[val_start..i];
                    try recordColumnType(allocator, key, val, column_names, column_types);
                    in_key = true;
                }
            }
        }

        if (!in_string and ch == ',') {
            in_key = true;
        }
    }
}

fn recordColumnType(allocator: std.mem.Allocator, key: []const u8, val: []const u8, column_names: *std.ArrayList([]const u8), column_types: *std.ArrayList(DataType)) !void {
    // Check if column exists
    var col_index: ?usize = null;
    for (column_names.items, 0..) |existing_key, idx| {
        if (std.mem.eql(u8, existing_key, key)) {
            col_index = idx;
            break;
        }
    }

    const trimmed_val = std.mem.trim(u8, val, &std.ascii.whitespace);
    const inferred_type = inferJSONValueType(trimmed_val);

    if (col_index == null) {
        // New column
        const key_copy = try allocator.dupe(u8, key);
        try column_names.append(allocator, key_copy);
        try column_types.append(allocator, inferred_type);
    } else if (col_index) |idx| {
        // Update type to most general
        if (column_types.items[idx] != inferred_type) {
            column_types.items[idx] = promoteType(column_types.items[idx], inferred_type);
        }
    }
}

fn inferJSONValueType(val: []const u8) DataType {
    if (std.mem.eql(u8, val, "null")) {
        return .string; // Default to string for null
    }

    if (std.mem.eql(u8, val, "true") or std.mem.eql(u8, val, "false")) {
        return .boolean;
    }

    if (val[0] == '"') {
        return .string;
    }

    if (val[0] == '[' or val[0] == '{') {
        return .string; // Complex types as strings
    }

    // Try to parse as number
    if (std.fmt.parseInt(i64, val, 10)) |_| {
        return .int64;
    } else |_| {}

    if (std.fmt.parseFloat(f64, val)) |_| {
        return .float64;
    } else |_| {}

    return .string;
}

fn promoteType(current: DataType, new: DataType) DataType {
    if (current == new) return current;
    if (current == .string or new == .string) return .string;
    if (current == .float64 or new == .float64) return .float64;
    if (current == .int64 or new == .int64) return .int64;
    if (current == .int32 or new == .int32) return .int32;
    return .string;
}

fn loadJSON(allocator: std.mem.Allocator, file_path: []const u8, opts: LoadOptions) !*Table {
    const schema = try inferJSONSchema(allocator, file_path, opts);
    defer schema.deinit();

    const table_name = opts.table_name orelse "data";
    var table = try Table.init(allocator, table_name, schema.columns.items);

    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(content);

    const is_jsonl = isJSONL(content);
    var row_count: usize = 0;

    if (is_jsonl) {
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (opts.max_rows) |max_rows| {
                if (row_count >= max_rows) break;
            }

            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            try parseJSONRowAndInsert(allocator, trimmed, &table, &schema);
            row_count += 1;
        }
    } else {
        // JSON array format
        const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);
        if (std.mem.startsWith(u8, trimmed, "[")) {
            var brace_count: usize = 0;
            var obj_start: usize = 0;
            var in_string = false;

            for (trimmed, 0..) |ch, i| {
                if (ch == '"' and (i == 0 or trimmed[i - 1] != '\\')) {
                    in_string = !in_string;
                }
                if (!in_string) {
                    if (ch == '{') {
                        if (brace_count == 0) obj_start = i;
                        brace_count += 1;
                    } else if (ch == '}') {
                        brace_count -= 1;
                        if (brace_count == 0) {
                            if (opts.max_rows) |max_rows| {
                                if (row_count >= max_rows) break;
                            }
                            const obj_str = trimmed[obj_start .. i + 1];
                            try parseJSONRowAndInsert(allocator, obj_str, &table, &schema);
                            row_count += 1;
                        }
                    }
                }
            }
        }
    }

    return table;
}

fn parseJSONRowAndInsert(allocator: std.mem.Allocator, obj_str: []const u8, table: *Table, schema: *const Schema) !void {
    var row = std.ArrayList(Value){};
    defer row.deinit(allocator);

    for (schema.columns.items) |col| {
        // Extract value for this column
        const val = try extractJSONValue(allocator, obj_str, col.name);
        try row.append(allocator, val);
    }

    try table.insertRow(allocator, row.items);
}

fn extractJSONValue(allocator: std.mem.Allocator, obj_str: []const u8, key: []const u8) !Value {
    // Find key in JSON object
    var search_str = obj_str;
    var found = false;
    var val_start: usize = 0;
    var val_end: usize = 0;

    var i: usize = 0;
    var in_string = false;

    while (i < search_str.len) : (i += 1) {
        const ch = search_str[i];

        if (ch == '"' and (i == 0 or search_str[i - 1] != '\\')) {
            if (!in_string) {
                in_string = true;
                // Check if this is our key
                if (i + key.len + 2 <= search_str.len) {
                    const potential_key = search_str[i + 1 .. i + 1 + key.len];
                    if (std.mem.eql(u8, potential_key, key)) {
                        // Found our key
                        i += key.len + 1;
                        // Skip to colon
                        while (i < search_str.len and search_str[i] != ':') : (i += 1) {}
                        i += 1;
                        // Skip whitespace
                        while (i < search_str.len and (search_str[i] == ' ' or search_str[i] == '\t')) : (i += 1) {}

                        val_start = i;
                        found = true;
                        in_string = false;
                        break;
                    }
                }
            }
        }
    }

    if (!found) {
        // Column not in this row
        return .{ .string = "" };
    }

    // Extract value
    in_string = false;
    var brace_count: usize = 0;

    for (val_start..search_str.len) |j| {
        const ch = search_str[j];

        if (ch == '"' and (j == 0 or search_str[j - 1] != '\\')) {
            in_string = !in_string;
        }

        if (!in_string) {
            if (ch == '{' or ch == '[') {
                brace_count += 1;
            } else if (ch == '}' or ch == ']') {
                brace_count -= 1;
            } else if ((ch == ',' or ch == '}') and brace_count == 0) {
                val_end = j;
                break;
            }
        }
    }

    if (val_end == 0) {
        val_end = search_str.len;
    }

    const raw_val = std.mem.trim(u8, search_str[val_start..val_end], &std.ascii.whitespace);

    // Parse value based on type
    if (std.mem.eql(u8, raw_val, "null")) {
        return .{ .string = "" };
    }

    if (raw_val[0] == '"') {
        const unquoted = raw_val[1 .. raw_val.len - 1];
        return .{ .string = try allocator.dupe(u8, unquoted) };
    }

    if (std.mem.eql(u8, raw_val, "true")) {
        return .{ .boolean = true };
    }

    if (std.mem.eql(u8, raw_val, "false")) {
        return .{ .boolean = false };
    }

    if (std.fmt.parseInt(i64, raw_val, 10)) |int_val| {
        return .{ .int64 = int_val };
    } else |_| {}

    if (std.fmt.parseFloat(f64, raw_val)) |float_val| {
        return .{ .float64 = float_val };
    } else |_| {}

    const str_copy = try allocator.dupe(u8, raw_val);
    return .{ .string = str_copy };
}

fn saveJSON(allocator: std.mem.Allocator, table: *Table, file_path: []const u8, opts: SaveOptions) !void {
    const is_jsonl = std.mem.endsWith(u8, file_path, "jsonl") or std.mem.endsWith(u8, file_path, "ndjson");

    var output = std.ArrayList(u8){};
    defer output.deinit(allocator);

    if (!is_jsonl) {
        try output.appendSlice(allocator, "[\n");
    }

    for (0..table.row_count) |row_idx| {
        var row_obj = std.ArrayList(u8){};
        defer row_obj.deinit(allocator);

        try row_obj.appendSlice(allocator, "{");

        for (table.schema.columns.items, 0..) |col, col_idx| {
            if (col_idx > 0) {
                try row_obj.appendSlice(allocator, ",");
            }

            try row_obj.writer().print("\"{s}\":", .{col.name});

            const val = try table.getCell(allocator, row_idx, col_idx);

            switch (val) {
                .string => |s| try row_obj.writer().print("\"{s}\"", .{s}),
                .boolean => |b| try row_obj.writer().print("{}", .{b}),
                .int32 => |i| try row_obj.writer().print("{}", .{i}),
                .int64 => |i| try row_obj.writer().print("{}", .{i}),
                .float32 => |f| try row_obj.writer().print("{d}", .{f}),
                .float64 => |f| try row_obj.writer().print("{d}", .{f}),
                .timestamp => |ts| try row_obj.writer().print("{}", .{ts}),
                .vector => |_| try row_obj.appendSlice(allocator, "null"),
            }
        }

        try row_obj.appendSlice(allocator, "}");

        if (is_jsonl) {
            try output.appendSlice(allocator, row_obj.items);
            try output.appendSlice(allocator, "\n");
        } else {
            try output.appendSlice(allocator, row_obj.items);
            if (row_idx < table.row_count - 1) {
                try output.appendSlice(allocator, ",\n");
            } else {
                try output.appendSlice(allocator, "\n");
            }
        }
    }

    if (!is_jsonl) {
        try output.appendSlice(allocator, "]");
    }

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    try file.writeAll(output.items);

    _ = opts;
}
