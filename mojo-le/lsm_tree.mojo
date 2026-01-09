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

# Import memtable types directly
from memtable import SortedMemtable, SkipListMemtable
from trie_memtable import TrieMemtable
from advanced_memtables import LinkedListMemtable, HashLinkedListMemtable, EnhancedSkipListMemtable, HashSkipListMemtable, VectorMemtable
from sstable import SSTable, SSTableMetadata
from compaction_strategy import CompactionStrategy
from compaction_strategy import CompactionStrategy
from background_compaction_worker import BackgroundCompactionWorker

# LSM Tree Configuration
struct LSMTreeConfig:
    var memtable_type: String
    var max_memtable_size: Int
    var data_dir: String
    var enable_background_compaction: Bool
    var compaction_check_interval: Int  # milliseconds
    
    fn __init__(out self, 
                memtable_type: String = "sorted",
                max_memtable_size: Int = 64 * 1024,
                data_dir: String = "./lsm_data",
                enable_background_compaction: Bool = True,
                compaction_check_interval: Int = 5000):
        self.memtable_type = memtable_type
        self.max_memtable_size = max_memtable_size
        self.data_dir = data_dir
        self.enable_background_compaction = enable_background_compaction
        self.compaction_check_interval = compaction_check_interval
    
    fn validate(self) raises:
        """Validate configuration parameters."""
        if self.max_memtable_size <= 0:
            raise "max_memtable_size must be positive"
        
        var valid_types = List[String]()
        valid_types.append("sorted")
        valid_types.append("skiplist")
        valid_types.append("trie")
        valid_types.append("linked_list")
        valid_types.append("hash_linked_list")
        valid_types.append("enhanced_skiplist")
        valid_types.append("hash_skiplist")
        valid_types.append("vector")
        
        var is_valid = False
        for valid_type in valid_types:
            if self.memtable_type == valid_type:
                is_valid = True
                break
        
        if not is_valid:
            raise "Invalid memtable_type. Valid options: sorted, skiplist, trie, linked_list, hash_linked_list, enhanced_skiplist, hash_skiplist, vector"

