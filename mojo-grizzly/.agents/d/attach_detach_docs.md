# Attach/Detach Ecosystem Documentation

## Overview
The Attach/Detach Ecosystem allows Mojo-Grizzly to connect to external databases and execute cross-database queries. This enables federated database operations, where you can query data from multiple .grz files or execute SQL scripts as virtual tables.

## Commands

### ATTACH
Attach an external database or SQL script to the current session.

#### Syntax
```
ATTACH 'path/to/file' AS alias
```

#### Examples
```sql
-- Attach a .grz database file
ATTACH 'external_db.grz' AS ext_db

-- Attach a SQL script as a virtual table
ATTACH 'create_table.sql' AS virtual_table
```

#### Behavior
- For .grz files: Loads the Parquet or AVRO formatted database into memory with the given alias
- For .sql files: Executes the SQL script and stores the result table with the given alias
- If alias already exists, the command fails
- If file not found or invalid format, prints error message

### DETACH
Remove an attached database from the session.

#### Syntax
```
DETACH alias
```

#### Examples
```sql
DETACH ext_db
```

#### Behavior
- Removes the table associated with the alias from the registry
- If alias not found, prints error message

## Cross-Database Queries

### Syntax
```sql
-- Query attached database directly
SELECT * FROM alias

-- Query specific table in attached database (if supported)
SELECT * FROM alias.table

-- Join across databases
SELECT * FROM local_table l JOIN attached_db a ON l.id = a.id
```

### Examples
```sql
-- Attach databases
ATTACH 'sales.grz' AS sales
ATTACH 'inventory.grz' AS inv

-- Query attached database
SELECT * FROM sales WHERE revenue > 1000

-- Cross-database join
SELECT s.product, i.quantity
FROM sales s
JOIN inv i ON s.product_id = i.product_id
```

## Implementation Details

### Registry
- Attached databases are stored in a global `Dict[String, Table]` called `tables`
- The registry persists for the session duration
- Tables are loaded into memory for fast access

### File Formats
- .grz files: Parquet (ColumnStore) or AVRO (RowStore) format
- .sql files: Executed as SQL scripts, result stored as table

### Error Handling
- File not found: Prints "Failed to load path"
- Invalid format: Read functions raise exceptions, caught and printed
- Duplicate alias: Prints "Alias already exists"
- Missing alias on DETACH: Prints "Alias not found"

### Performance
- Attached tables are loaded into memory
- Cross-database queries use the same execution engine as local queries
- No additional indexing or optimization for attached tables

## Limitations
- Only supports .grz (Parquet/AVRO) and .sql files
- Tables must fit in memory
- No persistent registry across sessions
- No support for remote databases (yet)