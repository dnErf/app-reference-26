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
    retry_count: u8 = 3, // Number of retries on failure
    retry_delay_ms: u32 = 1000, // Delay between retries
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
    max_connections: usize = 10,
    connection_timeout_ms: u32 = 5000, // 5 seconds

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
        while (it.next()) |conn_ptr| {
            const conn = conn_ptr.*;
            conn.stream.close();
            self.allocator.free(conn.host);
            self.allocator.destroy(conn);
        }
        self.connection_pool.deinit();
        self.tls.deinit();
    }

    /// Send an HTTP request
    pub fn send(self: *Client, req: Request) !Response {
        var attempt: u8 = 0;
        while (attempt <= req.retry_count) {
            var current_url = req.url;
            var redirects: u8 = 0;

            while (redirects <= req.max_redirects) {
                const response = self.sendSingle(req.method, current_url, req.headers, req.body, req.timeout_ms) catch |err| {
                    if (attempt < req.retry_count and self.shouldRetry(err)) {
                        attempt += 1;
                        std.time.sleep(req.retry_delay_ms * 1000000); // Convert to nanoseconds
                        break;
                    } else {
                        return err;
                    }
                };

                if (req.follow_redirects and isRedirect(response.status.code)) {
                    if (response.headers.get("location")) |location| {
                        current_url = try URL.parse(location);
                        redirects += 1;
                        response.deinit();
                        continue;
                    }
                }

                return response;
            }

            if (redirects > req.max_redirects) {
                return error.TooManyRedirects;
            }
        }

        return error.MaxRetriesExceeded;
    }

    fn sendSingle(self: *Client, method: Method, url: URL, headers: Headers, body: ?[]const u8, timeout_ms: u32) !Response {
        const is_https = std.mem.eql(u8, url.scheme, "https");
        const port: u16 = url.port orelse if (is_https) 443 else 80;

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
        const conn_key = try std.fmt.allocPrint(self.allocator, "{s}:{d}:{s}", .{ host, port, if (is_https) "https" else "http" });
        defer self.allocator.free(conn_key);

        // Check for existing connection in pool
        if (self.connection_pool.getPtr(conn_key)) |conn_ptr| {
            const now = std.time.timestamp();
            const age_ms = (now - conn_ptr.*.last_used) * 1000;
            if (age_ms < self.connection_timeout_ms) {
                // Connection is still fresh, reuse it
                conn_ptr.*.last_used = now;
                return conn_ptr.*.stream;
            } else {
                // Connection is stale, remove it
                conn_ptr.*.stream.close();
                self.allocator.free(conn_ptr.*.host);
                self.allocator.destroy(conn_ptr);
                _ = self.connection_pool.remove(conn_key);
            }
        }

        // Create new connection
        const address = try std.net.Address.resolveIp(host, port);
        const stream = try std.net.tcpConnectToAddress(address);

        if (is_https) {
            // TODO: Implement TLS handshake
            // try self.tls.handshake(&stream, host);
        }

        // Add to pool if not at max capacity
        if (self.connection_pool.count() < self.max_connections) {
            const conn = try self.allocator.create(Connection);
            conn.* = Connection{
                .stream = stream,
                .last_used = std.time.timestamp(),
                .host = try self.allocator.dupe(u8, host),
                .port = port,
                .is_https = is_https,
            };
            try self.connection_pool.put(try self.allocator.dupe(u8, conn_key), conn);
        }

        return stream;
    }

    fn sendRequest(self: *Client, stream: *std.net.Stream, method: Method, url: URL, headers: Headers, body: ?[]const u8) !void {
        const method_str = switch (method) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };

        // Build request
        var request_buf = std.ArrayList(u8).init(self.allocator);
        defer request_buf.deinit();

        try request_buf.writer().print("{s} {s} HTTP/1.1\r\n", .{ method_str, url.path });
        try request_buf.writer().print("Host: {s}\r\n", .{url.host});

        var it = headers.iterator();
        while (it.next()) |entry| {
            try request_buf.writer().print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        if (body) |b| {
            try request_buf.writer().print("Content-Length: {d}\r\n", .{b.len});
        }

        try request_buf.writer().print("\r\n", .{});

        // Send headers
        _ = try stream.write(request_buf.items);

        // Send body
        if (body) |b| {
            _ = try stream.write(b);
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

    fn readLineWithTimeout(self: *Client, stream: *std.net.Stream, timeout_ms: u32) ![]u8 {
        const start_time = std.time.milliTimestamp();
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        var reader = stream.reader();
        while (true) {
            const elapsed = std.time.milliTimestamp() - start_time;
            if (elapsed > timeout_ms) return error.TimedOut;

            const byte = reader.readByte() catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };

            try buffer.append(byte);
            if (byte == '\n') break;
        }

        return buffer.toOwnedSlice();
    }

    fn readWithTimeout(self: *Client, stream: *std.net.Stream, buffer: []u8, timeout_ms: u32) !usize {
        _ = self;
        const start_time = std.time.milliTimestamp();
        var total_read: usize = 0;

        while (total_read < buffer.len) {
            const elapsed = std.time.milliTimestamp() - start_time;
            if (elapsed > timeout_ms) return error.TimedOut;

            const bytes_read = stream.reader().read(buffer[total_read..]) catch |err| {
                if (err == error.WouldBlock) continue;
                return err;
            };

            if (bytes_read == 0) break;
            total_read += bytes_read;
        }

        return total_read;
    }

    fn readChunkedBody(self: *Client, stream: *std.net.Stream, body: *std.ArrayList(u8), timeout_ms: u32) !void {
        while (true) {
            const size_line = try self.readLineWithTimeout(stream, timeout_ms);
            defer self.allocator.free(size_line);

            const trimmed = std.mem.trim(u8, size_line, &std.ascii.whitespace);
            const chunk_size = try std.fmt.parseInt(usize, trimmed, 16);

            if (chunk_size == 0) break; // Last chunk

            try body.resize(body.items.len + chunk_size);
            const bytes_read = try self.readWithTimeout(stream, body.items[body.items.len - chunk_size ..], timeout_ms);
            if (bytes_read != chunk_size) return error.IncompleteChunk;

            // Read trailing CRLF
            const crlf = try self.readLineWithTimeout(stream, timeout_ms);
            defer self.allocator.free(crlf);
            if (!std.mem.eql(u8, crlf, "\r\n")) return error.InvalidChunkFormat;
        }
    }

    fn shouldRetry(err: anyerror) bool {
        return switch (err) {
            error.ConnectionRefused, error.ConnectionTimedOut, error.ConnectionResetByPeer, error.BrokenPipe, error.NetworkUnreachable, error.HostUnreachable, error.TimedOut => true,
            else => false,
        };
    }

    /// Send an HTTP request (alias for send)
    pub fn request(self: *Client, req: Request) !Response {
        return self.send(req);
    }

    fn isRedirect(code: u16) bool {
        return code >= 300 and code < 400;
    }
};
