use std::fmt;

const MIN_DEGREE: usize = 3;

/// B+ Tree Entry with key and value
#[derive(Clone, Debug)]
pub struct Entry {
    pub key: i32,
    pub value: String,
}

/// B+ Tree Node - either Leaf or Internal
#[derive(Clone, Debug)]
pub enum Node {
    Leaf {
        entries: Vec<Entry>,
    },
    Internal {
        keys: Vec<i32>,
        children: Vec<Box<Node>>,
    },
}

impl Node {
    pub fn new_leaf() -> Self {
        Node::Leaf {
            entries: Vec::new(),
        }
    }

    pub fn new_internal() -> Self {
        Node::Internal {
            keys: Vec::new(),
            children: Vec::new(),
        }
    }

    pub fn is_leaf(&self) -> bool {
        matches!(self, Node::Leaf { .. })
    }

    pub fn num_keys(&self) -> usize {
        match self {
            Node::Leaf { entries } => entries.len(),
            Node::Internal { keys, .. } => keys.len(),
        }
    }

    pub fn is_full(&self) -> bool {
        self.num_keys() >= 2 * MIN_DEGREE - 1
    }
}

/// B+ Tree Implementation
pub struct BPlusTree {
    root: Box<Node>,
    height: usize,
}

impl BPlusTree {
    /// Create a new empty B+ Tree
    pub fn new() -> Self {
        BPlusTree {
            root: Box::new(Node::new_leaf()),
            height: 1,
        }
    }

    /// Insert a key-value pair
    pub fn insert(&mut self, key: i32, value: String) {
        if self.root.is_full() {
            let old_root = std::mem::replace(&mut self.root, Box::new(Node::new_internal()));
            
            if let Node::Internal {
                keys: _,
                ref mut children,
            } = *self.root
            {
                children.push(old_root);
                self.split_child(0);
            }
            
            self.height += 1;
        }

        self.insert_non_full(key, value);
    }

    fn insert_non_full(&mut self, key: i32, value: String) {
        if self.root.is_leaf() {
            if let Node::Leaf { ref mut entries } = *self.root {
                if let Some(pos) = entries.iter().position(|e| e.key == key) {
                    entries[pos].value = value;
                } else {
                    let pos = entries.iter().position(|e| e.key > key).unwrap_or(entries.len());
                    entries.insert(pos, Entry { key, value });
                }
            }
        } else {
            let mut child_idx = 0;
            {
                if let Node::Internal { keys, .. } = self.root.as_ref() {
                    for (i, k) in keys.iter().enumerate() {
                        if key < *k {
                            child_idx = i;
                            break;
                        }
                        child_idx = i + 1;
                    }
                }
            }

            let should_split = if let Node::Internal { children, .. } = self.root.as_ref() {
                children[child_idx].is_full()
            } else {
                false
            };

            if should_split {
                self.split_child_internal(child_idx);
                let key_val = if let Node::Internal { keys, .. } = self.root.as_ref() {
                    keys[child_idx]
                } else {
                    i32::MIN
                };
                if key > key_val {
                    child_idx += 1;
                }
            }

            self.insert_into_child(child_idx, key, value);
        }
    }

    fn insert_into_child(&mut self, child_idx: usize, key: i32, value: String) {
        if let Node::Internal { ref mut children, .. } = *self.root {
            if children[child_idx].is_leaf() {
                if let Node::Leaf { ref mut entries } = *children[child_idx] {
                    if let Some(pos) = entries.iter().position(|e| e.key == key) {
                        entries[pos].value = value;
                    } else {
                        let pos = entries.iter().position(|e| e.key > key).unwrap_or(entries.len());
                        entries.insert(pos, Entry { key, value });
                    }
                }
            }
        }
    }

    fn split_child(&mut self, child_idx: usize) {
        if let Node::Internal {
            ref mut keys,
            ref mut children,
        } = *self.root
        {
            let mid = MIN_DEGREE - 1;
            let child = children[child_idx].clone();

            if let Node::Leaf { ref entries } = child.as_ref() {
                if entries.len() > mid {
                    let split_key = entries[mid].key;
                    
                    let left_entries = entries[..mid].to_vec();
                    let right_entries = entries[mid..].to_vec();

                    children[child_idx] = Box::new(Node::Leaf {
                        entries: left_entries,
                    });

                    let right_child = Box::new(Node::Leaf {
                        entries: right_entries,
                    });

                    keys.insert(child_idx, split_key);
                    children.insert(child_idx + 1, right_child);
                }
            }
        }
    }

