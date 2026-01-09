# Merge Policies for Overlapping SSTables - 2026-01-08

## Overview

This document describes the implementation of merge policies for handling overlapping SSTables in the LSM Tree system. The merge policies determine when and how to merge SSTables that have overlapping key ranges to maintain efficient storage and query performance.

## Key Components

### KeyRange Struct
Represents a key range with minimum and maximum bounds:
- `overlaps(other: KeyRange)`: Checks if two ranges overlap
- `contains(key: String)`: Checks if range contains a specific key

### MergeIterator Struct
Iterator for efficiently merging multiple sorted SSTable streams:
- Maintains indices into external SSTable collections
- Tracks current position in each SSTable stream
- Provides sorted key-value pair iteration with duplicate resolution

### MergePolicy Struct
Main policy engine for SSTable merging decisions:
- Configurable merge parameters (max files, memory limits)
- Overlap detection algorithms
- Merge decision logic based on size and overlap ratios

## Implementation Details

### Overlap Detection
The system detects overlapping SSTable groups by analyzing key ranges:
```mojo
// Two ranges overlap if: range1.min <= range2.max AND range1.max >= range2.min
fn overlaps(self, other: KeyRange) -> Bool:
    return (self.min_key <= other.max_key) and (self.max_key >= other.min_key)
```

### Merge Decision Logic
Groups are merged based on:
1. **File Count**: Groups exceeding `max_merge_files` are always merged
2. **Overlap Ratio**: Groups with high overlap ratios (>50%) are merged
3. **Memory Constraints**: Merges respect `max_memory_mb` limits

### Merge Execution
The merge process:
1. Creates a new SSTable with combined key range
2. Updates metadata with merged statistics
3. Returns new SSTable metadata for integration

## Performance Characteristics

### Time Complexity
- **Overlap Detection**: O(N²) for N SSTables (can be optimized with interval trees)
- **Merge Iterator**: O(K log K) for K-way merge
- **Decision Logic**: O(1) per group evaluation

### Space Complexity
- **Memory Bounded**: Configurable memory limits prevent excessive RAM usage
- **Streaming Merge**: Processes data in chunks for large SSTable sets

### Optimization Opportunities
- **Interval Trees**: Replace O(N²) overlap detection with O(N log N)
- **Parallel Merging**: Concurrent merge of independent groups
- **Memory Pool**: Pre-allocated memory pools for merge operations

## Integration Points

### Compaction Strategy
Merge policies work with the compaction strategy to:
- Identify SSTable groups needing compaction
- Determine optimal merge order and priority
- Coordinate with background compaction workers

### LSM Tree Coordinator
The LSM tree uses merge policies for:
- Post-compaction cleanup of overlapping files
- Size-based merge triggers
- Query optimization through reduced file counts

## Testing and Validation

### Demo Output
```
=== Merge Policies for Overlapping SSTables Demo ===

Detected 2 overlap groups:
  Group 0 : SSTables [0, 1, 2]
  Group 1 : SSTables [3]

Merge recommendations:
  Group 0 (size = 3 ) should merge: True
Merging 3 SSTables...
Merge completed: created merged_sstable_300.parquet with 300 entries
    Merged result: merged_sstable_300.parquet ( key_000 to key_299 )
  Group 1 (size = 1 ) should merge: False

=== Merge Policies Demo Completed ===
```

### Test Scenarios
1. **No Overlaps**: Single SSTable groups remain unmerged
2. **Partial Overlaps**: Adjacent ranges trigger selective merging
3. **Full Overlaps**: Completely overlapping ranges consolidated
4. **Large Groups**: File count limits enforced for manageable merges

## Future Enhancements

### Advanced Features
- **Cost-Based Optimization**: Consider I/O costs and query patterns
- **Adaptive Policies**: Learn from access patterns to optimize merges
- **Incremental Merging**: Partial merges for very large SSTable sets

### Performance Improvements
- **GPU Acceleration**: Parallel overlap detection on GPU
- **Memory Mapping**: Zero-copy merging for read-heavy workloads
- **Compression-Aware**: Consider compression ratios in merge decisions

## Files Created
- `merge_policies.mojo`: Complete merge policy implementation
- Comprehensive documentation and testing

## Conclusion

The merge policies implementation provides a solid foundation for intelligent SSTable merging in the LSM Tree system. The modular design allows for easy extension with advanced optimization techniques while maintaining compatibility with the existing compaction strategy framework.