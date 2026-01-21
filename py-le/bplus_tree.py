"""B+ Tree implementation in Python"""

from typing import List, Optional, Tuple, Any


class BPlusNode:
    """Base class for B+ tree nodes"""
    
    def __init__(self, max_keys: int, is_leaf: bool = False):
        self.max_keys = max_keys
        self.is_leaf = is_leaf
        self.keys: List[Any] = []
        self.children: List['BPlusNode'] = [] if not is_leaf else []
        self.values: List[Any] = [] if is_leaf else []
        self.next: Optional['BPlusNode'] = None  # For leaf linking
        self.prev: Optional['BPlusNode'] = None  # For leaf linking
    
    def is_full(self) -> bool:
        """Check if node is full"""
        return len(self.keys) >= self.max_keys
    
    def is_empty(self) -> bool:
        """Check if node is empty"""
        return len(self.keys) == 0


class BPlusTree:
    """B+ Tree implementation"""
    
    def __init__(self, max_keys: int = 3):
        """
        Initialize B+ tree
        
        Args:
            max_keys: Maximum number of keys in a node (must be odd)
        """
        self.max_keys = max_keys
        self.root: BPlusNode = BPlusNode(max_keys, is_leaf=True)
        self.leaf_head: Optional[BPlusNode] = self.root
    
    def search(self, key: Any) -> Optional[Any]:
        """Search for a value by key"""
        leaf = self._find_leaf(key)
        if leaf and key in leaf.keys:
            idx = leaf.keys.index(key)
            return leaf.values[idx]
        return None
    
    def insert(self, key: Any, value: Any) -> None:
        """Insert a key-value pair"""
        leaf = self._find_leaf(key)
        
        # If key exists, update value
        if key in leaf.keys:
            idx = leaf.keys.index(key)
            leaf.values[idx] = value
            return
        
        # Insert into leaf
        leaf.keys.append(key)
        leaf.values.append(value)
        leaf.keys.sort()
        
        # Reorder values to match sorted keys
        combined = sorted(zip(leaf.keys, leaf.values))
        leaf.keys = [k for k, v in combined]
        leaf.values = [v for k, v in combined]
        
        # Check if split needed
        if leaf.is_full():
            self._split_leaf(leaf)
    
    def delete(self, key: Any) -> bool:
        """Delete a key from the tree"""
        leaf = self._find_leaf(key)
        
        if not leaf or key not in leaf.keys:
            return False
        
        idx = leaf.keys.index(key)
        leaf.keys.pop(idx)
        leaf.values.pop(idx)
        
        # Handle underflow
        if leaf != self.root and len(leaf.keys) < (self.max_keys + 1) // 2:
            self._handle_underflow(leaf)
        
        return True
    
    def range_query(self, start_key: Any, end_key: Any) -> List[Tuple[Any, Any]]:
        """Get all key-value pairs within range [start_key, end_key]"""
        result = []
        
        # Find starting leaf
        leaf = self._find_leaf(start_key)
        
        # Traverse leaf nodes
        while leaf:
            for key, value in zip(leaf.keys, leaf.values):
                if start_key <= key <= end_key:
                    result.append((key, value))
                elif key > end_key:
                    return result
            leaf = leaf.next
        
        return result
    
    def get_all_keys(self) -> List[Any]:
        """Get all keys in sorted order"""
        keys = []
        leaf = self.leaf_head
        
        while leaf:
            keys.extend(leaf.keys)
            leaf = leaf.next
        
        return sorted(keys)
    
    def _find_leaf(self, key: Any) -> BPlusNode:
        """Find the leaf node where a key should be"""
        current = self.root
        
        while not current.is_leaf:
            idx = 0
            for i, k in enumerate(current.keys):
                if key < k:
                    break
                idx = i + 1
            
            current = current.children[idx]
        
        return current
    
    def _split_leaf(self, leaf: BPlusNode) -> None:
        """Split a full leaf node"""
        mid = (self.max_keys + 1) // 2
        
        # Create new leaf
        new_leaf = BPlusNode(self.max_keys, is_leaf=True)
        new_leaf.keys = leaf.keys[mid:]
        new_leaf.values = leaf.values[mid:]
        
        leaf.keys = leaf.keys[:mid]
        leaf.values = leaf.values[:mid]
        
        # Link leaves
        new_leaf.next = leaf.next
        new_leaf.prev = leaf
        if leaf.next:
            leaf.next.prev = new_leaf
        leaf.next = new_leaf
        
        # Promote key to parent
        self._insert_to_parent(leaf, new_leaf.keys[0], new_leaf)
    
    def _split_internal(self, node: BPlusNode) -> None:
        """Split a full internal node"""
        mid = self.max_keys // 2
        
        # Create new internal node
        new_node = BPlusNode(self.max_keys, is_leaf=False)
        new_node.keys = node.keys[mid + 1:]
        new_node.children = node.children[mid + 1:]
        
        promote_key = node.keys[mid]
        node.keys = node.keys[:mid]
        node.children = node.children[:mid + 1]
        
        self._insert_to_parent(node, promote_key, new_node)
    
    def _insert_to_parent(self, left: BPlusNode, key: Any, right: BPlusNode) -> None:
        """Insert a key and child pointer to parent"""
        if left == self.root:
            # Create new root
            new_root = BPlusNode(self.max_keys, is_leaf=False)
            new_root.keys = [key]
            new_root.children = [left, right]
            self.root = new_root
            return
        
        # Find parent
        parent = self._find_parent(key, left)
        if parent is None:
            return
        
        # Insert into parent
        idx = 0
        for i, k in enumerate(parent.keys):
            if key < k:
                break
            idx = i + 1
        
        parent.keys.insert(idx, key)
        parent.children.insert(idx + 1, right)
        
        # Check if parent is full
        if parent.is_full():
            self._split_internal(parent)
    
    def _find_parent(self, key: Any, target: BPlusNode) -> Optional[BPlusNode]:
        """Find parent of a node"""
        if self.root == target:
            return None
        
        def search_parent(node: BPlusNode, target: BPlusNode) -> Optional[BPlusNode]:
            if node.is_leaf:
                return None
            
            for child in node.children:
                if child == target:
                    return node
            
            for child in node.children:
                result = search_parent(child, target)
                if result:
                    return result
            
            return None
        
        return search_parent(self.root, target)
    
    def _handle_underflow(self, node: BPlusNode) -> None:
        """Handle underflow in a node"""
        # Simplified implementation - just leave underflowed nodes for now
        pass
    
    def display(self) -> str:
        """Display tree structure"""
        result = []
        result.append(f"B+ Tree (max_keys={self.max_keys})")
        result.append(f"Root is {'leaf' if self.root.is_leaf else 'internal'}")
        result.append(f"Height: {self._get_height()}")
        result.append(f"All keys (sorted): {self.get_all_keys()}")
        
        # Display leaf nodes
        result.append("\nLeaf nodes (linked):")
        leaf = self.leaf_head
        while leaf:
            pairs = list(zip(leaf.keys, leaf.values))
            result.append(f"  {pairs}")
            leaf = leaf.next
        
        return "\n".join(result)
    
    def _get_height(self) -> int:
        """Get height of tree"""
        if self.root.is_leaf:
            return 1
        
        height = 1
        current = self.root
        while not current.is_leaf:
            current = current.children[0]
            height += 1
        
        return height
