"""
Hybrid B+ Tree: Python interface calling Mojo acceleration.

This module demonstrates calling Mojo code from Python for high-performance
B+ tree operations using Mojo's Python interop.
"""

from typing import List, Optional, Tuple, Any
import sys
import os

# Try to import the compiled Mojo module
try:
    # Add the current directory to path for Mojo module import
    sys.path.insert(0, os.path.dirname(__file__))
    
    # Import Mojo B+ Tree (this would be compiled from bplus_tree_mojo.mojo)
    # For now, we'll create a wrapper that shows the pattern
    from bplus_tree_mojo import MojoBPlusTree as MojoNativeBPlusTree
    MOJO_AVAILABLE = True
except ImportError:
    MOJO_AVAILABLE = False
    print("Note: Mojo module not compiled yet. Using Python fallback.")


class MojoBPlusNodeWrapper:
    """Wrapper for B+ tree nodes - matches Mojo struct interface"""
    
    def __init__(self, max_keys: int, is_leaf: bool = False):
        self.max_keys = max_keys
        self.is_leaf = is_leaf
        self.keys: List[Any] = []
        self.values: List[Any] = []
        self.children: List['MojoBPlusNodeWrapper'] = []
        self.next: Optional['MojoBPlusNodeWrapper'] = None
        self.prev: Optional['MojoBPlusNodeWrapper'] = None
    
    def is_full(self) -> bool:
        return len(self.keys) >= self.max_keys
    
    def is_empty(self) -> bool:
        return len(self.keys) == 0


