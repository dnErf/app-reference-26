# Grizzly DB 🐻

**A fast, hybrid-storage, AI-friendly embedded database written in pure Zig**

Grizzly DB combines the best features of DuckDB (small footprint, efficient storage), Polars (parallel compute), SQLMesh (maintainable schemas), SQL Server Columnstore (adaptive indexing), and Neo4j (graph relationships) into a zero-dependency database that's optimized for AI workflows and modern data platforms.

## Features

### 🏗️ Hybrid Storage Architecture (Coming Q1-Q2 2027)
- **Column Store**: OLAP-optimized for analytics, aggregations, and scans
- **Row Store**: OLTP-optimized for transactions, point lookups, and updates
- **Graph Store**: Relationship-optimized for traversals, pattern matching, and social networks
- **Automatic Selection**: Query planner chooses optimal storage per table/query
- **Cross-Store Joins**: Seamlessly join across all three storage types

### 🚀 Fast Columnar Storage (Current)
- **Columnar layout**: Store data in columns for faster analytical queries
- **Zero-copy operations**: Minimal memory overhead
- **Cache-friendly**: Optimized memory access patterns
- **100k+ rows/sec insertion rate**: See benchmarks below

### ⚡ Parallel Compute
- **Multi-threaded aggregations**: Leverage all CPU cores
- **SIMD-friendly design**: Vectorized operations where possible
- **Efficient filtering**: Parallel table scans
- **Thread-safe operations**: Built for concurrent workloads

### 🤖 AI-Friendly Export
- **JSON**: Human-readable, widely supported
- **JSONL**: Streaming format for large datasets
- **CSV**: Universal compatibility
- **Binary**: Compact columnar format (3x compression)

### 📂 Multi-Format Data Ingestion
- **CSV**: Automatic schema inference, configurable delimiters
- **JSON**: Both array and line-delimited JSONL formats
- **Format Detection**: Auto-detect by extension or content
- **Pluggable Architecture**: Extensible loader interface for custom formats
- **Schema Inference**: Sample-based type detection with promotion heuristics

### 📊 Complete SQL Analytics
- **ORDER BY**: Sort results by one or more columns (ASC/DESC)
- **GROUP BY**: Group rows for aggregation with multiple columns
- **HAVING**: Filter grouped results with aggregate conditions
- **Aggregations**: SUM, AVG, COUNT, MIN, MAX functions
- **LIMIT/OFFSET**: Pagination support for large result sets
- **Enhanced JOINs**: INNER, LEFT, RIGHT, FULL OUTER JOIN operations
- **CTEs**: WITH clause support with MATERIALIZED/NOT MATERIALIZED options
- **Views**: Virtual and materialized views with refresh capabilities

### 🧠 Adaptive Query Optimizer
- **Logical plans**: `PlanNode` tree with predicate & projection pushdown
- **Cost-based decisions**: Estimates rows/cost to pick the cheapest path
- **Index-aware**: Transparently switches scans to B+Tree index lookups
- **Explainable**: `QueryPlan.explain()` shows the pipeline and estimated cost

### 🪢 Hash Joins + Multi-Table Optimizer
- **JOIN parser + planner**: SQL `JOIN ... ON ...` clauses translate into multi-branch plan nodes
- **Enhanced JOINs**: INNER, LEFT, RIGHT, FULL OUTER JOIN support
- **Recursive executor**: Plan nodes execute depth-first so joins, limits, and filters compose naturally
- **Hash join engine**: Build-side hash tables enable sub-linear join lookups with automatic equality verification
- **Audit hooks**: Optimizer decisions (index picks, join strategies) stream directly into the AI audit log

### 🌲 B+Tree Indexes
- **Order-32 B+Trees**: Cache-friendly nodes with linked leaves for range scans
- **Per-column indexes**: `Table.createIndex()` and `lookupIndex()` APIs
- **Statistics**: Height, key counts, and density tracking for observability
- **Persistence**: Index definitions saved/loaded with the lakehouse format

