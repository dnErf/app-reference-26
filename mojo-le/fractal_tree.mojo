"""
Fractal Tree Implementation in Mojo
===================================

A fractal tree is a data structure designed for high-performance storage systems.
It uses a hierarchical buffering strategy where data is written to memory buffers
first, then merged into larger structures on disk.

Key Characteristics:
- Multi-level buffering for write optimization
- Log-structured storage with merging
- Excellent write performance
- Good read performance through indexing
- Designed for flash/SSD storage systems

This implementation demonstrates:
- Buffer management and merging strategies
- Hierarchical storage levels
- Write-optimized data structure
- Memory-efficient operations
- Integration patterns for database storage

Fractal Tree vs B+ Tree:
- Fractal trees optimize for writes over reads
- B+ trees optimize for reads with some write penalty
- Fractal trees use buffering and merging
- B+ trees use in-place updates and splitting
"""

from collections import List, Dict

# Fractal Tree Configuration
alias BUFFER_SIZE = 4  # Maximum entries per buffer
alias MAX_LEVELS = 3   # Maximum tree levels

# Buffer entry for fractal tree
struct BufferEntry:
    var key: Int
    var value: String

    fn __init__(out self, key: Int, value: String):
        self.key = key
        self.value = value

# Buffer for storing entries at each level
struct FractalBuffer:
    var entries: List[BufferEntry]
    var level: Int
    var is_full: Bool

    fn __init__(out self, level: Int):
        self.entries = List[BufferEntry]()
        self.level = level
        self.is_full = False

    fn add_entry(mut self, key: Int, value: String) -> Bool:
        """Add an entry to the buffer. Returns True if buffer becomes full."""
        if len(self.entries) >= BUFFER_SIZE:
            self.is_full = True
            return True

        # Insert in sorted order
        var pos = 0
        while pos < len(self.entries) and key > self.entries[pos].key:
            pos += 1

        var entry = BufferEntry(key, value)
        self.entries.insert(pos, entry)

        if len(self.entries) >= BUFFER_SIZE:
            self.is_full = True
            return True

        return False

    fn get_entries(self) -> List[BufferEntry]:
        """Get all entries in the buffer."""
        return self.entries

    fn clear(mut self):
        """Clear all entries from the buffer."""
        self.entries.clear()
        self.is_full = False

# Fractal Tree main structure
struct FractalTree:
    var buffers: List[FractalBuffer]  # One buffer per level
    var num_entries: Int

    fn __init__(out self):
        self.buffers = List[FractalBuffer]()
        self.num_entries = 0

        # Initialize buffers for each level
        for level in range(MAX_LEVELS):
            self.buffers.append(FractalBuffer(level))

    fn insert(mut self, key: Int, value: String):
        """Insert a key-value pair into the fractal tree."""
        # Start with level 0 buffer
        var current_level = 0

        while current_level < MAX_LEVELS:
            var buffer_full = self.buffers[current_level].add_entry(key, value)

            if not buffer_full:
                # Entry added successfully
                self.num_entries += 1
                return

            # Buffer is full, need to merge/compact
            if current_level == MAX_LEVELS - 1:
                # At max level, force merge down
                self._merge_down(current_level)
            else:
                # Merge to next level
                self._merge_to_next_level(current_level)
                current_level += 1

        self.num_entries += 1

    fn search(self, key: Int) -> String:
        """Search for a key across all buffer levels."""
        # Search from bottom level up (most recent data first)
        for level in range(MAX_LEVELS):
            var buffer = self.buffers[level]
            for entry in buffer.entries:
                if entry[].key == key:
                    return entry[].value

        return ""

    fn _merge_to_next_level(mut self, from_level: Int):
        """Merge a full buffer to the next level."""
        if from_level >= MAX_LEVELS - 1:
            return

        var source_buffer = self.buffers[from_level]
        var target_buffer = self.buffers[from_level + 1]

        # Add all entries from source to target
        for entry in source_buffer.entries:
            target_buffer.add_entry(entry[].key, entry[].value)

        # Clear source buffer
        source_buffer.clear()

    fn _merge_down(mut self, level: Int):
        """Merge down from the highest level (simplified compaction)."""
        var buffer = self.buffers[level]

        # In a real implementation, this would write to disk
        # For now, just clear the buffer (simulating disk write)
        print("Merging level", level, "to disk (", len(buffer.entries), "entries)")

        # Sort entries by key for efficient storage
        # (In real implementation, would use external sort)
        self._sort_buffer(buffer)

        # Clear buffer after "writing to disk"
        buffer.clear()

    fn _sort_buffer(mut self, buffer: FractalBuffer):
        """Sort buffer entries by key (simplified bubble sort for demo)."""
        var entries = buffer.entries
        var n = len(entries)

        for i in range(n):
            for j in range(0, n - i - 1):
                if entries[j].key > entries[j + 1].key:
                    # Swap
                    var temp = entries[j]
                    entries[j] = entries[j + 1]
                    entries[j + 1] = temp

    fn get_stats(self) -> Tuple[Int, Int, Int]:
        """Return (total_entries, levels_used, max_buffer_size)."""
        var levels_used = 0
        var max_size = 0

        for buffer in self.buffers:
            if len(buffer.entries) > 0:
                levels_used += 1
            if len(buffer.entries) > max_size:
                max_size = len(buffer.entries)

        return (self.num_entries, levels_used, max_size)

    fn print_buffers(self):
        """Print the current state of all buffers."""
        for level in range(MAX_LEVELS):
            var buffer = self.buffers[level]
            print("Level", level, ":", len(buffer.entries), "entries")
            for entry in buffer.entries:
                print("  Key:", entry[].key, "Value:", entry[].value)


fn demo_fractal_tree():
    """Demonstrate fractal tree operations."""
    print("=== Fractal Tree Demonstration ===\n")

    var tree = FractalTree()
    print("Fractal tree created with", MAX_LEVELS, "levels")

    # Insert test data
    print("\nInserting data...")
    var test_data = List[Tuple[Int, String]]()
    test_data.append((10, "Alice"))
    test_data.append((20, "Bob"))
    test_data.append((5, "Charlie"))
    test_data.append((15, "Diana"))
    test_data.append((25, "Eve"))
    test_data.append((30, "Frank"))
    test_data.append((35, "Grace"))
    test_data.append((40, "Henry"))
    test_data.append((12, "Ian"))
    test_data.append((18, "Julia"))

    var insert_count = 0
    for item in test_data:
        tree.insert(item[0], item[1])
        insert_count += 1
        if insert_count % 3 == 0:
            print("After", insert_count, "inserts:", tree.get_stats())

    print("\nFinal stats:", tree.get_stats())
    print("\nBuffer states:")
    tree.print_buffers()

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


fn main():
    """Main entry point."""
    demo_fractal_tree()