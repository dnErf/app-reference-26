const std = @import("std");
const Database = @import("database.zig").Database;

/// Analyzes SQL queries to extract dependencies on tables and models
pub const DependencyAnalyzer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DependencyAnalyzer {
        return DependencyAnalyzer{
            .allocator = allocator,
        };
    }

    /// Extract table and model dependencies from SQL
    pub fn extractDependencies(self: *const DependencyAnalyzer, sql: []const u8, db: *Database) !std.StringHashMap(void) {
        var deps = std.StringHashMap(void).init(self.allocator);
        defer deps.deinit();

        // Convert to lowercase for case-insensitive matching
        var sql_lower = std.ArrayListUnmanaged(u8){};
        defer sql_lower.deinit(self.allocator);

        for (sql) |c| {
            try sql_lower.append(self.allocator, std.ascii.toLower(c));
        }

        // Extract dependencies from FROM clauses
        try self.extractFromDependencies(sql_lower.items, sql, &deps, db);

        // Extract dependencies from JOIN clauses
        try self.extractJoinDependencies(sql_lower.items, sql, &deps, db);

        // Extract dependencies from subqueries
        try self.extractSubqueryDependencies(sql_lower.items, sql, &deps, db);

        return deps;
    }

    fn extractFromDependencies(self: *const DependencyAnalyzer, sql_lower: []const u8, original_sql: []const u8, deps: *std.StringHashMap(void), db: *Database) !void {
        _ = db;
        var i: usize = 0;
        while (i < sql_lower.len) {
            // Look for "from "
            if (i + 5 <= sql_lower.len and std.mem.eql(u8, sql_lower[i .. i + 5], "from ")) {
                i += 5;
                // Skip whitespace
                while (i < sql_lower.len and std.ascii.isWhitespace(sql_lower[i])) i += 1;
                // Read table/model name
                if (i < sql_lower.len) {
                    const table_name = try self.extractIdentifier(sql_lower, original_sql, &i);
                    // if (self.isValidDependency(table_name, db)) {
                    const owned_name = try self.allocator.dupe(u8, table_name);
                    try deps.put(owned_name, {});
                    // }
                }
            } else {
                i += 1;
            }
        }
    }

    fn extractJoinDependencies(self: *const DependencyAnalyzer, sql_lower: []const u8, original_sql: []const u8, deps: *std.StringHashMap(void), db: *Database) !void {
        _ = db;
        var i: usize = 0;
        while (i < sql_lower.len) {
            // Look for "join "
            if (i + 5 <= sql_lower.len and std.mem.eql(u8, sql_lower[i .. i + 5], "join ")) {
                i += 5;
                // Skip whitespace
                while (i < sql_lower.len and std.ascii.isWhitespace(sql_lower[i])) i += 1;
                // Read table/model name
                if (i < sql_lower.len) {
                    const table_name = try self.extractIdentifier(sql_lower, original_sql, &i);
                    // if (self.isValidDependency(table_name, db)) {
                    const owned_name = try self.allocator.dupe(u8, table_name);
                    try deps.put(owned_name, {});
                    // }
                }
            } else {
                i += 1;
            }
        }
    }

    fn extractSubqueryDependencies(_: *const DependencyAnalyzer, _: []const u8, _: []const u8, _: *std.StringHashMap(void), _: *Database) !void {
        // TODO: Implement subquery dependency analysis
        // For now, skip to avoid recursion complexity
    }

    fn extractIdentifier(_: *const DependencyAnalyzer, sql_lower: []const u8, original_sql: []const u8, i: *usize) ![]const u8 {
        const start = i.*;
        while (i.* < sql_lower.len and (std.ascii.isAlphanumeric(sql_lower[i.*]) or sql_lower[i.*] == '_')) {
            i.* += 1;
        }
        return original_sql[start..i.*];
    }

    fn isValidDependency(_: *const DependencyAnalyzer, name: []const u8, db: *Database) bool {
        // Check if it's a table
        if (db.tables.contains(name)) return true;
        // Check if it's a model
        if (db.models.getModel(name) != null) return true;
        // Check if it's a view
        if (db.views.getView(name) != null) return true;
        // Check if it's a materialized view
        if (db.materialized_views.getMaterializedView(name) != null) return true;
        return false;
    }

    /// Build dependency graph from all models in the database
    pub fn buildModelDependencyGraph(self: *const DependencyAnalyzer, db: *Database) !std.StringHashMap(std.ArrayListUnmanaged([]const u8)) {
        var graph = std.StringHashMap(std.ArrayListUnmanaged([]const u8)).init(self.allocator);
        errdefer {
            var it = graph.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            graph.deinit();
        }

        // Get all model names
        const model_names = try db.models.listModels(self.allocator);
        defer self.allocator.free(model_names);

        for (model_names) |model_name| {
            const model = db.models.getModel(model_name) orelse continue;
            var deps = try self.extractDependencies(model.sql_definition, db);
            defer deps.deinit();

            var dep_list = std.ArrayListUnmanaged([]const u8){};
            errdefer dep_list.deinit(self.allocator);

            var it = deps.iterator();
            while (it.next()) |entry| {
                // Only include other models as dependencies (not tables directly)
                if (db.models.getModel(entry.key_ptr.*) != null) {
                    try dep_list.append(self.allocator, try self.allocator.dupe(u8, entry.key_ptr.*));
                }
            }

            const model_name_copy = try self.allocator.dupe(u8, model_name);
            try graph.put(model_name_copy, dep_list);
        }

        return graph;
    }

    /// Analyze column-level dependencies (for future lineage features)
    pub fn extractColumnDependencies(self: *const DependencyAnalyzer, sql: []const u8, allocator: std.mem.Allocator) !std.StringHashMap(std.ArrayListUnmanaged([]const u8)) {
        var column_deps = std.StringHashMap(std.ArrayListUnmanaged([]const u8)).init(allocator);
        errdefer {
            var it = column_deps.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(allocator);
            }
            column_deps.deinit();
        }

        // Basic column dependency analysis
        // This is a simplified version - a full implementation would need proper SQL parsing

        var sql_lower = std.ArrayListUnmanaged(u8){};
        defer sql_lower.deinit(allocator);

        for (sql) |c| {
            try sql_lower.append(allocator, std.ascii.toLower(c));
        }

        // Look for SELECT clause
        var i: usize = 0;
        while (i < sql_lower.items.len) {
            if (i + 7 <= sql_lower.items.len and std.mem.eql(u8, sql_lower.items[i .. i + 7], "select ")) {
                i += 7;
                // Parse column expressions
                try self.parseSelectColumns(sql_lower.items, sql, &i, &column_deps, allocator);
                break;
            }
            i += 1;
        }

        return column_deps;
    }

    fn parseSelectColumns(self: *const DependencyAnalyzer, sql_lower: []const u8, original_sql: []const u8, i: *usize, column_deps: *std.StringHashMap(std.ArrayListUnmanaged([]const u8)), allocator: std.mem.Allocator) !void {
        // Skip whitespace
        while (i.* < sql_lower.len and std.ascii.isWhitespace(sql_lower[i.*])) i.* += 1;

        // Parse until FROM or end
        while (i.* < sql_lower.len) {
            if (i.* + 5 <= sql_lower.len and std.mem.eql(u8, sql_lower.items[i.* .. i.* + 5], "from ")) {
                break;
            }

            // Parse column expression
            const col_start = i.*;
            var paren_depth: usize = 0;
            var in_string = false;

            while (i.* < sql_lower.len) {
                if (sql_lower[i.*] == '(' and !in_string) paren_depth += 1;
                if (sql_lower[i.*] == ')' and !in_string) {
                    if (paren_depth == 0) break;
                    paren_depth -= 1;
                }
                if (sql_lower[i.*] == '\'') in_string = !in_string;
                if (sql_lower[i.*] == ',' and paren_depth == 0 and !in_string) break;
                i.* += 1;
            }

            const col_expr = std.mem.trim(u8, original_sql[col_start..i.*], &std.ascii.whitespace);
            if (col_expr.len > 0) {
                try self.analyzeColumnExpression(col_expr, column_deps, allocator);
            }

            // Skip comma
            if (i.* < sql_lower.len and sql_lower[i.*] == ',') i.* += 1;
        }
    }

    fn analyzeColumnExpression(_: *const DependencyAnalyzer, expr: []const u8, column_deps: *std.StringHashMap(std.ArrayListUnmanaged([]const u8)), allocator: std.mem.Allocator) !void {
        // Extract column references from expression
        // This is a very basic implementation

        var deps = std.ArrayListUnmanaged([]const u8){};
        defer deps.deinit(allocator);

        // Look for dot notation (table.column)
        var i: usize = 0;
        while (i < expr.len) {
            if (expr[i] == '.') {
                // Found a dot, look backwards for table/column name
                var start = i - 1;
                while (start > 0 and (std.ascii.isAlphanumeric(expr[start]) or expr[start] == '_')) {
                    start -= 1;
                }
                if (start < i - 1) {
                    const table_ref = expr[start + 1 .. i];
                    try deps.append(allocator, try allocator.dupe(u8, table_ref));
                }
            }
            i += 1;
        }

        // Also look for simple column names
        i = 0;
        while (i < expr.len) {
            if (std.ascii.isAlpha(expr[i]) or expr[i] == '_') {
                const start = i;
                while (i < expr.len and (std.ascii.isAlphanumeric(expr[i]) or expr[i] == '_')) {
                    i += 1;
                }
                const word = expr[start..i];
                // Skip SQL keywords
                if (!isSqlKeyword(word)) {
                    try deps.append(allocator, try allocator.dupe(u8, word));
                }
            } else {
                i += 1;
            }
        }

        // For now, just store the expression as the key
        // In a full implementation, we'd parse the AS clause for aliases
        const expr_copy = try allocator.dupe(u8, expr);
        try column_deps.put(expr_copy, deps);
    }
};

fn isSqlKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{
        "select", "from", "where", "join", "on",       "group", "by",   "having", "order", "limit",
        "and",    "or",   "not",   "as",   "distinct", "count", "sum",  "avg",    "max",   "min",
        "case",   "when", "then",  "else", "end",      "null",  "true", "false",
    };

    for (keywords) |kw| {
        if (std.ascii.eqlIgnoreCase(word, kw)) return true;
    }
    return false;
}
