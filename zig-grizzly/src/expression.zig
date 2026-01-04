const std = @import("std");
const types = @import("types.zig");
const function_mod = @import("function.zig");
const pattern_mod = @import("pattern.zig");
pub const Value = types.Value;
const FunctionRegistry = function_mod.FunctionRegistry;
const MatchCase = pattern_mod.MatchCase;

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
    pub fn evaluate(self: *ExpressionEngine, expression: []const u8) (std.mem.Allocator.Error || std.fmt.ParseIntError || error{ InvalidExpression, UndefinedVariable, InvalidArgumentCount, InvalidArgumentType, NoPatternMatched, InvalidPipeTarget, UnknownFunction, InvalidOperandTypes, DivisionByZero, InvalidMethodCall, UnmatchedBrace })!Value {
        // First try to parse as a complex expression
        var parser = ExpressionParser.init(self.allocator);
        if (parser.parseComplexExpression(expression)) |node| {
            defer {
                node.deinit(self.allocator);
                self.allocator.destroy(node);
            }
            return try self.evaluateNode(node);
        } else |_| {
            // Fall back to simple evaluation
        }

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

    /// Evaluate a pipe chain (left |> right)
    pub fn evaluatePipeChain(self: *ExpressionEngine, left: *ExprNode, right: *ExprNode) !Value {
        // Evaluate left side
        const left_value = try self.evaluateNode(left);
        errdefer @constCast(&left_value).deinit(self.allocator);

        // For pipe chains, the right side should be a function call
        // The left value becomes the first argument to the right function
        switch (right.*) {
            .function_call => |*fc| {
                // Create new args array with left_value as first arg
                var new_args = try std.ArrayList(Value).initCapacity(self.allocator, fc.args.len + 1);
                defer new_args.deinit(self.allocator);

                // Clone left value for the function call
                const left_clone = try left_value.clone(self.allocator);
                try new_args.append(self.allocator, left_clone);

                // Evaluate remaining args
                for (fc.args) |*arg| {
                    const arg_value = try self.evaluateNode(arg);
                    try new_args.append(self.allocator, arg_value);
                }

                // Call the function
                if (self.functions) |funcs| {
                    if (funcs.getFunction(fc.name)) |func| {
                        return try func.execute(new_args.items, self);
                    }
                }

                // If not a registered function, try built-in functions
                return try self.callBuiltinFunction(fc.name, new_args.items);
            },
            .method_call => |*mc| {
                // Method calls in pipes: left |> [receiver] method(args)
                // This becomes: method(left, receiver, args...)
                var new_args = try std.ArrayList(Value).initCapacity(self.allocator, mc.args.len + 2);
                defer new_args.deinit(self.allocator);

                // Clone left value
                const left_clone = try left_value.clone(self.allocator);
                try new_args.append(self.allocator, left_clone);

                // Evaluate receiver
                const receiver_value = try self.evaluateNode(mc.receiver);
                try new_args.append(self.allocator, receiver_value);

                // Evaluate remaining args
                for (mc.args) |*arg| {
                    const arg_value = try self.evaluateNode(arg);
                    try new_args.append(self.allocator, arg_value);
                }

                // Call as method
                return try self.callBuiltinFunction(mc.method, new_args.items);
            },
            else => return error.InvalidPipeTarget,
        }
    }

    /// Evaluate a method call [receiver] method(args)
    pub fn evaluateMethodCall(self: *ExpressionEngine, receiver: *ExprNode, method: []const u8, args: []ExprNode) !Value {
        // Evaluate receiver
        const receiver_value = try self.evaluateNode(receiver);
        errdefer @constCast(&receiver_value).deinit(self.allocator);

        // Create args array with receiver as first arg
        var method_args = try std.ArrayList(Value).initCapacity(self.allocator, args.len + 1);
        defer method_args.deinit(self.allocator);

        // Clone receiver value
        const receiver_clone = try receiver_value.clone(self.allocator);
        try method_args.append(self.allocator, receiver_clone);

        // Evaluate remaining args
        for (args) |*arg| {
            const arg_value = try self.evaluateNode(arg);
            try method_args.append(self.allocator, arg_value);
        }

        // Call as method
        return try self.callBuiltinFunction(method, method_args.items);
    }

    /// Call a built-in function
    pub fn callBuiltinFunction(self: *ExpressionEngine, name: []const u8, args: []const Value) !Value {
        if (std.mem.eql(u8, name, "filter")) {
            return try self.builtinFilter(args);
        } else if (std.mem.eql(u8, name, "map")) {
            return try self.builtinMap(args);
        } else if (std.mem.eql(u8, name, "sum")) {
            return try self.builtinSum(args);
        } else if (std.mem.eql(u8, name, "length")) {
            return try self.builtinLength(args);
        }

        return error.UnknownFunction;
    }

    /// Built-in filter function: filter(array, predicate_func)
    fn builtinFilter(self: *ExpressionEngine, args: []const Value) !Value {
        if (args.len != 2) return error.InvalidArgumentCount;

        // For now, return the first argument unchanged
        // TODO: Implement actual filtering logic
        return try args[0].clone(self.allocator);
    }

    /// Built-in map function: map(array, transform_func)
    fn builtinMap(self: *ExpressionEngine, args: []const Value) !Value {
        if (args.len != 2) return error.InvalidArgumentCount;

        // For now, return the first argument unchanged
        // TODO: Implement actual mapping logic
        return try args[0].clone(self.allocator);
    }

    /// Built-in sum function: sum(array)
    fn builtinSum(_: *ExpressionEngine, args: []const Value) !Value {
        if (args.len != 1) return error.InvalidArgumentCount;

        // For now, return 0
        // TODO: Implement actual sum logic
        return Value{ .int64 = 0 };
    }

    /// Built-in length function: length(array)
    fn builtinLength(_: *ExpressionEngine, args: []const Value) !Value {
        if (args.len != 1) return error.InvalidArgumentCount;

        // For now, return 0
        // TODO: Implement actual length logic
        return Value{ .int64 = 0 };
    }

    /// Evaluate an AST node
    pub fn evaluateNode(self: *ExpressionEngine, node: *ExprNode) (std.mem.Allocator.Error || std.fmt.ParseIntError || error{ InvalidExpression, UndefinedVariable, InvalidArgumentCount, InvalidArgumentType, NoPatternMatched, InvalidPipeTarget, UnknownFunction, InvalidOperandTypes, DivisionByZero, InvalidMethodCall, UnmatchedBrace })!Value {
        switch (node.*) {
            .variable => |name| {
                if (self.getVariable(name)) |value| {
                    return try value.clone(self.allocator);
                }
                return error.UndefinedVariable;
            },
            .literal => |*lit| return try lit.clone(self.allocator),
            .binary_op => |*bop| {
                const left_val = try self.evaluateNode(bop.left);
                errdefer @constCast(&left_val).deinit(self.allocator);
                const right_val = try self.evaluateNode(bop.right);
                errdefer @constCast(&right_val).deinit(self.allocator);

                const result = try self.evaluateBinaryOp(left_val, right_val, bop.op);
                @constCast(&left_val).deinit(self.allocator);
                @constCast(&right_val).deinit(self.allocator);
                return result;
            },
            .if_expr => |*ife| {
                const cond = try self.evaluateNode(ife.condition);
                defer @constCast(&cond).deinit(self.allocator);
                const result = switch (cond) {
                    .boolean => |b| b,
                    .int64 => |i| i != 0,
                    .float64 => |f| f != 0.0,
                    .string => |s| s.len > 0,
                    else => false,
                };
                if (result) {
                    return try self.evaluateNode(ife.then_branch);
                } else {
                    return try self.evaluateNode(ife.else_branch);
                }
            },
            .function_call => |*fc| {
                // Evaluate arguments
                var arg_values = try std.ArrayList(Value).initCapacity(self.allocator, fc.args.len);
                defer arg_values.deinit(self.allocator);

                for (fc.args) |*arg| {
                    const value = try self.evaluateNode(arg);
                    try arg_values.append(self.allocator, value);
                }

                // Try user-defined functions first
                if (self.functions) |funcs| {
                    if (funcs.getFunction(fc.name)) |func| {
                        return try func.execute(arg_values.items, self);
                    }
                }

                // Try built-in functions
                return try self.callBuiltinFunction(fc.name, arg_values.items);
            },
            .pipe_chain => |*pc| {
                return try self.evaluatePipeChain(pc.left, pc.right);
            },
            .method_call => |*mc| {
                return try self.evaluateMethodCall(mc.receiver, mc.method, mc.args);
            },
            .try_expr => |*t| {
                // Try to evaluate the try body
                const result = self.evaluateNode(t.try_body) catch {
                    // If it fails, evaluate the catch body
                    return try self.evaluateNode(t.catch_body);
                };
                return result;
            },
            .match_expr => |*m| {
                const value = try self.evaluateNode(m.value);
                errdefer @constCast(&value).deinit(self.allocator);

                var matcher = pattern_mod.PatternMatcher.init(self.allocator);
                const result = try matcher.evaluateMatch(value, m.cases, self);
                @constCast(&value).deinit(self.allocator);
                return result;
            },
        }
    }

    /// Evaluate a binary operation
    pub fn evaluateBinaryOp(self: *ExpressionEngine, left: Value, right: Value, op: BinaryOp) !Value {
        return switch (op) {
            .add => try addValues(left, right, self.allocator),
            .subtract => try subtractValues(left, right, self.allocator),
            .multiply => try multiplyValues(left, right, self.allocator),
            .divide => try divideValues(left, right, self.allocator),
            .equal => Value{ .boolean = valuesEqual(left, right) },
            .not_equal => Value{ .boolean = !valuesEqual(left, right) },
            .less => Value{ .boolean = try compareValues(left, right) == .lt },
            .less_equal => {
                const cmp = try compareValues(left, right);
                return Value{ .boolean = cmp == .lt or cmp == .eq };
            },
            .greater => Value{ .boolean = try compareValues(left, right) == .gt },
            .greater_equal => {
                const cmp = try compareValues(left, right);
                return Value{ .boolean = cmp == .gt or cmp == .eq };
            },
            .@"and" => {
                if (left != .boolean or right != .boolean) return error.InvalidOperandTypes;
                return Value{ .boolean = left.boolean and right.boolean };
            },
            .@"or" => {
                if (left != .boolean or right != .boolean) return error.InvalidOperandTypes;
                return Value{ .boolean = left.boolean or right.boolean };
            },
        };
    }
};