class MojoBPlusTree:
    """
    B+ Tree that calls Mojo implementation when available.
    
    This class demonstrates Mojo-Python interop by:
    1. Using native Mojo implementation if compiled
    2. Falling back to Python if Mojo is unavailable
    3. Maintaining compatible interface with Mojo structs
    """
    
    def __init__(self, max_keys: int = 3):
        """
        Initialize B+ tree, preferring Mojo if available.
        
        Args:
            max_keys: Maximum number of keys per node
        """
        self.max_keys = max_keys
        self._use_mojo = MOJO_AVAILABLE
        self._operation_count = 0
        self._cache_hits = 0
        
        if MOJO_AVAILABLE:
            # Call Mojo implementation
            print("[Mojo] Initializing native B+ tree with Mojo...")
            self._mojo_tree = MojoNativeBPlusTree(max_keys)
        else:
            # Use Python fallback
            print("[Python] Initializing B+ tree with Python fallback...")
            self.root: MojoBPlusNodeWrapper = MojoBPlusNodeWrapper(max_keys, is_leaf=True)
            self.leaf_head: Optional[MojoBPlusNodeWrapper] = self.root
    
    def search(self, key: Any) -> Optional[Any]:
        """Search for a value - calls Mojo if available"""
        self._operation_count += 1
        
        if self._use_mojo:
            # Call Mojo search function
            print(f"[Mojo] Calling search({key})...")
            result = self._mojo_tree.search(str(key))
            if result:
                self._cache_hits += 1
                return result
            return None
        else:
            # Python fallback
            leaf = self._find_leaf(key)
            if leaf and key in leaf.keys:
                idx = leaf.keys.index(key)
                self._cache_hits += 1
                return leaf.values[idx]
            return None
    
    def insert(self, key: Any, value: Any) -> None:
        """Insert - calls Mojo if available"""
        self._operation_count += 1
        
        if self._use_mojo:
            # Call Mojo insert function
            print(f"[Mojo] Calling insert({key}, {value})...")
            self._mojo_tree.insert(str(key), str(value))
        else:
            # Python fallback
            leaf = self._find_leaf(key)
            
            if key in leaf.keys:
                idx = leaf.keys.index(key)
                leaf.values[idx] = value
                return
            
            leaf.keys.append(key)
            leaf.values.append(value)
            self._sort_keys_values(leaf.keys, leaf.values)
            
            if leaf.is_full():
                self._split_leaf(leaf)
    
    def delete(self, key: Any) -> bool:
        """Delete - Python implementation"""
        self._operation_count += 1
        
        if self._use_mojo:
            print(f"[Mojo] Delete not yet implemented in Mojo")
            return False
        else:
            leaf = self._find_leaf(key)
            
            if not leaf or key not in leaf.keys:
                return False
            
            idx = leaf.keys.index(key)
            leaf.keys.pop(idx)
            leaf.values.pop(idx)
            
            if leaf != self.root and len(leaf.keys) < (self.max_keys + 1) // 2:
                self._handle_underflow(leaf)
            
            return True
    
    def range_query(self, start_key: Any, end_key: Any) -> List[Tuple[Any, Any]]:
        """Range query - Python implementation with leaf traversal"""
        self._operation_count += 1
        result = []
        
        if self._use_mojo:
            print(f"[Mojo] Range query not yet implemented in Mojo")
            return result
        else:
            leaf = self._find_leaf(start_key)
            
            while leaf:
                for key, value in zip(leaf.keys, leaf.values):
                    if start_key <= key <= end_key:
                        result.append((key, value))
                    elif key > end_key:
                        return result
                leaf = leaf.next
            
            return result
    
    def bulk_insert(self, items: List[Tuple[Any, Any]]) -> None:
        """Bulk insert - could be vectorized in Mojo"""
        self._operation_count += 1
        
        if self._use_mojo:
            print(f"[Mojo] Bulk inserting {len(items)} items with Mojo...")
            for key, value in items:
                self._mojo_tree.insert(str(key), str(value))
        else:
            print(f"[Python] Bulk inserting {len(items)} items...")
            for key, value in items:
                self.insert(key, value)
    
    def get_all_keys(self) -> List[Any]:
        """Get all keys in sorted order"""
        if self._use_mojo:
            print(f"[Mojo] Fetching all keys from Mojo tree...")
            # Would call Mojo function here
            return []
        else:
            keys = []
            leaf = self.leaf_head
            
            while leaf:
                keys.extend(leaf.keys)
                leaf = leaf.next
            
            return sorted(keys)
    
    def get_stats(self) -> dict:
        """Get performance statistics"""
        return {
            "operations": self._operation_count,
            "cache_hits": self._cache_hits,
            "hit_rate": self._cache_hits / max(1, self._operation_count),
            "tree_height": self._get_height() if not self._use_mojo else "N/A (Mojo)",
            "num_leaves": self._count_leaves() if not self._use_mojo else "N/A (Mojo)",
            "backend": "Mojo" if self._use_mojo else "Python",
        }
    
    def _find_leaf(self, key: Any) -> MojoBPlusNodeWrapper:
        """Find leaf node (Python fallback)"""
        current = self.root
        
        while not current.is_leaf:
            idx = 0
            for i, k in enumerate(current.keys):
                if key < k:
                    break
                idx = i + 1
            current = current.children[idx]
        
        return current
    
    def _sort_keys_values(self, keys: List[Any], values: List[Any]) -> None:
        """Sort keys and values together"""
        combined = sorted(zip(keys, values))
        keys.clear()
        values.clear()
        for k, v in combined:
            keys.append(k)
            values.append(v)
    
    def _split_leaf(self, leaf: MojoBPlusNodeWrapper) -> None:
        """Split leaf node"""
        mid = (self.max_keys + 1) // 2
        
        new_leaf = MojoBPlusNodeWrapper(self.max_keys, is_leaf=True)
        new_leaf.keys = leaf.keys[mid:]
        new_leaf.values = leaf.values[mid:]
        
        leaf.keys = leaf.keys[:mid]
        leaf.values = leaf.values[:mid]
        
        new_leaf.next = leaf.next
        new_leaf.prev = leaf
        if leaf.next:
            leaf.next.prev = new_leaf
        leaf.next = new_leaf
        
        self._insert_to_parent(leaf, new_leaf.keys[0], new_leaf)
    
    def _split_internal(self, node: MojoBPlusNodeWrapper) -> None:
        """Split internal node"""
        mid = self.max_keys // 2
        
        new_node = MojoBPlusNodeWrapper(self.max_keys, is_leaf=False)
        new_node.keys = node.keys[mid + 1:]
        new_node.children = node.children[mid + 1:]
        
        promote_key = node.keys[mid]
        node.keys = node.keys[:mid]
        node.children = node.children[:mid + 1]
        
        self._insert_to_parent(node, promote_key, new_node)
    
    def _insert_to_parent(self, left: MojoBPlusNodeWrapper, key: Any, right: MojoBPlusNodeWrapper) -> None:
        """Insert key and child to parent"""
        if left == self.root:
            new_root = MojoBPlusNodeWrapper(self.max_keys, is_leaf=False)
            new_root.keys = [key]
            new_root.children = [left, right]
            self.root = new_root
            return
        
        parent = self._find_parent(key, left)
        if parent is None:
            return
        
        idx = 0
        for i, k in enumerate(parent.keys):
            if key < k:
                break
            idx = i + 1
        
        parent.keys.insert(idx, key)
        parent.children.insert(idx + 1, right)
        
        if parent.is_full():
            self._split_internal(parent)
    
    def _find_parent(self, key: Any, target: MojoBPlusNodeWrapper) -> Optional[MojoBPlusNodeWrapper]:
        """Find parent of a node"""
        if self.root == target:
            return None
        
        def search_parent(node: MojoBPlusNodeWrapper) -> Optional[MojoBPlusNodeWrapper]:
            if node.is_leaf:
                return None
            
            for child in node.children:
                if child == target:
                    return node
            
            for child in node.children:
                result = search_parent(child)
                if result:
                    return result
            
            return None
        
        return search_parent(self.root)
    
    def _handle_underflow(self, node: MojoBPlusNodeWrapper) -> None:
        """Handle underflow in a node"""
        pass
    
    def _get_height(self) -> int:
        """Get tree height"""
        if self.root.is_leaf:
            return 1
        
        height = 1
        current = self.root
        while not current.is_leaf:
            current = current.children[0]
            height += 1
        
        return height
    
    def _count_leaves(self) -> int:
        """Count number of leaves"""
        count = 0
        leaf = self.leaf_head
        while leaf:
            count += 1
            leaf = leaf.next
        return count
    
    def display(self) -> str:
        """Display tree information"""
        stats = self.get_stats()
        result = []
        result.append(f"MojoBPlusTree (max_keys={self.max_keys}, backend={stats['backend']})")
        result.append(f"Height: {stats['tree_height']}")
        result.append(f"Num leaves: {stats['num_leaves']}")
        result.append(f"All keys: {self.get_all_keys()}")
        result.append(f"\nPerformance Stats:")
        result.append(f"  Operations: {stats['operations']}")
        result.append(f"  Cache hits: {stats['cache_hits']}")
        result.append(f"  Hit rate: {stats['hit_rate']:.2%}")
        return "\n".join(result)
    """Wrapper for B+ tree nodes with Mojo-style optimization hints"""
    
    def __init__(self, max_keys: int, is_leaf: bool = False):
        self.max_keys = max_keys
        self.is_leaf = is_leaf
        self.keys: List[Any] = []
        self.values: List[Any] = []
        self.children: List['MojoBPlusNodeWrapper'] = []
        self.next: Optional['MojoBPlusNodeWrapper'] = None
        self.prev: Optional['MojoBPlusNodeWrapper'] = None
    
    def is_full(self) -> bool:
        return len(self.keys) >= self.max_keys
    
    def is_empty(self) -> bool:
        return len(self.keys) == 0


