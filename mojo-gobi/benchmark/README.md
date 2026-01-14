# Benchmark Directory Organization

This directory contains all benchmark-related data, databases, and reports for the PL-GRIZZLY lakehouse system performance evaluation.

## Directory Structure

### `data/`
Performance test data and schemas used for benchmarking.
- `schema/` - Database schemas for performance testing

### `query/`
Query performance benchmark databases and data.

#### `query/standard/`
Standard scale query benchmarks (typical dataset sizes).
- `integrity/` - Merkle tree integrity files for data verification
- `schema/` - Database schema definitions
- `tables/` - ORC table files for query benchmarking

#### `query/large_scale/`
Large scale query benchmarks (1M+ records).
- `integrity/` - Merkle tree integrity files for data verification
- `schema/` - Database schema definitions
- `tables/` - ORC table files for large-scale query benchmarking

### `reports/`
Performance benchmark reports and analysis.
- `performance_report_*.md` - Detailed performance analysis reports

### `storage/`
Storage engine benchmark databases and data.

#### `storage/orc/`
ORC storage format benchmarks.
- `integrity/` - Merkle tree integrity files for data verification
- `tables/` - ORC table files for storage benchmarking

## Benchmark Categories

### Query Benchmarks
- **Standard Scale**: Typical workload sizes for standard performance evaluation
- **Large Scale**: Million-record datasets for scalability testing

### Storage Benchmarks
- **ORC Format**: Apache ORC file format performance and compression testing

### Performance Reports
- **Automated Reports**: Generated performance analysis with metrics and recommendations

## Data Integrity

All benchmark databases include Merkle tree integrity verification:
- `.merkle` files contain cryptographic hashes for data integrity
- Ensures benchmark data hasn't been corrupted
- Enables tamper detection for performance comparisons

## Usage

### Running Benchmarks
```bash
cd /home/lnx/Dev/app-reference-26/mojo-gobi/src
# Run query benchmarks
mojo run ../benchmark/query/standard/benchmark_queries.mojo
mojo run ../benchmark/query/large_scale/benchmark_large_queries.mojo

# Run storage benchmarks
mojo run ../benchmark/storage/orc/benchmark_storage.mojo
```

### Viewing Reports
```bash
cat benchmark/reports/performance_report_*.md
```

## Benchmark Data

- **benchmark_users**: User data table for authentication/query benchmarks
- **benchmark_table**: Generic table for storage format testing
- All data includes integrity verification via Merkle trees

## Maintenance

- Reports are automatically generated during benchmark runs
- Database files can be regenerated using benchmark setup scripts
- Integrity files ensure data consistency across benchmark runs