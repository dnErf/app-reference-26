"""
Test Advanced Query Features - Mojo Kodiak Database

Tests complex join algorithms, advanced aggregation functions, subqueries,
query result caching, and prepared statements.
"""

from database import Database
from types import Row

fn test_advanced_aggregations() raises -> Bool:
    """
    Test SUM, COUNT, AVG, MAX, MIN functions.
    """
    print("Testing advanced aggregation functions...")

    var db = Database()
    db.create_table("sales", List[String]("id", "product", "price", "quantity"))

    # Insert test data
    var row1 = Row()
    row1["id"] = "1"
    row1["product"] = "Widget A"
    row1["price"] = "10.50"
    row1["quantity"] = "5"
    db.insert_into_table("sales", row1)

    var row2 = Row()
    row2["id"] = "2"
    row2["product"] = "Widget B"
    row2["price"] = "15.75"
    row2["quantity"] = "3"
    db.insert_into_table("sales", row2)

    var row3 = Row()
    row3["id"] = "3"
    row3["product"] = "Widget A"
    row3["price"] = "10.50"
    row3["quantity"] = "2"
    db.insert_into_table("sales", row3)

    # Test aggregations
    var total = db.sum("sales", "price")
    print(f"Sum of prices: {total}")
    assert(total == 36.75, "Sum should be 36.75")

    var count = db.count("sales", "")
    print(f"Total rows: {count}")
    assert(count == 3, "Should have 3 rows")

    var avg_price = db.avg("sales", "price")
    print(f"Average price: {avg_price}")
    assert(avg_price == 12.25, "Average should be 12.25")

    var max_price = db.max("sales", "price")
    print(f"Max price: {max_price}")
    assert(max_price == "15.75", "Max should be 15.75")

    var min_price = db.min("sales", "price")
    print(f"Min price: {min_price}")
    assert(min_price == "10.50", "Min should be 10.50")

    print("✓ Advanced aggregations test passed")
    return True

fn test_join_algorithms() raises -> Bool:
    """
    Test hash join and merge join algorithms.
    """
    print("Testing join algorithms...")

    var db = Database()

    # Create users table
    db.create_table("users", List[String]("id", "name"))
    var user1 = Row()
    user1["id"] = "1"
    user1["name"] = "Alice"
    db.insert_into_table("users", user1)

    var user2 = Row()
    user2["id"] = "2"
    user2["name"] = "Bob"
    db.insert_into_table("users", user2)

    # Create orders table
    db.create_table("orders", List[String]("id", "user_id", "amount"))
    var order1 = Row()
    order1["id"] = "1"
    order1["user_id"] = "1"
    order1["amount"] = "100.00"
    db.insert_into_table("orders", order1)

    var order2 = Row()
    order2["id"] = "2"
    order2["user_id"] = "2"
    order2["amount"] = "200.00"
    db.insert_into_table("orders", order2)

    # Test hash join
    var hash_result = db.hash_join("users", "orders", "id", "user_id")
    print(f"Hash join result count: {len(hash_result)}")
    assert(len(hash_result) == 2, "Hash join should return 2 rows")

    # Test merge join
    var merge_result = db.merge_join("users", "orders", "id", "user_id")
    print(f"Merge join result count: {len(merge_result)}")
    assert(len(merge_result) == 2, "Merge join should return 2 rows")

    print("✓ Join algorithms test passed")
    return True

fn test_query_caching() raises -> Bool:
    """
    Test query result caching and invalidation.
    """
    print("Testing query caching...")

    var db = Database()
    db.create_table("cache_test", List[String]("id", "value"))

    # Insert test data
    for i in range(5):
        var row = Row()
        row["id"] = String(i + 1)
        row["value"] = "test_" + String(i + 1)
        db.insert_into_table("cache_test", row)

    # Define a filter function
    fn filter_func(r: Row) raises -> Bool:
        return r["value"].startswith("test_")

    # First query should cache result
    var result1 = db.select_with_cache("cache_test", filter_func)
    print(f"First query result count: {len(result1)}")
    assert(len(result1) == 5, "Should return 5 rows")

    # Second query should use cache
    var result2 = db.select_with_cache("cache_test", filter_func)
    print(f"Second query result count: {len(result2)}")
    assert(len(result2) == 5, "Should return 5 rows from cache")

    # Check cache stats
    print(f"Cache hits: {db.cache_hits}, Cache misses: {db.cache_misses}")
    assert(db.cache_hits >= 1, "Should have at least 1 cache hit")

    # Insert new row should invalidate cache
    var new_row = Row()
    new_row["id"] = "6"
    new_row["value"] = "test_6"
    db.insert_into_table("cache_test", new_row)

    # Query again should miss cache
    var result3 = db.select_with_cache("cache_test", filter_func)
    print(f"After insert result count: {len(result3)}")
    assert(len(result3) == 6, "Should return 6 rows after cache invalidation")

    print("✓ Query caching test passed")
    return True

fn test_prepared_statements() raises -> Bool:
    """
    Test prepared statement functionality.
    """
    print("Testing prepared statements...")

    var db = Database()

    # Prepare a statement (simplified for testing)
    var stmt_id = db.prepare_statement("SELECT * FROM test_table WHERE id = ?")
    print(f"Prepared statement ID: {stmt_id}")

    # Execute prepared statement with parameters
    var params = Dict[String, String]()
    params["param_0"] = "1"

    var result = db.execute_prepared(stmt_id, params)
    print(f"Prepared statement result count: {len(result)}")

    # Statement should exist
    assert(stmt_id.startswith("stmt_"), "Statement ID should start with 'stmt_'")

    print("✓ Prepared statements test passed")
    return True

fn main() raises:
    """
    Run all advanced query feature tests.
    """
    print("Running Advanced Query Features Tests...")
    print("=" * 50)

    var tests_passed = 0
    var total_tests = 4

    try:
        if test_advanced_aggregations():
            tests_passed += 1
    except e:
        print(f"❌ Advanced aggregations test failed: {e}")

    try:
        if test_join_algorithms():
            tests_passed += 1
    except e:
        print(f"❌ Join algorithms test failed: {e}")

    try:
        if test_query_caching():
            tests_passed += 1
    except e:
        print(f"❌ Query caching test failed: {e}")

    try:
        if test_prepared_statements():
            tests_passed += 1
    except e:
        print(f"❌ Prepared statements test failed: {e}")

    print("=" * 50)
    print(f"Tests passed: {tests_passed}/{total_tests}")

    if tests_passed == total_tests:
        print("🎉 All advanced query features tests passed!")
    else:
        print("⚠️  Some tests failed. Check implementation.")

fn main() raises:
    """
    Main entry point for running advanced query tests.
    """
    run_advanced_query_tests()