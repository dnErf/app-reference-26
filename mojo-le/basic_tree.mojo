"""
Basic Tree Structures in Mojo
=============================

Demonstrating fundamental tree data structures before implementing B+ trees.
"""

from collections import List

# Simplified Tree using Lists for storage (sorted array approach)
struct SimpleTree:
    var keys: List[Int]
    var values: List[String]

    fn __init__(out self):
        self.keys = List[Int]()
        self.values = List[String]()

    fn insert(mut self, key: Int, value: String):
        """Insert a key-value pair (simple sorted insert)."""
        var pos = 0
        while pos < len(self.keys) and key > self.keys[pos]:
            pos += 1

        self.keys.insert(pos, key)
        self.values.insert(pos, value)

    fn search(self, key: Int) -> String:
        """Search for a key and return its value."""
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                return self.values[i]
        return ""

    fn get_stats(self) -> Int:
        """Return number of keys."""
        return len(self.keys)


fn demo_simple_tree():
    """Demonstrate basic tree operations."""
    print("=== Simple Tree Demonstration ===\n")

    var tree = SimpleTree()
    print("Tree created successfully")

    # Insert some data
    print("\nInserting data...")
    tree.insert(10, "Alice")
    tree.insert(20, "Bob")
    tree.insert(5, "Charlie")
    print("Tree size:", tree.get_stats())

    # Search
    print("\nSearching...")
    print("Key 10:", tree.search(10))
    print("Key 20:", tree.search(20))
    print("Key 5:", tree.search(5))
    print("Key 99:", tree.search(99))


fn main():
    """Main entry point."""
    demo_simple_tree()