const std = @import("std");
const zig_grizzly = @import("root.zig");
const Database = zig_grizzly.Database;
const QueryEngine = zig_grizzly.QueryEngine;
const QueryResult = zig_grizzly.QueryResult;
const Table = zig_grizzly.Table;
const Value = zig_grizzly.Value;
const Schema = zig_grizzly.Schema;

pub const CTE = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    sql: []const u8,
    materialized_result: ?QueryResult, // For recursive CTEs or when needed
    is_recursive: bool,
    references: std.ArrayList([]const u8), // Other CTEs this one references

    pub fn init(allocator: std.mem.Allocator, name: []const u8, sql: []const u8, is_recursive: bool) !CTE {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const sql_copy = try allocator.dupe(u8, sql);
        errdefer allocator.free(sql_copy);

        return CTE{
            .allocator = allocator,
            .name = name_copy,
            .sql = sql_copy,
            .materialized_result = null,
            .is_recursive = is_recursive,
            .references = try std.ArrayList([]const u8).initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *CTE, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.sql);
        if (self.materialized_result) |*result| {
            result.deinit();
        }
        for (self.references.items) |ref| {
            allocator.free(ref);
        }
        self.references.deinit(allocator);
    }

    pub fn execute(self: *CTE, db: *Database, cte_context: *CTEContext) !*Table {
        // For recursive CTEs, we need special handling
        if (self.is_recursive) {
            if (self.materialized_result == null) {
                self.materialized_result = try self.executeRecursive(db, cte_context);
            }
            return &self.materialized_result.?.table;
        }

        // Check if we have circular references
        if (cte_context.isBeingExecuted(self.name)) {
            return error.CircularCTEReference;
        }

        try cte_context.markExecuting(self.name);
        defer cte_context.unmarkExecuting();

        // Execute the query if not already materialized
        if (self.materialized_result == null) {
            var query_engine = QueryEngine.init(db.allocator, db, &db.functions);

            if (db.audit_log) |log| {
                query_engine.attachAuditLog(log);
            }

            const result = try query_engine.execute(self.sql);
            switch (result) {
                .table => self.materialized_result = result,
                .message => return error.CTEQueryReturnedMessage,
                .rows_affected => return error.CTEQueryReturnedRowsAffected,
            }
        }

        return &self.materialized_result.?.table;
    }

    fn executeRecursive(_: *CTE, db: *Database, _: *CTEContext) !QueryResult {
        // Recursive CTE implementation
        // This is a simplified version - real implementation would need:
        // 1. Working table for intermediate results
        // 2. Recursive term execution
        // 3. UNION ALL combination
        // 4. Cycle detection

        var result_table = try Table.init(db.allocator, "recursive_result", &[_]Schema.ColumnDef{});
        errdefer result_table.deinit(db.allocator);

        // Placeholder implementation
        // In reality, we'd parse the recursive CTE structure and execute iteratively
        return QueryResult{ .table = result_table };
    }

    pub fn addReference(self: *CTE, cte_name: []const u8) !void {
        const ref_copy = try self.allocator.dupe(u8, cte_name);
        errdefer self.allocator.free(ref_copy);
        try self.references.append(ref_copy);
    }
};

