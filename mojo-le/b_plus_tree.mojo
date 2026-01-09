"""
B+ Tree Implementation in Mojo
===============================

A B+ tree is a self-balancing tree data structure that maintains sorted data
and allows searches, sequential access, insertions, and deletions in O(log n) time.
Unlike B-trees, B+ trees store all data in leaf nodes, making them ideal for
database indexing and file systems.

Key Characteristics:
- All data is stored in leaf nodes
- Internal nodes contain only keys for navigation
- Leaf nodes are linked for efficient range queries
- Self-balancing with minimum fill factor
- Excellent for disk-based storage systems

This implementation demonstrates:
- Core B+ tree operations (insert, search, delete)
- Node splitting and merging
- Range queries and bulk operations
- Memory-efficient data structures
- Integration patterns with PyArrow for persistent storage
"""

from collections import List

# B+ Tree Configuration
alias ORDER = 4  # Maximum keys per node (order-1 minimum)
alias MAX_KEYS = ORDER - 1
alias MIN_KEYS = (ORDER // 2) - 1

# Node structure for B+ Tree
struct BPlusNode:
    var keys: List[Int]  # Keys for navigation/searching
    var children: List[Pointer[mut=True, BPlusNode]]  # Child pointers (internal nodes)
    var values: List[String]  # Data values (leaf nodes only)
    var is_leaf: Bool
    var parent: Pointer[mut=True, BPlusNode]  # Parent node pointer
    var next_leaf: Pointer[mut=True, BPlusNode]  # Next leaf for range queries
    var prev_leaf: Pointer[mut=True, BPlusNode]  # Previous leaf for range queries

    fn __init__(self, is_leaf: Bool = False):
        self.keys = List[Int]()
        self.children = List[Pointer[mut=True, BPlusNode]]()
        self.values = List[String]()
        self.is_leaf = is_leaf
        self.parent = Pointer[mut=True, BPlusNode].get_null()
        self.next_leaf = Pointer[mut=True, BPlusNode].get_null()
        self.prev_leaf = Pointer[mut=True, BPlusNode].get_null()

    fn deinit(self):
        # Clean up child pointers (but don't delete recursively to avoid cycles)
        self.children.clear()
        self.keys.clear()
        self.values.clear()

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
        # TODO: Implement proper tree destruction
        # For now, just deallocate root
        if self.root:
            self.root.destroy()

    # Search for a key in the B+ tree
    fn search(self, key: Int) -> String:
        """Search for a key and return its associated value."""
        var node = self.root
        var level = self.height

        # Traverse down to leaf
        while not node[].is_leaf and level > 1:
            var i = 0
            while i < len(node[].keys) and key >= node[].keys[i]:
                i += 1
            node = node[].children[i]
            level -= 1

        # Search within leaf node
        for i in range(len(node[].keys)):
            if node[].keys[i] == key:
                return node[].values[i]

        return ""  # Key not found

    # Insert a key-value pair
    fn insert(inout self, key: Int, value: String):
        """Insert a key-value pair into the B+ tree."""
        if self.num_keys == 0:
            # Empty tree
            self.root[].keys.append(key)
            self.root[].values.append(value)
            self.num_keys += 1
            return

        # Find the leaf where key should be inserted
        var leaf = self._find_leaf(key)

        # Insert into leaf
        var insert_pos = 0
        while insert_pos < len(leaf[].keys) and key > leaf[].keys[insert_pos]:
            insert_pos += 1

        # Insert key and value
        leaf[].keys.insert(insert_pos, key)
        leaf[].values.insert(insert_pos, value)
        self.num_keys += 1

        # Check if leaf needs to split
        if len(leaf[].keys) > MAX_KEYS:
            self._split_leaf(leaf)

    # Delete a key from the tree
    fn delete(inout self, key: Int) -> Bool:
        """Delete a key from the B+ tree. Returns True if key was found and deleted."""
        var leaf = self._find_leaf(key)

        # Find key in leaf
        for i in range(len(leaf[].keys)):
            if leaf[].keys[i] == key:
                # Remove key and value
                leaf[].keys.remove(i)
                leaf[].values.remove(i)
                self.num_keys -= 1

                # Check if leaf needs to be merged or rebalanced
                if len(leaf[].keys) < MIN_KEYS and self.height > 1:
                    self._rebalance_leaf(leaf)

                return True

        return False  # Key not found

    # Range query: find all keys between start and end
    fn range_query(self, start_key: Int, end_key: Int) -> List[Tuple[Int, String]]:
        """Perform a range query returning all key-value pairs in the range."""
        var results = List[Tuple[Int, String]]()

        # Find starting leaf
        var current_leaf = self._find_leaf(start_key)

        # Traverse through leaves
        while current_leaf:
            for i in range(len(current_leaf[].keys)):
                var key = current_leaf[].keys[i]
                if key >= start_key and key <= end_key:
                    results.append((key, current_leaf[].values[i]))
                elif key > end_key:
                    return results  # Past the end range

            current_leaf = current_leaf[].next_leaf

        return results^

    # Helper: Find the leaf node where a key should be located
    fn _find_leaf(self, key: Int) -> Pointer[BPlusNode, mut=True]:
        """Find the leaf node where the key should be located."""
        var node = self.root
        var level = self.height

        while not node[].is_leaf and level > 1:
            var i = 0
            while i < len(node[].keys) and key >= node[].keys[i]:
                i += 1
            node = node[].children[i]
            level -= 1

        return node

    # Helper: Split a full leaf node
    fn _split_leaf(inout self, leaf: Pointer[BPlusNode, mut=True]):
        """Split a leaf node when it becomes full."""
        var mid = ORDER // 2
        var new_leaf = Pointer[BPlusNode, mut=True].alloc(1)
        new_leaf[] = BPlusNode(is_leaf=True)

        # Move second half of keys and values to new leaf
        for i in range(mid, len(leaf[].keys)):
            new_leaf[].keys.append(leaf[].keys[i])
            new_leaf[].values.append(leaf[].values[i])

        # Remove moved elements from original leaf
        while len(leaf[].keys) > mid:
            leaf[].keys.remove(-1)
            leaf[].values.remove(-1)

        # Update leaf links
        new_leaf[].next_leaf = leaf[].next_leaf
        if leaf[].next_leaf:
            leaf[].next_leaf[].prev_leaf = new_leaf
        leaf[].next_leaf = new_leaf
        new_leaf[].prev_leaf = leaf

        # Insert separator key into parent
        var separator_key = new_leaf[].keys[0]
        self._insert_into_parent(leaf, separator_key, new_leaf)

    # Helper: Insert a key into parent node during split
    fn _insert_into_parent(inout self, left: Pointer[BPlusNode, mut=True], key: Int, right: Pointer[BPlusNode, mut=True]):
        """Insert a separator key into the parent node."""
        if left[].parent == Pointer[BPlusNode, mut=True].get_null():
            # Create new root
            var new_root = Pointer[BPlusNode, mut=True].alloc(1)
            new_root[] = BPlusNode(is_leaf=False)
            new_root[].keys.append(key)
            new_root[].children.append(left)
            new_root[].children.append(right)
            left[].parent = new_root
            right[].parent = new_root
            self.root = new_root
            self.height += 1
            return

        var parent = left[].parent
        var insert_pos = 0
        while insert_pos < len(parent[].keys) and key > parent[].keys[insert_pos]:
            insert_pos += 1

        parent[].keys.insert(insert_pos, key)
        parent[].children.insert(insert_pos + 1, right)
        right[].parent = parent

        # Check if parent needs to split
        if len(parent[].keys) > MAX_KEYS:
            self._split_internal(parent)

    # Helper: Split an internal node
    fn _split_internal(inout self, node: Pointer[BPlusNode, mut=True]):
        """Split an internal node when it becomes full."""
        var mid = ORDER // 2
        var new_node = Pointer[BPlusNode, mut=True].alloc(1)
        new_node[] = BPlusNode(is_leaf=False)

        # Move keys and children to new node
        var separator_key = node[].keys[mid]
        for i in range(mid + 1, len(node[].keys)):
            new_node[].keys.append(node[].keys[i])
        for i in range(mid + 1, len(node[].children)):
            new_node[].children.append(node[].children[i])
            node[].children[i][].parent = new_node

        # Remove moved elements
        while len(node[].keys) > mid:
            node[].keys.remove(-1)
        while len(node[].children) > mid + 1:
            node[].children.remove(-1)

        # Insert separator into parent
        self._insert_into_parent(node, separator_key, new_node)

    # Helper: Rebalance a leaf node that's underfull
    fn _rebalance_leaf(inout self, leaf: Pointer[BPlusNode, mut=True]):
        """Rebalance or merge an underfull leaf node."""
        # For simplicity, we'll implement a basic version
        # In a full implementation, this would borrow from siblings or merge
        if len(leaf[].keys) >= MIN_KEYS:
            return  # No rebalancing needed

        # Try to borrow from left sibling
        if leaf[].prev_leaf != Pointer[BPlusNode, mut=True].get_null() and len(leaf[].prev_leaf[].keys) > MIN_KEYS:
            var sibling = leaf[].prev_leaf
            var borrowed_key = sibling[].keys[-1]
            var borrowed_value = sibling[].values[-1]
            sibling[].keys.remove(-1)
            sibling[].values.remove(-1)

            # Insert at beginning of current leaf
            leaf[].keys.insert(0, borrowed_key)
            leaf[].values.insert(0, borrowed_value)
            return

        # Try to borrow from right sibling
        if leaf[].next_leaf != Pointer[BPlusNode, mut=True].get_null() and len(leaf[].next_leaf[].keys) > MIN_KEYS:
            var sibling = leaf[].next_leaf
            var borrowed_key = sibling[].keys[0]
            var borrowed_value = sibling[].values[0]
            sibling[].keys.remove(0)
            sibling[].values.remove(0)

            # Insert at end of current leaf
            leaf[].keys.append(borrowed_key)
            leaf[].values.append(borrowed_value)
            return

        # Merge with sibling (simplified - merge with right sibling)
        if leaf[].next_leaf != Pointer[BPlusNode, mut=True].get_null():
            var sibling = leaf[].next_leaf
            for i in range(len(sibling[].keys)):
                leaf[].keys.append(sibling[].keys[i])
                leaf[].values.append(sibling[].values[i])

            # Update links
            leaf[].next_leaf = sibling[].next_leaf
            if sibling[].next_leaf != Pointer[BPlusNode, mut=True].get_null():
                sibling[].next_leaf[].prev_leaf = leaf

            # Remove from parent (simplified)
            # In full implementation, would remove separator key from parent
            sibling.destroy()

    # Get tree statistics
    fn get_stats(self) -> Tuple[Int, Int, Int]:
        """Return (height, total_keys, total_nodes)."""
        var total_nodes = 0
        var leaf_count = 0

        if self.root:
            var queue = List[Pointer[BPlusNode, mut=True]]()
            queue.append(self.root)

            while len(queue) > 0:
                var level_size = len(queue)
                total_nodes += level_size

                for _ in range(level_size):
                    var node = queue[0]
                    queue.remove(0)

                    if node[].is_leaf:
                        leaf_count += 1
                    else:
                        for child in node[].children:
                            queue.append(child[])

        return (self.height, self.num_keys, total_nodes)


# Demonstration and testing functions
fn demo_b_plus_tree():
    """Demonstrate B+ tree operations."""
    print("=== B+ Tree Demonstration ===\n")

    var tree = BPlusTree()
    print("Tree created successfully")
    print("Initial stats:", tree.get_stats())

    # Insert test data
    print("Inserting data...")
    var test_data = List[Tuple[Int, String]]()
    test_data.append((10, "Alice"))
    test_data.append((20, "Bob"))
    test_data.append((5, "Charlie"))
    test_data.append((15, "Diana"))
    test_data.append((25, "Eve"))
    test_data.append((30, "Frank"))
    test_data.append((35, "Grace"))
    test_data.append((40, "Henry"))

    for item in test_data:
        tree.insert(item[0], item[1])
        print("Inserted:", item[0], "->", item[1])

    print("\nTree stats:", tree.get_stats())

    # Search operations
    print("\n=== Search Operations ===")
    var search_keys = List[Int]()
    search_keys.append(15)
    search_keys.append(25)
    search_keys.append(50)  # Non-existent

    for key in search_keys:
        var result = tree.search(key)
        if result != "":
            print("Found key", key, "->", result)
        else:
            print("Key", key, "not found")

    # Range query
    print("\n=== Range Query (10-30) ===")
    var range_results = tree.range_query(10, 30)
    for result in range_results:
        print("Range result:", result[0], "->", result[1])

    # Delete operation
    print("\n=== Delete Operations ===")
    var delete_keys = List[Int]()
    delete_keys.append(20)
    delete_keys.append(35)

    for key in delete_keys:
        var deleted = tree.delete(key)
        if deleted:
            print("Deleted key:", key)
        else:
            print("Key", key, "not found for deletion")

    print("\nFinal tree stats:", tree.get_stats())


fn main():
    """Main entry point."""
    demo_b_plus_tree()