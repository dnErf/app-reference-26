# Mojo Kodiak Database - Migration Guide

## Overview

This guide helps you migrate your data and applications from other database systems to Mojo Kodiak. Mojo Kodiak uses Apache Feather format for data persistence, making it compatible with the broader data science ecosystem.

## Supported Source Databases

### Relational Databases
- SQLite
- PostgreSQL
- MySQL/MariaDB
- SQL Server
- Oracle Database

### NoSQL Databases
- MongoDB
- Cassandra
- DynamoDB
- Redis (key-value data)

### File Formats
- CSV
- JSON
- Parquet
- Feather
- Excel/Spreadsheet

## Migration Process

### Phase 1: Assessment
1. Analyze current database schema
2. Identify data volumes and access patterns
3. Determine migration scope (full vs. incremental)
4. Plan downtime requirements

### Phase 2: Data Export
1. Export data from source system
2. Transform data to Feather format
3. Validate data integrity
4. Test import process

### Phase 3: Application Migration
1. Update connection strings
2. Modify queries to Mojo Kodiak syntax
3. Update data types and schemas
4. Test application functionality

### Phase 4: Go-Live
1. Perform final data migration
2. Switch application to Mojo Kodiak
3. Monitor performance and stability
4. Plan rollback procedures

## Database-Specific Migrations

### From SQLite

#### Export Data
```python
import sqlite3
import pandas as pd

# Connect to SQLite database
conn = sqlite3.connect('your_database.db')

# Export each table to Feather format
tables = ['users', 'products', 'orders']  # Your table names

for table in tables:
    # Read table into DataFrame
    df = pd.read_sql_query(f"SELECT * FROM {table}", conn)

    # Convert data types to strings (Mojo Kodiak requirement)
    df = df.astype(str)

    # Save as Feather
    df.to_feather(f'{table}.feather')
    print(f"Exported {table}: {len(df)} rows")

conn.close()
```

#### Schema Migration
```sql
-- SQLite schema
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT,
    created_date DATETIME
);

-- Becomes Mojo Kodiak (all fields as strings)
-- id: "1"
-- name: "John Doe"
-- email: "john@example.com"
-- created_date: "2024-01-15 10:30:00"
```

#### Query Migration
```sql
-- SQLite queries
SELECT * FROM users WHERE id = 1;
INSERT INTO users (name, email) VALUES ('John', 'john@example.com');

-- Mojo Kodiak equivalent
var users = db.select_all_from_table("users")
// Filter in application code
for user in users:
    if user.get_int("id") == 1:
        // Process user

var new_user = Row()
new_user["name"] = "John"
new_user["email"] = "john@example.com"
db.insert_into_table("users", new_user)
```

### From PostgreSQL

#### Export with pg_dump and pandas
```python
import pandas as pd
import sqlalchemy as sa

# Connect to PostgreSQL
engine = sa.create_engine('postgresql://user:password@localhost:5432/database')

# Get all table names
tables_df = pd.read_sql_query("""
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
""", engine)

tables = tables_df['tablename'].tolist()

# Export each table
for table in tables:
    print(f"Exporting {table}...")

    # Read table
    df = pd.read_sql_table(table, engine)

    # Convert all columns to string
    df = df.astype(str)

    # Handle NULL values
    df = df.fillna('')

    # Save as Feather
    df.to_feather(f'{table}.feather')
    print(f"Exported {len(df)} rows")
```

#### Handle PostgreSQL-Specific Types
```python
import pandas as pd
from datetime import datetime

def convert_postgres_types(df):
    """Convert PostgreSQL types to Mojo Kodiak compatible strings"""

    for col in df.columns:
        # Convert timestamps to ISO format strings
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            df[col] = df[col].dt.strftime('%Y-%m-%d %H:%M:%S')

        # Convert arrays to JSON strings
        elif df[col].dtype == 'object':
            # Check if column contains arrays/lists
            sample = df[col].dropna().iloc[0] if len(df[col].dropna()) > 0 else None
            if isinstance(sample, list):
                import json
                df[col] = df[col].apply(lambda x: json.dumps(x) if isinstance(x, list) else str(x))

        # Convert everything else to string
        df[col] = df[col].astype(str)

    return df
```

### From MySQL/MariaDB

