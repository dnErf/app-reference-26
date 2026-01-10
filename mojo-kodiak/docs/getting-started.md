# Mojo Kodiak Database - Getting Started Guide

## Installation

### Prerequisites

- Mojo programming language (latest version)
- Python 3.8+ with PyArrow installed
- Linux/macOS/Windows (64-bit)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/dnErf/app-reference-26.git
cd app-reference-26/mojo-kodiak
```

2. Install Python dependencies:
```bash
pip install pyarrow
```

3. Build the database:
```bash
mojo build src/main.mojo
```

4. Run tests to verify installation:
```bash
cd src
./test_runner
```

## Your First Database

### Basic Operations

```mojo
from database import Database
from types import Row

fn main() raises:
    # Create database instance
    var db = Database()

    # Create a table
    db.create_table("users")

    # Insert some data
    var user1 = Row()
    user1["id"] = "1"
    user1["name"] = "Alice"
    user1["email"] = "alice@example.com"
    user1["age"] = "28"

    var user2 = Row()
    user2["id"] = "2"
    user2["name"] = "Bob"
    user2["email"] = "bob@example.com"
    user2["age"] = "32"

    db.insert_into_table("users", user1)
    db.insert_into_table("users", user2)

    # Query all users
    var users = db.select_all_from_table("users")
    print("Total users:", len(users))

    for user in users:
        print("User:", user["name"], "Email:", user["email"])
```

**Output:**
```
Total users: 2
User: Alice Email: alice@example.com
User: Bob Email: bob@example.com
```

### Working with Data Types

```mojo
from database import Database
from types import Row

fn main() raises:
    var db = Database()
    db.create_table("products")

    # Create product with various data types
    var product = Row()
    product["id"] = "1001"
    product["name"] = "Laptop"
    product["price"] = "999.99"
    product["in_stock"] = "true"
    product["category"] = "Electronics"
    product["rating"] = "4.5"

    db.insert_into_table("products", product)

    # Retrieve and work with different types
    var products = db.select_all_from_table("products")
    for prod in products:
        var name = prod.get_string("name")
        var price = prod.get_float("price")
        var in_stock = prod.get_bool("in_stock")
        var rating = prod.get_float("rating")

        print(name, "costs $", price, "Rating:", rating, "In stock:", in_stock)
```

## Advanced Examples

### Table Joins

```mojo
from database import Database
from types import Row

fn main() raises:
    var db = Database()

    # Create tables
    db.create_table("customers")
    db.create_table("orders")

    # Add customers
    var customer1 = Row()
    customer1["id"] = "1"
    customer1["name"] = "Alice"
    db.insert_into_table("customers", customer1)

    var customer2 = Row()
    customer2["id"] = "2"
    customer2["name"] = "Bob"
    db.insert_into_table("customers", customer2)

    # Add orders
    var order1 = Row()
    order1["id"] = "100"
    order1["customer_id"] = "1"
    order1["product"] = "Laptop"
    order1["amount"] = "999.99"
    db.insert_into_table("orders", order1)

    var order2 = Row()
    order2["id"] = "101"
    order2["customer_id"] = "1"
    order2["product"] = "Mouse"
    order2["amount"] = "29.99"
    db.insert_into_table("orders", order2)

    var order3 = Row()
    order3["id"] = "102"
    order3["customer_id"] = "2"
    order3["product"] = "Keyboard"
    order3["amount"] = "79.99"
    db.insert_into_table("orders", order3)

    # Join customers with their orders
    var customer_orders = db.join("customers", "orders", "id", "customer_id")

    print("Customer Orders:")
    for co in customer_orders:
        print(co["name"], "ordered", co["product"], "for $", co["amount"])
```

**Output:**
```
Customer Orders:
Alice ordered Laptop for $ 999.99
Alice ordered Mouse for $ 29.99
Bob ordered Keyboard for $ 79.99
```

### Using the Query Parser

```mojo
from database import Database
from extensions.query_parser import parse_query

fn main() raises:
    var db = Database()

    # Create table using query
    var create_query = parse_query("CREATE TABLE employees")
    db.execute_query(create_query)

    # Insert using query
    var insert_query = parse_query("INSERT INTO employees VALUES (1, 'John', 'Developer')")
    db.execute_query(insert_query)

    # Select using query
    var select_query = parse_query("SELECT * FROM employees")
    var results = db.execute_query(select_query)

    print("Employees:")
    for emp in results:
        print("ID:", emp["id"], "Name:", emp["name"], "Role:", emp["role"])
```

### Custom Functions

```mojo
from database import Database
from extensions.query_parser import parse_query

