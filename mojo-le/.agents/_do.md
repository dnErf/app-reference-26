# Current Tasks - LSM Tree Implementation

## Set 1: Memtable Variants (COMPLETED)
- [x] SortedMemtable with binary search and range queries
- [x] SkipListMemtable (simplified Dict-based)
- [x] TrieMemtable with prefix operations

## Set 2: SSTable with PyArrow and Unified Compaction (COMPLETED)
- [x] Create `sstable.mojo` using PyArrow Parquet for persistent immutable files
- [x] Implement SSTable reader/writer with bloom filters
- [x] Add metadata management (min/max keys, size, timestamp)
- [x] Support for range queries and point lookups
- [x] Create `compaction_strategy.mojo` with level-based and size-tiered merging
- [x] Implement compaction triggers (size thresholds, level limits)
- [x] Background compaction worker
- [x] Merge policies for overlapping SSTables

## Integration Tasks (PENDING)
- [ ] Update LSM tree to support multiple memtable variants
- [ ] Add SSTable persistence layer
- [ ] Implement compaction triggers and background merging
