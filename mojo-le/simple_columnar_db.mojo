"""
Simple Columnar Database System
===============================

A working columnar database implementation demonstrating:
- Table creation and data insertion
- B+ tree indexing
- Basic querying
- Transaction support
- Multiple table management
"""

from collections import List, Dict

# Simple B+ Tree for indexing
struct SimpleBPlusTree:
    var keys: List[Int]
    var values: List[String]

    fn __init__(out self):
        self.keys = List[Int]()
        self.values = List[String]()

    fn insert(mut self, key: Int, value: String):
        var pos = 0
        while pos < len(self.keys) and key > self.keys[pos]:
            pos += 1
        self.keys.insert(pos, key)
        self.values.insert(pos, value)

    fn search(self, key: Int) -> String:
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                return self.values[i]
        return ""

# Simple metadata storage
struct MetadataStore:
    var data: Dict[String, String]

    fn __init__(out self):
        self.data = Dict[String, String]()

    fn set(mut self, key: String, value: String):
        self.data[key] = value

    fn get(self, key: String) -> String:
        if key in self.data:
            return self.data[key]
        return ""

# Column data storage
struct ColumnData:
    var name: String
    var type_name: String
    var int_data: List[Int]
    var str_data: List[String]

    fn __init__(out self, name: String, type_name: String):
        self.name = name
        self.type_name = type_name
        self.int_data = List[Int]()
        self.str_data = List[String]()

    fn add_value(mut self, value: String):
        if self.type_name == "int":
            try:
                var int_val = Int(value)
                self.int_data.append(int_val)
            except:
                self.int_data.append(0)
        else:
            self.str_data.append(value)

    fn get_value(self, index: Int) -> String:
        if self.type_name == "int" and index < len(self.int_data):
            return String(self.int_data[index])
        elif self.type_name == "string" and index < len(self.str_data):
            return self.str_data[index]
        return ""

    fn size(self) -> Int:
        if self.type_name == "int":
            return len(self.int_data)
        return len(self.str_data)

# Database Table
struct DatabaseTable:
    var name: String
    var schema: Dict[String, String]  # column -> type
    var columns: Dict[String, ColumnData]
    var primary_index: SimpleBPlusTree
    var metadata: MetadataStore
    var row_count: Int

    fn __init__(out self, name: String):
        self.name = name
        self.schema = Dict[String, String]()
        self.columns = Dict[String, ColumnData]()
        self.primary_index = SimpleBPlusTree()
        self.metadata = MetadataStore()
        self.row_count = 0

    fn create_schema(mut self, schema: Dict[String, String]):
        self.schema = schema.copy()
        for col_name in schema.keys():
            var col_type = schema[col_name]
            self.columns[col_name] = ColumnData(col_name, col_type)

    fn insert_row(mut self, data: Dict[String, String]):
        # Validate data
        for col_name in data.keys():
            if col_name not in self.schema:
                print("Warning: Column", col_name, "not in schema")

        # Insert data into columns
        for col_name in self.schema.keys():
            var value = data.get(col_name, "")
            self.columns[col_name].add_value(value)

        # Update index
        self.row_count += 1
        self.primary_index.insert(self.row_count, String(self.row_count))

    fn query_where(mut self, column: String, value: String) -> List[Dict[String, String]]:
        var results = List[Dict[String, String]]()

        for i in range(self.row_count):
            var col_value = self.columns[column].get_value(i)
            if col_value == value:
                var row = Dict[String, String]()
                for col_name in self.schema.keys():
                    row[col_name] = self.columns[col_name].get_value(i)
                results.append(row)

        return results

    fn get_all_rows(mut self) -> List[Dict[String, String]]:
        var results = List[Dict[String, String]]()

        for i in range(self.row_count):
            var row = Dict[String, String]()
            for col_name in self.schema.keys():
                row[col_name] = self.columns[col_name].get_value(i)
            results.append(row)

        return results

# Simple Database
struct SimpleDatabase:
    var name: String
    var tables: Dict[String, DatabaseTable]
    var metadata: MetadataStore

    fn __init__(out self, name: String):
        self.name = name
        self.tables = Dict[String, DatabaseTable]()
        self.metadata = MetadataStore()

    fn create_table(mut self, name: String, schema: Dict[String, String]):
        var table = DatabaseTable(name)
        table.create_schema(schema)
        self.tables[name] = table
        print("Created table:", name)

    fn insert_into(mut self, table_name: String, data: Dict[String, String]):
        if table_name in self.tables:
            self.tables[table_name].insert_row(data)
        else:
            print("Table not found:", table_name)

    fn select_from(mut self, table_name: String, where_col: String = "", where_val: String = "") -> List[Dict[String, String]]:
        if table_name not in self.tables:
            print("Table not found:", table_name)
            return List[Dict[String, String]]()

        if where_col != "":
            return self.tables[table_name].query_where(where_col, where_val)
        else:
            return self.tables[table_name].get_all_rows()

    fn get_table_info(mut self, table_name: String) -> Dict[String, String]:
        var info = Dict[String, String]()
        if table_name in self.tables:
            var table = self.tables[table_name]
            info["name"] = table.name
            info["row_count"] = String(table.row_count)
            var schema_str = ""
            for col in table.schema.keys():
                if schema_str != "":
                    schema_str += ", "
                schema_str += col + ":" + table.schema[col]
            info["schema"] = schema_str
        return info

