const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");
const schema_mod = @import("schema.zig");

const Value = types.Value;
const Table = table_mod.Table;
const Schema = schema_mod.Schema;

/// Database manages multiple tables
pub const Database = struct {
    name: []const u8,
    tables: std.StringHashMap(*Table),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Database {
        const owned_name = try allocator.dupe(u8, name);
        return Database{
            .name = owned_name,
            .tables = std.StringHashMap(*Table).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Database) void {
        var it = self.tables.valueIterator();
        while (it.next()) |table_ptr| {
            table_ptr.*.deinit();
            self.allocator.destroy(table_ptr.*);
        }
        self.tables.deinit();
        self.allocator.free(self.name);
    }

    /// Create a new table
    pub fn createTable(self: *Database, table_name: []const u8, schema_def: []const Schema.ColumnDef) !void {
        if (self.tables.contains(table_name)) {
            return error.TableAlreadyExists;
        }

        const table = try self.allocator.create(Table);
        table.* = try Table.init(self.allocator, table_name, schema_def);
        try self.tables.put(table_name, table);
    }

    /// Get a table by name
    pub fn getTable(self: *Database, table_name: []const u8) !*Table {
        return self.tables.get(table_name) orelse error.TableNotFound;
    }

    /// Drop a table
    pub fn dropTable(self: *Database, table_name: []const u8) !void {
        if (self.tables.fetchRemove(table_name)) |kv| {
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        } else {
            return error.TableNotFound;
        }
    }

    /// List all table names
    pub fn listTables(self: Database, allocator: std.mem.Allocator) ![][]const u8 {
        var list = std.ArrayList([]const u8){};
        errdefer list.deinit(allocator);

        var it = self.tables.keyIterator();
        while (it.next()) |key| {
            try list.append(allocator, key.*);
        }

        return list.toOwnedSlice(allocator);
    }

    /// Save database to disk
    pub fn save(self: Database, dir_path: []const u8) !void {
        // Create directory if it doesn't exist
        std.fs.cwd().makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        var dir = try std.fs.cwd().openDir(dir_path, .{});
        defer dir.close();

        // Save metadata
        const meta_file = try dir.createFile("db.meta", .{});
        defer meta_file.close();
        
        var meta_buf: [4096]u8 = undefined;
        var meta_writer = meta_file.writer(&meta_buf);
        try meta_writer.interface.print("database:{s}\\n", .{self.name});
        try meta_writer.interface.print("tables:{d}\\n", .{self.tables.count()});
        try meta_writer.flush();

        // Save each table
        var it = self.tables.iterator();
        while (it.next()) |entry| {
            try saveTable(entry.value_ptr.*, dir);
        }
    }

    fn saveTable(table: *Table, dir: std.fs.Dir) !void {
        const filename = try std.fmt.allocPrint(table.allocator, "{s}.gtbl", .{table.name});
        defer table.allocator.free(filename);

        const file = try dir.createFile(filename, .{});
        defer file.close();

    fn saveTable(table: *Table, dir: std.fs.Dir) !void {
        const filename = try std.fmt.allocPrint(table.allocator, "{s}.gtbl", .{table.name});
        defer table.allocator.free(filename);

        const file = try dir.createFile(filename, .{});
        defer file.close();

        var file_buf: [8192]u8 = undefined;
        var file_writer = file.writer(&file_buf);
        const writer = &file_writer.interface;

        // Write schema
        try writer.print("GRIZZLY_TABLE\n", .{});
        try writer.print("name:{s}\n", .{table.name});
        try writer.print("columns:{d}\n", .{table.schema.columns.len});
        try writer.print("rows:{d}\n", .{table.row_count});

        // Write column definitions
        for (table.schema.columns) |col| {
            try writer.print("col:{s}:{s}\n", .{ col.name, col.data_type.name() });
        }

        // Write data row by row
        try writer.print("DATA\n", .{});
        var row: usize = 0;
        while (row < table.row_count) : (row += 1) {
            for (0..table.columns.len) |col_idx| {
                if (col_idx > 0) try writer.print(",", .{});
                const val = try table.getCell(row, col_idx);
                try writer.print("{any}", .{val});
            }
            try writer.print("\n", .{});
        }
        
        try file_writer.flush();
    }

    /// Load database from disk
    pub fn load(allocator: std.mem.Allocator, dir_path: []const u8) !Database {
        var dir = try std.fs.cwd().openDir(dir_path, .{});
        defer dir.close();

        // Read metadata
        const meta_file = try dir.openFile("db.meta", .{});
        defer meta_file.close();

        var buf_reader = std.io.bufferedReader(meta_file.reader());
        var reader = buf_reader.reader();

        var line_buf: [1024]u8 = undefined;
        
        // Read database name
        const db_line = try reader.readUntilDelimiter(&line_buf, '\n');
        const db_name = db_line[9..]; // Skip "database:"
        
        var db = try Database.init(allocator, db_name);
        errdefer db.deinit();

        // Skip table count line
        _ = try reader.readUntilDelimiter(&line_buf, '\n');

        // Load all .gtbl files
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".gtbl")) {
                try loadTable(&db, dir, entry.name);
            }
        }

        return db;
    }

    fn loadTable(db: *Database, dir: std.fs.Dir, filename: []const u8) !void {
        const file = try dir.openFile(filename, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var reader = buf_reader.reader();

        var line_buf: [4096]u8 = undefined;

        // Read header
        _ = try reader.readUntilDelimiter(&line_buf, '\n'); // GRIZZLY_TABLE
        
        const name_line = try reader.readUntilDelimiter(&line_buf, '\n');
        const table_name = name_line[5..]; // Skip "name:"

        const cols_line = try reader.readUntilDelimiter(&line_buf, '\n');
        const col_count = try std.fmt.parseInt(usize, cols_line[8..], 10);

        _ = try reader.readUntilDelimiter(&line_buf, '\n'); // Skip rows line

        // Read column definitions
        const columns = try db.allocator.alloc(Schema.ColumnDef, col_count);
        defer db.allocator.free(columns);

        for (columns) |*col| {
            const col_line = try reader.readUntilDelimiter(&line_buf, '\n');
            var parts = std.mem.split(u8, col_line[4..], ":");
            const col_name = parts.next().?;
            const type_name = parts.next().?;

            const data_type = parseDataType(type_name);
            col.* = .{
                .name = col_name,
                .data_type = data_type,
            };
        }

        // Create table
        try db.createTable(table_name, columns);
        const table = try db.getTable(table_name);

        // Skip "DATA" line
        _ = try reader.readUntilDelimiter(&line_buf, '\n');

        // Read data rows
        while (reader.readUntilDelimiter(&line_buf, '\n')) |line| {
            if (line.len == 0) continue;
            
            var values = try db.allocator.alloc(Value, col_count);
            defer db.allocator.free(values);

            var parts = std.mem.split(u8, line, ",");
            var idx: usize = 0;
            while (parts.next()) |part| : (idx += 1) {
                const trimmed = std.mem.trim(u8, part, " \t\"");
                values[idx] = try parseValue(trimmed, columns[idx].data_type, db.allocator);
            }

            try table.insertRow(values);
        } else |err| {
            if (err != error.EndOfStream) return err;
        }
    }

    fn parseDataType(name: []const u8) types.DataType {
        if (std.mem.eql(u8, name, "int32")) return .int32;
        if (std.mem.eql(u8, name, "int64")) return .int64;
        if (std.mem.eql(u8, name, "float32")) return .float32;
        if (std.mem.eql(u8, name, "float64")) return .float64;
        if (std.mem.eql(u8, name, "boolean")) return .boolean;
        if (std.mem.eql(u8, name, "string")) return .string;
        if (std.mem.eql(u8, name, "timestamp")) return .timestamp;
        return .int32; // default
    }

    fn parseValue(str: []const u8, data_type: types.DataType, allocator: std.mem.Allocator) !Value {
        return switch (data_type) {
            .int32 => Value{ .int32 = try std.fmt.parseInt(i32, str, 10) },
            .int64 => Value{ .int64 = try std.fmt.parseInt(i64, str, 10) },
            .float32 => Value{ .float32 = try std.fmt.parseFloat(f32, str) },
            .float64 => Value{ .float64 = try std.fmt.parseFloat(f64, str) },
            .boolean => Value{ .boolean = std.mem.eql(u8, str, "true") },
            .string => Value{ .string = try allocator.dupe(u8, str) },
            .timestamp => Value{ .timestamp = try std.fmt.parseInt(i64, str, 10) },
        };
    }
};

test "Database operations" {
    const allocator = std.testing.allocator;
    
    var db = try Database.init(allocator, "test_db");
    defer db.deinit();

    const schema_def = [_]Schema.ColumnDef{
        .{ .name = "id", .data_type = .int32 },
        .{ .name = "name", .data_type = .string },
    };

    try db.createTable("users", &schema_def);
    
    const table = try db.getTable("users");
    try table.insertRow(&[_]Value{
        Value{ .int32 = 1 },
        Value{ .string = "Alice" },
    });

    try std.testing.expectEqual(@as(usize, 1), table.row_count);
}
