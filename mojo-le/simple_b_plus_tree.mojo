"""
B+ Tree Implementation in Mojo
===============================

A simplified B+ tree implementation demonstrating core concepts.
"""

from collections import List

# B+ Tree Configuration
alias ORDER = 4  # Maximum keys per node
alias MAX_KEYS = ORDER - 1

# Node structure for B+ Tree
struct BPlusNode:
    var keys: List[Int]
    var values: List[String]  # Only used in leaf nodes
    var children: List[Pointer[mut=True, BPlusNode]]
    var is_leaf: Bool
    var next_leaf: Pointer[mut=True, BPlusNode]

    fn __init__(self, is_leaf: Bool = False):
        self.keys = List[Int]()
        self.values = List[String]()
        self.children = List[Pointer[mut=True, BPlusNode]]()
        self.is_leaf = is_leaf
        self.next_leaf = Pointer[mut=True, BPlusNode].get_null()

    fn deinit(self):
        self.keys.clear()
        self.values.clear()
        self.children.clear()

# B+ Tree main structure
struct BPlusTree:
    var root: Pointer[mut=True, BPlusNode]
    var height: Int
    var num_keys: Int

    fn __init__(self):
        self.root = Pointer[mut=True, BPlusNode].alloc(1)
        self.root[] = BPlusNode(is_leaf=True)
        self.height = 1
        self.num_keys = 0

    fn deinit(self):
        if self.root:
            self.root.destroy()

    # Insert a key-value pair
    fn insert(self, key: Int, value: String):
        """Insert a key-value pair (simplified version)."""
        if self.num_keys == 0:
            self.root[].keys.append(key)
            self.root[].values.append(value)
            self.num_keys += 1
            return

        # Simple insert without splitting for now
        var leaf = self._find_leaf(key)
        var pos = 0
        while pos < len(leaf[].keys) and key > leaf[].keys[pos]:
            pos += 1

        leaf[].keys.insert(pos, key)
        leaf[].values.insert(pos, value)
        self.num_keys += 1

    # Search for a key
    fn search(self, key: Int) -> String:
        """Search for a key and return its value."""
        var leaf = self._find_leaf(key)
        for i in range(len(leaf[].keys)):
            if leaf[].keys[i] == key:
                return leaf[].values[i]
        return ""

    # Helper: Find leaf node for a key
    fn _find_leaf(self, key: Int) -> Pointer[mut=True, BPlusNode]:
        """Find the leaf node where key should be."""
        var node = self.root
        while not node[].is_leaf:
            var i = 0
            while i < len(node[].keys) and key >= node[].keys[i]:
                i += 1
            if i < len(node[].children):
                node = node[].children[i]
            else:
                break
        return node

    # Get tree statistics
    fn get_stats(self) -> Tuple[Int, Int]:
        """Return (height, num_keys)."""
        return (self.height, self.num_keys)


fn demo_b_plus_tree():
    """Demonstrate basic B+ tree operations."""
    print("=== B+ Tree Demonstration ===\n")

    var tree = BPlusTree()
    print("Tree created successfully")
    print("Initial stats:", tree.get_stats())

    # Insert some data
    print("\nInserting data...")
    tree.insert(10, "Alice")
    tree.insert(20, "Bob")
    tree.insert(5, "Charlie")
    print("After inserts:", tree.get_stats())

    # Search
    print("\nSearching...")
    print("Key 10:", tree.search(10))
    print("Key 20:", tree.search(20))
    print("Key 5:", tree.search(5))
    print("Key 99:", tree.search(99))


fn main():
    """Main entry point."""
    demo_b_plus_tree()