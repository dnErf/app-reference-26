const std = @import("std");

/// URL structure
pub const URL = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,

    /// Parse a URL string
    pub fn parse(url_str: []const u8) !URL {
        var url = URL{
            .scheme = "",
            .host = "",
            .port = null,
            .path = "/",
            .query = null,
            .fragment = null,
        };

        // Find scheme
        if (std.mem.indexOf(u8, url_str, "://")) |scheme_end| {
            url.scheme = url_str[0..scheme_end];
            var remaining = url_str[scheme_end + 3 ..];

            // Find path
            var path_start: usize = 0;
            if (std.mem.indexOf(u8, remaining, "/")) |slash_pos| {
                path_start = slash_pos;
            } else {
                path_start = remaining.len;
            }

            // Parse host and port
            const host_part = remaining[0..path_start];
            if (std.mem.indexOf(u8, host_part, ":")) |colon_pos| {
                url.host = host_part[0..colon_pos];
                url.port = try std.fmt.parseInt(u16, host_part[colon_pos + 1 ..], 10);
            } else {
                url.host = host_part;
            }

            // Parse path, query, fragment
            if (path_start < remaining.len) {
                var path_part = remaining[path_start..];

                // Find query
                if (std.mem.indexOf(u8, path_part, "?")) |query_pos| {
                    url.path = path_part[0..query_pos];
                    var query_part = path_part[query_pos + 1 ..];

                    // Find fragment
                    if (std.mem.indexOf(u8, query_part, "#")) |frag_pos| {
                        url.query = query_part[0..frag_pos];
                        url.fragment = query_part[frag_pos + 1 ..];
                    } else {
                        url.query = query_part;
                    }
                } else if (std.mem.indexOf(u8, path_part, "#")) |frag_pos| {
                    url.path = path_part[0..frag_pos];
                    url.fragment = path_part[frag_pos + 1 ..];
                } else {
                    url.path = path_part;
                }
            }
        } else {
            return error.InvalidURL;
        }

        return url;
    }

    /// Format URL back to string
    pub fn format(self: URL, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.writer().print("{s}://{s}", .{ self.scheme, self.host });

        if (self.port) |port| {
            try buffer.writer().print(":{d}", .{port});
        }

        try buffer.writer().writeAll(self.path);

        if (self.query) |query| {
            try buffer.writer().print("?{s}", .{query});
        }

        if (self.fragment) |fragment| {
            try buffer.writer().print("#{s}", .{fragment});
        }

        return buffer.toOwnedSlice();
    }
};
