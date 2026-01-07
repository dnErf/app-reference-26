# Grizzly Database CLI Commands Design

## Overview
The Grizzly Database CLI provides a SQLite/DuckDB-like interactive interface for columnar data operations. Commands are designed to be intuitive for SQL users while supporting advanced columnar database features.

## Command Categories

### 1. Data Loading Commands

#### LOAD SAMPLE DATA
**Syntax:** `LOAD SAMPLE DATA`
**Description:** Loads built-in sample data for testing and demonstrations
**Example:**
```
grizzly> LOAD SAMPLE DATA
Executing: LOAD SAMPLE DATA
```
**Output:** Loads 3 sample user records (Alice:25, Bob:30, Charlie:35)

#### LOAD JSONL
**Syntax:** `LOAD JSONL 'filename.jsonl'`
**Description:** Loads data from a JSONL (JSON Lines) file
**Status:** ✅ Implemented
**Example:**
```
grizzly> LOAD JSONL 'sample_data.jsonl'
Executing: LOAD JSONL 'sample_data.jsonl'
Loaded 1000 rows from sample_data.jsonl
```
**Error Handling:**
- File not found: "Error loading file: [error message]"
- Invalid syntax: "Usage: LOAD JSONL 'filename.jsonl'"

#### LOAD PARQUET
**Syntax:** `LOAD PARQUET 'filename.parquet'`
**Description:** Loads data from a Parquet file (columnar format)
**Status:** 🔄 Planned
**Example:**
```
grizzly> LOAD PARQUET 'data.parquet'
Executing: LOAD PARQUET 'data.parquet'
Loaded 50000 rows from data.parquet
```

#### LOAD AVRO
**Syntax:** `LOAD AVRO 'filename.avro'`
**Description:** Loads data from an Avro file
**Status:** 🔄 Planned
**Example:**
```
grizzly> LOAD AVRO 'data.avro'
Executing: LOAD AVRO 'data.avro'
Loaded 25000 rows from data.avro
```

#### LOAD CSV
**Syntax:** `LOAD CSV 'filename.csv' [DELIMITER ','] [HEADER]`
**Description:** Loads data from a CSV file with optional delimiter and header detection
**Status:** 🔄 Planned
**Examples:**
```
grizzly> LOAD CSV 'data.csv'
grizzly> LOAD CSV 'data.tsv' DELIMITER '\t'
grizzly> LOAD CSV 'data.csv' HEADER
```

### 2. SQL Query Commands

#### SELECT * FROM table
**Syntax:** `SELECT * FROM table`
**Description:** Displays all rows and columns from the loaded table
**Status:** ✅ Implemented
**Example:**
```
grizzly> SELECT * FROM table
Executing: SELECT * FROM table
Query result:
Found 3 rows
Row 0 : id = 1 , name = User1 , age = 25
Row 1 : id = 2 , name = User2 , age = 30
Row 2 : id = 3 , name = User3 , age = 35
```

#### SELECT COUNT(*) FROM table
**Syntax:** `SELECT COUNT(*) FROM table`
**Description:** Returns the total number of rows in the table
**Status:** ✅ Implemented
**Example:**
```
grizzly> SELECT COUNT(*) FROM table
Executing: SELECT COUNT(*) FROM table
Query result: Found 3 rows
```

#### Aggregate Functions
**Syntax:** `SELECT {SUM|AVG|MIN|MAX|PERCENTILE}(column) FROM table`
**Description:** Performs aggregate calculations on numeric columns
**Status:** ✅ Implemented (SUM, AVG, MIN, MAX, PERCENTILE)
**Examples:**
```
grizzly> SELECT SUM(age) FROM table
Query result: Sum = 90

grizzly> SELECT AVG(age) FROM table
Query result: Average = 30.0

grizzly> SELECT PERCENTILE(age, 0.5) FROM table
Query result: 50th percentile = 30
```

#### SELECT with WHERE clause
**Syntax:** `SELECT * FROM table WHERE condition`
**Description:** Filters rows based on conditions
**Status:** ✅ Implemented (basic conditions)
**Example:**
```
grizzly> SELECT * FROM table WHERE age > 25
Executing: SELECT * FROM table WHERE age > 25
Query result:
Found 2 rows (Bob: 30, Charlie: 35)
Row 0: id = 2, name = Bob, age = 30
Row 1: id = 3, name = Charlie, age = 35
```

