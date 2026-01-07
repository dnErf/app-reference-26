# Grizzly Database Demo
# Simple demonstration of database operations
# Run: mojo run demo.mojo

from arrow import Schema, Table
from query import execute_query
from formats import read_jsonl

fn demo_database_operations() raises:
    print("=== Grizzly Database Demo ===")
    print("")

    # Create a simple table from JSONL
    print("1. Creating table from JSONL data...")
    var jsonl_content = '{"id": 1, "name": "Alice", "age": 25}\n{"id": 2, "name": "Bob", "age": 30}\n{"id": 3, "name": "Charlie", "age": 35}'
    var users_table = read_jsonl(jsonl_content)
    print("   Created users table with", users_table.num_rows(), "rows")

    # Display the table (avoiding print issues)
    print("   Table created successfully with", users_table.num_rows(), "rows")
    print("   Number of columns:", len(users_table.schema.fields))

    print("")
    print("2. Running SQL query...")
    # Note: Full SQL parsing may not work, but basic operations do
    print("   (SQL queries have limited support in this demo)")
    print("   Use the main.mojo file for full query examples")

    print("")
    print("3. Database operations available:")
    print("   - Table loading from JSONL, CSV, Parquet, AVRO")
    print("   - Columnar operations and joins")
    print("   - Basic query execution")
    print("   - File format conversions")
    print("")
    print("4. To create your own database:")
    print("   - Modify this file or main.mojo")
    print("   - Add your data loading logic")
    print("   - Implement your query operations")
    print("")
    print("Demo completed successfully!")

fn main() raises:
    demo_database_operations()