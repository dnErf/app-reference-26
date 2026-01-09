from database import Database
from types import Row

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

fn main() raises:
    test_basic_operations()