#### Export with mysqldump alternative
```python
import pandas as pd
import pymysql

# Connect to MySQL
conn = pymysql.connect(
    host='localhost',
    user='your_user',
    password='your_password',
    database='your_database'
)

# Get table list
cursor = conn.cursor()
cursor.execute("SHOW TABLES")
tables = [table[0] for table in cursor.fetchall()]

# Export each table
for table in tables:
    df = pd.read_sql(f"SELECT * FROM {table}", conn)

    # Convert types
    df = df.astype(str)
    df = df.fillna('')

    # Handle MySQL-specific encodings
    for col in df.columns:
        df[col] = df[col].str.encode('utf-8').str.decode('utf-8')

    df.to_feather(f'{table}.feather')
    print(f"Exported {table}")

conn.close()
```

### From MongoDB

#### Export Collections
```python
from pymongo import MongoClient
import pandas as pd
import json

# Connect to MongoDB
client = MongoClient('mongodb://localhost:27017/')
db = client['your_database']

# Get all collections
collections = db.list_collection_names()

for collection_name in collections:
    collection = db[collection_name]

    # Export to DataFrame
    documents = list(collection.find())
    df = pd.DataFrame(documents)

    # Remove MongoDB ObjectId
    if '_id' in df.columns:
        df = df.drop('_id', axis=1)

    # Convert nested objects to JSON strings
    for col in df.columns:
        if df[col].dtype == 'object':
            df[col] = df[col].apply(lambda x: json.dumps(x) if isinstance(x, dict) else str(x))

    # Convert to strings
    df = df.astype(str)
    df = df.fillna('')

    df.to_feather(f'{collection_name}.feather')
    print(f"Exported {collection_name}: {len(df)} rows")
```

### From CSV Files

#### Direct CSV Import
```python
import pandas as pd

# Read CSV
df = pd.read_csv('data.csv')

# Convert data types to strings
df = df.astype(str)

# Handle missing values
df = df.fillna('')

# Save as Feather
df.to_feather('data.feather')

print(f"Converted {len(df)} rows, {len(df.columns)} columns")
```

#### Handle Large CSV Files
```python
import pandas as pd

# For large files, process in chunks
chunk_size = 100000

reader = pd.read_csv('large_file.csv', chunksize=chunk_size)
chunk_num = 0

for chunk in reader:
    # Process chunk
    chunk = chunk.astype(str)
    chunk = chunk.fillna('')

    # Save chunk
    chunk.to_feather(f'data_chunk_{chunk_num}.feather')
    chunk_num += 1

print(f"Processed {chunk_num} chunks")
```

## Data Type Mapping

### SQL to Mojo Kodiak Types

| SQL Type | PostgreSQL | MySQL | Mojo Kodiak | Notes |
|----------|------------|-------|-------------|-------|
| INTEGER | int4, int8 | INT | String | Convert to string |
| VARCHAR/TEXT | varchar, text | VARCHAR | String | Already string |
| BOOLEAN | bool | TINYINT(1) | String | "true"/"false" |
| DECIMAL/NUMERIC | numeric | DECIMAL | String | Preserve precision |
| TIMESTAMP | timestamp | DATETIME | String | ISO format |
| DATE | date | DATE | String | YYYY-MM-DD |
| JSON/JSONB | jsonb | JSON | String | JSON string |
| ARRAY | int[] | N/A | String | JSON array string |
| BLOB | bytea | BLOB | String | Base64 encoded |

### Automatic Type Conversion
```python
import pandas as pd

def convert_to_mojo_types(df):
    """Convert DataFrame types to Mojo Kodiak compatible strings"""

    converters = {
        # Convert booleans
        'is_active': lambda x: str(bool(x)).lower(),
        'enabled': lambda x: str(bool(x)).lower(),

        # Convert numbers to strings while preserving precision
        'price': lambda x: f"{float(x):.2f}" if pd.notna(x) else "",
        'quantity': lambda x: str(int(float(x))) if pd.notna(x) else "",

        # Convert dates to ISO format
        'created_at': lambda x: pd.to_datetime(x).isoformat() if pd.notna(x) else "",
        'updated_at': lambda x: pd.to_datetime(x).isoformat() if pd.notna(x) else "",
    }

    for col in df.columns:
        if col in converters:
            df[col] = df[col].apply(converters[col])
        else:
            # Default: convert to string
            df[col] = df[col].astype(str)

    # Fill NaN values
    df = df.fillna('')

    return df
```

