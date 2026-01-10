from database import Database
from types import Row
from extensions.query_parser import parse_query

fn test_basic_operations() raises:
    print("Running basic operations test...")
    var db = Database()
    
    # Create table
    db.create_table("users")
    
    # Insert rows
    var row1 = Row()
    row1["id"] = "1"
    row1["name"] = "Alice"
    row1["age"] = "25"
    db.insert_into_table("users", row1)
    
    var row2 = Row()
    row2["id"] = "2"
    row2["name"] = "Bob"
    row2["age"] = "30"
    db.insert_into_table("users", row2)
    
    # Select all
    var rows = db.select_all_from_table("users")
    print("Total rows:", len(rows))
    
    # Test aggregate (placeholder)
    # var sum_age = db.aggregate("users", "age", sum_func)
    # print("Sum of ages:", sum_age)
    
    # Test join (need another table)
    db.create_table("orders")
    var order1 = Row()
    order1["id"] = "1"
    order1["user_id"] = "1"
    order1["item"] = "Book"
    db.insert_into_table("orders", order1)
    
    var joined = db.join("users", "orders", "id", "user_id")
    print("Joined rows:", len(joined))
    
    print("Basic operations test passed!")

fn test_async_functions() raises:
    print("Running async functions test...")
    var db = Database()
    
    # Create a default async function (functions are async by default)
    var create_default_async = parse_query("CREATE FUNCTION default_async() RETURNS TEXT { print('Default async executed'); return 'async_done' }")
    var result1 = db.execute_query(create_default_async)
    print("Default async function created")
    
    # Create an explicit async function
    var create_explicit_async = parse_query("CREATE FUNCTION explicit_async() RETURNS TEXT AS ASYNC { print('Explicit async executed'); return 'explicit_done' }")
    var result2 = db.execute_query(create_explicit_async)
    print("Explicit async function created")
    
    # Create a sync function
    var create_sync = parse_query("CREATE FUNCTION sync_func() RETURNS TEXT AS SYNC { print('Sync executed'); return 'sync_done' }")
    var result3 = db.execute_query(create_sync)
    print("Sync function created")
    
    # Test PL expressions
    var pl1 = parse_query("SELECT default_async()")
    var pl_result1 = db.execute_query(pl1)
    print("Default async function executed, result:", len(pl_result1))
    
    var pl2 = parse_query("SELECT explicit_async()")
    var pl_result2 = db.execute_query(pl2)
    print("Explicit async function executed, result:", len(pl_result2))
    
    var pl3 = parse_query("SELECT sync_func()")
    var pl_result3 = db.execute_query(pl3)
    print("Sync function executed, result:", len(pl_result3))
    
    print("Async functions test passed!")

fn main() raises:
    test_basic_operations()
    test_async_functions()