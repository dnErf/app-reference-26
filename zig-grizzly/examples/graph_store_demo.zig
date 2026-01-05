const std = @import("std");
const zig_grizzly = @import("zig_grizzly");

const GraphStore = zig_grizzly.GraphStore;
const GraphQuery = zig_grizzly.GraphQuery;
const Value = zig_grizzly.Value;

/// Demo showcasing Phase 5: Blockchain Graph Store Implementation
/// Features: Graph database with blockchain immutability, ORC-based storage, SQL graph queries
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 Grizzly DB - Phase 5: Blockchain Graph Store Implementation Demo\n", .{});
    std.debug.print("========================================================================\n\n", .{});

    // Initialize graph store
    const base_path = "test_graph_output";
    std.fs.cwd().makeDir(base_path) catch {}; // Ignore if already exists

    var store = try GraphStore.init(allocator, base_path);
    defer store.deinit();

    std.debug.print("✅ Initialized graph store with blockchain immutability\n", .{});

    // Create some nodes (people)
    std.debug.print("\n📍 Creating graph nodes (people)...\n", .{});

    var alice_props = std.StringHashMap(Value).init(allocator);
    defer alice_props.deinit();
    try alice_props.put("name", Value{ .string = "Alice" });
    try alice_props.put("age", Value{ .int32 = 30 });
    try alice_props.put("city", Value{ .string = "New York" });

    try store.createNode("alice", &[_][]const u8{"Person"}, alice_props);
    std.debug.print("  ✅ Created node 'alice' with Person label\n", .{});

    var bob_props = std.StringHashMap(Value).init(allocator);
    defer bob_props.deinit();
    try bob_props.put("name", Value{ .string = "Bob" });
    try bob_props.put("age", Value{ .int32 = 25 });
    try bob_props.put("city", Value{ .string = "San Francisco" });

    try store.createNode("bob", &[_][]const u8{"Person"}, bob_props);
    std.debug.print("  ✅ Created node 'bob' with Person label\n", .{});

    var charlie_props = std.StringHashMap(Value).init(allocator);
    defer charlie_props.deinit();
    try charlie_props.put("name", Value{ .string = "Charlie" });
    try charlie_props.put("age", Value{ .int32 = 35 });
    try charlie_props.put("city", Value{ .string = "New York" });

    try store.createNode("charlie", &[_][]const u8{"Person"}, charlie_props);
    std.debug.print("  ✅ Created node 'charlie' with Person label\n", .{});

    // Create relationships
    std.debug.print("\n🔗 Creating relationships...\n", .{});

    var friendship_props = std.StringHashMap(Value).init(allocator);
    defer friendship_props.deinit();
    try friendship_props.put("since", Value{ .int32 = 2020 });
    try friendship_props.put("strength", Value{ .float32 = 0.9 });

    try store.createEdge("alice", "bob", "FRIENDS_WITH", friendship_props);
    std.debug.print("  ✅ Created FRIENDS_WITH relationship: alice -> bob\n", .{});

    var colleague_props = std.StringHashMap(Value).init(allocator);
    defer colleague_props.deinit();
    try colleague_props.put("company", Value{ .string = "TechCorp" });
    try colleague_props.put("department", Value{ .string = "Engineering" });

    try store.createEdge("alice", "charlie", "WORKS_WITH", colleague_props);
    std.debug.print("  ✅ Created WORKS_WITH relationship: alice -> charlie\n", .{});

    try store.createEdge("bob", "charlie", "FRIENDS_WITH", friendship_props);
    std.debug.print("  ✅ Created FRIENDS_WITH relationship: bob -> charlie\n", .{});

    // Query the graph
    std.debug.print("\n🔍 Querying the graph...\n", .{});

    var query = try GraphQuery.init(allocator);
    defer query.deinit();

    try query.parse("MATCH (n:Person) RETURN n.name");
    std.debug.print("  📝 Parsed query: MATCH (n:Person) RETURN n.name\n", .{});

    var results = try query.execute(store);
    defer results.deinit(allocator);

    std.debug.print("  📊 Found {d} nodes matching the pattern:\n", .{results.items.len});
    for (results.items) |node| {
        const name = node.properties.get("name") orelse continue;
        if (name == .string) {
            std.debug.print("    - {s}\n", .{name.string});
        }
    }

    // Demonstrate blockchain immutability
    std.debug.print("\n⛓️  Blockchain verification...\n", .{});

    const blockchain = store.blockchain;
    const is_valid = try blockchain.verifyChain();
    std.debug.print("  ✅ Blockchain integrity: {any}\n", .{is_valid});
    std.debug.print("  📊 Total blocks: {d}\n", .{blockchain.getBlockCount()});

    // Show performance metrics
    std.debug.print("\n📊 Performance Metrics:\n", .{});
    std.debug.print("  Read Latency:  {d:.2}ms\n", .{store.performance_metrics.read_latency_ms});
    std.debug.print("  Write Latency: {d:.2}ms\n", .{store.performance_metrics.write_latency_ms});
    std.debug.print("  Compression:   {:.1}x\n", .{store.performance_metrics.compression_ratio});
    std.debug.print("  Throughput:    {:.2} MB/s\n", .{store.performance_metrics.throughput_mbps});

    std.debug.print("\n🎉 Graph Store demo completed successfully!\n", .{});
    std.debug.print("Features demonstrated:\n", .{});
    std.debug.print("  ✅ Graph database with nodes and relationships\n", .{});
    std.debug.print("  ✅ Blockchain-inspired immutability\n", .{});
    std.debug.print("  ✅ SQL-based graph query language\n", .{});
    std.debug.print("  ✅ ORC-based compressed storage (framework ready)\n", .{});
    std.debug.print("  ✅ Verifiable data integrity\n", .{});
}
