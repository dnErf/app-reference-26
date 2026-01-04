const std = @import("std");
const types = @import("types.zig");

const Value = types.Value;
const DataType = types.DataType;

/// ANSI SQL compliant WHERE clause evaluation
/// Supports: =, !=, <>, <, >, <=, >=, AND, OR, NOT, IS NULL, IS NOT NULL, LIKE, BETWEEN, IN
/// Expression types for WHERE clause
pub const ExprType = enum {
    // Comparison operators
    equal, // =
    not_equal, // != or <>
    less_than, // <
    greater_than, // >
    less_equal, // <=
    greater_equal, // >=

    // Logical operators
    and_op, // AND
    or_op, // OR
    not_op, // NOT

    // NULL checks
    is_null, // IS NULL
    is_not_null, // IS NOT NULL

    // Pattern matching
    like, // LIKE
    not_like, // NOT LIKE

    // Range and set
    between, // BETWEEN ... AND ...
    in, // IN (...)
    not_in, // NOT IN (...)

    // Vector search
    vector_search, // VECTOR_SEARCH(column, query_vector, k)

    // Literals and references
    literal,
    column_ref,
};

/// Expression node in WHERE clause AST
pub const Expr = struct {
    type: ExprType,
    value: ?Value = null, // For literals
    column_name: ?[]const u8 = null, // For column references
    left: ?*Expr = null, // For binary operators
    right: ?*Expr = null, // For binary operators
    operand: ?*Expr = null, // For unary operators (NOT, IS NULL, etc.)
    values: ?[]Value = null, // For IN operator

    // Vector search parameters
    vector_column: ?[]const u8 = null, // Column name for vector search
    query_vector: ?[]const f32 = null, // Query vector for search
    k: ?usize = null, // Number of nearest neighbors

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, expr_type: ExprType) !*Expr {
        const expr = try allocator.create(Expr);
        expr.* = .{
            .type = expr_type,
            .allocator = allocator,
        };
        return expr;
    }

    pub fn deinit(self: *Expr) void {
        if (self.left) |left| left.deinit();
        if (self.right) |right| right.deinit();
        if (self.operand) |operand| operand.deinit();
        if (self.values) |vals| self.allocator.free(vals);
        if (self.query_vector) |vec| self.allocator.free(vec);
        self.allocator.destroy(self);
    }

    /// Create a literal expression
    pub fn literal(allocator: std.mem.Allocator, val: Value) !*Expr {
        const expr = try init(allocator, .literal);
        expr.value = val;
        return expr;
    }

    /// Create a column reference expression
    pub fn columnRef(allocator: std.mem.Allocator, name: []const u8) !*Expr {
        const expr = try init(allocator, .column_ref);
        expr.column_name = name;
        return expr;
    }

    /// Create a binary operator expression
    pub fn binary(allocator: std.mem.Allocator, expr_type: ExprType, left_expr: *Expr, right_expr: *Expr) !*Expr {
        const expr = try init(allocator, expr_type);
        expr.left = left_expr;
        expr.right = right_expr;
        return expr;
    }

    /// Create a unary operator expression
    pub fn unary(allocator: std.mem.Allocator, expr_type: ExprType, operand_expr: *Expr) !*Expr {
        const expr = try init(allocator, expr_type);
        expr.operand = operand_expr;
        return expr;
    }
};

