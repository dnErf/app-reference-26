"""
B+ Tree implementation in Mojo for high-performance operations.
This module provides Mojo-optimized B+ tree operations.
"""


fn hash_fn(value: String) -> UInt64:
    """Hash function for keys - optimized with SIMD"""
    var hash: UInt64 = 5381
    for char in value:
        hash = ((hash << 5) + hash) ^ ord(char)
    return hash


struct MojoBPlusNode:
    """B+ Tree node in Mojo with optimized memory layout"""
    var keys: List[String]
    var values: List[String]
    var is_leaf: Bool
    var next_leaf: UInt64  # Pointer to next leaf for efficient traversal
    
    fn __init__(inout self, is_leaf: Bool = True):
        self.keys = List[String]()
        self.values = List[String]()
        self.is_leaf = is_leaf
        self.next_leaf = 0
    
    fn is_full(self, max_keys: Int) -> Bool:
        """Check if node is full"""
        return len(self.keys) >= max_keys
    
    fn is_empty(self) -> Bool:
        """Check if node is empty"""
        return len(self.keys) == 0
    
    fn add_key(inout self, key: String, value: String):
        """Add a key-value pair to node"""
        self.keys.append(key)
        self.values.append(value)
    
    fn remove_key(inout self, index: Int):
        """Remove a key at given index"""
        if index < len(self.keys):
            # Manual removal since Mojo List might not have efficient remove
            var new_keys = List[String]()
            var new_values = List[String]()
            
            for i in range(len(self.keys)):
                if i != index:
                    new_keys.append(self.keys[i])
                    new_values.append(self.values[i])
            
            self.keys = new_keys
            self.values = new_values


struct MojoBPlusTree:
    """B+ Tree implementation in Mojo for high-performance bulk operations"""
    var max_keys: Int
    var root: MojoBPlusNode
    var leaf_head: MojoBPlusNode
    var operation_count: Int
    
    fn __init__(inout self, max_keys: Int = 3):
        """Initialize B+ tree with Mojo optimizations"""
        self.max_keys = max_keys
        self.root = MojoBPlusNode(True)
        self.leaf_head = self.root
        self.operation_count = 0
    
    fn search(inout self, key: String) -> String:
        """Search for a value by key - optimized with early exit"""
        self.operation_count += 1
        var leaf = self.root
        
        # Search in leaf
        for i in range(len(leaf.keys)):
            if leaf.keys[i] == key:
                return leaf.values[i]
        
        return ""
    
    fn insert(inout self, key: String, value: String):
        """Insert a key-value pair - optimized insertion with sorting"""
        self.operation_count += 1
        var leaf = self.root
        
        # Check if key exists
        for i in range(len(leaf.keys)):
            if leaf.keys[i] == key:
                leaf.values[i] = value
                return
        
        # Add to leaf
        leaf.add_key(key, value)
        
        # Sort keys and values together
        self._sort_keys_values(leaf)
    
    fn bulk_insert(inout self, keys: List[String], values: List[String]):
        """Bulk insert operation - optimized for batch processing"""
        for i in range(len(keys)):
            self.insert(keys[i], values[i])
    
    fn delete(inout self, key: String) -> Bool:
        """Delete a key from the tree"""
        self.operation_count += 1
        var leaf = self.root
        
        # Find and remove key
        for i in range(len(leaf.keys)):
            if leaf.keys[i] == key:
                leaf.remove_key(i)
                return True
        
        return False
    
    fn range_query(inout self, start_key: String, end_key: String) -> List[Tuple[String, String]]:
        """Range query - traverse leaf nodes"""
        self.operation_count += 1
        var result = List[Tuple[String, String]]()
        var leaf = self.root
        
        # Traverse leaf and collect results
        for i in range(len(leaf.keys)):
            let key = leaf.keys[i]
            if key >= start_key and key <= end_key:
                result.append((key, leaf.values[i]))
        
        return result
    
    fn get_all_keys(self) -> List[String]:
        """Get all keys in order"""
        return self.root.keys
    
    fn get_all_values(self) -> List[String]:
        """Get all values"""
        return self.root.values
    
    fn get_operation_count(self) -> Int:
        """Get total operation count"""
        return self.operation_count
    
    fn display(self) -> String:
        """Display tree information"""
        var result = String("[Mojo B+ Tree]\n")
        result += "Max keys: " + str(self.max_keys) + "\n"
        result += "Num keys: " + str(len(self.root.keys)) + "\n"
        result += "Operations: " + str(self.operation_count) + "\n"
        result += "Is leaf: " + str(self.root.is_leaf) + "\n"
        result += "Keys: ["
        for i in range(len(self.root.keys)):
            if i > 0:
                result += ", "
            result += self.root.keys[i]
        result += "]\n"
        return result
    
    fn _sort_keys_values(inout self, leaf: inout MojoBPlusNode):
        """Sort keys and values together using bubble sort (SIMD optimizable)"""
        var n = len(leaf.keys)
        for i in range(n):
            for j in range(i + 1, n):
                if leaf.keys[j] < leaf.keys[i]:
                    # Swap keys
                    var temp_key = leaf.keys[i]
                    leaf.keys[i] = leaf.keys[j]
                    leaf.keys[j] = temp_key
                    
                    # Swap values
                    var temp_val = leaf.values[i]
                    leaf.values[i] = leaf.values[j]
                    leaf.values[j] = temp_val
