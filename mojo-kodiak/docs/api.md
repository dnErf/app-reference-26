# Mojo Kodiak Database - API Documentation

## Overview

Mojo Kodiak is a high-performance database system built with the Mojo programming language. It combines in-memory operations with persistent storage, advanced indexing, and extensible architecture.

## Core Components

### Database Class

The main entry point for all database operations.

#### Initialization

```mojo
from database import Database

var db = Database()
```

**Parameters**: None

**Returns**: Initialized Database instance

**Notes**:
- Automatically initializes PyArrow for data persistence
- Sets up threading locks for concurrent access
- Initializes WAL, block store, and indexing systems

#### Table Operations

##### create_table(name: String) -> Bool

Creates a new table in the database.

```mojo
var success = db.create_table("users")
```

**Parameters**:
- `name`: String - The name of the table to create

**Returns**: Bool - True if successful, False otherwise

**Example**:
```mojo
if db.create_table("products"):
    print("Table created successfully")
else:
    print("Failed to create table")
```

##### insert_into_table(table_name: String, row: Row) raises

Inserts a new row into the specified table.

```mojo
var user = Row()
user["id"] = "1"
user["name"] = "Alice"
user["email"] = "alice@example.com"
db.insert_into_table("users", user)
```

**Parameters**:
- `table_name`: String - The name of the table
- `row`: Row - The row data to insert

**Raises**: Error if table doesn't exist or insertion fails

**Notes**:
- Automatically indexes rows with ID fields using B+ tree
- Persists data using Feather format via PyArrow

##### select_all_from_table(table_name: String) -> List[Row]

Retrieves all rows from the specified table.

```mojo
var users = db.select_all_from_table("users")
for user in users:
    print("User:", user["name"])
```

**Parameters**:
- `table_name`: String - The name of the table

**Returns**: List[Row] - All rows in the table

**Raises**: Error if table doesn't exist

##### join(table1: String, table2: String, col1: String, col2: String) -> List[Row]

Performs an inner join between two tables.

```mojo
var user_orders = db.join("users", "orders", "id", "user_id")
```

**Parameters**:
- `table1`: String - First table name
- `table2`: String - Second table name
- `col1`: String - Join column in first table
- `col2`: String - Join column in second table

**Returns**: List[Row] - Joined result rows

**Notes**:
- Currently supports inner joins only
- Results contain columns from both tables

### Row Class

Represents a single row of data with key-value pairs.

#### Initialization

```mojo
from types import Row

var row = Row()
```

#### Field Operations

##### Setting Fields

```mojo
row["id"] = "123"
row["name"] = "Alice"
row["active"] = "true"
```

**Notes**: All values must be strings. Convert numbers and booleans to strings.

##### Getting Fields

```mojo
var name = row["name"]  // Returns String
var id = row.get_string("id")
var count = row.get_int("count")
var active = row.get_bool("active")
var score = row.get_float("score")
```

**Available Getters**:
- `get_string(key: String) -> String`
- `get_int(key: String) -> Int`
- `get_bool(key: String) -> Bool`
- `get_float(key: String) -> Float64`

##### Field Existence

```mojo
if "email" in row:
    print("Email field exists")

if row.has_field("phone"):
    print("Phone field is present")
```

##### Field Iteration

```mojo
for field_name in row.keys():
    var value = row[field_name]
    print(field_name + ": " + value)
```

### B+ Tree Index

Automatic indexing system for fast lookups.

#### Search Operations

```mojo
// Note: Direct B+ tree access is typically internal
// Indexing happens automatically during inserts
```

**Notes**: B+ tree indexing is transparent to users and happens automatically for rows with ID fields.

## Extension System

### Built-in Extensions

Mojo Kodiak includes several built-in extensions:

- **core**: Core database functionality
- **storage**: Storage layer management
- **indexing**: Indexing operations
- **query**: Query processing
- **transactions**: Transaction management
- **backup**: Backup and recovery
- **monitoring**: Performance monitoring

### Extension Commands

#### List Extensions

```bash
./kodiak extension list
```

Displays all registered extensions with their status.

#### Install Extension

```bash
./kodiak extension install <name>
```

Installs a new extension (placeholder for future implementation).

#### Uninstall Extension

```bash
./kodiak extension uninstall <name>
```

Removes an installed extension (placeholder for future implementation).

## Query System

### Basic Queries

Mojo Kodiak supports basic SQL-like queries through the query parser.

#### SELECT Queries

```mojo
from extensions.query_parser import parse_query

var query = parse_query("SELECT * FROM users")
var results = db.execute_query(query)
```

#### INSERT Queries

```mojo
var insert_query = parse_query("INSERT INTO users VALUES (1, 'Alice', 'alice@example.com')")
db.execute_query(insert_query)
```

#### CREATE TABLE Queries

```mojo
var create_query = parse_query("CREATE TABLE products")
db.execute_query(create_query)
```

### Advanced Features

#### Functions

```mojo
var func_query = parse_query("CREATE FUNCTION greet() RETURNS TEXT { return 'Hello World' }")
db.execute_query(func_query)
```

#### Types

```mojo
var type_query = parse_query("CREATE TYPE User STRUCT { id: Int, name: String }")
db.execute_query(type_query)
```

## Storage Architecture

### Multi-Layer Storage

