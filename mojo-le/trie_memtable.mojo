"""
Trie Memtable Implementation in Mojo
====================================

This file implements a trie-inspired memtable for the LSM Tree system.
Uses a dictionary-based approach with prefix-aware operations for efficiency.

Key Features:
- Prefix-based storage and retrieval
- Memory-efficient for keys with common prefixes
- Fast prefix operations
- Size-based flush triggers

Performance Characteristics:
- Insert: O(1) dict operations
- Lookup: O(1) dict operations
- Prefix search: O(N) where N is matching keys
- Memory: Dict-based storage

Use Cases:
- String keys with prefix patterns
- Prefix-based queries
- Efficient prefix matching
"""

from collections import List, Dict

# Trie-inspired Memtable using Dict with prefix operations
struct TrieMemtable:
    var entries: Dict[String, String]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):  # 1MB default
        self.entries = Dict[String, String]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update a key-value pair. Returns True if memtable is full."""
        var old_size = 0
        try:
            old_size = len(self.entries[key])
        except:
            pass
        self.entries[key] = value
        self.size_bytes += len(key) + len(value) - old_size
        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key."""
        try:
            return self.entries[key]
        except:
            return ""

    fn prefix_search(self, prefix: String) raises -> List[Tuple[String, String]]:
        """Find all keys that start with the given prefix."""
        var result = List[Tuple[String, String]]()

        for key in self.entries.keys():
            if key.startswith(prefix):
                try:
                    var value = self.entries[key]
                    result.append((key, value))
                except:
                    pass

        return result^

    fn delete(mut self, key: String) raises -> Bool:
        """Delete a key. Returns True if key existed."""
        try:
            var value = self.entries[key]
            self.size_bytes -= len(key) + len(value)
            _ = self.entries.pop(key)
            return True
        except:
            return False

    fn is_empty(self) -> Bool:
        return len(self.entries) == 0

    fn clear(mut self):
        self.entries.clear()
        self.size_bytes = 0

    # Additional trie-inspired operations
    fn longest_prefix_match(self, key: String) raises -> Tuple[String, String]:
        """Find the longest prefix of the key that exists in the memtable."""
        var longest_key = ""
        var longest_value = ""

        for candidate_key in self.entries.keys():
            if key.startswith(candidate_key) and len(candidate_key) > len(longest_key):
                longest_key = candidate_key
                try:
                    longest_value = self.entries[candidate_key]
                except:
                    longest_value = ""

        return (longest_key, longest_value)

    fn common_prefixes(self, min_length: Int = 1) raises -> List[String]:
        """Find common prefixes of a minimum length."""
        var prefixes = Dict[String, Int]()

        for key in self.entries.keys():
            for i in range(min_length, len(key) + 1):
                var prefix = key[:i]
                try:
                    prefixes[prefix] += 1
                except:
                    prefixes[prefix] = 1

        var result = List[String]()
        var prefix_keys = List[String]()
        for key in prefixes.keys():
            prefix_keys.append(key)
        
        for candidate_prefix in prefix_keys:
            try:
                var count = prefixes[candidate_prefix]
                if count > 1:  # Appears in multiple keys
                    result.append(candidate_prefix)
            except:
                pass

        return result^

    fn get_size_bytes(self) -> Int:
        return self.size_bytes

    fn get_entry_count(self) -> Int:
        return len(self.entries)

    fn get_all_entries(self) raises -> Dict[String, String]:
        return self.entries.copy()

# Demonstration functions
fn demo_trie_memtable() raises:
    """Demonstrate trie memtable operations."""
    print("=== Trie Memtable Demonstration ===\n")

    var memtable = TrieMemtable(1024)  # Small size for demo

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("apple", "red fruit"))
    test_data.append(("application", "software"))
    test_data.append(("apply", "to use"))
    test_data.append(("bat", "flying mammal"))
    test_data.append(("batch", "group"))
    test_data.append(("bath", "washing"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nPrefix search for 'app'...")
    var app_results = memtable.prefix_search("app")
    for result in app_results:
        print("Prefix result:", result[0], "=", result[1])

    print("\nPrefix search for 'bat'...")
    var bat_results = memtable.prefix_search("bat")
    for result in bat_results:
        print("Prefix result:", result[0], "=", result[1])

    print("\nPrefix search for 'xyz' (should be empty)...")
    var xyz_results = memtable.prefix_search("xyz")
    print("Results found:", len(xyz_results))

    print("\nDelete operation...")
    var deleted = memtable.delete("apple")
    print("Deleted 'apple':", deleted)
    var apple_value = memtable.get("apple")
    print("Read deleted key:", "found" if apple_value != "" else "not found")

    print("\nPrefix search for 'app' after deletion...")
    app_results = memtable.prefix_search("app")
    for result in app_results:
        print("Prefix result:", result[0], "=", result[1])

    print("\nStatistics:")
    print("Entries:", len(memtable.entries))
    print("Size bytes:", memtable.size_bytes)
    print("Max size:", memtable.max_size)

fn main() raises:
    """Main entry point."""
    demo_trie_memtable()