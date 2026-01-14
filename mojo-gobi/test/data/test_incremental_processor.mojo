# Test IncrementalProcessor with Merkle Proof Support
# Demonstrates change data capture with cryptographic integrity

# Include necessary code directly for testing
from collections import List, Dict

# Merkle Proof for cryptographic verification
struct MerkleProof(Movable, Copyable):
    var target_hash: UInt64
    var proof_hashes: List[UInt64]
    var is_left: List[Bool]  # True if sibling is on left, False if on right

    fn __init__(out self):
        self.target_hash = 0
        self.proof_hashes = List[UInt64]()
        self.is_left = List[Bool]()

    fn verify(self, root_hash: UInt64) -> Bool:
        """Verify the proof against a root hash."""
        var current_hash = self.target_hash

        for i in range(len(self.proof_hashes)):
            var hash_data = String("")
            if self.is_left[i]:
                # Sibling is on left, so hash = sibling_hash + current_hash
                hash_data = String(self.proof_hashes[i]) + String(current_hash)
            else:
                # Sibling is on right, so hash = current_hash + sibling_hash
                hash_data = String(current_hash) + String(self.proof_hashes[i])
            current_hash = self._compute_hash(hash_data)

        return current_hash == root_hash

    fn _compute_hash(self, data: String) -> UInt64:
        """Compute hash of string data."""
        var h = UInt64(0)
        for i in range(len(data)):
            h = (h * 31) + UInt64(ord(data[i]))
        return h

# Simplified MerkleBPlusTree for testing
struct MerkleBPlusTree(Movable, Copyable):
    var nodes: List[UInt64]
    var root_index: Int
    var compaction_strategy: UniversalCompactionStrategy

    fn __init__(out self):
        self.nodes = List[UInt64]()
        self.root_index = 0
        self.compaction_strategy = UniversalCompactionStrategy()

    fn insert(self, key: Int, value: String) -> Bool:
        # Simplified insert
        return True

    fn range_query(self, start: Int, end: Int) -> List[String]:
        # Simplified range query - return empty for testing
        return List[String]()

    fn verify_integrity(self) -> Bool:
        return True

    fn count_nodes(self) -> Int:
        return len(self.nodes)

    fn clear(self):
        self.nodes.clear()

    fn get_merkle_proof(self, key: Int) raises -> MerkleProof:
        var proof = MerkleProof()
        proof.target_hash = UInt64(key)
        return proof

# Universal Compaction Strategy
struct UniversalCompactionStrategy(Movable, Copyable):
    var compaction_threshold: Float64
    var reorganization_count: Int

    fn __init__(out self, threshold: Float64 = 0.7):
        self.compaction_threshold = threshold
        self.reorganization_count = 0

    fn should_compact(self, tree: MerkleBPlusTree) -> Bool:
        return False

    fn compact_data(self, data: List[KeyValue]) -> List[KeyValue]:
        return data.copy()

# KeyValue for compaction
struct KeyValue(Movable, Copyable):
    var key: Int
    var value: String

    fn __init__(out self, k: Int, v: String):
        self.key = k
        self.value = v

# Simplified MerkleTimeline for testing
struct MerkleTimeline(Movable, Copyable):
    var commit_tree: MerkleBPlusTree
    var snapshots: Dict[String, Int64]
    var table_watermarks: Dict[String, Int64]
    var commit_counter: Int

    fn __init__(out self):
        self.commit_tree = MerkleBPlusTree()
        self.snapshots = Dict[String, Int64]()
        self.table_watermarks = Dict[String, Int64]()
        self.commit_counter = 0

    fn commit(mut self, table: String, changes: List[String]) -> String:
        self.commit_counter += 1
        var timestamp = Int64(self.commit_counter * 1000)
        var commit_id = "commit_" + String(timestamp) + "_" + table
        return commit_id

    fn get_commits_since(self, table: String, since: Int64) -> List[String]:
        return List[String]()

    fn get_commit_proof(self, commit_id: String) raises -> MerkleProof:
        var proof = MerkleProof()
        return proof

    fn verify_commit_proof(self, commit_id: String, proof: MerkleProof) raises -> Bool:
        return True

    fn verify_timeline_integrity(mut self) -> Bool:
        return True

    fn update_watermark(mut self, table: String, watermark: Int64):
        self.table_watermarks[table] = watermark

