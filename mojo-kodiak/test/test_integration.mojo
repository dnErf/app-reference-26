"""
Integration tests for database operations.
"""

from database import Database
from types import Row
from extensions.query_parser import parse_query

fn test_database_workflow() raises -> Bool:
    """Test complete database workflow from creation to queries."""
    print("Testing complete database workflow...")

    var db = Database()

    # Create tables
    db.create_table("users")
    db.create_table("products")
    db.create_table("orders")

    # Insert users
    for i in range(1, 6):
        var user = Row()
        user["id"] = i
        user["name"] = f"User{i}"
        user["email"] = f"user{i}@example.com"
        db.insert_into_table("users", user)

    # Insert products
    var products = List[Tuple[String, Float64]](
        ("Laptop", 999.99),
        ("Mouse", 29.99),
        ("Keyboard", 79.99),
        ("Monitor", 299.99),
        ("Headphones", 149.99)
    )

    var product_id = 1
    for product in products:
        var prod = Row()
        prod["id"] = product_id
        prod["name"] = product[].get[0, String]()
        prod["price"] = product[].get[1, Float64]()
        db.insert_into_table("products", prod)
        product_id += 1

    # Insert orders
    for i in range(1, 11):
        var order = Row()
        order["id"] = i
        order["user_id"] = (i % 5) + 1  # Cycle through users
        order["product_id"] = (i % 5) + 1  # Cycle through products
        order["quantity"] = (i % 3) + 1  # 1-3 quantity
        db.insert_into_table("orders", order)

    # Test queries
    var users = db.select_all_from_table("users")
    if len(users) != 5:
        print(f"ERROR: Expected 5 users, got {len(users)}")
        return False

    var products_result = db.select_all_from_table("products")
    if len(products_result) != 5:
        print(f"ERROR: Expected 5 products, got {len(products_result)}")
        return False

    var orders = db.select_all_from_table("orders")
    if len(orders) != 10:
        print(f"ERROR: Expected 10 orders, got {len(orders)}")
        return False

    # Test joins
    var user_orders = db.join("users", "orders", "id", "user_id")
    if len(user_orders) != 10:
        print(f"ERROR: Expected 10 user-orders joins, got {len(user_orders)}")
        return False

    print("✓ Database workflow test passed")
    return True

fn test_indexing_integration() raises -> Bool:
    """Test that indexing works in integrated scenarios."""
    print("Testing indexing integration...")

    var db = Database()

    # Create table with ID field
    db.create_table("indexed_test")

    # Insert many rows with IDs
    for i in range(1, 101):
        var row = Row()
        row["id"] = i
        row["data"] = f"value_{i}"
        row["timestamp"] = i * 1000
        db.insert_into_table("indexed_test", row)

    # Verify all rows are inserted
    var rows = db.select_all_from_table("indexed_test")
    if len(rows) != 100:
        print(f"ERROR: Expected 100 rows, got {len(rows)}")
        return False

    # Verify B+ tree integration (rows should be indexed)
    # We can't directly test the index, but we can verify the database
    # handles the indexed inserts without errors

    print("✓ Indexing integration test passed")
    return True

fn test_extension_integration() raises -> Bool:
    """Test extension system integration."""
    print("Testing extension integration...")

    var db = Database()

    # Check that extensions are loaded
    if len(db.extensions) == 0:
        print("ERROR: No extensions loaded")
        return False

    # Verify core extension is loaded
    if "core" not in db.extensions:
        print("ERROR: Core extension not found")
        return False

    var core_ext = db.extensions["core"]
    if not core_ext.is_loaded:
        print("ERROR: Core extension not loaded")
        return False

    # Test that we can perform operations (which use extensions)
    db.create_table("ext_test")
    var row = Row()
    row["id"] = 1
    row["name"] = "test"
    db.insert_into_table("ext_test", row)

    var results = db.select_all_from_table("ext_test")
    if len(results) != 1:
        print("ERROR: Extension integration failed - insert/select not working")
        return False

    print("✓ Extension integration test passed")
    return True