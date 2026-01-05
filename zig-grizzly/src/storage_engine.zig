const std = @import("std");
const types = @import("types.zig");
const memory_store = @import("memory_store.zig");

const Value = types.Value;
const MemoryStore = memory_store.MemoryStore;

/// Performance metrics for storage operations
pub const PerformanceMetrics = struct {
    read_latency_ms: f32,
    write_latency_ms: f32,
    compression_ratio: f32,
    throughput_mbps: f32,
};

/// Storage capability flags
pub const StorageCapabilities = struct {
    supports_olap: bool = false,
    supports_oltp: bool = false,
    supports_graph: bool = false,
    supports_blockchain: bool = false,
};

/// Unified storage engine interface
/// All storage implementations must conform to this interface
pub const StorageEngine = struct {
    /// Pointer to implementation-specific data
    ptr: *anyopaque,
    /// Virtual table for operations
    vtable: *const VTable,

    /// Virtual table defining storage operations
    pub const VTable = struct {
        save: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,
        load: *const fn (ptr: *anyopaque, key: []const u8) anyerror![]u8,
        query: *const fn (ptr: *anyopaque, query_str: []const u8, allocator: std.mem.Allocator) anyerror![]Value,
        getCapabilities: *const fn (ptr: *anyopaque) StorageCapabilities,
        getPerformanceMetrics: *const fn (ptr: *anyopaque) PerformanceMetrics,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    /// Save data to storage
    pub fn save(self: StorageEngine, data: []const u8) !void {
        return self.vtable.save(self.ptr, data);
    }

    /// Load data from storage by key
    pub fn load(self: StorageEngine, key: []const u8) ![]u8 {
        return self.vtable.load(self.ptr, key);
    }

    /// Execute query against storage
    pub fn query(self: StorageEngine, query_str: []const u8, allocator: std.mem.Allocator) ![]Value {
        return self.vtable.query(self.ptr, query_str, allocator);
    }

    /// Get storage capabilities
    pub fn getCapabilities(self: StorageEngine) StorageCapabilities {
        return self.vtable.getCapabilities(self.ptr);
    }

    /// Get performance metrics
    pub fn getPerformanceMetrics(self: StorageEngine) PerformanceMetrics {
        return self.vtable.getPerformanceMetrics(self.ptr);
    }

    /// Clean up storage resources
    pub fn deinit(self: StorageEngine) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Storage engine types for automatic selection
pub const StorageType = enum {
    memory,
    column,
    row,
    graph,
};

/// Storage selection recommendation
pub const StorageRecommendation = struct {
    storage_type: StorageType,
    confidence: f32, // 0.0 to 1.0
    reasoning: []const u8,
};

/// Storage migration result
pub const MigrationResult = struct {
    success: bool,
    bytes_migrated: usize,
    duration_ms: u64,
    error_message: ?[]const u8,
};
/// Create a new memory store instance
pub fn createMemoryStore(allocator: std.mem.Allocator) !StorageEngine {
    const store = try MemoryStore.init(allocator);
    return store.asStorageEngine();
}