/// Helper functions for binary operations
/// Add two values
fn addValues(left: Value, right: Value, allocator: std.mem.Allocator) !Value {
    if (left == .int64 and right == .int64) {
        return Value{ .int64 = left.int64 + right.int64 };
    }
    if (left == .float64 and right == .float64) {
        return Value{ .float64 = left.float64 + right.float64 };
    }
    if (left == .int64 and right == .float64) {
        const left_f: f64 = @floatFromInt(left.int64);
        return Value{ .float64 = left_f + right.float64 };
    }
    if (left == .float64 and right == .int64) {
        const right_f: f64 = @floatFromInt(right.int64);
        return Value{ .float64 = left.float64 + right_f };
    }
    if (left == .string and right == .string) {
        const concatenated = try std.fmt.allocPrint(allocator, "{s}{s}", .{ left.string, right.string });
        return Value{ .string = concatenated };
    }
    return error.InvalidOperandTypes;
}

/// Subtract two values
fn subtractValues(left: Value, right: Value, _: std.mem.Allocator) !Value {
    if (left == .int64 and right == .int64) {
        return Value{ .int64 = left.int64 - right.int64 };
    }
    if (left == .float64 and right == .float64) {
        return Value{ .float64 = left.float64 - right.float64 };
    }
    if (left == .int64 and right == .float64) {
        const left_f: f64 = @floatFromInt(left.int64);
        return Value{ .float64 = left_f - right.float64 };
    }
    if (left == .float64 and right == .int64) {
        const right_f: f64 = @floatFromInt(right.int64);
        return Value{ .float64 = left.float64 - right_f };
    }
    return error.InvalidOperandTypes;
}

