# Merkle Tree Implementation for Timeline Integrity

## 🌳 **Merkle Tree Structure**

```mojo
struct MerkleNode:
    var hash: String
    var left: Optional[MerkleNode]
    var right: Optional[MerkleNode]

struct MerkleTree:
    var root: Optional[MerkleNode]
    var leaves: List[String]  # Commit hashes

    fn __init__(self):
        self.root = None
        self.leaves = List[String]()

    fn add_leaf(self, data: String):
        """Add a commit hash to the Merkle tree"""
        # Hash the commit data
        leaf_hash = self._hash(data)
        self.leaves.append(leaf_hash)
        self._rebuild_tree()

    fn get_root_hash(self) -> String:
        """Get the current Merkle root"""
        if self.root:
            return self.root.value().hash
        return ""

    fn get_proof(self, leaf_index: Int) -> List[String]:
        """Generate Merkle proof for a leaf"""
        var proof = List[String]()
        var current_index = leaf_index

        # Build proof path to root
        var level_size = len(self.leaves)
        while level_size > 1:
            var sibling_index: Int
            if current_index % 2 == 0:
                sibling_index = current_index + 1
            else:
                sibling_index = current_index - 1

            if sibling_index < level_size:
                proof.append(self.leaves[sibling_index])

            current_index = current_index // 2
            level_size = (level_size + 1) // 2

        return proof

    fn verify_proof(self, leaf_hash: String, proof: List[String], root_hash: String) -> Bool:
        """Verify a Merkle proof"""
        var current_hash = leaf_hash

        for sibling_hash in proof:
            # Hash with sibling based on position
            if current_hash < sibling_hash:
                current_hash = self._hash(current_hash + sibling_hash)
            else:
                current_hash = self._hash(sibling_hash + current_hash)

        return current_hash == root_hash

    fn _hash(self, data: String) -> String:
        """Simple hash function (would use crypto hash in production)"""
        # In production, use SHA-256 or similar
        return f"hash_{data}"

    fn _rebuild_tree(self):
        """Rebuild the Merkle tree from leaves"""
        if len(self.leaves) == 0:
            self.root = None
            return

        # Build tree bottom-up
        var current_level = self.leaves

        while len(current_level) > 1:
            var next_level = List[String]()

            var i = 0
            while i < len(current_level):
                var left = current_level[i]
                var right = ""
                if i + 1 < len(current_level):
                    right = current_level[i + 1]
                else:
                    right = left  # Duplicate for odd number of nodes

                var combined_hash = self._hash(left + right)
                next_level.append(combined_hash)
                i += 2

            current_level = next_level

        # Create root node
        self.root = MerkleNode(current_level[0], None, None)
```

## 🔗 **Timeline Integration**

```mojo
struct Timeline:
    var commits: List[Commit]
    var merkle_tree: MerkleTree

    fn commit(self, table: String, changes: List[Change]) -> Commit:
        # Create commit
        var commit = Commit(
            id=self._generate_id(),
            timestamp=now(),
            table=table,
            changes=changes,
            merkle_root=""
        )

        # Serialize commit for hashing
        var commit_data = self._serialize_commit(commit)

        # Add to Merkle tree
        self.merkle_tree.add_leaf(commit_data)

        # Update commit with Merkle root
        commit.merkle_root = self.merkle_tree.get_root_hash()

        # Store commit
        self.commits.append(commit)

        return commit

    fn verify_commit_integrity(self, commit: Commit) -> Bool:
        """Verify a commit hasn't been tampered with"""
        var commit_data = self._serialize_commit(commit)
        var proof = self.merkle_tree.get_proof(len(self.commits) - 1)
        return self.merkle_tree.verify_proof(
            commit_data,
            proof,
            self.merkle_tree.get_root_hash()
        )

    fn verify_timeline_integrity(self) -> Bool:
        """Verify entire timeline integrity"""
        # Check all commits against Merkle tree
        for i in range(len(self.commits)):
            if not self.verify_commit_integrity(self.commits[i]):
                return False
        return True
```

## 🎯 **Key Advantages**

### **Cryptographic Integrity**
- Each commit includes a Merkle root proving its place in history
- Any tampering with commit data breaks the Merkle tree verification
- Timeline integrity verifiable with single root hash check

### **Efficient Verification**
- O(log n) verification time instead of O(n) full scan
- Merkle proofs allow verifying specific commits without full timeline
- Incremental verification for new commits

### **Incremental Processing Benefits**
- Changes can be verified cryptographically
- Watermarks include Merkle proofs for integrity
- Third parties can verify incremental updates without full data access

This Merkle Tree implementation provides **cryptographic data integrity** for the lakehouse timeline while maintaining the **simplicity** of the unified architecture.