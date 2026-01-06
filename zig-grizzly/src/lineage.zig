const std = @import("std");
const Model = @import("model.zig").Model;
const Database = @import("database.zig").Database;

/// Column-level lineage tracking for Grizzly models
pub const LineageEngine = struct {
    allocator: std.mem.Allocator,
    db: *Database,

    pub const ColumnLineage = struct {
        column_name: []const u8,
        source_model: []const u8,
        source_column: ?[]const u8, // null if computed/derived
        transformation: ?[]const u8, // SQL expression that created this column
        dependencies: []ColumnDependency,

        pub const ColumnDependency = struct {
            model_name: []const u8,
            column_name: []const u8,

            pub fn deinit(self: *ColumnDependency, allocator: std.mem.Allocator) void {
                allocator.free(self.model_name);
                allocator.free(self.column_name);
            }
        };

        pub fn deinit(self: *ColumnLineage, allocator: std.mem.Allocator) void {
            allocator.free(self.column_name);
            allocator.free(self.source_model);
            if (self.source_column) |col| {
                allocator.free(col);
            }
            if (self.transformation) |trans| {
                allocator.free(trans);
            }
            for (self.dependencies) |*dep| {
                dep.deinit(allocator);
            }
            allocator.free(self.dependencies);
        }
    };

    pub const LineageGraph = struct {
        nodes: std.StringHashMap(ColumnLineage),
        edges: std.ArrayListUnmanaged(LineageEdge),

        pub const LineageEdge = struct {
            from_model: []const u8,
            from_column: []const u8,
            to_model: []const u8,
            to_column: []const u8,
            transformation: ?[]const u8,

            pub fn deinit(self: *LineageEdge, allocator: std.mem.Allocator) void {
                allocator.free(self.from_model);
                allocator.free(self.from_column);
                allocator.free(self.to_model);
                allocator.free(self.to_column);
                if (self.transformation) |trans| {
                    allocator.free(trans);
                }
            }
        };

        pub fn init(allocator: std.mem.Allocator) LineageGraph {
            return LineageGraph{
                .nodes = std.StringHashMap(ColumnLineage).init(allocator),
                .edges = std.ArrayListUnmanaged(LineageEdge){},
            };
        }

        pub fn deinit(self: *LineageGraph, allocator: std.mem.Allocator) void {
            var node_it = self.nodes.valueIterator();
            while (node_it.next()) |lineage| {
                lineage.deinit(allocator);
            }
            self.nodes.deinit();

            for (self.edges.items) |*edge| {
                edge.deinit(allocator);
            }
            self.edges.deinit(allocator);
        }

        /// Export graph as GraphViz DOT format
        pub fn toGraphViz(self: LineageGraph, allocator: std.mem.Allocator) ![]const u8 {
            var result = std.ArrayList(u8).init(allocator);
            defer result.deinit();

            var writer = result.writer();

            try writer.writeAll("digraph ColumnLineage {\n");
            try writer.writeAll("  rankdir=TB;\n");
            try writer.writeAll("  node [shape=box, style=filled, fillcolor=lightgreen];\n\n");

            // Write nodes
            var node_it = self.nodes.iterator();
            while (node_it.next()) |entry| {
                const lineage = entry.value_ptr.*;
                try writer.print("  \"{s}.{s}\" [label=\"{s}\\n({s})\"];\n", .{ lineage.source_model, lineage.column_name, lineage.column_name, lineage.source_model });
            }

            try writer.writeAll("\n");

            // Write edges
            for (self.edges.items) |edge| {
                try writer.print("  \"{s}.{s}\" -> \"{s}.{s}\"", .{ edge.from_model, edge.from_column, edge.to_model, edge.to_column });

                if (edge.transformation) |trans| {
                    try writer.print(" [label=\"{s}\"]", .{trans});
                }

                try writer.writeAll(";\n");
            }

            try writer.writeAll("}\n");

            return result.toOwnedSlice();
        }
    };

    pub fn init(allocator: std.mem.Allocator, db: *Database) LineageEngine {
        return LineageEngine{
            .allocator = allocator,
            .db = db,
        };
    }

    /// Build complete lineage graph for all models
    pub fn buildLineageGraph(self: *LineageEngine) !LineageGraph {
        var graph = LineageGraph.init(self.allocator);

        // Process each model
        var model_it = self.db.models.models.iterator();
        while (model_it.next()) |entry| {
            const model_name = entry.key_ptr.*;
            const model = entry.value_ptr.*;

            try self.analyzeModelLineage(&graph, model_name, model);
        }

        return graph;
    }

    /// Get lineage for a specific column in a specific model
    pub fn getColumnLineage(self: *LineageEngine, model_name: []const u8, column_name: []const u8) !?ColumnLineage {
        const model = self.db.models.getModel(model_name) orelse return null;

        // Parse the SQL to find column lineage
        return try self.analyzeColumnLineage(model, column_name);
    }

    /// Get all upstream dependencies for a column
    pub fn getUpstreamDependencies(self: *LineageEngine, model_name: []const u8, column_name: []const u8) ![]ColumnLineage.ColumnDependency {
        var deps = std.ArrayListUnmanaged(ColumnLineage.ColumnDependency){};

        // Start with the target column
        var to_visit = std.ArrayListUnmanaged([]const u8).init(self.allocator);
        defer to_visit.deinit(self.allocator);
        try to_visit.append(self.allocator, try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ model_name, column_name }));

        var visited = std.StringHashMap(void).init(self.allocator);
        defer visited.deinit();

        while (to_visit.items.len > 0) {
            const current = to_visit.orderedRemove(0);
            defer self.allocator.free(current);

            if (visited.contains(current)) continue;
            try visited.put(try self.allocator.dupe(u8, current), {});

            // Parse model.column
            const dot_pos = std.mem.indexOf(u8, current, ".") orelse continue;
            const curr_model = current[0..dot_pos];
            const curr_column = current[dot_pos + 1 ..];

            const lineage = try self.getColumnLineage(curr_model, curr_column);
            if (lineage) |lin| {
                defer lin.deinit(self.allocator);

                // Add dependencies to visit list
                for (lin.dependencies) |dep| {
                    const dep_key = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ dep.model_name, dep.column_name });
                    defer self.allocator.free(dep_key);

                    if (!visited.contains(dep_key)) {
                        try to_visit.append(self.allocator, try self.allocator.dupe(u8, dep_key));
                    }

                    // Add to result
                    try deps.append(self.allocator, ColumnLineage.ColumnDependency{
                        .model_name = try self.allocator.dupe(u8, dep.model_name),
                        .column_name = try self.allocator.dupe(u8, dep.column_name),
                    });
                }
            }
        }

        return try deps.toOwnedSlice(self.allocator);
    }

    /// Analyze lineage for a single model
    fn analyzeModelLineage(self: *LineageEngine, graph: *LineageGraph, model_name: []const u8, model: *const Model) !void {
        // Extract column information from SELECT clause
        const columns = try self.extractColumnsFromSelect(model.sql_definition);

        for (columns) |col| {
            defer col.deinit(self.allocator);

            // Create lineage node
            const lineage_key = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ model_name, col.name });
            defer self.allocator.free(lineage_key);

            const lineage = try self.analyzeColumnLineage(model, col.name);
            if (lineage) |lin| {
                try graph.nodes.put(try self.allocator.dupe(u8, lineage_key), lin);

                // Create edges for dependencies
                for (lin.dependencies) |dep| {
                    try graph.edges.append(self.allocator, LineageGraph.LineageEdge{
                        .from_model = try self.allocator.dupe(u8, dep.model_name),
                        .from_column = try self.allocator.dupe(u8, dep.column_name),
                        .to_model = try self.allocator.dupe(u8, model_name),
                        .to_column = try self.allocator.dupe(u8, col.name),
                        .transformation = if (col.expression) |expr| try self.allocator.dupe(u8, expr) else null,
                    });
                }
            }
        }
    }

    /// Analyze lineage for a specific column
    fn analyzeColumnLineage(self: *LineageEngine, model: *const Model, column_name: []const u8) !?ColumnLineage {
        // Parse the SELECT clause to find the column expression
        const select_expr = try self.findColumnExpression(model.sql_definition, column_name);
        if (select_expr == null) return null;

        const expr = select_expr.?;

        // Analyze the expression to find dependencies
        var dependencies = std.ArrayListUnmanaged(ColumnLineage.ColumnDependency){};

        // Simple parsing - look for table.column references
        var i: usize = 0;
        while (i < expr.len) {
            // Look for word.word pattern (table.column)
            if (i + 1 < expr.len and std.ascii.isAlphabetic(expr[i])) {
                var j = i;
                while (j < expr.len and (std.ascii.isAlphabetic(expr[j]) or std.ascii.isDigit(expr[j]) or expr[j] == '_')) {
                    j += 1;
                }

                if (j < expr.len and expr[j] == '.') {
                    const table_start = i;
                    const table_end = j;
                    i = j + 1;

                    j = i;
                    while (j < expr.len and (std.ascii.isAlphabetic(expr[j]) or std.ascii.isDigit(expr[j]) or expr[j] == '_')) {
                        j += 1;
                    }

                    const table_name = expr[table_start..table_end];
                    const col_name = expr[i..j];

                    // Check if this table is in our dependencies
                    for (model.dependencies.items) |dep| {
                        if (std.mem.eql(u8, dep, table_name)) {
                            try dependencies.append(self.allocator, ColumnLineage.ColumnDependency{
                                .model_name = try self.allocator.dupe(u8, table_name),
                                .column_name = try self.allocator.dupe(u8, col_name),
                            });
                            break;
                        }
                    }

                    i = j;
                } else {
                    i = j;
                }
            } else {
                i += 1;
            }
        }

        return ColumnLineage{
            .column_name = try self.allocator.dupe(u8, column_name),
            .source_model = try self.allocator.dupe(u8, model.name),
            .source_column = null, // Would need more sophisticated analysis
            .transformation = try self.allocator.dupe(u8, expr),
            .dependencies = try dependencies.toOwnedSlice(self.allocator),
        };
    }

    fn extractColumnsFromSelect(self: *LineageEngine, sql: []const u8) ![]ColumnInfo {
        var columns = std.ArrayListUnmanaged(ColumnInfo){};

        // Find SELECT clause
        const select_lower = "select ";
        const from_lower = " from ";

        var sql_lower = std.ArrayListUnmanaged(u8){};
        defer sql_lower.deinit(self.allocator);

        for (sql) |c| {
            try sql_lower.append(self.allocator, std.ascii.toLower(c));
        }

        const select_pos = std.mem.indexOf(u8, sql_lower.items, select_lower) orelse return &[_]ColumnInfo{};
        const from_pos = std.mem.indexOf(u8, sql_lower.items[select_pos..], from_lower);
        const select_end = if (from_pos) |pos| select_pos + pos else sql_lower.items.len;

        const select_clause = sql[select_pos + select_lower.len .. select_end];

        // Parse column expressions
        var col_iter = std.mem.split(u8, select_clause, ",");
        while (col_iter.next()) |col_expr| {
            const trimmed = std.mem.trim(u8, col_expr, &std.ascii.whitespace);
            if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "*")) continue;

            // Extract column name and expression
            const as_pos = std.mem.indexOf(u8, trimmed, " AS ");
            const as_pos_lower = if (as_pos == null) std.mem.indexOf(u8, trimmed, " as ") else as_pos;

            if (as_pos_lower) |pos| {
                const expr = std.mem.trim(u8, trimmed[0..pos], &std.ascii.whitespace);
                const name = std.mem.trim(u8, trimmed[pos + 4 ..], &std.ascii.whitespace);
                try columns.append(self.allocator, ColumnInfo{
                    .name = try self.allocator.dupe(u8, name),
                    .expression = try self.allocator.dupe(u8, expr),
                });
            } else {
                // No AS clause - extract name from expression
                const name = try self.extractColumnName(trimmed);
                try columns.append(self.allocator, ColumnInfo{
                    .name = name,
                    .expression = try self.allocator.dupe(u8, trimmed),
                });
            }
        }

        return try columns.toOwnedSlice(self.allocator);
    }

    fn findColumnExpression(self: *LineageEngine, sql: []const u8, column_name: []const u8) !?[]const u8 {
        const columns = try self.extractColumnsFromSelect(sql);
        defer {
            for (columns) |*col| {
                col.deinit(self.allocator);
            }
            self.allocator.free(columns);
        }

        for (columns) |col| {
            if (std.mem.eql(u8, col.name, column_name)) {
                return try self.allocator.dupe(u8, col.expression);
            }
        }

        return null;
    }

    fn extractColumnName(self: *LineageEngine, expr: []const u8) ![]const u8 {
        // Simple extraction - take the last identifier
        var words = std.mem.split(u8, expr, &std.ascii.whitespace);
        var last_word: ?[]const u8 = null;

        while (words.next()) |word| {
            if (word.len > 0 and std.ascii.isAlphabetic(word[0])) {
                last_word = word;
            }
        }

        return if (last_word) |w| try self.allocator.dupe(u8, w) else try self.allocator.dupe(u8, expr);
    }

    const ColumnInfo = struct {
        name: []const u8,
        expression: []const u8,

        pub fn deinit(self: *ColumnInfo, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.expression);
        }
    };
};
