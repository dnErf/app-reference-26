const std = @import("std");
const gz = @import("zig_grizzly");

/// Performance benchmark for SecretsManager operations
pub fn main() !void {
    std.debug.print("🔐 SecretsManager Performance Benchmark\n", .{});
    std.debug.print("======================================\n\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize database
    var db = try gz.Database.init(allocator, "perf_test");
    defer db.deinit();

    // Initialize function registry
    var function_registry = gz.FunctionRegistry.init(allocator);
    defer function_registry.deinit();

    // Initialize query engine
    var query_engine = gz.QueryEngine.init(allocator, &db, &function_registry);

    // Benchmark CREATE SECRET operations
    std.debug.print("\n⚡ Benchmarking CREATE SECRET operations...\n", .{});

    const num_operations = 1000;
    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < num_operations) : (i += 1) {
        const secret_name = try std.fmt.allocPrint(allocator, "secret_{d}", .{i});
        defer allocator.free(secret_name);

        const secret_value = try std.fmt.allocPrint(allocator, "value_{d}_with_some_length_to_make_it_realistic", .{i});
        defer allocator.free(secret_value);

        const sql = try std.fmt.allocPrint(allocator, "CREATE SECRET {s} (KIND 'bearer', VALUE '{s}')", .{ secret_name, secret_value });
        defer allocator.free(sql);

        _ = try query_engine.execute(sql);
    }

    const create_time = timer.lap();
    const create_ops_per_sec = @as(f64, @floatFromInt(num_operations)) / (@as(f64, @floatFromInt(create_time)) / 1_000_000_000.0);

    std.debug.print("  ✅ Created {d} secrets in {d:.2}ms\n", .{ num_operations, @as(f64, @floatFromInt(create_time)) / 1_000_000.0 });
    std.debug.print("  📊 Throughput: {d:.0} CREATE SECRET ops/sec\n", .{create_ops_per_sec});

    // Benchmark secret retrieval
    std.debug.print("\n🔍 Benchmarking secret retrieval...\n", .{});

    timer.reset();
    i = 0;
    while (i < num_operations) : (i += 1) {
        const secret_name = try std.fmt.allocPrint(allocator, "secret_{d}", .{i});
        defer allocator.free(secret_name);

        // Use the secrets manager directly for retrieval benchmark
        _ = db.secrets_manager.getSecret(secret_name) catch continue;
    }

    const retrieve_time = timer.lap();
    const retrieve_ops_per_sec = @as(f64, @floatFromInt(num_operations)) / (@as(f64, @floatFromInt(retrieve_time)) / 1_000_000_000.0);

    std.debug.print("  ✅ Retrieved {d} secrets in {d:.2}ms\n", .{ num_operations, @as(f64, @floatFromInt(retrieve_time)) / 1_000_000.0 });
    std.debug.print("  📊 Throughput: {d:.0} secret retrievals/sec\n", .{retrieve_ops_per_sec});

    // Test encryption/decryption performance
    std.debug.print("\n🔒 Benchmarking encryption/decryption...\n", .{});

    const test_data = "This is a test secret value that needs to be encrypted and decrypted for performance testing.";
    const iterations = 1000;

    timer.reset();
    i = 0;
    while (i < iterations) : (i += 1) {
        // Create and retrieve a secret (this internally does encryption/decryption)
        const secret_name = try std.fmt.allocPrint(allocator, "crypto_test_{d}", .{i});
        defer allocator.free(secret_name);

        try db.secrets_manager.createSecret(secret_name, .token, test_data);

        const retrieved = try db.secrets_manager.getSecretValue(secret_name, allocator);
        defer allocator.free(retrieved);

        // Verify
        if (!std.mem.eql(u8, test_data, retrieved)) {
            return error.DecryptionFailed;
        }

        // Clean up
        try db.secrets_manager.deleteSecret(secret_name);
    }

    const crypto_time = timer.lap();
    const crypto_ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(crypto_time)) / 1_000_000_000.0);

    std.debug.print("  ✅ Performed {d} encrypt/decrypt cycles in {d:.2}ms\n", .{ iterations, @as(f64, @floatFromInt(crypto_time)) / 1_000_000.0 });
    std.debug.print("  📊 Throughput: {d:.0} crypto ops/sec\n", .{crypto_ops_per_sec});

    std.debug.print("\n🎉 Performance benchmark complete!\n", .{});
    std.debug.print("   ✅ CREATE SECRET operations: {d:.0} ops/sec\n", .{create_ops_per_sec});
    std.debug.print("   ✅ Secret retrieval: {d:.0} ops/sec\n", .{retrieve_ops_per_sec});
    std.debug.print("   ✅ AES-256-GCM crypto: {d:.0} ops/sec\n", .{crypto_ops_per_sec});
}