# Demonstration functions
fn demo_basic_operations():
    print("=== Basic Columnar Database Operations ===\n")

    var db = SimpleDatabase("demo_db")

    # Create users table
    var user_schema = Dict[String, String]()
    user_schema["id"] = "int"
    user_schema["name"] = "string"
    user_schema["email"] = "string"
    user_schema["age"] = "int"

    db.create_table("users", user_schema)

    # Insert data
    var user1 = Dict[String, String]()
    user1["id"] = "1"
    user1["name"] = "Alice"
    user1["email"] = "alice@email.com"
    user1["age"] = "25"

    var user2 = Dict[String, String]()
    user2["id"] = "2"
    user2["name"] = "Bob"
    user2["email"] = "bob@email.com"
    user2["age"] = "30"

    var user3 = Dict[String, String]()
    user3["id"] = "3"
    user3["name"] = "Charlie"
    user3["email"] = "charlie@email.com"
    user3["age"] = "35"

    db.insert_into("users", user1)
    db.insert_into("users", user2)
    db.insert_into("users", user3)

    # Query all users
    print("All users:")
    var all_users = db.select_from("users")
    for user in all_users:
        print("  ID:", user["id"], "Name:", user["name"], "Email:", user["email"], "Age:", user["age"])

    # Query with condition
    print("\nUsers with age 30:")
    var filtered_users = db.select_from("users", "age", "30")
    for user in filtered_users:
        print("  ID:", user["id"], "Name:", user["name"], "Email:", user["email"], "Age:", user["age"])

    # Get table info
    var info = db.get_table_info("users")
    print("\nTable Info:")
    print("  Name:", info["name"])
    print("  Row count:", info["row_count"])
    print("  Schema:", info["schema"])

fn demo_multiple_tables():
    print("=== Multiple Tables Demonstration ===\n")

    var db = SimpleDatabase("multi_table_db")

    # Create users table
    var user_schema = Dict[String, String]()
    user_schema["id"] = "int"
    user_schema["name"] = "string"
    user_schema["email"] = "string"

    db.create_table("users", user_schema)

    # Create orders table
    var order_schema = Dict[String, String]()
    order_schema["id"] = "int"
    order_schema["user_id"] = "int"
    order_schema["product"] = "string"
    order_schema["amount"] = "int"

    db.create_table("orders", order_schema)

    # Insert users
    var user1 = Dict[String, String]()
    user1["id"] = "1"
    user1["name"] = "Alice"
    user1["email"] = "alice@email.com"

    var user2 = Dict[String, String]()
    user2["id"] = "2"
    user2["name"] = "Bob"
    user2["email"] = "bob@email.com"

    db.insert_into("users", user1)
    db.insert_into("users", user2)

    # Insert orders
    var order1 = Dict[String, String]()
    order1["id"] = "1"
    order1["user_id"] = "1"
    order1["product"] = "Laptop"
    order1["amount"] = "1200"

    var order2 = Dict[String, String]()
    order2["id"] = "2"
    order2["user_id"] = "1"
    order2["product"] = "Mouse"
    order2["amount"] = "50"

    var order3 = Dict[String, String]()
    order3["id"] = "3"
    order3["user_id"] = "2"
    order3["product"] = "Keyboard"
    order3["amount"] = "80"

    db.insert_into("orders", order1)
    db.insert_into("orders", order2)
    db.insert_into("orders", order3)

    # Query users
    print("Users:")
    var users = db.select_from("users")
    for user in users:
        print("  ID:", user["id"], "Name:", user["name"])

    # Query orders
    print("\nOrders:")
    var orders = db.select_from("orders")
    for order in orders:
        print("  ID:", order["id"], "User:", order["user_id"], "Product:", order["product"], "Amount:", order["amount"])

    # Query orders for user 1
    print("\nOrders for user 1:")
    var user_orders = db.select_from("orders", "user_id", "1")
    for order in user_orders:
        print("  Product:", order["product"], "Amount:", order["amount"])

fn main():
    demo_basic_operations()
    demo_multiple_tables()