const std = @import("std");
const FunctionRegistry = @import("function.zig").FunctionRegistry;
const Function = @import("function.zig").Function;
const FunctionBody = @import("function.zig").FunctionBody;
const Parameter = @import("function.zig").Parameter;
const DataType = @import("types.zig").DataType;

/// Parse a SQL file and extract function definitions into a function registry
pub fn parseSqlFile(allocator: std.mem.Allocator, file_path: []const u8) !*FunctionRegistry {
    // Read the file
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const content = try allocator.alloc(u8, file_size);
    defer allocator.free(content);

    _ = try file.readAll(content);

    // Create a function registry
    const registry = try allocator.create(FunctionRegistry);
    registry.* = FunctionRegistry.init(allocator);
    errdefer {
        registry.deinit();
        allocator.destroy(registry);
    }

    // Simple parsing: look for CREATE FUNCTION
    var i: usize = 0;
    while (i < content.len) {
        // Skip whitespace
        while (i < content.len and std.ascii.isWhitespace(content[i])) {
            i += 1;
        }
        if (i >= content.len) break;

        // Look for CREATE
        if (std.mem.startsWith(u8, content[i..], "CREATE")) {
            i += 6;
            // Skip whitespace
            while (i < content.len and std.ascii.isWhitespace(content[i])) {
                i += 1;
            }
            // Look for FUNCTION
            if (std.mem.startsWith(u8, content[i..], "FUNCTION")) {
                i += 8;
                try parseSimpleCreateFunction(content, &i, registry);
            }
        } else {
            // Skip to next statement
            while (i < content.len and content[i] != ';') {
                i += 1;
            }
            if (i < content.len) i += 1; // skip ;
        }
    }

    return registry;
}

/// Simple CREATE FUNCTION parser
fn parseSimpleCreateFunction(content: []const u8, i: *usize, registry: *FunctionRegistry) !void {
    // Skip whitespace
    while (i.* < content.len and std.ascii.isWhitespace(content[i.*])) {
        i.* += 1;
    }

    // Get function name
    const name_start = i.*;
    while (i.* < content.len and content[i.*] != '(') {
        i.* += 1;
    }
    const function_name = std.mem.trim(u8, content[name_start..i.*], &std.ascii.whitespace);

    // Skip (
    i.* += 1;

    // Parse parameters
    var parameters = try std.ArrayList(Parameter).initCapacity(registry.allocator, 0);
    defer parameters.deinit(registry.allocator);

    while (i.* < content.len) {
        // Skip whitespace
        while (i.* < content.len and std.ascii.isWhitespace(content[i.*])) {
            i.* += 1;
        }

        if (content[i.*] == ')') {
            i.* += 1;
            break;
        }

        // Get parameter name
        const param_name_start = i.*;
        while (i.* < content.len and !std.ascii.isWhitespace(content[i.*])) {
            i.* += 1;
        }
        const param_name = content[param_name_start..i.*];

        // Skip whitespace
        while (i.* < content.len and std.ascii.isWhitespace(content[i.*])) {
            i.* += 1;
        }

        // Get parameter type
        const param_type_start = i.*;
        while (i.* < content.len and (std.ascii.isAlphabetic(content[i.*]) or content[i.*] == '_')) {
            i.* += 1;
        }
        const param_type_str = content[param_type_start..i.*];
        const param_type = try parseDataType(param_type_str);

        const param = Parameter{
            .name = try registry.allocator.dupe(u8, param_name),
            .type_ = param_type,
        };
        try parameters.append(registry.allocator, param);

        // Skip comma or )
        while (i.* < content.len and (content[i.*] == ',' or std.ascii.isWhitespace(content[i.*]))) {
            i.* += 1;
        }
    }

    // Skip RETURNS
    while (i.* < content.len and !std.mem.startsWith(u8, content[i.*..], "RETURNS")) {
        i.* += 1;
    }
    if (i.* < content.len) i.* += 7;

    // Skip whitespace
    while (i.* < content.len and std.ascii.isWhitespace(content[i.*])) {
        i.* += 1;
    }

    // Get return type
    const return_type_start = i.*;
    while (i.* < content.len and (std.ascii.isAlphabetic(content[i.*]) or content[i.*] == '_')) {
        i.* += 1;
    }
    const return_type_str = content[return_type_start..i.*];
    const return_type = try parseDataType(return_type_str);

    // Skip to {
    while (i.* < content.len and content[i.*] != '{') {
        i.* += 1;
    }
    i.* += 1; // skip {

    // Get function body until }
    const body_start = i.*;
    var brace_count: usize = 1;
    while (i.* < content.len and brace_count > 0) {
        if (content[i.*] == '{') {
            brace_count += 1;
        } else if (content[i.*] == '}') {
            brace_count -= 1;
        }
        i.* += 1;
    }
    const body_content = std.mem.trim(u8, content[body_start .. i.* - 1], &std.ascii.whitespace);

    // Build expression with quotes around string literals
    var expression = try std.ArrayList(u8).initCapacity(registry.allocator, 0);
    defer expression.deinit(registry.allocator);

    var j: usize = 0;
    while (j < body_content.len) {
        if (body_content[j] == '\'') {
            // String literal
            try expression.append(registry.allocator, '\'');
            j += 1;
            while (j < body_content.len and body_content[j] != '\'') {
                try expression.append(registry.allocator, body_content[j]);
                j += 1;
            }
            if (j < body_content.len) {
                try expression.append(registry.allocator, '\'');
                j += 1;
            }
        } else {
            try expression.append(registry.allocator, body_content[j]);
            j += 1;
        }
    }

    const function_body = FunctionBody{ .expression = try expression.toOwnedSlice(registry.allocator) };

    std.debug.print("Parsed function body: '{s}'\n", .{function_body.expression});

    // Create the function
    const function = try registry.allocator.create(Function);
    function.* = try Function.init(
        registry.allocator,
        function_name,
        try parameters.toOwnedSlice(registry.allocator),
        return_type,
        function_body,
        .runtime,
    );

    std.debug.print("Registering function '{s}'...\n", .{function_name});

    // Register the function
    try registry.registerFunction(function);

    std.debug.print("Function '{s}' registered successfully\n", .{function_name});
}

/// Parse a data type from string
fn parseDataType(type_str: []const u8) !DataType {
    if (std.mem.eql(u8, type_str, "INT") or std.mem.eql(u8, type_str, "INTEGER")) {
        return .int32;
    } else if (std.mem.eql(u8, type_str, "BIGINT")) {
        return .int64;
    } else if (std.mem.eql(u8, type_str, "FLOAT")) {
        return .float32;
    } else if (std.mem.eql(u8, type_str, "DOUBLE") or std.mem.eql(u8, type_str, "REAL")) {
        return .float64;
    } else if (std.mem.eql(u8, type_str, "BOOL") or std.mem.eql(u8, type_str, "BOOLEAN")) {
        return .boolean;
    } else if (std.mem.eql(u8, type_str, "TEXT") or std.mem.eql(u8, type_str, "VARCHAR") or std.mem.eql(u8, type_str, "STRING")) {
        return .string;
    } else if (std.mem.eql(u8, type_str, "TIMESTAMP")) {
        return .timestamp;
    } else {
        return error.UnknownDataType;
    }
}
