package main

import (
	"fmt"
	"sort"
	"strings"
)

const MinDegree = 3

// Entry represents a key-value pair
type Entry struct {
	Key   int
	Value string
}

// BPlusNode represents a node in the B+ tree
type BPlusNode struct {
	IsLeaf   bool
	Entries  []Entry      // For leaf nodes
	Keys     []int        // For internal nodes
	Children []*BPlusNode // For internal nodes
}

// BPlusTree represents the B+ tree
type BPlusTree struct {
	Root   *BPlusNode
	Height int
}

// NewBPlusTree creates a new empty B+ tree
func NewBPlusTree() *BPlusTree {
	return &BPlusTree{
		Root: &BPlusNode{
			IsLeaf:  true,
			Entries: make([]Entry, 0),
		},
		Height: 1,
	}
}

// NewLeafNode creates a new leaf node
func NewLeafNode() *BPlusNode {
	return &BPlusNode{
		IsLeaf:  true,
		Entries: make([]Entry, 0),
	}
}

// NewInternalNode creates a new internal node
func NewInternalNode() *BPlusNode {
	return &BPlusNode{
		IsLeaf:   false,
		Keys:     make([]int, 0),
		Children: make([]*BPlusNode, 0),
	}
}

// IsFull checks if a node is full
func (n *BPlusNode) IsFull() bool {
	if n.IsLeaf {
		return len(n.Entries) >= 2*MinDegree-1
	}
	return len(n.Keys) >= 2*MinDegree-1
}

// NumKeys returns the number of keys in the node
func (n *BPlusNode) NumKeys() int {
	if n.IsLeaf {
		return len(n.Entries)
	}
	return len(n.Keys)
}

// Insert inserts a key-value pair into the tree
func (t *BPlusTree) Insert(key int, value string) {
	if t.Root.IsFull() {
		oldRoot := t.Root
		t.Root = NewInternalNode()
		t.Root.Children = append(t.Root.Children, oldRoot)
		t.splitChild(0)
		t.Height++
	}

	t.insertNonFull(key, value)
}

// insertNonFull inserts into a node that is not full
func (t *BPlusTree) insertNonFull(key int, value string) {
	node := t.Root

	for !node.IsLeaf {
		// Find the child where the key should go
		childIdx := 0
		for i, k := range node.Keys {
			if key < k {
				childIdx = i
				break
			}
			childIdx = i + 1
		}

		// Check if child is full
		if node.Children[childIdx].IsFull() {
			t.splitChildInternal(node, childIdx)
			if key > node.Keys[childIdx] {
				childIdx++
			}
		}

		node = node.Children[childIdx]
	}

	// Insert into leaf
	idx := sort.Search(len(node.Entries), func(i int) bool {
		return node.Entries[i].Key > key
	})

	// Check if key exists
	if idx > 0 && node.Entries[idx-1].Key == key {
		node.Entries[idx-1].Value = value
	} else {
		// Insert new entry
		newEntry := Entry{Key: key, Value: value}
		node.Entries = append(node.Entries[:idx], append([]Entry{newEntry}, node.Entries[idx:]...)...)
	}
}

// splitChild splits the child of the root
func (t *BPlusTree) splitChild(childIdx int) {
	oldChild := t.Root.Children[0]
	mid := MinDegree - 1

	if oldChild.IsLeaf {
		// Split leaf node
		newLeaf := NewLeafNode()

		// Copy second half to new leaf
		newLeaf.Entries = make([]Entry, len(oldChild.Entries)-mid)
		copy(newLeaf.Entries, oldChild.Entries[mid:])

		// Keep first half in old leaf
		oldChild.Entries = oldChild.Entries[:mid]

		// Add middle key to root
		t.Root.Keys = append(t.Root.Keys, newLeaf.Entries[0].Key)
		t.Root.Children = append(t.Root.Children, newLeaf)
	}
}

