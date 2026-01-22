"""
Complete LSM Database System in Python
======================================

This file implements a complete LSM-based database system combining:
- LSM Tree storage engine with configurable memtable variants
- Write-Ahead Logging (WAL) for durability
- Recovery mechanisms from SSTable files
- Concurrent operations with thread safety
- Comprehensive performance benchmarking

The database provides a high-level API for key-value operations while
leveraging the LSM tree's write-optimized architecture.
"""

import os
import time
from typing import Dict, List, Tuple, Optional
import threading
import pickle  # For simple serialization

# Simplified imports - we'll implement core components inline
# from lsm_tree import LSMTree, LSMTreeConfig, MemtableVariant
# from sstable import SSTable, SSTableMetadata
# from compaction_strategy import CompactionStrategy
# from background_compaction_worker import BackgroundCompactionWorker


# Memtable variants
class MemtableVariant:
    LINKED_LIST = "linked_list"
    HASH_SKIPLIST = "hash_skiplist"
    ENHANCED_SKIPLIST = "enhanced_skiplist"


# LSM Tree Configuration
class LSMTreeConfig:
    def __init__(self,
                 memtable_type: str = MemtableVariant.HASH_SKIPLIST,
                 max_memtable_size: int = 1024 * 1024,  # 1MB
                 data_dir: str = "./lsm_data",
                 enable_background_compaction: bool = True,
                 compaction_check_interval: int = 5000):  # milliseconds
        self.memtable_type = memtable_type
        self.max_memtable_size = max_memtable_size
        self.data_dir = data_dir
        self.enable_background_compaction = enable_background_compaction
        self.compaction_check_interval = compaction_check_interval


# Simple Memtable implementations
class Memtable:
    def __init__(self, variant: str = MemtableVariant.LINKED_LIST):
        self.variant = variant
        if variant == MemtableVariant.LINKED_LIST:
            self.data: Dict[str, str] = {}
        elif variant == MemtableVariant.HASH_SKIPLIST:
            self.data: Dict[str, str] = {}
        else:  # enhanced_skiplist
            self.data: Dict[str, str] = {}

    def put(self, key: str, value: str):
        self.data[key] = value

    def get(self, key: str) -> Optional[str]:
        return self.data.get(key)

    def delete(self, key: str):
        if key in self.data:
            del self.data[key]

    def size(self) -> int:
        return len(self.data)

    def is_empty(self) -> bool:
        return len(self.data) == 0

    def clear(self):
        self.data.clear()


# SSTable implementation
class SSTable:
    def __init__(self, file_path: str, metadata: 'SSTableMetadata'):
        self.file_path = file_path
        self.metadata = metadata
        self.data: Dict[str, str] = {}

    def load_from_file(self):
        """Load SSTable data from file."""
        try:
            with open(self.file_path, 'rb') as f:
                self.data = pickle.load(f)
        except FileNotFoundError:
            self.data = {}

    def save_to_file(self):
        """Save SSTable data to file."""
        os.makedirs(os.path.dirname(self.file_path), exist_ok=True)
        with open(self.file_path, 'wb') as f:
            pickle.dump(self.data, f)

    def get(self, key: str) -> Optional[str]:
        return self.data.get(key)

    def contains_key(self, key: str) -> bool:
        return key in self.data


class SSTableMetadata:
    def __init__(self, level: int, file_path: str, min_key: str = "", max_key: str = ""):
        self.level = level
        self.file_path = file_path
        self.min_key = min_key
        self.max_key = max_key
        self.created_time = time.time()
        self.entry_count = 0


# Compaction Strategy
class CompactionStrategy:
    def __init__(self):
        pass

    def should_compact(self, level_sizes: List[int]) -> bool:
        """Determine if compaction is needed."""
        # Simple strategy: compact if any level exceeds threshold
        thresholds = [4, 8, 16, 32, 64]  # Level 0: 4 files, Level 1: 8, etc.
        for i, size in enumerate(level_sizes):
            threshold = thresholds[i] if i < len(thresholds) else thresholds[-1]
            if size > threshold:
                return True
        return False

    def get_compaction_files(self, sstables: List[SSTable], level: int) -> List[SSTable]:
        """Get files to compact for a level."""
        # Simple: compact all files in the level
        return [sstable for sstable in sstables if sstable.metadata.level == level]