fn main() raises:
    var db = Database()

    # Create a custom function
    var func_query = parse_query("""
        CREATE FUNCTION calculate_bonus(salary: Float64) RETURNS Float64 {
            return salary * 0.1
        }
    """)
    db.execute_query(func_query)

    # Use the function
    var use_func = parse_query("SELECT calculate_bonus(50000)")
    var result = db.execute_query(use_func)

    if len(result) > 0:
        var bonus = result[0].get_float("calculate_bonus")
        print("Bonus amount: $", bonus)
```

## CLI Usage

### Basic Commands

```bash
# Start interactive REPL
./kodiak

# List available extensions
./kodiak extension list

# Get help
./kodiak --help
```

### REPL Examples

```sql
-- Create a table
CREATE TABLE projects;

-- Insert data
INSERT INTO projects VALUES (1, 'Website', 'In Progress');
INSERT INTO projects VALUES (2, 'Mobile App', 'Planning');

-- Query data
SELECT * FROM projects;

-- Create a function
CREATE FUNCTION status_count(status: String) RETURNS Int {
    -- Function implementation
};
```

## Data Import/Export

### Importing from CSV

```python
import pandas as pd

# Load CSV data
df = pd.read_csv('customers.csv')

# Convert to Feather format (Mojo Kodiak's native format)
df.to_feather('customers.feather')

# Data is automatically available in Mojo Kodiak
```

### Exporting Data

```mojo
from database import Database

fn export_to_csv(db: Database, table_name: String, filename: String) raises:
    var rows = db.select_all_from_table(table_name)

    # Convert to Python for CSV export
    var python_rows = []
    for row in rows:
        var py_row = {}
        for key in row.keys():
            py_row[key] = row[key]
        python_rows.append(py_row)

    # Use Python to write CSV
    var csv_module = Python.import_module("csv")
    # ... CSV writing logic ...
```

## Performance Optimization

### Indexing Strategy

```mojo
from database import Database
from types import Row

fn main() raises:
    var db = Database()

    # Create table with ID field (automatically indexed)
    db.create_table("articles")

    # Insert articles with IDs (triggers B+ tree indexing)
    for i in range(1, 1001):
        var article = Row()
        article["id"] = String(i)
        article["title"] = "Article " + String(i)
        article["content"] = "Content for article " + String(i)
        db.insert_into_table("articles", article)

    # Fast lookups by ID (O(log n) performance)
    # The B+ tree index makes this efficient
```

### Memory Management

```mojo
from database import Database

fn main() raises:
    var db = Database()

    # Configure memory settings
    db.memory_threshold = 200 * 1024 * 1024  # 200MB
    db.cache_max_size = 500  # Cache up to 500 queries

    # Monitor memory usage
    print("Memory usage:", db.memory_usage, "bytes")
    print("Cache hits:", db.cache_hits)
    print("Cache misses:", db.cache_misses)
```

## Error Handling

### Graceful Error Handling

```mojo
from database import Database
from types import Row

fn safe_operations() raises:
    var db = Database()

    # Safe table creation
    if db.create_table("users"):
        print("Table created successfully")
    else:
        print("Failed to create table")
        return

    # Safe insertion with error handling
    var user = Row()
    user["id"] = "1"
    user["name"] = "Alice"

    try:
        db.insert_into_table("users", user)
        print("User inserted successfully")
    except:
        print("Failed to insert user")

    # Safe querying
    try:
        var users = db.select_all_from_table("users")
        print("Found", len(users), "users")
    except:
        print("Failed to query users")
```

## Real-World Example: Blog System

```mojo
from database import Database
from types import Row

fn create_blog_system() raises:
    var db = Database()

    # Create tables
    db.create_table("posts")
    db.create_table("comments")
    db.create_table("users")

    # Add a user
    var user = Row()
    user["id"] = "1"
    user["username"] = "admin"
    user["email"] = "admin@blog.com"
    db.insert_into_table("users", user)

    # Add a blog post
    var post = Row()
    post["id"] = "1"
    post["title"] = "Welcome to Mojo Kodiak"
    post["content"] = "This is our first blog post using Mojo Kodiak database..."
    post["author_id"] = "1"
    post["published"] = "true"
    db.insert_into_table("posts", post)

    # Add comments
    var comment1 = Row()
    comment1["id"] = "1"
    comment1["post_id"] = "1"
    comment1["user_id"] = "1"
    comment1["content"] = "Great first post!"
    db.insert_into_table("comments", comment1)

    # Query blog with comments
    var blog_posts = db.join("posts", "comments", "id", "post_id")

    print("Blog Posts with Comments:")
    for item in blog_posts:
        print("Post:", item["title"])
        print("Comment:", item["content"])
        print("---")
```

## Next Steps

- Explore the [API Documentation](api.md) for detailed method references
- Check out the [Performance Guide](performance.md) for optimization tips
- Review the [Migration Guide](migration.md) for moving from other databases
- Join the community for support and contributions

Happy coding with Mojo Kodiak!