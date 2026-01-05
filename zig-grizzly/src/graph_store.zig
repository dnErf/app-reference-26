const std = @import("std");
const types = @import("types.zig");
const storage_engine = @import("storage_engine.zig");
const blockchain_mod = @import("blockchain.zig");
const graph_query_mod = @import("graph_query.zig");
const table_mod = @import("table.zig");
const schema_mod = @import("schema.zig");

const Value = types.Value;
const StorageEngine = storage_engine.StorageEngine;
const StorageCapabilities = storage_engine.StorageCapabilities;
const PerformanceMetrics = storage_engine.PerformanceMetrics;
const Table = table_mod.Table;
const Schema = schema_mod.Schema;
const Blockchain = blockchain_mod.Blockchain;
const GraphQuery = graph_query_mod.GraphQuery;

/// Graph Store - Blockchain-inspired immutable graph storage using ORC format
/// Combines graph database capabilities with blockchain immutability for secure, verifiable data
/// Supports complex relationships, traversals, and compressed block storage
pub const GraphStore = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8,
    blockchain: *Blockchain,
    nodes: std.StringHashMap(*GraphNode),
    edges: std.ArrayList(*GraphEdge),
    performance_metrics: PerformanceMetrics,
    start_time: i64,

    pub const GraphNode = struct {
        id: []const u8,
        labels: std.ArrayList([]const u8),
        properties: std.StringHashMap(Value),
        created_at: i64,
        block_hash: []const u8,
    };

    pub const GraphEdge = struct {
        id: []const u8,
        from_node: []const u8,
        to_node: []const u8,
        relationship_type: []const u8,
        properties: std.StringHashMap(Value),
        created_at: i64,
        block_hash: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !*GraphStore {
        const path_copy = try allocator.dupe(u8, base_path);
        errdefer allocator.free(path_copy);

        const store = try allocator.create(GraphStore);
        errdefer allocator.destroy(store);

        const blockchain = try Blockchain.init(allocator, path_copy);
        errdefer blockchain.deinit();

        store.* = GraphStore{
            .allocator = allocator,
            .base_path = path_copy,
            .blockchain = blockchain,
            .nodes = std.StringHashMap(*GraphNode).init(allocator),
            .edges = try std.ArrayList(*GraphEdge).initCapacity(allocator, 0),
            .performance_metrics = PerformanceMetrics{
                .read_latency_ms = 0.0,
                .write_latency_ms = 0.0,
                .compression_ratio = 1.0,
                .throughput_mbps = 0.0,
            },
            .start_time = std.time.milliTimestamp(),
        };

        // Create base directory if it doesn't exist
        std.fs.cwd().makeDir(path_copy) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        return store;
    }

    pub fn deinit(self: *GraphStore) void {
        self.allocator.free(self.base_path);

        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            self.deinitNode(entry.value_ptr.*);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.nodes.deinit();

        for (self.edges.items) |edge| {
            self.deinitEdge(edge);
            self.allocator.destroy(edge);
        }
        self.edges.deinit(self.allocator);

        self.blockchain.deinit();
        self.allocator.destroy(self.blockchain);

        self.allocator.destroy(self);
    }

    fn deinitNode(self: *GraphStore, node: *GraphNode) void {
        self.allocator.free(node.id);
        for (node.labels.items) |label| {
            self.allocator.free(label);
        }
        node.labels.deinit(self.allocator);

        var prop_iter = node.properties.iterator();
        while (prop_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            // Value deinit if needed
        }
        node.properties.deinit();
        self.allocator.free(node.block_hash);
    }

    fn deinitEdge(self: *GraphStore, edge: *GraphEdge) void {
        self.allocator.free(edge.id);
        self.allocator.free(edge.from_node);
        self.allocator.free(edge.to_node);
        self.allocator.free(edge.relationship_type);

        var prop_iter = edge.properties.iterator();
        while (prop_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            // Value deinit if needed
        }
        edge.properties.deinit();
        self.allocator.free(edge.block_hash);
    }

    // Graph operations
    pub fn createNode(self: *GraphStore, id: []const u8, labels: []const []const u8, properties: std.StringHashMap(Value)) !void {
        const start_time = std.time.milliTimestamp();

        const node_id = try self.allocator.dupe(u8, id);
        errdefer self.allocator.free(node_id);

        const node = try self.allocator.create(GraphNode);
        errdefer self.allocator.destroy(node);

        var node_labels = try std.ArrayList([]const u8).initCapacity(self.allocator, labels.len);
        errdefer node_labels.deinit(self.allocator);

        for (labels) |label| {
            const label_copy = try self.allocator.dupe(u8, label);
            node_labels.appendAssumeCapacity(label_copy);
        }

        var node_props = std.StringHashMap(Value).init(self.allocator);
        errdefer node_props.deinit();

        var prop_iter = properties.iterator();
        while (prop_iter.next()) |entry| {
            const key_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            errdefer self.allocator.free(key_copy);
            try node_props.put(key_copy, entry.value_ptr.*);
        }

        // Create blockchain entry
        const block_data = try std.fmt.allocPrint(self.allocator, "CREATE NODE {any} WITH LABELS {any}", .{ std.zig.fmtId(id), labels });
        defer self.allocator.free(block_data);

        const block_hash = try self.blockchain.addBlock(block_data);

        node.* = GraphNode{
            .id = node_id,
            .labels = node_labels,
            .properties = node_props,
            .created_at = std.time.milliTimestamp(),
            .block_hash = block_hash,
        };

        try self.nodes.put(node_id, node);

        const end_time = std.time.milliTimestamp();
        self.performance_metrics.write_latency_ms = @floatFromInt(end_time - start_time);
    }

    pub fn createEdge(self: *GraphStore, from_id: []const u8, to_id: []const u8, relationship: []const u8, properties: std.StringHashMap(Value)) !void {
        const start_time = std.time.milliTimestamp();

        // Verify nodes exist
        if (!self.nodes.contains(from_id) or !self.nodes.contains(to_id)) {
            return error.NodeNotFound;
        }

        const edge_id = try std.fmt.allocPrint(self.allocator, "{any}-> {any}:{any}", .{ std.zig.fmtId(from_id), std.zig.fmtId(to_id), std.zig.fmtId(relationship) });
        errdefer self.allocator.free(edge_id);

        const from_copy = try self.allocator.dupe(u8, from_id);
        errdefer self.allocator.free(from_copy);

        const to_copy = try self.allocator.dupe(u8, to_id);
        errdefer self.allocator.free(to_copy);

        const rel_copy = try self.allocator.dupe(u8, relationship);
        errdefer self.allocator.free(rel_copy);

        const edge = try self.allocator.create(GraphEdge);
        errdefer self.allocator.destroy(edge);

        var edge_props = std.StringHashMap(Value).init(self.allocator);
        errdefer edge_props.deinit();

        var prop_iter = properties.iterator();
        while (prop_iter.next()) |entry| {
            const key_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            errdefer self.allocator.free(key_copy);
            try edge_props.put(key_copy, entry.value_ptr.*);
        }

        // Create blockchain entry
        const block_data = try std.fmt.allocPrint(self.allocator, "CREATE EDGE {any} -[{any}]-> {any}", .{ std.zig.fmtId(from_id), std.zig.fmtId(relationship), std.zig.fmtId(to_id) });
        defer self.allocator.free(block_data);

        const block_hash = try self.blockchain.addBlock(block_data);

        edge.* = GraphEdge{
            .id = edge_id,
            .from_node = from_copy,
            .to_node = to_copy,
            .relationship_type = rel_copy,
            .properties = edge_props,
            .created_at = std.time.milliTimestamp(),
            .block_hash = block_hash,
        };

        try self.edges.append(self.allocator, edge);

        const end_time = std.time.milliTimestamp();
        self.performance_metrics.write_latency_ms = @floatFromInt(end_time - start_time);
    }

    pub fn queryGraph(self: *GraphStore, graph_query: GraphQuery) !std.ArrayList(*GraphNode) {
        const start_time = std.time.milliTimestamp();

        var results = try std.ArrayList(*GraphNode).initCapacity(self.allocator, 0);
        errdefer results.deinit(self.allocator);

        // Simple traversal implementation
        // TODO: Implement full graph query language
        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            const node = entry.value_ptr.*;
            if (graph_query.matchesNode(node)) {
                try results.append(self.allocator, node);
            }
        }

        const end_time = std.time.milliTimestamp();
        self.performance_metrics.read_latency_ms = @floatFromInt(end_time - start_time);

        return results;
    }

    // Storage engine interface
    pub fn getStorageEngine(self: *GraphStore) StorageEngine {
        return StorageEngine{
            .ptr = self,
            .vtable = &GRAPH_STORE_VTABLE,
        };
    }
};

