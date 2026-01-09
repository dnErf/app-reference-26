"""
Advanced Memtable Variants for LSM Tree
=======================================

This file implements advanced memtable variants for the LSM Tree system,
providing different performance characteristics for various use cases.

Implemented Variants:
1. LinkedListMemtable: Simple list with O(N) operations
2. HashLinkedListMemtable: List with hash map for O(1) lookups
3. Enhanced SkipListMemtable: Skip list using lists
4. HashSkipListMemtable: Skip list with hash acceleration
5. VectorMemtable: Dynamic array-based storage

Key Features:
- Size-based flush triggers across all variants
- Memory usage tracking
- Integration with LSM tree flushing
- Performance optimizations for different access patterns
"""

from collections import List, Dict

# Common entry type
alias Entry = Tuple[String, String]

# Linked List Memtable - Simple O(N) operations using List
struct LinkedListMemtable:
    var entries: List[Entry]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):  # 1MB default
        self.entries = List[Entry]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update with O(N) linear search. Returns True if memtable is full."""
        # Check if key exists and update
        for i in range(len(self.entries)):
            if self.entries[i][0] == key:
                # Update existing entry
                self.size_bytes -= len(self.entries[i][1])
                self.entries[i] = (key, value)
                self.size_bytes += len(value)
                return self.size_bytes >= self.max_size

        # Insert new entry
        self.entries.append((key, value))
        self.size_bytes += len(key) + len(value)

        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key with O(N) linear search."""
        for entry in self.entries:
            if entry[0] == key:
                return entry[1]
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
        var result = Dict[String, String]()
        for entry in self.entries:
            result[entry[0]] = entry[1]
        return result^

# Hash Linked List Memtable - O(1) lookups with ordered iteration
struct HashLinkedListMemtable:
    var hash_map: Dict[String, String]
    var insertion_order: List[String]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):
        self.hash_map = Dict[String, String]()
        self.insertion_order = List[String]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update with O(1) hash operations. Returns True if memtable is full."""
        var old_size = 0
        if key in self.hash_map:
            old_size = len(self.hash_map[key])
        else:
            self.insertion_order.append(key)

        self.hash_map[key] = value
        self.size_bytes += len(value) - old_size

        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key with O(1) hash lookup."""
        if key in self.hash_map:
            return self.hash_map[key]
        return ""

    fn is_empty(self) -> Bool:
        return len(self.hash_map) == 0

    fn clear(mut self):
        self.hash_map.clear()
        self.insertion_order.clear()
        self.size_bytes = 0

    fn get_size_bytes(self) -> Int:
        return self.size_bytes

    fn get_entry_count(self) -> Int:
        return len(self.hash_map)

    fn get_all_entries(self) raises -> Dict[String, String]:
        return self.hash_map.copy()

# Enhanced Skip List Memtable - Simplified skip list using lists
struct EnhancedSkipListMemtable:
    var entries: List[Entry]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):
        self.entries = List[Entry]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update with simplified O(log N) simulation. Returns True if memtable is full."""
        # Simple sorted insertion (simulating skip list behavior)
        var insert_idx = 0
        while insert_idx < len(self.entries) and self.entries[insert_idx][0] < key:
            insert_idx += 1

        if insert_idx < len(self.entries) and self.entries[insert_idx][0] == key:
            # Update existing
            self.size_bytes -= len(self.entries[insert_idx][1])
            self.entries[insert_idx] = (key, value)
            self.size_bytes += len(value)
        else:
            # Insert new
            self.entries.insert(insert_idx, (key, value))
            self.size_bytes += len(key) + len(value)

        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key with binary search simulation."""
        var left = 0
        var right = len(self.entries) - 1

        while left <= right:
            var mid = left + (right - left) // 2
            var mid_key = self.entries[mid][0]

            if mid_key == key:
                return self.entries[mid][1]
            elif mid_key < key:
                left = mid + 1
            else:
                right = mid - 1

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
        var result = Dict[String, String]()
        for entry in self.entries:
            result[entry[0]] = entry[1]
        return result^

