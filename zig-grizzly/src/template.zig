const std = @import("std");
const expression = @import("expression.zig");
const ExpressionEngine = expression.ExpressionEngine;

/// Template compilation and execution for PL-Grizzly
pub const TemplateEngine = struct {
    allocator: std.mem.Allocator,
    expression_engine: ExpressionEngine,

    pub fn init(allocator: std.mem.Allocator) TemplateEngine {
        return TemplateEngine{
            .allocator = allocator,
            .expression_engine = ExpressionEngine.init(allocator),
        };
    }

    pub fn initWithFunctions(allocator: std.mem.Allocator, functions: *const @import("function.zig").FunctionRegistry) TemplateEngine {
        return TemplateEngine{
            .allocator = allocator,
            .expression_engine = ExpressionEngine.initWithFunctions(allocator, functions),
        };
    }

    pub fn deinit(self: *TemplateEngine) void {
        self.expression_engine.deinit();
    }

    /// Compile a template string with PL-Grizzly expressions
    /// Input format: { expression } or { if condition then 'sql' else 'sql' end }
    pub fn compileTemplate(self: *TemplateEngine, template_sql: []const u8) ![]const u8 {
        var result = try std.ArrayList(u8).initCapacity(self.allocator, template_sql.len);
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < template_sql.len) {
            if (i + 1 < template_sql.len and template_sql[i] == '{' and template_sql[i + 1] == '{') {
                // Skip double braces {{ - these are literal braces
                try result.append(self.allocator, '{');
                i += 2;
                continue;
            }

            if (template_sql[i] == '{') {
                // Find the matching }
                var brace_count: usize = 1;
                var j = i + 1;
                const expr_start = i + 1;

                while (j < template_sql.len and brace_count > 0) {
                    if (template_sql[j] == '{') {
                        brace_count += 1;
                    } else if (template_sql[j] == '}') {
                        brace_count -= 1;
                    }
                    j += 1;
                }

                if (brace_count > 0) {
                    return error.UnmatchedBrace;
                }

                const expr_content = template_sql[expr_start .. j - 1];
                const trimmed_expr = std.mem.trim(u8, expr_content, &std.ascii.whitespace);

                // Handle different expression types
                if (std.mem.startsWith(u8, trimmed_expr, "if ")) {
                    const sql = try self.compileIfExpression(trimmed_expr);
                    try result.appendSlice(self.allocator, sql);
                    self.allocator.free(sql);
                } else if (std.mem.startsWith(u8, trimmed_expr, "let ")) {
                    try self.compileLetExpression(trimmed_expr);
                } else {
                    // Simple variable or expression
                    const value = try self.expression_engine.evaluate(trimmed_expr);
                    try self.appendValueToSql(&result, value);
                    @constCast(&value).deinit(self.allocator);
                }

                i = j;
                continue;
            }

            try result.append(self.allocator, template_sql[i]);
            i += 1;
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Compile an if expression: { if condition then 'sql' else 'sql' end }
    fn compileIfExpression(self: *TemplateEngine, expr: []const u8) ![]const u8 {
        // Parse: if condition then 'sql' else 'sql' end
        const if_pattern = "if ";
        const then_pattern = " then ";
        const else_pattern = " else ";
        const end_pattern = " end";

        if (!std.mem.startsWith(u8, expr, if_pattern)) {
            return error.InvalidIfExpression;
        }

        var remaining = expr[if_pattern.len..];

        // Find 'then'
        const then_index = std.mem.indexOf(u8, remaining, then_pattern) orelse return error.InvalidIfExpression;
        const condition = remaining[0..then_index];
        remaining = remaining[then_index + then_pattern.len ..];

        // Find 'else'
        const else_index = std.mem.indexOf(u8, remaining, else_pattern) orelse return error.InvalidIfExpression;
        const then_sql = remaining[0..else_index];
        remaining = remaining[else_index + else_pattern.len ..];

        // Find 'end'
        const end_index = std.mem.indexOf(u8, remaining, end_pattern) orelse return error.InvalidIfExpression;
        const else_sql = remaining[0..end_index];

        // Evaluate condition
        const cond_value = try self.expression_engine.evaluate(std.mem.trim(u8, condition, &std.ascii.whitespace));
        const condition_result = switch (cond_value) {
            .boolean => |b| b,
            .int64 => |i| i != 0,
            .float64 => |f| f != 0.0,
            .string => |s| s.len > 0,
            else => false,
        };

        // Return appropriate SQL (remove quotes if present and process template variables)
        const sql_to_use = if (condition_result) then_sql else else_sql;
        const trimmed_sql = std.mem.trim(u8, sql_to_use, &std.ascii.whitespace);

        var sql_content: []const u8 = undefined;
        if (trimmed_sql.len >= 2 and trimmed_sql[0] == '\'' and trimmed_sql[trimmed_sql.len - 1] == '\'') {
            sql_content = trimmed_sql[1 .. trimmed_sql.len - 1];
        } else {
            sql_content = trimmed_sql;
        }

        // Unescape the SQL content (handle \' -> ')
        var unescaped = try std.ArrayList(u8).initCapacity(self.allocator, sql_content.len);
        defer unescaped.deinit(self.allocator);
        var i: usize = 0;
        while (i < sql_content.len) {
            if (i < sql_content.len - 1 and sql_content[i] == '\\' and sql_content[i + 1] == '\'') {
                try unescaped.append(self.allocator, '\'');
                i += 2;
            } else {
                try unescaped.append(self.allocator, sql_content[i]);
                i += 1;
            }
        }

        // Process template variables in the unescaped SQL content
        return self.expression_engine.evaluateTemplate(unescaped.items);
    }

    /// Compile a let expression: { let var_name = value }
    fn compileLetExpression(self: *TemplateEngine, expr: []const u8) !void {
        const let_pattern = "let ";
        const eq_pattern = " = ";

        if (!std.mem.startsWith(u8, expr, let_pattern)) {
            return error.InvalidLetExpression;
        }

        var remaining = expr[let_pattern.len..];
        const eq_index = std.mem.indexOf(u8, remaining, eq_pattern) orelse return error.InvalidLetExpression;

        const var_name = std.mem.trim(u8, remaining[0..eq_index], &std.ascii.whitespace);
        const value_expr = std.mem.trim(u8, remaining[eq_index + eq_pattern.len ..], &std.ascii.whitespace);

        const value = try self.expression_engine.evaluate(value_expr);
        try self.expression_engine.setVariable(var_name, value);
        @constCast(&value).deinit(self.allocator);
    }

    /// Append a value to SQL output
    fn appendValueToSql(self: *TemplateEngine, result: *std.ArrayList(u8), value: expression.Value) !void {
        switch (value) {
            .string => |s| try result.appendSlice(self.allocator, s),
            .int64 => |int| {
                var buf: [20]u8 = undefined;
                const str = try std.fmt.bufPrint(&buf, "{}", .{int});
                try result.appendSlice(self.allocator, str);
            },
            .float64 => |f| {
                var buf: [32]u8 = undefined;
                const str = try std.fmt.bufPrint(&buf, "{}", .{f});
                try result.appendSlice(self.allocator, str);
            },
            .boolean => |b| try result.appendSlice(self.allocator, if (b) "true" else "false"),
            else => return error.UnsupportedValueType,
        }
    }

    /// Set a template variable
    pub fn setVariable(self: *TemplateEngine, name: []const u8, value: expression.Value) !void {
        try self.expression_engine.setVariable(name, value);
    }

    /// Get a template variable
    pub fn getVariable(self: *TemplateEngine, name: []const u8) ?expression.Value {
        return self.expression_engine.getVariable(name);
    }
};

test "TemplateEngine basic compilation" {
    var engine = TemplateEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Test simple variable substitution
    const table_name = try std.testing.allocator.dupe(u8, "users");
    defer std.testing.allocator.free(table_name);
    try engine.setVariable("table_name", expression.Value{ .string = table_name });

    const template = "SELECT * FROM {table_name}";
    const result = try engine.compileTemplate(template);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("SELECT * FROM users", result);
}

test "TemplateEngine if expression" {
    var engine = TemplateEngine.init(std.testing.allocator);
    defer engine.deinit();

    try engine.setVariable("active_only", expression.Value{ .boolean = true });

    const template = "SELECT * FROM users { if active_only then 'WHERE active = true' else '' end }";
    const result = try engine.compileTemplate(template);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("SELECT * FROM users WHERE active = true", result);
}

test "TemplateEngine let expression" {
    var engine = TemplateEngine.init(std.testing.allocator);
    defer engine.deinit();

    const template = "{ let table_name = 'products' }SELECT * FROM {table_name}";
    const result = try engine.compileTemplate(template);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("SELECT * FROM products", result);
}

test "TemplateEngine complex template" {
    var engine = TemplateEngine.init(std.testing.allocator);
    defer engine.deinit();

    const table_name = try std.testing.allocator.dupe(u8, "orders");
    defer std.testing.allocator.free(table_name);
    try engine.setVariable("include_filter", expression.Value{ .boolean = true });
    try engine.setVariable("table_name", expression.Value{ .string = table_name });
    try engine.setVariable("limit_count", expression.Value{ .int64 = 100 });

    const template =
        \\{ let status_filter = 'pending' }
        \\SELECT id, amount FROM {table_name}
        \\{ if include_filter then 'WHERE status = \'{status_filter}\'' else '' end }
        \\ORDER BY created_at DESC
        \\LIMIT {limit_count}
    ;

    const result = try engine.compileTemplate(template);
    defer std.testing.allocator.free(result);

    const expected =
        \\
        \\SELECT id, amount FROM orders
        \\WHERE status = 'pending'
        \\ORDER BY created_at DESC
        \\LIMIT 100
    ;

    try std.testing.expectEqualStrings(expected, result);
}