### 🧩 PL-Grizzly - Functional Programming Language ✅ FOUNDATION COMPLETE
- **CREATE FUNCTION**: User-defined functions with pattern matching
- **Dual Execution Modes**: Runtime execution in SELECT queries + compile-time expansion in templates
- **Async by Default**: Non-blocking execution with optional SYNC override
- **Expression Language**: Variables, conditionals, and functional composition
- **Smart Pipes**: `|>` operator for functional programming chains
- **Method Receivers**: `[object] method()` syntax for object-oriented style
- **Built-in Functions**: `filter`, `map`, `sum`, `length` for data transformation
- **Template Integration**: `{function_call(args)}` syntax for dynamic SQL generation

### 💾 Database Persistence ✅ COMPLETE
- **SAVE DATABASE**: Export current database to `.griz` file with optional compression
- **LOAD DATABASE**: Import database from `.griz` file with validation
- **ATTACH DATABASE**: Mount additional databases read-only with aliases
- **DETACH DATABASE**: Remove attached databases by alias
- **SHOW DATABASES**: List all attached databases with metadata
- **Compression Support**: lz4, zstd, gzip, snappy algorithms (framework ready)
- **File Safety**: Overwrite protection prevents accidental data loss
- **Lakehouse Format**: Hierarchical storage with metadata, data, and unstructured files
- **SQL Interface**: Complete SQL commands for database save/load operations

### SQL Syntax Examples

```sql
-- Create table from query results
CREATE TABLE high_value_customers AS
  SELECT customer_id, SUM(order_amount) as lifetime_value
  FROM orders
  GROUP BY customer_id
  HAVING SUM(order_amount) > 10000;

-- Create transformation model
CREATE MODEL customer_360 AS
  SELECT
    c.*,
    COALESCE(o.order_count, 0) as orders,
    COALESCE(o.total_spent, 0) as spent
  FROM customers c
  LEFT JOIN (
    SELECT customer_id, COUNT(*) as order_count, SUM(amount) as total_spent
    FROM orders GROUP BY customer_id
  ) o ON c.customer_id = o.customer_id;

-- Create incremental model with partition tracking
CREATE INCREMENTAL MODEL daily_metrics
  PARTITION BY DATE(created_at)
AS
  SELECT
    DATE(created_at) as date,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(amount) as total_revenue
  FROM events;

-- Save database with compression
SAVE DATABASE TO 'mydb.griz' WITH COMPRESSION lz4;
SAVE DATABASE TO 'backup.griz' WITH COMPRESSION zstd;
```

### 🛰️ Incremental Lakehouse Snapshots
- **Manifest-tracked baselines**: Each `.griz` snapshot emits `manifest.json` with per-table row counts
- **Delta files**: `saveIncremental()` writes only the new rows plus schema guards into a compact `.delta`
- **Fast apply**: `applyIncremental()` verifies schema + row offsets, then appends rows without re-reading the base snapshot
- **Retention-friendly**: Keep periodic full snapshots plus small deltas for point-in-time recovery

### 🗜️ Compression metadata
- Column chunks record a chosen compression codec (`none`, `rle`, `dictionary`, `bitpack`) and per-column statistics (original size, compressed size, compression ratio, optional min/max for integer columns) in the table metadata JSON file. This enables the optimizer to make better choices and helps downstream tools (e.g., DuckDB) understand snapshot layout.

### 🧾 Explainable Plans (JSON + Mermaid)
- **Structured explain**: `QueryPlan.explainJSON()` returns a machine-readable tree for AI agents
- **Visual graphs**: `QueryPlan.explainMermaid()` emits Mermaid diagrams for docs, PRs, or observability dashboards
- **Plan introspection**: Combine text, JSON, and graphs to debug optimizer rewrites or share insights with teammates

### 📦 Zero Dependencies
- **Pure Zig**: No external libraries
- **Embedded**: Single executable, no server required
- **Cross-platform**: Linux, macOS, Windows

### 🔮 Future Capabilities (Roadmap)

#### Data Transformation Pipeline (Q1-Q4 2026)
- **Views & Materialized Views**: dbt-style model definitions
- **DAG & Lineage**: Automatic dependency tracking and visualization
- **Data Testing**: Built-in test framework for data quality
- **PLGrizzly-Functional**: OCaml-inspired functional language with Lua simplicity
- **Macros**: Integrated as higher-order functions (no separate templating)
- **Scheduler**: Built-in job orchestration
- **Environments**: dev/staging/prod isolation