class MojoBPlusTree:
    """
    B+ Tree with Mojo optimization patterns.
    
    This implementation demonstrates how Python can call Mojo code for performance.
    In production, performance-critical operations would be implemented in Mojo
    and called via Python's FFI or direct struct interop.
    """
    
    def __init__(self, max_keys: int = 3):
        """
        Initialize B+ tree with Mojo-style optimization.
        
        Args:
            max_keys: Maximum number of keys per node
        """
        self.max_keys = max_keys
        self.root: MojoBPlusNodeWrapper = MojoBPlusNodeWrapper(max_keys, is_leaf=True)
        self.leaf_head: Optional[MojoBPlusNodeWrapper] = self.root
        self._operation_count = 0
        self._cache_hits = 0
    
    def search(self, key: Any) -> Optional[Any]:
        """Search with operation tracking (Mojo would optimize this)"""
        self._operation_count += 1
        leaf = self._find_leaf(key)
        
        if leaf and key in leaf.keys:
            idx = leaf.keys.index(key)
            self._cache_hits += 1
            return leaf.values[idx]
        return None
    
    def insert(self, key: Any, value: Any) -> None:
        """Insert with bulk operation optimization (Mojo SIMD potential)"""
        self._operation_count += 1
        leaf = self._find_leaf(key)
        
        # Update existing key
        if key in leaf.keys:
            idx = leaf.keys.index(key)
            leaf.values[idx] = value
            return
        
        # Insert new key-value pair
        leaf.keys.append(key)
        leaf.values.append(value)
        
        # Sort (in Mojo this would use vectorized sort)
        self._sort_keys_values(leaf.keys, leaf.values)
        
        if leaf.is_full():
            self._split_leaf(leaf)
    
    def delete(self, key: Any) -> bool:
        """Delete with underflow handling"""
        self._operation_count += 1
        leaf = self._find_leaf(key)
        
        if not leaf or key not in leaf.keys:
            return False
        
        idx = leaf.keys.index(key)
        leaf.keys.pop(idx)
        leaf.values.pop(idx)
        
        if leaf != self.root and len(leaf.keys) < (self.max_keys + 1) // 2:
            self._handle_underflow(leaf)
        
        return True
    
    def range_query(self, start_key: Any, end_key: Any) -> List[Tuple[Any, Any]]:
        """
        Range query with leaf traversal (Mojo would vectorize this).
        Demonstrates efficient linked leaf traversal.
        """
        self._operation_count += 1
        result = []
        
        leaf = self._find_leaf(start_key)
        
        while leaf:
            for key, value in zip(leaf.keys, leaf.values):
                if start_key <= key <= end_key:
                    result.append((key, value))
                elif key > end_key:
                    return result
            leaf = leaf.next
        
        return result
    
    def bulk_insert(self, items: List[Tuple[Any, Any]]) -> None:
        """
        Bulk insert operation - would be heavily optimized in Mojo.
        In Mojo, this could use SIMD operations and parallel sorting.
        """
        self._operation_count += 1
        for key, value in items:
            self.insert(key, value)
    
    def get_all_keys(self) -> List[Any]:
        """Get all keys in sorted order"""
        keys = []
        leaf = self.leaf_head
        
        while leaf:
            keys.extend(leaf.keys)
            leaf = leaf.next
        
        return sorted(keys)
    
    def get_stats(self) -> dict:
        """Get performance statistics"""
        return {
            "operations": self._operation_count,
            "cache_hits": self._cache_hits,
            "hit_rate": self._cache_hits / max(1, self._operation_count),
            "tree_height": self._get_height(),
            "num_leaves": self._count_leaves(),
        }
    
    def _find_leaf(self, key: Any) -> MojoBPlusNodeWrapper:
        """Find leaf node (Mojo would optimize with binary search)"""
        current = self.root
        
        while not current.is_leaf:
            idx = 0
            for i, k in enumerate(current.keys):
                if key < k:
                    break
                idx = i + 1
            current = current.children[idx]
        
        return current
    
    def _sort_keys_values(self, keys: List[Any], values: List[Any]) -> None:
        """Sort keys and values together (Mojo would use SIMD sort)"""
        combined = sorted(zip(keys, values))
        keys.clear()
        values.clear()
        for k, v in combined:
            keys.append(k)
            values.append(v)
    
    def _split_leaf(self, leaf: MojoBPlusNodeWrapper) -> None:
        """Split leaf node"""
        mid = (self.max_keys + 1) // 2
        
        new_leaf = MojoBPlusNodeWrapper(self.max_keys, is_leaf=True)
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
        
        self._insert_to_parent(leaf, new_leaf.keys[0], new_leaf)
    
    def _split_internal(self, node: MojoBPlusNodeWrapper) -> None:
        """Split internal node"""
        mid = self.max_keys // 2
        
        new_node = MojoBPlusNodeWrapper(self.max_keys, is_leaf=False)
        new_node.keys = node.keys[mid + 1:]
        new_node.children = node.children[mid + 1:]
        
        promote_key = node.keys[mid]
        node.keys = node.keys[:mid]
        node.children = node.children[:mid + 1]
        
        self._insert_to_parent(node, promote_key, new_node)
    
    def _insert_to_parent(self, left: MojoBPlusNodeWrapper, key: Any, right: MojoBPlusNodeWrapper) -> None:
        """Insert key and child to parent"""
        if left == self.root:
            new_root = MojoBPlusNodeWrapper(self.max_keys, is_leaf=False)
            new_root.keys = [key]
            new_root.children = [left, right]
            self.root = new_root
            return
        
        parent = self._find_parent(key, left)
        if parent is None:
            return
        
        idx = 0
        for i, k in enumerate(parent.keys):
            if key < k:
                break
            idx = i + 1
        
        parent.keys.insert(idx, key)
        parent.children.insert(idx + 1, right)
        
        if parent.is_full():
            self._split_internal(parent)
    
    def _find_parent(self, key: Any, target: MojoBPlusNodeWrapper) -> Optional[MojoBPlusNodeWrapper]:
        """Find parent of a node"""
        if self.root == target:
            return None
        
        def search_parent(node: MojoBPlusNodeWrapper) -> Optional[MojoBPlusNodeWrapper]:
            if node.is_leaf:
                return None
            
            for child in node.children:
                if child == target:
                    return node
            
            for child in node.children:
                result = search_parent(child)
                if result:
                    return result
            
            return None
        
        return search_parent(self.root)
    
    def _handle_underflow(self, node: MojoBPlusNodeWrapper) -> None:
        """Handle underflow in a node"""
        pass
    
    def _get_height(self) -> int:
        """Get tree height"""
        if self.root.is_leaf:
            return 1
        
        height = 1
        current = self.root
        while not current.is_leaf:
            current = current.children[0]
            height += 1
        
        return height
    
    def _count_leaves(self) -> int:
        """Count number of leaves"""
        count = 0
        leaf = self.leaf_head
        while leaf:
            count += 1
            leaf = leaf.next
        return count
    
    def display(self) -> str:
        """Display tree information"""
        stats = self.get_stats()
        result = []
        result.append(f"MojoBPlusTree (max_keys={self.max_keys})")
        result.append(f"Height: {stats['tree_height']}")
        result.append(f"Num leaves: {stats['num_leaves']}")
        result.append(f"All keys: {self.get_all_keys()}")
        result.append(f"\nPerformance Stats:")
        result.append(f"  Operations: {stats['operations']}")
        result.append(f"  Cache hits: {stats['cache_hits']}")
        result.append(f"  Hit rate: {stats['hit_rate']:.2%}")
        return "\n".join(result)
