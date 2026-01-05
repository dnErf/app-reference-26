const std = @import("std");
const testing = std.testing;
const root = @import("root");
const storage_engine = root.storage_engine;
const storage_config = root.storage_config;
const storage_selector = root.storage_selector;
const Value = root.Value;

// Mock storage engine for testing
const MockStorageEngine = struct {
    data: std.StringHashMap([]u8),
    capabilities: storage_engine.StorageCapabilities,

    pub fn init(allocator: std.mem.Allocator, caps: storage_engine.StorageCapabilities) !MockStorageEngine {
        return MockStorageEngine{
            .data = std.StringHashMap([]u8).init(allocator),
            .capabilities = caps,
        };
    }

    pub fn deinit(self: *MockStorageEngine) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            testing.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
    }

    pub fn save(self: *MockStorageEngine, key: []const u8, value: []const u8) !void {
        const key_copy = try testing.allocator.dupe(u8, key);
        const value_copy = try testing.allocator.dupe(u8, value);
        try self.data.put(key_copy, value_copy);
    }

    pub fn load(self: MockStorageEngine, key: []const u8) ![]u8 {
        return self.data.get(key) orelse error.KeyNotFound;
    }

    pub fn query(_: MockStorageEngine, _: []const u8, _: std.mem.Allocator) ![]Value {
        // Mock implementation - return empty result
        return &[_]Value{};
    }

    pub fn getCapabilities(self: MockStorageEngine) root.StorageCapabilities {
        return self.capabilities;
    }

    pub fn getPerformanceMetrics(_: MockStorageEngine) root.PerformanceMetrics {
        return root.PerformanceMetrics{
            .read_latency_ms = 1.0,
            .write_latency_ms = 2.0,
            .compression_ratio = 1.5,
            .throughput_mbps = 100.0,
        };
    }
};

test "StorageEngine interface" {
    var mock = try MockStorageEngine.init(testing.allocator, storage_engine.StorageCapabilities{
        .supports_olap = true,
        .supports_oltp = false,
    });
    defer mock.deinit();

    // Test capabilities
    const caps = mock.getCapabilities();
    try testing.expect(caps.supports_olap);
    try testing.expect(!caps.supports_oltp);

    // Test performance metrics
    const metrics = mock.getPerformanceMetrics();
    try testing.expect(metrics.read_latency_ms == 1.0);
    try testing.expect(metrics.compression_ratio == 1.5);
}

test "StorageConfig" {
    var config = try storage_config.StorageConfig.init(testing.allocator, .memory, "test_engine");
    defer config.deinit(testing.allocator);

    try testing.expectEqual(config.storage_type, .memory);
    try testing.expectEqualStrings(config.name, "test_engine");
    try testing.expect(config.compression_enabled);
}

test "StorageMetadata" {
    var metadata = storage_config.StorageMetadata.init(.column);

    try testing.expectEqual(metadata.engine_type, .column);
    try testing.expect(metadata.total_operations == 0);

    metadata.recordOperation(true, 100, 5.0);
    try testing.expect(metadata.read_operations == 1);
    try testing.expect(metadata.total_bytes_read == 100);
    try testing.expect(metadata.average_query_time_ms > 0.0);
}

test "StorageRegistry" {
    var registry = storage_config.StorageRegistry.init(testing.allocator);
    defer registry.deinit();

    // Create a mock engine (simplified for testing)
    var mock = try MockStorageEngine.init(testing.allocator, storage_engine.StorageCapabilities{});
    defer mock.deinit();

    // For testing, we'll skip full engine registration as it requires VTable setup
    // This test focuses on registry structure
    const engines = try registry.listEngines(testing.allocator);
    defer testing.allocator.free(engines);
    try testing.expect(engines.len == 0);
}

test "StorageSelector - workload analysis" {
    var selector = storage_selector.StorageSelector.init(testing.allocator);

    const queries = [_][]const u8{
        "SELECT COUNT(*) FROM users",
        "SELECT * FROM users WHERE id = 1",
        "INSERT INTO users VALUES (1, 'John')",
    };

    const profile = try selector.analyzeQueries(&queries);
    try testing.expect(profile.read_heavy);
    try testing.expect(profile.write_heavy);
    try testing.expect(profile.analytical_queries);
    try testing.expect(profile.point_lookups);
}

test "StorageSelector - storage recommendation" {
    var selector = storage_selector.StorageSelector.init(testing.allocator);

    // Test analytical workload (should recommend column store)
    const analytical_workload = storage_selector.WorkloadProfile{
        .analytical_queries = true,
        .batch_processing = true,
        .read_heavy = true,
    };

    const recommendation = try selector.recommendStorage(analytical_workload);
    try testing.expectEqual(recommendation.storage_type, .column);
    try testing.expect(recommendation.confidence > 0.0);

    // Test OLTP workload (should recommend row store)
    const oltp_workload = storage_selector.WorkloadProfile{
        .write_heavy = true,
        .point_lookups = true,
        .real_time = true,
    };

    const oltp_recommendation = try selector.recommendStorage(oltp_workload);
    try testing.expectEqual(oltp_recommendation.storage_type, .row);
}
