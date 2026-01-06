## Overview
Build a high-performance, columnar database leveraging a pure Mojo implementation of Apache Arrow as the core data format, with zero external dependencies. The database will provide seamless interoperability with popular data formats including JSONL, AVRO, ORC, Parquet, and CSV, enabling easy data ingestion, querying, and export across ecosystems.

## Goals (First Principles)
- **Performance**: Utilize custom columnar format and Mojo's compiled efficiency to achieve sub-second queries on large datasets.
- **Interoperability**: Native support for reading/writing multiple formats without data loss or transformation overhead.
- **Simplicity**: SQL-like query interface with minimal setup, targeting data scientists and engineers.
- **Extensibility**: Modular design for adding custom formats, functions, and integrations.
- **Reliability**: ACID compliance where applicable, with robust error handling and testing.
- **Zero Dependencies**: Pure Mojo implementation, no external libs.
- **In-Memory First**: Optimized for in-memory operations with lazy evaluation.
- **SQL Syntax**: Query syntax comparable to DuckDB and PostgreSQL (SELECT, FROM, WHERE, JOIN, etc.).

## Core Components
1. **Arrow Core Layer**: Pure Mojo structs for buffers, arrays, schemas, tables, IPC.
2. **Storage Engine**: In-memory columnar storage with optional persistence via IPC.
3. **Query Engine**: SQL parser and executor with PostgreSQL/DuckDB-like syntax.
4. **Format Interoperability Module**: Readers/writers for JSONL, AVRO, ORC, Parquet, CSV, using custom conversions.
5. **API/CLI**: RESTful API and command-line interface for data operations.
6. **Testing & Benchmarks**: Comprehensive tests against real datasets, performance comparisons with DuckDB/Polars.

## Core Components
1. **Arrow Core Layer**: Pure Mojo structs for buffers, arrays, schemas, tables, IPC.
2. **Storage Engine**: Persistent storage using custom IPC format, with indexing for fast access.
3. **Query Engine**: Basic SQL parser and executor optimized for columnar operations (select, filter, aggregate).
4. **Format Interoperability Module**: Readers/writers for JSONL, AVRO, ORC, Parquet, CSV, using custom conversions.
5. **API/CLI**: RESTful API and command-line interface for data operations.
6. **Testing & Benchmarks**: Comprehensive tests against real datasets, performance comparisons with DuckDB/Polars.

## Implementation Phases
### Phase 1: Arrow Foundation (2-3 weeks)
- Implement core Arrow structures: Buffer, Array (primitive, string), Schema, Table.
- Add basic IPC serialization/deserialization.
- Unit tests for correctness.

### Phase 2: Storage & Query Basics (2-3 weeks)
- Design storage layer using custom IPC for persistence.
- Build simple query engine for basic operations (scan, filter).
- Add format readers for JSONL and CSV.

### Phase 3: Interoperability Expansion (2-3 weeks)
- Implement AVRO, ORC, Parquet readers/writers.
- Optimize conversions using zero-copy where possible.
- Add export functionality.

### Phase 4: Advanced Features & Optimization (2-4 weeks)
- Add aggregations, joins, and indexing.
- Performance tuning and benchmarking.
- API/CLI development.

### Phase 5: Testing & Polish (1-2 weeks)
- Unit/integration tests.
- Documentation and examples.
- Open-source preparation if applicable.

## TODO
- [x] Research Mojo-Arrow integration options (native bindings vs Python interop). **DONE: Pure Mojo implementation required.**
- [x] Implement Arrow Buffer struct.
- [x] Implement Arrow Array (primitive types).
- [x] Implement Arrow Schema and Table.
- [x] Implement basic SQL query engine (simple WHERE).
- [x] Implement full SQL parser (SELECT, FROM, WHERE, etc.).
- [x] Add IPC serialization.
- [x] Set up project scaffolding (main.mojo, modules).
- [x] Prototype basic Arrow table operations in Mojo.
- [x] Design schema for storage engine.
- [x] Implement JSONL reader.
- [x] Add basic query parser.
- [x] Implement CLI for .sql files.
- [x] Implement basic Grizzly PL functions.
- [x] Benchmark against existing tools.
- [x] Implement AVRO/ORC readers.
- [x] Document API and usage.
- [x] Add more data types (Float64).
- [x] Performance optimizations (SIMD).
- [x] Advanced storage (indexing).
- [x] Extend PL with pattern matching and pipes.
- [x] Implement full Grizzly PL (try/catch, templating, async execution).
- [x] Add JOIN operations.
- [ ] Add aggregates (SUM, COUNT).
- [ ] RESTful API.
- [x] Document API and usage.
- [x] Add more data types (Float64).
- [x] Performance optimizations (SIMD).
- [x] Advanced storage (indexing).
- [ ] Document API and usage.
- [x] Implement async execution in Grizzly PL (async fn, await for concurrency).
- [x] Implement PL AST parser for robust expression evaluation.
- [x] Add custom error types for try/catch in PL.
- [x] Implement compile-time evaluation for PL templates.
- [x] Extend PL data types and operators (FLOAT, TEXT, ARRAY, binary ops).
- [x] Integrate async pipes for concurrency in PL.
- [x] Implement runtime/compile-time modes in PL.
- [x] Add CREATE MODEL for templated SQL.
- [x] Add type checking in PL AST.
- [x] Enhance pipes with higher-order functions (lambdas).
- [x] Optimize AST evaluation with SIMD/parallelism.
- [x] Add user-defined types/structs to PL.
- [x] Add built-in functions library to PL.
- [x] Add recursive functions and TCO to PL.
- [x] Add debugging/inspection features to PL.
- [x] Add caching/memoization to PL.
- [x] Update PL design doc with examples/use cases.
- [x] Implement templating in Grizzly PL (conditional SQL generation with {if/else/end}).

## Risks & Mitigations
- Arrow bindings in Mojo: If native bindings don't exist, use Python interop as fallback, but monitor performance.
- Format complexity: Start with simple formats (JSONL, CSV), expand to binary (AVRO, ORC).
- Performance: Profile early, optimize hot paths with Mojo's features.

## Notes
- Always activate the virtual environment before running any commands: `source .venv/bin/activate`
- Inspired by Grizzly DB (Zig version) but focused on Arrow ecosystem.
- Leverage Mojo's SIMD and async for parallelism.
- Ensure all code has summary comments at top for readability.