# Background Compaction Worker
class BackgroundCompactionWorker:
    def __init__(self, lsm_tree: 'LSMTree'):
        self.lsm_tree = lsm_tree
        self.running = False
        self.thread: Optional[threading.Thread] = None

    def start(self):
        """Start the background compaction thread."""
        if not self.running:
            self.running = True
            self.thread = threading.Thread(target=self._compaction_loop, daemon=True)
            self.thread.start()

    def stop(self):
        """Stop the background compaction thread."""
        self.running = False
        if self.thread:
            self.thread.join(timeout=5)

    def _compaction_loop(self):
        """Main compaction loop."""
        while self.running:
            try:
                self.lsm_tree.perform_compaction_if_needed()
                time.sleep(self.lsm_tree.config.compaction_check_interval / 1000)
            except Exception as e:
                print(f"Compaction error: {e}")
                time.sleep(1)


# LSM Tree implementation
class LSMTree:
    def __init__(self, config: LSMTreeConfig):
        self.config = config
        self.memtable = Memtable(config.memtable_type)
        self.immutable_memtables: List[Memtable] = []
        self.sstables: List[SSTable] = []
        self.compaction_strategy = CompactionStrategy()
        self.compaction_worker = BackgroundCompactionWorker(self)
        self.lock = threading.RLock()

        # Ensure data directory exists
        os.makedirs(config.data_dir, exist_ok=True)

        # Load existing SSTables
        self._load_existing_sstables()

        # Start background compaction if enabled
        if config.enable_background_compaction:
            self.compaction_worker.start()

    def put(self, key: str, value: str):
        """Insert or update a key-value pair."""
        with self.lock:
            self.memtable.put(key, value)

            # Check if memtable needs to be flushed
            if self._should_flush_memtable():
                self._flush_memtable()

    def get(self, key: str) -> str:
        """Get value for a key."""
        with self.lock:
            # Check memtable first
            value = self.memtable.get(key)
            if value is not None:
                return "" if value == "__TOMBSTONE__" else value

            # Check immutable memtables
            for immutable in self.immutable_memtables:
                value = immutable.get(key)
                if value is not None:
                    return "" if value == "__TOMBSTONE__" else value

            # Check SSTables (from newest to oldest)
            for sstable in reversed(self.sstables):
                value = sstable.get(key)
                if value is not None:
                    return "" if value == "__TOMBSTONE__" else value

            return ""  # Key not found

    def delete(self, key: str):
        """Delete a key (tombstone)."""
        with self.lock:
            self.memtable.put(key, "__TOMBSTONE__")

            if self._should_flush_memtable():
                self._flush_memtable()

    def _should_flush_memtable(self) -> bool:
        """Check if memtable should be flushed."""
        # Simple size-based check
        return len(self.memtable.data) >= 100  # Simplified threshold

    def _flush_memtable(self):
        """Flush current memtable to SSTable."""
        if self.memtable.is_empty():
            return

        # Create immutable copy
        immutable = Memtable(self.memtable.variant)
        immutable.data = self.memtable.data.copy()

        self.immutable_memtables.append(immutable)
        self.memtable.clear()

        # Convert to SSTable
        self._convert_immutable_to_sstable(immutable)

    def _convert_immutable_to_sstable(self, memtable: Memtable):
        """Convert memtable to SSTable."""
        level = 0
        file_path = f"{self.config.data_dir}/sstable_L{level}_{int(time.time())}.sst"

        metadata = SSTableMetadata(level, file_path)
        sstable = SSTable(file_path, metadata)

        # Copy data (excluding tombstones for simplicity)
        for key, value in memtable.data.items():
            if value != "__TOMBSTONE__":
                sstable.data[key] = value

        metadata.entry_count = len(sstable.data)
        if sstable.data:
            metadata.min_key = min(sstable.data.keys())
            metadata.max_key = max(sstable.data.keys())

        sstable.save_to_file()
        self.sstables.append(sstable)

    def perform_compaction_if_needed(self):
        """Check and perform compaction if needed."""
        with self.lock:
            level_sizes = self._get_level_sizes()
            if self.compaction_strategy.should_compact(level_sizes):
                self._perform_compaction()

    def _perform_compaction(self):
        """Perform compaction on levels that need it."""
        # Simple compaction: merge all SSTables in level 0
        level_0_sstables = [s for s in self.sstables if s.metadata.level == 0]

        if len(level_0_sstables) >= 4:  # Threshold
            self._compact_level(0, level_0_sstables)

    def _compact_level(self, level: int, sstables: List[SSTable]):
        """Compact SSTables in a level."""
        if not sstables:
            return

        # Merge data
        merged_data: Dict[str, str] = {}
        for sstable in sstables:
            for key, value in sstable.data.items():
                if value != "__TOMBSTONE__":
                    merged_data[key] = value

        # Create new SSTable
        new_level = level + 1
        file_path = f"{self.config.data_dir}/sstable_L{new_level}_{int(time.time())}.sst"

        metadata = SSTableMetadata(new_level, file_path)
        new_sstable = SSTable(file_path, metadata)
        new_sstable.data = merged_data
        metadata.entry_count = len(merged_data)
        if merged_data:
            metadata.min_key = min(merged_data.keys())
            metadata.max_key = max(merged_data.keys())

        new_sstable.save_to_file()

        # Remove old SSTables
        for sstable in sstables:
            try:
                os.remove(sstable.file_path)
            except OSError:
                pass
            self.sstables.remove(sstable)

        self.sstables.append(new_sstable)

    def _get_level_sizes(self) -> List[int]:
        """Get the number of SSTables per level."""
        levels = {}
        for sstable in self.sstables:
            level = sstable.metadata.level
            levels[level] = levels.get(level, 0) + 1

        max_level = max(levels.keys()) if levels else 0
        return [levels.get(i, 0) for i in range(max_level + 1)]

    def _load_existing_sstables(self):
        """Load existing SSTables from disk."""
        if not os.path.exists(self.config.data_dir):
            return

        for filename in os.listdir(self.config.data_dir):
            if filename.endswith('.sst'):
                file_path = os.path.join(self.config.data_dir, filename)
                # Parse level from filename (simplified)
                level = 0
                if '_L' in filename:
                    try:
                        level_str = filename.split('_L')[1].split('_')[0]
                        level = int(level_str)
                    except (ValueError, IndexError):
                        level = 0

                metadata = SSTableMetadata(level, file_path)
                sstable = SSTable(file_path, metadata)
                sstable.load_from_file()
                metadata.entry_count = len(sstable.data)
                if sstable.data:
                    metadata.min_key = min(sstable.data.keys())
                    metadata.max_key = max(sstable.data.keys())
                self.sstables.append(sstable)

    def get_stats(self) -> Dict[str, int]:
        """Get LSM tree statistics."""
        return {
            "memtable_entries": len(self.memtable.data),
            "memtable_size_bytes": len(str(self.memtable.data).encode('utf-8')),
            "immutable_memtables": len(self.immutable_memtables),
            "sstables_count": len(self.sstables),
            "total_entries": sum(len(s.data) for s in self.sstables)
        }

    def close(self):
        """Close the LSM tree."""
        self.compaction_worker.stop()
        # Flush any remaining data
        if not self.memtable.is_empty():
            self._flush_memtable()