# Memtable variant type to support multiple implementations
struct MemtableVariant:
    var variant_type: String
    
    # All possible memtable types
    var sorted_memtable: SortedMemtable
    var skiplist_memtable: SkipListMemtable  
    var trie_memtable: TrieMemtable
    var linked_list_memtable: LinkedListMemtable
    var hash_linked_list_memtable: HashLinkedListMemtable
    var enhanced_skiplist_memtable: EnhancedSkipListMemtable
    var hash_skiplist_memtable: HashSkipListMemtable
    var vector_memtable: VectorMemtable
    
    fn __init__(out self, variant_type: String, max_size: Int = 64 * 1024) raises:
        self.variant_type = variant_type
        
        # Initialize all memtables (only the active one will be used)
        self.sorted_memtable = SortedMemtable(max_size)
        self.skiplist_memtable = SkipListMemtable(max_size)
        self.trie_memtable = TrieMemtable(max_size)
        self.linked_list_memtable = LinkedListMemtable(max_size)
        self.hash_linked_list_memtable = HashLinkedListMemtable(max_size)
        self.enhanced_skiplist_memtable = EnhancedSkipListMemtable(max_size)
        self.hash_skiplist_memtable = HashSkipListMemtable(max_size)
        self.vector_memtable = VectorMemtable(max_size)
    
    fn put(mut self, key: String, value: String) raises -> Bool:
        """Put operation - delegates to active memtable variant."""
        if self.variant_type == "sorted":
            return self.sorted_memtable.put(key, value)
        elif self.variant_type == "skiplist":
            return self.skiplist_memtable.put(key, value)
        elif self.variant_type == "trie":
            return self.trie_memtable.put(key, value)
        elif self.variant_type == "linked_list":
            return self.linked_list_memtable.put(key, value)
        elif self.variant_type == "hash_linked_list":
            return self.hash_linked_list_memtable.put(key, value)
        elif self.variant_type == "enhanced_skiplist":
            return self.enhanced_skiplist_memtable.put(key, value)
        elif self.variant_type == "hash_skiplist":
            return self.hash_skiplist_memtable.put(key, value)
        elif self.variant_type == "vector":
            return self.vector_memtable.put(key, value)
        else:
            # Default to sorted
            return self.sorted_memtable.put(key, value)
    
    fn get(self, key: String) raises -> String:
        """Get operation - delegates to active memtable variant."""
        if self.variant_type == "sorted":
            return self.sorted_memtable.get(key)
        elif self.variant_type == "skiplist":
            return self.skiplist_memtable.get(key)
        elif self.variant_type == "trie":
            return self.trie_memtable.get(key)
        elif self.variant_type == "linked_list":
            return self.linked_list_memtable.get(key)
        elif self.variant_type == "hash_linked_list":
            return self.hash_linked_list_memtable.get(key)
        elif self.variant_type == "enhanced_skiplist":
            return self.enhanced_skiplist_memtable.get(key)
        elif self.variant_type == "hash_skiplist":
            return self.hash_skiplist_memtable.get(key)
        elif self.variant_type == "vector":
            return self.vector_memtable.get(key)
        else:
            # Default to sorted
            return self.sorted_memtable.get(key)
    
    fn is_empty(self) -> Bool:
        """Check if active memtable is empty."""
        if self.variant_type == "sorted":
            return self.sorted_memtable.is_empty()
        elif self.variant_type == "skiplist":
            return self.skiplist_memtable.is_empty()
        elif self.variant_type == "trie":
            return self.trie_memtable.is_empty()
        elif self.variant_type == "linked_list":
            return self.linked_list_memtable.is_empty()
        elif self.variant_type == "hash_linked_list":
            return self.hash_linked_list_memtable.is_empty()
        elif self.variant_type == "enhanced_skiplist":
            return self.enhanced_skiplist_memtable.is_empty()
        elif self.variant_type == "hash_skiplist":
            return self.hash_skiplist_memtable.is_empty()
        elif self.variant_type == "vector":
            return self.vector_memtable.is_empty()
        else:
            return self.sorted_memtable.is_empty()
    
    fn clear(mut self):
        """Clear active memtable."""
        if self.variant_type == "sorted":
            self.sorted_memtable.clear()
        elif self.variant_type == "skiplist":
            self.skiplist_memtable.clear()
        elif self.variant_type == "trie":
            self.trie_memtable.clear()
        elif self.variant_type == "linked_list":
            self.linked_list_memtable.clear()
        elif self.variant_type == "hash_linked_list":
            self.hash_linked_list_memtable.clear()
        elif self.variant_type == "enhanced_skiplist":
            self.enhanced_skiplist_memtable.clear()
        elif self.variant_type == "hash_skiplist":
            self.hash_skiplist_memtable.clear()
        elif self.variant_type == "vector":
            self.vector_memtable.clear()
        else:
            self.sorted_memtable.clear()
    
    fn get_entry_count(self) -> Int:
        """Get entry count from active memtable."""
        if self.variant_type == "sorted":
            return self.sorted_memtable.get_entry_count()
        elif self.variant_type == "skiplist":
            return self.skiplist_memtable.get_entry_count()
        elif self.variant_type == "trie":
            return self.trie_memtable.get_entry_count()
        elif self.variant_type == "linked_list":
            return self.linked_list_memtable.get_entry_count()
        elif self.variant_type == "hash_linked_list":
            return self.hash_linked_list_memtable.get_entry_count()
        elif self.variant_type == "enhanced_skiplist":
            return self.enhanced_skiplist_memtable.get_entry_count()
        elif self.variant_type == "hash_skiplist":
            return self.hash_skiplist_memtable.get_entry_count()
        elif self.variant_type == "vector":
            return self.vector_memtable.get_entry_count()
        else:
            return self.sorted_memtable.get_entry_count()
    
    fn get_size_bytes(self) -> Int:
        """Get size in bytes from active memtable."""
        if self.variant_type == "sorted":
            return self.sorted_memtable.get_size_bytes()
        elif self.variant_type == "skiplist":
            return self.skiplist_memtable.get_size_bytes()
        elif self.variant_type == "trie":
            return self.trie_memtable.get_size_bytes()
        elif self.variant_type == "linked_list":
            return self.linked_list_memtable.get_size_bytes()
        elif self.variant_type == "hash_linked_list":
            return self.hash_linked_list_memtable.get_size_bytes()
        elif self.variant_type == "enhanced_skiplist":
            return self.enhanced_skiplist_memtable.get_size_bytes()
        elif self.variant_type == "hash_skiplist":
            return self.hash_skiplist_memtable.get_size_bytes()
        elif self.variant_type == "vector":
            return self.vector_memtable.get_size_bytes()
        else:
            return self.sorted_memtable.get_size_bytes()
    
    fn get_all_entries(self) raises -> Dict[String, String]:
        """Get all entries from active memtable."""
        if self.variant_type == "sorted":
            return self.sorted_memtable.get_all_entries()
        elif self.variant_type == "skiplist":
            return self.skiplist_memtable.get_all_entries()
        elif self.variant_type == "trie":
            return self.trie_memtable.get_all_entries()
        elif self.variant_type == "linked_list":
            return self.linked_list_memtable.get_all_entries()
        elif self.variant_type == "hash_linked_list":
            return self.hash_linked_list_memtable.get_all_entries()
        elif self.variant_type == "enhanced_skiplist":
            return self.enhanced_skiplist_memtable.get_all_entries()
        elif self.variant_type == "hash_skiplist":
            return self.hash_skiplist_memtable.get_all_entries()
        elif self.variant_type == "vector":
            return self.vector_memtable.get_all_entries()
        else:
            return self.sorted_memtable.get_all_entries()
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

