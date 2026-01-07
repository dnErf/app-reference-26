# Mojo Grizzly Database

A high-performance, columnar database built in pure Mojo, leveraging Apache Arrow for in-memory analytics. Zero dependencies, SQL-like queries comparable to DuckDB/PostgreSQL, with Grizzly PL functions. Production-ready with enterprise features.

## Features
- **Columnar Storage**: Arrow-based arrays with validity bitmaps, zero-copy views.
- **SQL Queries**: SELECT, FROM, WHERE, JOIN, aggregates (SUM, COUNT, AVG, MIN, MAX, PERCENTILE), GROUP BY, subqueries, CTE, window functions.
- **Formats**: Full JSONL, AVRO, ORC, Parquet readers/writers with compression and schema evolution.
- **Indexing**: B-tree and hash indexes for fast lookups and ranges.
- **CLI**: Enhanced with tab completion, run .sql/.grz files.
- **PL Functions**: CREATE FUNCTION with AST evaluation, async, templating, debugging, external loading.
- **Testing**: Comprehensive unit tests and fuzzing.
- **Storage Types**: MEMORY (in-memory), BLOCK (persistent ORC-based), LAKEHOUSE (versioned multi-format).
- **Extensions**: Loadable modules for analytics, blockchain, graph, ML, observability, REST API, security, secrets.
- **Concurrency**: Threading for parallel query execution.
- **Error Handling**: Result types for robust error propagation.
- **Security**: RLS policies, AES encryption, JWT auth, audit logging.
- **Benchmarks**: Expanded suite for queries, I/O, indexing with performance reports.
- **Time Travel**: Versioning and point-in-time queries.
- **Distributed**: TCP server for federated queries.

## Usage

### Installation
Requires Mojo SDK (version 0.7+ recommended). Clone and build:
```bash
git clone https://github.com/dnErf/app-reference-26.git
cd app-reference-26/mojo-grizzly
# Activate venv if using Python interop
source .venv/bin/activate  # For extensions using Python
mojo build main.mojo
```

For development:
```bash
mojo run cli.mojo  # Interactive REPL
```

### CLI
```bash
mojo cli.mojo test.sql
# With tab completion for commands
```

### Extensions
Load extensions for additional features:
```sql
LOAD EXTENSION 'rest_api';  -- Starts HTTP server on 8080
LOAD EXTENSION 'security';  -- Enables auth and encryption
LOAD EXTENSION 'analytics'; -- Adds time-series and geospatial
```

### SQL Example
```sql
LOAD JSONL '{"id": 1, "value": 10}
{"id": 2, "value": 20}';

SELECT SUM(value) FROM table GROUP BY id;

SAVE 'table.parquet';
```

### PL Example
```sql
CREATE FUNCTION double(x) RETURN x * 2;

SELECT double(value) FROM table;
```

### API
Import modules:
```mojo
from arrow import Table, Schema, DataType, Result
from query import execute_query
from formats import read_parquet, write_avro
from extensions.security import generate_token
```

Create table:
```mojo
var schema = Schema()
schema.add_field("id", DataType.int64)
var table = Table(schema, 10)
table.append_row([1])
table.build_index("id")  # B-tree for ranges
```

Query with error handling:
```mojo
let result = execute_query(table, "SELECT * FROM table WHERE id == 5")
if result.is_ok():
    print(result.unwrap())
else:
    print("Error:", result.error())
```

Export:
```mojo
let parquet_result = write_parquet(table, "data.parquet")
```

#### Key Functions
- `Table.append_row(values: List[Variant])`: Add a row with mixed types.
- `Table.build_index(column: String)`: Build B-tree index on column.
- `execute_query(table: Table, sql: String) -> Result[Table, String]`: Execute SQL query.
- `read_parquet(filename: String) -> Result[Table, String]`: Read Parquet file.
- `write_avro(table: Table, filename: String) -> Result[(), String]`: Write AVRO file.
- `generate_token(user_id: String) -> String`: Generate JWT token.
- `validate_token(token: String) -> String`: Validate and return user_id.

### REST API
Start server:
```sql
LOAD EXTENSION 'rest_api';
```
Then POST to http://localhost:8080/query with JSON body {"sql": "SELECT * FROM table", "token": "jwt_token"}

### Testing
```bash
mojo test.mojo
```

### Benchmarking
```bash
mojo benchmark.mojo
# Outputs performance report
```

## Architecture
- `arrow.mojo`: Core Arrow structs with zero-copy TableView, Result types.
- `query.mojo`: SQL parser and parallel executor with threading.
- `formats.mojo`: Full data format implementations with compression.
- `index.mojo`: B-tree and hash indexing.
- `pl.mojo`: Function system with external loading.
- `cli.mojo`: Enhanced CLI with readline.
- `extensions/`: Modular features like security, analytics, etc.
- `benchmark.mojo`: Performance testing suite.

## Documentation
Detailed docs in [.agents/d/](.agents/d/) including variant integration, B-tree indexing, WAL transactions, PL libraries, security audit, and more.

## Troubleshooting
- Compilation errors: Ensure Mojo SDK is installed and up-to-date.
- Extension loading: Check file paths and permissions.
- Performance issues: Run benchmarks and check threading.
- Security: Review audit logs in audit.log.

## Roadmap
All planned features implemented. Production-ready with enterprise features. Open-source ready.

## Data Types
Supports int64, float64, string with Variant columns for type safety.

## Performance Features
- SIMD-accelerated aggregates
- Query caching
- Parallel execution
- BLOCK storage for persistence