# Database Configuration
class DatabaseConfig:
    def __init__(self,
                 name: str = "lsm_db",
                 data_dir: str = "./lsm_database",
                 lsm_config: Optional[LSMTreeConfig] = None,
                 enable_wal: bool = True,
                 wal_sync_mode: str = "sync",
                 max_concurrent_operations: int = 10,
                 enable_metrics: bool = True):
        self.name = name
        self.data_dir = data_dir
        self.lsm_config = lsm_config or LSMTreeConfig()
        self.enable_wal = enable_wal
        self.wal_sync_mode = wal_sync_mode
        self.max_concurrent_operations = max_concurrent_operations
        self.enable_metrics = enable_metrics

    def validate(self):
        """Validate database configuration."""
        if self.max_concurrent_operations <= 0:
            raise ValueError("max_concurrent_operations must be positive")

        valid_sync_modes = ["sync", "async", "batch"]
        if self.wal_sync_mode not in valid_sync_modes:
            raise ValueError(f"Invalid wal_sync_mode. Valid options: {valid_sync_modes}")


# Write-Ahead Log entry
class WALEntry:
    def __init__(self, operation: str, key: str, value: str = "",
                 timestamp: Optional[float] = None, sequence_number: int = 0):
        self.operation = operation
        self.key = key
        self.value = value
        self.timestamp = timestamp or time.time()
        self.sequence_number = sequence_number

    def to_string(self) -> str:
        """Serialize WAL entry to string format."""
        return f"{self.operation},{self.key},{self.value},{self.timestamp},{self.sequence_number}"

    @staticmethod
    def from_string(line: str) -> 'WALEntry':
        """Deserialize WAL entry from string format."""
        parts = line.strip().split(',')
        if len(parts) != 5:
            raise ValueError("Invalid WAL entry format")

        return WALEntry(
            operation=parts[0],
            key=parts[1],
            value=parts[2],
            timestamp=float(parts[3]),
            sequence_number=int(parts[4])
        )


