const std = @import("std");
const CustomType = @import("types_custom.zig").CustomType;
const EnumType = @import("types_custom.zig").EnumType;
const StructType = @import("types_custom.zig").StructType;
const ExceptionType = @import("types_custom.zig").ExceptionType;
const TypeAlias = @import("types_custom.zig").TypeAlias;

/// Global type registry for managing custom types
pub const TypeRegistry = struct {
    allocator: std.mem.Allocator,
    types: std.StringHashMap(CustomType),
    aliases: std.StringHashMap([]const u8), // alias -> target_type_name
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) TypeRegistry {
        return TypeRegistry{
            .allocator = allocator,
            .types = std.StringHashMap(CustomType).init(allocator),
            .aliases = std.StringHashMap([]const u8).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *TypeRegistry) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Clean up types
        var type_it = self.types.iterator();
        while (type_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.types.deinit();

        // Clean up aliases
        var alias_it = self.aliases.iterator();
        while (alias_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.aliases.deinit();
    }

    /// Create a new enum type
    pub fn createEnum(self: *TypeRegistry, name: []const u8, values: []const []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if type already exists
        if (self.types.contains(name)) {
            return error.TypeAlreadyExists;
        }

        // Validate enum values (no duplicates)
        var seen = std.StringHashMap(void).init(self.allocator);
        defer {
            var it = seen.keyIterator();
            while (it.next()) |key| {
                self.allocator.free(key.*);
            }
            seen.deinit();
        }

        for (values) |value| {
            if (seen.contains(value)) {
                return error.DuplicateEnumValue;
            }
            try seen.put(try self.allocator.dupe(u8, value), {});
        }

        // Create the enum type
        var enum_type = try EnumType.init(self.allocator, name, values);
        errdefer enum_type.deinit(self.allocator);

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        try self.types.put(name_copy, CustomType{ .enum_type = enum_type });
    }

    /// Create a new struct type
    pub fn createStruct(self: *TypeRegistry, name: []const u8, fields: []const @import("types_custom.zig").StructField) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if type already exists
        if (self.types.contains(name)) {
            return error.TypeAlreadyExists;
        }

        // Validate field names (no duplicates)
        var seen = std.StringHashMap(void).init(self.allocator);
        defer {
            var it = seen.keyIterator();
            while (it.next()) |key| {
                self.allocator.free(key.*);
            }
            seen.deinit();
        }

        for (fields) |field| {
            if (seen.contains(field.name)) {
                return error.DuplicateFieldName;
            }
            try seen.put(try self.allocator.dupe(u8, field.name), {});
        }

        // Create the struct type
        var struct_type = try StructType.init(self.allocator, name, fields);
        errdefer struct_type.deinit(self.allocator);

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        try self.types.put(name_copy, CustomType{ .struct_type = struct_type });
    }

    /// Create a new exception type
    pub fn createException(self: *TypeRegistry, name: []const u8, message: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if type already exists
        if (self.types.contains(name)) {
            return error.TypeAlreadyExists;
        }

        // Create the exception type
        var exception_type = try ExceptionType.init(self.allocator, name, message);
        errdefer exception_type.deinit(self.allocator);

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        try self.types.put(name_copy, CustomType{ .exception_type = exception_type });
    }

    /// Create a type alias
    pub fn createAlias(self: *TypeRegistry, alias: []const u8, target_type: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if alias already exists
        if (self.aliases.contains(alias) or self.types.contains(alias)) {
            return error.AliasAlreadyExists;
        }

        // Check if target type exists (either built-in or custom)
        if (!self.isValidType(target_type)) {
            return error.InvalidTargetType;
        }

        const alias_copy = try self.allocator.dupe(u8, alias);
        errdefer self.allocator.free(alias_copy);

        const target_copy = try self.allocator.dupe(u8, target_type);
        errdefer self.allocator.free(target_copy);

        try self.aliases.put(alias_copy, target_copy);
    }

    /// Drop a type (with optional CASCADE)
    pub fn dropType(self: *TypeRegistry, name: []const u8, cascade: bool) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if it's a custom type
        if (self.types.getEntry(name)) |entry| {
            // Check for dependencies if not cascading
            if (!cascade) {
                try self.checkDependencies(name);
            }

            // Remove the type
            const key = entry.key_ptr.*;
            var value = entry.value_ptr.*;
            self.types.removeByPtr(entry.key_ptr);

            // Clean up
            value.deinit(self.allocator);
            self.allocator.free(key);

            return;
        }

        // Check if it's an alias
        if (self.aliases.getEntry(name)) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            self.aliases.removeByPtr(entry.key_ptr);

            // Clean up
            self.allocator.free(key);
            self.allocator.free(value);

            return;
        }

        return error.TypeNotFound;
    }

    /// Get a custom type by name
    pub fn getType(self: *TypeRegistry, name: []const u8) ?CustomType {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.types.get(name);
    }

    /// Get type alias target
    pub fn getAlias(self: *TypeRegistry, alias: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.aliases.get(alias);
    }

    /// Resolve a type name (following aliases)
    pub fn resolveType(self: *TypeRegistry, name: []const u8) []const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var current = name;
        var depth: usize = 0;

        // Prevent infinite alias loops
        while (depth < 10) {
            if (self.aliases.get(current)) |target| {
                current = target;
                depth += 1;
            } else {
                break;
            }
        }

        return current;
    }

    /// Check if a type name is valid (built-in or custom)
    pub fn isValidType(self: *TypeRegistry, name: []const u8) bool {
        // Check built-in types (both internal names and SQL names)
        const builtin_types = [_][]const u8{
            "int32",   "int64",  "float32",   "float64",
            "boolean", "string", "timestamp", "vector",
            "integer", "bigint", "float",     "double",
            "bool",    "text",   "varchar",
        };

        var buf: [32]u8 = undefined;
        if (name.len <= buf.len) {
            const lowercase = std.ascii.lowerString(&buf, name);
            for (builtin_types) |builtin| {
                if (std.mem.eql(u8, lowercase, builtin)) return true;
            }
        }

        // Check custom types
        return self.types.contains(name);
    }

    /// List all custom types
    pub fn listTypes(self: *TypeRegistry, allocator: std.mem.Allocator) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = try std.ArrayList([]const u8).initCapacity(allocator, 0);
        errdefer {
            for (result.items) |item| allocator.free(item);
            result.deinit(allocator);
        }

        var it = self.types.iterator();
        while (it.next()) |entry| {
            try result.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
        }

        return try result.toOwnedSlice(allocator);
    }

    /// List all type aliases
    pub fn listAliases(self: *TypeRegistry, allocator: std.mem.Allocator) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = try std.ArrayList([]const u8).initCapacity(allocator, 0);
        errdefer {
            for (result.items) |item| allocator.free(item);
            result.deinit(allocator);
        }

        var it = self.aliases.iterator();
        while (it.next()) |entry| {
            try result.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
        }

        return try result.toOwnedSlice(allocator);
    }

    /// Check for dependencies before dropping a type
    fn checkDependencies(self: *TypeRegistry, type_name: []const u8) !void {
        // Check if any struct types reference this type
        var it = self.types.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*) {
                .struct_type => |st| {
                    for (st.fields) |field| {
                        if (field.type_ref == .custom and std.mem.eql(u8, field.type_ref.custom, type_name)) {
                            return error.TypeHasDependencies;
                        }
                    }
                },
                else => {},
            }
        }

        // Check if any aliases reference this type
        var alias_it = self.aliases.iterator();
        while (alias_it.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.*, type_name)) {
                return error.TypeHasDependencies;
            }
        }
    }

    /// Get type information for introspection
    pub fn describeType(self: *TypeRegistry, name: []const u8, allocator: std.mem.Allocator) !?TypeInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if it's an alias
        if (self.aliases.get(name)) |target| {
            return TypeInfo{
                .name = try allocator.dupe(u8, name),
                .kind = .alias,
                .alias_target = try allocator.dupe(u8, target),
            };
        }

        // Check if it's a custom type
        if (self.types.get(name)) |custom_type| {
            return try self.describeCustomType(name, custom_type, allocator);
        }

        return null;
    }

    fn describeCustomType(_: *const TypeRegistry, name: []const u8, custom_type: CustomType, allocator: std.mem.Allocator) !TypeInfo {
        const name_copy = try allocator.dupe(u8, name);

        switch (custom_type) {
            .enum_type => |et| {
                var values_copy = try allocator.alloc([]const u8, et.values.len);
                errdefer allocator.free(values_copy);

                for (et.values, 0..) |value, i| {
                    values_copy[i] = try allocator.dupe(u8, value);
                }

                return TypeInfo{
                    .name = name_copy,
                    .kind = .enum_type,
                    .enum_values = values_copy,
                };
            },
            .struct_type => |st| {
                var fields_copy = try allocator.alloc(FieldInfo, st.fields.len);
                errdefer allocator.free(fields_copy);

                for (st.fields, 0..) |field, i| {
                    fields_copy[i] = FieldInfo{
                        .name = try allocator.dupe(u8, field.name),
                        .type_name = try allocator.dupe(u8, field.type_ref.name()),
                    };
                }

                return TypeInfo{
                    .name = name_copy,
                    .kind = .struct_type,
                    .struct_fields = fields_copy,
                };
            },
            .alias => unreachable, // Handled above
        }
    }
};

