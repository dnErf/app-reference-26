"""
Memtable Interface for LSM Tree
===============================

This file defines the common interface that all memtable variants must implement.
This allows the LSM tree to work with different memtable implementations.
"""

from collections import List, Dict

# Common entry type
alias Entry = Tuple[String, String]

# Memtable interface that all variants must implement
trait MemtableInterface:
    """Common interface for all memtable implementations."""

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update a key-value pair. Returns True if memtable is full."""
        ...

    fn get(self, key: String) raises -> String:
        """Get value for key."""
        ...

    fn is_empty(self) -> Bool:
        """Check if memtable is empty."""
        ...

    fn clear(mut self):
        """Clear all entries from memtable."""
        ...

    fn get_size_bytes(self) -> Int:
        """Get current size in bytes."""
        ...

    fn get_entry_count(self) -> Int:
        """Get number of entries."""
        ...

    fn get_all_entries(self) raises -> Dict[String, String]:
        """Get all entries as a dictionary for flushing to SSTable."""
        ...

# Helper function to create memtable instances
fn create_sorted_memtable(max_size: Int = 1024 * 1024) -> SortedMemtable:
    """Create a sorted memtable instance."""
    return SortedMemtable(max_size)

fn create_skiplist_memtable(max_size: Int = 1024 * 1024) -> SkipListMemtable:
    """Create a skiplist memtable instance."""
    return SkipListMemtable(max_size)

fn create_trie_memtable(max_size: Int = 1024 * 1024) -> TrieMemtable:
    """Create a trie memtable instance."""
    return TrieMemtable(max_size)</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/mojo-le/memtable_interface.mojo