/// Predicate evaluator for WHERE clause
pub const Predicate = struct {
    expr: *Expr,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, expr: *Expr) Predicate {
        return .{
            .expr = expr,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Predicate) void {
        self.expr.deinit();
    }

    /// Evaluate predicate for a single row
    /// column_values: map from column name to value
    pub fn evaluate(self: Predicate, column_values: std.StringHashMap(Value)) !bool {
        return try self.evaluateExpr(self.expr, column_values);
    }

    fn evaluateExpr(self: Predicate, expr: *Expr, column_values: std.StringHashMap(Value)) !bool {
        switch (expr.type) {
            .literal => {
                // Literals evaluate to their boolean value
                if (expr.value) |val| {
                    return switch (val) {
                        .boolean => |b| b,
                        else => true, // Non-boolean literals are truthy
                    };
                }
                return false;
            },

            .column_ref => {
                // Column references need to be evaluated in context
                return error.InvalidExpression;
            },

            .equal => {
                const left_val = try self.getValue(expr.left.?, column_values);
                const right_val = try self.getValue(expr.right.?, column_values);
                return left_val.eql(right_val);
            },

            .not_equal => {
                const left_val = try self.getValue(expr.left.?, column_values);
                const right_val = try self.getValue(expr.right.?, column_values);
                return !left_val.eql(right_val);
            },

            .less_than => {
                const left_val = try self.getValue(expr.left.?, column_values);
                const right_val = try self.getValue(expr.right.?, column_values);
                return left_val.lessThan(right_val);
            },

            .greater_than => {
                const left_val = try self.getValue(expr.left.?, column_values);
                const right_val = try self.getValue(expr.right.?, column_values);
                return right_val.lessThan(left_val);
            },

            .less_equal => {
                const left_val = try self.getValue(expr.left.?, column_values);
                const right_val = try self.getValue(expr.right.?, column_values);
                return left_val.lessThan(right_val) or left_val.eql(right_val);
            },

            .greater_equal => {
                const left_val = try self.getValue(expr.left.?, column_values);
                const right_val = try self.getValue(expr.right.?, column_values);
                return right_val.lessThan(left_val) or left_val.eql(right_val);
            },

            .and_op => {
                const left_result = try self.evaluateExpr(expr.left.?, column_values);
                if (!left_result) return false; // Short-circuit
                return try self.evaluateExpr(expr.right.?, column_values);
            },

            .or_op => {
                const left_result = try self.evaluateExpr(expr.left.?, column_values);
                if (left_result) return true; // Short-circuit
                return try self.evaluateExpr(expr.right.?, column_values);
            },

            .not_op => {
                const operand_result = try self.evaluateExpr(expr.operand.?, column_values);
                return !operand_result;
            },

            .is_null => {
                // Check if column value is null (we don't have NULL support yet, so always false)
                return false;
            },

            .is_not_null => {
                // Check if column value is not null (always true since we don't have NULL)
                return true;
            },

            .like => {
                const left_val = try self.getValue(expr.left.?, column_values);
                const right_val = try self.getValue(expr.right.?, column_values);

                // LIKE operator for string pattern matching
                if (left_val != .string or right_val != .string) {
                    return error.TypeMismatch;
                }

                return try self.matchPattern(left_val.string, right_val.string);
            },

            .not_like => {
                const like_expr = try Expr.init(self.allocator, .like);
                like_expr.left = expr.left;
                like_expr.right = expr.right;
                const result = try self.evaluateExpr(like_expr, column_values);
                like_expr.left = null;
                like_expr.right = null;
                like_expr.deinit();
                return !result;
            },

            .between => {
                // BETWEEN is implemented as: value >= lower AND value <= upper
                return error.NotImplemented;
            },

            .in => {
                const left_val = try self.getValue(expr.left.?, column_values);
                if (expr.values) |vals| {
                    for (vals) |val| {
                        if (left_val.eql(val)) return true;
                    }
                }
                return false;
            },

            .not_in => {
                const in_expr = try Expr.init(self.allocator, .in);
                in_expr.left = expr.left;
                in_expr.values = expr.values;
                const result = try self.evaluateExpr(in_expr, column_values);
                in_expr.left = null;
                in_expr.values = null;
                in_expr.deinit();
                return !result;
            },

            .vector_search => {
                // Vector search requires table-level execution, not row-level evaluation
                return error.VectorSearchRequiresTableContext;
            },
        }
    }

    fn getValue(self: Predicate, expr: *Expr, column_values: std.StringHashMap(Value)) !Value {
        _ = self;
        switch (expr.type) {
            .literal => {
                return expr.value orelse error.NoValue;
            },
            .column_ref => {
                const col_name = expr.column_name orelse return error.NoColumnName;
                return column_values.get(col_name) orelse error.ColumnNotFound;
            },
            else => return error.InvalidExpression,
        }
    }

    /// ANSI SQL LIKE pattern matching
    /// Supports % (any characters) and _ (single character)
    fn matchPattern(self: Predicate, text: []const u8, pattern: []const u8) !bool {
        _ = self;
        return matchPatternRecursive(text, 0, pattern, 0);
    }

    fn matchPatternRecursive(text: []const u8, text_idx: usize, pattern: []const u8, pat_idx: usize) bool {
        // End of pattern
        if (pat_idx >= pattern.len) {
            return text_idx >= text.len;
        }

        // End of text
        if (text_idx >= text.len) {
            // Check if remaining pattern is all %
            for (pattern[pat_idx..]) |ch| {
                if (ch != '%') return false;
            }
            return true;
        }

        const pat_char = pattern[pat_idx];

        if (pat_char == '%') {
            // % matches zero or more characters
            // Try matching rest of pattern with current position
            if (matchPatternRecursive(text, text_idx, pattern, pat_idx + 1)) {
                return true;
            }
            // Try consuming one character from text
            return matchPatternRecursive(text, text_idx + 1, pattern, pat_idx);
        } else if (pat_char == '_') {
            // _ matches exactly one character
            return matchPatternRecursive(text, text_idx + 1, pattern, pat_idx + 1);
        } else {
            // Literal character must match
            if (text[text_idx] == pat_char) {
                return matchPatternRecursive(text, text_idx + 1, pattern, pat_idx + 1);
            }
            return false;
        }
    }
};

