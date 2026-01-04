const std = @import("std");
const types = @import("types.zig");
const schema_mod = @import("schema.zig");
const table_mod = @import("table.zig");
const database_mod = @import("database.zig");

const DataType = types.DataType;
const Schema = schema_mod.Schema;
const Table = table_mod.Table;
const Database = database_mod.Database;

/// Options for loading data from files
pub const LoadOptions = struct {
    table_name: ?[]const u8 = null,
    header: bool = true,
    delimiter: u8 = ',',
    quote_char: u8 = '"',
    skip_rows: usize = 0,
    max_rows: ?usize = null,
    columns: ?[]const []const u8 = null,
    sample_size: usize = 1000,
    infer_types: bool = true,
};

/// Options for saving data to files
pub const SaveOptions = struct {
    compression: CompressionType = .none,
    row_group_size: usize = 10000,
    include_metadata: bool = true,
    include_header: bool = true,
};

pub const CompressionType = enum {
    none,
    gzip,
    snappy,
    zstd,
    lz4,
};

/// Format loader interface - all format implementations must conform to this
pub const FormatLoader = struct {
    name: []const u8,
    extensions: []const []const u8,

    // Function pointers for format operations
    detectFn: *const fn (file_path: []const u8) bool,
    inferSchemaFn: *const fn (allocator: std.mem.Allocator, file_path: []const u8, opts: LoadOptions) anyerror!Schema,
    loadFn: *const fn (allocator: std.mem.Allocator, file_path: []const u8, opts: LoadOptions) anyerror!*Table,
    saveFn: ?*const fn (allocator: std.mem.Allocator, table: *Table, file_path: []const u8, opts: SaveOptions) anyerror!void,
};

/// Central registry for file format loaders
pub const FormatRegistry = struct {
    allocator: std.mem.Allocator,
    loaders: std.StringHashMap(*const FormatLoader),

    pub fn init(allocator: std.mem.Allocator) FormatRegistry {
        return FormatRegistry{
            .allocator = allocator,
            .loaders = std.StringHashMap(*const FormatLoader).init(allocator),
        };
    }

    pub fn deinit(self: *FormatRegistry) void {
        self.loaders.deinit();
    }

    /// Register a format loader
    pub fn register(self: *FormatRegistry, loader: *const FormatLoader) !void {
        try self.loaders.put(loader.name, loader);
    }

    /// Detect format by file extension
    pub fn detectByExtension(self: *FormatRegistry, file_path: []const u8) ?*const FormatLoader {
        // Find extension
        var i: usize = file_path.len;
        while (i > 0) {
            i -= 1;
            if (file_path[i] == '.') {
                const ext = file_path[i + 1 ..];

                // Check each loader's extensions
                var iter = self.loaders.valueIterator();
                while (iter.next()) |loader| {
                    for (loader.*.extensions) |supported_ext| {
                        if (std.ascii.eqlIgnoreCase(ext, supported_ext)) {
                            return loader.*;
                        }
                    }
                }
                break;
            }
            if (file_path[i] == '/') break;
        }

        return null;
    }

    /// Detect format by file content (magic bytes)
    pub fn detectByContent(self: *FormatRegistry, file_path: []const u8) !?*const FormatLoader {
        var iter = self.loaders.valueIterator();
        while (iter.next()) |loader| {
            if (loader.*.detectFn(file_path)) {
                return loader.*;
            }
        }
        return null;
    }

    /// Auto-detect format and return appropriate loader
    pub fn detectFormat(self: *FormatRegistry, file_path: []const u8) !*const FormatLoader {
        // Try extension first (faster)
        if (self.detectByExtension(file_path)) |loader| {
            return loader;
        }

        // Fall back to content detection
        if (try self.detectByContent(file_path)) |loader| {
            return loader;
        }

        return error.UnknownFormat;
    }

    /// Load file using appropriate format loader
    pub fn loadFile(self: *FormatRegistry, file_path: []const u8, opts: LoadOptions) !*Table {
        const loader = try self.detectFormat(file_path);
        return try loader.loadFn(self.allocator, file_path, opts);
    }

    /// Save table to file using appropriate format
    pub fn saveFile(self: *FormatRegistry, table: *Table, file_path: []const u8, opts: SaveOptions) !void {
        const loader = try self.detectFormat(file_path);
        if (loader.saveFn) |saveFn| {
            try saveFn(self.allocator, table, file_path, opts);
        } else {
            return error.SaveNotSupported;
        }
    }

    /// Infer schema from file
    pub fn inferSchema(self: *FormatRegistry, file_path: []const u8, opts: LoadOptions) !Schema {
        const loader = try self.detectFormat(file_path);
        return try loader.inferSchemaFn(self.allocator, file_path, opts);
    }
};

/// Helper function to get file extension
pub fn getExtension(file_path: []const u8) ?[]const u8 {
    var i: usize = file_path.len;
    while (i > 0) {
        i -= 1;
        if (file_path[i] == '.') {
            return file_path[i + 1 ..];
        }
        if (file_path[i] == '/') break;
    }
    return null;
}

/// Check if file exists
pub fn fileExists(file_path: []const u8) bool {
    const file = std.fs.cwd().openFile(file_path, .{}) catch return false;
    file.close();
    return true;
}

test "Format registry basic operations" {
    const allocator = std.testing.allocator;

    var registry = FormatRegistry.init(allocator);
    defer registry.deinit();

    // Test should compile without loaders registered
    try std.testing.expect(registry.loaders.count() == 0);
}

test "Get extension" {
    try std.testing.expectEqualStrings("csv", getExtension("data.csv").?);
    try std.testing.expectEqualStrings("json", getExtension("/path/to/file.json").?);
    try std.testing.expectEqualStrings("parquet", getExtension("data.parquet").?);
    try std.testing.expect(getExtension("noextension") == null);
}