#### Advanced SQL (Planned)
**Status:** 🔄 Future Implementation
**Examples:**
```
SELECT column1, column2 FROM table
SELECT * FROM table ORDER BY column
SELECT * FROM table LIMIT 10
SELECT * FROM table GROUP BY category
SELECT * FROM table1 JOIN table2 ON table1.id = table2.id
```

### 3. Table Management Commands

#### SHOW TABLES
**Syntax:** `SHOW TABLES`
**Description:** Lists all available tables in the database
**Status:** ✅ Implemented
**Example:**
```
grizzly> SHOW TABLES
Executing: SHOW TABLES
Tables: 1 defined
Available tables: users, products
```

#### DESCRIBE TABLE
**Syntax:** `DESCRIBE table_name` or `DESC table_name`
**Description:** Shows the schema/structure of a table
**Status:** 🔄 Planned
**Example:**
```
grizzly> DESCRIBE users
Table: users
Columns:
  id: Int64
  name: String
  age: Int32
  email: String
```

#### CREATE TABLE
**Syntax:** `CREATE TABLE table_name (col1 type, col2 type, ...)`
**Description:** Creates a new table with specified schema
**Status:** 🔄 Planned
**Example:**
```
grizzly> CREATE TABLE users (id INT, name STRING, age INT)
Table 'users' created successfully
```

#### DROP TABLE
**Syntax:** `DROP TABLE table_name`
**Description:** Removes a table and all its data
**Status:** 🔄 Planned
**Example:**
```
grizzly> DROP TABLE temp_data
Table 'temp_data' dropped
```

#### INSERT INTO
**Syntax:** `INSERT INTO table_name VALUES (val1, val2, ...)`
**Description:** Adds new rows to a table
**Status:** 🔄 Planned
**Example:**
```
grizzly> INSERT INTO users VALUES (4, 'Diana', 28)
1 row inserted
```

#### UPDATE
**Syntax:** `UPDATE table_name SET col=val WHERE condition`
**Description:** Modifies existing rows
**Status:** 🔄 Planned
**Example:**
```
grizzly> UPDATE users SET age=29 WHERE name='Diana'
1 row updated
```

#### DELETE FROM
**Syntax:** `DELETE FROM table_name WHERE condition`
**Description:** Removes rows from a table
**Status:** 🔄 Planned
**Example:**
```
grizzly> DELETE FROM users WHERE age < 21
2 rows deleted
```

### 4. Data Export Commands

#### SAVE AS
**Syntax:** `SAVE table_name AS 'filename.format'`
**Description:** Exports table data to various formats
**Status:** 🔄 Planned
**Examples:**
```
grizzly> SAVE users AS 'users.jsonl'
grizzly> SAVE products AS 'products.parquet'
grizzly> SAVE sales AS 'sales.csv'
```

#### EXPORT
**Syntax:** `EXPORT query TO 'filename.format'`
**Description:** Exports query results to a file
**Status:** 🔄 Planned
**Example:**
```
grizzly> EXPORT SELECT * FROM users WHERE age > 25 TO 'adults.jsonl'
```

### 5. System and Utility Commands

#### HELP
**Syntax:** `HELP` or `?`
**Description:** Shows available commands and usage examples
**Status:** ✅ Implemented
**Example:**
```
grizzly> HELP
Available commands:
  LOAD SAMPLE DATA    - Load sample user data
  LOAD JSONL 'file'   - Load data from JSONL file
  SELECT ...          - Run SQL queries (full SQL support)
  SHOW TABLES         - Show available tables
  HELP                - Show this help
  EXIT                - Quit REPL

SQL Examples:
  SELECT * FROM table
  SELECT COUNT(*) FROM table
  SELECT SUM(age) FROM table
  SELECT AVG(age) FROM table
  SELECT MIN(age) FROM table
  SELECT MAX(age) FROM table
  SELECT PERCENTILE(age, 0.5) FROM table
  SELECT * FROM table WHERE age > 25

File Loading Examples:
  LOAD JSONL 'sample_data.jsonl'
  LOAD PARQUET 'data.parquet'
  LOAD AVRO 'data.avro'
```

#### EXIT / QUIT
**Syntax:** `EXIT` or `QUIT`
**Description:** Exits the REPL
**Status:** ✅ Implemented
**Example:**
```
grizzly> EXIT
Goodbye!
```