test "WHERE predicate evaluation - equals" {
    const allocator = std.testing.allocator;

    // Create expression: age = 30
    const left = try Expr.columnRef(allocator, "age");
    const right = try Expr.literal(allocator, Value{ .int32 = 30 });
    const expr = try Expr.binary(allocator, .equal, left, right);

    var predicate = Predicate.init(allocator, expr);
    defer predicate.deinit();

    // Test with matching value
    var values = std.StringHashMap(Value).init(allocator);
    defer values.deinit();
    try values.put("age", Value{ .int32 = 30 });

    const result = try predicate.evaluate(values);
    try std.testing.expect(result);

    // Test with non-matching value
    _ = values.fetchRemove("age");
    try values.put("age", Value{ .int32 = 25 });

    const result2 = try predicate.evaluate(values);
    try std.testing.expect(!result2);
}

test "WHERE predicate evaluation - AND" {
    const allocator = std.testing.allocator;

    // Create expression: age > 18 AND age < 65
    const left_col = try Expr.columnRef(allocator, "age");
    const left_lit = try Expr.literal(allocator, Value{ .int32 = 18 });
    const left_cmp = try Expr.binary(allocator, .greater_than, left_col, left_lit);

    const right_col = try Expr.columnRef(allocator, "age");
    const right_lit = try Expr.literal(allocator, Value{ .int32 = 65 });
    const right_cmp = try Expr.binary(allocator, .less_than, right_col, right_lit);

    const expr = try Expr.binary(allocator, .and_op, left_cmp, right_cmp);

    var predicate = Predicate.init(allocator, expr);
    defer predicate.deinit();

    // Test with value in range
    var values = std.StringHashMap(Value).init(allocator);
    defer values.deinit();
    try values.put("age", Value{ .int32 = 30 });

    const result = try predicate.evaluate(values);
    try std.testing.expect(result);

    // Test with value out of range
    _ = values.fetchRemove("age");
    try values.put("age", Value{ .int32 = 70 });

    const result2 = try predicate.evaluate(values);
    try std.testing.expect(!result2);
}

test "LIKE pattern matching" {
    const allocator = std.testing.allocator;

    // Test pattern: name LIKE 'A%'
    const left = try Expr.columnRef(allocator, "name");
    const right = try Expr.literal(allocator, Value{ .string = "A%" });
    const expr = try Expr.binary(allocator, .like, left, right);

    var predicate = Predicate.init(allocator, expr);
    defer predicate.deinit();

    var values = std.StringHashMap(Value).init(allocator);
    defer values.deinit();

    // Test matching name
    try values.put("name", Value{ .string = "Alice" });
    try std.testing.expect(try predicate.evaluate(values));

    // Test non-matching name
    _ = values.fetchRemove("name");
    try values.put("name", Value{ .string = "Bob" });
    try std.testing.expect(!try predicate.evaluate(values));
}

test "IN operator" {
    const allocator = std.testing.allocator;

    // Test: status IN ('active', 'pending')
    const left = try Expr.columnRef(allocator, "status");
    const expr = try Expr.init(allocator, .in);
    expr.left = left;

    const values_array = try allocator.alloc(Value, 2);
    values_array[0] = Value{ .string = "active" };
    values_array[1] = Value{ .string = "pending" };
    expr.values = values_array;

    var predicate = Predicate.init(allocator, expr);
    defer predicate.deinit();

    var values = std.StringHashMap(Value).init(allocator);
    defer values.deinit();

    // Test matching value
    try values.put("status", Value{ .string = "active" });
    try std.testing.expect(try predicate.evaluate(values));

    // Test non-matching value
    _ = values.fetchRemove("status");
    try values.put("status", Value{ .string = "inactive" });
    try std.testing.expect(!try predicate.evaluate(values));
}
