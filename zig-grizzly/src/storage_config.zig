const std = @import("std");
const storage_engine = @import("storage_engine.zig");
const StorageType = storage_engine.StorageType;
const StorageCapabilities = storage_engine.StorageCapabilities;

/// Storage configuration for a specific engine instance
pub const StorageConfig = struct {
    storage_type: StorageType,
    name: []const u8,
    max_memory_mb: usize = 1024,
    compression_enabled: bool = true,
    compression_algorithm: CompressionAlgorithm = .lz4,
    cache_enabled: bool = true,
    cache_size_mb: usize = 256,
    read_only: bool = false,

    pub fn init(allocator: std.mem.Allocator, storage_type: StorageType, name: []const u8) !StorageConfig {
        const name_copy = try allocator.dupe(u8, name);
        return StorageConfig{
            .storage_type = storage_type,
            .name = name_copy,
        };
    }

    pub fn deinit(self: *StorageConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

/// Compression algorithms supported
pub const CompressionAlgorithm = enum {
    none,
    lz4,
    zstd,
    gzip,
    snappy,
};

/// Storage metadata for monitoring and optimization
pub const StorageMetadata = struct {
    engine_type: StorageType,
    created_at: i64,
    last_accessed: i64,
    total_operations: usize,
    read_operations: usize,
    write_operations: usize,
    total_bytes_read: usize,
    total_bytes_written: usize,
    average_query_time_ms: f32,
    cache_hit_ratio: f32,
    compression_ratio: f32,
    error_count: usize,

    pub fn init(engine_type: StorageType) StorageMetadata {
        const now = std.time.timestamp();
        return StorageMetadata{
            .engine_type = engine_type,
            .created_at = now,
            .last_accessed = now,
            .total_operations = 0,
            .read_operations = 0,
            .write_operations = 0,
            .total_bytes_read = 0,
            .total_bytes_written = 0,
            .average_query_time_ms = 0.0,
            .cache_hit_ratio = 0.0,
            .compression_ratio = 1.0,
            .error_count = 0,
        };
    }

    pub fn recordOperation(self: *StorageMetadata, is_read: bool, bytes: usize, duration_ms: f32) void {
        self.total_operations += 1;
        self.last_accessed = std.time.timestamp();

        if (is_read) {
            self.read_operations += 1;
            self.total_bytes_read += bytes;
        } else {
            self.write_operations += 1;
            self.total_bytes_written += bytes;
        }

        // Update rolling average for query time
        const alpha = 0.1; // Smoothing factor
        self.average_query_time_ms = self.average_query_time_ms * (1.0 - alpha) + duration_ms * alpha;
    }

    pub fn recordError(self: *StorageMetadata) void {
        self.error_count += 1;
    }

    pub fn updateCacheStats(self: *StorageMetadata, hit_ratio: f32) void {
        self.cache_hit_ratio = hit_ratio;
    }

    pub fn updateCompressionStats(self: *StorageMetadata, ratio: f32) void {
        self.compression_ratio = ratio;
    }
};

/// Storage registry for managing multiple engines
pub const StorageRegistry = struct {
    allocator: std.mem.Allocator,
    engines: std.StringHashMap(storage_engine.StorageEngine),
    configs: std.StringHashMap(StorageConfig),
    metadata: std.StringHashMap(StorageMetadata),

    pub fn init(allocator: std.mem.Allocator) StorageRegistry {
        return StorageRegistry{
            .allocator = allocator,
            .engines = std.StringHashMap(storage_engine.StorageEngine).init(allocator),
            .configs = std.StringHashMap(StorageConfig).init(allocator),
            .metadata = std.StringHashMap(StorageMetadata).init(allocator),
        };
    }

    pub fn deinit(self: *StorageRegistry) void {
        var engine_iter = self.engines.iterator();
        while (engine_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.engines.deinit();

        var config_iter = self.configs.iterator();
        while (config_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.configs.deinit();

        self.metadata.deinit();
    }

    pub fn registerEngine(self: *StorageRegistry, name: []const u8, engine: storage_engine.StorageEngine, config: StorageConfig) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        try self.engines.put(name_copy, engine);
        try self.configs.put(name_copy, config);
        try self.metadata.put(name_copy, StorageMetadata.init(config.storage_type));
    }

    pub fn getEngine(self: StorageRegistry, name: []const u8) ?storage_engine.StorageEngine {
        return self.engines.get(name);
    }

    pub fn getConfig(self: StorageRegistry, name: []const u8) ?StorageConfig {
        return self.configs.get(name);
    }

    pub fn getMetadata(self: StorageRegistry, name: []const u8) ?StorageMetadata {
        return self.metadata.get(name);
    }

    pub fn updateMetadata(self: *StorageRegistry, name: []const u8, metadata: StorageMetadata) !void {
        try self.metadata.put(name, metadata);
    }

    pub fn listEngines(self: StorageRegistry, allocator: std.mem.Allocator) ![][]const u8 {
        var result = try std.ArrayList([]const u8).initCapacity(allocator, 0);
        errdefer result.deinit(allocator);

        var iter = self.engines.keyIterator();
        while (iter.next()) |key| {
            try result.append(allocator, try allocator.dupe(u8, key.*));
        }

        return result.toOwnedSlice(allocator);
    }
};
