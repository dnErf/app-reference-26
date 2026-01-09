"""
Simplified LSM Tree Implementation in Mojo
==========================================

This demonstrates the core LSM tree concepts:
- Memtable for in-memory writes
- SSTable concept (simplified)
- Basic compaction
- Write-ahead logging simulation

LSM trees provide excellent write performance by:
1. Buffering writes in memory (memtable)
2. Flushing to immutable sorted files (SSTables)
3. Merging SSTables during compaction

Key benefits:
- Write-optimized: Sequential I/O for writes
- Read-optimized: Multi-level structure
- Durable: WAL for crash recovery
- Scalable: Handles high write throughput
"""

from collections import List, Dict
import os

# Simplified Memtable
struct Memtable:
    var entries: Dict[String, String]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 64 * 1024):  # 64KB for demo
        self.entries = Dict[String, String]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Add key-value pair. Returns True if memtable is full."""
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

# Simplified SSTable
struct SSTable:
    var filename: String
    var level: Int
    var entry_count: Int

    fn __init__(out self, filename: String, level: Int, entry_count: Int):
        self.filename = filename
        self.level = level
        self.entry_count = entry_count

# Main LSM Tree structure
struct LSMTree:
    var memtable: Memtable
    var sstable_files: List[String]  # Just filenames for simplicity
    var data_dir: String
    var next_sstable_id: Int

    fn __init__(out self, data_dir: String, max_memtable_size: Int = 64 * 1024):
        self.memtable = Memtable(max_memtable_size)
        self.sstable_files = List[String]()
        self.data_dir = data_dir
        self.next_sstable_id = 0

        # Create data directory
        try:
            os.makedirs(data_dir)
        except:
            pass

    # Write operations
    fn put(mut self, key: String, value: String) raises:
        """Insert or update a key-value pair."""
        print("WAL: PUT", key, "=", value)
        if self.memtable.put(key, value):
            self._flush_memtable()

    fn delete(mut self, key: String) raises:
        """Delete a key (tombstone operation)."""
        print("WAL: DELETE", key)
        if self.memtable.put(key, ""):  # Empty value = tombstone
            self._flush_memtable()

    # Read operations
    fn get(self, key: String) raises -> String:
        """Get value for key."""
        # Check memtable first (most recent)
        var value = self.memtable.get(key)
        if value != "":
            return value

        # Check SSTables (simplified - no actual file reading)
        for sstable_file in self.sstable_files:
            print("Checking SSTable:", sstable_file)
            # In real implementation, would read from file with bloom filters
            # For demo, return empty (not found)

        return ""

    # Internal operations
    fn _flush_memtable(mut self) raises:
        """Flush memtable to SSTable."""
        if self.memtable.is_empty():
            return

        print("Flushing memtable with", len(self.memtable.entries), "entries")

        var filename = self.data_dir + "/sstable_" + String(self.next_sstable_id) + ".data"
        self.next_sstable_id += 1

        self.sstable_files.append(filename)

        print("Created SSTable:", filename)

        # Reset memtable
        self.memtable.clear()

        # Trigger compaction if too many SSTables
        if len(self.sstable_files) > 3:
            self._compact()

    fn _compact(mut self) raises:
        """Simple compaction - merge all SSTables."""
        if len(self.sstable_files) == 0:
            return

        print("Compacting", len(self.sstable_files), "SSTables")

        var merged_filename = self.data_dir + "/merged_" + String(self.next_sstable_id) + ".data"
        self.next_sstable_id += 1

        print("Created merged SSTable:", merged_filename, "from", len(self.sstable_files), "files")

        # Clear old files and add merged one
        self.sstable_files.clear()
        self.sstable_files.append(merged_filename)

        print("Created merged SSTable:", merged_filename, "from", len(self.sstable_files), "files")

    # Statistics
    fn get_stats(self) -> Dict[String, Int]:
        """Get LSM tree statistics."""
        var stats = Dict[String, Int]()
        stats["memtable_entries"] = len(self.memtable.entries)
        stats["memtable_size_bytes"] = self.memtable.size_bytes
        stats["sstables_count"] = len(self.sstable_files)
        stats["total_sstable_entries"] = 0  # Simplified - would count actual entries in real impl
        return stats^


fn demo_lsm_tree() raises:
    """Demonstrate LSM tree operations."""
    print("=== LSM Tree Demonstration ===\n")

    var data_dir = "./lsm_data"
    var lsm = LSMTree(data_dir)

    print("LSM Tree created with data directory:", data_dir)
    print("Memtable max size:", lsm.memtable.max_size, "bytes\n")

    # Insert test data
    print("=== Inserting Test Data ===")
    var test_keys = List[String]()
    test_keys.append("user:alice")
    test_keys.append("user:bob")
    test_keys.append("user:charlie")
    test_keys.append("product:laptop")
    test_keys.append("product:mouse")
    test_keys.append("order:1001")
    test_keys.append("order:1002")

    var test_values = List[String]()
    test_values.append("Alice Johnson")
    test_values.append("Bob Smith")
    test_values.append("Charlie Brown")
    test_values.append("Gaming Laptop")
    test_values.append("Wireless Mouse")
    test_values.append("Alice's order")
    test_values.append("Bob's order")

    for i in range(len(test_keys)):
        lsm.put(test_keys[i], test_values[i])
        print("Inserted:", test_keys[i], "=", test_values[i])

    # Check stats after insertions
    print("\n=== Statistics After Inserts ===")
    var stats = lsm.get_stats()
    print("memtable_entries:", stats["memtable_entries"])
    print("memtable_size_bytes:", stats["memtable_size_bytes"])
    print("sstables_count:", stats["sstables_count"])
    print("total_sstable_entries:", stats["total_sstable_entries"])

    # Read operations
    print("\n=== Read Operations ===")
    for key in test_keys:
        var value = lsm.get(key)
        if value != "":
            print("Found:", key, "=", value)
        else:
            print("Not found:", key)

    # Test non-existent key
    var not_found = lsm.get("nonexistent:key")
    print("Non-existent key result:", "found" if not_found != "" else "not found")

    # Delete operation
    print("\n=== Delete Operation ===")
    lsm.delete("user:bob")
    var deleted_value = lsm.get("user:bob")
    print("After deleting user:bob:", "found" if deleted_value != "" else "deleted (tombstone)")

    # Final statistics
    print("\n=== Final Statistics ===")
    stats = lsm.get_stats()
    print("memtable_entries:", stats["memtable_entries"])
    print("memtable_size_bytes:", stats["memtable_size_bytes"])
    print("sstables_count:", stats["sstables_count"])
    print("total_sstable_entries:", stats["total_sstable_entries"])

    print("\n=== LSM Tree Architecture Benefits ===")
    print("✓ Write-optimized: Sequential writes to memtable/WAL")
    print("✓ Read-optimized: Multi-level structure with compaction")
    print("✓ Durable: Write-ahead logging for crash recovery")
    print("✓ Scalable: Handles high write throughput efficiently")
    print("✓ Space efficient: Automatic compaction reduces storage")


fn main() raises:
    """Main entry point."""
    demo_lsm_tree()