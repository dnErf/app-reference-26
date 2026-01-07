# Query Engine Implementation Details
## Overview
The query engine (`query.mojo`) handles SQL-like queries for the Mojo Grizzly database, including SELECT, WHERE, JOIN, and parallel processing.

## Key Features Implemented
- **Query Planning**: Parses SQL for operations (join, filter, sort), estimates cost based on features and row count.
- **Parallel Execution**: Splits table into chunks, submits to ThreadPool (sequential fallback), combines results.
- **JOIN Logic**: Left/right/full joins with key matching, full join merges and dedupes.
- **LIKE Operator**: String pattern matching with % wildcards (prefix, suffix, contains).
- **Filtering**: Supports eq, neq, gt, lt, in, between, is null, like with index utilization.

## Data Structures
- **QueryPlan**: List of operations and cost estimate.
- **Result[T]**: Generic result with error handling.
- **QueryResult**: Table result with error string.
- **ColumnSpec/TableSpec**: For parsing column/table names and aliases.

## Algorithms
- **Parallel Scan**: Chunking and thread submission for aggregation.
- **JOIN**: Nested loop for key matching, with null handling.
- **LIKE Matching**: Simple pattern matching for wildcards.
- **Cost Estimation**: Additive costs for operations plus row-based scan cost.

## Testing
Validated with test.mojo, all tests pass including query operations.