/// Multiply two values
fn multiplyValues(left: Value, right: Value, _: std.mem.Allocator) !Value {
    if (left == .int64 and right == .int64) {
        return Value{ .int64 = left.int64 * right.int64 };
    }
    if (left == .float64 and right == .float64) {
        return Value{ .float64 = left.float64 * right.float64 };
    }
    if (left == .int64 and right == .float64) {
        const left_f: f64 = @floatFromInt(left.int64);
        return Value{ .float64 = left_f * right.float64 };
    }
    if (left == .float64 and right == .int64) {
        const right_f: f64 = @floatFromInt(right.int64);
        return Value{ .float64 = left.float64 * right_f };
    }
    return error.InvalidOperandTypes;
}

/// Divide two values
fn divideValues(left: Value, right: Value, _: std.mem.Allocator) !Value {
    if (left == .int64 and right == .int64) {
        if (right.int64 == 0) return error.DivisionByZero;
        return Value{ .int64 = @divTrunc(left.int64, right.int64) };
    }
    if (left == .float64 and right == .float64) {
        if (right.float64 == 0.0) return error.DivisionByZero;
        return Value{ .float64 = left.float64 / right.float64 };
    }
    if (left == .int64 and right == .float64) {
        if (right.float64 == 0.0) return error.DivisionByZero;
        const left_f: f64 = @floatFromInt(left.int64);
        return Value{ .float64 = left_f / right.float64 };
    }
    if (left == .float64 and right == .int64) {
        if (right.int64 == 0) return error.DivisionByZero;
        const right_f: f64 = @floatFromInt(right.int64);
        return Value{ .float64 = left.float64 / right_f };
    }
    return error.InvalidOperandTypes;
}

