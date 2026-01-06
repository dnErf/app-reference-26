# Mojo Arrow Database

A high-performance, columnar database built in pure Mojo, leveraging Apache Arrow for in-memory analytics. Zero dependencies, SQL-like queries comparable to DuckDB/PostgreSQL, with Grizzly PL functions.

## Features
- **Columnar Storage**: Arrow-based arrays with validity bitmaps.
- **SQL Queries**: SELECT, FROM, WHERE, JOIN, aggregates (SUM, COUNT, AVG, MIN, MAX), GROUP BY.
- **Formats**: JSONL, AVRO, ORC, Parquet readers/writers, CSV export.
- **Indexing**: HashIndex for fast WHERE lookups.
- **CLI**: Run .sql files.
- **PL Functions**: CREATE FUNCTION with AST evaluation, async, templating, debugging.
- **Testing**: Comprehensive unit tests in test.mojo.
- **Storage Types**: MEMORY (in-memory) and BLOCK (persistent ORC-based).
- **Extensions**: Loadable modules like 'secret' (default), 'blockchain', 'graph'.

## Memory Access in Mojo

This project includes a simple `MemoryAccess` struct (`memory_access.mojo`) demonstrating low-level memory management in Mojo. Key concepts:

- **Allocation/Deallocation**: Uses `List[UInt8]` for dynamic memory, resized on init.
- **Read/Write Operations**: Bounds-checked access to individual bytes or multi-byte values (e.g., Int32).
- **Copy Operations**: Efficient bulk copying between buffers.
- **Ownership & Safety**: Automatic deallocation via RAII; raises on out-of-bounds access.

Example:
```mojo
var mem = MemoryAccess(1024)
mem.write(0, 42)
print(mem.read(0))  # 42
mem.write_int32(4, 12345)
print(mem.read_int32(4))  # 12345
```

This serves as a foundation for understanding Mojo's memory model, crucial for fixing ownership issues in the main codebase.

## Usage

### CLI
```bash
mojo cli.mojo test.sql
```

### Extensions
```sql
LOAD EXTENSION 'secret';
LOAD EXTENSION 'blockchain';
```

### SQL Example
```sql
LOAD JSONL '{"id": 1, "value": 10}
{"id": 2, "value": 20}';

SELECT SUM(value) FROM table GROUP BY id;

SAVE 'table.ipc';
```

### PL Example
```sql
CREATE FUNCTION double(x) RETURN x * 2;

SELECT double(value) FROM table;
```

### API
Import modules:
```mojo
from arrow import Table, Schema, DataType
from query import execute_query
from formats import read_avro, write_csv
```

Create table:
```mojo
var schema = Schema()
schema.add_field("id", DataType.int64)
var table = Table(schema, 10)
table.columns[0][0] = 1
table.build_index("id")  # For fast queries
```

Query:
```mojo
let result = execute_query(table, "SELECT * FROM table WHERE id == 5")
```

Export:
```mojo
let csv_data = write_csv(table)
```

### Testing
```bash
mojo test.mojo
```

## Architecture
- `arrow.mojo`: Core Arrow structs (Buffer, Arrays, Schema, Table).
- `query.mojo`: SQL parser and executor.
- `formats.mojo`: Data format readers.
- `ipc.mojo`: Serialization.
- `pl.mojo`: Function system.
- `cli.mojo`: Command-line interface.

## Roadmap
- REST API.
- Full AVRO/ORC/Parquet implementations.
- Advanced optimizations.
- Open-source release.

## Benchmarks
Run `mojo benchmark.mojo` for performance tests on large datasets.