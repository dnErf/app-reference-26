# Mojo Kodiak Database - Migration Guides

## Overview

This guide provides step-by-step instructions for migrating data and applications from other database systems to Mojo Kodiak. Each migration path includes data export, schema conversion, and application code updates.

## Migration from SQLite

### Step 1: Export SQLite Schema

```bash
# Dump schema to SQL file
sqlite3 your_database.db .schema > schema.sql

# Export data to CSV files
sqlite3 your_database.db -header -csv "SELECT * FROM users;" > users.csv
sqlite3 your_database.db -header -csv "SELECT * FROM products;" > products.csv
# Repeat for each table
```

### Step 2: Convert Schema to Mojo Kodiak

SQLite schema conversion:

```sql
-- SQLite schema (schema.sql)
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    age INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Mojo Kodiak equivalent
CREATE TABLE users (
    id INTEGER,
    name TEXT,
    email TEXT,
    age INTEGER,
    created_at TEXT
);
```

**Key Differences:**
- Remove `PRIMARY KEY AUTOINCREMENT` (use manual ID assignment)
- Remove `NOT NULL` constraints (not yet supported)
- Remove `UNIQUE` constraints (not yet supported)
- Convert `DATETIME` to `TEXT`
- Remove `DEFAULT CURRENT_TIMESTAMP` (use application logic)

### Step 3: Import Data to Mojo Kodiak

```bash
# Create Mojo Kodiak database
./kodiak create migrated_db
./kodiak open migrated_db

# Import schema
./kodiak exec < schema_mojokodiak.sql

# Import CSV data (using Python helper)
python3 import_csv.py users.csv users
python3 import_csv.py products.csv products
```

### Step 4: Update Application Code

```python
# Before (SQLite)
import sqlite3

conn = sqlite3.connect('your_database.db')
cursor = conn.cursor()

# Insert data
cursor.execute("INSERT INTO users (name, email) VALUES (?, ?)", ('John', 'john@example.com'))
conn.commit()

# Query data
cursor.execute("SELECT * FROM users WHERE id = ?", (1,))
result = cursor.fetchone()

# After (Mojo Kodiak)
import subprocess

# Insert data
subprocess.run([
    './kodiak', 'exec',
    "INSERT INTO users VALUES (1, 'John', 'john@example.com', 25, '2024-01-01')"
])

# Query data (using JSON output - future feature)
# result = subprocess.run(['./kodiak', 'query', 'SELECT * FROM users WHERE id = 1'],
#                        capture_output=True, text=True)
# data = json.loads(result.stdout)
```

## Migration from PostgreSQL

### Step 1: Export PostgreSQL Data

```bash
# Export schema
pg_dump --schema-only --no-owner your_database > schema.sql

# Export data to CSV
psql your_database -c "COPY users TO 'users.csv' WITH CSV HEADER;"
psql your_database -c "COPY products TO 'products.csv' WITH CSV HEADER;"
```

### Step 2: Convert PostgreSQL Schema

```sql
-- PostgreSQL schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    age INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB
);

-- Mojo Kodiak equivalent
CREATE TABLE users (
    id INTEGER,
    name TEXT,
    email TEXT,
    age INTEGER,
    created_at TEXT,
    metadata TEXT
);
```

**Key Conversions:**
- `SERIAL` → `INTEGER` (manual ID management)
- `VARCHAR(n)` → `TEXT`
- `TIMESTAMP` → `TEXT`
- `JSONB` → `TEXT` (store as JSON string)
- Remove all constraints and defaults

### Step 3: Handle Sequences and Serials

```sql
-- PostgreSQL: Auto-incrementing IDs
-- Mojo Kodiak: Manual ID management

-- Find max ID and increment manually
-- SELECT MAX(id) + 1 FROM users;
```

### Step 4: PostgreSQL Application Migration

