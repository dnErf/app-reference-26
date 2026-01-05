const std = @import("std");
const tls_mod = @import("tls.zig");
const url_mod = @import("url.zig");

const TLS = tls_mod.TLS;
const URL = url_mod.URL;

/// HTTP method
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
};

/// HTTP status
pub const Status = struct {
    code: u16,
    reason: []const u8,
};

/// HTTP headers
pub const Headers = std.StringHashMap([]const u8);

/// HTTP request
pub const Request = struct {
    method: Method,
    url: URL,
    headers: Headers,
    body: ?[]const u8 = null,
    timeout_ms: u32 = 30000, // 30 second default
    follow_redirects: bool = true,
    max_redirects: u8 = 5,
};

/// HTTP response
pub const Response = struct {
    status: Status,
    headers: Headers,
    body: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
        self.body.deinit();
    }
};

/// HTTP client
pub const Client = struct {
    allocator: std.mem.Allocator,
    tls: TLS,
    connection_pool: std.StringHashMap(*Connection),

    const Connection = struct {
        stream: std.net.Stream,
        last_used: i64,
        host: []const u8,
        port: u16,
        is_https: bool,
    };

    pub fn init(allocator: std.mem.Allocator) !Client {
        return Client{
            .allocator = allocator,
            .tls = try TLS.init(allocator),
            .connection_pool = std.StringHashMap(*Connection).init(allocator),
        };
    }

    pub fn deinit(self: *Client) void {
        // Clean up connection pool
        var it = self.connection_pool.valueIterator();
        while (it.next()) |conn| {
            conn.stream.close();
            self.allocator.free(conn.host);
            self.allocator.destroy(conn);
        }
        self.connection_pool.deinit();
        self.tls.deinit();
    }

    /// Send an HTTP request
    pub fn send(self: *Client, request: Request) !Response {
        var current_url = request.url;
        var redirects: u8 = 0;

        while (redirects <= request.max_redirects) {
            const response = try self.sendSingle(request.method, current_url, request.headers, request.body, request.timeout_ms);

            if (request.follow_redirects and isRedirect(response.status.code)) {
                if (response.headers.get("location")) |location| {
                    current_url = try URL.parse(location);
                    redirects += 1;
                    response.deinit();
                    continue;
                }
            }

            return response;
        }

        return error.TooManyRedirects;
    }

    fn sendSingle(self: *Client, method: Method, url: URL, headers: Headers, body: ?[]const u8, timeout_ms: u32) !Response {
        const is_https = std.mem.eql(u8, url.scheme, "https");
        const port = url.port orelse if (is_https) 443 else 80;

        // Get or create connection
        const conn_key = try std.fmt.allocPrint(self.allocator, "{s}:{d}:{s}", .{ url.host, port, if (is_https) "https" else "http" });
        defer self.allocator.free(conn_key);

        var stream = try self.getConnection(url.host, port, is_https);

        // Send request
        try self.sendRequest(&stream, method, url, headers, body);

        // Read response with timeout
        return try self.readResponse(&stream, timeout_ms);
    }

    fn getConnection(self: *Client, host: []const u8, port: u16, is_https: bool) !std.net.Stream {
        _ = self;
        // For now, create new connection each time
        // TODO: Implement connection pooling
        const address = try std.net.Address.resolveIp(host, port);
        const stream = try std.net.tcpConnectToAddress(address);

        if (is_https) {
            // Wrap with TLS
            // TODO: Implement TLS handshake
        }

        return stream;
    }

    fn sendRequest(self: *Client, stream: *std.net.Stream, method: Method, url: URL, headers: Headers, body: ?[]const u8) !void {
        _ = self;
        const method_str = switch (method) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };

        // Send request line
        try stream.writer().print("{s} {s} HTTP/1.1\r\n", .{ method_str, url.path });

        // Send Host header
        try stream.writer().print("Host: {s}\r\n", .{url.host});

        // Send other headers
        var it = headers.iterator();
        while (it.next()) |entry| {
            try stream.writer().print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        // Send Content-Length if body present
        if (body) |b| {
            try stream.writer().print("Content-Length: {d}\r\n", .{b.len});
        }

        // End headers
        try stream.writer().print("\r\n", .{});

        // Send body
        if (body) |b| {
            try stream.writer().writeAll(b);
        }
    }

    fn readResponse(self: *Client, stream: *std.net.Stream, timeout_ms: u32) !Response {
        var response = Response{
            .status = undefined,
            .headers = Headers.init(self.allocator),
            .body = std.ArrayList(u8).init(self.allocator),
            .allocator = self.allocator,
        };
        errdefer response.deinit();

        // Read status line with timeout
        const status_line = try self.readLineWithTimeout(stream, timeout_ms);
        defer self.allocator.free(status_line);

        // Parse status
        var status_parts = std.mem.split(u8, status_line, " ");
        _ = status_parts.next(); // HTTP/1.1
        const code_str = status_parts.next() orelse return error.InvalidResponse;
        const reason = status_parts.next() orelse "";

        response.status.code = try std.fmt.parseInt(u16, code_str, 10);
        response.status.reason = try self.allocator.dupe(u8, reason);

        // Read headers
        while (true) {
            const line = try self.readLineWithTimeout(stream, timeout_ms);
            defer self.allocator.free(line);

            if (line.len == 0) break; // End of headers

            if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
                const name = std.mem.trim(u8, line[0..colon_pos], " ");
                const value = std.mem.trim(u8, line[colon_pos + 1 ..], " ");
                try response.headers.put(try self.allocator.dupe(u8, name), try self.allocator.dupe(u8, value));
            }
        }

        // Read body
        if (response.headers.get("transfer-encoding")) |encoding| {
            if (std.mem.eql(u8, encoding, "chunked")) {
                try self.readChunkedBody(stream, &response.body, timeout_ms);
            }
        } else if (response.headers.get("content-length")) |length_str| {
            const length = try std.fmt.parseInt(usize, length_str, 10);
            try response.body.resize(length);
            _ = try self.readWithTimeout(stream, response.body.items, timeout_ms);
        }

        return response;
    }

    fn readLineWithTimeout(self: *Client, stream: *std.net.Stream, _: u32) ![]u8 {
        // TODO: Implement timeout reading
        return try stream.reader().readUntilDelimiterAlloc(self.allocator, '\n', 4096);
    }

    fn readWithTimeout(self: *Client, stream: *std.net.Stream, buffer: []u8, _: u32) !usize {
        // TODO: Implement timeout reading
        _ = self;
        return try stream.reader().read(buffer);
    }

    fn readChunkedBody(self: *Client, _: *std.net.Stream, _: *std.ArrayList(u8), _: u32) !void {
        // TODO: Implement chunked transfer encoding
        _ = self;
    }

    fn isRedirect(code: u16) bool {
        return code >= 300 and code < 400;
    }
};