## Schema Migration

### Table Creation
```mojo
from database import Database

fn create_tables_from_schema(db: Database) raises:
    # Users table
    db.create_table("users")

    # Products table
    db.create_table("products")

    # Orders table
    db.create_table("orders")

    # Categories table
    db.create_table("categories")
```

### Index Creation
```mojo
# Note: ID fields are automatically indexed
# Future: Custom index support
# db.create_index("users", "email")
# db.create_index("products", "category_id")
# db.create_index("orders", "user_id", "created_at")
```

## Query Migration

### SELECT Queries

#### Simple Selection
```sql
-- SQL
SELECT * FROM users WHERE id = 1;

-- Mojo Kodiak
var users = db.select_all_from_table("users")
for user in users:
    if user.get_int("id") == 1:
        // Process user
```

#### JOIN Queries
```sql
-- SQL
SELECT u.name, o.amount
FROM users u
JOIN orders o ON u.id = o.user_id;

-- Mojo Kodiak
var user_orders = db.join("users", "orders", "id", "user_id")
for item in user_orders:
    print(item["name"], "ordered", item["amount"])
```

#### Aggregation Queries
```sql
-- SQL
SELECT COUNT(*) FROM users;
SELECT AVG(age) FROM users;

-- Mojo Kodiak (manual aggregation)
var users = db.select_all_from_table("users")
var count = len(users)
var total_age = 0
for user in users:
    total_age += user.get_int("age")
var avg_age = total_age / count
```

### INSERT Queries

#### Single Row Insert
```sql
-- SQL
INSERT INTO users (name, email) VALUES ('John', 'john@example.com');

-- Mojo Kodiak
var user = Row()
user["name"] = "John"
user["email"] = "john@example.com"
db.insert_into_table("users", user)
```

#### Batch Insert
```sql
-- SQL
INSERT INTO users (name, email) VALUES
('John', 'john@example.com'),
('Jane', 'jane@example.com');

-- Mojo Kodiak
var users = [
    ("John", "john@example.com"),
    ("Jane", "jane@example.com")
]

for user_data in users:
    var user = Row()
    user["name"] = user_data.get[0, String]()
    user["email"] = user_data.get[1, String]()
    db.insert_into_table("users", user)
```

### UPDATE Queries

#### Update Operations
```sql
-- SQL
UPDATE users SET email = 'new@example.com' WHERE id = 1;

-- Mojo Kodiak (read-modify-write)
var users = db.select_all_from_table("users")
// Note: This is a simplified example
// Production code would need proper update methods
```

## Application Code Migration

### Connection Management

#### Python Application
```python
# Before (SQLAlchemy)
from sqlalchemy import create_engine
engine = create_engine('postgresql://user:pass@localhost/db')

# After (Mojo Kodiak)
# Use subprocess to call Mojo Kodiak CLI
import subprocess
result = subprocess.run(['./kodiak', 'query', 'SELECT * FROM users'],
                       capture_output=True, text=True)
```

#### Go Application
```go
// Before (pq driver)
import "github.com/lib/pq"
db, err := sql.Open("postgres", "user=pass dbname=db")

// After (Mojo Kodiak)
// Use exec to call Mojo Kodiak
cmd := exec.Command("./kodiak", "query", "SELECT * FROM users")
output, err := cmd.Output()
```

### ORM Migration

#### Replace ORM Logic
```python
# Before (SQLAlchemy ORM)
user = User(name="John", email="john@example.com")
session.add(user)
session.commit()

# After (Mojo Kodiak)
# Direct data manipulation
import subprocess
import json

user_data = {"name": "John", "email": "john@example.com"}
# Call Mojo Kodiak to insert
# This is a simplified example - you'd build a proper client
```

## Testing Migration

### Data Validation
```python
import pandas as pd

def validate_migration(original_db, mojo_db_path):
    """Validate data integrity after migration"""

    # Compare row counts
    original_counts = get_table_counts(original_db)
    mojo_counts = get_mojo_table_counts(mojo_db_path)

    for table in original_counts:
        if original_counts[table] != mojo_counts.get(table, 0):
            print(f"Row count mismatch in {table}")

    # Spot check data samples
    for table in original_counts:
        original_sample = get_sample_data(original_db, table, 10)
        mojo_sample = get_mojo_sample_data(mojo_db_path, table, 10)

        if not samples_match(original_sample, mojo_sample):
            print(f"Data mismatch in {table}")

def get_table_counts(db_connection):
    """Get row counts for all tables"""
    # Implementation depends on source database
    pass

def get_mojo_table_counts(db_path):
    """Get row counts from Mojo Kodiak"""
    # Use CLI or direct file inspection
    pass
```

