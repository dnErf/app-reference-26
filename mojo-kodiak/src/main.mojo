"""
Mojo Kodiak DB - Main Entry Point

A high-performance database with in-memory and block storage layers.
"""

from database import Database
from types import Row, Table

fn main() raises:
    print("Welcome to Mojo Kodiak DB!")
    # Initialize database
    var db = Database()
    
    # Create a table
    db.create_table("users")
    
    # Insert some rows
    var row1 = Row(data=Dict[String, String]())
    row1.data["name"] = "Alice"
    row1.data["age"] = "30"
    db.insert_into_table("users", row1)
    
    var row2 = Row(data=Dict[String, String]())
    row2.data["name"] = "Bob"
    row2.data["age"] = "25"
    db.insert_into_table("users", row2)
    
    print("Inserted 2 rows into 'users'")
    
    # Select all rows
    fn all_filter(row: Row) raises -> Bool:
        return True
    
    var all_rows = db.select_from_table("users", all_filter)
    print("Total rows in 'users':", len(all_rows))
    
    # Select rows where age > 25
    fn age_filter(row: Row) raises -> Bool:
        var age_str = row.data.get("age", "0")
        var age = atol(age_str)
        return age > 25
    
    var filtered_rows = db.select_from_table("users", age_filter)
    print("Rows with age > 25:", len(filtered_rows))
    
    # Example usage
    print("Database operations completed.")