# Hash Skip List Memtable - Hash with ordered access
struct HashSkipListMemtable:
    var hash_map: Dict[String, String]
    var sorted_keys: List[String]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):
        self.hash_map = Dict[String, String]()
        self.sorted_keys = List[String]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update with hash + sorted list maintenance. Returns True if memtable is full."""
        var old_size = 0
        var existed = key in self.hash_map

        if existed:
            old_size = len(self.hash_map[key])
        else:
            # Find insertion point for sorted keys
            var insert_idx = 0
            while insert_idx < len(self.sorted_keys) and self.sorted_keys[insert_idx] < key:
                insert_idx += 1
            self.sorted_keys.insert(insert_idx, key)

        self.hash_map[key] = value
        self.size_bytes += len(value) - old_size

        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key with O(1) hash lookup."""
        if key in self.hash_map:
            return self.hash_map[key]
        return ""

    fn is_empty(self) -> Bool:
        return len(self.hash_map) == 0

    fn clear(mut self):
        self.hash_map.clear()
        self.sorted_keys.clear()
        self.size_bytes = 0

    fn get_size_bytes(self) -> Int:
        return self.size_bytes

    fn get_entry_count(self) -> Int:
        return len(self.hash_map)

    fn get_all_entries(self) raises -> Dict[String, String]:
        return self.hash_map.copy()

# Vector Memtable - Dynamic array-based storage
struct VectorMemtable:
    var entries: List[Entry]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):
        self.entries = List[Entry]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update using dynamic array. Returns True if memtable is full."""
        # Check if key exists and update
        for i in range(len(self.entries)):
            if self.entries[i][0] == key:
                # Update existing entry
                self.size_bytes -= len(self.entries[i][1])
                self.entries[i] = (key, value)
                self.size_bytes += len(value)
                return self.size_bytes >= self.max_size

        # Insert new entry (append to end)
        self.entries.append((key, value))
        self.size_bytes += len(key) + len(value)

        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key with linear search through vector."""
        for entry in self.entries:
            if entry[0] == key:
                return entry[1]
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
        var result = Dict[String, String]()
        for entry in self.entries:
            result[entry[0]] = entry[1]
        return result^

# Demonstration functions
fn demo_linked_list_memtable() raises:
    """Demonstrate LinkedListMemtable operations."""
    print("=== LinkedListMemtable Demonstration ===\n")

    var memtable = LinkedListMemtable(1024)  # Small size for demo

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("key1", "value1"))
    test_data.append(("key2", "value2"))
    test_data.append(("key3", "value3"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nStatistics:")
    print("Entries:", memtable.get_entry_count())
    print("Size bytes:", memtable.get_size_bytes())
    print("Max size:", memtable.max_size)

fn demo_hash_linked_list_memtable() raises:
    """Demonstrate HashLinkedListMemtable operations."""
    print("\n=== HashLinkedListMemtable Demonstration ===\n")

    var memtable = HashLinkedListMemtable(1024)

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("key1", "value1"))
    test_data.append(("key2", "value2"))
    test_data.append(("key3", "value3"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nStatistics:")
    print("Entries:", memtable.get_entry_count())
    print("Size bytes:", memtable.get_size_bytes())
    print("Max size:", memtable.max_size)

fn demo_enhanced_skip_list_memtable() raises:
    """Demonstrate EnhancedSkipListMemtable operations."""
    print("\n=== EnhancedSkipListMemtable Demonstration ===\n")

    var memtable = EnhancedSkipListMemtable(1024)

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("apple", "red fruit"))
    test_data.append(("banana", "yellow fruit"))
    test_data.append(("cherry", "red fruit"))
    test_data.append(("date", "brown fruit"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nStatistics:")
    print("Entries:", memtable.get_entry_count())
    print("Size bytes:", memtable.get_size_bytes())
    print("Max size:", memtable.max_size)

fn demo_hash_skip_list_memtable() raises:
    """Demonstrate HashSkipListMemtable operations."""
    print("\n=== HashSkipListMemtable Demonstration ===\n")

    var memtable = HashSkipListMemtable(1024)

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("apple", "red fruit"))
    test_data.append(("banana", "yellow fruit"))
    test_data.append(("cherry", "red fruit"))
    test_data.append(("date", "brown fruit"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nStatistics:")
    print("Entries:", memtable.get_entry_count())
    print("Size bytes:", memtable.get_size_bytes())
    print("Max size:", memtable.max_size)

fn demo_vector_memtable() raises:
    """Demonstrate VectorMemtable operations."""
    print("\n=== VectorMemtable Demonstration ===\n")

    var memtable = VectorMemtable(1024)

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("user1", "John Doe"))
    test_data.append(("user2", "Jane Smith"))
    test_data.append(("user3", "Bob Johnson"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nStatistics:")
    print("Entries:", memtable.get_entry_count())
    print("Size bytes:", memtable.get_size_bytes())
    print("Max size:", memtable.max_size)

fn main() raises:
    """Main entry point for advanced memtable demonstrations."""
    demo_linked_list_memtable()
    demo_hash_linked_list_memtable()
    demo_enhanced_skip_list_memtable()
    demo_hash_skip_list_memtable()
    demo_vector_memtable()