#### CLEAR
**Syntax:** `CLEAR` or `CLS`
**Description:** Clears the terminal screen
**Status:** 🔄 Planned

#### HISTORY
**Syntax:** `HISTORY`
**Description:** Shows command history
**Status:** 🔄 Planned
**Example:**
```
grizzly> HISTORY
1: LOAD SAMPLE DATA
2: SELECT * FROM table
3: SELECT COUNT(*) FROM table
```

### 6. Advanced Features (Future)

#### ANALYZE
**Syntax:** `ANALYZE table_name`
**Description:** Analyzes table statistics for query optimization
**Status:** 🔄 Future
**Example:**
```
grizzly> ANALYZE users
Table analysis complete. Statistics updated.
```

#### EXPLAIN
**Syntax:** `EXPLAIN query`
**Description:** Shows query execution plan
**Status:** 🔄 Future
**Example:**
```
grizzly> EXPLAIN SELECT * FROM users WHERE age > 25
Execution Plan:
  1. Scan table 'users'
  2. Filter by age > 25
  3. Return results
```

#### CREATE INDEX
**Syntax:** `CREATE INDEX idx_name ON table_name (column)`
**Description:** Creates an index for faster queries
**Status:** 🔄 Future
**Example:**
```
grizzly> CREATE INDEX idx_age ON users (age)
Index created on users.age
```

#### BACKUP / RESTORE
**Syntax:** `BACKUP TO 'filename.griz'` / `RESTORE FROM 'filename.griz'`
**Description:** Database backup and restore operations using native .griz format
**Status:** 🔄 Future
**Examples:**
```
grizzly> BACKUP TO 'backup_2026.griz'
Database backed up to backup_2026.griz

grizzly> RESTORE FROM 'backup_2026.griz'
Database restored from backup_2026.griz
```

## Database File Management (.griz Format)

### Overview
The `.griz` file is Grizzly's native database file format, providing persistent storage for tables, schemas, indexes, and metadata. Similar to SQLite's `.db` files, `.griz` files are self-contained, cross-platform, and support ACID transactions.

### .griz File Structure

#### File Header (64 bytes)
```
Offset 0-7:   Magic bytes "GRIZZDB" (8 bytes)
Offset 8-11:  Version number (4 bytes, e.g., 0x00010000 for v1.0.0)
Offset 12-15: Page size in bytes (4 bytes, default 4096)
Offset 16-19: File format version (4 bytes)
Offset 20-23: Reserved (4 bytes)
Offset 24-31: Creation timestamp (8 bytes, Unix epoch)
Offset 32-39: Last modified timestamp (8 bytes, Unix epoch)
Offset 40-47: Database size in pages (8 bytes)
Offset 48-55: Free page list head (8 bytes)
Offset 56-63: Schema page number (8 bytes)
```

#### Page Types
- **Data Pages**: Store columnar table data
- **Schema Pages**: Table definitions, column types, constraints
- **Index Pages**: B-tree indexes for fast lookups
- **Free Pages**: Available space for reuse
- **WAL Pages**: Write-Ahead Logging for transactions
- **Metadata Pages**: Database statistics, configuration

#### Data Storage Format
- **Columnar Storage**: Each column stored separately for efficient analytics
- **Compression**: Automatic compression using LZ4 or ZSTD
- **Null Handling**: Bitmap-based null value tracking
- **Type Safety**: Strong typing with schema validation

### Database Management Commands

#### CREATE DATABASE
**Syntax:** `CREATE DATABASE 'filename.griz'`
**Description:** Creates a new empty .griz database file
**Status:** 🔄 Planned
**Example:**
```
grizzly> CREATE DATABASE 'mydb.griz'
Database 'mydb.griz' created successfully
```

#### ATTACH DATABASE
**Syntax:** `ATTACH DATABASE 'filename.griz' [AS alias]`
**Description:** Attaches a .griz database file for querying. If no alias is provided, attaches as the main database.
**Status:** 🔄 Planned
**Examples:**
```
grizzly> ATTACH DATABASE 'mydb.griz'
Database 'mydb.griz' attached as main database. 5 tables loaded.

grizzly> ATTACH DATABASE 'analytics.griz' AS analytics
Database attached as 'analytics'
```

