const std = @import("std");
const types = @import("types.zig");
const function_mod = @import("function.zig");
pub const Value = types.Value;
const FunctionRegistry = function_mod.FunctionRegistry;

/// Expression evaluation engine for PL-Grizzly
pub const ExpressionEngine = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(Value),
    functions: ?*FunctionRegistry,

    pub fn init(allocator: std.mem.Allocator) ExpressionEngine {
        return ExpressionEngine{
            .allocator = allocator,
            .variables = std.StringHashMap(Value).init(allocator),
            .functions = null,
        };
    }

    pub fn initWithFunctions(allocator: std.mem.Allocator, functions: *FunctionRegistry) ExpressionEngine {
        return ExpressionEngine{
            .allocator = allocator,
            .variables = std.StringHashMap(Value).init(allocator),
            .functions = functions,
        };
    }

    pub fn deinit(self: *ExpressionEngine) void {
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.variables.deinit();
    }

    /// Set a variable in the current scope
    pub fn setVariable(self: *ExpressionEngine, name: []const u8, value: Value) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        // Clone the value to ensure ownership
        var value_copy = try value.clone(self.allocator);
        errdefer value_copy.deinit(self.allocator);

        // Remove existing if present
        if (self.variables.getKey(name)) |existing_key| {
            self.allocator.free(existing_key);
            if (self.variables.getPtr(existing_key)) |existing_value| {
                existing_value.deinit(self.allocator);
            }
        }

        try self.variables.put(name_copy, value_copy);
    }

    /// Get a variable value
    pub fn getVariable(self: *ExpressionEngine, name: []const u8) ?Value {
        return self.variables.get(name);
    }

    /// Evaluate a simple expression (for now just variable lookup)
    pub fn evaluate(self: *ExpressionEngine, expression: []const u8) (std.mem.Allocator.Error || std.fmt.ParseIntError || error{ InvalidExpression, UndefinedVariable, InvalidArgumentCount, InvalidArgumentType, NoPatternMatched })!Value {
        // Check for function calls first
        if (self.tryEvaluateFunctionCall(expression)) |maybe_result| {
            if (maybe_result) |result| {
                return result;
            }
        } else |err| {
            return err;
        }

        // For now, just support variable lookup
        // TODO: Add full expression parsing
        if (self.getVariable(expression)) |value| {
            return try value.clone(self.allocator);
        }

        // Try to parse as literal
        if (std.mem.eql(u8, expression, "true")) {
            return Value{ .boolean = true };
        }
        if (std.mem.eql(u8, expression, "false")) {
            return Value{ .boolean = false };
        }

        // Try to parse as string literal (basic)
        if (expression.len >= 2 and expression[0] == '"' and expression[expression.len - 1] == '"') {
            const str_content = expression[1 .. expression.len - 1];
            const str_copy = try self.allocator.dupe(u8, str_content);
            return Value{ .string = str_copy };
        }

        // Try to parse as single-quoted string literal
        if (expression.len >= 2 and expression[0] == '\'' and expression[expression.len - 1] == '\'') {
            const str_content = expression[1 .. expression.len - 1];
            const str_copy = try self.allocator.dupe(u8, str_content);
            return Value{ .string = str_copy };
        }

        // Try to parse as number
        if (std.fmt.parseFloat(f64, expression)) |num| {
            return Value{ .float64 = num };
        } else |_| {}

        if (std.fmt.parseInt(i64, expression, 10)) |num| {
            return Value{ .int64 = num };
        } else |_| {}

        return error.InvalidExpression;
    }

    /// Try to evaluate a function call expression like "func_name(arg1, arg2)"
    pub fn tryEvaluateFunctionCall(self: *ExpressionEngine, expression: []const u8) !?Value {
        if (self.functions == null) return null;

        // Look for function call pattern: name(args)
        var paren_start: ?usize = null;
        var paren_end: ?usize = null;
        var paren_count: usize = 0;

        for (expression, 0..) |char, i| {
            switch (char) {
                '(' => {
                    if (paren_start == null) paren_start = i;
                    paren_count += 1;
                },
                ')' => {
                    paren_count -= 1;
                    if (paren_count == 0) {
                        paren_end = i;
                        break;
                    }
                },
                else => {},
            }
        }

        if (paren_start == null or paren_end == null) return null;

        // Extract function name and arguments
        const func_name = std.mem.trim(u8, expression[0..paren_start.?], &std.ascii.whitespace);
        const args_str = expression[paren_start.? + 1 .. paren_end.?];

        // Get the function
        const function = self.functions.?.getFunction(func_name) orelse return null;

        // Parse arguments
        var args = try std.ArrayList(Value).initCapacity(self.allocator, 0);
        defer args.deinit(self.allocator);

        if (args_str.len > 0) {
            // Simple argument parsing (comma-separated)
            var arg_start: usize = 0;
            var in_string = false;
            var string_char: u8 = 0;
            var paren_depth: usize = 0;

            for (args_str, 0..) |char, i| {
                switch (char) {
                    '"', '\'' => {
                        if (!in_string) {
                            in_string = true;
                            string_char = char;
                        } else if (char == string_char) {
                            in_string = false;
                            string_char = 0;
                        }
                    },
                    '(' => {
                        if (!in_string) paren_depth += 1;
                    },
                    ')' => {
                        if (!in_string) paren_depth -= 1;
                    },
                    ',' => {
                        if (!in_string and paren_depth == 0) {
                            // End of argument
                            const arg_expr = std.mem.trim(u8, args_str[arg_start..i], &std.ascii.whitespace);
                            if (arg_expr.len > 0) {
                                const arg_value = try self.evaluate(arg_expr);
                                try args.append(self.allocator, arg_value);
                            }
                            arg_start = i + 1;
                        }
                    },
                    else => {},
                }
            }

            // Last argument
            const last_arg = std.mem.trim(u8, args_str[arg_start..], &std.ascii.whitespace);
            if (last_arg.len > 0) {
                const arg_value = try self.evaluate(last_arg);
                try args.append(self.allocator, arg_value);
            }
        }

        // Execute the function
        const result = try function.execute(args.items, self);
        return result;
    }

    /// Evaluate a conditional expression
    pub fn evaluateIf(self: *ExpressionEngine, condition: []const u8, then_expr: []const u8, else_expr: []const u8) !Value {
        const cond_value = try self.evaluate(condition);
        defer cond_value.deinit(self.allocator);
        const condition_result = switch (cond_value) {
            .boolean => |b| b,
            .integer => |i| i != 0,
            .float => |f| f != 0.0,
            .string => |s| s.len > 0,
            else => false,
        };

        if (condition_result) {
            return self.evaluate(then_expr);
        } else {
            return self.evaluate(else_expr);
        }
    }

    /// Evaluate a template string with variable substitution
    pub fn evaluateTemplate(self: *ExpressionEngine, template: []const u8) ![]const u8 {
        var result = try std.ArrayList(u8).initCapacity(self.allocator, template.len);
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < template.len) {
            if (template[i] == '{') {
                // Find the closing }
                var j = i + 1;
                while (j < template.len and template[j] != '}') {
                    j += 1;
                }
                if (j < template.len) {
                    // Extract variable name
                    const var_name = template[i + 1 .. j];
                    const value = try self.evaluate(var_name);

                    // Convert value to string and append
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
                    @constCast(&value).deinit(self.allocator);

                    i = j + 1;
                    continue;
                }
            }

            try result.append(self.allocator, template[i]);
            i += 1;
        }

        return result.toOwnedSlice(self.allocator);
    }
};

