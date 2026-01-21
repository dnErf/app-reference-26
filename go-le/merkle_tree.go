package main

import (
	"crypto/sha256"
	"fmt"
	"strings"
)

// MerkleNode represents a node in the Merkle tree
type MerkleNode struct {
	Hash   string
	Data   string
	Left   *MerkleNode
	Right  *MerkleNode
	IsLeaf bool
}

// MerkleProof represents a proof for a leaf verification
type MerkleProof struct {
	SiblingHash string
	Position    string // "left" or "right"
}

// MerkleTree represents a binary Merkle tree
type MerkleTree struct {
	Root     *MerkleNode
	Leaves   []*MerkleNode
	HashFunc string
}

// NewMerkleTree creates a new Merkle tree from data blocks
func NewMerkleTree(dataBlocks []string, hashFunc string) (*MerkleTree, error) {
	if len(dataBlocks) == 0 {
		return nil, fmt.Errorf("data blocks cannot be empty")
	}

	tree := &MerkleTree{
		HashFunc: hashFunc,
	}

	tree.Build(dataBlocks)
	return tree, nil
}

// Hash computes the hash of data
func (mt *MerkleTree) Hash(data string) string {
	if mt.HashFunc != "sha256" {
		mt.HashFunc = "sha256"
	}
	hash := sha256.Sum256([]byte(data))
	return fmt.Sprintf("%x", hash)
}

// Build constructs the Merkle tree from data blocks
func (mt *MerkleTree) Build(dataBlocks []string) {
	// Create leaf nodes
	mt.Leaves = make([]*MerkleNode, len(dataBlocks))
	for i, data := range dataBlocks {
		hash := mt.Hash(data)
		leaf := &MerkleNode{
			Hash:   hash,
			Data:   data,
			IsLeaf: true,
		}
		mt.Leaves[i] = leaf
	}

	// Build tree bottom-up
	currentLevel := make([]*MerkleNode, len(mt.Leaves))
	copy(currentLevel, mt.Leaves)

	for len(currentLevel) > 1 {
		var nextLevel []*MerkleNode

		// Process pairs
		for i := 0; i < len(currentLevel); i += 2 {
			left := currentLevel[i]
			right := currentLevel[i]

			// Handle odd number of nodes
			if i+1 < len(currentLevel) {
				right = currentLevel[i+1]
			}

			// Combine hashes
			combined := left.Hash + right.Hash
			parentHash := mt.Hash(combined)
			parent := &MerkleNode{
				Hash:   parentHash,
				Left:   left,
				Right:  right,
				IsLeaf: false,
			}

			nextLevel = append(nextLevel, parent)
		}

		currentLevel = nextLevel
	}

	// Set root
	if len(currentLevel) > 0 {
		mt.Root = currentLevel[0]
	}
}

// GetRootHash returns the root hash of the tree
func (mt *MerkleTree) GetRootHash() string {
	if mt.Root == nil {
		return ""
	}
	return mt.Root.Hash
}

// GetProof generates a Merkle proof for a leaf at given index
func (mt *MerkleTree) GetProof(leafIndex int) []MerkleProof {
	if leafIndex >= len(mt.Leaves) {
		return nil
	}

	var proof []MerkleProof
	target := mt.Leaves[leafIndex]
	mt.findProofPath(mt.Root, target, &proof)

	// Reverse proof to go from leaf to root
	for i, j := 0, len(proof)-1; i < j; i, j = i+1, j-1 {
		proof[i], proof[j] = proof[j], proof[i]
	}

	return proof
}

// findProofPath recursively finds the proof path for a leaf
func (mt *MerkleTree) findProofPath(node *MerkleNode, target *MerkleNode, proof *[]MerkleProof) bool {
	if node == nil {
		return false
	}

	if node == target {
		return true
	}

	if node.Left == nil {
		return false
	}

	// Search left subtree
	if mt.findProofPath(node.Left, target, proof) {
		// Add right sibling
		if node.Right != nil {
			*proof = append([]MerkleProof{{SiblingHash: node.Right.Hash, Position: "right"}}, (*proof)...)
		}
		return true
	}

	// Search right subtree
	if node.Right != nil && mt.findProofPath(node.Right, target, proof) {
		// Add left sibling
		*proof = append([]MerkleProof{{SiblingHash: node.Left.Hash, Position: "left"}}, (*proof)...)
		return true
	}

	return false
}

// VerifyLeaf verifies a leaf using Merkle proof
func (mt *MerkleTree) VerifyLeaf(leafIndex int, data string, proof []MerkleProof) bool {
	// Compute leaf hash
	currentHash := mt.Hash(data)

	// Traverse proof path
	for _, p := range proof {
		if p.Position == "left" {
			currentHash = mt.Hash(p.SiblingHash + currentHash)
		} else {
			currentHash = mt.Hash(currentHash + p.SiblingHash)
		}
	}

	return currentHash == mt.GetRootHash()
}

// GetHeight returns the height of the tree
func (mt *MerkleTree) GetHeight() int {
	if mt.Root == nil {
		return 0
	}
	return mt.getNodeHeight(mt.Root)
}

// getNodeHeight recursively computes node height
func (mt *MerkleTree) getNodeHeight(node *MerkleNode) int {
	if node == nil || node.IsLeaf {
		return 1
	}
	return 1 + max(mt.getNodeHeight(node.Left), mt.getNodeHeight(node.Right))
}

// Display returns a string representation of the tree
func (mt *MerkleTree) Display() string {
	result := []string{
		fmt.Sprintf("Merkle Tree (hash=%s)", mt.HashFunc),
		fmt.Sprintf("Number of leaves: %d", len(mt.Leaves)),
		fmt.Sprintf("Height: %d", mt.GetHeight()),
		fmt.Sprintf("Root hash: %s", mt.GetRootHash()),
		"",
		"Leaves:",
	}

	for i, leaf := range mt.Leaves {
		hash := leaf.Hash
		if len(hash) > 16 {
			hash = hash[:16] + "..."
		}
		result = append(result, fmt.Sprintf("  [%d] %s -> %s", i, leaf.Data, hash))
	}

	return strings.Join(result, "\n")
}

// VisualizeTree returns an ASCII visualization of the tree
func (mt *MerkleTree) VisualizeTree() string {
	if mt.Root == nil {
		return "Empty tree"
	}
	return mt.visualizeNode(mt.Root, "", true)
}

// visualizeNode recursively visualizes tree nodes
func (mt *MerkleTree) visualizeNode(node *MerkleNode, prefix string, isTail bool) string {
	if node == nil {
		return ""
	}

	connector := "└── "
	if !isTail {
		connector = "├── "
	}

	hash := node.Hash
	if len(hash) > 8 {
		hash = hash[:8] + "..."
	}

	var label string
	if node.IsLeaf {
		label = fmt.Sprintf("%s [%s]", node.Data, hash)
	} else {
		label = fmt.Sprintf("[%s]", hash)
	}

	result := prefix + connector + label + "\n"

	if node.Left != nil || node.Right != nil {
		extension := "    "
		if !isTail {
			extension = "│   "
		}

		if node.Left != nil {
			result += mt.visualizeNode(node.Left, prefix+extension, node.Right == nil)
		}

		if node.Right != nil {
			result += mt.visualizeNode(node.Right, prefix+extension, true)
		}
	}

	return result
}

// Helper function
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