#### DETACH DATABASE
**Syntax:** `DETACH DATABASE [alias]`
**Description:** Detaches a database. If no alias is provided, detaches the main database.
**Status:** 🔄 Planned
**Examples:**
```
grizzly> DETACH DATABASE analytics
Database 'analytics' detached

grizzly> DETACH DATABASE
Main database detached
```

#### SHOW DATABASES
**Syntax:** `SHOW DATABASES`
**Description:** Lists all attached databases
**Status:** 🔄 Planned
**Example:**
```
grizzly> SHOW DATABASES
Attached databases:
  main: mydb.griz (5 tables)
  analytics: analytics.griz (12 tables)
```

#### DATABASE INFO
**Syntax:** `DATABASE INFO [alias]` or `DBINFO [alias]`
**Description:** Shows detailed information about a database. If no alias is provided, shows info for the main database.
**Status:** 🔄 Planned
**Example:**
```
grizzly> DATABASE INFO
Database: mydb.griz (main)
Version: 1.0.0
Created: 2026-01-07 10:30:00
Size: 2.5 MB (640 pages)
Tables: 5
Indexes: 8
Compression: LZ4
Page Size: 4096 bytes
```

### .griz File Operations

#### Vacuum
**Syntax:** `VACUUM`
**Description:** Reclaims unused space and optimizes database file
**Status:** 🔄 Future
**Example:**
```
grizzly> VACUUM
Database vacuumed. Reclaimed 45 MB of space.
```

#### Integrity Check
**Syntax:** `PRAGMA integrity_check`
**Description:** Verifies database file integrity
**Status:** 🔄 Future
**Example:**
```
grizzly> PRAGMA integrity_check
Integrity check passed. No errors found.
```

#### Optimize
**Syntax:** `PRAGMA optimize`
**Description:** Runs optimization passes on the database
**Status:** 🔄 Future
**Example:**
```
grizzly> PRAGMA optimize
Database optimized. 3 indexes rebuilt, statistics updated.
```

### Transaction Support

#### BEGIN TRANSACTION
**Syntax:** `BEGIN` or `BEGIN TRANSACTION`
**Description:** Starts a new transaction
**Status:** 🔄 Future
**Example:**
```
grizzly> BEGIN
Transaction started
```

#### COMMIT
**Syntax:** `COMMIT` or `COMMIT TRANSACTION`
**Description:** Commits the current transaction
**Status:** 🔄 Future
**Example:**
```
grizzly> COMMIT
Transaction committed
```

#### ROLLBACK
**Syntax:** `ROLLBACK` or `ROLLBACK TRANSACTION`
**Description:** Rolls back the current transaction
**Status:** 🔄 Future
**Example:**
```
grizzly> ROLLBACK
Transaction rolled back
```

### Advanced .griz Features

#### Write-Ahead Logging (WAL)
- **Automatic**: Enabled by default for crash recovery
- **Checkpointing**: Periodic WAL consolidation
- **Concurrent Readers**: Multiple read transactions during writes

#### Encryption Support
**Syntax:** `PRAGMA encryption_key = 'key'`
**Description:** Enables encryption for the database file
**Status:** 🔄 Future

#### Compression Options
**Syntax:** `PRAGMA compression = {none|lz4|zstd|snappy}`
**Description:** Sets the compression algorithm for data storage
**Status:** 🔄 Future

#### Memory Mapping
**Syntax:** `PRAGMA mmap_size = bytes`
**Description:** Enables memory-mapped I/O for better performance
**Status:** 🔄 Future

### .griz vs Other Formats

| Feature | .griz | SQLite .db | Parquet | JSONL |
|---------|-------|------------|---------|-------|
| ACID Transactions | ✅ | ✅ | ❌ | ❌ |
| Columnar Storage | ✅ | ❌ | ✅ | ❌ |
| Schema Enforcement | ✅ | ✅ | ❌ | ❌ |
| Indexes | ✅ | ✅ | ❌ | ❌ |
| Compression | ✅ | ❌ | ✅ | ❌ |
| Cross-Platform | ✅ | ✅ | ✅ | ✅ |
| Query Performance | 🏆 | ⚡ | 🏆 | 🐌 |
| File Size | 📏 | 📏 | 🗜️ | 📈 |

### Migration Commands

#### IMPORT FROM
**Syntax:** `IMPORT FROM 'source.db' [AS sqlite|duckdb|postgres]`
**Description:** Imports data from other database formats
**Status:** 🔄 Future
**Example:**
```
grizzly> IMPORT FROM 'old.db' AS sqlite
Imported 5 tables, 10000 rows from SQLite database
```

