"""
Simple test runner for Mojo Kodiak database.
"""

from database import Database
from types import Row
from extensions.b_plus_tree import BPlusTree

fn run_basic_tests() raises -> Bool:
    """Run basic database tests."""
    print("Running basic database tests...")

    # Test database creation
    var db = Database()
    print("✓ Database creation test passed")

    # Test table operations
    db.create_table("test_table")
    var row = Row()
    row["id"] = "1"
    row["name"] = "Test"
    db.insert_into_table("test_table", row)

    var rows = db.select_all_from_table("test_table")
    if len(rows) == 1:
        print("✓ Table operations test passed")
        return True
    else:
        print("✗ Table operations test failed - wrong row count")
        return False

fn run_bplus_tree_tests() raises -> Bool:
    """Run B+ tree tests."""
    print("Running B+ tree tests...")

    var tree = BPlusTree(order=3)

    # Test basic insert
    var row = Row()
    row["id"] = "1"
    row["data"] = "test"
    tree.insert(1, row)

    # Test search
    var result = tree.search(1)
    if len(result.data) > 0:
        print("✓ B+ tree test passed")
        return True
    else:
        print("✗ B+ tree test failed - search failed")
        return False

fn main() raises:
    """Main test function."""
    print("Mojo Kodiak Database Test Suite")
    print("===============================")

    var passed = 0
    var total = 2

    if run_basic_tests():
        passed += 1

    if run_bplus_tree_tests():
        passed += 1

    print("")
    print("Results: " + String(passed) + "/" + String(total) + " tests passed")

    if passed == total:
        print("All tests passed!")
    else:
        print(String(total - passed) + " test(s) failed")