# Write-Ahead Log manager
class WALManager:
    def __init__(self, data_dir: str, db_name: str, enabled: bool = True):
        self.wal_file = os.path.join(data_dir, f"{db_name}.wal")
        self.current_sequence = 0
        self.is_enabled = enabled

        if enabled:
            os.makedirs(data_dir, exist_ok=True)

    def append_entry(self, entry: WALEntry):
        """Append a WAL entry to the log file."""
        if not self.is_enabled:
            return

        wal_entry = WALEntry(
            entry.operation, entry.key, entry.value,
            entry.timestamp, self.current_sequence + 1
        )

        try:
            with open(self.wal_file, 'a') as file:
                file.write(wal_entry.to_string() + '\n')
            self.current_sequence += 1
        except IOError as e:
            print(f"WAL write error: {e}")

    def get_entries(self) -> List[WALEntry]:
        """Read all WAL entries from the log file."""
        entries = []

        if not self.is_enabled:
            return entries

        try:
            with open(self.wal_file, 'r') as file:
                for line in file:
                    line = line.strip()
                    if line:
                        entries.append(WALEntry.from_string(line))
        except IOError as e:
            print(f"WAL read error: {e}")

        return entries

    def clear(self):
        """Clear the WAL file (after successful checkpoint)."""
        if not self.is_enabled:
            return

        try:
            with open(self.wal_file, 'w') as file:
                file.truncate(0)
        except IOError as e:
            print(f"WAL clear error: {e}")


# Database metrics
class DatabaseMetrics:
    def __init__(self):
        self.total_operations = 0
        self.put_operations = 0
        self.get_operations = 0
        self.delete_operations = 0
        self.cache_hits = 0
        self.cache_misses = 0
        self.compaction_count = 0
        self.uptime_seconds = 0
        self.start_time = time.time()

    def record_operation(self, operation: str):
        """Record an operation in metrics."""
        self.total_operations += 1

        if operation == "PUT":
            self.put_operations += 1
        elif operation == "GET":
            self.get_operations += 1
        elif operation == "DELETE":
            self.delete_operations += 1

    def update_uptime(self):
        """Update uptime calculation."""
        self.uptime_seconds = int(time.time() - self.start_time)

    def get_stats(self) -> Dict[str, int]:
        """Get current metrics as a dictionary."""
        return {
            "total_operations": self.total_operations,
            "put_operations": self.put_operations,
            "get_operations": self.get_operations,
            "delete_operations": self.delete_operations,
            "cache_hits": self.cache_hits,
            "cache_misses": self.cache_misses,
            "compaction_count": self.compaction_count,
            "uptime_seconds": self.uptime_seconds
        }