#### EXPORT TO
**Syntax:** `EXPORT TO 'target.db' [AS sqlite|duckdb|postgres]`
**Description:** Exports data to other database formats
**Status:** 🔄 Future
**Example:**
```
grizzly> EXPORT TO 'backup.db' AS sqlite
Exported 5 tables to SQLite format
```

### Performance Characteristics

#### Query Performance
- **Columnar Scans**: 5-10x faster than row-based for analytics
- **Predicate Pushdown**: Filters applied during scan
- **Vectorized Execution**: SIMD operations on columnar data
- **Index Usage**: B-tree indexes for selective queries

#### Storage Efficiency
- **Compression Ratios**: 70-90% size reduction typical
- **Null Storage**: Bitmap compression for sparse data
- **Dictionary Encoding**: Automatic for low-cardinality columns

#### Concurrency
- **MVCC**: Multi-Version Concurrency Control
- **Reader/Writer Locks**: Fine-grained locking
- **WAL Mode**: Concurrent readers during writes

This .griz format provides a modern, efficient database file format optimized for analytical workloads while maintaining the simplicity and reliability of traditional database files.

## Command Processing Rules

### Case Insensitivity
- Commands are case-insensitive: `SELECT`, `select`, `Select` all work
- Table names and column names are case-sensitive
- String literals preserve case

### Quoting Rules
- Single quotes for file paths: `'filename.jsonl'`
- Double quotes for string literals: `"John's data"`
- Backticks for identifiers: `` `column-name` ``

### Error Handling
- Invalid syntax: Shows usage message
- File not found: Descriptive error message
- Query errors: Clear error description with suggestions
- Unknown commands: Lists available commands

### Auto-completion (Future)
- Tab completion for commands and table names
- Context-aware suggestions
- Command history navigation with arrow keys

## Interactive Mode Features

### Prompt
```
grizzly>
```
Shows current database state and readiness for input

### Multi-line Commands
- Commands ending with `\` continue on next line
- `;` terminates multi-line commands

### Output Formatting
- Query results show row count first
- Columnar display for readability
- Truncated output for large results with "..." indicator

### Session Management
- Commands persist across session
- Loaded data remains available
- Table definitions maintained

## Command-Line Interface Modes

### Overview
Grizzly supports multiple execution modes to accommodate different use cases, from interactive exploration to automated batch processing. Users can choose the appropriate mode based on their workflow.

### Interactive REPL Mode (Default)
**Usage:** `grizzly` or `grizzly repl`
**Description:** Interactive command-line interface for exploratory data analysis
**Best For:** Learning, debugging, ad-hoc queries, development
**Example:**
```bash
$ grizzly
=== Grizzly Database REPL ===
Similar to SQLite/DuckDB - Type SQL commands!

grizzly> LOAD SAMPLE DATA
grizzly> SELECT * FROM table
grizzly> EXIT
```

### Batch Mode
**Usage:** `grizzly < script.sql` or `grizzly -c "SELECT * FROM table"`
**Description:** Execute SQL commands from files or command-line arguments
**Best For:** Automation, CI/CD, scheduled jobs, one-off queries
**Examples:**
```bash
# Execute from file
$ grizzly < queries.sql

# Execute single command
$ grizzly -c "SELECT COUNT(*) FROM users"

# Execute with output redirection
$ grizzly < analysis.sql > results.csv

# Chain commands
$ grizzly -c "LOAD SAMPLE DATA" && grizzly -c "SELECT * FROM table"
```

### Server Mode (Future)
**Usage:** `grizzly server [--port 8080] [--host 0.0.0.0]`
**Description:** Run Grizzly as a REST API server
**Best For:** Web applications, microservices, API integration
**Example:**
```bash
$ grizzly server --port 8080
Server started on http://localhost:8080
API endpoints:
  POST /query - Execute SQL queries
  GET /tables - List available tables
  POST /load - Load data files
```

### Import/Export Mode
**Usage:** `grizzly import <source> [options]` or `grizzly export <query> [options]`
**Description:** Specialized mode for data migration and ETL operations
**Best For:** Data migration, backups, ETL pipelines
**Examples:**
```bash
# Import from various formats
$ grizzly import data.csv --format csv --table users
$ grizzly import data.parquet --format parquet --table sales
$ grizzly import old.db --format sqlite --database legacy