/// Compare two values
fn compareValues(left: Value, right: Value) !std.math.Order {
    if (left == .int64 and right == .int64) {
        return std.math.order(left.int64, right.int64);
    }
    if (left == .float64 and right == .float64) {
        return std.math.order(left.float64, right.float64);
    }
    if (left == .int64 and right == .float64) {
        const left_f: f64 = @floatFromInt(left.int64);
        return std.math.order(left_f, right.float64);
    }
    if (left == .float64 and right == .int64) {
        const right_f: f64 = @floatFromInt(right.int64);
        return std.math.order(left.float64, right_f);
    }
    if (left == .string and right == .string) {
        return std.mem.order(u8, left.string, right.string);
    }
    return error.InvalidOperandTypes;
}

/// Check if two values are equal
fn valuesEqual(a: Value, b: Value) bool {
    if (@as(std.meta.Tag(Value), a) != @as(std.meta.Tag(Value), b)) return false;

    return switch (a) {
        .int32 => |v| v == b.int32,
        .int64 => |v| v == b.int64,
        .float32 => |v| v == b.float32,
        .float64 => |v| v == b.float64,
        .boolean => |v| v == b.boolean,
        .string => |s| std.mem.eql(u8, s, b.string),
        .timestamp => |t| t == b.timestamp,
        .vector => |vec| {
            if (vec.len() != b.vector.len()) return false;
            for (vec.values, b.vector.values) |av, bv| {
                if (av != bv) return false;
            }
            return true;
        },
        .custom => |cv| {
            // For now, custom values are compared by their type only
            return @as(std.meta.Tag(@import("types_custom.zig").CustomValue), cv) == @as(std.meta.Tag(@import("types_custom.zig").CustomValue), b.custom);
        },
        .exception => |ev| {
            const bev = b.exception;
            return std.mem.eql(u8, ev.type_name, bev.type_name) and std.mem.eql(u8, ev.message, bev.message);
        },
    };
}

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
    pipe_chain: struct {
        left: *ExprNode,
        right: *ExprNode,
    },
    method_call: struct {
        receiver: *ExprNode,
        method: []const u8,
        args: []ExprNode,
    },
    try_expr: struct {
        try_body: *ExprNode,
        catch_body: *ExprNode,
    },
    match_expr: struct {
        value: *ExprNode,
        cases: []MatchCase,
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
            .pipe_chain => |*p| {
                p.left.deinit(allocator);
                allocator.destroy(p.left);
                p.right.deinit(allocator);
                allocator.destroy(p.right);
            },
            .method_call => |*m| {
                m.receiver.deinit(allocator);
                allocator.destroy(m.receiver);
                allocator.free(m.method);
                for (m.args) |*arg| {
                    arg.deinit(allocator);
                }
                allocator.free(m.args);
            },
            .try_expr => |*t| {
                t.try_body.deinit(allocator);
                allocator.destroy(t.try_body);
                t.catch_body.deinit(allocator);
                allocator.destroy(t.catch_body);
            },
            .match_expr => |*m| {
                m.value.deinit(allocator);
                allocator.destroy(m.value);
                for (m.cases) |*case_| {
                    case_.deinit(allocator);
                }
                allocator.free(m.cases);
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

    /// Parse a complex expression with pipes, method calls, and binary operations
    pub fn parseComplexExpression(self: *ExpressionParser, input: []const u8) !*ExprNode {
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

        // Check for try/catch syntax: try expr catch expr
        if (std.mem.startsWith(u8, trimmed, "try ")) {
            // Find the catch keyword
            if (std.mem.indexOf(u8, trimmed, " catch ")) |catch_pos| {
                const try_part = std.mem.trim(u8, trimmed[4..catch_pos], &std.ascii.whitespace);
                const catch_part = std.mem.trim(u8, trimmed[catch_pos + 7 ..], &std.ascii.whitespace);

                const try_expr = try self.parseComplexExpression(try_part);
                const catch_expr = try self.parseComplexExpression(catch_part);

                const try_node = try self.allocator.create(ExprNode);
                try_node.* = ExprNode{ .try_expr = .{
                    .try_body = try_expr,
                    .catch_body = catch_expr,
                } };
                return try_node;
            }
        }

        // Check for match syntax: match value { pattern1 => expr1, pattern2 => expr2 }
        if (std.mem.startsWith(u8, trimmed, "match ")) {
            // Find the opening brace
            if (std.mem.indexOf(u8, trimmed, " {")) |brace_pos| {
                const value_part = std.mem.trim(u8, trimmed[6..brace_pos], &std.ascii.whitespace);
                const cases_part = std.mem.trim(u8, trimmed[brace_pos + 2 .. trimmed.len - 1], &std.ascii.whitespace); // Remove { and }

                const value_expr = try self.parseComplexExpression(value_part);

                // Parse cases
                var cases = try std.ArrayList(MatchCase).initCapacity(self.allocator, 0);
                defer cases.deinit(self.allocator);

                var case_start: usize = 0;
                var i: usize = 0;
                var brace_depth: usize = 0;

                while (i < cases_part.len) {
                    const char = cases_part[i];
                    if (char == '{') {
                        brace_depth += 1;
                    } else if (char == '}') {
                        brace_depth -= 1;
                    } else if (char == ',' and brace_depth == 0) {
                        const case_str = std.mem.trim(u8, cases_part[case_start..i], &std.ascii.whitespace);
                        if (case_str.len > 0) {
                            try self.parseMatchCase(case_str, &cases);
                        }
                        case_start = i + 1;
                    }
                    i += 1;
                }

                // Last case
                const last_case = std.mem.trim(u8, cases_part[case_start..], &std.ascii.whitespace);
                if (last_case.len > 0) {
                    try self.parseMatchCase(last_case, &cases);
                }

                const match_node = try self.allocator.create(ExprNode);
                match_node.* = ExprNode{ .match_expr = .{
                    .value = value_expr,
                    .cases = try cases.toOwnedSlice(self.allocator),
                } };
                return match_node;
            }
        }

        // Otherwise, parse binary operations
        return self.parseBinaryExpression(input);
    }

    /// Parse binary expressions with operator precedence
    fn parseBinaryExpression(self: *ExpressionParser, input: []const u8) !*ExprNode {
        return self.parseBinaryExpressionWithPrecedence(input, 0);
    }

    /// Parse binary expression with precedence handling
    fn parseBinaryExpressionWithPrecedence(self: *ExpressionParser, input: []const u8, min_precedence: u8) !*ExprNode {
        // Parse left operand (any expression with higher precedence)
        const left_result = try self.parsePipeOrMethodCall(input);
        const left = left_result.node;

        // Continue parsing from where left stopped
        const remaining = input[left_result.consumed..];
        var pos: usize = 0;

        // Skip whitespace after the left expression
        while (pos < remaining.len) {
            const char = remaining[pos];
            if (char == ' ' or char == '\t' or char == '\n') {
                pos += 1;
                continue;
            }
            break;
        }

        // Find the operator
        while (pos < remaining.len) {
            const op_start = pos;
            const op = self.getBinaryOperator(remaining[op_start..]);
            if (op == null) {
                pos += 1;
                continue;
            }

            const precedence = self.getPrecedence(op.?);
            if (precedence <= min_precedence) {
                pos += self.getOperatorLength(op.?);
                continue;
            }

            // Found an operator with higher precedence
            const op_len = self.getOperatorLength(op.?);
            const right_start = op_start + op_len;

            // Parse right operand
            const right = try self.parseBinaryExpressionWithPrecedence(remaining[right_start..], precedence);

            // Create binary operation
            const bin_node = try self.allocator.create(ExprNode);
            bin_node.* = ExprNode{ .binary_op = .{
                .left = left,
                .op = op.?,
                .right = right,
            } };

            return bin_node;
        }

        return left;
    }

    const ParseResult = struct {
        node: *ExprNode,
        consumed: usize,
    };

    /// Parse pipe chains and method calls (stops at binary operators)
    fn parsePipeOrMethodCall(self: *ExpressionParser, input: []const u8) !ParseResult {
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

        // Find where this expression ends (at binary operators, ignoring parentheses/braces)
        var end_pos: usize = trimmed.len;
        var paren_depth: usize = 0;
        var brace_depth: usize = 0;
        var in_string = false;
        var string_char: u8 = 0;

        for (trimmed, 0..) |char, i| {
            if (!in_string) {
                if (char == '"' or char == '\'') {
                    in_string = true;
                    string_char = char;
                } else if (char == '(') {
                    paren_depth += 1;
                } else if (char == ')') {
                    paren_depth -= 1;
                } else if (char == '{') {
                    brace_depth += 1;
                } else if (char == '}') {
                    brace_depth -= 1;
                } else if (paren_depth == 0 and brace_depth == 0) {
                    const op = self.getBinaryOperator(trimmed[i..]);
                    if (op != null) {
                        end_pos = i;
                        break;
                    }
                }
            } else if (char == string_char) {
                in_string = false;
                string_char = 0;
            }
        }

        const expr_to_parse = trimmed[0..end_pos];

        // Now parse pipes and method calls within expr_to_parse
        var parts = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
        defer parts.deinit(self.allocator);

        // Split by pipe operators (|>) while respecting parentheses and strings
        var start: usize = 0;
        var pipe_paren_depth: usize = 0;
        var pipe_brace_depth: usize = 0;
        var pipe_in_string = false;
        var pipe_string_char: u8 = 0;

        for (expr_to_parse, 0..) |char, i| {
            if (!pipe_in_string) {
                if (char == '"' or char == '\'') {
                    pipe_in_string = true;
                    pipe_string_char = char;
                } else if (char == '(') {
                    pipe_paren_depth += 1;
                } else if (char == ')') {
                    pipe_paren_depth -= 1;
                } else if (char == '{') {
                    pipe_brace_depth += 1;
                } else if (char == '}') {
                    pipe_brace_depth -= 1;
                } else if (pipe_paren_depth == 0 and pipe_brace_depth == 0 and i + 1 < expr_to_parse.len and std.mem.eql(u8, expr_to_parse[i .. i + 2], "|>")) {
                    // Found pipe operator
                    const part = std.mem.trim(u8, expr_to_parse[start..i], &std.ascii.whitespace);
                    if (part.len > 0) {
                        try parts.append(self.allocator, part);
                    }
                    start = i + 2;
                }
            } else if (char == pipe_string_char) {
                pipe_in_string = false;
                pipe_string_char = 0;
            }
        }

        // Add the last part
        const last_part = std.mem.trim(u8, expr_to_parse[start..], &std.ascii.whitespace);
        if (last_part.len > 0) {
            try parts.append(self.allocator, last_part);
        }

        if (parts.items.len == 0) {
            return error.EmptyExpression;
        }

        // If only one part, parse it directly
        if (parts.items.len == 1) {
            const node = try self.parse(parts.items[0]);
            return ParseResult{ .node = node, .consumed = end_pos };
        }

        // Build pipe chain
        var current = try self.parse(parts.items[0]);
        for (parts.items[1..]) |part| {
            // Parse method call: obj.method(args...)
            if (std.mem.indexOf(u8, part, "(")) |paren_pos| {
                const method_name = std.mem.trim(u8, part[0..paren_pos], &std.ascii.whitespace);
                const args_str = part[paren_pos..];

                // Parse arguments
                var args = try std.ArrayList(*ExprNode).initCapacity(self.allocator, 0);
                defer args.deinit(self.allocator);

                if (args_str.len > 2) { // More than just ()
                    const args_content = args_str[1 .. args_str.len - 1]; // Remove ()
                    var arg_parts = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
                    defer arg_parts.deinit(self.allocator);

                    // Split arguments by comma, respecting parentheses and strings
                    var arg_start: usize = 0;
                    var arg_paren_depth: usize = 0;
                    var arg_brace_depth: usize = 0;
                    var arg_in_string = false;
                    var arg_string_char: u8 = 0;

                    for (args_content, 0..) |arg_char, arg_i| {
                        if (!arg_in_string) {
                            if (arg_char == '"' or arg_char == '\'') {
                                arg_in_string = true;
                                arg_string_char = arg_char;
                            } else if (arg_char == '(') {
                                arg_paren_depth += 1;
                            } else if (arg_char == ')') {
                                arg_paren_depth -= 1;
                            } else if (arg_char == '{') {
                                arg_brace_depth += 1;
                            } else if (arg_char == '}') {
                                arg_brace_depth -= 1;
                            } else if (arg_paren_depth == 0 and arg_brace_depth == 0 and arg_char == ',') {
                                const arg_part = std.mem.trim(u8, args_content[arg_start..arg_i], &std.ascii.whitespace);
                                if (arg_part.len > 0) {
                                    try arg_parts.append(self.allocator, arg_part);
                                }
                                arg_start = arg_i + 1;
                            }
                        } else if (arg_char == arg_string_char) {
                            arg_in_string = false;
                            arg_string_char = 0;
                        }
                    }

                    // Add last argument
                    const last_arg = std.mem.trim(u8, args_content[arg_start..], &std.ascii.whitespace);
                    if (last_arg.len > 0) {
                        try arg_parts.append(self.allocator, last_arg);
                    }

                    // Parse each argument
                    for (arg_parts.items) |arg_str| {
                        const arg_expr = try self.parse(arg_str);
                        try args.append(self.allocator, arg_expr);
                    }
                }

                // Create method call node
                const method_name_copy = try self.allocator.dupe(u8, method_name);
                const method_args = try self.allocator.alloc(ExprNode, args.items.len);
                for (args.items, 0..) |arg_ptr, i| {
                    method_args[i] = arg_ptr.*;
                }
                const method_node = try self.allocator.create(ExprNode);
                method_node.* = ExprNode{ .method_call = .{
                    .receiver = current,
                    .method = method_name_copy,
                    .args = method_args,
                } };
                current = method_node;
            } else {
                return error.InvalidPipeSyntax;
            }
        }

        return ParseResult{ .node = current, .consumed = end_pos };
    }

    /// Parse a single match case: pattern => expression
    fn parseMatchCase(self: *ExpressionParser, case_str: []const u8, cases: *std.ArrayList(MatchCase)) !void {
        if (std.mem.indexOf(u8, case_str, " => ")) |arrow_pos| {
            const pattern_str = std.mem.trim(u8, case_str[0..arrow_pos], &std.ascii.whitespace);
            const expr_str = std.mem.trim(u8, case_str[arrow_pos + 4 ..], &std.ascii.whitespace);

            const pattern = try self.parsePattern(pattern_str);
            const match_case = try MatchCase.init(self.allocator, pattern, expr_str);
            try cases.append(self.allocator, match_case);
        } else {
            return error.InvalidMatchCase;
        }
    }

    /// Parse a pattern for match expressions
    fn parsePattern(self: *ExpressionParser, pattern_str: []const u8) !pattern_mod.Pattern {
        const trimmed = std.mem.trim(u8, pattern_str, &std.ascii.whitespace);

        // Wildcard
        if (std.mem.eql(u8, trimmed, "_")) {
            return pattern_mod.Pattern.initWildcard();
        }

        // Variable (starts with lowercase letter)
        if (trimmed.len > 0 and std.ascii.isLower(trimmed[0])) {
            return try pattern_mod.Pattern.initVariable(self.allocator, trimmed);
        }

        // Try to parse as literal
        if (self.parse(trimmed)) |node| {
            defer self.allocator.destroy(node);

            if (node.* == .literal) {
                return try pattern_mod.Pattern.initLiteral(self.allocator, node.literal);
            }
        } else |_| {}

        return error.InvalidPattern;
    }

    /// Parse a method call: [receiver] method(args)
    fn parseMethodCall(self: *ExpressionParser, receiver: *ExprNode, method_call: []const u8) !*ExprNode {
        const trimmed = std.mem.trim(u8, method_call, &std.ascii.whitespace);

        // Find method name and arguments
        const paren_start = std.mem.indexOf(u8, trimmed, "(") orelse return error.InvalidMethodCall;
        const method_name = std.mem.trim(u8, trimmed[0..paren_start], &std.ascii.whitespace);
        const args_str = trimmed[paren_start + 1 .. trimmed.len - 1]; // Remove closing )

        // Parse arguments
        var args = try std.ArrayList(ExprNode).initCapacity(self.allocator, 0);
        defer args.deinit(self.allocator);

        if (args_str.len > 0) {
            var arg_start: usize = 0;
            var i: usize = 0;
            var paren_depth: usize = 0;
            var in_string = false;
            var string_char: u8 = 0;

            while (i < args_str.len) {
                const char = args_str[i];
                if (!in_string) {
                    if (char == '"' or char == '\'') {
                        in_string = true;
                        string_char = char;
                    } else if (char == '(') {
                        paren_depth += 1;
                    } else if (char == ')') {
                        paren_depth -= 1;
                    } else if (char == ',' and paren_depth == 0) {
                        const arg_expr = std.mem.trim(u8, args_str[arg_start..i], &std.ascii.whitespace);
                        if (arg_expr.len > 0) {
                            const arg_node = try self.parse(arg_expr);
                            defer arg_node.deinit(self.allocator);
                            defer self.allocator.destroy(arg_node);
                            try args.append(self.allocator, arg_node.*);
                        }
                        arg_start = i + 1;
                    }
                } else if (char == string_char) {
                    in_string = false;
                    string_char = 0;
                }
                i += 1;
            }

            // Last argument
            const last_arg = std.mem.trim(u8, args_str[arg_start..], &std.ascii.whitespace);
            if (last_arg.len > 0) {
                const arg_node = try self.parse(last_arg);
                defer arg_node.deinit(self.allocator);
                defer self.allocator.destroy(arg_node);
                try args.append(self.allocator, arg_node.*);
            }
        }

        const method_name_copy = try self.allocator.dupe(u8, method_name);
        const method_node = try self.allocator.create(ExprNode);
        method_node.* = ExprNode{ .method_call = .{
            .receiver = receiver,
            .method = method_name_copy,
            .args = try args.toOwnedSlice(self.allocator),
        } };

        return method_node;
    }

    /// Get binary operator from string
    fn getBinaryOperator(self: *ExpressionParser, input: []const u8) ?BinaryOp {
        _ = self; // unused
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
        if (std.mem.startsWith(u8, trimmed, "+")) return .add;
        if (std.mem.startsWith(u8, trimmed, "-")) return .subtract;
        if (std.mem.startsWith(u8, trimmed, "*")) return .multiply;
        if (std.mem.startsWith(u8, trimmed, "/")) return .divide;
        if (std.mem.startsWith(u8, trimmed, "==")) return .equal;
        if (std.mem.startsWith(u8, trimmed, "!=")) return .not_equal;
        if (std.mem.startsWith(u8, trimmed, "<=")) return .less_equal;
        if (std.mem.startsWith(u8, trimmed, "<")) return .less;
        if (std.mem.startsWith(u8, trimmed, ">=")) return .greater_equal;
        if (std.mem.startsWith(u8, trimmed, ">")) return .greater;
        if (std.mem.startsWith(u8, trimmed, "&&")) return .@"and";
        if (std.mem.startsWith(u8, trimmed, "||")) return .@"or";
        return null;
    }

    /// Get operator precedence (higher number = higher precedence)
    fn getPrecedence(self: *ExpressionParser, op: BinaryOp) u8 {
        _ = self; // unused
        return switch (op) {
            .@"or" => 1,
            .@"and" => 2,
            .equal, .not_equal => 3,
            .less, .less_equal, .greater, .greater_equal => 4,
            .add, .subtract => 5,
            .multiply, .divide => 6,
        };
    }

    /// Get operator string length
    fn getOperatorLength(self: *ExpressionParser, op: BinaryOp) usize {
        _ = self; // unused
        return switch (op) {
            .add, .subtract, .multiply, .divide, .less, .greater => 1,
            .equal, .not_equal, .less_equal, .greater_equal, .@"and", .@"or" => 2,
        };
    }

    /// Parse a simple expression (for now just variables and literals)
    pub fn parse(self: *ExpressionParser, input: []const u8) !*ExprNode {
        // Trim whitespace
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

        // Try to parse as string literal
        // Try to parse as string literal

        // Try to parse as string literal
        if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
            const content = trimmed[1 .. trimmed.len - 1];
            const str_copy = try self.allocator.dupe(u8, content);
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .string = str_copy } };
            return node;
        }

        // Try to parse as single-quoted string literal
        if (trimmed.len >= 2 and trimmed[0] == '\'' and trimmed[trimmed.len - 1] == '\'') {
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

        // Try to parse as number (int first, then float)
        if (std.fmt.parseInt(i64, trimmed, 10)) |num| {
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .int64 = num } };
            return node;
        } else |_| {}

        if (std.fmt.parseFloat(f64, trimmed)) |num| {
            const node = try self.allocator.create(ExprNode);
            node.* = ExprNode{ .literal = Value{ .float64 = num } };
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

test "ExpressionEngine binary operations" {
    var engine = ExpressionEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Test simple literal parsing first
    const result0 = try engine.evaluate("5");
    try std.testing.expectEqual(@as(i64, 5), result0.int64);

    // Test addition
    const result1 = try engine.evaluate("5 + 3");
    try std.testing.expectEqual(@as(i64, 8), result1.int64);

    // Test mixed types
    const result2 = try engine.evaluate("5 + 3.5");
    try std.testing.expectEqual(@as(f64, 8.5), result2.float64);

    // Test comparison
    const result3 = try engine.evaluate("10 > 5");
    try std.testing.expect(result3.boolean);

    // Test logical operations
    const result4 = try engine.evaluate("true && false");
    try std.testing.expect(!result4.boolean);
}

test "ExpressionEngine try/catch operations" {
    var engine = ExpressionEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Test try/catch with successful expression
    const result1 = try engine.evaluate("try 5 + 3 catch 0");
    try std.testing.expectEqual(@as(i64, 8), result1.int64);

    // Test try/catch with error in try block (division by zero)
    // For now, since we don't have division, test with undefined variable
    const result2 = try engine.evaluate("try undefined_var catch 42");
    try std.testing.expectEqual(@as(i64, 42), result2.int64);
}

test "ExpressionEngine pipe operations" {
    var engine = ExpressionEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Set up some test data
    try engine.setVariable("x", Value{ .int64 = 10 });

    // Test pipe with built-in function (if implemented)
    // For now, just test that parsing doesn't crash
    const result = try engine.evaluate("x");
    try std.testing.expectEqual(@as(i64, 10), result.int64);
}