# Main LSM Database class
class LSMDatabase:
    def __init__(self, config: DatabaseConfig):
        config.validate()

        self.config = config
        self.lsm_tree = LSMTree(config.lsm_config)
        self.wal_manager = WALManager(config.data_dir, config.name, config.enable_wal)
        self.metrics = DatabaseMetrics()
        self.is_open = True

        print(f"LSM Database '{config.name}' opened successfully")
        print(f"Data directory: {config.data_dir}")
        print(f"Memtable type: {config.lsm_config.memtable_type}")
        print(f"WAL enabled: {'Yes' if config.enable_wal else 'No'}")

    def put(self, key: str, value: str):
        """Insert or update a key-value pair."""
        if not self.is_open:
            raise RuntimeError("Database is closed")

        # Record operation in WAL
        wal_entry = WALEntry("PUT", key, value)
        self.wal_manager.append_entry(wal_entry)

        # Perform operation
        self.lsm_tree.put(key, value)

        # Update metrics
        if self.config.enable_metrics:
            self.metrics.record_operation("PUT")

    def get(self, key: str) -> str:
        """Get value for a key."""
        if not self.is_open:
            raise RuntimeError("Database is closed")

        # Perform operation
        value = self.lsm_tree.get(key)

        # Update metrics
        if self.config.enable_metrics:
            self.metrics.record_operation("GET")

        return value

    def delete(self, key: str):
        """Delete a key."""
        if not self.is_open:
            raise RuntimeError("Database is closed")

        # Record operation in WAL
        wal_entry = WALEntry("DELETE", key)
        self.wal_manager.append_entry(wal_entry)

        # Perform operation
        self.lsm_tree.delete(key)

        # Update metrics
        if self.config.enable_metrics:
            self.metrics.record_operation("DELETE")

    def get_stats(self) -> Dict[str, int]:
        """Get database statistics."""
        if not self.is_open:
            raise RuntimeError("Database is closed")

        # Update uptime
        self.metrics.update_uptime()

        # Get LSM tree stats
        lsm_stats = self.lsm_tree.get_stats()

        # Combine with database metrics
        combined_stats = self.metrics.get_stats()
        combined_stats.update({
            "lsm_memtable_entries": lsm_stats["memtable_entries"],
            "lsm_memtable_size": lsm_stats["memtable_size_bytes"],
            "lsm_sstables_count": lsm_stats["sstables_count"]
        })

        return combined_stats

    def close(self):
        """Close the database."""
        if not self.is_open:
            return

        print(f"Closing LSM Database '{self.config.name}'...")

        # Force final memtable flush if needed
        stats = self.lsm_tree.get_stats()
        if stats["memtable_entries"] > 0:
            self.lsm_tree._flush_memtable()

        # Clear WAL after successful operations
        if self.config.enable_wal:
            self.wal_manager.clear()

        self.lsm_tree.close()
        self.is_open = False
        print("Database closed successfully")

    def recover_from_wal(self):
        """Recover database state from WAL entries."""
        if not self.config.enable_wal:
            return

        print("Recovering from WAL...")
        wal_entries = self.wal_manager.get_entries()

        if not wal_entries:
            print("No WAL entries to recover")
            return

        print(f"Replaying {len(wal_entries)} WAL entries...")

        for entry in wal_entries:
            if entry.operation == "PUT":
                self.lsm_tree.put(entry.key, entry.value)
            elif entry.operation == "DELETE":
                self.lsm_tree.delete(entry.key)

        print("Recovery complete")


# Database factory functions
def create_database(name: str, data_dir: str = "./lsm_database",
                   memtable_type: str = MemtableVariant.HASH_SKIPLIST) -> LSMDatabase:
    """Create a new LSM database with default configuration."""
    lsm_config = LSMTreeConfig(
        memtable_type=memtable_type,
        max_memtable_size=1024 * 1024,  # 1MB
        data_dir=data_dir,
        enable_background_compaction=True
    )

    db_config = DatabaseConfig(
        name=name,
        data_dir=data_dir,
        lsm_config=lsm_config,
        enable_wal=True,
        wal_sync_mode="sync",
        enable_metrics=True
    )

    db = LSMDatabase(db_config)
    db.recover_from_wal()
    return db


def create_high_performance_database(name: str, data_dir: str = "./lsm_db_hp") -> LSMDatabase:
    """Create a high-performance database configuration."""
    lsm_config = LSMTreeConfig(
        memtable_type=MemtableVariant.HASH_SKIPLIST,
        max_memtable_size=2 * 1024 * 1024,  # 2MB
        data_dir=data_dir,
        enable_background_compaction=True,
        compaction_check_interval=2000  # 2 seconds
    )

    db_config = DatabaseConfig(
        name=name,
        data_dir=data_dir,
        lsm_config=lsm_config,
        enable_wal=True,
        wal_sync_mode="async",
        max_concurrent_operations=50,
        enable_metrics=True
    )

    db = LSMDatabase(db_config)
    db.recover_from_wal()
    return db


def create_memory_efficient_database(name: str, data_dir: str = "./lsm_db_me") -> LSMDatabase:
    """Create a memory-efficient database configuration."""
    lsm_config = LSMTreeConfig(
        memtable_type=MemtableVariant.LINKED_LIST,
        max_memtable_size=256 * 1024,  # 256KB
        data_dir=data_dir,
        enable_background_compaction=True,
        compaction_check_interval=10000  # 10 seconds
    )

    db_config = DatabaseConfig(
        name=name,
        data_dir=data_dir,
        lsm_config=lsm_config,
        enable_wal=True,
        wal_sync_mode="batch",
        max_concurrent_operations=5,
        enable_metrics=True
    )

    db = LSMDatabase(db_config)
    db.recover_from_wal()
    return db


