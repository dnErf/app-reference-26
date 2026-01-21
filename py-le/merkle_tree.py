"""Merkle Tree implementation in Python"""

import hashlib
from typing import List, Optional, Tuple


class MerkleNode:
    """Node in a Merkle tree"""
    
    def __init__(self, hash_value: str, data: Optional[str] = None, left: Optional['MerkleNode'] = None, right: Optional['MerkleNode'] = None):
        self.hash = hash_value
        self.data = data
        self.left = left
        self.right = right
        self.is_leaf = data is not None
    
    def __repr__(self) -> str:
        return f"MerkleNode(hash={self.hash[:8]}..., is_leaf={self.is_leaf})"


class MerkleTree:
    """Binary Merkle Tree implementation"""
    
    def __init__(self, data_blocks: Optional[List[str]] = None, hash_func: str = "sha256"):
        """
        Initialize Merkle tree
        
        Args:
            data_blocks: List of data strings to hash
            hash_func: Hash function to use ('sha256', 'sha1', 'md5')
        """
        self.hash_func = hash_func
        self.root: Optional[MerkleNode] = None
        self.leaves: List[MerkleNode] = []
        self.tree_nodes: List[MerkleNode] = []
        
        if data_blocks:
            self.build(data_blocks)
    
    @staticmethod
    def _hash(data: str, hash_func: str = "sha256") -> str:
        """Compute hash of data"""
        if hash_func == "sha256":
            return hashlib.sha256(data.encode()).hexdigest()
        elif hash_func == "sha1":
            return hashlib.sha1(data.encode()).hexdigest()
        elif hash_func == "md5":
            return hashlib.md5(data.encode()).hexdigest()
        else:
            raise ValueError(f"Unknown hash function: {hash_func}")
    
    def build(self, data_blocks: List[str]) -> None:
        """Build Merkle tree from data blocks"""
        if not data_blocks:
            raise ValueError("Data blocks cannot be empty")
        
        # Create leaf nodes
        self.leaves = []
        for data in data_blocks:
            hash_value = self._hash(data, self.hash_func)
            leaf = MerkleNode(hash_value, data=data)
            self.leaves.append(leaf)
            self.tree_nodes.append(leaf)
        
        # Build tree bottom-up
        current_level = self.leaves[:]
        
        while len(current_level) > 1:
            next_level = []
            
            # Process pairs
            for i in range(0, len(current_level), 2):
                left = current_level[i]
                right = current_level[i + 1] if i + 1 < len(current_level) else left
                
                # Combine hashes
                combined = left.hash + right.hash
                parent_hash = self._hash(combined, self.hash_func)
                parent = MerkleNode(parent_hash, left=left, right=right)
                
                next_level.append(parent)
                self.tree_nodes.append(parent)
            
            current_level = next_level
        
        # Set root
        self.root = current_level[0] if current_level else None
    
    def get_root_hash(self) -> str:
        """Get the root hash of the tree"""
        if not self.root:
            raise RuntimeError("Tree is not built")
        return self.root.hash
    
    def get_proof(self, leaf_index: int) -> List[Tuple[str, str]]:
        """
        Get Merkle proof for a leaf node
        Returns list of (sibling_hash, position) tuples where position is 'left' or 'right'
        """
        if leaf_index >= len(self.leaves):
            raise IndexError(f"Leaf index {leaf_index} out of range")
        
        proof = []
        current = self.leaves[leaf_index]
        
        # Find path from leaf to root
        def find_proof_path(node: MerkleNode, target: MerkleNode, path: List[MerkleNode]) -> bool:
            if node is target:
                return True
            
            if node.left is None:
                return False
            
            if find_proof_path(node.left, target, path):
                # Add right sibling
                if node.right:
                    proof.append((node.right.hash, "left"))
                return True
            
            if node.right and find_proof_path(node.right, target, path):
                # Add left sibling
                proof.append((node.left.hash, "right"))
                return True
            
            return False
        
        find_proof_path(self.root, current, [])
        return proof
    
    def verify_leaf(self, leaf_index: int, data: str, proof: List[Tuple[str, str]]) -> bool:
        """
        Verify a leaf using Merkle proof
        
        Args:
            leaf_index: Index of the leaf
            data: Data that should hash to leaf
            proof: Merkle proof (list of sibling hashes)
        
        Returns:
            True if leaf is valid
        """
        # Compute leaf hash
        current_hash = self._hash(data, self.hash_func)
        
        # Traverse proof path
        for sibling_hash, position in proof:
            if position == "left":
                current_hash = self._hash(current_hash + sibling_hash, self.hash_func)
            else:
                current_hash = self._hash(sibling_hash + current_hash, self.hash_func)
        
        return current_hash == self.get_root_hash()
    
    def get_height(self) -> int:
        """Get height of the tree"""
        if not self.root:
            return 0
        
        def height(node: Optional[MerkleNode]) -> int:
            if node is None or node.is_leaf:
                return 1
            return 1 + max(height(node.left), height(node.right))
        
        return height(self.root)
    
    def display(self) -> str:
        """Display tree structure"""
        result = []
        result.append(f"Merkle Tree (hash={self.hash_func})")
        result.append(f"Number of leaves: {len(self.leaves)}")
        result.append(f"Height: {self.get_height()}")
        result.append(f"Root hash: {self.get_root_hash()}")
        
        result.append("\nLeaves:")
        for i, leaf in enumerate(self.leaves):
            result.append(f"  [{i}] {leaf.data} -> {leaf.hash[:16]}...")
        
        return "\n".join(result)
    
    def visualize_tree(self, node: Optional[MerkleNode] = None, prefix: str = "", is_tail: bool = True) -> str:
        """Visualize tree structure"""
        if node is None:
            node = self.root
            if not node:
                return "Empty tree"
        
        result = []
        
        # Add current node
        connector = "└── " if is_tail else "├── "
        label = f"{node.data} [{node.hash[:8]}...]" if node.is_leaf else f"[{node.hash[:8]}...]"
        result.append(prefix + connector + label)
        
        # Add children
        if node.left or node.right:
            extension = "    " if is_tail else "│   "
            
            if node.left:
                child_result = self.visualize_tree(node.left, prefix + extension, node.right is None)
                result.append(child_result)
            
            if node.right:
                child_result = self.visualize_tree(node.right, prefix + extension, True)
                result.append(child_result)
        
        return "\n".join(result)
