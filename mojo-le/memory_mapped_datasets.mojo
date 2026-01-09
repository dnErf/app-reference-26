"""
Memory-Mapped Datasets with PyArrow Integration
==============================================

This example demonstrates memory-mapped dataset operations using PyArrow
for efficient large dataset processing in Mojo.

Key concepts covered:
- Memory-mapped file I/O
- Large dataset processing
- Zero-copy operations
- Memory management optimization
- Dataset scanning and filtering
"""

from python import Python
from python import PythonObject


def main():
    print("=== Memory-Mapped Datasets with PyArrow Integration ===")
    print("Demonstrating efficient large dataset processing\n")

    # Demonstrate memory-mapped file operations
    demonstrate_memory_mapped_io()

    # Show large dataset processing
    demonstrate_large_dataset_processing()

    # Zero-copy operations
    demonstrate_zero_copy_operations()

    print("\n=== Memory-Mapped Datasets Complete ===")
    print("Key takeaways:")
    print("- Memory mapping enables efficient large file access")
    print("- Zero-copy operations reduce memory overhead")
    print("- Dataset scanning optimizes query performance")
    print("- PyArrow provides scalable data processing")


def demonstrate_memory_mapped_io():
    """
    Demonstrate memory-mapped file I/O operations with real PyArrow operations.
    """
    print("=== Memory-Mapped File I/O ===")

    try:
        # Import PyArrow modules
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.parquet")
        pa = Python.import_module("pyarrow")

        # Create sample data for demonstration
        data = Python.dict()
        data["id"] = Python.list()
        data["value"] = Python.list()
        data["category"] = Python.list()

        for i in range(100):  # Create 100 records for faster testing
            data["id"].append(i)
            data["value"].append(i * 1.5)
            data["category"].append("cat_" + String(i % 10))

        # Create Arrow table
        table = pa.table(data)
        print("Created Arrow table with", table.num_rows, "rows")

        # Write to Parquet file with memory mapping preparation
        parquet_file = "memory_mapped_demo.parquet"
        pq.write_table(table, parquet_file)
        print("Written to Parquet file:", parquet_file)

        # Read with memory mapping
        print("\nReading with memory mapping enabled:")
        memory_mapped_table = pq.read_table(parquet_file, memory_map=True)
        print("Memory-mapped table loaded successfully")
        print("Schema:", memory_mapped_table.schema)
        print("Number of rows:", memory_mapped_table.num_rows)
        print("Number of columns:", memory_mapped_table.num_columns)

        # Demonstrate memory efficiency
        print("\nMemory mapping benefits:")
        print("- File mapped to virtual memory without full loading")
        print("- Data accessed on-demand (lazy loading)")
        print("- Reduced physical memory usage for large files")

        # Clean up
        import os
        os.remove(parquet_file)
        print("Memory-mapped I/O demonstration completed successfully")

    except e:
        print("Memory-mapped I/O demonstration failed:", String(e))