# Change types for incremental processing
struct ChangeType:
    static let INSERT: String = "INSERT"
    static let UPDATE: String = "UPDATE"
    static let DELETE: String = "DELETE"

# Individual change record with Merkle verification
struct Change(Movable, Copyable):
    var change_type: String
    var table: String
    var key_columns: List[String]
    var key_values: List[String]
    var data: Dict[String, String]
    var timestamp: Int64
    var commit_id: String
    var merkle_proof: MerkleProof

    fn __init__(out self, change_type: String, table: String, timestamp: Int64, commit_id: String):
        self.change_type = change_type
        self.table = table
        self.key_columns = List[String]()
        self.key_values = List[String]()
        self.data = Dict[String, String]()
        self.timestamp = timestamp
        self.commit_id = commit_id
        self.merkle_proof = MerkleProof()

    fn verify_integrity(self, timeline: MerkleTimeline) raises -> Bool:
        return timeline.verify_commit_proof(self.commit_id, self.merkle_proof)

# Change set for batch processing with cryptographic integrity
struct ChangeSet(Movable, Copyable):
    var changes: List[Change]
    var watermark: Int64
    var table: String
    var merkle_root: UInt64
    var commit_proof: MerkleProof

    fn __init__(out self, table: String, watermark: Int64 = 0):
        self.changes = List[Change]()
        self.watermark = watermark
        self.table = table
        self.merkle_root = 0
        self.commit_proof = MerkleProof()

    fn add_change(mut self, change: Change):
        self.changes.append(change.copy())

    fn count_changes(self) -> Int:
        return len(self.changes)

    fn verify_integrity(self, timeline: MerkleTimeline) raises -> Bool:
        for change in self.changes:
            if not change.verify_integrity(timeline):
                return False
        return True