1. **In-Memory**: Fast access for active data
2. **Block Store**: Persistent block-based storage
3. **WAL (Write-Ahead Log)**: Transaction durability
4. **Feather Format**: Columnar storage via PyArrow

### Indexing

- **B+ Tree**: Primary indexing for ID-based lookups
- **Fractal Tree**: Advanced indexing for complex queries
- **Automatic**: Transparent indexing on insert operations

## Configuration

### Default Settings

- **Cache Size**: 100 query results
- **Max Connections**: 10 concurrent connections
- **Memory Threshold**: 100MB cleanup trigger
- **Block Size**: Optimized for Feather format

### Configuration File

Configuration is loaded from `config.json` in the working directory.

```json
{
  "max_connections": 20,
  "cache_size": 200,
  "memory_threshold": 200
}
```

## Error Handling

### Common Errors

- **TableNotFound**: Attempting to access non-existent table
- **InvalidQuery**: Malformed query syntax
- **StorageError**: Disk I/O or persistence failures
- **MemoryError**: Out of memory conditions

### Error Recovery

- Automatic WAL replay on startup
- Transaction rollback on failures
- Graceful degradation for non-critical errors

## Performance Characteristics

### Benchmarks

- **Insert Rate**: ~1000+ rows/second (depends on hardware)
- **Query Rate**: ~5000+ queries/second for simple selects
- **Join Performance**: Scales with data size, optimized for memory
- **Memory Usage**: ~50MB base + ~1KB per row

### Optimization Tips

1. Use appropriate data types (strings for all fields)
2. Index frequently queried columns (automatic for IDs)
3. Batch operations when possible
4. Monitor memory usage for large datasets

## Migration Guide

### From Other Databases

#### SQLite

```python
# SQLite to Mojo Kodiak migration
import sqlite3
import pyarrow as pa

# Export from SQLite
conn = sqlite3.connect('old.db')
df = pd.read_sql_query("SELECT * FROM users", conn)
table = pa.Table.from_pandas(df)
table.to_feather('users.feather')

# Import to Mojo Kodiak
db = Database()
# Data automatically loaded from feather files
```

#### PostgreSQL/MySQL

```python
# Export via pandas
import pandas as pd
import sqlalchemy as sa

engine = sa.create_engine('postgresql://user:pass@localhost/db')
df = pd.read_sql_table('users', engine)
df.to_feather('users.feather')
```

### Data Format Conversion

Mojo Kodiak uses Feather format for persistence. Convert your data:

```python
import pandas as pd

# From CSV
df = pd.read_csv('data.csv')
df.to_feather('data.feather')

# From JSON
df = pd.read_json('data.json')
df.to_feather('data.feather')

# From Parquet
df = pd.read_parquet('data.parquet')
df.to_feather('data.feather')
```

## Best Practices

### Schema Design

1. Use string IDs for consistency
2. Keep row sizes reasonable (< 1MB)
3. Use descriptive column names
4. Plan for data growth

### Query Optimization

1. Use indexed fields in WHERE clauses
2. Limit result sets when possible
3. Batch inserts for bulk operations
4. Monitor query performance

### Memory Management

1. Set appropriate memory thresholds
2. Monitor cache hit rates
3. Clean up unused connections
4. Use streaming for large datasets

### Backup Strategy

1. Regular automated backups
2. Test restore procedures
3. Keep multiple backup versions
4. Monitor backup success/failure

## Troubleshooting

### Common Issues

#### Slow Queries
- Check if fields are indexed
- Verify query syntax
- Monitor memory usage
- Consider data partitioning

#### Memory Issues
- Increase memory threshold
- Reduce cache size
- Monitor connection count
- Check for memory leaks

#### Storage Issues
- Verify disk space
- Check file permissions
- Monitor I/O performance
- Validate Feather file integrity

### Debug Mode

Enable debug logging:

```mojo
db.config["debug"] = "true"
```

### Performance Monitoring

Access performance metrics:

```mojo
print("Query count:", db.query_count)
print("Avg query time:", db.total_query_time / db.query_count)
print("Cache hits:", db.cache_hits)
print("Cache misses:", db.cache_misses)
```

## API Reference

### Database Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `create_table` | `name: String` | `Bool` | Create new table |
| `insert_into_table` | `table: String, row: Row` | `Void` | Insert row |
| `select_all_from_table` | `table: String` | `List[Row]` | Get all rows |
| `join` | `t1, t2, c1, c2: String` | `List[Row]` | Join tables |
| `execute_query` | `query: Query` | `List[Row]` | Execute parsed query |

### Row Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `__getitem__` | `key: String` | `String` | Get field value |
| `__setitem__` | `key, value: String` | `Void` | Set field value |
| `get_string` | `key: String` | `String` | Get string field |
| `get_int` | `key: String` | `Int` | Get int field |
| `get_bool` | `key: String` | `Bool` | Get bool field |
| `get_float` | `key: String` | `Float64` | Get float field |
| `has_field` | `key: String` | `Bool` | Check field exists |
| `keys` | - | `List[String]` | Get all field names |

### Extension Methods

| Command | Parameters | Description |
|---------|------------|-------------|
| `extension list` | - | List all extensions |
| `extension install` | `name: String` | Install extension |
| `extension uninstall` | `name: String` | Uninstall extension |

This documentation covers the core API. For advanced features, see the extension-specific documentation.