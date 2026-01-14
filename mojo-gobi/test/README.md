# Test Directory Organization

This directory contains all test files for the PL-GRIZZLY lakehouse system, organized by category.

## Directory Structure

### `component/`
Component-level tests that test individual system components in isolation.
- `test_query_optimization` - Query optimization component tests

### `data/`
Data processing and manipulation tests.
- `test_complex_query_execution.mojo` - Complex query execution scenarios
- `test_incremental_processor.mojo` - Incremental data processing tests

### `integration/`
Integration tests that validate interactions between multiple components.
- `test_component_integration.mojo` - Cross-component integration validation
- `test_data_ingestion_pipeline.mojo` - End-to-end data ingestion pipeline tests

### `performance/`
Performance-related tests and benchmarks.
- `test_performance_profiling_integration.mojo` - Performance profiling and monitoring tests

## Test Data

Test data files are located in the `../test_data/` directory:
- `test_data.csv` - CSV test data
- `test_data.json` - JSON test data
- `test_file_reading.sql` - SQL test scripts
- `test_script.sql` - Additional SQL test scripts

## Running Tests

To run all tests:
```bash
cd /home/lnx/Dev/app-reference-26/mojo-gobi/src
mojo run ../test/integration/test_component_integration.mojo
mojo run ../test/integration/test_data_ingestion_pipeline.mojo
mojo run ../test/performance/test_performance_profiling_integration.mojo
mojo run ../test/data/test_complex_query_execution.mojo
mojo run ../test/data/test_incremental_processor.mojo
```

## Test Categories

- **Unit Tests**: Individual function/component testing (component/)
- **Integration Tests**: Multi-component interaction testing (integration/)
- **Performance Tests**: Performance benchmarking and profiling (performance/)
- **Data Tests**: Data processing and query execution (data/)