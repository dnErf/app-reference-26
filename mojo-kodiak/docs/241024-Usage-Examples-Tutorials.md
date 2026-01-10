# Mojo Kodiak Database - Usage Examples & Tutorials

## Quick Start Tutorial

### 1. Installation & Setup

First, ensure you have the Mojo SDK installed. Then build Mojo Kodiak:

```bash
cd /path/to/mojo-kodiak
mojo build src/main.mojo
```

### 2. Creating Your First Database

```bash
# Create a new database
./kodiak create mydb

# Open the database
./kodiak open mydb
```

### 3. Basic Operations

#### Creating Tables

```bash
# Enter REPL mode
./kodiak repl

# Create a users table
kodiak> CREATE TABLE users (id INTEGER, name TEXT, email TEXT);

# Create a products table
kodiak> CREATE TABLE products (id INTEGER, name TEXT, price REAL, category TEXT);
```

#### Inserting Data

```bash
# Insert user records
kodiak> INSERT INTO users VALUES (1, 'Alice Johnson', 'alice@example.com');
kodiak> INSERT INTO users VALUES (2, 'Bob Smith', 'bob@example.com');
kodiak> INSERT INTO users VALUES (3, 'Carol Davis', 'carol@example.com');

# Insert product records
kodiak> INSERT INTO products VALUES (1, 'Laptop', 999.99, 'Electronics');
kodiak> INSERT INTO products VALUES (2, 'Book', 19.99, 'Education');
kodiak> INSERT INTO products VALUES (3, 'Headphones', 79.99, 'Electronics');
```

#### Querying Data

```bash
# Select all users
kodiak> SELECT * FROM users;

# Select specific columns
kodiak> SELECT name, email FROM users;

# Filter with conditions
kodiak> SELECT * FROM users WHERE id = 1;

# Query products by category
kodiak> SELECT name, price FROM products WHERE category = 'Electronics';
```

## Advanced Examples

### Working with Extensions

```bash
# List available extensions
./kodiak extension list

# Install the SCM extension for schema versioning
./kodiak extension install scm

# Use SCM commands
./kodiak scm init
./kodiak scm add users
./kodiak scm commit "Add users table"
./kodiak scm status
```

### Complex Queries

```bash
# Create related tables
kodiak> CREATE TABLE orders (id INTEGER, user_id INTEGER, product_id INTEGER, quantity INTEGER);
kodiak> CREATE TABLE reviews (id INTEGER, product_id INTEGER, user_id INTEGER, rating INTEGER, comment TEXT);

# Insert sample data
kodiak> INSERT INTO orders VALUES (1, 1, 1, 2);
kodiak> INSERT INTO orders VALUES (2, 2, 3, 1);
kodiak> INSERT INTO reviews VALUES (1, 1, 1, 5, 'Great laptop!');
kodiak> INSERT INTO reviews VALUES (2, 3, 2, 4, 'Good sound quality');

# Query with joins (future feature)
# SELECT u.name, p.name, o.quantity
# FROM users u, products p, orders o
# WHERE u.id = o.user_id AND p.id = o.product_id;
```

### Data Import/Export

```bash
# Export table to CSV (future feature)
# ./kodiak export users users.csv

# Import from CSV (future feature)
# ./kodiak import products.csv products
```

## Tutorial: Building a Blog System

### Step 1: Database Design

```bash
./kodiak create blogdb
./kodiak open blogdb
./kodiak repl
```

```sql
-- Create authors table
CREATE TABLE authors (
    id INTEGER,
    name TEXT,
    email TEXT,
    bio TEXT
);

-- Create posts table
CREATE TABLE posts (
    id INTEGER,
    title TEXT,
    content TEXT,
    author_id INTEGER,
    published_date TEXT,
    status TEXT
);

-- Create comments table
CREATE TABLE comments (
    id INTEGER,
    post_id INTEGER,
    author_name TEXT,
    content TEXT,
    created_date TEXT
);

-- Create categories table
CREATE TABLE categories (
    id INTEGER,
    name TEXT,
    description TEXT
);

-- Create post_categories junction table
CREATE TABLE post_categories (
    post_id INTEGER,
    category_id INTEGER
);
```

