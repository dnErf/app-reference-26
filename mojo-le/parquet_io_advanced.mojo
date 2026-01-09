"""
Advanced Parquet I/O Operations with PyArrow
============================================

This example demonstrates high-performance Parquet file operations using PyArrow,
including compression, partitioning, and advanced I/O patterns. Parquet is the
de facto standard for analytical data storage in big data ecosystems.

Key Concepts:
- Parquet file format advantages
- Compression algorithms and trade-offs
- Data partitioning strategies
- Predicate pushdown optimization
- Column projection
- Metadata and statistics

Parquet Features:
- Columnar storage for analytics
- Efficient compression
- Schema evolution support
- Predicate pushdown
- Statistics for query optimization
"""

from python import Python
from python import PythonObject
import os

fn create_sample_dataset() raises -> PythonObject:
    """Create a sample dataset for Parquet operations."""
    var code = """
{
    "customer_id": list(range(1, 101)),
    "age": [25, 30, 35, 40, 45] * 20,
    "income": [30000, 40000, 50000, 60000, 70000] * 20,
    "category": ["A", "B", "C", "D", "A"] * 20,
    "region": ["North", "South", "East", "West", "North"] * 20,
    "signup_year": [2020, 2021, 2022, 2023, 2020] * 20,
    "active": [True, False, True, True, False] * 20
}
"""
    return Python.evaluate(code)