#### Storage Architecture (Q1-Q2 2027)
- **Row Store Engine**: MVCC, row-level locking, efficient updates
- **Graph Database**: Neo4j-style nodes, edges, Cypher queries, traversals
- **Columnstore Indexes**: SQL Server-style segment elimination, batch mode
- **Unified Query Planner**: Optimize across all storage types

See [TRANSFORMATION_ROADMAP.md](.agents/TRANSFORMATION_ROADMAP.md) for detailed specifications.

## Sprint History
- [Sprint 17 - Cross-File Function Sharing](.agents/SPRINT_17.md): Enable function reusability across database files using ATTACH syntax for SQL files 📋 Planned
- [Sprint 16 - Exception Types & Zig-Style Error Handling](.agents/SPRINT_16.md): Custom exception types with CREATE TYPE AS EXCEPTION, exception value system, and foundation for Zig-style try-catch syntax ✅ Complete
- [Sprint 12 - Persistence SQL Commands](.agents/SPRINT_12.md): Complete SQL interface for database save/load with SAVE DATABASE, LOAD DATABASE, ATTACH/DETACH DATABASE, and SHOW DATABASES commands ✅ Complete
- [Sprint 11 - Incremental Models](.agents/SPRINT_11_COMPLETION.md): Model Refresh Scheduler with cron syntax, retry logic, automated execution, and Column-Level Lineage tracking (Phases 3 & 4 ✅ Complete)
- [Sprint 9 - Views & CTEs](.agents/SPRINT_9_COMPLETION.md): Virtual views, materialized views, CTEs with MATERIALIZED/NOT MATERIALIZED syntax
- [Sprint 8.5 - Vector Support & Delta Compaction](.agents/TRANSFORMATION_ROADMAP.md): Vector similarity search, HNSW indexing, delta compaction, retention policies
- [Sprint 8 - Hybrid Storage](.agents/ARCHITECTURE.md): Row store, column store, graph store architecture design
- [Sprint 7 - Compression & Parallel](.agents/SPRINT_7_COMPLETION.md): Dictionary encoding, delta encoding, SIMD aggregations, parallel scans
- [Sprint 6 - File Format System](.agents/SPRINT_6_FORMAT_COMPLETE.md): Pluggable format loaders for CSV, JSON, JSONL with auto-detection and schema inference.
- [Sprint 5 - Cardinality Estimation](.agents/SPRINT_CARDINALITY_STATISTICS.md): Real cardinality statistics, HyperLogLog approximation, improved optimizer and compression heuristics, AI-friendly JSON exports.
- [Sprint 4 - Hash Joins & Composite Indexes](.agents/SPRINT_HASH_JOINS_COMPOSITE.md): Hash joins, composite hash indexes, incremental lakehouse snapshots, JSON/Mermaid explain outputs with audit logging.
- [Sprint 3 - Optimizer & Indexes](.agents/SPRINT_OPTIMIZER_INDEXES_ASYNC.md): Cost-based optimizer, automatic B+Tree indexes, async lakehouse save/load pipelines.
- [Sprint 2 - Lakehouse & WHERE](.agents/SPRINT_LAKEHOUSE_WHERE.md): Lakehouse persistence format plus ANSI SQL WHERE clause parsing/execution.
- [Sprint 1 - AI-Auditable](.agents/SPRINT_AI_AUDITABLE.md): AI-auditable with lineage-aware aggregations, validators, CEO dashboard demo.

See [.agents/](.agents/) for detailed sprint reports, plans, and verification documents.

## Quick Start

### Build from Source

```bash
zig build
```

### Run Demo

```bash
./zig-out/bin/zig_grizzly
```

### Run Sprint 3 Optimizer Demo

```bash
zig build run-sprint3
```

### Run Benchmarks

```bash
./zig-out/bin/zig_grizzly benchmark
```

## Usage Examples

### Creating a Database

```zig
const grizzly = @import("zig_grizzly");
const allocator = std.heap.page_allocator;

var db = try grizzly.Database.init(allocator, "my_database");
defer db.deinit();

// Define schema
const schema = [_]grizzly.Schema.ColumnDef{
    .{ .name = "id", .data_type = .int32 },
    .{ .name = "name", .data_type = .string },
    .{ .name = "age", .data_type = .int32 },
    .{ .name = "score", .data_type = .float64 },
};

// Create table
try db.createTable("users", &schema);
```