/// Expression AST node types
pub const ExprNode = union(enum) {
    variable: []const u8,
    literal: Value,
    binary_op: struct {
        left: *ExprNode,
        op: BinaryOp,
        right: *ExprNode,
    },
    if_expr: struct {
        condition: *ExprNode,
        then_branch: *ExprNode,
        else_branch: *ExprNode,
    },
    function_call: struct {
        name: []const u8,
        args: []ExprNode,
    },

    pub fn deinit(self: *ExprNode, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .variable => |v| allocator.free(v),
            .literal => |*l| l.deinit(allocator),
            .binary_op => |*b| {
                b.left.deinit(allocator);
                allocator.destroy(b.left);
                b.right.deinit(allocator);
                allocator.destroy(b.right);
            },
            .if_expr => |*i| {
                i.condition.deinit(allocator);
                allocator.destroy(i.condition);
                i.then_branch.deinit(allocator);
                allocator.destroy(i.then_branch);
                i.else_branch.deinit(allocator);
                allocator.destroy(i.else_branch);
            },
            .function_call => |*f| {
                allocator.free(f.name);
                for (f.args) |*arg| {
                    arg.deinit(allocator);
                }
                allocator.free(f.args);
            },
        }
    }
};

pub const BinaryOp = enum {
    add,
    subtract,
    multiply,
    divide,
    equal,
    not_equal,
    less,
    less_equal,
    greater,
    greater_equal,
    @"and",
    @"or",
};