```python
# Before (PostgreSQL with psycopg2)
import psycopg2

conn = psycopg2.connect("dbname=your_database user=your_user")
cursor = conn.cursor()

# Insert with returning
cursor.execute("""
    INSERT INTO users (name, email, age)
    VALUES (%s, %s, %s)
    RETURNING id
""", ('John', 'john@example.com', 25))
user_id = cursor.fetchone()[0]

# JSON operations
cursor.execute("SELECT metadata->>'key' FROM users WHERE id = %s", (user_id,))

# After (Mojo Kodiak)
import subprocess
import json

# Insert (manual ID management)
next_id = get_next_id('users')  # Implement this function
subprocess.run([
    './kodiak', 'exec',
    f"INSERT INTO users VALUES ({next_id}, 'John', 'john@example.com', 25, '{datetime.now().isoformat()}', '{{\"key\": \"value\"}}')"
])

# JSON operations (manual parsing)
# result = query_single(f"SELECT metadata FROM users WHERE id = {user_id}")
# metadata = json.loads(result)
# value = metadata.get('key')
```

## Migration from MySQL

### Step 1: Export MySQL Data

```bash
# Export schema
mysqldump --no-data your_database > schema.sql

# Export data to CSV
mysql -e "SELECT * FROM users INTO OUTFILE 'users.csv' FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" your_database
mysql -e "SELECT * FROM products INTO OUTFILE 'products.csv' FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" your_database
```

### Step 2: Convert MySQL Schema

```sql
-- MySQL schema
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    age INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    FOREIGN KEY (department_id) REFERENCES departments(id)
) ENGINE=InnoDB;

-- Mojo Kodiak equivalent
CREATE TABLE users (
    id INTEGER,
    name TEXT,
    email TEXT,
    age INTEGER,
    created_at TEXT
);
```

**Key Conversions:**
- `INT AUTO_INCREMENT` → `INTEGER`
- `VARCHAR(n)` → `TEXT`
- `TIMESTAMP` → `TEXT`
- Remove `ENGINE`, `INDEX`, `FOREIGN KEY` (not yet supported)

### Step 3: Handle Auto-Increment

```sql
-- MySQL: AUTO_INCREMENT
-- Mojo Kodiak: Application-level ID generation

# Python helper for ID generation
def get_next_id(table_name):
    # Query max ID and increment
    result = subprocess.run([
        './kodiak', 'query', f'SELECT MAX(id) FROM {table_name}'
    ], capture_output=True, text=True)
    max_id = int(result.stdout.strip()) if result.stdout.strip() else 0
    return max_id + 1
```

### Step 4: MySQL Application Migration

```python
# Before (MySQL with mysql-connector)
import mysql.connector

conn = mysql.connector.connect(
    host="localhost",
    user="your_user",
    password="your_password",
    database="your_database"
)
cursor = conn.cursor()

# Insert with lastrowid
cursor.execute("""
    INSERT INTO users (name, email, age)
    VALUES (%s, %s, %s)
""", ('John', 'john@example.com', 25))
user_id = cursor.lastrowid

# After (Mojo Kodiak)
import subprocess

# Insert with manual ID
next_id = get_next_id('users')
subprocess.run([
    './kodiak', 'exec',
    f"INSERT INTO users VALUES ({next_id}, 'John', 'john@example.com', 25, '{datetime.now().isoformat()}')"
])
```

## Migration from MongoDB

### Step 1: Export MongoDB Data

```bash
# Export collections to JSON
mongoexport --db your_database --collection users --out users.json
mongoexport --db your_database --collection products --out products.json
```

### Step 2: Design Relational Schema

```sql
-- MongoDB document structure
{
    "_id": ObjectId("..."),
    "name": "John Doe",
    "email": "john@example.com",
    "addresses": [
        {"type": "home", "street": "123 Main St"},
        {"type": "work", "street": "456 Office Blvd"}
    ],
    "metadata": {"last_login": "2024-01-01", "preferences": {...}}
}

-- Mojo Kodiak relational schema
CREATE TABLE users (
    id INTEGER,
    name TEXT,
    email TEXT,
    addresses TEXT,  -- JSON string
    metadata TEXT    -- JSON string
);

CREATE TABLE user_addresses (
    id INTEGER,
    user_id INTEGER,
    type TEXT,
    street TEXT
);
```

