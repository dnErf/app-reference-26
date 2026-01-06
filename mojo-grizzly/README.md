# Mojo Arrow Database

A high-performance, columnar database built in pure Mojo, leveraging Apache Arrow for in-memory analytics. Zero dependencies, SQL-like queries comparable to DuckDB/PostgreSQL, with Grizzly PL functions.

## Features
- **Columnar Storage**: Arrow-based arrays with validity bitmaps.
- **SQL Queries**: SELECT, FROM, WHERE with > operator.
- **Formats**: JSONL reader, IPC serialization.
- **CLI**: Run .sql files.
- **PL Functions**: CREATE FUNCTION with simple evaluation.

## Usage

### CLI
```bash
mojo cli.mojo test.sql
```

### SQL Example
```sql
LOAD JSONL '{"id": 1, "value": 10}
{"id": 2, "value": 20}';

SELECT * FROM table WHERE value > 15;

SAVE 'table.ipc';
```

### API
Import modules:
```mojo
from arrow import Table, Schema, DataType
from query import execute_query
```

Create table:
```mojo
var schema = Schema()
schema.add_field("id", DataType.int64)
var table = Table(schema, 10)
table.columns[0][0] = 1
```

Query:
```mojo
let result = execute_query(table, "SELECT * FROM table WHERE id > 5")
```

## Architecture
- `arrow.mojo`: Core Arrow structs (Buffer, Arrays, Schema, Table).
- `query.mojo`: SQL parser and executor.
- `formats.mojo`: Data format readers.
- `ipc.mojo`: Serialization.
- `pl.mojo`: Function system.
- `cli.mojo`: Command-line interface.

## Roadmap
- Full SQL (JOIN, aggregates).
- More formats (AVRO, ORC).
- Advanced PL (pattern matching, pipes).
- Performance optimizations.
- REST API.

## Benchmarks
Run `mojo benchmark.mojo` for performance tests on large datasets.