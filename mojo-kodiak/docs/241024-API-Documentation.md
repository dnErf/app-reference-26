# Mojo Kodiak Database - API Documentation

## Overview

Mojo Kodiak is a high-performance, extensible database written in the Mojo programming language with Python interop capabilities. It provides in-memory and persistent storage with advanced indexing, SQL query processing, and a modular extension system.

## Core Architecture

### Database Class

The main entry point for database operations.

```mojo
struct Database:
    var name: String
    var tables: Dict[String, Table]
    var block_store: BlockStore
    var extension_registry: Dict[String, ExtensionMetadata]
    var b_plus_tree: BPlusTree
```

#### Key Methods

- `create_table(name: String, schema: Dict[String, String]) -> Bool`
  - Creates a new table with the specified schema
  - Returns true on success, false if table already exists

- `insert(table_name: String, row: Row) -> Bool`
  - Inserts a row into the specified table
  - Returns true on success, false on failure

- `select(table_name: String, conditions: Optional[Dict[String, String]] = None) -> List[Row]`
  - Selects rows from a table with optional conditions
  - Returns list of matching rows

- `save_to_disk() -> Bool`
  - Persists all tables to disk using PyArrow Feather format
  - Returns true on success

- `load_from_disk() -> Bool`
  - Loads all tables from disk
  - Returns true on success

### Table Structure

```mojo
struct Table:
    var name: String
    var schema: Dict[String, String]
    var rows: List[Row]
    var file_path: String
```

### Row Structure

```mojo
struct Row:
    var id: Int
    var data: Dict[String, String]
```

## Extension System

### Extension Metadata

```mojo
struct ExtensionMetadata:
    var name: String
    var version: String
    var description: String
    var status: ExtensionStatus
    var path: String
```

### Extension Management

Extensions can be managed through the CLI:

```bash
# List all extensions
kodiak extension list

# Install an extension
kodiak extension install <name>

# Uninstall an extension
kodiak extension uninstall <name>
```

## Query Processing

### SQL Parser

Supports basic SQL syntax:

```sql
CREATE TABLE users (id INTEGER, name TEXT, email TEXT);
INSERT INTO users VALUES (1, 'John Doe', 'john@example.com');
SELECT * FROM users WHERE id = 1;
```

### Query Execution

Queries are parsed and executed through the REPL:

```mojo
# In REPL mode
kodiak> CREATE TABLE test (id INTEGER, name TEXT);
kodiak> INSERT INTO test VALUES (1, 'Hello');
kodiak> SELECT * FROM test;
```

## Storage Engine

### Block Storage

- Uses PyArrow Feather format for columnar persistence
- Automatic saving on create/insert operations
- Efficient storage for analytical workloads

### Indexing

- B+ Tree implementation for fast lookups
- Automatic indexing on ID fields
- Optimized for range queries and sorting

## CLI Commands

### Database Operations

```bash
# Create a new database
kodiak create <name>

# Open existing database
kodiak open <name>

# Show database status
kodiak status
```

### Table Operations

```bash
# List tables
kodiak tables

# Show table schema
kodiak schema <table_name>

# Show table data
kodiak data <table_name>
```

### REPL Mode

```bash
# Enter interactive mode
kodiak repl

# Execute SQL commands
kodiak> SELECT * FROM users;
```

## Extension API

### Creating Extensions

Extensions are Mojo modules that implement specific interfaces:

```mojo
struct MyExtension:
    fn init(db: Database) -> Bool:
        # Initialize extension
        return True

    fn execute(command: String, args: List[String]) -> String:
        # Execute extension command
        return "Result"
```

### Built-in Extensions

- **SCM**: Source control management for database schemas
- **Health**: Database health monitoring and diagnostics

## Performance Characteristics

- **In-Memory Operations**: Sub-millisecond query response
- **Persistent Storage**: PyArrow Feather format for fast I/O
- **Indexing**: B+ Tree with O(log n) lookup complexity
- **Memory Usage**: Efficient data structures with minimal overhead

## Error Handling

All operations return boolean success indicators. Detailed error information is available through:

- CLI error messages
- REPL error reporting
- Extension-specific error handling

## Thread Safety

Current implementation is single-threaded. Future versions will include:

- Concurrent query execution
- Lock-free data structures
- Transaction isolation

## Python Interop

Full Python integration through Mojo's Python interop:

```mojo
from python import Python

# Use Python libraries
py_dict = Python.dict()
py_dict["key"] = "value"
```

## Development

### Building

```bash
mojo build src/main.mojo
```

### Testing

```bash
mojo run test/test_runner.mojo
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes
4. Add tests
5. Submit pull request

## Migration Guide

### From SQLite

```sql
-- SQLite syntax
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);

-- Mojo Kodiak equivalent
CREATE TABLE users (id INTEGER, name TEXT);
```

### From PostgreSQL

```sql
-- PostgreSQL syntax
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(255));

-- Mojo Kodiak equivalent
CREATE TABLE users (id INTEGER, name TEXT);
```

## Troubleshooting

### Common Issues

1. **Compilation Errors**: Ensure Mojo SDK is properly installed
2. **Import Errors**: Check PYTHONPATH for Python dependencies
3. **Memory Issues**: Monitor heap usage in long-running processes

### Debug Mode

Enable debug logging:

```bash
export MOJO_DEBUG=1
kodiak <command>
```

## License

Mojo Kodiak is open source software licensed under the Apache 2.0 License.