from collections import List
from types import Row

struct BPlusNode(Copyable, Movable):
    var keys: List[Int]
    var children_indices: List[Int]
    var values: List[Row]
    var is_leaf: Bool
    var next_leaf_index: Int
    var parent_index: Int

    fn __init__(out self, is_leaf: Bool = False):
        self.keys = List[Int]()
        self.children_indices = List[Int]()
        self.values = List[Row]()
        self.is_leaf = is_leaf
        self.next_leaf_index = -1
        self.parent_index = -1

struct BPlusTree(Copyable, Movable):
    var nodes: List[BPlusNode]
    var root_index: Int
    var order: Int

    fn __init__(out self, order: Int = 3):
        self.nodes = List[BPlusNode]()
        self.order = order
        # Create root node
        var root = BPlusNode(True)
        self.nodes.append(root ^)
        self.root_index = 0

    fn insert(mut self, key: Int, value: Row) raises:
        # Find leaf node
        var leaf_index = self._find_leaf(key)
        var leaf = self.nodes[leaf_index].copy()
        
        # Insert into leaf
        var pos = 0
        while pos < len(leaf.keys) and leaf.keys[pos] < key:
            pos += 1
        
        leaf.keys.insert(pos, key)
        leaf.values.insert(pos, value.copy())
        
        # Update the node
        self.nodes[leaf_index] = leaf ^
        
        # Check if need split
        if len(leaf.keys) > self.order - 1:
            self._split_node(leaf_index)

    fn _find_leaf(self, key: Int) -> Int:
        var current = self.root_index
        while not self.nodes[current].is_leaf:
            var node = self.nodes[current].copy()
            var i = 0
            while i < len(node.keys) and key >= node.keys[i]:
                i += 1
            current = node.children_indices[i]
        return current

    fn _split_node(mut self, node_index: Int):
        var node = self.nodes[node_index].copy()
        var mid = len(node.keys) // 2
        var mid_key = node.keys[mid]
        
        # Create new node
        var new_node = BPlusNode(node.is_leaf)
        for i in range(mid + 1, len(node.keys)):
            new_node.keys.append(node.keys[i])
            if node.is_leaf:
                new_node.values.append(node.values[i].copy())
            else:
                new_node.children_indices.append(node.children_indices[i])
        
        # Remove from old node
        while len(node.keys) > mid:
            _ = node.keys.pop()
            if node.is_leaf:
                _ = node.values.pop()
            else:
                _ = node.children_indices.pop()
        
        # Append new node
        self.nodes.append(new_node ^)
        var new_node_index = len(self.nodes) - 1
        
        # If leaf, link
        if node.is_leaf:
            new_node.next_leaf_index = node.next_leaf_index
            node.next_leaf_index = new_node_index
        
        # If root, create new root
        if node_index == self.root_index:
            var new_root = BPlusNode(False)
            new_root.keys.append(mid_key)
            new_root.children_indices.append(node_index)
            new_root.children_indices.append(new_node_index)
            self.nodes[node_index].parent_index = len(self.nodes)
            self.nodes[new_node_index].parent_index = len(self.nodes)
            self.nodes.append(new_root ^)
            self.root_index = len(self.nodes) - 1
        else:
            # Insert into parent
            self._insert_into_parent(node.parent_index, mid_key, new_node_index)
        
        # Update node
        self.nodes[node_index] = node ^

    fn _insert_into_parent(mut self, parent_index: Int, key: Int, child_index: Int):
        var parent = self.nodes[parent_index].copy()
        var pos = 0
        while pos < len(parent.keys) and key > parent.keys[pos]:
            pos += 1
        parent.keys.insert(pos, key)
        parent.children_indices.insert(pos + 1, child_index)
        self.nodes[child_index].parent_index = parent_index
        self.nodes[parent_index] = parent ^
        if len(parent.keys) > self.order - 1:
            self._split_node(parent_index)

    fn search(self, key: Int) -> Row:
        var leaf_index = self._find_leaf(key)
        var leaf = self.nodes[leaf_index].copy()
        for i in range(len(leaf.keys)):
            if leaf.keys[i] == key:
                return leaf.values[i].copy()
        # Not found, return empty row
        return Row()