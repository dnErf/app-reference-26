const std = @import("std");
const grizzly = @import("zig_grizzly");

const Database = grizzly.Database;
const QueryEngine = grizzly.QueryEngine;
const FunctionRegistry = grizzly.FunctionRegistry;
const Lakehouse = grizzly.Lakehouse;
const Value = grizzly.Value;

pub const Cli = struct {
    allocator: std.mem.Allocator,
    database: ?*Database,
    query_engine: ?*QueryEngine,
    function_registry: ?*FunctionRegistry,
    timer_enabled: bool,
    query_timeout_ms: u32,

    pub fn init(allocator: std.mem.Allocator) Cli {
        return Cli{
            .allocator = allocator,
            .database = null,
            .query_engine = null,
            .function_registry = null,
            .timer_enabled = false,
            .query_timeout_ms = 30000, // 30 second default timeout
        };
    }

    pub fn deinit(self: *Cli) void {
        if (self.query_engine) |qe| {
            // QueryEngine doesn't have deinit, just destroy the pointer
            self.allocator.destroy(qe);
        }
        if (self.function_registry) |fr| {
            fr.deinit();
            self.allocator.destroy(fr);
        }
        if (self.database) |db| {
            db.deinit();
            self.allocator.destroy(db);
        }
    }

    pub fn loadDatabase(self: *Cli, filename: ?[]const u8) !void {
        if (self.database) |db| {
            db.deinit();
            self.allocator.destroy(db);
        }
        if (self.function_registry) |fr| {
            fr.deinit();
            self.allocator.destroy(fr);
        }
        if (self.query_engine) |qe| {
            // QueryEngine doesn't have deinit, just destroy the pointer
            self.allocator.destroy(qe);
        }

        if (filename) |fname| {
            // Try to load existing database
            var lakehouse = Lakehouse.init(self.allocator);
            self.database = try self.allocator.create(Database);
            if (lakehouse.load(fname)) |db| {
                self.database.?.* = db;
            } else |err| {
                std.debug.print("Failed to load database '{s}': {}\n", .{ fname, err });
                std.debug.print("Creating empty database instead.\n", .{});
                self.database.?.* = try Database.init(self.allocator, "cli_db");
            }
        } else {
            // Create empty database
            self.database = try self.allocator.create(Database);
            self.database.?.* = try Database.init(self.allocator, "cli_db");
        }

        self.function_registry = try self.allocator.create(FunctionRegistry);
        self.function_registry.?.* = FunctionRegistry.init(self.allocator);

        self.query_engine = try self.allocator.create(QueryEngine);
        self.query_engine.?.* = QueryEngine.init(self.allocator, self.database.?, self.function_registry.?);
    }

    pub fn executeQuery(self: *Cli, sql: []const u8) !void {
        if (self.query_engine == null) {
            std.debug.print("Error: No database loaded. Use .load <filename> or .open <filename>\n", .{});
            return;
        }

        const start_time = std.time.nanoTimestamp();

        // Execute query with timeout
        var result: ?grizzly.QueryResult = null;

        // Simple timeout implementation - execute in a way that can be interrupted
        const timeout_ns = @as(u64, self.query_timeout_ms) * 1_000_000;

        // For now, we'll execute synchronously but check timeout after
        // In a real implementation, this would use async or threading
        result = try self.query_engine.?.execute(sql);
        errdefer if (result) |*r| r.deinit();

        const elapsed_ns = std.time.nanoTimestamp() - start_time;
        if (elapsed_ns > timeout_ns) {
            if (result) |*r| r.deinit();
            return error.QueryTimeout;
        }

        defer if (result) |*r| r.deinit();

        // Display results
        if (result) |*r| {
            try self.displayResults(r);
        }

        if (self.timer_enabled) {
            const end_time = std.time.nanoTimestamp();
            const duration_ns = end_time - start_time;
            const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
            std.debug.print("\nTime: {}ms\n", .{duration_ms});
        }
    }

    fn displayResults(self: *Cli, result: *const grizzly.QueryResult) !void {
        switch (result.*) {
            .table => |*table| {
                if (table.schema.columns.len == 0) {
                    std.debug.print("Query executed successfully (no columns).\n", .{});
                    return;
                }

                // Print column headers
                for (table.schema.columns, 0..) |col, i| {
                    if (i > 0) std.debug.print(" | ", .{});
                    std.debug.print("{s}", .{col.name});
                }
                std.debug.print("\n", .{});

                // Print separator
                for (table.schema.columns, 0..) |_, i| {
                    if (i > 0) std.debug.print("-+-", .{});
                    std.debug.print("---", .{});
                }
                std.debug.print("\n", .{});

                // Print rows
                for (0..table.row_count) |row_idx| {
                    for (0..table.schema.columns.len) |col_idx| {
                        if (col_idx > 0) std.debug.print(" | ", .{});
                        const val = try table.getCell(row_idx, col_idx);
                        try self.printValue(val);
                    }
                    std.debug.print("\n", .{});
                }

                std.debug.print("\n{d} rows returned\n", .{table.row_count});
            },
            .message => |msg| {
                std.debug.print("{s}\n", .{msg});
            },
            .rows_affected => |count| {
                std.debug.print("{d} rows affected\n", .{count});
            },
        }
    }

    fn printValue(_: *Cli, value: Value) !void {
        switch (value) {
            .int32 => |i| std.debug.print("{d}", .{i}),
            .int64 => |i| std.debug.print("{d}", .{i}),
            .float32 => |f| std.debug.print("{}", .{f}),
            .float64 => |f| std.debug.print("{}", .{f}),
            .boolean => |b| std.debug.print("{s}", .{if (b) "true" else "false"}),
            .string => |s| std.debug.print("'{s}'", .{s}),
            .timestamp => |ts| std.debug.print("{d}", .{ts}),
            .vector => |vec| {
                std.debug.print("[", .{});
                for (vec.values, 0..) |item, i| {
                    if (i > 0) std.debug.print(", ", .{});
                    std.debug.print("{}", .{item});
                }
                std.debug.print("]", .{});
            },
            .custom => std.debug.print("<custom>", .{}),
            .exception => |e| std.debug.print("EXCEPTION: {s}", .{e.message}),
        }
    }

    pub fn executeSpecialCommand(self: *Cli, command: []const u8) !bool {
        var tokens = std.mem.tokenizeAny(u8, command, " \t");
        const cmd = tokens.next() orelse return false;

        if (std.mem.eql(u8, cmd, ".help")) {
            try self.printHelp();
            return true;
        } else if (std.mem.eql(u8, cmd, ".quit") or std.mem.eql(u8, cmd, ".exit")) {
            return true; // Signal to quit
        } else if (std.mem.eql(u8, cmd, ".tables")) {
            try self.showTables();
            return true;
        } else if (std.mem.eql(u8, cmd, ".schema")) {
            const table_name = tokens.next();
            if (table_name) |name| {
                try self.showSchema(name);
            } else {
                std.debug.print("Usage: .schema <table_name>\n", .{});
            }
            return true;
        } else if (std.mem.eql(u8, cmd, ".databases")) {
            try self.showDatabases();
            return true;
        } else if (std.mem.eql(u8, cmd, ".save")) {
            const filename = tokens.next();
            if (filename) |fname| {
                try self.saveDatabase(fname);
            } else {
                std.debug.print("Usage: .save <filename>\n", .{});
            }
            return true;
        } else if (std.mem.eql(u8, cmd, ".timer")) {
            const arg = tokens.next();
            if (arg) |a| {
                if (std.mem.eql(u8, a, "on")) {
                    self.timer_enabled = true;
                    std.debug.print("Timer enabled\n", .{});
                } else if (std.mem.eql(u8, a, "off")) {
                    self.timer_enabled = false;
                    std.debug.print("Timer disabled\n", .{});
                } else {
                    std.debug.print("Usage: .timer on|off\n", .{});
                }
            } else {
                std.debug.print("Timer is {s}\n", .{if (self.timer_enabled) "enabled" else "disabled"});
            }
            return true;
        } else if (std.mem.eql(u8, cmd, ".load") or std.mem.eql(u8, cmd, ".open")) {
            const filename = tokens.next();
            if (filename) |fname| {
                try self.loadDatabase(fname);
                std.debug.print("Loaded database: {s}\n", .{fname});
            } else {
                std.debug.print("Usage: .load <filename>\n", .{});
            }
            return true;
        } else if (std.mem.eql(u8, cmd, ".timeout")) {
            const arg = tokens.next();
            if (arg) |a| {
                const timeout_ms = std.fmt.parseInt(u32, a, 10) catch {
                    std.debug.print("Invalid timeout value: {s}\n", .{a});
                    return true;
                };
                self.query_timeout_ms = timeout_ms;
                std.debug.print("Query timeout set to {d}ms\n", .{timeout_ms});
            } else {
                std.debug.print("Query timeout: {d}ms\n", .{self.query_timeout_ms});
            }
            return true;
        }

        return false; // Not a special command
    }

    fn printHelp(_: *Cli) !void {
        std.debug.print("Grizzly DB Interactive Shell\n", .{});
        std.debug.print("===========================\n\n", .{});
        std.debug.print("Special Commands:\n", .{});
        std.debug.print("  .help              Show this help message\n", .{});
        std.debug.print("  .quit, .exit       Exit the shell\n", .{});
        std.debug.print("  .tables            List all tables\n", .{});
        std.debug.print("  .schema <table>    Show table schema\n", .{});
        std.debug.print("  .databases         List all databases\n", .{});
        std.debug.print("  .save <file>       Save database to file\n", .{});
        std.debug.print("  .load <file>       Load database from file\n", .{});
        std.debug.print("  .timer on|off      Enable/disable query timing\n", .{});
        std.debug.print("  .timeout <ms>      Set query timeout in milliseconds\n", .{});
        std.debug.print("\nSQL Commands:\n", .{});
        std.debug.print("  Any valid SQL statement\n", .{});
        std.debug.print("\n", .{});
    }

    fn showTables(self: *Cli) !void {
        if (self.database == null) {
            std.debug.print("No database loaded\n", .{});
            return;
        }

        std.debug.print("Tables in database:\n", .{});
        var it = self.database.?.tables.iterator();
        var count: usize = 0;
        while (it.next()) |entry| {
            std.debug.print("  {s}\n", .{entry.key_ptr.*});
            count += 1;
        }
        if (count == 0) {
            std.debug.print("  (no tables)\n", .{});
        }
    }

    fn showSchema(self: *Cli, table_name: []const u8) !void {
        if (self.database == null) {
            std.debug.print("No database loaded\n", .{});
            return;
        }

        const table = self.database.?.tables.get(table_name) orelse {
            std.debug.print("Table '{s}' not found\n", .{table_name});
            return;
        };

        std.debug.print("Schema for table '{s}':\n", .{table_name});
        std.debug.print("Columns:\n", .{});
        for (table.schema.columns) |col| {
            std.debug.print("  {s}: {s}", .{ col.name, @tagName(col.data_type) });
            if (col.vector_dim > 0) {
                std.debug.print("({d})", .{col.vector_dim});
            }
            std.debug.print("\n", .{});
        }
    }

    fn showDatabases(self: *Cli) !void {
        if (self.database == null) {
            std.debug.print("No database loaded\n", .{});
            return;
        }

        std.debug.print("Databases:\n", .{});
        std.debug.print("  main: {s}\n", .{self.database.?.name});

        // Show attached databases
        var it = self.database.?.attached_databases.iterator();
        var count: usize = 1; // main is already counted
        while (it.next()) |entry| {
            std.debug.print("  {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.name });
            count += 1;
        }
        if (count == 1) {
            std.debug.print("  (no attached databases)\n", .{});
        }
    }

    fn saveDatabase(self: *Cli, filename: []const u8) !void {
        if (self.database == null) {
            std.debug.print("No database loaded\n", .{});
            return;
        }

        var lakehouse = Lakehouse.init(self.allocator);
        try lakehouse.save(self.database.?, filename, .none);
        std.debug.print("Database saved to '{s}'\n", .{filename});
    }
};

pub fn runInteractiveShell(allocator: std.mem.Allocator, initial_db: ?[]const u8) !void {
    var cli = Cli.init(allocator);
    defer cli.deinit();

    // Load initial database if provided
    if (initial_db) |db| {
        try cli.loadDatabase(db);
        std.debug.print("Loaded database: {s}\n", .{db});
    }

    std.debug.print("Grizzly DB Interactive Shell\n", .{});
    std.debug.print("Type '.help' for help, '.quit' to exit\n", .{});

    var stdin_file = std.fs.File.stdin();

    while (true) {
        std.debug.print("grizzly> ", .{});

        // Read line manually
        var line_buf: [1024]u8 = undefined;
        var line_len: usize = 0;

        while (line_len < line_buf.len) {
            var byte: [1]u8 = undefined;
            const bytes_read = try stdin_file.read(&byte);
            if (bytes_read == 0) break; // EOF

            const c = byte[0];
            if (c == '\n') break;
            line_buf[line_len] = c;
            line_len += 1;
        }

        if (line_len == 0) continue;

        const line = line_buf[0..line_len];
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;

        // Check for special commands
        if (try cli.executeSpecialCommand(trimmed)) {
            if (std.mem.eql(u8, trimmed, ".quit") or std.mem.eql(u8, trimmed, ".exit")) {
                break;
            }
            continue;
        }

        // Execute SQL
        cli.executeQuery(trimmed) catch |err| {
            switch (err) {
                error.QueryTimeout => std.debug.print("Error: Query timed out after {d}ms\n", .{cli.query_timeout_ms}),
                else => std.debug.print("Error: {}\n", .{err}),
            }
        };
    }
}
