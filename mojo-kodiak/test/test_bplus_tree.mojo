"""
Unit tests for B+ tree operations.
"""

from extensions.b_plus_tree import BPlusTree, BPlusNode
from types import Row

fn test_bplus_tree_creation() raises -> Bool:
    """Test B+ tree creation and basic properties."""
    print("Testing B+ tree creation...")
    var tree = BPlusTree(order=3)

    # Check initial state
    if tree.root:
        print("ERROR: Root should be None initially")
        return False

    if len(tree.nodes) != 0:
        print("ERROR: Nodes list should be empty initially")
        return False

    print("✓ B+ tree creation test passed")
    return True

fn test_bplus_tree_insert() raises -> Bool:
    """Test B+ tree insert operations."""
    print("Testing B+ tree insert...")
    var tree = BPlusTree(order=3)

    # Insert some values
    var row1 = Row()
    row1["id"] = 1
    row1["data"] = "value1"
    tree.insert(1, row1)

    var row2 = Row()
    row2["id"] = 2
    row2["data"] = "value2"
    tree.insert(2, row2)

    var row3 = Row()
    row3["id"] = 3
    row3["data"] = "value3"
    tree.insert(3, row3)

    # Check that root exists
    if not tree.root:
        print("ERROR: Root should exist after inserts")
        return False

    # Check that nodes were created
    if len(tree.nodes) == 0:
        print("ERROR: Nodes should have been created")
        return False

    print("✓ B+ tree insert test passed")
    return True

fn test_bplus_tree_search() raises -> Bool:
    """Test B+ tree search operations."""
    print("Testing B+ tree search...")
    var tree = BPlusTree(order=3)

    # Insert test data
    for i in range(1, 11):
        var row = Row()
        row["id"] = i
        row["data"] = f"value_{i}"
        tree.insert(i, row)

    # Test successful searches
    for i in range(1, 11):
        var result = tree.search(i)
        if not result:
            print(f"ERROR: Failed to find key {i}")
            return False

        var found_row = result.value()
        if found_row.get_int("id") != i:
            print(f"ERROR: Wrong ID returned for key {i}")
            return False

    # Test unsuccessful search
    var not_found = tree.search(99)
    if not_found:
        print("ERROR: Should not have found non-existent key")
        return False

    print("✓ B+ tree search test passed")
    return True

fn test_bplus_tree_node_splitting() raises -> Bool:
    """Test B+ tree node splitting behavior."""
    print("Testing B+ tree node splitting...")
    var tree = BPlusTree(order=3)  # Small order to force splitting

    # Insert enough values to cause splitting
    for i in range(1, 8):  # More than order * 2
        var row = Row()
        row["id"] = i
        row["data"] = f"value_{i}"
        tree.insert(i, row)

    # Check that multiple nodes exist (splitting occurred)
    if len(tree.nodes) < 3:
        print(f"ERROR: Expected multiple nodes due to splitting, got {len(tree.nodes)}")
        return False

    # Verify all values are still searchable
    for i in range(1, 8):
        var result = tree.search(i)
        if not result:
            print(f"ERROR: Lost key {i} after splitting")
            return False

    print("✓ B+ tree node splitting test passed")
    return True

fn test_bplus_tree_order() raises -> Bool:
    """Test different tree orders."""
    print("Testing B+ tree order variations...")

    # Test order 4
    var tree4 = BPlusTree(order=4)
    for i in range(1, 21):
        var row = Row()
        row["id"] = i
        row["data"] = f"value_{i}"
        tree4.insert(i, row)

    for i in range(1, 21):
        var result = tree4.search(i)
        if not result:
            print(f"ERROR: Order 4 tree failed to find key {i}")
            return False

    # Test order 5
    var tree5 = BPlusTree(order=5)
    for i in range(1, 31):
        var row = Row()
        row["id"] = i
        row["data"] = f"value_{i}"
        tree5.insert(i, row)

    for i in range(1, 31):
        var result = tree5.search(i)
        if not result:
            print(f"ERROR: Order 5 tree failed to find key {i}")
            return False

    print("✓ B+ tree order test passed")
    return True

fn test_bplus_tree_duplicates() raises -> Bool:
    """Test handling of duplicate keys."""
    print("Testing B+ tree duplicate handling...")
    var tree = BPlusTree(order=3)

    # Insert same key multiple times (should overwrite)
    var row1 = Row()
    row1["id"] = 1
    row1["data"] = "first"
    tree.insert(1, row1)

    var row2 = Row()
    row2["id"] = 1
    row2["data"] = "second"
    tree.insert(1, row2)

    # Should find the second value
    var result = tree.search(1)
    if not result:
        print("ERROR: Failed to find key after duplicate insert")
        return False

    var found_row = result.value()
    if found_row.get_string("data") != "second":
        print("ERROR: Duplicate insert didn't overwrite correctly")
        return False

    print("✓ B+ tree duplicate handling test passed")
    return True

fn test_bplus_tree() raises -> Bool:
    """Run all B+ tree tests."""
    if not test_bplus_tree_creation():
        return False
    if not test_bplus_tree_insert():
        return False
    if not test_bplus_tree_search():
        return False
    if not test_bplus_tree_node_splitting():
        return False
    if not test_bplus_tree_order():
        return False
    if not test_bplus_tree_duplicates():
        return False

    return True