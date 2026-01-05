const std = @import("std");
const http_client = @import("../src/http_client.zig");
const url_mod = @import("../src/url.zig");
const extension_api = @import("../src/extension_api.zig");

const Client = http_client.Client;
const Request = http_client.Request;
const Response = http_client.Response;
const Method = http_client.Method;
const URL = url_mod.URL;

/// HTTPFS Extension for remote data access over HTTPS
pub const HttpfsExtension = struct {
    allocator: std.mem.Allocator,
    client: Client,
    config: Config,

    const Config = struct {
        timeout_ms: u32 = 30000,
        max_redirects: u8 = 5,
        follow_redirects: bool = true,
        user_agent: []const u8 = "GrizzlyDB/1.0",
    };

    pub fn init(allocator: std.mem.Allocator, config_data: ?[]const u8) !HttpfsExtension {
        var config = Config{};

        // Parse config if provided
        if (config_data) |data| {
            // TODO: Parse JSON config
            _ = data;
        }

        const client = try Client.init(allocator);

        return HttpfsExtension{
            .allocator = allocator,
            .client = client,
            .config = config,
        };
    }

    pub fn deinit(self: *HttpfsExtension) void {
        self.client.deinit();
    }

    /// Handle HTTPFS-specific queries
    pub fn handleQuery(self: *HttpfsExtension, query: []const u8) !extension_api.ResultSet {
        // Parse HTTPFS query syntax
        // Examples:
        // SELECT * FROM 'https://example.com/data.csv'
        // SELECT * FROM read_csv('https://example.com/data.csv')
        // COPY (SELECT * FROM table) TO 'https://example.com/upload' WITH (format 'csv')

        if (std.mem.startsWith(u8, query, "SELECT")) {
            return try self.handleSelectQuery(query);
        } else if (std.mem.startsWith(u8, query, "COPY")) {
            return try self.handleCopyQuery(query);
        }

        return error.UnsupportedQuery;
    }

    fn handleSelectQuery(self: *HttpfsExtension, query: []const u8) !extension_api.ResultSet {
        // Parse URL from query like: SELECT * FROM 'https://example.com/data.csv'
        const url_start = std.mem.indexOf(u8, query, "'https://") orelse
            std.mem.indexOf(u8, query, "'http://") orelse
            return error.InvalidQuery;

        const url_end = std.mem.indexOfPos(u8, query, url_start + 1, "'") orelse
            return error.InvalidQuery;

        const url_str = query[url_start + 1 .. url_end];

        // Parse URL
        const url = try URL.parse(self.allocator, url_str);
        defer url.deinit(self.allocator);

        // Determine format from URL extension or query hints
        const format = try self.detectFormat(url_str, query);

        // Make HTTP request
        var request = Request{
            .method = .GET,
            .url = url,
            .timeout_ms = self.config.timeout_ms,
            .follow_redirects = self.config.follow_redirects,
            .max_redirects = self.config.max_redirects,
        };

        // Add User-Agent header
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        try headers.put("User-Agent", self.config.user_agent);

        request.headers = headers;

        const response = try self.client.request(request);
        defer response.deinit();

        if (response.status.code >= 400) {
            return error.HttpError;
        }

        // Parse response based on format
        return try self.parseResponseData(response, format);
    }

    fn handleCopyQuery(self: *HttpfsExtension, query: []const u8) !extension_api.ResultSet {
        // Parse COPY query to extract destination URL
        // COPY (SELECT * FROM table) TO 'https://example.com/upload' WITH (format 'csv')

        const to_pos = std.mem.indexOf(u8, query, " TO ") orelse return error.InvalidQuery;
        const url_start = std.mem.indexOfPos(u8, query, to_pos, "'https://") orelse
            std.mem.indexOfPos(u8, query, to_pos, "'http://") orelse
            return error.InvalidQuery;

        const url_end = std.mem.indexOfPos(u8, query, url_start + 1, "'") orelse
            return error.InvalidQuery;

        const url_str = query[url_start + 1 .. url_end];

        // Parse URL
        const url = try URL.parse(self.allocator, url_str);
        defer url.deinit(self.allocator);

        // Extract data from subquery (simplified - would need full query parsing)
        const data = "simulated data"; // TODO: Execute subquery and format data

        // Make HTTP POST request
        var request = Request{
            .method = .POST,
            .url = url,
            .body = data,
            .timeout_ms = self.config.timeout_ms,
            .follow_redirects = self.config.follow_redirects,
            .max_redirects = self.config.max_redirects,
        };

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        try headers.put("User-Agent", self.config.user_agent);
        try headers.put("Content-Type", "text/plain"); // TODO: Determine from format

        request.headers = headers;

        const response = try self.client.request(request);
        defer response.deinit();

        // Return success/failure result
        var result_set = extension_api.ResultSet.init(self.allocator);
        errdefer result_set.deinit();

        // Add single row with status
        var row = std.ArrayList(extension_api.Value).init(self.allocator);
        defer row.deinit();

        const status_msg = if (response.status.code < 300) "SUCCESS" else "FAILED";
        try row.append(extension_api.Value{ .string = try self.allocator.dupe(u8, status_msg) });

        try result_set.rows.append(row);

        return result_set;
    }

    fn detectFormat(self: *HttpfsExtension, url_str: []const u8, query: []const u8) ![]const u8 {
        _ = self;
        _ = query; // TODO: Check for format hints in query

        // Detect format from URL extension
        if (std.mem.endsWith(u8, url_str, ".csv")) {
            return "csv";
        } else if (std.mem.endsWith(u8, url_str, ".json")) {
            return "json";
        } else if (std.mem.endsWith(u8, url_str, ".parquet")) {
            return "parquet";
        } else {
            return "csv"; // Default
        }
    }

    fn parseResponseData(self: *HttpfsExtension, response: Response, format: []const u8) !extension_api.ResultSet {
        var result_set = extension_api.ResultSet.init(self.allocator);
        errdefer result_set.deinit();

        if (std.mem.eql(u8, format, "csv")) {
            try self.parseCsvData(&result_set, response.body.items);
        } else if (std.mem.eql(u8, format, "json")) {
            try self.parseJsonData(&result_set, response.body.items);
        } else {
            return error.UnsupportedFormat;
        }

        return result_set;
    }

    fn parseCsvData(self: *HttpfsExtension, result_set: *extension_api.ResultSet, data: []const u8) !void {
        var lines = std.mem.split(u8, data, "\n");

        // Parse header row
        if (lines.next()) |header_line| {
            var headers = std.mem.split(u8, header_line, ",");
            while (headers.next()) |header| {
                const trimmed = std.mem.trim(u8, header, " \r");
                try result_set.columns.append(try self.allocator.dupe(u8, trimmed));
            }
        }

        // Parse data rows
        while (lines.next()) |line| {
            const trimmed_line = std.mem.trim(u8, line, " \r");
            if (trimmed_line.len == 0) continue;

            var row = std.ArrayList(extension_api.Value).init(self.allocator);
            errdefer {
                for (row.items) |*value| {
                    value.deinit(self.allocator);
                }
                row.deinit();
            }

            var fields = std.mem.split(u8, trimmed_line, ",");
            while (fields.next()) |field| {
                const trimmed = std.mem.trim(u8, field, " \"");
                try row.append(extension_api.Value{ .string = try self.allocator.dupe(u8, trimmed) });
            }

            try result_set.rows.append(row);
        }
    }

    fn parseJsonData(self: *HttpfsExtension, result_set: *extension_api.ResultSet, data: []const u8) !void {
        // Simplified JSON parsing - assumes array of objects
        // TODO: Implement proper JSON parsing
        _ = result_set;
        _ = data;
        return error.NotImplemented;
    }

    /// Get extension capabilities
    pub fn getCapabilities(self: *const HttpfsExtension) extension_api.ExtensionCapabilities {
        _ = self;
        return extension_api.ExtensionCapabilities{
            .supports_read = true,
            .supports_write = true,
            .supported_formats = &[_][]const u8{ "csv", "json" },
            .requires_auth = false,
        };
    }
};