# Export query results
$ grizzly export "SELECT * FROM users WHERE active=1" --output active_users.jsonl
$ grizzly export "SELECT * FROM sales" --output sales.parquet --format parquet
```

### Configuration Mode
**Usage:** `grizzly config [options]`
**Description:** Manage Grizzly configuration and settings
**Best For:** Setup, optimization, troubleshooting
**Examples:**
```bash
# Show current configuration
$ grizzly config --show

# Set memory limit
$ grizzly config --memory-limit 8GB

# Configure default compression
$ grizzly config --compression zstd

# Reset to defaults
$ grizzly config --reset
```

## Command-Line Options

### Global Options
- `--help, -h` - Show help message
- `--version, -v` - Show version information
- `--verbose, -V` - Enable verbose output
- `--quiet, -q` - Suppress non-essential output
- `--config FILE` - Specify configuration file

### REPL Options
- `--database FILE` - Auto-attach database on startup
- `--history FILE` - Command history file location
- `--no-banner` - Skip welcome banner

### Batch Options
- `--command, -c SQL` - Execute SQL command
- `--file, -f FILE` - Execute SQL from file
- `--output, -o FILE` - Redirect output to file
- `--format FORMAT` - Output format (json, csv, table)

### Server Options
- `--port PORT` - Server port (default: 8080)
- `--host HOST` - Server host (default: localhost)
- `--cors` - Enable CORS for web applications
- `--auth` - Enable authentication

### Performance Options
- `--memory-limit SIZE` - Memory usage limit
- `--threads NUM` - Number of worker threads
- `--cache-size SIZE` - Query result cache size
- `--mmap` - Enable memory-mapped I/O

## Mode Selection Logic

Grizzly automatically detects the intended mode based on command-line arguments:

1. **If `--server` specified** → Server mode
2. **If `--import` or `--export` specified** → Import/Export mode  
3. **If `--config` specified** → Configuration mode
4. **If `-c`, `-f`, or stdin redirected** → Batch mode
5. **Otherwise** → Interactive REPL mode

## Packaging and Distribution

### Standalone Executable
The packaged Grizzly executable supports all modes:

```bash
# Download and extract
wget https://example.com/grizzly-linux-x64.tar.gz
tar -xzf grizzly-linux-x64.tar.gz
cd grizzly/

# Make executable
chmod +x grizzly

# Use in different modes
./grizzly                    # REPL mode
./grizzly < script.sql       # Batch mode
./grizzly server             # Server mode
./grizzly import data.csv    # Import mode
```

### Docker Container
```bash
# Pull and run
docker run -it grizzly/grizzly:latest

# Mount volumes for data
docker run -v /data:/data -it grizzly/grizzly:latest
```

### System Integration
```bash
# Add to PATH
sudo cp grizzly /usr/local/bin/

# Create desktop shortcut
cp grizzly.desktop ~/.local/share/applications/

# Use system-wide
grizzly --version
```

## Mojo Project Packaging System

### Overview
Grizzly includes a comprehensive packaging system that allows Mojo developers to package their own projects into standalone executables, similar to Python's `cx_Freeze`, Rust's Cargo, or Go's build system. This enables Mojo developers to distribute their applications as self-contained binaries without requiring end users to install Mojo.

### Project Packaging Commands

#### INIT PACKAGE
**Syntax:** `PACKAGE INIT [project_name]`
**Description:** Initializes a new Mojo project with packaging configuration
**Status:** 🔄 Planned
**Example:**
```bash
$ grizzly package init my-project
Created project structure:
  my-project/
    ├── mojo.toml          # Project configuration
    ├── src/
    │   └── main.mojo      # Main entry point
    ├── tests/
    └── build/             # Build artifacts