/// Simple expression parser (basic implementation)
pub const ExpressionParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ExpressionParser {
        return ExpressionParser{ .allocator = allocator };
    }

    /// Parse a simple expression (for now just variables and literals)
    pub fn parse(self: *ExpressionParser, input: []const u8) !*ExprNode {
        // Trim whitespace
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

        // Try to parse as string literal
        if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
            const content = trimmed[1 .. trimmed.len - 1];
            const str_copy = try self.allocator.dupe(u8, content);
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .string = str_copy } };
            return node;
        }

        // Try to parse as boolean
        if (std.mem.eql(u8, trimmed, "true")) {
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .boolean = true } };
            return node;
        }
        if (std.mem.eql(u8, trimmed, "false")) {
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .boolean = false } };
            return node;
        }

        // Try to parse as number
        if (std.fmt.parseFloat(f64, trimmed)) |num| {
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .float64 = num } };
            return node;
        } else |_| {}

        if (std.fmt.parseInt(i64, trimmed, 10)) |num| {
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .int64 = num } };
            return node;
        } else |_| {}

        // Assume it's a variable
        const var_copy = try self.allocator.dupe(u8, trimmed);
        const node = try self.allocator.create(ExprNode);
        node.* = ExprNode{ .variable = var_copy };
        return node;
    }
};

test "ExpressionEngine basic functionality" {
    var engine = ExpressionEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Test variable setting and getting
    try engine.setVariable("test_var", Value{ .int64 = 42 });
    const value = engine.getVariable("test_var").?;
    try std.testing.expectEqual(@as(i64, 42), value.int64);

    // Test evaluation
    const result = try engine.evaluate("test_var");
    try std.testing.expectEqual(@as(i64, 42), result.int64);
}

test "ExpressionEngine template evaluation" {
    var engine = ExpressionEngine.init(std.testing.allocator);
    defer engine.deinit();

    try engine.setVariable("active_only", Value{ .boolean = true });

    const template = "SELECT * FROM users WHERE active = {active_only}";
    const result = try engine.evaluateTemplate(template);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("SELECT * FROM users WHERE active = true", result);
}

test "ExpressionParser basic parsing" {
    var parser = ExpressionParser.init(std.testing.allocator);

    // Test string literal
    const node1 = try parser.parse("\"hello world\"");
    defer {
        node1.deinit(std.testing.allocator);
        std.testing.allocator.destroy(node1);
    }
    try std.testing.expectEqualStrings("hello world", node1.literal.string);

    // Test variable
    const node2 = try parser.parse("my_variable");
    defer {
        node2.deinit(std.testing.allocator);
        std.testing.allocator.destroy(node2);
    }
    try std.testing.expectEqualStrings("my_variable", node2.variable);
}
