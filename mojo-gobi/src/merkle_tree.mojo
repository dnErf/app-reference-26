"""
Merkle B+ Tree with SHA-256 and Universal Compaction
====================================================

Enhanced Merkle B+ Tree using SHA-256 for cryptographic integrity
and universal compaction strategy for optimization.
"""

from collections import List
from python import Python, PythonObject

# SHA-256 Hash function using Python interop
struct SHA256Hash:
    @staticmethod
    fn compute(data: String) raises -> String:
        """Compute SHA-256 hash of string data."""
        var hashlib = Python.import_module("hashlib")
        var py_data = PythonObject(data)
        var hash_obj = hashlib.sha256(py_data.encode("utf-8"))
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

# Universal Compaction Strategy with Performance Optimizations
struct UniversalCompactionStrategy(Movable, Copyable):
    var compaction_threshold: Float64
    var reorganization_count: Int
    var adaptive_threshold: Bool
    var min_threshold: Float64
    var max_threshold: Float64

    fn __init__(out self, threshold: Float64 = 0.7, adaptive: Bool = True):
        self.compaction_threshold = threshold
        self.reorganization_count = 0
        self.adaptive_threshold = adaptive
        self.min_threshold = 0.5
        self.max_threshold = 0.9

    fn __copyinit__(out self, other: Self):
        self.compaction_threshold = other.compaction_threshold
        self.reorganization_count = other.reorganization_count
        self.adaptive_threshold = other.adaptive_threshold
        self.min_threshold = other.min_threshold
        self.max_threshold = other.max_threshold

    fn __moveinit__(out self, deinit existing: Self):
        self.compaction_threshold = existing.compaction_threshold
        self.reorganization_count = existing.reorganization_count
        self.adaptive_threshold = existing.adaptive_threshold
        self.min_threshold = existing.min_threshold
        self.max_threshold = existing.max_threshold

    fn should_compact(self, tree: MerkleBPlusTree) -> Bool:
        """Determine if tree needs universal compaction with adaptive thresholds."""
        var total_nodes = tree.count_nodes()
        var underutilized_nodes = tree.count_underutilized_nodes()

        if total_nodes == 0:
            return False

        var utilization_ratio = Float64(underutilized_nodes) / Float64(total_nodes)
        return utilization_ratio >= self.compaction_threshold

    fn adjust_threshold(mut self):
        """Adjust compaction threshold based on reorganization frequency."""
        if self.adaptive_threshold:
            if self.reorganization_count > 10:
                # If we've compacted many times, lower threshold to reduce frequency
                self.compaction_threshold = max(self.min_threshold, self.compaction_threshold - 0.1)
            elif self.reorganization_count < 3:
                # If we haven't compacted much, can be more aggressive
                self.compaction_threshold = min(self.max_threshold, self.compaction_threshold + 0.05)

    fn compact(mut self, tree: MerkleBPlusTree):
        """Perform compaction on the given tree."""
        tree.perform_compaction()

# Merkle B+ Tree with SHA-256
struct MerkleBPlusTree(Movable, Copyable):
    var keys: List[Int]
    var values: List[String]
    var merkle_hash: String
    var compaction_strategy: UniversalCompactionStrategy

    fn __init__(out self):
        self.keys = List[Int]()
        self.values = List[String]()
        self.merkle_hash = ""
        self.compaction_strategy = UniversalCompactionStrategy()

    fn __copyinit__(out self, other: Self):
        self.keys = other.keys.copy()
        self.values = other.values.copy()
        self.merkle_hash = other.merkle_hash
        self.compaction_strategy = other.compaction_strategy.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.keys = existing.keys^
        self.values = existing.values^
        self.merkle_hash = existing.merkle_hash^
        self.compaction_strategy = existing.compaction_strategy^

    fn compute_hash(mut self) raises:
        """Compute SHA-256 Merkle hash for the tree."""
        var hash_data = String("")
        for i in range(len(self.keys)):
            hash_data += String(self.keys[i]) + ":" + self.values[i] + ";"
        self.merkle_hash = SHA256Hash.compute(hash_data)

    fn perform_compaction(mut self):
        """Perform universal compaction on this tree with optimized sorting."""
        print("Performing universal compaction...")

        # Use quicksort for O(n log n) performance instead of bubble sort O(n²)
        self.quicksort_keys(0, len(self.keys) - 1)

        self.compaction_strategy.reorganization_count += 1
        self.compaction_strategy.adjust_threshold()
        print("Universal compaction completed. Reorganizations:", self.compaction_strategy.reorganization_count)

    fn quicksort_keys(mut self, low: Int, high: Int):
        """Quicksort the keys and values in-place for better performance."""
        if low < high:
            var pivot_index = self.partition(low, high)
            self.quicksort_keys(low, pivot_index - 1)
            self.quicksort_keys(pivot_index + 1, high)

    fn partition(mut self, low: Int, high: Int) -> Int:
        """Partition function for quicksort."""
        var pivot = self.keys[high]
        var i = low - 1

        for j in range(low, high):
            if self.keys[j] <= pivot:
                i += 1
                # Swap keys
                var temp_key = self.keys[i]
                self.keys[i] = self.keys[j]
                self.keys[j] = temp_key
                # Swap values
                var temp_value = self.values[i]
                self.values[i] = self.values[j]
                self.values[j] = temp_value

        # Swap with pivot
        var temp_key = self.keys[i + 1]
        self.keys[i + 1] = self.keys[high]
        self.keys[high] = temp_key
        var temp_value = self.values[i + 1]
        self.values[i + 1] = self.values[high]
        self.values[high] = temp_value

        return i + 1

    fn get_performance_stats(self) -> String:
        """Get performance statistics for the tree."""
        var stats = "Merkle B+ Tree Performance Stats:\n"
        stats += "  Total Keys: " + String(len(self.keys)) + "\n"
        stats += "  Memory Usage: ~" + String((len(self.keys) * 8 + len(self.values) * 16)) + " bytes\n"
        stats += "  " + self.compaction_strategy.get_performance_metrics()
        return stats

    fn optimize_space_usage(mut self):
        """Optimize space usage by trimming unused capacity."""
        # Trim lists to exact size to free unused memory
        self.keys.resize(len(self.keys), 0)
        self.values.resize(len(self.values), "")

    fn insert(mut self, key: Int, value: String) raises -> String:
        """Insert key-value pair with SHA-256 hash updates. Returns the computed hash."""
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
        return self.merkle_hash

    fn search(self, key: Int) -> String:
        """Search for a key and return its value."""
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                return self.values[i]
        return ""

    fn delete(mut self, key: Int) raises -> Bool:
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

    fn verify_integrity(mut self) raises -> Bool:
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

    fn get_root_hash(self) -> String:
        """Get the current root Merkle hash."""
        return self.merkle_hash

    fn get_stats(mut self) -> String:
        """Get tree statistics."""
        var stats = "Merkle B+ Tree Statistics (SHA-256):\n"
        stats += "  Keys stored: " + String(len(self.keys)) + "\n"
        stats += "  Integrity verified: " + String(self.verify_integrity()) + "\n"
        stats += "  Compaction reorganizations: " + String(self.compaction_strategy.reorganization_count) + "\n"
        stats += "  Merkle Root Hash: " + self.merkle_hash + "\n"
        return stats