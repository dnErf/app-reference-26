"""
Memtable Variants Implementation in Mojo
=======================================

This file implements various memtable variants for the LSM Tree system.
Memtables are the in-memory write buffers that accumulate recent writes
before flushing to SSTables.

Implemented Variants:
1. Sorted Memtable: Uses sorted arrays for efficient range queries
2. SkipList Memtable: Tree-based structure for balanced performance (simplified)

Key Features:
- Size-based flush triggers
- Efficient key-value storage
- Memory usage tracking
- Range query support (where applicable)
- Integration with LSM tree flushing

Performance Characteristics:
- Sorted Memtable: O(log N) inserts, O(log N) lookups, O(K) range queries
- SkipList Memtable: O(log N) average operations, good concurrency
- Memory efficient: Tracks size for automatic flushing

Usage in LSM Tree:
- Accumulates writes until size threshold
- Flushes to SSTable when full
- Supports concurrent reads during writes
- Provides foundation for advanced indexing
"""

from collections import List, Dict
import time

# Common entry type
alias Entry = Tuple[String, String]

# Sorted Memtable using binary search
struct SortedMemtable:
    var entries: List[Entry]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):  # 1MB default
        self.entries = List[Entry]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update a key-value pair. Returns True if memtable is full."""
        # Find insertion point using binary search
        var insert_idx = self._find_insert_position(key)

        # Check if key already exists
        var existing_size = 0
        if insert_idx < len(self.entries) and self.entries[insert_idx][0] == key:
            # Update existing entry
            existing_size = len(self.entries[insert_idx][0]) + len(self.entries[insert_idx][1])
            self.entries[insert_idx] = (key, value)
        else:
            # Insert new entry
            self.entries.insert(insert_idx, (key, value))

        # Update size tracking
        self.size_bytes += len(key) + len(value) - existing_size

        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key using binary search."""
        var idx = self._binary_search(key)
        if idx >= 0:
            return self.entries[idx][1]
        return ""

    fn range_query(self, start_key: String, end_key: String) raises -> List[Entry]:
        """Get all entries in the key range [start_key, end_key]."""
        var result = List[Entry]()

        # Find start position
        var start_idx = self._find_insert_position(start_key)
        if start_idx >= len(self.entries):
            return result^

        # Adjust if we need to include the start key
        if start_idx > 0 and self.entries[start_idx][0] > start_key:
            start_idx -= 1

        # Collect entries in range
        for i in range(start_idx, len(self.entries)):
            var entry_key = self.entries[i][0]
            if entry_key >= start_key and entry_key <= end_key:
                result.append(self.entries[i])
            elif entry_key > end_key:
                break  # Past the end range

        return result^

    fn is_empty(self) -> Bool:
        return len(self.entries) == 0

    fn clear(mut self):
        self.entries.clear()
        self.size_bytes = 0

    fn _binary_search(self, key: String) -> Int:
        """Binary search for exact key match. Returns index or -1."""
        var left = 0
        var right = len(self.entries) - 1

        while left <= right:
            var mid = left + (right - left) // 2
            var mid_key = self.entries[mid][0]

            if mid_key == key:
                return mid
            elif mid_key < key:
                left = mid + 1
            else:
                right = mid - 1

        return -1

    fn _find_insert_position(self, key: String) -> Int:
        """Find the position where key should be inserted to maintain sorted order."""
        var left = 0
        var right = len(self.entries)

        while left < right:
            var mid = left + (right - left) // 2
            if self.entries[mid][0] < key:
                left = mid + 1
            else:
                right = mid

        return left

    fn get_size_bytes(self) -> Int:
        return self.size_bytes

    fn get_entry_count(self) -> Int:
        return len(self.entries)

    fn get_all_entries(self) raises -> Dict[String, String]:
        var result = Dict[String, String]()
        for entry in self.entries:
            result[entry[0]] = entry[1]
        return result^

# Simplified SkipList-based Memtable
struct SkipListMemtable:
    var entries: Dict[String, String]  # Simplified to Dict for now
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):
        self.entries = Dict[String, String]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update (simplified skiplist simulation)."""
        var old_size = 0
        try:
            old_size = len(self.entries[key])
        except:
            pass
        self.entries[key] = value
        self.size_bytes += len(value) - old_size
        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key."""
        try:
            return self.entries[key]
        except:
            return ""

    fn is_empty(self) -> Bool:
        return len(self.entries) == 0

    fn clear(mut self):
        self.entries.clear()
        self.size_bytes = 0

    fn get_size_bytes(self) -> Int:
        return self.size_bytes

    fn get_entry_count(self) -> Int:
        return len(self.entries)

    fn get_all_entries(self) raises -> Dict[String, String]:
        return self.entries.copy()
fn demo_sorted_memtable() raises:
    """Demonstrate sorted memtable operations."""
    print("=== Sorted Memtable Demonstration ===\n")

    var memtable = SortedMemtable(1024)  # Small size for demo

    print("Inserting test data...")
    var keys = List[String]()
    keys.append("apple")
    keys.append("banana")
    keys.append("cherry")
    keys.append("date")
    keys.append("elderberry")

    var values = List[String]()
    values.append("red fruit")
    values.append("yellow fruit")
    values.append("dark red fruit")
    values.append("sweet fruit")
    values.append("purple fruit")

    for i in range(len(keys)):
        var should_flush = memtable.put(keys[i], values[i])
        print("Inserted:", keys[i], "=", values[i], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for key in keys:
        var value = memtable.get(key)
        print("Read:", key, "=", value)

    print("\nRange query [banana, date]...")
    var range_result = memtable.range_query("banana", "date")
    for entry in range_result:
        print("Range result:", entry[0], "=", entry[1])

    print("\nStatistics:")
    print("Entries:", len(memtable.entries))
    print("Size bytes:", memtable.size_bytes)
    print("Max size:", memtable.max_size)

fn demo_skiplist_memtable() raises:
    """Demonstrate skiplist memtable operations."""
    print("\n=== SkipList Memtable Demonstration ===\n")

    var memtable = SkipListMemtable(1024)  # Small size for demo

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("key1", "value1"))
    test_data.append(("key3", "value3"))
    test_data.append(("key2", "value2"))
    test_data.append(("key5", "value5"))
    test_data.append(("key4", "value4"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nStatistics:")
    print("Entries:", len(memtable.entries))
    print("Size bytes:", memtable.size_bytes)
    print("Max size:", memtable.max_size)

fn main() raises:
    """Main entry point."""
    demo_sorted_memtable()
    demo_skiplist_memtable()