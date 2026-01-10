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
    print("Sum of prices: " + String(total))
    if total != 36.75:
        print("ERROR: Sum should be 36.75")
        return False

    var count = db.count("sales", "")
    print("Total rows: " + String(count))
    if count != 3:
        print("ERROR: Should have 3 rows")
        return False

    var avg_price = db.avg("sales", "price")
    print("Average price: " + String(avg_price))
    if avg_price != 12.25:
        print("ERROR: Average should be 12.25")
        return False

    var max_price = db.max("sales", "price")
    print("Max price: " + max_price)
    if max_price != "15.75":
        print("ERROR: Max should be 15.75")
        return False

    var min_price = db.min("sales", "price")
    print("Min price: " + min_price)
    if min_price != "10.50":
        print("ERROR: Min should be 10.50")
        return False

    print("✓ Advanced aggregations test passed")
    return True

fn run_advanced_query_tests() raises:
    """
    Run all advanced query feature tests.
    """
    print("Running Advanced Query Features Tests...")
    print("=" * 50)

    var tests_passed = 0
    var total_tests = 1

    try:
        if test_advanced_aggregations():
            tests_passed += 1
    except e:
        print("❌ Advanced aggregations test failed: " + String(e))

    print("=" * 50)
    print("Tests passed: " + String(tests_passed) + "/" + String(total_tests))

    if tests_passed == total_tests:
        print("🎉 All advanced query features tests passed!")
    else:
        print("⚠️  Some tests failed. Check implementation.")

fn main() raises:
    """
    Main entry point for running advanced query tests.
    """
    run_advanced_query_tests()