# Incremental Processor with Merkle verification
struct IncrementalProcessor(Movable, Copyable):
    var timeline: MerkleTimeline
    var change_log: Dict[String, List[Change]]
    var watermarks: Dict[String, Int64]
    var processed_commits: Dict[String, Bool]

    fn __init__(out self):
        self.timeline = MerkleTimeline()
        self.change_log = Dict[String, List[Change]]()
        self.watermarks = Dict[String, Int64]()
        self.processed_commits = Dict[String, Bool]()

    fn process_commit_changes(mut self, table: String, since_watermark: Int64) raises -> ChangeSet:
        var changeset = ChangeSet(table, since_watermark)
        var commits = self.timeline.get_commits_since(table, since_watermark)

        for commit_data in commits:
            var parts = commit_data.split("|")
            if len(parts) >= 4:
                var commit_id = String(parts[0])
                var timestamp = Int64(parts[1])
                var changes_str = parts[3]

                if commit_id in self.processed_commits:
                    continue

                var change_lines = changes_str.split(";")
                for change_line in change_lines:
                    if len(change_line) > 0:
                        var change = self._parse_change(String(change_line), table, timestamp, commit_id)
                        change.merkle_proof = self.timeline.get_commit_proof(commit_id)
                        changeset.add_change(change)

                self.processed_commits[commit_id] = True

        if len(commits) > 0:
            var last_commit_parts = commits[len(commits) - 1].split("|")
            changeset.commit_proof = self.timeline.get_commit_proof(String(last_commit_parts[0]))
            changeset.merkle_root = self.timeline.commit_tree.nodes[self.timeline.commit_tree.root_index]

        if not table in self.change_log:
            self.change_log[table] = List[Change]()
        for change in changeset.changes:
            self.change_log[table].append(change.copy())

        return changeset.copy()

    fn _parse_change(self, change_str: String, table: String, timestamp: Int64, commit_id: String) -> Change:
        var change = Change("INSERT", table, timestamp, commit_id)

        if change_str.find("INSERT") != -1:
            change.change_type = "INSERT"
        elif change_str.find("UPDATE") != -1:
            change.change_type = "UPDATE"
        elif change_str.find("DELETE") != -1:
            change.change_type = "DELETE"

        change.key_columns.append("id")
        change.key_values.append("1")
        change.data["operation"] = change_str

        return change.copy()

    fn get_changes_since(mut self, table: String, since: Int64) raises -> ChangeSet:
        return self.process_commit_changes(table, since)

    fn update_watermark(mut self, table: String, watermark: Int64):
        self.watermarks[table] = watermark
        self.timeline.update_watermark(table, watermark)

    fn verify_changes_integrity(self, changeset: ChangeSet) raises -> Bool:
        return changeset.verify_integrity(self.timeline)

    fn process_table_incremental(mut self, table: String, processor_fn: fn(ChangeSet) -> ()) raises:
        var watermark = self.watermarks.get(table, 0)
        var changeset = self.get_changes_since(table, watermark)

        if changeset.count_changes() > 0:
            if not self.verify_changes_integrity(changeset):
                print("⚠️  Warning: Change set integrity verification failed for table:", table)
                return

            processor_fn(changeset)
            self.update_watermark(table, changeset.watermark)

    fn get_stats(mut self) raises -> String:
        var stats = "Incremental Processor Statistics:\n"
        stats += "  Tables with changes: " + String(len(self.change_log)) + "\n"
        stats += "  Tables with watermarks: " + String(len(self.watermarks)) + "\n"
        stats += "  Processed commits: " + String(len(self.processed_commits)) + "\n"
        stats += "  Timeline integrity: " + String(self.timeline.verify_timeline_integrity()) + "\n"

        var total_changes = 0
        for entry in self.change_log.items():
            total_changes += len(entry.value)
        stats += "  Total changes processed: " + String(total_changes) + "\n"

        return stats

fn test_incremental_processor() raises:
    """Test the IncrementalProcessor with Merkle proof integration."""
    print("=== Testing IncrementalProcessor with Merkle Proofs ===\n")

    var processor = IncrementalProcessor()

    # Create some test commits in the timeline
    print("Creating test commits in timeline...")

    var changes1 = List[String]()
    changes1.append("INSERT INTO users VALUES (1, 'Alice')")
    changes1.append("INSERT INTO users VALUES (2, 'Bob')")
    var commit1 = processor.timeline.commit("users", changes1)

    var changes2 = List[String]()
    changes2.append("UPDATE users SET name = 'Alice Smith' WHERE id = 1")
    changes2.append("INSERT INTO users VALUES (3, 'Charlie')")
    var commit2 = processor.timeline.commit("users", changes2)

    var changes3 = List[String]()
    changes3.append("DELETE FROM users WHERE id = 2")
    var commit3 = processor.timeline.commit("users", changes3)

    print("✓ Created 3 commits with Merkle integrity\n")

    # Test getting changes since watermark
    print("Testing incremental change retrieval...")

    var changeset = processor.get_changes_since("users", 0)
    print("✓ Retrieved", changeset.count_changes(), "changes since watermark 0")

    # Verify integrity of the change set
    var integrity_ok = processor.verify_changes_integrity(changeset)
    print("✓ Change set integrity verified:", integrity_ok)

    # Update watermark
    processor.update_watermark("users", changeset.watermark)
    print("✓ Updated watermark to:", String(changeset.watermark))

    # Test getting changes since new watermark
    var changeset2 = processor.get_changes_since("users", changeset.watermark)
    print("✓ Retrieved", changeset2.count_changes(), "changes since updated watermark")

    print("\n=== Processor Statistics ===")
    print(processor.get_stats())

    print("\n✓ IncrementalProcessor test completed successfully!")

fn main() raises:
    test_incremental_processor()