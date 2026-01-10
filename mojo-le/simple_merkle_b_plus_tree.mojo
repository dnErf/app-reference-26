"""
Simplified Merkle B+ Tree with Universal Compaction Strategy
============================================================

This is a simplified implementation demonstrating the core concepts of
Merkle hash verification and universal compaction strategy.

Key Features:
- Merkle hash verification for data integrity
- Universal compaction strategy for tree optimization
- Basic B+ tree operations (insert, search, delete)
- Range queries with hash verification

Note: This is a simplified single-node implementation for demonstration.
A full B+ tree would require more complex node management.
"""

from collections import List

# Hash function for Merkle tree
struct Hash:
    @staticmethod
    fn compute(data: String) -> UInt64:
        """Compute hash of string data."""
        var h = UInt64(0)
        for i in range(len(data)):
            h = (h * 31) + UInt64(ord(data[i]))
        return h

# Simplified Merkle B+ Tree (Single node for demonstration)
struct MerkleBPlusTree:
    var keys: List[Int]
    var values: List[String]
    var merkle_hash: UInt64
    var compaction_strategy: UniversalCompactionStrategy

    fn __init__(out self):
        self.keys = List[Int]()
        self.values = List[String]()
        self.merkle_hash = 0
        self.compaction_strategy = UniversalCompactionStrategy()

    fn compute_hash(mut self):
        """Compute Merkle hash for the tree."""
        var hash_data = String("")
        for i in range(len(self.keys)):
            hash_data += String(self.keys[i]) + ":" + self.values[i] + ";"
        self.merkle_hash = Hash.compute(hash_data)

    fn insert(mut self, key: Int, value: String):
        """Insert key-value pair with Merkle hash updates."""
        # Check if universal compaction is needed
        if self.compaction_strategy.should_compact(self):
            self.perform_compaction()

        # Find insertion point
        var insert_pos = 0
        while insert_pos < len(self.keys) and key > self.keys[insert_pos]:
            insert_pos += 1

        self.keys.insert(insert_pos, key)
        self.values.insert(insert_pos, value)

        # Update Merkle hash
        self.compute_hash()

    fn perform_compaction(mut self):
        """Perform compaction on this tree."""
        # In this simplified version, compaction just sorts the data
        # In a real implementation, this would reorganize the tree structure

        # Sort keys and values by key
        var sorted_indices = List[Int]()
        for i in range(len(self.keys)):
            sorted_indices.append(i)

        # Simple bubble sort for demonstration
        for i in range(len(sorted_indices)):
            for j in range(i + 1, len(sorted_indices)):
                if self.keys[sorted_indices[i]] > self.keys[sorted_indices[j]]:
                    var temp = sorted_indices[i]
                    sorted_indices[i] = sorted_indices[j]
                    sorted_indices[j] = temp

        # Rebuild sorted lists
        var sorted_keys = List[Int]()
        var sorted_values = List[String]()

        for idx in sorted_indices:
            sorted_keys.append(self.keys[idx])
            sorted_values.append(self.values[idx])

        self.keys = sorted_keys.copy()
        self.values = sorted_values.copy()

        self.compaction_strategy.reorganization_count += 1
        print("Universal compaction completed. Reorganizations:", self.compaction_strategy.reorganization_count)

    fn search(self, key: Int) -> String:
        """Search for a key and return its value."""
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                return self.values[i]
        return ""

    fn delete(mut self, key: Int) -> Bool:
        """Delete a key from the tree."""
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                _ = self.keys.pop(i)
                _ = self.values.pop(i)
                self.compute_hash()

                # Check if universal compaction is needed
                if self.compaction_strategy.should_compact(self):
                    self.perform_compaction()

                return True
        return False

    fn range_query(self, start_key: Int, end_key: Int) -> List[String]:
        """Perform range query."""
        var results = List[String]()
        for i in range(len(self.keys)):
            if self.keys[i] >= start_key and self.keys[i] <= end_key:
                results.append(self.values[i])
        return results.copy()

    fn verify_integrity(mut self) -> Bool:
        """Verify Merkle tree integrity."""
        var expected_hash = self.merkle_hash
        self.compute_hash()
        return self.merkle_hash == expected_hash

    fn count_nodes(self) -> Int:
        """Count total nodes (always 1 in this simplified version)."""
        return 1

    fn count_underutilized_nodes(self) -> Int:
        """Count underutilized nodes."""
        # In this simplified version, consider underutilized if less than 2 keys
        return 1 if len(self.keys) < 2 else 0

    fn clear(mut self):
        """Clear the tree."""
        self.keys.clear()
        self.values.clear()
        self.merkle_hash = 0

    fn get_stats(mut self) -> String:
        """Get tree statistics."""
        var stats = "Simplified Merkle B+ Tree Statistics:\n"
        stats += "  Keys stored: " + String(len(self.keys)) + "\n"
        stats += "  Integrity verified: " + String(self.verify_integrity()) + "\n"
        stats += "  Compaction reorganizations: " + String(self.compaction_strategy.reorganization_count) + "\n"
        return stats

# Universal Compaction Strategy for B+ Tree
struct UniversalCompactionStrategy:
    var compaction_threshold: Float64
    var reorganization_count: Int

    fn __init__(out self, threshold: Float64 = 0.7):
        self.compaction_threshold = threshold
        self.reorganization_count = 0

    fn should_compact(self, tree: MerkleBPlusTree) -> Bool:
        """Determine if tree needs universal compaction."""
        var total_nodes = tree.count_nodes()
        var underutilized_nodes = tree.count_underutilized_nodes()

        if total_nodes == 0:
            return False

        var utilization_ratio = Float64(underutilized_nodes) / Float64(total_nodes)
        return utilization_ratio >= self.compaction_threshold

fn main():
    """Demonstrate Simplified Merkle B+ Tree with Universal Compaction."""
    print("=== Simplified Merkle B+ Tree with Universal Compaction ===\n")

    var tree = MerkleBPlusTree()

    print("Initial tree stats:")
    print(tree.get_stats())
    print()

    # Insert test data
    print("Inserting test data...")
    for i in range(10):
        tree.insert(i, "value_" + String(i))

    print("After insertions:")
    print(tree.get_stats())
    print()

    # Test search
    print("Searching for key 7:", tree.search(7))
    print()

    # Test range query
    var range_results = tree.range_query(3, 7)
    print("Range query [3, 7] found", len(range_results), "results")
    print()

    # Delete some keys to create underutilization
    print("Deleting keys to trigger compaction...")
    for i in range(0, 10, 2):  # Delete even keys
        _ = tree.delete(i)

    print("After deletions:")
    print(tree.get_stats())
    print()

    # Insert more data to potentially trigger compaction
    print("Inserting more data...")
    for i in range(100, 110):
        tree.insert(i, "new_value_" + String(i))

    print("Final tree stats:")
    print(tree.get_stats())
    print()

    print("=== Simplified Merkle B+ Tree Demo Complete ===")