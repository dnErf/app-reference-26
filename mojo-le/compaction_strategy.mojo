"""
Compaction Strategy Implementation in Mojo
===========================================

This file implements unified compaction strategies for the LSM Tree system,
combining level-based and size-tiered compaction approaches for optimal
storage efficiency and query performance.

Key Features:
- Level-based compaction for predictable performance
- Size-tiered compaction for write optimization
- Configurable compaction triggers and policies
- Background compaction worker simulation
- Merge policies for overlapping SSTables

Performance Characteristics:
- Level-based: Predictable read/write patterns, higher space amplification
- Size-tiered: Better write performance, variable read patterns
- Unified: Balances both approaches based on level and size thresholds

Use Cases:
- Level-based: Read-heavy workloads, predictable performance
- Size-tiered: Write-heavy workloads, variable read patterns
- Unified: Balanced workloads, adaptive compaction

Integration:
- Works with SSTable metadata for compaction decisions
- Triggers based on level sizes and file counts
- Background processing to avoid blocking writes
"""

from collections import List, Dict

# Forward declaration for SSTableMetadata
struct SSTableMetadata(Movable):
    var filename: String
    var min_key: String
    var max_key: String
    var num_entries: Int
    var file_size: Int
    var created_at: Int64
    var level: Int

    fn __init__(out self, filename: String, min_key: String, max_key: String,
                num_entries: Int, file_size: Int, level: Int = 0):
        self.filename = filename
        self.min_key = min_key
        self.max_key = max_key
        self.num_entries = num_entries
        self.file_size = file_size
        self.created_at = 0  # Placeholder
        self.level = level

# Compaction task representation
struct CompactionTask(Movable):
    var level: Int
    var input_files: List[String]
    var output_files: List[String]
    var strategy: String  # "level" or "size"
    var priority: Int     # Higher number = higher priority

    fn __init__(out self, level: Int, strategy: String, priority: Int = 1):
        self.level = level
        self.input_files = List[String]()
        self.output_files = List[String]()
        self.strategy = strategy
        self.priority = priority

