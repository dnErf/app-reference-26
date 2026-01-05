const std = @import("std");
const zig_grizzly = @import("zig_grizzly");

// Demo of Phase 1: Storage Abstraction Layer
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("=== Grizzly DB Sprint 19: Storage Abstraction Layer Demo ===\n\n", .{});

    // Initialize storage selector
    var selector = zig_grizzly.StorageSelector.init(allocator);

    // Example workload: Analytical queries on large dataset
    const analytical_workload = zig_grizzly.WorkloadProfile{
        .analytical_queries = true,
        .batch_processing = true,
        .read_heavy = true,
        .data_size_gb = 50.0,
    };

    std.debug.print("Analyzing analytical workload...\n", .{});
    const recommendation = try selector.recommendStorage(analytical_workload);
    std.debug.print("Recommended storage: {s} (confidence: {d:.2})\n", .{
        @tagName(recommendation.storage_type),
        recommendation.confidence,
    });
    std.debug.print("Reasoning: {s}\n\n", .{recommendation.reasoning});

    // Example workload: Real-time OLTP
    const oltp_workload = zig_grizzly.WorkloadProfile{
        .write_heavy = true,
        .point_lookups = true,
        .real_time = true,
        .data_size_gb = 5.0,
    };

    std.debug.print("Analyzing OLTP workload...\n", .{});
    const oltp_recommendation = try selector.recommendStorage(oltp_workload);
    std.debug.print("Recommended storage: {s} (confidence: {d:.2})\n", .{
        @tagName(oltp_recommendation.storage_type),
        oltp_recommendation.confidence,
    });
    std.debug.print("Reasoning: {s}\n\n", .{oltp_recommendation.reasoning});

    // Initialize storage registry
    var registry = zig_grizzly.StorageRegistry.init(allocator);
    defer registry.deinit();

    std.debug.print("Storage registry initialized with {d} engines\n", .{
        (try registry.listEngines(allocator)).len,
    });

    // Create storage config
    var config = try zig_grizzly.StorageConfig.init(allocator, zig_grizzly.StorageType.memory, "demo_memory_store");
    defer config.deinit(allocator);

    std.debug.print("Created storage config: {s} ({s})\n", .{
        config.name,
        @tagName(config.storage_type),
    });

    std.debug.print("\n=== Phase 1 Complete: Storage abstraction layer operational ===\n", .{});
}