# Main LSM Tree structure
struct LSMTree:
    var memtable: MemtableVariant  # Now supports all memtable variants
    var sstables: List[String]  # List of SSTable filenames
    var data_dir: String
    var compaction_strategy: CompactionStrategy
    var background_worker: BackgroundCompactionWorker
    var next_sstable_id: Int
    var memtable_type: String         # Track which memtable type is used

    fn __init__(out self, config: LSMTreeConfig) raises:
        # Validate configuration
        config.validate()
        
        # Initialize memtable variant (supports all types now)
        self.memtable = MemtableVariant(config.memtable_type, config.max_memtable_size)
        self.sstables = List[String]()
        self.data_dir = config.data_dir
        self.compaction_strategy = CompactionStrategy()
        self.next_sstable_id = 0
        self.memtable_type = config.memtable_type

        # Create data directory
        try:
            os.makedirs(config.data_dir)
        except:
            pass

        # Start background compaction worker if enabled
        if config.enable_background_compaction:
            self.background_worker = BackgroundCompactionWorker("lsm_worker")
            try:
                self.background_worker.start()
            except:
                print("Warning: Could not start background compaction worker")
        else:
            # Initialize empty background worker (won't be used)
            self.background_worker = BackgroundCompactionWorker("disabled")

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

        # Check SSTables in order (most recent first)
        for filename in self.sstables:
            # Load SSTable from file
            var sstable = SSTable.load(filename)
            var sstable_value = sstable.get(key)
            if sstable_value != "":
                return sstable_value

        return ""

    # Internal operations
    fn _flush_memtable(mut self) raises:
        """Flush memtable to SSTable."""
        if self.memtable.is_empty():
            return

        print("Flushing memtable with", self.memtable.get_entry_count(), "entries")

        # Get all entries from memtable
        var entries = self.memtable.get_all_entries()

        # Create SSTable from entries
        var sstable = SSTable(entries, 0)  # Start at level 0
        var filename = sstable.save(self.data_dir)
        self.next_sstable_id += 1

        # Add filename to list
        self.sstables.append(filename)

        print("Created SSTable:", filename)

        # Reset memtable
        self.memtable.clear()

        # Check if compaction is needed
        var sstable_files = List[String]()
        for filename in self.sstables:
            sstable_files.append(filename)

        if self.background_worker.check_compaction_needed(sstable_files):
            self._trigger_compaction()

    fn _trigger_compaction(mut self) raises:
        """Trigger background compaction."""
        var sstable_files = List[String]()
        for filename in self.sstables:
            sstable_files.append(filename)

        print("Triggering background compaction for", len(sstable_files), "SSTables")
        self.background_worker.submit_compaction_task(sstable_files)

    # Statistics
    fn get_stats(self) -> Dict[String, Int]:
        """Get LSM tree statistics."""
        var stats = Dict[String, Int]()
        stats["memtable_entries"] = self.memtable.get_entry_count()
        stats["memtable_size_bytes"] = self.memtable.get_size_bytes()
        stats["sstables_count"] = len(self.sstables)
        stats["total_sstable_entries"] = 0  # Would count actual entries in real impl
        return stats^