const GRAPH_STORE_VTABLE = StorageEngine.VTable{
    .save = save,
    .load = load,
    .query = query,
    .getCapabilities = getCapabilities,
    .getPerformanceMetrics = getPerformanceMetrics,
};

fn save(ctx: *anyopaque, data: []const u8) anyerror!void {
    const self: *GraphStore = @ptrCast(@alignCast(ctx));
    _ = self;
    _ = data;
    // TODO: Implement ORC-based persistence
    return error.NotImplemented;
}

fn load(ctx: *anyopaque, key: []const u8) anyerror![]u8 {
    const self: *GraphStore = @ptrCast(@alignCast(ctx));
    _ = self;
    _ = key;
    // TODO: Implement ORC-based loading
    return error.NotImplemented;
}

fn query(ctx: *anyopaque, query_str: []const u8) anyerror![]u8 {
    const self: *GraphStore = @ptrCast(@alignCast(ctx));
    _ = self;
    _ = query_str;
    // TODO: Implement graph query processing
    return error.NotImplemented;
}

fn getCapabilities(ctx: *anyopaque) StorageCapabilities {
    _ = ctx;
    return StorageCapabilities{
        .supports_olap = false,
        .supports_oltp = false,
        .supports_graph = true,
        .supports_blockchain = true,
    };
}

fn getPerformanceMetrics(ctx: *anyopaque) PerformanceMetrics {
    const self: *GraphStore = @ptrCast(@alignCast(ctx));
    return self.performance_metrics;
}
