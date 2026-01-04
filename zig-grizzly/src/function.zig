const std = @import("std");
const types = @import("types.zig");
const pattern_mod = @import("pattern.zig");

const Value = types.Value;
const DataType = types.DataType;
const PatternMatcher = pattern_mod.PatternMatcher;

/// Execution context for functions
pub const ExecutionContext = enum {
    runtime,
    compile_time,
};

/// Function parameter definition
pub const Parameter = struct {
    name: []const u8,
    type_: DataType,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, type_: DataType) !Parameter {
        const name_copy = try allocator.dupe(u8, name);
        return Parameter{
            .name = name_copy,
            .type_ = type_,
        };
    }

    pub fn deinit(self: *Parameter, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

/// Pattern matching case in function body
pub const MatchCase = struct {
    pattern: pattern_mod.Pattern,
    expression: []const u8, // Expression to evaluate if pattern matches

    pub fn init(pattern: pattern_mod.Pattern, expression: []const u8) MatchCase {
        return MatchCase{
            .pattern = pattern,
            .expression = expression,
        };
    }

    pub fn deinit(self: *MatchCase, allocator: std.mem.Allocator) void {
        self.pattern.deinit(allocator);
        allocator.free(self.expression);
    }
};

/// Function body - either expression or pattern matching
pub const FunctionBody = union(enum) {
    expression: []const u8, // Simple expression body
    match: struct {
        value_expr: []const u8, // Expression to match against
        cases: []MatchCase,
    },

    pub fn deinit(self: *FunctionBody, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .expression => |expr| allocator.free(expr),
            .match => |*m| {
                allocator.free(m.value_expr);
                for (m.cases) |*case_| {
                    case_.deinit(allocator);
                }
                allocator.free(m.cases);
            },
        }
    }
};

/// User-defined function
pub const Function = struct {
    name: []const u8,
    parameters: []Parameter,
    return_type: DataType,
    body: FunctionBody,
    context: ExecutionContext,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        parameters: []Parameter,
        return_type: DataType,
        body: FunctionBody,
        context: ExecutionContext,
    ) !Function {
        const owned_name = try allocator.dupe(u8, name);

        // Clone parameters
        var owned_params = try allocator.alloc(Parameter, parameters.len);
        for (parameters, 0..) |param, i| {
            owned_params[i] = Parameter{
                .name = try allocator.dupe(u8, param.name),
                .type_ = param.type_,
            };
        }

        return Function{
            .name = owned_name,
            .parameters = owned_params,
            .return_type = return_type,
            .body = body,
            .context = context,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Function) void {
        self.allocator.free(self.name);
        for (self.parameters) |*param| {
            param.deinit(self.allocator);
        }
        self.allocator.free(self.parameters);
        self.body.deinit(self.allocator);
    }

    /// Execute the function with given arguments
    pub fn execute(self: *const Function, args: []const Value, expression_engine: anytype) !Value {
        // Validate argument count
        if (args.len != self.parameters.len) {
            return error.InvalidArgumentCount;
        }

        // Validate argument types
        for (args, self.parameters) |arg, param| {
            if (!typesCompatible(arg, param.type_)) {
                return error.InvalidArgumentType;
            }
        }

        // Set up function scope with parameters
        for (args, self.parameters) |arg, param| {
            try expression_engine.setVariable(param.name, arg);
        }

        // Execute based on body type
        switch (self.body) {
            .expression => |expr| {
                return try expression_engine.evaluate(expr);
            },
            .match => |*match_body| {
                // Evaluate the value to match against
                const match_value = try expression_engine.evaluate(match_body.value_expr);

                // Try each case
                for (match_body.cases) |case_| {
                    if (try case_.pattern.matches(match_value, expression_engine.allocator)) {
                        return try expression_engine.evaluate(case_.expression);
                    }
                }

                return error.NoPatternMatched;
            },
        }
    }

    /// Check if two types are compatible
    fn typesCompatible(value: Value, expected_type: DataType) bool {
        return switch (value) {
            .int32 => expected_type == .int32,
            .int64 => expected_type == .int64,
            .float32 => expected_type == .float32,
            .float64 => expected_type == .float64,
            .boolean => expected_type == .boolean,
            .string => expected_type == .string,
            .timestamp => expected_type == .timestamp,
            .vector => expected_type == .vector,
            .custom => expected_type == .custom,
            .exception => expected_type == .exception,
        };
    }
};

