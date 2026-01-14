# Incremental Processor with Merkle Proof Support
# Provides change data capture with cryptographic integrity

from collections import List, Dict
from merkle_timeline import MerkleTimeline, MerkleProof

# Individual change record with Merkle verification
struct Change(Movable, Copyable):
    var change_type: String
    var table: String
    var key_columns: List[String]
    var key_values: List[String]
    var data: Dict[String, String]  # Column -> Value mapping
    var timestamp: Int64
    var commit_id: String
    var merkle_proof: MerkleProof  # Cryptographic proof for this change

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
        """Verify this change's integrity using Merkle proof."""
        return timeline.verify_commit_proof(self.commit_id, self.merkle_proof)

# Change set for batch processing with cryptographic integrity
struct ChangeSet(Movable, Copyable):
    var changes: List[Change]
    var watermark: Int64
    var table: String
    var merkle_root: UInt64
    var commit_proof: MerkleProof  # Proof for the entire change set

    fn __init__(out self, table: String, watermark: Int64 = 0):
        self.changes = List[Change]()
        self.watermark = watermark
        self.table = table
        self.merkle_root = 0
        self.commit_proof = MerkleProof()

    fn add_change(mut self, change: Change):
        """Add a change to the set."""
        self.changes.append(change.copy())

    fn count_changes(self) -> Int:
        """Count total changes."""
        return len(self.changes)

    fn verify_integrity(self, timeline: MerkleTimeline) raises -> Bool:
        """Verify the entire change set integrity."""
        # Verify the change set proof
        if not timeline.verify_commit_proof(self.table + "_changeset_" + String(self.watermark), self.commit_proof):
            return False

        # Verify each individual change
        for change in self.changes:
            if not change.verify_integrity(timeline):
                return False

        return True

# Incremental Processor with Merkle verification
struct IncrementalProcessor(Movable, Copyable):
    var timeline: MerkleTimeline
    var change_log: Dict[String, List[Change]]  # table -> changes
    var watermarks: Dict[String, Int64]  # table -> last processed timestamp
    var processed_commits: Dict[String, Bool]  # commit_id -> processed status

    fn __init__(out self):
        self.timeline = MerkleTimeline()
        self.change_log = Dict[String, List[Change]]()
        self.watermarks = Dict[String, Int64]()
        self.processed_commits = Dict[String, Bool]()

    fn process_commit_changes(mut self, table: String, since_watermark: Int64) raises -> ChangeSet:
        """Process changes from commits since watermark and return ChangeSet with Merkle proofs."""
        var changeset = ChangeSet(table, since_watermark)

        # Get commits from timeline since the watermark
        var commits = self.timeline.get_commits_since(table, since_watermark)

        for commit_data in commits:
            var parts = commit_data.split("|")
            if len(parts) >= 4:
                var commit_id = String(parts[0])
                var timestamp = Int64(parts[1])
                var changes_str = parts[3]

                # Skip if already processed
                if commit_id in self.processed_commits:
                    continue

                # Parse individual changes
                var change_lines = changes_str.split(";")
                for change_line in change_lines:
                    if len(change_line) > 0:
                        var change = self._parse_change(String(change_line), table, timestamp, commit_id)
                        # Generate Merkle proof for this change
                        change.merkle_proof = self.timeline.get_commit_proof(commit_id)
                        changeset.add_change(change.copy())

                # Mark commit as processed
                self.processed_commits[commit_id] = True

        # Generate proof for the entire change set
        if len(commits) > 0:
            var last_commit_parts = commits[len(commits) - 1].split("|")
            changeset.commit_proof = self.timeline.get_commit_proof(String(last_commit_parts[0]))
            changeset.merkle_root = self.timeline.commit_tree.nodes[self.timeline.commit_tree.root_index].merkle_hash

        # Store in change log
        if not table in self.change_log:
            self.change_log[table] = List[Change]()
        for change in changeset.changes:
            self.change_log[table].append(change.copy())

        return changeset.copy()

    fn _parse_change(self, change_str: String, table: String, timestamp: Int64, commit_id: String) -> Change:
        """Parse a change string into Change struct."""
        var change = Change("INSERT", table, timestamp, commit_id)

        if change_str.find("INSERT") != -1:
            change.change_type = "INSERT"
        elif change_str.find("UPDATE") != -1:
            change.change_type = "UPDATE"
        elif change_str.find("DELETE") != -1:
            change.change_type = "DELETE"

        # Parse key columns and values (simplified)
        change.key_columns.append("id")
        change.key_values.append("1")
        change.data["operation"] = change_str

        return change.copy()

    fn get_changes_since(mut self, table: String, since: Int64) raises -> ChangeSet:
        """Get changes since a specific timestamp with Merkle verification."""
        return self.process_commit_changes(table, since)

    fn update_watermark(mut self, table: String, watermark: Int64):
        """Update watermark for a table."""
        self.watermarks[table] = watermark
        self.timeline.update_watermark(table, watermark)

    fn verify_changes_integrity(self, changeset: ChangeSet) raises -> Bool:
        """Verify change set integrity using Merkle proof."""
        return changeset.verify_integrity(self.timeline)

    fn process_table_incremental(mut self, table: String, processor_fn: fn(ChangeSet) -> ()) raises:
        """Process incremental changes for a table."""
        var watermark = self.watermarks.get(table, 0)
        var changeset = self.get_changes_since(table, watermark)

        if changeset.count_changes() > 0:
            # Verify integrity before processing
            if not self.verify_changes_integrity(changeset):
                print("⚠️  Warning: Change set integrity verification failed for table:", table)
                return

            # Process the changes
            processor_fn(changeset)

            # Update watermark
            self.update_watermark(table, changeset.watermark)

    fn get_stats(mut self) raises -> String:
        """Get processor statistics."""
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