### Step 3: Transform and Import Data

```python
import json
import subprocess

def migrate_mongodb_collection(json_file, table_name, transform_func):
    with open(json_file, 'r') as f:
        for line in f:
            doc = json.loads(line)
            # Transform MongoDB document to relational format
            row = transform_func(doc)
            # Insert into Mojo Kodiak
            values = ', '.join(f"'{v}'" if isinstance(v, str) else str(v) for v in row.values())
            subprocess.run(['./kodiak', 'exec', f'INSERT INTO {table_name} VALUES ({values})'])

def transform_user(doc):
    return {
        'id': int(str(doc['_id']), 16) % 1000000,  # Simple ID generation
        'name': doc.get('name', ''),
        'email': doc.get('email', ''),
        'addresses': json.dumps(doc.get('addresses', [])),
        'metadata': json.dumps(doc.get('metadata', {}))
    }

# Migrate users collection
migrate_mongodb_collection('users.json', 'users', transform_user)
```

## Migration from CSV/Excel Files

### Step 1: Prepare Data Files

```bash
# Ensure CSV files have headers
head -1 data.csv  # Should show: id,name,email,age

# Clean data if necessary
# Remove quotes, fix encoding, handle NULLs
```

### Step 2: Create Schema

```sql
-- Infer schema from CSV
-- id,name,email,age → INTEGER,TEXT,TEXT,INTEGER

CREATE TABLE imported_data (
    id INTEGER,
    name TEXT,
    email TEXT,
    age INTEGER
);
```

### Step 3: Import CSV Data

```python
import csv
import subprocess

def import_csv_to_mojokodiak(csv_file, table_name):
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)

        for row in reader:
            # Convert empty strings to NULL or appropriate defaults
            values = []
            for value in row.values():
                if value == '':
                    values.append('NULL')
                elif value.isdigit():
                    values.append(value)
                else:
                    values.append(f"'{value}'")

            values_str = ', '.join(values)
            subprocess.run([
                './kodiak', 'exec',
                f'INSERT INTO {table_name} VALUES ({values_str})'
            ])

import_csv_to_mojokodiak('data.csv', 'imported_data')
```

## Application Code Migration Patterns

### Connection Management

```python
# Before: Connection pooling
# pool = psycopg2.pool.SimpleConnectionPool(1, 20, dsn)

# After: Process-based execution
import subprocess

class MojoKodiakClient:
    def __init__(self, db_path):
        self.db_path = db_path

    def execute(self, query):
        result = subprocess.run([
            './kodiak', 'exec', query
        ], capture_output=True, text=True, cwd=self.db_path)
        return result.returncode == 0

    def query(self, query):
        # Future: JSON output support
        # For now, use file-based approach
        pass

client = MojoKodiakClient('./my_database/')
```

### Transaction Management

```python
# Before: ACID transactions
# with conn.cursor() as cursor:
#     cursor.execute("BEGIN")
#     cursor.execute("INSERT INTO users ...")
#     cursor.execute("INSERT INTO logs ...")
#     cursor.execute("COMMIT")

# After: Application-level transactions (future feature)
# For now: Execute all statements together
def execute_transaction(queries):
    all_queries = '; '.join(queries)
    return subprocess.run(['./kodiak', 'exec', all_queries]).returncode == 0

queries = [
    "INSERT INTO users VALUES (1, 'John', 'john@example.com')",
    "INSERT INTO logs VALUES (1, 'User created', '2024-01-01')"
]
execute_transaction(queries)
```

### ORM Migration