/// Function registry for managing user-defined functions
pub const FunctionRegistry = struct {
    functions: std.StringHashMap(*Function),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FunctionRegistry {
        return FunctionRegistry{
            .functions = std.StringHashMap(*Function).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FunctionRegistry) void {
        var it = self.functions.valueIterator();
        while (it.next()) |func_ptr| {
            func_ptr.*.deinit();
            self.allocator.destroy(func_ptr.*);
        }
        self.functions.deinit();
    }

    /// Register a new function
    pub fn registerFunction(self: *FunctionRegistry, function: *Function) !void {
        if (self.functions.contains(function.name)) {
            return error.FunctionAlreadyExists;
        }
        try self.functions.put(function.name, function);
    }

    /// Get a function by name
    pub fn getFunction(self: *const FunctionRegistry, name: []const u8) ?*Function {
        return self.functions.get(name);
    }

    /// Remove a function
    pub fn removeFunction(self: *FunctionRegistry, name: []const u8) bool {
        if (self.functions.getPtr(name)) |func_ptr| {
            func_ptr.*.deinit();
            self.allocator.destroy(func_ptr.*);
            return self.functions.remove(name);
        }
        return false;
    }

    /// List all function names
    pub fn listFunctions(self: *const FunctionRegistry, allocator: std.mem.Allocator) ![][]const u8 {
        var names = try std.ArrayList([]const u8).initCapacity(allocator, 0);
        errdefer names.deinit(allocator);

        var it = self.functions.iterator();
        while (it.next()) |entry| {
            try names.append(allocator, entry.key_ptr.*);
        }

        return names.toOwnedSlice(allocator);
    }
};

test "Function creation and execution" {
    var registry = FunctionRegistry.init(std.testing.allocator);
    defer registry.deinit();

    // Create a simple function: calculate_discount(price, tier) -> price
    var params = [_]Parameter{
        try Parameter.init(std.testing.allocator, "price", .float64),
        try Parameter.init(std.testing.allocator, "tier", .string),
    };
    defer for (&params) |*p| p.deinit(std.testing.allocator);

    const body_expr = "price";
    const body = FunctionBody{ .expression = try std.testing.allocator.dupe(u8, body_expr) };
    // Note: body ownership is transferred to Function, so don't defer deinit here

    const function = try std.testing.allocator.create(Function);
    function.* = try Function.init(
        std.testing.allocator,
        "calculate_discount",
        &params,
        .float64,
        body,
        .runtime,
    );
    // Note: function ownership is transferred to registry, so don't defer deinit here

    try registry.registerFunction(function);

    // Test execution
    var engine = @import("expression.zig").ExpressionEngine.initWithFunctions(std.testing.allocator, &registry);
    defer engine.deinit();

    const args = [_]Value{
        Value{ .float64 = 100.0 },
        Value{ .string = "silver" },
    };

    const result = try function.execute(&args, &engine);
    try std.testing.expectEqual(@as(f64, 100.0), result.float64);
}

test "Function registry operations" {
    var registry = FunctionRegistry.init(std.testing.allocator);
    defer registry.deinit();

    // Create and register function
    var params = [_]Parameter{try Parameter.init(std.testing.allocator, "x", .int64)};
    defer params[0].deinit(std.testing.allocator);

    const body_expr = try std.testing.allocator.dupe(u8, "x + 1");
    // Note: body_expr ownership is transferred to FunctionBody, so don't defer free here
    const body = FunctionBody{ .expression = body_expr };

    const function = try std.testing.allocator.create(Function);
    function.* = try Function.init(
        std.testing.allocator,
        "increment",
        &params,
        .int64,
        body,
        .runtime,
    );
    // Note: function ownership is transferred to registry, so don't defer deinit here

    try registry.registerFunction(function);

    // Test retrieval
    const retrieved = registry.getFunction("increment");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("increment", retrieved.?.name);

    // Test listing
    const names = try registry.listFunctions(std.testing.allocator);
    defer std.testing.allocator.free(names);
    try std.testing.expectEqual(@as(usize, 1), names.len);
    try std.testing.expectEqualStrings("increment", names[0]);
}
