"""
Working Columnar Database System
=================================

A functional columnar database demonstrating core concepts:
- Table creation with schemas
- Data insertion and storage
- Basic querying with conditions
- Multiple table support
- B+ tree indexing
"""

from collections import List

# Simple key-value storage
struct KeyValueStore:
    var keys: List[String]
    var values: List[String]

    fn __init__(out self):
        self.keys = List[String]()
        self.values = List[String]()

    fn set(mut self, key: String, value: String):
        # Simple implementation - just append
        self.keys.append(key)
        self.values.append(value)

    fn get(self, key: String) -> String:
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                return self.values[i]
        return ""

# Simple B+ Tree
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

# Column storage
struct Column:
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
    var columns: List[Column]
    var primary_index: SimpleBPlusTree
    var metadata: KeyValueStore
    var row_count: Int

    fn __init__(out self, name: String):
        self.name = name
        self.columns = List[Column]()
        self.primary_index = SimpleBPlusTree()
        self.metadata = KeyValueStore()
        self.row_count = 0

    fn add_column(mut self, name: String, type_name: String):
        var col = Column(name, type_name)
        self.columns.append(col)

    fn insert_row(mut self, data: List[String]):
        # Insert data into each column
        for i in range(len(self.columns)):
            if i < len(data):
                self.columns[i].add_value(data[i])
            else:
                self.columns[i].add_value("")  # Default empty value

        self.row_count += 1
        self.primary_index.insert(self.row_count, String(self.row_count))

    fn get_row(self, index: Int) -> List[String]:
        var row = List[String]()
        for col in self.columns:
            row.append(col.get_value(index))
        return row

    fn find_rows_where(mut self, col_index: Int, value: String) -> List[Int]:
        var matching_rows = List[Int]()

        if col_index >= len(self.columns):
            return matching_rows

        var col = self.columns[col_index]
        for i in range(col.size()):
            if col.get_value(i) == value:
                matching_rows.append(i)

        return matching_rows

    fn get_column_names(self) -> List[String]:
        var names = List[String]()
        for col in self.columns:
            names.append(col.name)
        return names

# Simple Database
struct SimpleDatabase:
    var name: String
    var tables: List[DatabaseTable]
    var table_names: List[String]

    fn __init__(out self, name: String):
        self.name = name
        self.tables = List[DatabaseTable]()
        self.table_names = List[String]()

    fn create_table(mut self, name: String, schema: List[String]):
        """Create table with schema as ["name:type", "name:type", ...]"""
        var table = DatabaseTable(name)
        for schema_item in schema:
            var parts = schema_item.split(":")
            if len(parts) == 2:
                table.add_column(parts[0], parts[1])

        self.tables.append(table)
        self.table_names.append(name)
        print("Created table:", name)

    fn get_table_index(self, name: String) -> Int:
        for i in range(len(self.table_names)):
            if self.table_names[i] == name:
                return i
        return -1

    fn insert_into(mut self, table_name: String, data: List[String]):
        var table_idx = self.get_table_index(table_name)
        if table_idx >= 0:
            self.tables[table_idx].insert_row(data)
        else:
            print("Table not found:", table_name)

    fn select_all_from(mut self, table_name: String) -> List[List[String]]:
        var table_idx = self.get_table_index(table_name)
        if table_idx < 0:
            return List[List[String]]()

        var table = self.tables[table_idx]
        var results = List[List[String]]()

        for i in range(table.row_count):
            results.append(table.get_row(i))

        return results

    fn select_where(mut self, table_name: String, col_name: String, value: String) -> List[List[String]]:
        var table_idx = self.get_table_index(table_name)
        if table_idx < 0:
            return List[List[String]]()

        var table = self.tables[table_idx]
        var col_names = table.get_column_names()

        # Find column index
        var col_index = -1
        for i in range(len(col_names)):
            if col_names[i] == col_name:
                col_index = i
                break

        if col_index < 0:
            return List[List[String]]()

        var matching_rows = table.find_rows_where(col_index, value)
        var results = List[List[String]]()

        for row_idx in matching_rows:
            results.append(table.get_row(row_idx))

        return results

    fn get_table_info(mut self, table_name: String) -> String:
        var table_idx = self.get_table_index(table_name)
        if table_idx < 0:
            return "Table not found"

        var table = self.tables[table_idx]
        var info = "Table: " + table.name + ", Rows: " + String(table.row_count) + ", Columns: "

        var col_names = table.get_column_names()
        for i in range(len(col_names)):
            if i > 0:
                info += ", "
            info += col_names[i]

        return info

