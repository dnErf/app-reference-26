"""
Merkle B+ Tree with SHA-256 and Universal Compaction
====================================================

Enhanced Merkle B+ Tree using SHA-256 for cryptographic integrity
and universal compaction strategy for optimization with thread-safety.
"""

from collections import List
from python import Python, PythonObject
from thread_safe_memory import AtomicInt, SpinLock, ThreadSafeCounter

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

    fn compute_hash(mut self) raises:
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

    fn should_compact(self, total_nodes: Int, underutilized_nodes: Int) -> Bool:
        """Determine if tree needs universal compaction with adaptive thresholds."""
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

# Merkle B+ Tree with SHA-256
struct MerkleBPlusTree(Movable, Copyable):
    var keys: List[Int]
    var values: List[String]
    var merkle_hash: String
    var compaction_strategy: UniversalCompactionStrategy
    var node_count: ThreadSafeCounter
    var operation_count: ThreadSafeCounter
    var tree_lock: SpinLock

    fn __init__(out self):
        self.keys = List[Int]()
        self.values = List[String]()
        self.merkle_hash = ""
        self.compaction_strategy = UniversalCompactionStrategy()
        self.node_count = ThreadSafeCounter(1)  # Root node
        self.operation_count = ThreadSafeCounter()
        self.tree_lock = SpinLock()

    fn __copyinit__(out self, other: Self):
        self.keys = other.keys.copy()
        self.values = other.values.copy()
        self.merkle_hash = other.merkle_hash
        self.compaction_strategy = other.compaction_strategy.copy()
        # Create new counters (can't copy values from other due to mut requirements)
        self.node_count = ThreadSafeCounter(1)
        self.operation_count = ThreadSafeCounter()
        self.tree_lock = SpinLock()

    fn __moveinit__(out self, deinit existing: Self):
        self.keys = existing.keys^
        self.values = existing.values^
        self.merkle_hash = existing.merkle_hash^
        self.compaction_strategy = existing.compaction_strategy^
        self.node_count = existing.node_count^
        self.operation_count = existing.operation_count^
        self.tree_lock = existing.tree_lock^

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

    fn get_performance_stats(mut self) -> String:
        """Get performance statistics for the tree."""
        var stats = "Merkle B+ Tree Performance Stats:\n"
        stats += "  Total Keys: " + String(len(self.keys)) + "\n"
        stats += "  Memory Usage: ~" + String((len(self.keys) * 8 + len(self.values) * 16)) + " bytes\n"
        stats += "  Compaction reorganizations: " + String(self.compaction_strategy.reorganization_count) + "\n"
        return stats

    fn optimize_space_usage(mut self):
        """Optimize space usage by trimming unused capacity."""
        # Trim lists to exact size to free unused memory
        self.keys.resize(len(self.keys), 0)
        self.values.resize(len(self.values), "")

    fn insert(mut self, key: Int, value: String) raises -> String:
        """Insert key-value pair with SHA-256 hash updates. Returns the computed hash."""
        self.tree_lock.acquire()
        _ = self.operation_count.increment()
        
        # Check if universal compaction is needed
        var total_nodes = self.node_count.get()
        var underutilized_nodes = self.count_underutilized_nodes()
        if self.compaction_strategy.should_compact(total_nodes, underutilized_nodes):
            self.perform_compaction()

        # Find insertion point
        var insert_pos = 0
        while insert_pos < len(self.keys) and key > self.keys[insert_pos]:
            insert_pos += 1

        self.keys.insert(insert_pos, key)
        self.values.insert(insert_pos, value)

        # Update Merkle hash
        self.compute_hash()
        self.tree_lock.release()
        return self.merkle_hash

    fn search(mut self, key: Int) -> String:
        """Search for a key and return its value."""
        self.tree_lock.acquire()
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                self.tree_lock.release()
                return self.values[i]
        self.tree_lock.release()
        return ""

    fn delete(mut self, key: Int) raises -> Bool:
        """Delete a key from the tree."""
        self.tree_lock.acquire()
        _ = self.operation_count.increment()
        
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                _ = self.keys.pop(i)
                _ = self.values.pop(i)
                self.compute_hash()

                # Check if universal compaction is needed
                var total_nodes = self.node_count.get()
                var underutilized_nodes = self.count_underutilized_nodes()
                if self.compaction_strategy.should_compact(total_nodes, underutilized_nodes):
                    # Perform compaction directly instead of using compact method
                    self.perform_compaction()

                self.tree_lock.release()
                return True
        self.tree_lock.release()
        return False

    fn range_query(mut self, start_key: Int, end_key: Int) -> List[String]:
        """Perform range query."""
        self.tree_lock.acquire()
        var results = List[String]()
        for i in range(len(self.keys)):
            if self.keys[i] >= start_key and self.keys[i] <= end_key:
                results.append(self.values[i])
        self.tree_lock.release()
        return results.copy()

    fn verify_integrity(mut self) raises -> Bool:
        """Verify Merkle tree integrity."""
        var expected_hash = self.merkle_hash
        self.compute_hash()
        return self.merkle_hash == expected_hash

    fn count_nodes(mut self) -> Int:
        """Count total nodes."""
        return self.node_count.get()

    fn count_underutilized_nodes(self) -> Int:
        """Count underutilized nodes."""
        return 1 if len(self.keys) < 2 else 0

    fn get_root_hash(self) -> String:
        """Get the current root Merkle hash."""
        return self.merkle_hash

    fn get_stats(mut self) raises -> String:
        """Get tree statistics."""
        var stats = "Merkle B+ Tree Statistics (SHA-256, Thread-Safe):\n"
        stats += "  Keys stored: " + String(len(self.keys)) + "\n"
        stats += "  Total nodes: " + String(self.node_count.get()) + "\n"
        stats += "  Total operations: " + String(self.operation_count.get()) + "\n"
        stats += "  Integrity verified: " + String(self.verify_integrity()) + "\n"
        stats += "  Compaction reorganizations: " + String(self.compaction_strategy.reorganization_count) + "\n"
        stats += "  Merkle Root Hash: " + self.merkle_hash + "\n"
        return stats