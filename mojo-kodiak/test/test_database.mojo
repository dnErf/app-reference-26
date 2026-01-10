"""
Unit tests for database operations.
"""

from database import Database
from types import Row

fn test_database_creation() raises -> Bool:
    """Test database creation and initialization."""
    print("Testing database creation...")
    var db = Database()

    # Check that extensions are registered
    if "core" not in db.extensions:
        print("ERROR: Core extension not registered")
        return False

    if "indexing" not in db.extensions:
        print("ERROR: Indexing extension not registered")
        return False

    print("✓ Database creation test passed")
    return True

fn test_table_operations() raises -> Bool:
    """Test table creation, insertion, and selection."""
    print("Testing table operations...")
    var db = Database()

    # Create table
    db.create_table("test_table")

    # Insert rows
    var row1 = Row()
    row1["id"] = 1
    row1["name"] = "Alice"
    row1["age"] = 25
    db.insert_into_table("test_table", row1)

    var row2 = Row()
    row2["id"] = 2
    row2["name"] = "Bob"
    row2["age"] = 30
    db.insert_into_table("test_table", row2)

    # Select all
    var rows = db.select_all_from_table("test_table")
    if len(rows) != 2:
        print(f"ERROR: Expected 2 rows, got {len(rows)}")
        return False

    # Check first row
    var first_row = rows[0]
    if first_row.get_int("id") != 1:
        print("ERROR: First row ID incorrect")
        return False

    if first_row.get_string("name") != "Alice":
        print("ERROR: First row name incorrect")
        return False

    print("✓ Table operations test passed")
    return True

fn test_join_operations() raises -> Bool:
    """Test table join operations."""
    print("Testing join operations...")
    var db = Database()

    # Create users table
    db.create_table("users")
    var user1 = Row()
    user1["id"] = 1
    user1["name"] = "Alice"
    db.insert_into_table("users", user1)

    var user2 = Row()
    user2["id"] = 2
    user2["name"] = "Bob"
    db.insert_into_table("users", user2)

    # Create orders table
    db.create_table("orders")
    var order1 = Row()
    order1["id"] = 1
    order1["user_id"] = 1
    order1["item"] = "Book"
    db.insert_into_table("orders", order1)

    var order2 = Row()
    order2["id"] = 2
    order2["user_id"] = 1
    order2["item"] = "Pen"
    db.insert_into_table("orders", order2)

    var order3 = Row()
    order3["id"] = 3
    order3["user_id"] = 2
    order3["item"] = "Notebook"
    db.insert_into_table("orders", order3)

    # Test join
    var joined = db.join("users", "orders", "id", "user_id")
    if len(joined) != 3:
        print(f"ERROR: Expected 3 joined rows, got {len(joined)}")
        return False

    # Check that Alice has 2 orders
    var alice_orders = 0
    for row in joined:
        if row[].get_string("name") == "Alice":
            alice_orders += 1

    if alice_orders != 2:
        print(f"ERROR: Expected Alice to have 2 orders, got {alice_orders}")
        return False

    print("✓ Join operations test passed")
    return True

fn test_indexing_operations() raises -> Bool:
    """Test that indexing works with inserts."""
    print("Testing indexing operations...")
    var db = Database()

    # Create table and insert rows with IDs
    db.create_table("indexed_table")

    for i in range(10):
        var row = Row()
        row["id"] = i
        row["data"] = f"value_{i}"
        db.insert_into_table("indexed_table", row)

    # The B+ tree should be populated (we can't directly test search yet
    # but we can verify the database doesn't crash)
    print("✓ Indexing operations test passed")
    return True

fn test_error_handling() raises -> Bool:
    """Test error handling for invalid operations."""
    print("Testing error handling...")
    var db = Database()

    # Try to select from non-existent table
    try:
        var rows = db.select_all_from_table("non_existent_table")
        print("ERROR: Should have raised error for non-existent table")
        return False
    except:
        # Expected error
        pass

    # Try to insert into non-existent table
    try:
        var row = Row()
        row["id"] = 1
        db.insert_into_table("non_existent_table", row)
        print("ERROR: Should have raised error for non-existent table")
        return False
    except:
        # Expected error
        pass

    print("✓ Error handling test passed")
    return True

fn test_database_basic() raises -> Bool:
    """Run all basic database tests."""
    if not test_database_creation():
        return False
    if not test_table_operations():
        return False
    if not test_join_operations():
        return False
    if not test_indexing_operations():
        return False
    if not test_error_handling():
        return False

    return True