### Inserting Data

```zig
const table = try db.getTable("users");

try table.insertRow(&[_]grizzly.Value{
    grizzly.Value{ .int32 = 1 },
    grizzly.Value{ .string = "Alice" },
    grizzly.Value{ .int32 = 30 },
    grizzly.Value{ .float64 = 95.5 },
});
```

### Querying Data

```zig
// Get specific cell
const value = try table.getCell(0, 1); // Row 0, Column 1
std.debug.print("Name: {s}\n", .{value.string});

// Aggregations
const avg_age = try table.aggregate(allocator, "age", .avg);
std.debug.print("Average age: {d}\n", .{avg_age.value.float64});

const max_score = try table.aggregate(allocator, "score", .max);
std.debug.print("Max score: {d}\n", .{max_score.value.float64});
```

### Exporting Data

```zig
const export_mod = grizzly.export_mod;

// Export to JSON
var json_buffer = std.ArrayList(u8){};
defer json_buffer.deinit(allocator);
const json_writer = json_buffer.writer(allocator);
try export_mod.exportJSON(table.*, json_writer);

// Save to file
const file = try std.fs.cwd().createFile("data.json", .{});
defer file.close();
try file.writeAll(json_buffer.items);

// Export to other formats
try export_mod.exportCSV(table.*, csv_writer);
try export_mod.exportJSONL(table.*, jsonl_writer);
try export_mod.exportBinary(table.*, binary_writer);
```

### SQL Queries

```zig
var engine = grizzly.QueryEngine.init(allocator, &db);

// Create table via SQL
const create_sql = "CREATE TABLE products (id INT, name STRING, price FLOAT)";
var result = try engine.execute(create_sql);
defer result.deinit();

// Insert data
const insert_sql = "INSERT INTO products VALUES (1, 'Widget', 19.99)";
var insert_result = try engine.execute(insert_sql);
defer insert_result.deinit();

// Query data
const select_sql = "SELECT * FROM products";
var query_result = try engine.execute(select_sql);
defer query_result.deinit();
```

## Benchmarks

Tested on a modern Linux system with Zig 0.15.2:

| Operation | Performance | Notes |
|-----------|-------------|-------|
| **Insert** | 2.3M rows/sec | 100k rows in 43ms |
| **SUM aggregation** | 0.27ms | 100k rows |
| **AVG aggregation** | 0.25ms | 100k rows |
| **MAX aggregation** | 28ms | 100k rows |
| **JSON export** | 760ms | 100k rows, 3.8MB |
| **Binary export** | 131ms | 100k rows, 1.2MB |
| **Compression ratio** | 3.2x | Binary vs JSON |

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────┐
│                    CLI / API                        │
│                   (main.zig)                        │
└─────────────────────┬───────────────────────────────┘
                      │
         ┌────────────┼────────────┐
         │            │            │
         ▼            ▼            ▼
┌────────────┐ ┌────────────┐ ┌──────────────┐
│   Query    │ │  Database  │ │   Export     │
│   Engine   │ │  Manager   │ │   Formats    │
│(query.zig) │ │(database.  │ │ (export.zig) │
│            │ │     zig)   │ │              │
└──────┬─────┘ └─────┬──────┘ └──────┬───────┘
       │             │               │
       └─────────────┼───────────────┘
                     │
              ┌──────▼──────┐
              │    Table    │
              │ (table.zig) │
              └──────┬──────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
         ▼           ▼           ▼
  ┌──────────┐ ┌─────────┐ ┌──────────┐
  │  Column  │ │ Schema  │ │ Parallel │
  │ Storage  │ │ (schema │ │  Engine  │
  │(column.  │ │   .zig) │ │(parallel │
  │   zig)   │ │         │ │   .zig)  │
  └────┬─────┘ └────┬────┘ └────┬─────┘
       │            │           │
       └────────────┼───────────┘
                    │
             ┌──────▼─────┐
             │   Types    │
             │ (types.zig)│
             └────────────┘
