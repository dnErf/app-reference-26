const std = @import("std");
const types = @import("types.zig");
const types_custom = @import("types_custom.zig");

const Value = types.Value;
const DataType = types.DataType;
const CustomValue = types_custom.CustomValue;

/// Pattern types for matching
pub const Pattern = union(enum) {
    literal: Value, // Match exact value
    variable: []const u8, // Bind to variable (always matches)
    wildcard, // Match anything (_)

    pub fn initLiteral(allocator: std.mem.Allocator, value: Value) !Pattern {
        return Pattern{ .literal = try value.clone(allocator) };
    }

    pub fn initVariable(allocator: std.mem.Allocator, name: []const u8) !Pattern {
        return Pattern{ .variable = try allocator.dupe(u8, name) };
    }

    pub fn initWildcard() Pattern {
        return Pattern.wildcard;
    }

    pub fn deinit(self: *Pattern, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .literal => |*v| v.deinit(allocator),
            .variable => |name| allocator.free(name),
            .wildcard => {},
        }
    }

    /// Check if this pattern matches the given value
    /// If it matches and it's a variable pattern, binds the value to the variable name
    pub fn matches(self: *const Pattern, value: Value, _: std.mem.Allocator) !bool {
        switch (self.*) {
            .literal => |lit| {
                return valuesEqual(lit, value);
            },
            .variable => |_| {
                // Variables always match - binding happens in the calling context
                return true;
            },
            .wildcard => {
                return true;
            },
        }
    }

    /// Get the variable name if this is a variable pattern
    pub fn getVariableName(self: *const Pattern) ?[]const u8 {
        switch (self.*) {
            .variable => |name| return name,
            else => return null,
        }
    }
};

/// Pattern matcher for evaluating match expressions
pub const PatternMatcher = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PatternMatcher {
        return PatternMatcher{ .allocator = allocator };
    }

    /// Evaluate a match expression: match value with pattern1 -> expr1, pattern2 -> expr2, ...
    pub fn evaluateMatch(
        self: *PatternMatcher,
        value: Value,
        cases: []const MatchCase,
        expression_engine: anytype,
    ) !Value {
        for (cases) |case_| {
            if (try case_.pattern.matches(value, self.allocator)) {
                // If this is a variable pattern, bind the value
                if (case_.pattern.getVariableName()) |var_name| {
                    try expression_engine.setVariable(var_name, value);
                }
                return try expression_engine.evaluate(case_.expression);
            }
        }
        return error.NoPatternMatched;
    }
};

/// A single case in a match expression
pub const MatchCase = struct {
    pattern: Pattern,
    expression: []const u8,

    pub fn init(allocator: std.mem.Allocator, pattern: Pattern, expression: []const u8) !MatchCase {
        return MatchCase{
            .pattern = pattern,
            .expression = try allocator.dupe(u8, expression),
        };
    }

    pub fn deinit(self: *MatchCase, allocator: std.mem.Allocator) void {
        self.pattern.deinit(allocator);
        allocator.free(self.expression);
    }
};

/// Check if two values are equal
fn valuesEqual(a: Value, b: Value) bool {
    if (@as(DataType, a) != @as(DataType, b)) return false;

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
            // TODO: Implement proper custom value comparison
            return @as(std.meta.Tag(CustomValue), cv) == @as(std.meta.Tag(CustomValue), b.custom);
        },
    };
}

test "Pattern matching - literals" {
    var pattern = try Pattern.initLiteral(std.testing.allocator, Value{ .int64 = 42 });
    defer pattern.deinit(std.testing.allocator);

    // Should match
    try std.testing.expect(try pattern.matches(Value{ .int64 = 42 }, std.testing.allocator));

    // Should not match
    try std.testing.expect(!try pattern.matches(Value{ .int64 = 43 }, std.testing.allocator));
    try std.testing.expect(!try pattern.matches(Value{ .string = "42" }, std.testing.allocator));
}

test "Pattern matching - variables" {
    var pattern = try Pattern.initVariable(std.testing.allocator, "x");
    defer pattern.deinit(std.testing.allocator);

    // Variables always match
    try std.testing.expect(try pattern.matches(Value{ .int64 = 42 }, std.testing.allocator));
    try std.testing.expect(try pattern.matches(Value{ .string = "hello" }, std.testing.allocator));

    // Check variable name
    try std.testing.expectEqualStrings("x", pattern.getVariableName().?);
}

test "Pattern matching - wildcards" {
    var pattern = Pattern.initWildcard();
    defer pattern.deinit(std.testing.allocator);

    // Wildcards always match
    try std.testing.expect(try pattern.matches(Value{ .int64 = 42 }, std.testing.allocator));
    try std.testing.expect(try pattern.matches(Value{ .string = "hello" }, std.testing.allocator));
    try std.testing.expect(try pattern.matches(Value{ .boolean = true }, std.testing.allocator));
}

test "PatternMatcher - match expression" {
    var matcher = PatternMatcher.init(std.testing.allocator);
    var engine = @import("expression.zig").ExpressionEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Create cases: 1 -> "one", 2 -> "two", _ -> "other"
    var cases = [_]MatchCase{
        try MatchCase.init(std.testing.allocator, try Pattern.initLiteral(std.testing.allocator, Value{ .int64 = 1 }), "\"one\""),
        try MatchCase.init(std.testing.allocator, try Pattern.initLiteral(std.testing.allocator, Value{ .int64 = 2 }), "\"two\""),
        try MatchCase.init(std.testing.allocator, Pattern.initWildcard(), "\"other\""),
    };
    defer for (&cases) |*c| c.deinit(std.testing.allocator);

    // Test matching 1
    const result1 = try matcher.evaluateMatch(Value{ .int64 = 1 }, &cases, &engine);
    defer @constCast(&result1).deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("one", result1.string);

    // Test matching 2
    const result2 = try matcher.evaluateMatch(Value{ .int64 = 2 }, &cases, &engine);
    defer @constCast(&result2).deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("two", result2.string);

    // Test matching other value (should hit wildcard)
    const result3 = try matcher.evaluateMatch(Value{ .int64 = 99 }, &cases, &engine);
    defer @constCast(&result3).deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("other", result3.string);
}

test "Value equality" {
    // Test string equality
    try std.testing.expect(valuesEqual(Value{ .string = "hello" }, Value{ .string = "hello" }));
    try std.testing.expect(!valuesEqual(Value{ .string = "hello" }, Value{ .string = "world" }));

    // Test numeric equality
    try std.testing.expect(valuesEqual(Value{ .int64 = 42 }, Value{ .int64 = 42 }));
    try std.testing.expect(!valuesEqual(Value{ .int64 = 42 }, Value{ .int64 = 43 }));

    // Test different types
    try std.testing.expect(!valuesEqual(Value{ .int64 = 42 }, Value{ .string = "42" }));
}
