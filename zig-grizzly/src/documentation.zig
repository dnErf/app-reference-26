const std = @import("std");
const Model = @import("model.zig").Model;
const ModelRegistry = @import("model.zig").ModelRegistry;
const Database = @import("database.zig").Database;

/// Documentation generation engine for Grizzly models
pub const DocumentationEngine = struct {
    allocator: std.mem.Allocator,
    db: *Database,

    pub const DocTemplate = struct {
        name: []const u8,
        template: []const u8,

        pub fn deinit(self: *DocTemplate, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.template);
        }
    };

    pub const ModelDoc = struct {
        model_name: []const u8,
        description: ?[]const u8,
        owner: ?[]const u8,
        category: ?[]const u8,
        tags: [][]const u8,
        sql_definition: []const u8,
        dependencies: [][]const u8,
        columns: []ColumnDoc,
        last_run: ?i64,
        row_count: ?u64,
        is_incremental: bool,
        freshness_status: []const u8,
        data_quality_score: ?f32,

        pub const ColumnDoc = struct {
            name: []const u8,
            type: []const u8,
            description: ?[]const u8,
            nullable: bool,

            pub fn deinit(self: *ColumnDoc, allocator: std.mem.Allocator) void {
                allocator.free(self.name);
                allocator.free(self.type);
                if (self.description) |desc| {
                    allocator.free(desc);
                }
            }
        };

        pub fn deinit(self: *ModelDoc, allocator: std.mem.Allocator) void {
            allocator.free(self.model_name);
            if (self.description) |desc| {
                allocator.free(desc);
            }
            if (self.owner) |owner| {
                allocator.free(owner);
            }
            if (self.category) |cat| {
                allocator.free(cat);
            }
            for (self.tags) |tag| {
                allocator.free(tag);
            }
            allocator.free(self.tags);
            allocator.free(self.sql_definition);
            for (self.dependencies) |dep| {
                allocator.free(dep);
            }
            allocator.free(self.dependencies);
            for (self.columns) |*col| {
                col.deinit(allocator);
            }
            allocator.free(self.columns);
            allocator.free(self.freshness_status);
        }
    };

    pub fn init(allocator: std.mem.Allocator, db: *Database) DocumentationEngine {
        return DocumentationEngine{
            .allocator = allocator,
            .db = db,
        };
    }

    /// Generate documentation for a single model
    pub fn generateModelDoc(self: *DocumentationEngine, model_name: []const u8) !ModelDoc {
        const model = self.db.models.getModel(model_name) orelse return error.ModelNotFound;

        // Extract column information from SQL (basic parsing)
        const columns = try self.extractColumnsFromSQL(model.sql_definition);

        // Get freshness status
        const freshness_status = try model.getFreshnessStatus(self.allocator);

        // Duplicate tags
        var tags = try std.ArrayListUnmanaged([]const u8).initCapacity(self.allocator, model.tags.items.len);
        for (model.tags.items) |tag| {
            try tags.append(self.allocator, try self.allocator.dupe(u8, tag));
        }

        // Duplicate dependencies
        var deps = try std.ArrayListUnmanaged([]const u8).initCapacity(self.allocator, model.dependencies.items.len);
        for (model.dependencies.items) |dep| {
            try deps.append(self.allocator, try self.allocator.dupe(u8, dep));
        }

        return ModelDoc{
            .model_name = try self.allocator.dupe(u8, model.name),
            .description = if (model.description) |desc| try self.allocator.dupe(u8, desc) else null,
            .owner = if (model.owner) |owner| try self.allocator.dupe(u8, owner) else null,
            .category = if (model.category) |cat| try self.allocator.dupe(u8, cat) else null,
            .tags = try tags.toOwnedSlice(self.allocator),
            .sql_definition = try self.allocator.dupe(u8, model.sql_definition),
            .dependencies = try deps.toOwnedSlice(self.allocator),
            .columns = columns,
            .last_run = model.last_run,
            .row_count = model.row_count,
            .is_incremental = model.is_incremental,
            .freshness_status = freshness_status,
            .data_quality_score = model.data_quality_score,
        };
    }

    /// Generate HTML documentation for all models
    pub fn generateHTMLDocs(self: *DocumentationEngine, output_path: []const u8) !void {
        var docs_dir = try std.fs.cwd().makeOpenPath(output_path, .{});
        defer docs_dir.close();

        // Generate index.html
        try self.generateIndexHTML(docs_dir);

        // Generate individual model pages
        var it = self.db.models.models.iterator();
        while (it.next()) |entry| {
            const model_doc = try self.generateModelDoc(entry.key_ptr.*);
            defer model_doc.deinit(self.allocator);

            try self.generateModelHTML(docs_dir, model_doc);
        }

        // Generate CSS
        try self.generateCSS(docs_dir);
    }

    /// Generate dependency graph in GraphViz DOT format
    pub fn generateDependencyGraph(self: *DocumentationEngine, output_path: []const u8) !void {
        var file = try std.fs.cwd().createFile(output_path, .{});
        defer file.close();

        var writer = file.writer();

        try writer.writeAll("digraph ModelDependencies {\n");
        try writer.writeAll("  rankdir=LR;\n");
        try writer.writeAll("  node [shape=box, style=filled, fillcolor=lightblue];\n\n");

        var it = self.db.models.models.iterator();
        while (it.next()) |entry| {
            const model_name = entry.key_ptr.*;
            const model = entry.value_ptr.*;

            // Write node
            try writer.print("  \"{s}\" [label=\"{s}", .{ model_name, model_name });
            if (model.category) |cat| {
                try writer.print("\\n({s})", .{cat});
            }
            try writer.writeAll("\"];\n");

            // Write edges
            for (model.dependencies.items) |dep| {
                try writer.print("  \"{s}\" -> \"{s}\";\n", .{ dep, model_name });
            }
        }

        try writer.writeAll("}\n");
    }

    fn extractColumnsFromSQL(self: *DocumentationEngine, sql: []const u8) ![]ModelDoc.ColumnDoc {
        var columns = std.ArrayListUnmanaged(ModelDoc.ColumnDoc){};

        // Very basic SQL parsing - look for SELECT clause
        // This is a simplified implementation; a full SQL parser would be better
        var sql_lower = std.ArrayListUnmanaged(u8){};
        defer sql_lower.deinit(self.allocator);

        for (sql) |c| {
            try sql_lower.append(self.allocator, std.ascii.toLower(c));
        }

        const select_pos = std.mem.indexOf(u8, sql_lower.items, "select") orelse return &[_]ModelDoc.ColumnDoc{};
        const from_pos = std.mem.indexOf(u8, sql_lower.items[select_pos..], "from") orelse sql_lower.items.len;
        const select_clause = sql[select_pos + 6 .. select_pos + from_pos];

        // Split by commas and extract column names
        var column_iter = std.mem.split(u8, select_clause, ",");
        while (column_iter.next()) |col_expr| {
            const trimmed = std.mem.trim(u8, col_expr, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            // Extract column name (very basic - assumes format like "column_name" or "table.column_name")
            var name_end = trimmed.len;
            for (trimmed, 0..) |c, i| {
                if (c == ' ' or c == '\t') {
                    name_end = i;
                    break;
                }
            }

            const col_name = trimmed[0..name_end];
            if (std.mem.eql(u8, col_name, "*")) continue; // Skip SELECT *

            try columns.append(self.allocator, ModelDoc.ColumnDoc{
                .name = try self.allocator.dupe(u8, col_name),
                .type = try self.allocator.dupe(u8, "unknown"), // Would need schema analysis
                .description = null, // Would need comment parsing
                .nullable = true, // Default assumption
            });
        }

        return try columns.toOwnedSlice(self.allocator);
    }

    fn generateIndexHTML(self: *DocumentationEngine, docs_dir: std.fs.Dir) !void {
        var file = try docs_dir.createFile("index.html", .{});
        defer file.close();

        var buffer = [_]u8{0} ** 4096;
        var writer = file.writer(&buffer);

        _ = try file.write("<!DOCTYPE html>\n<html>\n<head>\n");
        _ = try file.write("<title>Grizzly DB Model Documentation</title>\n");
        _ = try file.write("<link rel=\"stylesheet\" href=\"styles.css\">\n");
        _ = try file.write("</head>\n<body>\n");

        _ = try file.write("<h1>Grizzly DB Model Documentation</h1>\n");
        _ = try file.write("<p>Generated on ");
        const now = std.time.timestamp();
        const time_str = try std.fmt.allocPrint(self.allocator, "{d}", .{now});
        defer self.allocator.free(time_str);
        _ = try file.write(time_str);
        _ = try file.write("</p>\n");

        // Group models by category
        var categories = std.StringHashMap(std.ArrayListUnmanaged([]const u8)){};
        defer {
            var cat_it = categories.valueIterator();
            while (cat_it.next()) |list| {
                list.deinit(self.allocator);
            }
            categories.deinit();
        }

        var it = self.db.models.models.iterator();
        while (it.next()) |entry| {
            const model = entry.value_ptr.*;
            const category = model.category orelse "Uncategorized";

            const gop = try categories.getOrPut(category);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayListUnmanaged([]const u8){};
            }
            try gop.value_ptr.append(self.allocator, entry.key_ptr.*);
        }

        // Generate table of contents
        var cat_it = categories.iterator();
        while (cat_it.next()) |entry| {
            const category = entry.key_ptr.*;
            const models = entry.value_ptr.*;

            const h2_str = try std.fmt.allocPrint(self.allocator, "<h2>{s}</h2>\n<ul>\n", .{category});
            defer self.allocator.free(h2_str);
            _ = try file.write(h2_str);

            for (models.items) |model_name| {
                const li_str = try std.fmt.allocPrint(self.allocator, "<li><a href=\"{s}.html\">{s}</a></li>\n", .{ model_name, model_name });
                defer self.allocator.free(li_str);
                _ = try file.write(li_str);
            }
            _ = try file.write("</ul>\n");
        }

        _ = try file.write("</body>\n</html>\n");
    }

    fn generateModelHTML(_: *DocumentationEngine, docs_dir: std.fs.Dir, doc: ModelDoc) !void {
        var file = try docs_dir.createFile("models.html", .{ .read = true });
        defer file.close();

        var writer = file.writer(undefined);

        try writer.write("<!DOCTYPE html>\n<html>\n<head>\n");
        try writer.print("<title>{s} - Grizzly DB Documentation</title>\n", .{doc.model_name});
        try writer.write("<link rel=\"stylesheet\" href=\"styles.css\">\n");
        try writer.write("</head>\n<body>\n");

        try writer.print("<h1>{s}</h1>\n", .{doc.model_name});

        if (doc.description) |desc| {
            try writer.print("<p class=\"description\">{s}</p>\n", .{desc});
        }

        // Metadata table
        try writer.write("<h2>Metadata</h2>\n<table>\n");
        if (doc.owner) |owner| {
            try writer.print("<tr><th>Owner</th><td>{s}</td></tr>\n", .{owner});
        }
        if (doc.category) |cat| {
            try writer.print("<tr><th>Category</th><td>{s}</td></tr>\n", .{cat});
        }
        try writer.print("<tr><th>Type</th><td>{s}</td></tr>\n", .{if (doc.is_incremental) "Incremental" else "Full Refresh"});
        try writer.print("<tr><th>Freshness</th><td>{s}</td></tr>\n", .{doc.freshness_status});
        if (doc.data_quality_score) |score| {
            try writer.print("<tr><th>Data Quality</th><td>{d:.2}%</td></tr>\n", .{score * 100.0});
        }
        if (doc.row_count) |count| {
            try writer.print("<tr><th>Row Count</th><td>{d}</td></tr>\n", .{count});
        }
        try writer.write("</table>\n");

        // Tags
        if (doc.tags.len > 0) {
            try writer.write("<h2>Tags</h2>\n<div class=\"tags\">\n");
            for (doc.tags) |tag| {
                try writer.print("<span class=\"tag\">{s}</span>\n", .{tag});
            }
            try writer.write("</div>\n");
        }

        // Columns
        if (doc.columns.len > 0) {
            try writer.write("<h2>Columns</h2>\n<table>\n");
            try writer.write("<tr><th>Name</th><th>Type</th><th>Nullable</th><th>Description</th></tr>\n");
            for (doc.columns) |col| {
                try writer.print("<tr><td>{s}</td><td>{s}</td><td>{s}</td><td>{s}</td></tr>\n", .{ col.name, col.type, if (col.nullable) "Yes" else "No", col.description orelse "" });
            }
            try writer.write("</table>\n");
        }

        // Dependencies
        if (doc.dependencies.len > 0) {
            try writer.write("<h2>Dependencies</h2>\n<ul>\n");
            for (doc.dependencies) |dep| {
                try writer.print("<li><a href=\"{s}.html\">{s}</a></li>\n", .{ dep, dep });
            }
            try writer.write("</ul>\n");
        }

        // SQL Definition
        try writer.write("<h2>SQL Definition</h2>\n<pre><code>");
        try writer.write(doc.sql_definition);
        try writer.write("</code></pre>\n");

        try writer.write("<p><a href=\"index.html\">← Back to Index</a></p>\n");
        try writer.write("</body>\n</html>\n");
    }

    fn generateCSS(_: *DocumentationEngine, docs_dir: std.fs.Dir) !void {
        var file = try docs_dir.createFile("styles.css", .{});
        defer file.close();

        var writer = file.writer(undefined);

        try writer.write("body { font-family: Arial, sans-serif; margin: 40px; }\n");
        try writer.write("h1 { color: #2c3e50; }\n");
        try writer.write("h2 { color: #34495e; border-bottom: 2px solid #ecf0f1; padding-bottom: 5px; }\n");
        try writer.write(".description { font-style: italic; color: #7f8c8d; margin-bottom: 20px; }\n");
        try writer.write("table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }\n");
        try writer.write("th, td { border: 1px solid #bdc3c7; padding: 8px; text-align: left; }\n");
        try writer.write("th { background-color: #ecf0f1; }\n");
        try writer.write("pre { background-color: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; }\n");
        try writer.write("code { font-family: 'Courier New', monospace; }\n");
        try writer.write(".tags { margin-bottom: 20px; }\n");
        try writer.write(".tag { display: inline-block; background-color: #3498db; color: white; padding: 4px 8px; margin: 2px; border-radius: 3px; font-size: 0.9em; }\n");
        try writer.write("ul { margin-bottom: 20px; }\n");
    }
};
