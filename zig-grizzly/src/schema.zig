const std = @import("std");
const types = @import("types.zig");
const DataType = types.DataType;

/// Schema defines the structure of a table
pub const Schema = struct {
    columns: []const ColumnDef,
    allocator: std.mem.Allocator,

    pub const ColumnDef = struct {
        name: []const u8,
        data_type: DataType,
        vector_dim: usize = 0,
    };

    pub fn init(allocator: std.mem.Allocator, columns: []const ColumnDef) !Schema {
        const owned_columns = try allocator.alloc(ColumnDef, columns.len);
        for (columns, 0..) |col, i| {
            const name = try allocator.dupe(u8, col.name);
            owned_columns[i] = .{
                .name = name,
                .data_type = col.data_type,
                .vector_dim = col.vector_dim,
            };
        }
        return Schema{
            .columns = owned_columns,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Schema) void {
        for (self.columns) |col| {
            self.allocator.free(col.name);
        }
        self.allocator.free(self.columns);
    }

    pub fn findColumn(self: Schema, name: []const u8) ?usize {
        for (self.columns, 0..) |col, i| {
            if (std.mem.eql(u8, col.name, name)) return i;
        }
        return null;
    }

    pub fn format(
        self: Schema,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Schema(", .{});
        for (self.columns, 0..) |col, i| {
            if (i > 0) try writer.print(", ", .{});
            if (col.data_type == .vector) {
                try writer.print("{s}: vector[{d}]", .{ col.name, col.vector_dim });
            } else {
                try writer.print("{s}: {s}", .{ col.name, col.data_type.name() });
            }
        }
        try writer.print(")", .{});
    }
};

test "Schema creation" {
    const allocator = std.testing.allocator;
    const cols = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
        .{ .name = "age", .data_type = .int32 },
    };

    var schema = try Schema.init(allocator, &cols);
    defer schema.deinit();

    try std.testing.expectEqual(@as(usize, 3), schema.columns.len);
    try std.testing.expectEqual(@as(?usize, 0), schema.findColumn("id"));
    try std.testing.expectEqual(@as(?usize, 1), schema.findColumn("name"));
    try std.testing.expectEqual(@as(?usize, null), schema.findColumn("unknown"));
}
