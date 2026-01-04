const std = @import("std");

/// Custom type definitions for user-defined types
pub const CustomType = union(enum) {
    enum_type: EnumType,
    struct_type: StructType,
    alias: TypeAlias,

    pub fn name(self: CustomType) []const u8 {
        return switch (self) {
            .enum_type => |et| et.name,
            .struct_type => |st| st.name,
            .alias => |a| a.alias,
        };
    }

    pub fn deinit(self: *CustomType, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .enum_type => |*et| et.deinit(allocator),
            .struct_type => |*st| st.deinit(allocator),
            .alias => {}, // No dynamic allocation
        }
    }

    pub fn clone(self: CustomType, allocator: std.mem.Allocator) !CustomType {
        return switch (self) {
            .enum_type => |et| CustomType{ .enum_type = try et.clone(allocator) },
            .struct_type => |st| CustomType{ .struct_type = try st.clone(allocator) },
            .alias => |a| CustomType{ .alias = a },
        };
    }
};

/// Enum type definition
pub const EnumType = struct {
    name: []const u8,
    values: []const []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, values: []const []const u8) !EnumType {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const values_copy = try allocator.alloc([]const u8, values.len);
        errdefer allocator.free(values_copy);

        var i: usize = 0;
        errdefer {
            for (values_copy[0..i]) |v| allocator.free(v);
        }

        for (values) |value| {
            values_copy[i] = try allocator.dupe(u8, value);
            i += 1;
        }

        return EnumType{
            .name = name_copy,
            .values = values_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EnumType, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.values) |value| {
            allocator.free(value);
        }
        allocator.free(self.values);
    }

    pub fn clone(self: EnumType, allocator: std.mem.Allocator) !EnumType {
        return try EnumType.init(allocator, self.name, self.values);
    }

    pub fn validateValue(self: EnumType, value: []const u8) bool {
        for (self.values) |enum_value| {
            if (std.mem.eql(u8, value, enum_value)) return true;
        }
        return false;
    }

    pub fn getIndex(self: EnumType, value: []const u8) ?usize {
        for (self.values, 0..) |enum_value, i| {
            if (std.mem.eql(u8, value, enum_value)) return i;
        }
        return null;
    }
};

/// Struct field definition
pub const StructField = struct {
    name: []const u8,
    type_ref: TypeRef,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, type_ref: TypeRef) !StructField {
        const name_copy = try allocator.dupe(u8, name);
        return StructField{
            .name = name_copy,
            .type_ref = type_ref,
        };
    }

    pub fn deinit(self: *StructField, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.type_ref.deinit(allocator);
    }

    pub fn clone(self: StructField, allocator: std.mem.Allocator) !StructField {
        return try StructField.init(allocator, self.name, try self.type_ref.clone(allocator));
    }
};

/// Struct type definition
pub const StructType = struct {
    name: []const u8,
    fields: []StructField,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, fields: []const StructField) !StructType {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const fields_copy = try allocator.alloc(StructField, fields.len);
        errdefer allocator.free(fields_copy);

        var i: usize = 0;
        errdefer {
            for (fields_copy[0..i]) |*field| field.deinit(allocator);
        }

        for (fields) |field| {
            fields_copy[i] = try field.clone(allocator);
            i += 1;
        }

        return StructType{
            .name = name_copy,
            .fields = fields_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StructType, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.fields) |*field| {
            field.deinit(allocator);
        }
        allocator.free(self.fields);
    }

    pub fn clone(self: StructType, allocator: std.mem.Allocator) !StructType {
        return try StructType.init(allocator, self.name, self.fields);
    }

    pub fn getFieldIndex(self: StructType, field_name: []const u8) ?usize {
        for (self.fields, 0..) |field, i| {
            if (std.mem.eql(u8, field.name, field_name)) return i;
        }
        return null;
    }

    pub fn getField(self: StructType, field_name: []const u8) ?*const StructField {
        if (self.getFieldIndex(field_name)) |idx| {
            return &self.fields[idx];
        }
        return null;
    }
};

/// Type alias definition
pub const TypeAlias = struct {
    alias: []const u8,
    target_type: []const u8,

    pub fn init(alias: []const u8, target_type: []const u8) TypeAlias {
        return TypeAlias{
            .alias = alias,
            .target_type = target_type,
        };
    }
};

/// Type reference - can point to built-in or custom types
pub const TypeRef = union(enum) {
    builtin: std.meta.Tag(std.builtin.Type),
    custom: []const u8, // Custom type name

    pub fn deinit(self: *TypeRef, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .builtin => {},
            .custom => |type_name| allocator.free(type_name),
        }
    }

    pub fn clone(self: TypeRef, allocator: std.mem.Allocator) !TypeRef {
        return switch (self) {
            .builtin => |tag| TypeRef{ .builtin = tag },
            .custom => |type_name| TypeRef{ .custom = try allocator.dupe(u8, type_name) },
        };
    }

    pub fn name(self: TypeRef) []const u8 {
        return switch (self) {
            .builtin => |tag| @tagName(tag),
            .custom => |type_name| type_name,
        };
    }
};

