const std = @import("std");

/// Node in the dependency graph
pub const DagNode = struct {
    id: []const u8, // Model or table name
    dependencies: std.ArrayListUnmanaged([]const u8), // Names of dependencies
    dependents: std.ArrayListUnmanaged([]const u8), // Names that depend on this
    execution_state: ExecutionState,
    last_executed: ?i64,

    pub const ExecutionState = enum {
        pending,
        executing,
        completed,
        failed,
    };

    pub fn init(allocator: std.mem.Allocator, id: []const u8) !DagNode {
        const id_copy = try allocator.dupe(u8, id);
        return DagNode{
            .id = id_copy,
            .dependencies = std.ArrayListUnmanaged([]const u8){},
            .dependents = std.ArrayListUnmanaged([]const u8){},
            .execution_state = .pending,
            .last_executed = null,
        };
    }

    pub fn deinit(self: *DagNode, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        for (self.dependencies.items) |dep| {
            allocator.free(dep);
        }
        self.dependencies.deinit(allocator);
        for (self.dependents.items) |dep| {
            allocator.free(dep);
        }
        self.dependents.deinit(allocator);
    }

    pub fn addDependency(self: *DagNode, allocator: std.mem.Allocator, dependency: []const u8) !void {
        const dep_copy = try allocator.dupe(u8, dependency);
        try self.dependencies.append(allocator, dep_copy);
    }

    pub fn addDependent(self: *DagNode, allocator: std.mem.Allocator, dependent: []const u8) !void {
        const dep_copy = try allocator.dupe(u8, dependent);
        try self.dependents.append(allocator, dep_copy);
    }

    pub fn hasDependency(self: *const DagNode, dependency: []const u8) bool {
        for (self.dependencies.items) |dep| {
            if (std.mem.eql(u8, dep, dependency)) return true;
        }
        return false;
    }

    pub fn isReadyToExecute(self: *const DagNode, executed_nodes: *std.StringHashMap(void)) bool {
        for (self.dependencies.items) |dep| {
            if (!executed_nodes.contains(dep)) return false;
        }
        return true;
    }
};