```

### Columnar Storage

Grizzly DB stores data column-by-column rather than row-by-row:

```
Traditional Row Storage:        Columnar Storage:
Row 1: [id, name, age]          id:   [1, 2, 3, 4]
Row 2: [id, name, age]          name: ["Alice", "Bob", ...]
Row 3: [id, name, age]          age:  [30, 25, 35, ...]
```

**Benefits:**
- Faster analytical queries (only read needed columns)
- Better compression (similar data together)
- Cache-friendly (sequential memory access)
- Vectorization-ready (SIMD operations)

### Type System

Supported data types:
- `int32`: 32-bit signed integer
- `int64`: 64-bit signed integer
- `float32`: 32-bit floating point
- `float64`: 64-bit floating point
- `boolean`: Boolean value
- `string`: Variable-length UTF-8 string
- `timestamp`: Unix timestamp (i64)

### Parallel Execution

Grizzly DB automatically parallelizes operations across CPU cores:
- **Map operations**: Transform columns in parallel chunks
- **Reduce operations**: Parallel aggregations with result merging
- **Filter operations**: Multi-threaded table scans

## AI Integration

Grizzly DB is designed for AI workflows:

### Embeddings Storage
Store vector embeddings efficiently in columnar format.

### Training Data Export
Export directly to formats consumable by ML frameworks:
- **JSONL**: For streaming to LLMs
- **Binary**: For fast NumPy/PyTorch loading
- **CSV**: For pandas/scikit-learn

### Schema Documentation
Auto-generate schema documentation for AI context:
```zig
try export_mod.exportSchemaDoc(table.*, writer);
```

Output:
```markdown
# Table: users

**Rows**: 4

## Schema

| Column | Type | Sample Values |
|--------|------|---------------|
| id | int32 | 1, 2, 3 |
| name | string | "Alice", "Bob", "Carol" |
| age | int32 | 30, 25, 35 |

## Statistics

- **age**: min=25, max=35, avg=29.5
- **salary**: min=65000.00, max=85000.00, avg=73750.00
```

## Project Structure

```
zig-grizzly/
├── src/
│   ├── root.zig          # Main library entry point
│   ├── types.zig         # Data types and values
│   ├── schema.zig        # Table schema definitions
│   ├── column.zig        # Columnar storage implementation
│   ├── table.zig         # Table operations
│   ├── database.zig      # Database management
│   ├── query.zig         # SQL parser and executor
│   ├── export.zig        # Export formats
│   ├── parallel.zig      # Parallel compute engine
│   └── main.zig          # CLI application
├── build.zig             # Build configuration
└── README.md             # This file
```

## Development

### Running Tests

```bash
zig build test
```

### Code Coverage

```bash
zig build test --summary all
```

### Performance Profiling

Build in release mode:
```bash
zig build -Doptimize=ReleaseFast
```

## Roadmap

- [x] **Persistence**: Save/load database to disk (lakehouse + async I/O)
- [x] **Indexing**: B-tree indexes with automatic optimizer integration
- [x] **Joins**: INNER joins with hash-based execution
- [x] **WHERE clauses**: ANSI filters with LIKE/IN support
- [ ] **Transactions**: ACID compliance
- [ ] **Compression**: LZ4/Zstandard support
- [ ] **Network protocol**: Client-server mode
- [ ] **Python bindings**: Use from Python/NumPy

## Comparison

| Feature | Grizzly | DuckDB | Polars | SQLite |
|---------|---------|--------|--------|--------|
| **Columnar** | ✅ | ✅ | ✅ | ❌ |
| **Parallel** | ✅ | ✅ | ✅ | ❌ |
| **Embedded** | ✅ | ✅ | ❌ | ✅ |
| **Zero deps** | ✅ | ❌ | ❌ | ✅ |
| **AI exports** | ✅ | ⚠️ | ⚠️ | ❌ |
| **Written in** | Zig | C++ | Rust | C |

## Why Zig?

Grizzly DB is written in Zig for:
- **Memory safety**: Compile-time checks without runtime overhead
- **Performance**: C-level speed with better ergonomics
- **Simplicity**: No hidden control flow or allocations
- **Cross-compilation**: Easy to build for any target

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please open an issue or PR.

## Acknowledgments

Inspired by:
- **DuckDB**: Columnar storage and embedded design
- **Polars**: Parallel dataframe operations
- **SQLMesh**: SQL-based data transformation patterns
- **Apache Arrow**: Columnar memory format

---

**Built with ❤️ and Zig 0.15.2**