```

#### ADD MOJO FILE
**Syntax:** `PACKAGE ADD FILE 'path/to/file.mojo'`
**Description:** Adds a Mojo source file to the package
**Status:** 🔄 Planned
**Example:**
```bash
$ grizzly package add file src/utils.mojo
Added src/utils.mojo to package
```

#### ADD PYTHON DEPENDENCY
**Syntax:** `PACKAGE ADD DEP 'package_name==version'`
**Description:** Adds a Python dependency for interop functionality
**Status:** 🔄 Planned
**Example:**
```bash
$ grizzly package add dep 'numpy==1.24.0'
Added numpy==1.24.0 to dependencies
```

#### BUILD PACKAGE
**Syntax:** `PACKAGE BUILD [options]`
**Description:** Builds the project into a standalone executable
**Status:** 🔄 Planned
**Options:**
- `--release` - Optimized release build
- `--debug` - Debug build with symbols
- `--target TRIPLE` - Cross-compilation target
- `--output FILE` - Output executable name
**Examples:**
```bash
# Development build
$ grizzly package build --debug

# Release build for Linux
$ grizzly package build --release --target x86_64-unknown-linux-gnu

# Cross-compile for Windows
$ grizzly package build --release --target x86_64-pc-windows-msvc --output myapp.exe
```

#### INSTALL PACKAGE
**Syntax:** `PACKAGE INSTALL [path]`
**Description:** Installs a built package to the system
**Status:** 🔄 Planned
**Example:**
```bash
$ grizzly package install
Package installed to /usr/local/bin/my-project

# Install to custom location
$ grizzly package install /opt/my-apps/
```

### Project Configuration (mojo.toml)

Grizzly uses a `mojo.toml` configuration file similar to Rust's `Cargo.toml` or Python's `pyproject.toml`:

```toml
[package]
name = "my-mojo-app"
version = "1.0.0"
authors = ["Your Name <your.email@example.com>"]
description = "A high-performance Mojo application"
license = "MIT"

[dependencies]
python = ["numpy==1.24.0", "pandas==2.0.0"]
mojo = ["grizzly==1.0.0"]

[[bin]]
name = "my-app"
path = "src/main.mojo"

[build]
target = "x86_64-unknown-linux-gnu"
optimization = "release"
lto = true

[package.metadata]
homepage = "https://example.com"
repository = "https://github.com/user/my-mojo-app"
```

### Advanced Packaging Features

#### Cross-Compilation
**Syntax:** `PACKAGE BUILD --target TRIPLE`
**Description:** Cross-compiles to different platforms
**Supported Targets:**
- `x86_64-unknown-linux-gnu` - Linux x64
- `aarch64-unknown-linux-gnu` - Linux ARM64
- `x86_64-pc-windows-msvc` - Windows x64
- `x86_64-apple-darwin` - macOS x64
- `aarch64-apple-darwin` - macOS ARM64
**Example:**
```bash
# Build for multiple platforms
$ grizzly package build --target x86_64-unknown-linux-gnu
$ grizzly package build --target x86_64-pc-windows-msvc --output myapp.exe
$ grizzly package build --target x86_64-apple-darwin
```

#### Library Packaging
**Syntax:** `PACKAGE BUILD --lib`
**Description:** Builds a library instead of an executable
**Example:**
```bash
$ grizzly package build --lib
Built library: libmyproject.so (Linux), myproject.dll (Windows)
```

#### Bundle Resources
**Syntax:** `PACKAGE ADD RESOURCE 'path/to/file'`
**Description:** Bundles additional files (config, data, assets) into the executable
**Example:**
```bash
$ grizzly package add resource config/default.json
$ grizzly package add resource assets/logo.png
$ grizzly package build
# Resources accessible at runtime via package API
```

#### Dependency Management
```bash
# Add dependencies
$ grizzly package add dep 'matplotlib==3.7.0'

# Update dependencies
$ grizzly package update

# List dependencies
$ grizzly package deps

# Remove dependency
$ grizzly package remove dep matplotlib
```

### Distribution Formats

#### Single Executable
Creates a standalone binary with all dependencies bundled:
```bash
$ grizzly package build --bundle
Built: my-app (45 MB)
$ ./my-app  # Runs without Mojo installation
```

#### Archive Distribution
Creates compressed archives for distribution:
```bash
$ grizzly package build --archive
Built archives:
  my-app-linux-x64.tar.gz
  my-app-windows-x64.zip
  my-app-macos-x64.dmg
```

#### Container Images
Generates Docker images automatically:
```bash
$ grizzly package build --docker
Built Docker image: my-app:latest
$ docker run my-app:latest
```

### Integration with Build Systems

#### CI/CD Integration
```yaml
# .github/workflows/build.yml
name: Build and Release
on: [push, release]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: grizzly/package-action@v1
        with:
          command: 'package build --release --archive'
      - uses: actions/upload-artifact@v3
        with:
          name: binaries
          path: build/