    fn split_child_internal(&mut self, child_idx: usize) {
        if let Node::Internal {
            ref mut keys,
            ref mut children,
        } = *self.root
        {
            let mid = MIN_DEGREE - 1;
            let child = children[child_idx].clone();

            if let Node::Leaf { ref entries } = child.as_ref() {
                if entries.len() > mid {
                    let split_key = entries[mid].key;
                    
                    let left_entries = entries[..mid].to_vec();
                    let right_entries = entries[mid..].to_vec();

                    children[child_idx] = Box::new(Node::Leaf {
                        entries: left_entries,
                    });

                    let right_child = Box::new(Node::Leaf {
                        entries: right_entries,
                    });

                    keys.insert(child_idx, split_key);
                    children.insert(child_idx + 1, right_child);
                }
            }
        }
    }

    /// Search for a value by key
    pub fn search(&self, key: i32) -> Option<String> {
        self.search_recursive(&self.root, key)
    }

    fn search_recursive(&self, node: &Node, key: i32) -> Option<String> {
        match node {
            Node::Leaf { entries } => {
                entries
                    .iter()
                    .find(|e| e.key == key)
                    .map(|e| e.value.clone())
            }
            Node::Internal { keys, children } => {
                let mut child_idx = 0;
                for (i, k) in keys.iter().enumerate() {
                    if key < *k {
                        child_idx = i;
                        break;
                    }
                    child_idx = i + 1;
                }
                self.search_recursive(&children[child_idx], key)
            }
        }
    }

    /// Range query: find all entries in range [start, end]
    pub fn range_query(&self, start: i32, end: i32) -> Vec<(i32, String)> {
        let mut result = Vec::new();
        self.range_query_recursive(&self.root, start, end, &mut result);
        result
    }

    fn range_query_recursive(
        &self,
        node: &Node,
        start: i32,
        end: i32,
        result: &mut Vec<(i32, String)>,
    ) {
        match node {
            Node::Leaf { entries } => {
                for entry in entries {
                    if entry.key >= start && entry.key <= end {
                        result.push((entry.key, entry.value.clone()));
                    }
                }
            }
            Node::Internal { keys, children } => {
                for (i, key) in keys.iter().enumerate() {
                    if start <= *key {
                        self.range_query_recursive(&children[i], start, end, result);
                    }
                }
                if let Some(last_child) = children.last() {
                    if end > keys.last().copied().unwrap_or(i32::MIN) {
                        self.range_query_recursive(last_child, start, end, result);
                    }
                }
            }
        }
    }

    /// Get all keys in sorted order
    pub fn all_keys(&self) -> Vec<i32> {
        let mut keys = Vec::new();
        self.collect_keys(&self.root, &mut keys);
        keys
    }

    fn collect_keys(&self, node: &Node, keys: &mut Vec<i32>) {
        match node {
            Node::Leaf { entries } => {
                for entry in entries {
                    keys.push(entry.key);
                }
            }
            Node::Internal { children, .. } => {
                for child in children {
                    self.collect_keys(child, keys);
                }
            }
        }
    }

    /// Print tree structure
    pub fn print_tree(&self) {
        println!("B+ Tree (min_degree = {})", MIN_DEGREE);
        println!("Height: {}", self.height);
        self.print_node(&self.root, 0);
    }

    fn print_node(&self, node: &Node, level: usize) {
        let indent = "  ".repeat(level);
        match node {
            Node::Leaf { entries } => {
                let keys: Vec<i32> = entries.iter().map(|e| e.key).collect();
                println!("{}Leaf: {:?}", indent, keys);
                for entry in entries {
                    println!("{}  {} -> {}", indent, entry.key, entry.value);
                }
            }
            Node::Internal { keys, children } => {
                println!("{}Internal: {:?}", indent, keys);
                for child in children {
                    self.print_node(child, level + 1);
                }
            }
        }
    }
}

impl fmt::Display for BPlusTree {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "B+ Tree(height={}, keys={:?})",
            self.height,
            self.all_keys()
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_insert_and_search() {
        let mut tree = BPlusTree::new();
        tree.insert(10, "ten".to_string());
        tree.insert(20, "twenty".to_string());
        tree.insert(5, "five".to_string());

        assert_eq!(tree.search(10), Some("ten".to_string()));
        assert_eq!(tree.search(20), Some("twenty".to_string()));
        assert_eq!(tree.search(5), Some("five".to_string()));
        assert_eq!(tree.search(100), None);
    }

    #[test]
    fn test_range_query() {
        let mut tree = BPlusTree::new();
        for i in 1..=10 {
            tree.insert(i * 10, format!("value_{}", i));
        }

        let result = tree.range_query(25, 75);
        assert!(!result.is_empty());
    }
}