// Extension interface implementation
pub const extension = extension_api.Extension{
    .name = "httpfs",
    .version = "1.0.0",
    .description = "HTTP File System extension for remote data access over HTTPS",

    .init = initExtension,
    .deinit = deinitExtension,
    .handleQuery = handleExtensionQuery,
    .getCapabilities = getExtensionCapabilities,
};

fn initExtension(allocator: std.mem.Allocator, config_data: ?[]const u8) !*anyopaque {
    const ext = try allocator.create(HttpfsExtension);
    ext.* = try HttpfsExtension.init(allocator, config_data);
    return ext;
}

fn deinitExtension(ptr: *anyopaque) void {
    const ext = @as(*HttpfsExtension, @ptrCast(@alignCast(ptr)));
    ext.deinit();
    ext.allocator.destroy(ext);
}

fn handleExtensionQuery(ptr: *anyopaque, query: []const u8) !extension_api.ResultSet {
    const ext = @as(*HttpfsExtension, @ptrCast(@alignCast(ptr)));
    return try ext.handleQuery(query);
}

fn getExtensionCapabilities(ptr: *anyopaque) extension_api.ExtensionCapabilities {
    const ext = @as(*const HttpfsExtension, @ptrCast(@alignCast(ptr)));
    return ext.getCapabilities();
}
