"""
Merkle B+ Tree with SHA-256 and Universal Compaction
====================================================

Enhanced Merkle B+ Tree using SHA-256 for cryptographic integrity
and universal compaction strategy for optimization.
"""

from collections import List
from python import Python

# SHA-256 Hash function using Python interop
struct SHA256Hash:
    @staticmethod
    fn compute(data: String) -> String:
        """Compute SHA-256 hash of string data."""
        var hashlib = Python.import_module("hashlib")
        var hash_obj = hashlib.sha256(data.encode())
        return String(hash_obj.hexdigest())

# Simplified Merkle B+ Tree Node with SHA-256
struct MerkleBPlusNode(Movable, Copyable):
    var keys: List[Int]
    var values: List[String]
    var is_leaf: Bool
    var merkle_hash: String

    fn __init__(out self, is_leaf: Bool = False):
        self.keys = List[Int]()
        self.values = List[String]()
        self.is_leaf = is_leaf
        self.merkle_hash = ""

    fn __copyinit__(out self, other: Self):
        self.keys = other.keys.copy()
        self.values = other.values.copy()
        self.is_leaf = other.is_leaf
        self.merkle_hash = other.merkle_hash

    fn __moveinit__(out self, owned other: Self):
        self.keys = other.keys^
        self.values = other.values^
        self.is_leaf = other.is_leaf
        self.merkle_hash = other.merkle_hash

    fn compute_hash(mut self):
        """Compute SHA-256 Merkle hash for this node."""
        var hash_data = String("")
        hash_data += String(self.is_leaf) + "|"

        for i in range(len(self.keys)):
            hash_data += String(self.keys[i]) + ":" + self.values[i] + ";"

        self.merkle_hash = SHA256Hash.compute(hash_data)

    fn is_full(self) -> Bool:
        """Check if node is at maximum capacity."""
        return len(self.keys) >= 4  # Small order for demo

    fn is_underflow(self) -> Bool:
        """Check if node is below minimum capacity."""
        return len(self.keys) < 1

# Universal Compaction Strategy
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

    fn compact(mut self, mut tree: MerkleBPlusTree):
        """Perform universal compaction on the tree."""
        print("Performing universal compaction...")

        # Sort keys and values by key
        var sorted_indices = List[Int]()
        for i in range(len(tree.keys)):
            sorted_indices.append(i)

        # Simple bubble sort
        for i in range(len(sorted_indices)):
            for j in range(i + 1, len(sorted_indices)):
                if tree.keys[sorted_indices[i]] > tree.keys[sorted_indices[j]]:
                    var temp = sorted_indices[i]
                    sorted_indices[i] = sorted_indices[j]
                    sorted_indices[j] = temp

        # Rebuild sorted lists
        var sorted_keys = List[Int]()
        var sorted_values = List[String]()

        for idx in sorted_indices:
            sorted_keys.append(tree.keys[idx])
            sorted_values.append(tree.values[idx])

        tree.keys = sorted_keys.copy()
        tree.values = sorted_values.copy()

        self.reorganization_count += 1
        print("Universal compaction completed. Reorganizations:", self.reorganization_count)

# Merkle B+ Tree with SHA-256
struct MerkleBPlusTree:
    var keys: List[Int]
    var values: List[String]
    var merkle_hash: String
    var compaction_strategy: UniversalCompactionStrategy

    fn __init__(out self):
        self.keys = List[Int]()
        self.values = List[String]()
        self.merkle_hash = ""
        self.compaction_strategy = UniversalCompactionStrategy()

    fn compute_hash(mut self):
        """Compute SHA-256 Merkle hash for the tree."""
        var hash_data = String("")
        for i in range(len(self.keys)):
            hash_data += String(self.keys[i]) + ":" + self.values[i] + ";"
        self.merkle_hash = SHA256Hash.compute(hash_data)

    fn insert(mut self, key: Int, value: String):
        """Insert key-value pair with SHA-256 hash updates."""
        # Check if universal compaction is needed
        if self.compaction_strategy.should_compact(self):
            self.compaction_strategy.compact(self)

        # Find insertion point
        var insert_pos = 0
        while insert_pos < len(self.keys) and key > self.keys[insert_pos]:
            insert_pos += 1

        self.keys.insert(insert_pos, key)
        self.values.insert(insert_pos, value)

        # Update Merkle hash
        self.compute_hash()

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
                    self.compaction_strategy.compact(self)

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
        return 1 if len(self.keys) < 2 else 0

    fn get_stats(mut self) -> String:
        """Get tree statistics."""
        var stats = "Merkle B+ Tree Statistics (SHA-256):\n"
        stats += "  Keys stored: " + String(len(self.keys)) + "\n"
        stats += "  Integrity verified: " + String(self.verify_integrity()) + "\n"
        stats += "  Compaction reorganizations: " + String(self.compaction_strategy.reorganization_count) + "\n"
        stats += "  Merkle Root Hash: " + self.merkle_hash + "\n"
        return stats