/// Custom type value storage
pub const CustomValue = union(enum) {
    enum_value: EnumValue,
    struct_value: StructValue,

    pub fn deinit(self: *CustomValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .enum_value => |*ev| ev.deinit(allocator),
            .struct_value => |*sv| sv.deinit(allocator),
        }
    }

    pub fn clone(self: CustomValue, allocator: std.mem.Allocator) !CustomValue {
        return switch (self) {
            .enum_value => |ev| CustomValue{ .enum_value = try ev.clone(allocator) },
            .struct_value => |sv| CustomValue{ .struct_value = try sv.clone(allocator) },
        };
    }
};

/// Enum value storage
pub const EnumValue = struct {
    type_name: []const u8,
    value: []const u8,
    index: usize,

    pub fn init(allocator: std.mem.Allocator, type_name: []const u8, value: []const u8, index: usize) !EnumValue {
        const type_name_copy = try allocator.dupe(u8, type_name);
        errdefer allocator.free(type_name_copy);

        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);

        return EnumValue{
            .type_name = type_name_copy,
            .value = value_copy,
            .index = index,
        };
    }

    pub fn deinit(self: *EnumValue, allocator: std.mem.Allocator) void {
        allocator.free(self.type_name);
        allocator.free(self.value);
    }

    pub fn clone(self: EnumValue, allocator: std.mem.Allocator) !EnumValue {
        return try EnumValue.init(allocator, self.type_name, self.value, self.index);
    }
};

/// Struct value storage
pub const StructValue = struct {
    type_name: []const u8,
    fields: std.StringHashMap(Value), // field_name -> value

    pub fn init(allocator: std.mem.Allocator, type_name: []const u8) !StructValue {
        const type_name_copy = try allocator.dupe(u8, type_name);
        errdefer allocator.free(type_name_copy);

        var fields = std.StringHashMap(Value).init(allocator);
        errdefer fields.deinit();

        return StructValue{
            .type_name = type_name_copy,
            .fields = fields,
        };
    }

    pub fn deinit(self: *StructValue, allocator: std.mem.Allocator) void {
        allocator.free(self.type_name);
        var it = self.fields.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(allocator);
        }
        self.fields.deinit();
    }

    pub fn clone(self: StructValue, allocator: std.mem.Allocator) !StructValue {
        var result = try StructValue.init(allocator, self.type_name);
        errdefer result.deinit(allocator);

        var it = self.fields.iterator();
        while (it.next()) |entry| {
            const key_copy = try allocator.dupe(u8, entry.key_ptr.*);
            errdefer allocator.free(key_copy);

            // Note: Value cloning would need to be implemented
            // For now, we'll assume values are copied by reference
            try result.fields.put(key_copy, entry.value_ptr.*);
        }

        return result;
    }

    pub fn setField(self: *StructValue, field_name: []const u8, value: Value) !void {
        const key_copy = try self.fields.allocator.dupe(u8, field_name);
        errdefer self.fields.allocator.free(key_copy);

        try self.fields.put(key_copy, value);
    }

    pub fn getField(self: StructValue, field_name: []const u8) ?Value {
        return self.fields.get(field_name);
    }
};

// Import Value for StructValue
const Value = @import("types.zig").Value;

test "EnumType basic functionality" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const values = [_][]const u8{ "happy", "sad", "curious" };
    var enum_type = try EnumType.init(allocator, "mood", &values);
    defer enum_type.deinit(allocator);

    try std.testing.expect(std.mem.eql(u8, enum_type.name, "mood"));
    try std.testing.expectEqual(@as(usize, 3), enum_type.values.len);
    try std.testing.expect(enum_type.validateValue("happy"));
    try std.testing.expect(!enum_type.validateValue("angry"));
    try std.testing.expectEqual(@as(?usize, 0), enum_type.getIndex("happy"));
    try std.testing.expectEqual(@as(?usize, null), enum_type.getIndex("angry"));
}

test "StructType basic functionality" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const type_ref = TypeRef{ .builtin = .int };
    var field = try StructField.init(allocator, "id", type_ref);
    defer field.deinit(allocator);

    const fields = [_]StructField{field};
    var struct_type = try StructType.init(allocator, "person", &fields);
    defer struct_type.deinit(allocator);

    try std.testing.expect(std.mem.eql(u8, struct_type.name, "person"));
    try std.testing.expectEqual(@as(usize, 1), struct_type.fields.len);
    try std.testing.expect(std.mem.eql(u8, struct_type.fields[0].name, "id"));
    try std.testing.expectEqual(@as(?usize, 0), struct_type.getFieldIndex("id"));
    try std.testing.expectEqual(@as(?usize, null), struct_type.getFieldIndex("name"));
}