### Performance Validation
```python
import time

def benchmark_migration():
    """Compare query performance before/after migration"""

    # Test queries
    test_queries = [
        "SELECT COUNT(*) FROM users",
        "SELECT * FROM users WHERE id = 1",
        "SELECT u.name, COUNT(o.id) FROM users u LEFT JOIN orders o ON u.id = o.user_id GROUP BY u.id"
    ]

    print("Performance Comparison:")
    print("Query | Original | Mojo Kodiak | Ratio")
    print("-" * 50)

    for query in test_queries:
        # Time original database
        start = time.time()
        # run_original_query(query)
        original_time = time.time() - start

        # Time Mojo Kodiak
        start = time.time()
        # run_mojo_query(query)
        mojo_time = time.time() - start

        ratio = original_time / mojo_time if mojo_time > 0 else float('inf')

        print(f"{query[:30]}... | {original_time:.3f}s | {mojo_time:.3f}s | {ratio:.1f}x")
```

## Rollback Planning

### Backup Strategy
```bash
# Create backups before migration
cp -r /path/to/original/database /backup/pre_migration/

# Backup Mojo Kodiak data
cp -r /path/to/mojo-kodiak/data /backup/mojo_data/

# Application config backup
cp /path/to/app/config.yml /backup/app_config.yml
```

### Rollback Procedure
```bash
#!/bin/bash
# rollback.sh

echo "Starting rollback to original database..."

# Stop application
systemctl stop myapp

# Restore original database
cp -r /backup/pre_migration/* /path/to/original/database/

# Restore application config
cp /backup/app_config.yml /path/to/app/config.yml

# Start application
systemctl start myapp

echo "Rollback complete. Verify application functionality."
```

## Common Issues and Solutions

### Data Type Issues

**Problem**: Numeric precision loss during conversion
**Solution**: Use string representation to preserve exact values

**Problem**: Date format inconsistencies
**Solution**: Standardize on ISO 8601 format (YYYY-MM-DDTHH:MM:SS)

### Encoding Issues

**Problem**: Character encoding problems during export
**Solution**:
```python
# Force UTF-8 encoding
df[col] = df[col].str.encode('utf-8').str.decode('utf-8')
```

### Memory Issues

**Problem**: Large tables cause memory exhaustion
**Solution**:
```python
# Process in chunks
for chunk in pd.read_csv('large_file.csv', chunksize=100000):
    process_chunk(chunk)
```

### Performance Issues

**Problem**: Slow migration of large datasets
**Solution**:
- Use parallel processing
- Optimize export queries
- Consider incremental migration

## Post-Migration Optimization

### Index Optimization
```mojo
// Future: Add custom indexes for query patterns
// db.create_index("orders", "customer_id", "order_date")
// db.create_index("products", "category", "price")
```

### Query Optimization
```mojo
// Use efficient data structures
// Cache frequently accessed data
// Implement query result caching
```

### Monitoring Setup
```mojo
// Monitor performance metrics
print("Query count:", db.query_count)
print("Cache hit rate:", calculate_hit_rate(db))

// Set up alerts for performance degradation
```

## Support and Resources

### Getting Help
- Check the [documentation](api.md) for detailed API reference
- Review [performance guide](performance.md) for optimization tips
- Join the community Discord for support

### Professional Services
For large-scale migrations or complex scenarios, consider:
- Consulting services for migration planning
- Custom migration tools development
- Performance optimization services
- Training and documentation services

## Success Metrics

### Migration KPIs
- **Data Accuracy**: 100% data integrity maintained
- **Downtime**: Minimal application downtime
- **Performance**: Query performance within 10% of original
- **Cost**: Migration completed within budget
- **User Impact**: No user-facing issues during transition

### Post-Migration Monitoring
- Query performance trends
- Error rates and types
- Resource utilization
- User satisfaction scores

This migration guide covers the most common scenarios. For your specific use case, consider creating a detailed migration plan with thorough testing before executing the migration.