/// Type information for introspection
pub const TypeInfo = struct {
    name: []const u8,
    kind: TypeKind,
    alias_target: ?[]const u8 = null,
    enum_values: ?[][]const u8 = null,
    struct_fields: ?[]FieldInfo = null,

    pub fn deinit(self: *TypeInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);

        if (self.alias_target) |target| allocator.free(target);
        if (self.enum_values) |values| {
            for (values) |value| allocator.free(value);
            allocator.free(values);
        }
        if (self.struct_fields) |fields| {
            for (fields) |field| {
                allocator.free(field.name);
                allocator.free(field.type_name);
            }
            allocator.free(fields);
        }
    }
};

pub const TypeKind = enum {
    alias,
    enum_type,
    struct_type,
};

pub const FieldInfo = struct {
    name: []const u8,
    type_name: []const u8,
};

test "TypeRegistry enum creation" {
    var registry = TypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const values = [_][]const u8{ "low", "medium", "high" };
    try registry.createEnum("priority", &values);

    const retrieved = registry.getType("priority");
    try std.testing.expect(retrieved != null);
    try std.testing.expect(std.mem.eql(u8, retrieved.?.enum_type.name, "priority"));
    try std.testing.expectEqual(@as(usize, 3), retrieved.?.enum_type.values.len);
}

test "TypeRegistry alias creation" {
    var registry = TypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    try registry.createAlias("person_id", "int64");

    const target = registry.getAlias("person_id");
    try std.testing.expect(target != null);
    try std.testing.expect(std.mem.eql(u8, target.?, "int64"));

    const resolved = registry.resolveType("person_id");
    try std.testing.expect(std.mem.eql(u8, resolved, "int64"));
}

test "TypeRegistry type validation" {
    var registry = TypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    // Built-in types should be valid
    try std.testing.expect(registry.isValidType("int32"));
    try std.testing.expect(registry.isValidType("string"));

    // Non-existent types should be invalid
    try std.testing.expect(!registry.isValidType("nonexistent"));

    // Custom types should be valid after creation
    const values = [_][]const u8{ "yes", "no" };
    try registry.createEnum("boolean_custom", &values);
    try std.testing.expect(registry.isValidType("boolean_custom"));
}