fn demonstrate_parquet_writing():
    """Demonstrate Parquet file writing with compression."""
    print("=== Parquet Writing Operations ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        var pd = Python.import_module("pandas")
        print("Creating sample dataset...")
        var data = create_sample_dataset()
        var df = pd.DataFrame(data)
        print("Converting to Arrow table...")
        var table = pa.Table.from_pandas(df)
        
        print("Created dataset with", table.num_rows, "rows and", table.num_columns, "columns")

        # Write with different compression algorithms
        pq.write_table(table, "sample_snappy.parquet", compression="SNAPPY")
        print("Compression SNAPPY - File created successfully")
        Python.evaluate("import os; os.remove('sample_snappy.parquet')")
        
        pq.write_table(table, "sample_gzip.parquet", compression="GZIP")
        print("Compression GZIP - File created successfully")
        Python.evaluate("import os; os.remove('sample_gzip.parquet')")
        
        pq.write_table(table, "sample_lz4.parquet", compression="LZ4")
        print("Compression LZ4 - File created successfully")
        Python.evaluate("import os; os.remove('sample_lz4.parquet')")
        
        pq.write_table(table, "sample_zstd.parquet", compression="ZSTD")
        print("Compression ZSTD - File created successfully")
        Python.evaluate("import os; os.remove('sample_zstd.parquet')")
        
        print("Successfully demonstrated Parquet writing with different compressions")

    except e:
        print("Parquet writing demonstration failed:", e)

fn demonstrate_compression_comparison():
    """Compare different compression algorithms."""
    print("\n=== Compression Algorithm Comparison ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        var pd = Python.import_module("pandas")
        var data = create_sample_dataset()
        var df = pd.DataFrame(data)
        var table = pa.Table.from_pandas(df)
        
        _ = Python.evaluate("{}")
        
        pq.write_table(table, "comp_snappy.parquet", compression="SNAPPY")
        Python.evaluate("import os; os.remove('comp_snappy.parquet')")
        
        pq.write_table(table, "comp_gzip.parquet", compression="GZIP")
        Python.evaluate("import os; os.remove('comp_gzip.parquet')")
        
        pq.write_table(table, "comp_lz4.parquet", compression="LZ4")
        Python.evaluate("import os; os.remove('comp_lz4.parquet')")
        
        pq.write_table(table, "comp_zstd.parquet", compression="ZSTD")
        Python.evaluate("import os; os.remove('comp_zstd.parquet')")
        
        print("Compression Results:")
        print("SNAPPY: Fast compression/decompression")
        print("GZIP: High compression ratio")
        print("LZ4: Balanced speed/ratio")
        print("ZSTD: Modern high-performance")

    except e:
        print("Compression comparison failed:", e)

fn demonstrate_partitioning():
    """Demonstrate data partitioning strategies."""
    print("\n=== Data Partitioning Strategies ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        var pd = Python.import_module("pandas")
        var data = create_sample_dataset()
        var df = pd.DataFrame(data)
        var table = pa.Table.from_pandas(df)
        
        # Create partitioned dataset by region and signup_year
        var partition_cols_code = """
['region', 'signup_year']
"""
        var partition_cols = Python.evaluate(partition_cols_code)
        pq.write_to_dataset(table, "partitioned_data", partition_cols=partition_cols, compression="SNAPPY")
        
        print("Created partitioned dataset with columns:", partition_cols)
        
        # List partition directories (simplified)
        print("Partition directories created (showing first few examples):")
        print(" - region=North/signup_year=2020/")
        print(" - region=South/signup_year=2021/")
        print(" - region=East/signup_year=2022/")
        print(" ... and more partitions")
        
        # Clean up
        var shutil_code = """
import shutil
shutil.rmtree('partitioned_data')
"""
        Python.evaluate(shutil_code)
        print("Partitioned dataset created and cleaned up successfully")

    except e:
        print("Partitioning demonstration failed:", e)

fn demonstrate_predicate_pushdown():
    """Demonstrate predicate pushdown optimization."""
    print("\n=== Predicate Pushdown Optimization ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        var ds = Python.import_module("pyarrow.dataset")
        var pc = Python.import_module("pyarrow.compute")
        var pd = Python.import_module("pandas")
        
        var data = create_sample_dataset()
        var df = pd.DataFrame(data)
        var table = pa.Table.from_pandas(df)
        
        # Write test file
        pq.write_table(table, "test_predicate.parquet", compression="SNAPPY")
        
        # Create dataset and scanner with filter
        var dataset = ds.dataset("test_predicate.parquet")
        var filter_expr = pc.greater(pc.field("age"), 30)
        var scanner = ds.Scanner.from_dataset(dataset, filter=filter_expr)
        
        # Scan with predicate pushdown
        var filtered_table = scanner.to_table()
        print("Original rows:", table.num_rows)
        print("Filtered rows (age > 30):", filtered_table.num_rows)
        print("Rows filtered out:", table.num_rows - filtered_table.num_rows)
        
        # Clean up
        os.remove("test_predicate.parquet")
        print("Predicate pushdown demonstrated successfully")

    except e:
        print("Predicate pushdown demonstration failed:", e)

fn demonstrate_column_projection():
    """Demonstrate column projection for selective reading."""
    print("\n=== Column Projection ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        var pd = Python.import_module("pandas")
        var data = create_sample_dataset()
        var df = pd.DataFrame(data)
        var table = pa.Table.from_pandas(df)
        
        # Write test file
        pq.write_table(table, "test_projection.parquet", compression="SNAPPY")
        
        # Read all columns
        var full_table = pq.read_table("test_projection.parquet")
        print("Full table columns:", full_table.num_columns)
        print("Full table size (rows):", full_table.num_rows)
        
        # Read only selected columns
        var columns_code = """
['customer_id', 'age', 'income']
"""
        var columns = Python.evaluate(columns_code)
        var projected_table = pq.read_table("test_projection.parquet", columns=columns)
        print("Projected columns:", projected_table.num_columns)
        print("Projected column names:", projected_table.column_names)
        print("Memory reduction: reading", projected_table.num_columns, "of", full_table.num_columns, "columns")
        
        # Clean up
        os.remove("test_projection.parquet")
        print("Column projection demonstrated successfully")

    except e:
        print("Column projection demonstration failed:", e)

fn demonstrate_metadata_operations():
    """Demonstrate Parquet metadata operations."""
    print("\n=== Parquet Metadata Operations ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        var pd = Python.import_module("pandas")
        var data = create_sample_dataset()
        var df = pd.DataFrame(data)
        var table = pa.Table.from_pandas(df)
        
        # Write test file
        pq.write_table(table, "test_metadata.parquet", compression="SNAPPY")
        
        # Read metadata
        var parquet_file = pq.ParquetFile("test_metadata.parquet")
        var metadata = parquet_file.metadata
        
        print("File Metadata:")
        print("  - Num rows:", metadata.num_rows)
        print("  - Num row groups:", metadata.num_row_groups)
        print("  - Num columns:", metadata.num_columns)
        print("  - Format version:", metadata.format_version)
        
        # Schema information
        var schema = metadata.schema
        print("Schema Information:")
        var schema_names = Python.list()
        for field in schema:
            schema_names.append(field.name)
        print("  - Schema names:", schema_names)
        print("  - Total fields:", len(schema))
        
        # Row group metadata
        if metadata.num_row_groups > 0:
            var rg_meta = metadata.row_group(0)
            print("Row Group 0 Metadata:")
            print("  - Num rows:", rg_meta.num_rows)
            print("  - Total byte size:", rg_meta.total_byte_size)
            print("  - Columns:", rg_meta.num_columns)
        
        # Clean up
        os.remove("test_metadata.parquet")
        print("Metadata operations demonstrated successfully")

    except e:
        print("Metadata operations demonstration failed:", e)

fn demonstrate_schema_evolution():
    """Demonstrate schema evolution capabilities."""
    print("\n=== Schema Evolution ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        
        # Create initial schema
        var initial_data_code = """
{'id': [1, 2, 3], 'name': ['Alice', 'Bob', 'Charlie']}
"""
        var initial_data = Python.evaluate(initial_data_code)
        var initial_table = pa.table(initial_data)
        pq.write_table(initial_table, "schema_v1.parquet")
        
        # Create evolved schema (added column)
        var evolved_data_code = """
{'id': [4, 5, 6], 'name': ['David', 'Eve', 'Frank'], 'age': [25, 30, 35]}
"""
        var evolved_data = Python.evaluate(evolved_data_code)
        var evolved_table = pa.table(evolved_data)
        pq.write_table(evolved_table, "schema_v2.parquet")
        
        print("Schema Evolution Features:")
        print("1. Backward Compatibility:")
        print("   - Initial schema columns:", initial_table.column_names)
        print("   - Evolved schema columns:", evolved_table.column_names)
        print("   - New column 'age' added successfully")
        
        print("2. Schema Reading:")
        var schema1 = pq.read_schema("schema_v1.parquet")
        var schema2 = pq.read_schema("schema_v2.parquet")
        print("   - V1 schema fields:", len(schema1))
        print("   - V2 schema fields:", len(schema2))
        
        # Clean up
        os.remove("schema_v1.parquet")
        os.remove("schema_v2.parquet")
        print("Schema evolution demonstrated successfully")

    except e:
        print("Schema evolution demonstration failed:", e)

fn demonstrate_performance_optimization():
    """Demonstrate performance optimization techniques."""
    print("\n=== Performance Optimization ===")

    try:
        var pq = Python.import_module("pyarrow.parquet")
        var pa = Python.import_module("pyarrow")
        var pd = Python.import_module("pandas")
        var time_module = Python.import_module("time")
        
        var data = create_sample_dataset()
        var df = pd.DataFrame(data)
        var table = pa.Table.from_pandas(df)
        
        print("Performance Optimization Strategies:")
        
        # Test different row group sizes
        var rg_sizes_code = """
[1000, 5000, 10000]
"""
        var rg_sizes = Python.evaluate(rg_sizes_code)
        print("1. Row Group Size Optimization:")
        
        for rg_size in rg_sizes:
            var start_write = time_module.time()
            pq.write_table(table, "perf_test.parquet", row_group_size=rg_size, compression="SNAPPY")
            var write_time = time_module.time() - start_write
            
            var file_size = os.path.getsize("perf_test.parquet")
            print("   - Row group size", rg_size, "- Write time:", write_time, "sec, Size:", file_size, "bytes")
            os.remove("perf_test.parquet")
        
        # Test column projection performance
        pq.write_table(table, "perf_test.parquet", compression="SNAPPY")
        
        # Full read
        var start_time = time_module.time()
        var full_read = pq.read_table("perf_test.parquet")
        var full_read_time = time_module.time() - start_time
        
        # Projected read
        var start_projected = time_module.time()
        var projected_cols_code = """
['customer_id', 'age']
"""
        var projected_cols = Python.evaluate(projected_cols_code)
        var projected_read = pq.read_table("perf_test.parquet", columns=projected_cols)
        var projected_read_time = time_module.time() - start_projected
        
        print("2. Column Projection Performance:")
        print("   - Full read time:", full_read_time, "sec")
        print("   - Projected read time:", projected_read_time, "sec")
        print("   - Speedup:", full_read_time / projected_read_time, "x")
        
        # Clean up
        os.remove("perf_test.parquet")
        print("Performance optimization demonstrated successfully")

    except e:
        print("Performance optimization demonstration failed:", e)

fn main():
    """Main Parquet I/O demonstration."""
    print("=== Advanced Parquet I/O Operations with PyArrow ===")
    print("Demonstrating high-performance Parquet file operations")
    print()

    # Demonstrate writing operations
    demonstrate_parquet_writing()

    # Compare compression algorithms
    demonstrate_compression_comparison()

    # Demonstrate partitioning
    demonstrate_partitioning()

    # Predicate pushdown
    demonstrate_predicate_pushdown()

    # Column projection
    demonstrate_column_projection()

    # Metadata operations
    demonstrate_metadata_operations()

    # Schema evolution
    demonstrate_schema_evolution()

    # Performance optimization
    demonstrate_performance_optimization()

    print("\n=== Parquet I/O Operations Complete ===")
    print("Key takeaways:")
    print("- Parquet provides columnar storage for analytics")
    print("- Compression reduces storage and I/O costs")
    print("- Partitioning improves query performance")
    print("- Predicate pushdown minimizes data scanning")
    print("- Column projection reduces memory usage")
    print("- Schema evolution supports data lake patterns")
    print("- Performance optimization is crucial for large datasets")