def demonstrate_large_dataset_processing():
    """
    Demonstrate processing of large datasets beyond RAM capacity with real PyArrow dataset operations.
    """
    print("\n=== Large Dataset Processing ===")

    try:
        # Import PyArrow dataset module
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.parquet")
        ds = Python.import_module("pyarrow.dataset")
        pa = Python.import_module("pyarrow")

        # Create larger sample dataset
        print("Creating large sample dataset...")
        data = Python.dict()
        data["customer_id"] = Python.list()
        data["transaction_amount"] = Python.list()
        data["transaction_date"] = Python.list()
        data["product_category"] = Python.list()

        for i in range(1000):  # 1k records for faster testing
            data["customer_id"].append(i % 100)  # 100 customers
            data["transaction_amount"].append((i % 500) + 10.0)
            data["transaction_date"].append("2023-01-01")
            data["product_category"].append("category_" + String(i % 5))

        # Create Arrow table
        table = pa.table(data)
        print("Created dataset with", table.num_rows, "transactions")

        # Write to partitioned Parquet dataset
        dataset_path = "large_dataset_demo"
        pq.write_to_dataset(table, dataset_path, partition_cols=["product_category"])
        print("Written to partitioned dataset:", dataset_path)

        # Create dataset object for scanning
        dataset = ds.dataset(dataset_path, format="parquet")
        print("\nDataset created for scanning operations")

        # Demonstrate scanning with filtering
        print("\nScanning with filtering (amount > 100):")
        filter_expr = pa.compute.greater(pa.compute.field("transaction_amount"), 100.0)
        scanner = ds.Scanner.from_dataset(dataset, filter=filter_expr)

        # Count matching records
        count = PythonObject(0)
        for batch in scanner.to_batches():
            count += batch.num_rows

        print("Records with amount > 100:", count)

        # Demonstrate chunked processing
        print("\nChunked processing demonstration:")
        scanner = ds.Scanner.from_dataset(dataset)
        batch_count = PythonObject(0)
        total_rows = PythonObject(0)

        for batch in scanner.to_batches():
            batch_count += 1
            total_rows += batch.num_rows
            print("  Batch", batch_count, ": rows =", batch.num_rows, ", columns =", batch.num_columns)

            # Process only first few batches for demo
            if batch_count >= 3:
                print("  ... (stopping after 3 batches for demo)")
                break

        print("Total rows processed:", total_rows)
        print("Large dataset processing demonstration completed successfully")

        # Clean up
        shutil = Python.import_module("shutil")
        shutil.rmtree(dataset_path)
        print("Cleanup completed")

    except e:
        print("Large dataset processing demonstration failed:", String(e))


def demonstrate_zero_copy_operations():
    """
    Demonstrate zero-copy data operations with real PyArrow memory management.
    """
    print("\n=== Zero-Copy Operations ===")

    try:
        # Import PyArrow modules
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.parquet")
        pa = Python.import_module("pyarrow")

        # Create sample data
        data = Python.dict()
        data["sensor_id"] = Python.list()
        data["temperature"] = Python.list()
        data["humidity"] = Python.list()
        data["timestamp"] = Python.list()

        for i in range(1000):  # 1k records for faster testing
            data["sensor_id"].append("sensor_" + String(i % 10))
            data["temperature"].append(20.0 + (i % 20))
            data["humidity"].append(40.0 + (i % 30))
            data["timestamp"].append("2023-01-01T12:00:00")

        # Create Arrow table
        table = pa.table(data)
        print("Created sensor data table with", table.num_rows, "records")

        # Write to Parquet (zero-copy during writing)
        parquet_file = "zero_copy_demo.parquet"
        pq.write_table(table, parquet_file)
        print("Written to Parquet with zero-copy optimization")

        # Read with memory mapping (zero-copy access)
        print("\nReading with zero-copy memory mapping:")
        mapped_table = pq.read_table(parquet_file, memory_map=True)
        print("Zero-copy table access established")

        # Demonstrate zero-copy column access
        print("\nZero-copy column operations:")
        temp_col = mapped_table.column("temperature")
        humid_col = mapped_table.column("humidity")

        print("Temperature column length:", temp_col.length())
        print("Humidity column length:", humid_col.length())

        # Calculate statistics without copying data
        temp_sum = PythonObject(0.0)
        humid_sum = PythonObject(0.0)

        sample_size = 1000

        for i in range(sample_size):  # Sample first 1000
            temp_sum += temp_col[i].as_py()
            humid_sum += humid_col[i].as_py()

        avg_temp = temp_sum / sample_size
        avg_humid = humid_sum / sample_size

        print("Average temperature (first", sample_size, "):", avg_temp)
        print("Average humidity (first", sample_size, "):", avg_humid)

        # Demonstrate slicing without copying
        print("\nZero-copy slicing operations:")
        slice_table = mapped_table.slice(100, 50)  # Rows 100-149
        print("Sliced table (rows 100-149):", slice_table.num_rows, "rows")

        # Show that slicing creates views, not copies
        print("Original table still accessible:", mapped_table.num_rows, "rows")
        print("Zero-copy operations completed successfully")

        # Clean up
        import os
        os.remove(parquet_file)
        print("Cleanup completed")

    except e:
        print("Zero-copy operations demonstration failed:", String(e))