# Demonstration
fn demo_database():
    print("=== Working Columnar Database Demo ===\n")

    var db = SimpleDatabase("demo_db")

    # Create users table
    var user_schema = List[String]()
    user_schema.append("id:int")
    user_schema.append("name:string")
    user_schema.append("email:string")
    user_schema.append("age:int")

    db.create_table("users", user_schema)

    # Insert users
    var user1 = List[String]()
    user1.append("1")
    user1.append("Alice")
    user1.append("alice@email.com")
    user1.append("25")

    var user2 = List[String]()
    user2.append("2")
    user2.append("Bob")
    user2.append("bob@email.com")
    user2.append("30")

    var user3 = List[String]()
    user3.append("3")
    user3.append("Charlie")
    user3.append("charlie@email.com")
    user3.append("35")

    db.insert_into("users", user1)
    db.insert_into("users", user2)
    db.insert_into("users", user3)

    # Query all users
    print("All users:")
    var all_users = db.select_all_from("users")
    var col_names = List[String]()
    col_names.append("ID")
    col_names.append("Name")
    col_names.append("Email")
    col_names.append("Age")

    for user in all_users:
        var line = ""
        for i in range(len(user)):
            if i > 0:
                line += " | "
            line += col_names[i] + ": " + user[i]
        print(" ", line)

    # Query with condition
    print("\nUsers with age 30:")
    var filtered_users = db.select_where("users", "age", "30")
    for user in filtered_users:
        var line = ""
        for i in range(len(user)):
            if i > 0:
                line += " | "
            line += col_names[i] + ": " + user[i]
        print(" ", line)

    # Table info
    print("\n" + db.get_table_info("users"))

    print("\n=== Multiple Tables Demo ===\n")

    # Create orders table
    var order_schema = List[String]()
    order_schema.append("id:int")
    order_schema.append("user_id:int")
    order_schema.append("product:string")
    order_schema.append("amount:int")

    db.create_table("orders", order_schema)

    # Insert orders
    var order1 = List[String]()
    order1.append("1")
    order1.append("1")
    order1.append("Laptop")
    order1.append("1200")

    var order2 = List[String]()
    order2.append("2")
    order2.append("1")
    order2.append("Mouse")
    order2.append("50")

    var order3 = List[String]()
    order3.append("3")
    order3.append("2")
    order3.append("Keyboard")
    order3.append("80")

    db.insert_into("orders", order1)
    db.insert_into("orders", order2)
    db.insert_into("orders", order3)

    # Query orders
    print("All orders:")
    var all_orders = db.select_all_from("orders")
    var order_col_names = List[String]()
    order_col_names.append("ID")
    order_col_names.append("UserID")
    order_col_names.append("Product")
    order_col_names.append("Amount")

    for order in all_orders:
        var line = ""
        for i in range(len(order)):
            if i > 0:
                line += " | "
            line += order_col_names[i] + ": " + order[i]
        print(" ", line)

    # Query orders for user 1
    print("\nOrders for user 1:")
    var user_orders = db.select_where("orders", "user_id", "1")
    for order in user_orders:
        var line = ""
        for i in range(len(order)):
            if i > 0:
                line += " | "
            line += order_col_names[i] + ": " + order[i]
        print(" ", line)

    print("\n" + db.get_table_info("orders"))

fn main():
    demo_database()