/// Directed Acyclic Graph for model dependencies
pub const DependencyGraph = struct {
    allocator: std.mem.Allocator,
    nodes: std.StringHashMap(DagNode),
    // Caching for performance optimization
    dependency_cache: std.StringHashMap(std.StringHashMap(void)),
    topological_sort_cache: ?[][]const u8,

    pub fn init(allocator: std.mem.Allocator) DependencyGraph {
        return DependencyGraph{
            .allocator = allocator,
            .nodes = std.StringHashMap(DagNode).init(allocator),
            .dependency_cache = std.StringHashMap(std.StringHashMap(void)).init(allocator),
            .topological_sort_cache = null,
        };
    }

    pub fn deinit(self: *DependencyGraph) void {
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.nodes.deinit();

        // Clean up caches
        var cache_it = self.dependency_cache.iterator();
        while (cache_it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.dependency_cache.deinit();

        if (self.topological_sort_cache) |cache| {
            self.allocator.free(cache);
        }
    }

    /// Add a node to the graph
    pub fn addNode(self: *DependencyGraph, id: []const u8) !void {
        if (self.nodes.contains(id)) return;
        const node = try DagNode.init(self.allocator, id);
        try self.nodes.put(id, node);
        self.invalidateCache();
    }

    /// Add a dependency relationship (from -> to, meaning 'from' depends on 'to')
    pub fn addDependency(self: *DependencyGraph, from: []const u8, to: []const u8) !void {
        // Ensure both nodes exist
        try self.addNode(from);
        try self.addNode(to);

        // Add dependency to 'from' node
        var from_node = self.nodes.getPtr(from).?;
        if (!from_node.hasDependency(to)) {
            try from_node.addDependency(self.allocator, to);
        }

        // Add dependent to 'to' node
        var to_node = self.nodes.getPtr(to).?;
        const from_copy = try self.allocator.dupe(u8, from);
        try to_node.addDependent(self.allocator, from_copy);

        self.invalidateCache();
    }

    /// Remove a node and all its relationships
    pub fn removeNode(self: *DependencyGraph, id: []const u8) !void {
        const entry = self.nodes.fetchRemove(id) orelse return;
        var node = entry.value;

        // Remove this node from all dependents' dependency lists
        for (node.dependents.items) |dependent_id| {
            if (self.nodes.getPtr(dependent_id)) |dependent_node| {
                // Remove this node from dependent's dependencies
                var new_deps = std.ArrayListUnmanaged([]const u8){};
                defer new_deps.deinit(self.allocator);

                for (dependent_node.dependencies.items) |dep| {
                    if (!std.mem.eql(u8, dep, id)) {
                        try new_deps.append(self.allocator, try self.allocator.dupe(u8, dep));
                    } else {
                        self.allocator.free(dep);
                    }
                }

                dependent_node.dependencies.clearRetainingCapacity();
                try dependent_node.dependencies.appendSlice(self.allocator, new_deps.items);
                new_deps.items.len = 0; // Transfer ownership
            }
        }

        node.deinit(self.allocator);
        self.invalidateCache();
    }

    /// Invalidate all caches when graph changes
    fn invalidateCache(self: *DependencyGraph) void {
        // Clear dependency cache
        var cache_it = self.dependency_cache.iterator();
        while (cache_it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.dependency_cache.clearRetainingCapacity();

        // Clear topological sort cache
        if (self.topological_sort_cache) |cache| {
            self.allocator.free(cache);
            self.topological_sort_cache = null;
        }
    }

    /// Detect cycles in the graph using DFS
    pub fn hasCycles(self: *const DependencyGraph) !bool {
        var visited = std.StringHashMap(void).init(self.allocator);
        defer visited.deinit();
        var recursion_stack = std.StringHashMap(void).init(self.allocator);
        defer recursion_stack.deinit();

        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            if (!visited.contains(entry.key_ptr.*)) {
                if (try self.hasCyclesDFS(entry.key_ptr.*, &visited, &recursion_stack)) {
                    return true;
                }
            }
        }
        return false;
    }

    fn hasCyclesDFS(self: *const DependencyGraph, node_id: []const u8, visited: *std.StringHashMap(void), recursion_stack: *std.StringHashMap(void)) !bool {
        try visited.put(node_id, {});
        try recursion_stack.put(node_id, {});

        const node = self.nodes.get(node_id) orelse return false;

        for (node.dependencies.items) |dep| {
            if (!visited.contains(dep)) {
                if (try self.hasCyclesDFS(dep, visited, recursion_stack)) {
                    return true;
                }
            } else if (recursion_stack.contains(dep)) {
                return true; // Cycle detected
            }
        }

        _ = recursion_stack.remove(node_id);
        return false;
    }

    /// Perform topological sort to get execution order - with caching
    pub fn topologicalSort(self: *DependencyGraph, allocator: std.mem.Allocator) ![][]const u8 {
        // Return cached result if available
        if (self.topological_sort_cache) |cached| {
            var result = std.ArrayListUnmanaged([]const u8){};
            defer result.deinit(allocator);

            for (cached) |node_id| {
                try result.append(allocator, try allocator.dupe(u8, node_id));
            }
            return result.toOwnedSlice(allocator);
        }

        var result = std.ArrayListUnmanaged([]const u8){};
        defer result.deinit(allocator);

        var temp_visited = std.StringHashMap(void).init(allocator);
        defer temp_visited.deinit();

        var perm_visited = std.StringHashMap(void).init(allocator);
        defer perm_visited.deinit();

        // Check for cycles first
        if (try self.hasCycles()) {
            return error.CircularDependency;
        }

        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            if (!perm_visited.contains(entry.key_ptr.*)) {
                try self.topologicalSortDFS(entry.key_ptr.*, &result, &temp_visited, &perm_visited);
            }
        }

        // Reverse the result to get correct execution order
        std.mem.reverse([]const u8, result.items);

        // Cache the result
        const cache_copy = try allocator.dupe([]const u8, result.items);
        self.topological_sort_cache = cache_copy;

        return result.toOwnedSlice(allocator);
    }

    fn topologicalSortDFS(self: *const DependencyGraph, node_id: []const u8, result: *std.ArrayListUnmanaged([]const u8), temp_visited: *std.StringHashMap(void), perm_visited: *std.StringHashMap(void)) !void {
        try temp_visited.put(node_id, {});

        const node = self.nodes.get(node_id) orelse return;

        for (node.dependencies.items) |dep| {
            if (temp_visited.contains(dep)) {
                return error.CircularDependency;
            }
            if (!perm_visited.contains(dep)) {
                try self.topologicalSortDFS(dep, result, temp_visited, perm_visited);
            }
        }

        _ = temp_visited.remove(node_id);
        try perm_visited.put(node_id, {});
        try result.append(self.allocator, try self.allocator.dupe(u8, node_id));
    }

    /// Get nodes that are ready to execute (all dependencies satisfied)
    pub fn getReadyNodes(self: *const DependencyGraph, executed_nodes: std.StringHashMap(void), allocator: std.mem.Allocator) ![][]const u8 {
        var ready = std.ArrayListUnmanaged([]const u8){};
        defer ready.deinit(allocator);

        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            if (!executed_nodes.contains(entry.key_ptr.*) and entry.value_ptr.isReadyToExecute(executed_nodes)) {
                try ready.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
            }
        }

        return ready.toOwnedSlice(allocator);
    }

    /// Get all dependencies of a node (recursive) - with caching
    pub fn getAllDependencies(self: *DependencyGraph, node_id: []const u8, allocator: std.mem.Allocator) !std.StringHashMap(void) {
        // Check cache first
        if (self.dependency_cache.get(node_id)) |cached| {
            // Return a copy of the cached result
            var result = std.StringHashMap(void).init(allocator);
            errdefer result.deinit();

            var it = cached.iterator();
            while (it.next()) |entry| {
                try result.put(entry.key_ptr.*, {});
            }
            return result;
        }

        // Compute and cache
        var deps = std.StringHashMap(void).init(allocator);
        errdefer deps.deinit();

        try self.getAllDependenciesDFS(node_id, &deps);

        // Cache the result (make a copy for the cache)
        var cache_copy = std.StringHashMap(void).init(self.allocator);
        var it = deps.iterator();
        while (it.next()) |entry| {
            try cache_copy.put(entry.key_ptr.*, {});
        }
        try self.dependency_cache.put(try self.allocator.dupe(u8, node_id), cache_copy);

        return deps;
    }

    fn getAllDependenciesDFS(self: *const DependencyGraph, node_id: []const u8, deps: *std.StringHashMap(void)) !void {
        if (deps.contains(node_id)) return;

        const node = self.nodes.get(node_id) orelse return;
        try deps.put(node_id, {});

        for (node.dependencies.items) |dep| {
            try self.getAllDependenciesDFS(dep, deps);
        }
    }

    /// Get all dependents of a node (recursive)
    pub fn getAllDependents(self: *const DependencyGraph, node_id: []const u8, allocator: std.mem.Allocator) !std.StringHashMap(void) {
        var deps = std.StringHashMap(void).init(allocator);
        errdefer deps.deinit();

        try self.getAllDependentsDFS(node_id, &deps);
        return deps;
    }

    fn getAllDependentsDFS(self: *const DependencyGraph, node_id: []const u8, deps: *std.StringHashMap(void)) !void {
        if (deps.contains(node_id)) return;

        const node = self.nodes.get(node_id) orelse return;
        try deps.put(node_id, {});

        for (node.dependents.items) |dep| {
            try self.getAllDependentsDFS(dep, deps);
        }
    }

    /// Export graph to DOT format for visualization
    pub fn toDot(self: *const DependencyGraph, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);
        const writer = buffer.writer(allocator);

        try writer.writeAll("digraph Dependencies {\n");
        try writer.writeAll("  rankdir=BT;\n"); // Bottom to top for dependency flow
        try writer.writeAll("  node [shape=box];\n\n");

        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr;
            for (node.dependencies.items) |dep| {
                try writer.print("  \"{s}\" -> \"{s}\";\n", .{ dep, entry.key_ptr.* });
            }
        }

        try writer.writeAll("}\n");
        return try buffer.toOwnedSlice(allocator);
    }

    /// Get node information
    pub fn getNode(self: *const DependencyGraph, id: []const u8) ?DagNode {
        return self.nodes.get(id);
    }

    /// Get nodes that can be executed in parallel (all dependencies satisfied, no conflicts)
    pub fn getParallelExecutionGroups(self: *const DependencyGraph, executed_nodes: *std.StringHashMap(void), allocator: std.mem.Allocator) ![][][]const u8 {
        var groups = std.ArrayListUnmanaged([][]const u8){};
        defer groups.deinit(allocator);

        var remaining_nodes = std.StringHashMap(void).init(allocator);
        defer remaining_nodes.deinit();

        // Start with all nodes that aren't executed
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            if (!executed_nodes.contains(entry.key_ptr.*)) {
                try remaining_nodes.put(entry.key_ptr.*, {});
            }
        }

        while (remaining_nodes.count() > 0) {
            var current_group = std.ArrayListUnmanaged([]const u8){};
            defer current_group.deinit(allocator);

            // Find all nodes that are ready to execute
            var ready_it = remaining_nodes.iterator();
            while (ready_it.next()) |entry| {
                const node = self.nodes.get(entry.key_ptr.*) orelse continue;
                if (node.isReadyToExecute(executed_nodes)) {
                    try current_group.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
                }
            }

            if (current_group.items.len == 0) {
                // No more nodes can be executed - this shouldn't happen if there are no cycles
                return error.CircularDependency;
            }

            // Remove these nodes from remaining and add to executed
            for (current_group.items) |node_id| {
                _ = remaining_nodes.remove(node_id);
                try executed_nodes.put(node_id, {});
            }

            try groups.append(allocator, try current_group.toOwnedSlice(allocator));
        }

        return groups.toOwnedSlice(allocator);
    }
};