pub const CTEContext = struct {
    allocator: std.mem.Allocator,
    ctes: std.StringHashMap(*CTE),
    execution_stack: std.ArrayListUnmanaged([]u8), // For cycle detection

    pub fn init(allocator: std.mem.Allocator) CTEContext {
        return CTEContext{
            .allocator = allocator,
            .ctes = std.StringHashMap(*CTE).init(allocator),
            .execution_stack = std.ArrayListUnmanaged([]u8){},
        };
    }

    pub fn deinit(self: *CTEContext) void {
        var it = self.ctes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr);
        }
        self.ctes.deinit();

        for (self.execution_stack.items) |name| {
            // TODO: Fix allocator.free issue
            // self.allocator.free(name);
            _ = name;
        }
        self.execution_stack.deinit(self.allocator);
    }

    pub fn addCTE(self: *CTEContext, name: []const u8, sql: []const u8, is_recursive: bool) !void {
        if (self.ctes.contains(name)) return error.CTERealreadyExists;

        const cte = try self.allocator.create(CTE);
        errdefer self.allocator.destroy(cte);

        cte.* = try CTE.init(self.allocator, name, sql, is_recursive);
        errdefer cte.deinit(self.allocator);

        try self.ctes.put(name, cte);
    }

    pub fn getCTE(self: *CTEContext, name: []const u8) ?*CTE {
        return self.ctes.get(name);
    }

    pub fn executeCTE(self: *CTEContext, name: []const u8, db: *Database) !Table {
        const cte = self.ctes.get(name) orelse return error.CTENotFound;
        return try cte.execute(db, self);
    }

    pub fn markExecuting(self: *CTEContext, name: []const u8) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        try self.execution_stack.append(self.allocator, name_copy);
    }

    pub fn unmarkExecuting(self: *CTEContext) void {
        if (self.execution_stack.items.len > 0) {
            const name = self.execution_stack.pop();
            // TODO: Fix allocator.free issue
            // self.allocator.free(name);
            _ = name;
        }
    }

    pub fn isBeingExecuted(self: *CTEContext, name: []const u8) bool {
        for (self.execution_stack.items) |executing| {
            if (std.mem.eql(u8, executing, name)) return true;
        }
        return false;
    }

    pub fn resolveDependencies(self: *CTEContext) !void {
        // Analyze CTE queries to find references to other CTEs
        // This is a simplified implementation
        var it = self.ctes.iterator();
        while (it.next()) |entry| {
            const cte_name = entry.key_ptr.*;
            var cte = entry.value_ptr;

            // Check if this CTE's query references other CTEs
            // In a real implementation, we'd parse the SQL and look for CTE references
            var other_it = self.ctes.iterator();
            while (other_it.next()) |other_entry| {
                const other_name = other_entry.key_ptr.*;
                if (!std.mem.eql(u8, cte_name, other_name)) {
                    // Check if the SQL contains the other CTE name
                    if (std.mem.indexOf(u8, cte.query.original_sql, other_name) != null) {
                        try cte.addReference(other_name);
                    }
                }
            }
        }
    }

    pub fn getExecutionOrder(self: *CTEContext, allocator: std.mem.Allocator) ![][]const u8 {
        // Topological sort of CTEs based on dependencies
        var result = std.ArrayList([]const u8).init(allocator);
        errdefer result.deinit();

        var visited = std.StringHashMap(bool).init(allocator);
        defer visited.deinit();

        var visiting = std.StringHashMap(bool).init(allocator);
        defer visiting.deinit();

        // Initialize visited map
        var it = self.ctes.iterator();
        while (it.next()) |entry| {
            try visited.put(entry.key_ptr.*, false);
            try visiting.put(entry.key_ptr.*, false);
        }

        // Perform topological sort
        it = self.ctes.iterator();
        while (it.next()) |entry| {
            if (!visited.get(entry.key_ptr.*).?) {
                try self.topologicalSort(entry.key_ptr.*, &result, &visited, &visiting);
            }
        }

        return result.toOwnedSlice();
    }

    fn topologicalSort(self: *CTEContext, name: []const u8, result: *std.ArrayList([]const u8), visited: *std.StringHashMap(bool), visiting: *std.StringHashMap(bool)) !void {
        try visiting.put(name, true);

        const cte = self.ctes.get(name).?;
        for (cte.references.items) |ref| {
            if (visiting.get(ref).?) {
                return error.CircularCTEDependency;
            }
            if (!visited.get(ref).?) {
                try self.topologicalSort(ref, result, visited, visiting);
            }
        }

        try visiting.put(name, false);
        try visited.put(name, true);
        try result.append(try self.allocator.dupe(u8, name));
    }
};

test "CTE creation and basic operations" {
    const allocator = std.testing.allocator;

    var context = CTEContext.init(allocator);
    defer context.deinit();

    try context.addCTE("test_cte", "SELECT 1 as id", false);

    const cte = context.getCTE("test_cte").?;
    try std.testing.expectEqualStrings("test_cte", cte.name);
    try std.testing.expectEqual(false, cte.is_recursive);
}

test "CTE dependency resolution" {
    const allocator = std.testing.allocator;

    var context = CTEContext.init(allocator);
    defer context.deinit();

    // Add CTEs with dependencies
    try context.addCTE("base_cte", "SELECT 1 as id", false);
    try context.addCTE("dependent_cte", "SELECT * FROM base_cte WHERE id > 0", false);

    try context.resolveDependencies();

    const dependent = context.getCTE("dependent_cte").?;
    try std.testing.expectEqual(@as(usize, 1), dependent.references.items.len);
    try std.testing.expectEqualStrings("base_cte", dependent.references.items[0]);
}

test "CTE execution order" {
    const allocator = std.testing.allocator;

    var context = CTEContext.init(allocator);
    defer context.deinit();

    // Add CTEs with dependencies
    try context.addCTE("cte_a", "SELECT 1 as id", false);
    try context.addCTE("cte_b", "SELECT * FROM cte_a", false);
    try context.addCTE("cte_c", "SELECT * FROM cte_b", false);

    try context.resolveDependencies();

    const order = try context.getExecutionOrder(allocator);
    defer {
        for (order) |name| {
            allocator.free(name);
        }
        allocator.free(order);
    }

    try std.testing.expectEqual(@as(usize, 3), order.len);
    // Should be: cte_a, cte_b, cte_c (or cte_a, cte_b, cte_c)
    try std.testing.expect(std.mem.eql(u8, order[0], "cte_a"));
}