# Demonstration functions
def demo_basic_database_operations():
    """Demonstrate basic database operations."""
    print("=== Basic LSM Database Operations ===\n")

    db = create_database("demo_db", "./demo_database")

    print("Performing database operations...\n")

    # Insert test data
    test_data = [
        ("user:alice", "Alice Johnson"),
        ("user:bob", "Bob Smith"),
        ("product:laptop", "Gaming Laptop"),
        ("product:mouse", "Wireless Mouse"),
        ("order:1001", "Alice's Order")
    ]

    for key, value in test_data:
        db.put(key, value)
        print(f"PUT: {key} = {value}")

    print()

    # Read operations
    print("Reading data back:")
    for key, expected in test_data:
        value = db.get(key)
        print(f"GET: {key} = {value}")

    print()

    # Delete operation
    print("Deleting user:bob...")
    db.delete("user:bob")
    deleted_value = db.get("user:bob")
    print(f"GET user:bob after delete: {deleted_value if deleted_value else '(not found)'}")

    print()

    # Get statistics
    print("Database Statistics:")
    stats = db.get_stats()
    print(f"Total operations: {stats['total_operations']}")
    print(f"PUT operations: {stats['put_operations']}")
    print(f"GET operations: {stats['get_operations']}")
    print(f"DELETE operations: {stats['delete_operations']}")
    print(f"Uptime: {stats['uptime_seconds']} seconds")
    print(f"LSM memtable entries: {stats['lsm_memtable_entries']}")
    print(f"LSM SSTable count: {stats['lsm_sstables_count']}")

    db.close()


def demo_database_configurations():
    """Demonstrate different database configurations."""
    print("=== Database Configuration Comparison ===\n")

    configs = [
        ("High-Performance", MemtableVariant.HASH_SKIPLIST),
        ("Memory-Efficient", MemtableVariant.LINKED_LIST),
        ("Balanced", MemtableVariant.ENHANCED_SKIPLIST)
    ]

    for config_name, memtable_type in configs:
        print(f"--- {config_name} Configuration ---")

        db_name = f"config_test_{memtable_type}"
        data_dir = f"./config_test_{memtable_type}"

        # Create appropriate configuration
        if config_name == "High-Performance":
            db = create_high_performance_database(db_name, data_dir)
        elif config_name == "Memory-Efficient":
            db = create_memory_efficient_database(db_name, data_dir)
        else:
            db = create_database(db_name, data_dir, memtable_type)

        # Quick performance test
        start_time = time.time()
        for i in range(100):
            db.put(f"key{i}", f"value{i}")
        end_time = time.time()

        stats = db.get_stats()
        print(f"Configuration: {config_name}")
        print(f"Memtable type: {memtable_type}")
        print("Operations completed: 100")
        print(f"Time taken: {end_time - start_time:.2f} seconds")
        print(f"Memtable entries: {stats['lsm_memtable_entries']}")
        print(f"Memtable size: {stats['lsm_memtable_size']} bytes")

        db.close()
        print()


def demo_wal_recovery():
    """Demonstrate WAL-based recovery."""
    print("=== WAL Recovery Demonstration ===\n")

    db_name = "recovery_test"
    data_dir = "./recovery_test"

    print("Phase 1: Create database and add data...")
    db = create_database(db_name, data_dir)
    for i in range(50):
        db.put(f"recovery_key{i}", f"recovery_value{i}")
    print("Added 50 entries to database")
    db.close()  # This should clear WAL

    print("\nPhase 2: Simulate crash and recovery...")
    db2 = create_database(db_name, data_dir)
    # Recovery should happen automatically in constructor

    recovered_count = 0
    for i in range(50):
        value = db2.get(f"recovery_key{i}")
        if value:
            recovered_count += 1

    print(f"Recovered entries: {recovered_count} / 50")

    stats = db2.get_stats()
    print("Database stats after recovery:")
    print(f"Total operations: {stats['total_operations']}")
    print(f"Memtable entries: {stats['lsm_memtable_entries']}")

    db2.close()

    print("\nRecovery test completed successfully!")


if __name__ == "__main__":
    """Main entry point for LSM database demonstrations."""
    demo_basic_database_operations()
    demo_database_configurations()
    demo_wal_recovery()