### Step 2: Insert Sample Data

```sql
-- Add authors
INSERT INTO authors VALUES (1, 'John Writer', 'john@blog.com', 'Tech enthusiast and blogger');
INSERT INTO authors VALUES (2, 'Jane Developer', 'jane@blog.com', 'Full-stack developer');

-- Add categories
INSERT INTO categories VALUES (1, 'Technology', 'Latest in tech');
INSERT INTO categories VALUES (2, 'Programming', 'Coding tutorials');
INSERT INTO categories VALUES (3, 'Database', 'Data management topics');

-- Add posts
INSERT INTO posts VALUES (1, 'Introduction to Mojo', 'Mojo is a new programming language...', 1, '2024-01-15', 'published');
INSERT INTO posts VALUES (2, 'Database Design Principles', 'Good database design is crucial...', 2, '2024-01-20', 'published');
INSERT INTO posts VALUES (3, 'SQL Best Practices', 'Writing efficient SQL queries...', 1, '2024-01-25', 'draft');

-- Link posts to categories
INSERT INTO post_categories VALUES (1, 1);
INSERT INTO post_categories VALUES (1, 2);
INSERT INTO post_categories VALUES (2, 3);
INSERT INTO post_categories VALUES (3, 2);
INSERT INTO post_categories VALUES (3, 3);

-- Add comments
INSERT INTO comments VALUES (1, 1, 'Tech Fan', 'Great introduction!', '2024-01-16');
INSERT INTO comments VALUES (2, 1, 'Coder', 'Looking forward to more posts', '2024-01-17');
INSERT INTO comments VALUES (3, 2, 'DB Admin', 'Very helpful article', '2024-01-21');
```

### Step 3: Query the Blog Data

```sql
-- Get all published posts with author info
SELECT p.title, a.name, p.published_date
FROM posts p, authors a
WHERE p.author_id = a.id AND p.status = 'published';

-- Get posts by category
SELECT p.title, c.name as category
FROM posts p, categories c, post_categories pc
WHERE p.id = pc.post_id AND c.id = pc.category_id;

-- Get comment count per post
SELECT p.title, COUNT(c.id) as comment_count
FROM posts p
LEFT JOIN comments c ON p.id = c.post_id
GROUP BY p.id, p.title;

-- Get recent comments
SELECT c.content, c.author_name, p.title
FROM comments c, posts p
WHERE c.post_id = p.id
ORDER BY c.created_date DESC
LIMIT 5;
```

## Performance Optimization Examples

### Indexing Strategy

```bash
-- Create indexes on frequently queried columns
CREATE INDEX idx_posts_author ON posts (author_id);
CREATE INDEX idx_posts_status ON posts (status);
CREATE INDEX idx_comments_post ON comments (post_id);
```

### Query Optimization

```sql
-- Use selective conditions first
SELECT * FROM posts
WHERE status = 'published' AND published_date > '2024-01-01';

-- Avoid full table scans
SELECT COUNT(*) FROM posts;  -- Fast with metadata
SELECT * FROM posts;         -- Full scan - use sparingly
```

## Extension Development Tutorial

### Creating a Custom Extension

1. Create a new Mojo file in `src/extensions/`

```mojo
from database import Database

struct AnalyticsExtension:
    var db: Database

    fn init(mut self, db: Database) -> Bool:
        self.db = db
        print("Analytics extension initialized")
        return True

    fn execute(self, command: String, args: List[String]) -> String:
        if command == "stats":
            return self.get_table_stats()
        elif command == "usage":
            return self.get_usage_stats()
        else:
            return "Unknown analytics command: " + command

    fn get_table_stats(self) -> String:
        var result = "Table Statistics:\n"
        for table_name in self.db.tables.keys():
            var table = self.db.tables[table_name]
            result += table_name + ": " + String(table.rows.size) + " rows\n"
        return result

    fn get_usage_stats(self) -> String:
        return "Usage statistics not yet implemented"
```