```

#### Makefile Integration
```makefile
.PHONY: build clean install

build:
    grizzly package build --release

clean:
    grizzly package clean

install: build
    grizzly package install

cross-compile:
    grizzly package build --target x86_64-pc-windows-msvc
    grizzly package build --target aarch64-apple-darwin
```

### Comparison with Other Tools

| Feature | Grizzly Package | Pixi | Hatch | cx_Freeze | Cargo |
|---------|-----------------|------|-------|-----------|-------|
| **Language** | Mojo | Python | Python | Python | Rust |
| **Cross-Platform** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Single Binary** | ✅ | ❌ | ❌ | ✅ | ✅ |
| **Python Interop** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Mojo Native** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Container Support** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Dependency Mgmt** | ✅ | ✅ | ✅ | ❌ | ✅ |

### User Workflow Examples

#### Simple CLI Tool
```bash
# Initialize project
$ grizzly package init cli-tool

# Add main file
$ grizzly package add file src/main.mojo

# Build and run
$ grizzly package build
$ ./cli-tool --help
```

#### Data Science Application
```bash
# Initialize project
$ grizzly package init data-analyzer

# Add dependencies
$ grizzly package add dep 'numpy==1.24.0'
$ grizzly package add dep 'pandas==2.0.0'

# Add source files
$ grizzly package add file src/analyzer.mojo
$ grizzly package add file src/visualization.mojo

# Bundle data files
$ grizzly package add resource data/sample.csv

# Build optimized binary
$ grizzly package build --release --bundle
```

#### Web Service
```bash
# Initialize project
$ grizzly package init web-api

# Add web framework dependency
$ grizzly package add dep 'fastapi==0.100.0'
$ grizzly package add dep 'uvicorn==0.23.0'

# Build container image
$ grizzly package build --docker

# Run service
$ docker run -p 8000:8000 web-api
```

This packaging system empowers Mojo developers to distribute their applications professionally, with the same ease as established ecosystems while leveraging Mojo's high performance and Python interoperability.

## User Experience Flow

### New User Journey
1. **Discovery**: Download and run `./grizzly` (enters REPL)
2. **Learning**: Type `HELP` to see available commands
3. **Experimentation**: Try `LOAD SAMPLE DATA` and basic queries
4. **Production**: Use batch mode for scripts and automation
5. **Integration**: Deploy server mode for applications

### Power User Workflow
1. **Configuration**: Set up preferences with `grizzly config`
2. **Database Setup**: Create/attach databases with ATTACH commands
3. **Batch Processing**: Use scripts for ETL and analysis
4. **API Integration**: Run server mode for web applications
5. **Monitoring**: Use verbose mode for performance tuning

This multi-mode design ensures Grizzly can be used effectively across the entire spectrum of data work, from interactive exploration to production deployment.

## Extension System

### LOAD EXTENSION
**Syntax:** `LOAD EXTENSION 'extension_name'`
**Description:** Loads additional functionality modules
**Status:** 🔄 Partial Implementation
**Available Extensions:**
- `column_store`: Advanced columnar storage
- `row_store`: Traditional row storage
- `graph`: Graph database features
- `blockchain`: Immutable audit trails
- `lakehouse`: Data lake integration
- `ml`: Machine learning features
- `security`: Authentication and authorization
- `analytics`: Advanced analytics functions

**Example:**
```
grizzly> LOAD EXTENSION 'analytics'
Analytics extension loaded
```

## Performance Considerations

### Memory Management
- Large datasets automatically spill to disk
- Memory usage displayed in status commands
- Configurable memory limits

### Query Optimization
- Automatic query planning for best performance
- Index usage for selective queries
- Parallel execution for aggregations

### Caching
- Query result caching for repeated queries
- Metadata caching for schema information
- Connection pooling for external data sources

## Security Features (Future)

### Authentication
```
grizzly> LOGIN username
Password: ******
Token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

### Authorization
- Row-level security
- Column-level permissions
- Query auditing

### Encryption
- Data-at-rest encryption
- TLS for network connections
- Secure credential storage

This design provides a comprehensive, user-friendly interface that scales from simple data exploration to advanced analytical workloads while maintaining the familiar SQL paradigm that users expect.</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/mojo-grizzly/.agents/d/cli_commands_design.md