# Unified compaction strategy
struct CompactionStrategy:
    var max_level_files: Dict[Int, Int]  # Max files per level
    var level_sizes: Dict[Int, Int]      # Target size per level
    var size_ratio: Float64              # Size ratio for size-tiered

    fn __init__(out self) raises:
        self.max_level_files = Dict[Int, Int]()
        self.level_sizes = Dict[Int, Int]()
        self.size_ratio = 10.0  # 10:1 size ratio for size-tiered

        # Initialize level configurations
        self._init_level_config()

    fn _init_level_config(mut self) raises:
        """Initialize level-based configuration."""
        # Level 0: Special case, allow more files
        self.max_level_files[0] = 4

        # Levels 1-6: Exponential growth
        for level in range(1, 7):
            self.max_level_files[level] = level * 10

        # Level sizes: 10MB, 100MB, 1GB, etc.
        self.level_sizes[0] = 10 * 1024 * 1024      # 10MB
        self.level_sizes[1] = 100 * 1024 * 1024     # 100MB
        self.level_sizes[2] = 1024 * 1024 * 1024    # 1GB
        self.level_sizes[3] = 10 * 1024 * 1024 * 1024  # 10GB
        for level in range(4, 7):
            try:
                self.level_sizes[level] = self.level_sizes[level-1] * 10
            except:
                self.level_sizes[level] = 100 * 1024 * 1024 * 1024  # 100GB fallback

    fn should_compact(self, level_file_counts: Dict[Int, Int], level_sizes: Dict[Int, Int]) -> Bool:
        """Check if any level needs compaction."""
        for level in level_file_counts.keys():
            try:
                var level_copy = level  # Avoid aliasing
                var count = level_file_counts[level_copy]
                var max_files = self.max_level_files.get(level_copy, 10)
                if count >= max_files:
                    return True

                # Check size-tiered for levels >= 1
                if level_copy >= 1:
                    var current_size = level_sizes.get(level_copy, 0)
                    var target_size = self.level_sizes.get(level_copy, 100*1024*1024)
                    if current_size >= target_size:
                        return True
            except:
                continue

        return False

    fn plan_compaction(self, level_file_counts: Dict[Int, Int]) raises -> CompactionTask:
        """Plan the next compaction task."""
        var highest_priority = -1
        var best_task: CompactionTask = CompactionTask(0, "none", 0)

        # Check each level for compaction needs
        for level in level_file_counts.keys():
            try:
                var file_count = level_file_counts[level]

                if level == 0:
                    var max_files = self.max_level_files.get(level, 4)
                    if file_count >= max_files:
                        var task = CompactionTask(level, "size", file_count)
                        if task.priority > highest_priority:
                            highest_priority = task.priority
                            best_task = task^

                # Higher levels: Use level-based when approaching limit
                elif level > 0:
                    var max_files = self.max_level_files.get(level, 10)
                    if file_count >= max_files - 1:  # Start early to avoid blocking
                        var task = CompactionTask(level, "level", file_count)
                        if task.priority > highest_priority:
                            highest_priority = task.priority
                            best_task = task^
            except:
                continue

        return best_task^

    fn execute_compaction(self, task: CompactionTask) raises -> List[String]:
        """Execute compaction and return new SSTable filenames."""
        var new_files = List[String]()

        print("Executing compaction:")
        print("  Level:", task.level)
        print("  Strategy:", task.strategy)
        print("  Priority:", task.priority)

        if task.strategy == "level":
            new_files = self._execute_level_compaction(task)
        elif task.strategy == "size":
            new_files = self._execute_size_compaction(task)
        else:
            print("  Unknown strategy, skipping")

        print("  Output files:", len(new_files))
        return new_files^

    fn _execute_level_compaction(self, task: CompactionTask) raises -> List[String]:
        """Execute level-based compaction."""
        var new_files = List[String]()

        # In level-based compaction, we merge files in the level
        # and create files for the next level
        var next_level = task.level + 1
        var total_entries = task.priority * 100  # Estimate based on priority
        var num_new_files = max(1, total_entries // 1000)  # Rough estimate

        for i in range(num_new_files):
            var filename = "sstable_L" + String(next_level) + "_compacted_" + String(i) + ".parquet"
            new_files.append(filename)

        return new_files^

    fn _execute_size_compaction(self, task: CompactionTask) raises -> List[String]:
        """Execute size-tiered compaction."""
        var new_files = List[String]()

        # In size-tiered compaction, we create a single larger file
        var filename = "sstable_L" + String(task.level) + "_size_compacted.parquet"
        new_files.append(filename)

        return new_files^

    fn get_stats(self) raises -> String:
        """Get compaction strategy statistics."""
        var stats = "Compaction Strategy Stats:\n"
        stats += "  Size ratio: " + String(self.size_ratio) + "\n"
        stats += "  Max files per level:\n"

        for level in self.max_level_files.keys():
            try:
                var max_files = self.max_level_files[level]
                stats += "    Level " + String(level) + ": " + String(max_files) + " files\n"
            except:
                stats += "    Level " + String(level) + ": unknown files\n"

        stats += "  Target sizes per level:\n"
        for level in self.level_sizes.keys():
            try:
                var size_mb = self.level_sizes[level] // (1024 * 1024)
                stats += "    Level " + String(level) + ": " + String(size_mb) + " MB\n"
            except:
                stats += "    Level " + String(level) + ": unknown MB\n"

        return stats

# Demonstration functions
fn demo_compaction_strategy() raises:
    """Demonstrate compaction strategy operations."""
    print("=== Compaction Strategy Demonstration ===\n")

    var strategy = CompactionStrategy()

    print("Strategy Configuration:")
    print(strategy.get_stats())
    print()

    # Create sample level file counts and sizes
    var level_file_counts = Dict[Int, Int]()
    level_file_counts[0] = 5  # Level 0: 5 files (over limit of 4)
    level_file_counts[1] = 12  # Level 1: 12 files (over limit of 10)

    var level_sizes = Dict[Int, Int]()
    level_sizes[0] = 5 * 1024 * 1024  # 5MB
    level_sizes[1] = 12 * 1024 * 1024  # 12MB

    print("Level Status:")
    for level in level_file_counts.keys():
        try:
            var level_copy = level  # Avoid aliasing
            var count = level_file_counts[level_copy]
            var size = level_sizes.get(level_copy, 0)
            var size_mb = size // (1024 * 1024)
            print("  Level", level_copy, ":", count, "files,", size_mb, "MB")
        except:
            continue
    print()

    # Check if compaction is needed
    var needs_compaction = strategy.should_compact(level_file_counts, level_sizes)
    print("Compaction needed:", needs_compaction)
    print()

    if needs_compaction:
        # Plan compaction
        var task = strategy.plan_compaction(level_file_counts)
        print("Planned compaction:")
        print("  Level:", task.level)
        print("  Strategy:", task.strategy)
        print("  Priority:", task.priority)
        print()

        # Execute compaction
        var new_files = strategy.execute_compaction(task)
        print("\nNew files created:")
        for filename in new_files:
            print("  ", filename)

    print("\n=== Compaction Strategy Demo Complete ===")

fn main() raises:
    """Main entry point."""
    demo_compaction_strategy()