2. Register the extension in the main database

```mojo
// In main.mojo or database.mojo
fn register_analytics_extension(db: Database):
    var metadata = ExtensionMetadata(
        name: "analytics",
        version: "1.0.0",
        description: "Database analytics and statistics",
        status: ExtensionStatus.loaded,
        path: ""
    )
    db.extension_registry["analytics"] = metadata
```

3. Use the extension

```bash
./kodiak extension install analytics
./kodiak analytics stats
```

## Migration Examples

### Migrating from CSV Files

```python
# Python script to import CSV data
import csv
import subprocess

def import_csv_to_kodiak(csv_file, table_name):
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)

        # Create table from CSV headers
        headers = reader.fieldnames
        schema_parts = []
        for header in headers:
            if header.lower().endswith('_id') or header.lower() in ['id', 'count']:
                schema_parts.append(f"{header} INTEGER")
            else:
                schema_parts.append(f"{header} TEXT")

        schema = ", ".join(schema_parts)
        create_cmd = f"CREATE TABLE {table_name} ({schema});"

        # Execute create command
        subprocess.run(["./kodiak", "exec", create_cmd])

        # Insert data
        for row in reader:
            values = []
            for header in headers:
                value = row[header].strip()
                if value.isdigit():
                    values.append(value)
                else:
                    values.append(f"'{value}'")

            values_str = ", ".join(values)
            insert_cmd = f"INSERT INTO {table_name} VALUES ({values_str});"
            subprocess.run(["./kodiak", "exec", insert_cmd])

# Usage
import_csv_to_kodiak("users.csv", "users")
```

### Migrating from JSON

```python
import json
import subprocess

def import_json_to_kodiak(json_file, table_name):
    with open(json_file, 'r') as f:
        data = json.load(f)

    if not data:
        return

    # Infer schema from first record
    first_record = data[0]
    schema_parts = []
    for key, value in first_record.items():
        if isinstance(value, int):
            schema_parts.append(f"{key} INTEGER")
        elif isinstance(value, float):
            schema_parts.append(f"{key} REAL")
        else:
            schema_parts.append(f"{key} TEXT")

    schema = ", ".join(schema_parts)
    create_cmd = f"CREATE TABLE {table_name} ({schema});"
    subprocess.run(["./kodiak", "exec", create_cmd])

    # Insert all records
    for record in data:
        values = []
        for key in first_record.keys():
            value = record.get(key, "")
            if isinstance(value, (int, float)):
                values.append(str(value))
            else:
                values.append(f"'{str(value)}'")

        values_str = ", ".join(values)
        insert_cmd = f"INSERT INTO {table_name} VALUES ({values_str});"
        subprocess.run(["./kodiak", "exec", insert_cmd])

# Usage
import_json_to_kodiak("products.json", "products")
```

## Best Practices

### Database Design

1. **Use appropriate data types**: INTEGER for IDs, TEXT for strings, REAL for decimals
2. **Normalize when necessary**: Avoid data duplication
3. **Index foreign keys**: Speed up joins and lookups
4. **Use descriptive names**: Clear table and column names

### Query Optimization

1. **Filter early**: Use WHERE clauses to reduce data volume
2. **Select only needed columns**: Avoid `SELECT *`
3. **Use indexes**: Create indexes on frequently filtered columns
4. **Limit results**: Use LIMIT for large datasets

### Performance Monitoring

```bash
# Check database health
./kodiak health

# Monitor memory usage
./kodiak status

# View query performance (future feature)
./kodiak profile "SELECT * FROM large_table"
```

### Backup and Recovery

```bash
# Create backup
cp mydb.db mydb_backup.db

# Verify backup integrity
./kodiak open mydb_backup
./kodiak status
```

This tutorial covers the essential concepts and patterns for working with Mojo Kodiak Database. For more advanced features, refer to the API documentation.