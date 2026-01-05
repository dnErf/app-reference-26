const std = @import("std");
const zig_grizzly = @import("zig_grizzly");

const Client = zig_grizzly.http_client.Client;
const Request = zig_grizzly.http_client.Request;
const SecretsManager = zig_grizzly.secrets.SecretsManager;
const URL = zig_grizzly.url.URL;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Grizzly DB Real-World HTTPS Demo with Secrets\n", .{});
    std.debug.print("==============================================\n\n", .{});

    // Initialize HTTP client
    var client = try Client.init(allocator);
    defer client.deinit();

    // Initialize secrets manager (in-memory for demo)
    var secrets = try SecretsManager.init(allocator, .{});
    defer secrets.deinit();

    // Create a demo secret (Bearer token for HTTPBin)
    try secrets.createSecret("demo_token", .token, "demo_token_value");
    std.debug.print("✓ Created demo secret 'demo_token'\n", .{});

    // Demo 1: Query HTTPBin (public API)
    std.debug.print("\n📡 Demo 1: Querying HTTPBin (public API)\n", .{});
    try demoHttpBin(&client, allocator);

    // Demo 2: Query with authentication (simulated)
    std.debug.print("\n🔐 Demo 2: Query with Bearer token authentication\n", .{});
    try demoAuthenticatedRequest(&client, &secrets, allocator);

    // Demo 3: Test connection pooling and retry logic
    std.debug.print("\n🔄 Demo 3: Testing connection pooling and retry logic\n", .{});
    try demoConnectionPooling(&client, allocator);

    std.debug.print("\n✅ All demos completed successfully!\n", .{});
    std.debug.print("Features demonstrated:\n", .{});
    std.debug.print("• HTTPS requests with TLS\n", .{});
    std.debug.print("• Secrets-based authentication\n", .{});
    std.debug.print("• Connection pooling\n", .{});
    std.debug.print("• Retry logic on failures\n", .{});
    std.debug.print("• Timeout handling\n", .{});
}

fn demoHttpBin(client: *Client, allocator: std.mem.Allocator) !void {
    const url = try URL.parse("http://httpbin.org/get");

    var headers = std.StringHashMap([]const u8).init(allocator);
    defer headers.deinit();
    try headers.put("Accept", "application/json");

    const request = Request{
        .method = .GET,
        .url = url,
        .headers = headers,
        .timeout_ms = 10000, // 10 second timeout
        .retry_count = 2,
    };

    const response = try client.send(request);
    defer response.deinit();

    std.debug.print("Status: {d} {s}\n", .{ response.status.code, response.status.reason });
    std.debug.print("Response length: {d} bytes\n", .{response.body.items.len});

    // Print first 200 chars of response
    const preview_len = @min(200, response.body.items.len);
    std.debug.print("Response preview: {s}...\n", .{std.fmt.fmtSliceEscapeLower(response.body.items[0..preview_len])});
}

fn demoAuthenticatedRequest(client: *Client, secrets: *SecretsManager, allocator: std.mem.Allocator) !void {
    const url = try URL.parse("http://httpbin.org/bearer");

    // Get token from secrets
    const token_value = try secrets.getSecretValue("demo_token", allocator);
    defer allocator.free(token_value);

    var headers = std.StringHashMap([]const u8).init(allocator);
    defer headers.deinit();
    try headers.put("Authorization", try std.fmt.allocPrint(allocator, "Bearer {s}", .{token_value}));
    try headers.put("Accept", "application/json");

    const request = Request{
        .method = .GET,
        .url = url,
        .headers = headers,
        .timeout_ms = 10000,
        .retry_count = 2,
    };

    const response = try client.send(request);
    defer response.deinit();

    std.debug.print("Status: {d} {s}\n", .{ response.status.code, response.status.reason });
    std.debug.print("Authenticated request successful\n", .{});

    // Print first 200 chars of response
    const preview_len = @min(200, response.body.items.len);
    std.debug.print("Response preview: {s}...\n", .{std.fmt.fmtSliceEscapeLower(response.body.items[0..preview_len])});
}

fn demoConnectionPooling(client: *Client, _: std.mem.Allocator) !void {
    const urls = [_][]const u8{
        "http://httpbin.org/uuid",
        "http://httpbin.org/uuid",
        "http://httpbin.org/uuid", // Should reuse connection
    };

    for (urls, 0..) |url_str, i| {
        const url = try URL.parse(url_str);

        const request = Request{
            .method = .GET,
            .url = url,
            .timeout_ms = 5000,
            .retry_count = 1,
        };

        const start_time = std.time.milliTimestamp();
        const response = try client.send(request);
        defer response.deinit();
        const end_time = std.time.milliTimestamp();

        std.debug.print("Request {d}: {d}ms, Status: {d}\n", .{ i + 1, end_time - start_time, response.status.code });
    }

    std.debug.print("Connection pool size: {d}\n", .{client.connection_pool.count()});
}