```python
# Before: SQLAlchemy/PostgreSQL
# from sqlalchemy import create_engine
# engine = create_engine('postgresql://user:pass@localhost/db')
# session = Session(engine)

# After: Custom ORM layer
class MojoKodiakORM:
    def __init__(self, db_path):
        self.db_path = db_path
        self._id_counters = {}

    def get_next_id(self, table):
        if table not in self._id_counters:
            # Query max ID
            result = subprocess.run([
                './kodiak', 'query', f'SELECT MAX(id) FROM {table}'
            ], capture_output=True, text=True, cwd=self.db_path)
            self._id_counters[table] = int(result.stdout.strip() or '0')
        self._id_counters[table] += 1
        return self._id_counters[table]

    def insert(self, table, data):
        id_field = f'id INTEGER, ' if 'id' not in data else ''
        fields = ', '.join(data.keys())
        values = ', '.join(f"'{v}'" if isinstance(v, str) else str(v) for v in data.values())

        query = f'INSERT INTO {table} ({fields}) VALUES ({values})'
        return subprocess.run(['./kodiak', 'exec', query], cwd=self.db_path).returncode == 0

orm = MojoKodiakORM('./my_database/')
user_data = {'name': 'John', 'email': 'john@example.com'}
orm.insert('users', user_data)
```

## Performance Considerations

### Batch Operations

```python
# Import large datasets efficiently
def batch_import(csv_file, table_name, batch_size=1000):
    batch = []
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            batch.append(row)
            if len(batch) >= batch_size:
                # Execute batch insert
                execute_batch(batch, table_name)
                batch = []

    # Execute remaining
    if batch:
        execute_batch(batch, table_name)
```

### Indexing Strategy

```sql
-- Create indexes after bulk import for better performance
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_created_at ON users (created_at);

-- Analyze query patterns and create appropriate indexes
-- - Foreign key columns
-- - Frequently filtered columns
-- - Columns used in ORDER BY
```

## Testing Migration

### Data Validation

```python
def validate_migration(original_db, mojokodiak_db):
    # Compare row counts
    orig_count = query_count(original_db, 'users')
    new_count = query_count(mojokodiak_db, 'users')
    assert orig_count == new_count, f"Row count mismatch: {orig_count} vs {new_count}"

    # Spot check data integrity
    sample_orig = query_sample(original_db, 'users', 10)
    sample_new = query_sample(mojokodiak_db, 'users', 10)
    # Compare samples

    # Validate constraints (application-level)
    validate_unique_emails(mojokodiak_db)
    validate_foreign_keys(mojokodiak_db)
```

### Performance Validation

```python
def benchmark_migration():
    # Test common queries
    queries = [
        "SELECT * FROM users WHERE id = 1",
        "SELECT COUNT(*) FROM users WHERE age > 25",
        "SELECT * FROM users ORDER BY created_at DESC LIMIT 10"
    ]

    for query in queries:
        time_mojokodiak = benchmark_query(mojokodiak_db, query)
        time_original = benchmark_query(original_db, query)
        print(f"{query}: {time_original:.2f}s → {time_mojokodiak:.2f}s")
```

## Rollback Planning

### Backup Strategy

```bash
# Create backups before migration
cp -r original_database/ backup/

# For Mojo Kodiak: Copy database directory
cp -r mojokodiak_db/ mojokodiak_backup/
```

### Rollback Procedure

```bash
# If migration fails, restore from backup
rm -rf mojokodiak_db/
cp -r mojokodiak_backup/ mojokodiak_db/

# Or switch back to original database
# Update application configuration
# Restart application services
```

## Common Migration Challenges

### Data Type Mismatches

- **Solution**: Create transformation functions for each data type
- **Example**: Convert PostgreSQL `TIMESTAMP` to ISO format strings

### Constraint Differences

- **Solution**: Implement application-level constraints
- **Example**: Check uniqueness in application code

### Transaction Scope

- **Solution**: Group related operations and execute together
- **Example**: Use batch execution for multi-table operations

### Performance Degradation

- **Solution**: Create appropriate indexes and optimize queries
- **Example**: Add indexes on frequently queried columns

This migration guide provides comprehensive strategies for moving from various database systems to Mojo Kodiak. Each migration path requires careful planning and testing to ensure data integrity and application compatibility.