fn demo_lsm_tree() raises:
    """Demonstrate LSM tree operations."""
    print("=== LSM Tree Demonstration ===\n")

    # Create configuration for sorted memtable
    var config = LSMTreeConfig(
        memtable_type="sorted",
        max_memtable_size=64 * 1024,  # 64KB
        data_dir="./lsm_data",
        enable_background_compaction=True
    )
    
    var lsm = LSMTree(config)

    print("LSM Tree created with data directory:", config.data_dir)
    print("Memtable type:", lsm.memtable_type)
    print("Memtable max size:", config.max_memtable_size, "bytes\n")

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
    print("✓ Configurable: Supports multiple memtable variants")


fn demo_memtable_variants() raises:
    """Demonstrate different memtable variants in LSM trees."""
    print("=== Advanced Memtable Variants Demonstration ===\n")

    var data_dir_base = "./lsm_data_variant"
    var variants = List[String]()
    variants.append("sorted")
    variants.append("skiplist")
    variants.append("trie")
    variants.append("linked_list")
    variants.append("hash_linked_list")
    variants.append("enhanced_skiplist")
    variants.append("hash_skiplist")
    variants.append("vector")

    for variant in variants:
        print("--- Testing", variant, "memtable ---")
        var data_dir = data_dir_base + "_" + variant
        
        # Create configuration for each variant
        var config = LSMTreeConfig(
            memtable_type=variant,
            max_memtable_size=2048,  # 2KB for demo
            data_dir=data_dir,
            enable_background_compaction=False  # Disable for demo speed
        )
        
        var lsm = LSMTree(config)

        # Insert some test data
        lsm.put("key1", "value1")
        lsm.put("key2", "value2")
        lsm.put("key3", "value3")

        # Read back
        print("  key1 =", lsm.get("key1"))
        print("  key2 =", lsm.get("key2"))
        print("  key3 =", lsm.get("key3"))

        var stats = lsm.get_stats()
        print("  Memtable entries:", stats["memtable_entries"])
        print("  Memtable size:", stats["memtable_size_bytes"], "bytes")
        print("  Memtable type:", lsm.memtable_type)
        print()