// splitChildInternal splits a child of an internal node
func (t *BPlusTree) splitChildInternal(parent *BPlusNode, childIdx int) {
	child := parent.Children[childIdx]
	mid := MinDegree - 1

	if child.IsLeaf && len(child.Entries) > mid {
		newLeaf := NewLeafNode()

		// Copy second half to new leaf
		newLeaf.Entries = append(newLeaf.Entries, child.Entries[mid:]...)

		// Keep first half in old child
		child.Entries = child.Entries[:mid]

		// Insert middle key into parent
		middleKey := newLeaf.Entries[0].Key

		// Insert key and child into parent
		parent.Keys = append(parent.Keys, 0)
		copy(parent.Keys[childIdx+1:], parent.Keys[childIdx:])
		parent.Keys[childIdx] = middleKey

		parent.Children = append(parent.Children, nil)
		copy(parent.Children[childIdx+2:], parent.Children[childIdx+1:])
		parent.Children[childIdx+1] = newLeaf
	}
}

// Search searches for a value by key
func (t *BPlusTree) Search(key int) (string, bool) {
	return t.searchRecursive(t.Root, key)
}

// searchRecursive recursively searches for a key
func (t *BPlusTree) searchRecursive(node *BPlusNode, key int) (string, bool) {
	if node.IsLeaf {
		// Linear search in leaf
		for _, entry := range node.Entries {
			if entry.Key == key {
				return entry.Value, true
			}
		}
		return "", false
	}

	// Find the child where the key might be
	childIdx := 0
	for i, k := range node.Keys {
		if key < k {
			childIdx = i
			break
		}
		childIdx = i + 1
	}

	return t.searchRecursive(node.Children[childIdx], key)
}

// RangeQuery finds all entries in range [start, end]
func (t *BPlusTree) RangeQuery(start, end int) []Entry {
	var result []Entry
	t.rangeQueryRecursive(t.Root, start, end, &result)
	return result
}

// rangeQueryRecursive recursively searches for keys in range
func (t *BPlusTree) rangeQueryRecursive(node *BPlusNode, start, end int, result *[]Entry) {
	if node.IsLeaf {
		for _, entry := range node.Entries {
			if entry.Key >= start && entry.Key <= end {
				*result = append(*result, entry)
			}
		}
		return
	}

	// Search in children
	for i, key := range node.Keys {
		if start <= key {
			t.rangeQueryRecursive(node.Children[i], start, end, result)
		}
	}

	// Check last child
	if len(node.Children) > len(node.Keys) {
		lastKey := 0
		if len(node.Keys) > 0 {
			lastKey = node.Keys[len(node.Keys)-1]
		}
		if end > lastKey {
			t.rangeQueryRecursive(node.Children[len(node.Keys)], start, end, result)
		}
	}
}

// AllKeys returns all keys in sorted order
func (t *BPlusTree) AllKeys() []int {
	var keys []int
	t.collectKeys(t.Root, &keys)
	return keys
}

// collectKeys recursively collects all keys
func (t *BPlusTree) collectKeys(node *BPlusNode, keys *[]int) {
	if node.IsLeaf {
		for _, entry := range node.Entries {
			*keys = append(*keys, entry.Key)
		}
	} else {
		for _, child := range node.Children {
			t.collectKeys(child, keys)
		}
	}
}

// PrintTree prints the tree structure
func (t *BPlusTree) PrintTree() {
	fmt.Printf("B+ Tree (min_degree = %d)\n", MinDegree)
	fmt.Printf("Height: %d\n", t.Height)
	t.printNode(t.Root, 0)
}

// printNode recursively prints a node
func (t *BPlusTree) printNode(node *BPlusNode, level int) {
	indent := strings.Repeat("  ", level)

	if node.IsLeaf {
		keys := make([]int, len(node.Entries))
		for i, entry := range node.Entries {
			keys[i] = entry.Key
		}
		fmt.Printf("%sLeaf: %v\n", indent, keys)
		for _, entry := range node.Entries {
			fmt.Printf("%s  %d -> %s\n", indent, entry.Key, entry.Value)
		}
	} else {
		fmt.Printf("%sInternal: %v\n", indent, node.Keys)
		for _, child := range node.Children {
			t.printNode(child, level+1)
		}
	}
}

// String returns a string representation of the tree
func (t *BPlusTree) String() string {
	return fmt.Sprintf("B+ Tree(height=%d, keys=%v)", t.Height, t.AllKeys())
}