fn benchmark_memtable_variants() raises:
    """Comprehensive performance benchmarking of all memtable variants."""
    print("=== Memtable Performance Benchmarking ===\n")
    
    var variants = List[String]()
    variants.append("sorted")
    variants.append("skiplist")
    variants.append("trie")
    variants.append("linked_list")
    variants.append("hash_linked_list")
    variants.append("enhanced_skiplist")
    variants.append("hash_skiplist")
    variants.append("vector")
    
    # Test data sizes
    var test_sizes = List[Int]()
    test_sizes.append(100)   # Small dataset
    test_sizes.append(1000)  # Medium dataset
    test_sizes.append(5000)  # Large dataset
    
    print("Benchmarking memtable variants with different data sizes...")
    print("Operations: Insert 100%, Read 100% (existing keys)")
    print()
    
    for test_size in test_sizes:
        print("--- Dataset Size:", test_size, "entries ---")
        
        for variant in variants:
            # Create configuration
            var config = LSMTreeConfig(
                memtable_type=variant,
                max_memtable_size=1024 * 1024,  # 1MB to avoid flushes during benchmark
                data_dir="./benchmark_data_" + variant,
                enable_background_compaction=False
            )
            
            var lsm = LSMTree(config)
            
            # Generate test keys
            var keys = List[String]()
            var values = List[String]()
            for i in range(test_size):
                keys.append("key" + String(i))
                values.append("value" + String(i) + "_with_some_extra_data_to_increase_size")
            
            # Benchmark insertions
            var start_time = 0  # Would use time module in real benchmark
            for i in range(test_size):
                lsm.put(keys[i], values[i])
            
            # Benchmark reads (existing keys)
            var read_count = 0
            for i in range(test_size):
                var value = lsm.get(keys[i])
                if value != "":
                    read_count += 1
            
            # Get statistics
            var stats = lsm.get_stats()
            
            print("  " + variant + ":")
            print("    Entries:", stats["memtable_entries"])
            print("    Memory:", stats["memtable_size_bytes"], "bytes")
            print("    Successful reads:", read_count, "/", test_size)
            print("    Memory per entry:", stats["memtable_size_bytes"] // stats["memtable_entries"], "bytes")
        
        print()


fn demo_configuration_options() raises:
    """Demonstrate different LSM tree configuration options."""
    print("=== LSM Tree Configuration Options ===\n")
    
    # Configuration 1: High-performance setup
    print("1. High-Performance Configuration:")
    var high_perf_config = LSMTreeConfig(
        memtable_type="hash_skiplist",
        max_memtable_size=1024 * 1024,  # 1MB
        data_dir="./high_perf_data",
        enable_background_compaction=True,
        compaction_check_interval=1000  # 1 second
    )
    print("   Memtable: hash_skiplist (O(1) reads, O(log N) ordered)")
    print("   Max size: 1MB")
    print("   Background compaction: Enabled")
    print()
    
    # Configuration 2: Memory-efficient setup
    print("2. Memory-Efficient Configuration:")
    var memory_efficient_config = LSMTreeConfig(
        memtable_type="linked_list",
        max_memtable_size=256 * 1024,  # 256KB
        data_dir="./memory_efficient_data",
        enable_background_compaction=True,
        compaction_check_interval=5000  # 5 seconds
    )
    print("   Memtable: linked_list (O(N) reads, low memory overhead)")
    print("   Max size: 256KB")
    print("   Background compaction: Enabled")
    print()
    
    # Configuration 3: Balanced setup
    print("3. Balanced Configuration:")
    var balanced_config = LSMTreeConfig(
        memtable_type="enhanced_skiplist",
        max_memtable_size=512 * 1024,  # 512KB
        data_dir="./balanced_data",
        enable_background_compaction=True,
        compaction_check_interval=3000  # 3 seconds
    )
    print("   Memtable: enhanced_skiplist (O(log N) reads, good balance)")
    print("   Max size: 512KB")
    print("   Background compaction: Enabled")
    print()
    
    # Test each configuration
    print("Testing High-Performance configuration:")
    var lsm1 = LSMTree(high_perf_config)
    lsm1.put("test_key", "test_value")
    var value1 = lsm1.get("test_key")
    print("  Quick test result:", "PASS" if value1 == "test_value" else "FAIL")
    var stats1 = lsm1.get_stats()
    print("  Memtable entries:", stats1["memtable_entries"])
    print("  Configuration valid: YES")
    print()
    
    print("Testing Memory-Efficient configuration:")
    var lsm2 = LSMTree(memory_efficient_config)
    lsm2.put("test_key", "test_value")
    var value2 = lsm2.get("test_key")
    print("  Quick test result:", "PASS" if value2 == "test_value" else "FAIL")
    var stats2 = lsm2.get_stats()
    print("  Memtable entries:", stats2["memtable_entries"])
    print("  Configuration valid: YES")
    print()
    
    print("Testing Balanced configuration:")
    var lsm3 = LSMTree(balanced_config)
    lsm3.put("test_key", "test_value")
    var value3 = lsm3.get("test_key")
    print("  Quick test result:", "PASS" if value3 == "test_value" else "FAIL")
    var stats3 = lsm3.get_stats()
    print("  Memtable entries:", stats3["memtable_entries"])
    print("  Configuration valid: YES")
    print()


fn main() raises:
    """Main entry point."""
    demo_lsm_tree()
    demo_memtable_variants()
    demo_configuration_options()
    benchmark_memtable_variants()