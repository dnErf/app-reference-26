"""
IPC Streaming with PyArrow Integration
=====================================

This example demonstrates IPC (Inter-Process Communication) streaming
operations using PyArrow for efficient data serialization and transfer in Mojo.

Key concepts covered:
- IPC stream format for sequential data
- IPC file format for random access
- Record batch streaming
- Zero-copy operations
- Memory-mapped IPC files
"""

from python import Python
from python import PythonObject


def main():
    print("=== IPC Streaming with PyArrow Integration ===")
    print("Demonstrating efficient data serialization and streaming\n")

    # Demonstrate IPC streaming format
    demonstrate_ipc_streaming()

    # Show IPC file format operations
    demonstrate_ipc_file_format()

    # Record batch operations
    demonstrate_record_batch_operations()

    # Zero-copy streaming
    demonstrate_zero_copy_streaming()

    # Memory-mapped IPC operations
    demonstrate_memory_mapped_ipc()

    print("\n=== IPC Streaming Complete ===")
    print("Key takeaways:")
    print("- IPC enables efficient inter-process data transfer")
    print("- Streaming format for sequential access, file format for random access")
    print("- Zero-copy operations minimize memory overhead")
    print("- Record batches provide flexible data chunks")
    print("- Memory mapping enables large dataset handling")


def demonstrate_ipc_streaming():
    """
    Demonstrate IPC streaming format for sequential data transfer.
    """
    print("=== IPC Streaming Format ===")

    try:
        # Import PyArrow IPC module
        pyarrow = Python.import_module("pyarrow")
        pa = pyarrow
        ipc_mod = pyarrow.ipc

        # Create simple sample data
        schema = Python.evaluate("import pyarrow as pa; pa.schema([('id', pa.int64()), ('value', pa.float64())])")

        # Create a simple record batch
        ids = Python.list()
        values = Python.list()
        for i in range(10):
            ids.append(i)
            values.append(i * 1.5)

        id_array = pa.array(ids, type=pa.int64())
        val_array = pa.array(values, type=pa.float64())
        batch = pa.record_batch([id_array, val_array], names=["id", "value"])

        print("Created record batch with", batch.num_rows(), "rows")
        print("Schema:", schema)

        # Write to IPC stream
        stream_file = "sensor_stream.arrow"
        stream = pa.output_stream(stream_file)
        writer = ipc_mod.new_stream_writer(stream, schema)
        writer.write_batch(batch)
        writer.close()
        stream.close()

        print("Wrote IPC stream to:", stream_file)

        # Read from IPC stream
        stream = pa.input_stream(stream_file)
        reader = ipc_mod.open_stream(stream)
        print("Stream schema:", reader.schema)
        print("Number of batches in stream:", reader.num_record_batches)

        read_batch = reader.get_batch(0)
        print("Read batch with", read_batch.num_rows(), "rows")
        print("Sample data - IDs:", read_batch.column(0).to_pylist()[:5])
        print("Sample data - Values:", read_batch.column(1).to_pylist()[:5])

        stream.close()

        # Clean up
        import os
        os.remove(stream_file)
        print("IPC streaming demonstration completed successfully")

    except e:
        print("IPC streaming demonstration failed:", String(e))


def demonstrate_ipc_file_format():
    """
    Demonstrate IPC file format for random access data operations.
    """
    print("\n=== IPC File Format ===")

    try:
        # Import PyArrow IPC module
        pyarrow = Python.import_module("pyarrow")
        pa = pyarrow
        ipc_mod = pyarrow.ipc

        # Create sample analytics data
        schema = Python.evaluate("import pyarrow as pa; pa.schema([('user_id', pa.int64()), ('event', pa.string()), ('timestamp', pa.int64())])")

        # Create multiple record batches
        batches = Python.list()
        events = Python.list()
        events.append("login")
        events.append("click")
        events.append("purchase")
        events.append("logout")
        events.append("view")

        for i in range(5):  # 5 batches for demo
            user_ids = Python.list()
            event_types = Python.list()
            timestamps = Python.list()

            for j in range(10):  # 10 rows per batch
                user_ids.append(i * 10 + j + 1)
                event_types.append(events[(i + j) % len(events)])
                timestamps.append(1672531200 + (i * 86400) + (j * 3600))  # Jan 2023 timestamps

            uid_array = pa.array(user_ids, type=pa.int64())
            event_array = pa.array(event_types, type=pa.string())
            ts_array = pa.array(timestamps, type=pa.int64())

            batch = pa.record_batch([uid_array, event_array, ts_array], names=["user_id", "event", "timestamp"])
            batches.append(batch)

        print("Created", len(batches), "record batches with", batches[0].num_rows(), "rows each")

        # Calculate total rows
        total_rows = PythonObject(0)
        for batch in batches:
            total_rows += batch.num_rows()
        print("Total rows:", total_rows)

        # Write to IPC file
        ipc_file = "analytics_data.arrow"
        stream = pa.output_stream(ipc_file)
        writer = ipc_mod.new_file_writer(stream, schema)
        for batch in batches:
            writer.write_batch(batch)
        writer.close()
        stream.close()

        print("Wrote IPC file:", ipc_file)

        # Read from IPC file with random access
        stream = pa.input_stream(ipc_file)
        reader = ipc_mod.open_file(stream)
        print("File schema:", reader.schema)
        print("Number of batches:", reader.num_record_batches)
        print("File metadata available:", reader.metadata is not None)

        # Random access examples
        print("\nRandom Access Examples:")
        first_batch = reader.get_batch(0)
        print("Batch 0 - First batch rows:", first_batch.num_rows())

        middle_batch = reader.get_batch(25)
        print("Batch 25 - Middle batch rows:", middle_batch.num_rows())

        last_batch = reader.get_batch(reader.num_record_batches - 1)
        print("Batch", reader.num_record_batches - 1, "- Last batch rows:", last_batch.num_rows())

        # Show sample data from different batches
        print("\nSample data from Batch 0:")
        print("User IDs:", first_batch.column(0).to_pylist()[:5])
        print("Events:", first_batch.column(1).to_pylist()[:5])

        print("\nSample data from Batch 25:")
        print("User IDs:", middle_batch.column(0).to_pylist()[:5])
        print("Events:", middle_batch.column(1).to_pylist()[:5])

        # Clean up
        import os
        os.remove(ipc_file)
        print("IPC file format demonstration completed successfully")

    except e:
        print("IPC file format demonstration failed:", String(e))


def demonstrate_record_batch_operations():
    """
    Demonstrate record batch operations in IPC streaming.
    """
    print("\n=== Record Batch Operations ===")

    try:
        # Import PyArrow
        pyarrow = Python.import_module("pyarrow")
        pa = pyarrow

        # Create sample sensor data
        schema = Python.evaluate("import pyarrow as pa; pa.schema([('sensor_id', pa.int32()), ('reading', pa.float64()), ('timestamp', pa.int64())])")

        print("Schema:", schema)

        # Create initial batch
        sensor_ids_py = Python.list()
        for id in [1, 1, 2, 2, 3, 3]:
            sensor_ids_py.append(id)
        readings_py = Python.list()
        for r in [23.5, 24.1, 1013.2, 1012.8, 65.4, 66.1]:
            readings_py.append(r)
        timestamps_py = Python.list()
        for ts in [1000, 2000, 1000, 2000, 1000, 2000]:
            timestamps_py.append(ts)

        sid_array = pa.array(sensor_ids_py, type=pa.int32())
        reading_array = pa.array(readings_py, type=pa.float64())
        ts_array = pa.array(timestamps_py, type=pa.int64())

        batch1 = pa.record_batch([sid_array, reading_array, ts_array], names=["sensor_id", "reading", "timestamp"])
        print("Created batch 1 with", batch1.num_rows(), "rows")
        print("Batch 1 data:")
        print("  Sensor IDs:", batch1.column(0).to_pylist())
        print("  Readings:", batch1.column(1).to_pylist())

        # Create second batch
        sensor_ids2_py = Python.list()
        for id in [1, 2, 3, 4]:
            sensor_ids2_py.append(id)
        readings2_py = Python.list()
        for r in [24.5, 1014.1, 67.2, 15.8]:
            readings2_py.append(r)
        timestamps2_py = Python.list()
        for ts in [3000, 3000, 3000, 3000]:
            timestamps2_py.append(ts)

        sid_array2 = pa.array(sensor_ids2_py, type=pa.int32())
        reading_array2 = pa.array(readings2_py, type=pa.float64())
        ts_array2 = pa.array(timestamps2_py, type=pa.int64())

        batch2 = pa.record_batch([sid_array2, reading_array2, ts_array2], names=["sensor_id", "reading", "timestamp"])
        print("\nCreated batch 2 with", batch2.num_rows(), "rows")

        # Batch concatenation
        combined_batch = pa.Table.from_batches([batch1, batch2]).to_batches()[0]
        print("\nCombined batch has", combined_batch.num_rows(), "rows")

        # Batch filtering (simple example - readings > 50)
        readings_col = combined_batch.column(1)
        mask = Python.list()
        for i in range(readings_col.length()):
            mask.append(readings_col[i].as_py() > 50)

        mask_array = pa.array(mask, type=pa.bool_())
        filtered_batch = combined_batch.filter(mask_array)
        print("Filtered batch (readings > 50) has", filtered_batch.num_rows(), "rows")
        print("Filtered readings:", filtered_batch.column(1).to_pylist())

        # Batch serialization to IPC
        batch_file = "batch_demo.arrow"
        stream = pa.output_stream(batch_file)
        writer = pa.ipc.new_file_writer(stream, schema)
        writer.write_batch(batch1)
        writer.write_batch(batch2)
        writer.write_batch(filtered_batch)
        writer.close()
        stream.close()

        print("\nWrote 3 batches to IPC file:", batch_file)

        # Read back and verify
        stream = pa.input_stream(batch_file)
        reader = pa.ipc.open_file(stream)
        print("Read back", reader.num_record_batches, "batches")
        for i in range(reader.num_record_batches):
            batch = reader.get_batch(i)
            print("  Batch", i, ":", batch.num_rows(), "rows")
        stream.close()

        # Clean up
        import os
        os.remove(batch_file)
        print("Record batch operations demonstration completed successfully")

    except e:
        print("Record batch operations demonstration failed:", String(e))


def demonstrate_zero_copy_streaming():
    """
    Demonstrate zero-copy operations in IPC streaming.
    """
    print("\n=== Zero-Copy Streaming ===")

    try:
        # Import PyArrow
        pyarrow = Python.import_module("pyarrow")
        pa = pyarrow

        # Create large dataset
        schema = Python.evaluate("import pyarrow as pa; pa.schema([('data', pa.int64())])")

        # Create a large array
        large_data = Python.list()
        for i in range(10000):
            large_data.append(i * 2)

        array = pa.array(large_data, type=pa.int64())
        table = pa.table([array], names=["data"])

        print("Created table with", table.num_rows(), "rows")
        print("Table size estimate:", table.nbytes(), "bytes")

        # Write to IPC file
        ipc_file = "zero_copy_demo.arrow"
        stream = pa.output_stream(ipc_file)
        writer = pa.ipc.new_file_writer(stream, schema)
        # Convert table to batches for writing
        batches = table.to_batches()
        for batch in batches:
            writer.write_batch(batch)
        writer.close()
        stream.close()

        print("Wrote data to IPC file")

        # Demonstrate zero-copy reading
        stream = pa.input_stream(ipc_file)
        reader = pa.ipc.open_file(stream)

        # Read all batches
        all_batches = Python.list()
        for i in range(reader.num_record_batches):
            batch = reader.get_batch(i)
            all_batches.append(batch)
        stream.close()

        print("Read", len(all_batches), "batches")

        # Combine into table (zero-copy where possible)
        combined_table = pa.Table.from_batches(all_batches)
        print("Combined table has", combined_table.num_rows(), "rows")

        # Demonstrate column access (zero-copy)
        data_column = combined_table.column(0)
        print("Column type:", data_column.type)
        print("First 10 values:", data_column.to_pylist()[:10])
        print("Last 10 values:", data_column.to_pylist()[-10:])

        # Calculate sum without full materialization
        total = PythonObject(0)
        length = data_column.length()
        sample_size = 100 if length > 100 else length
        for i in range(sample_size):  # Sample first values
            total += data_column[i].as_py()
        print("Sum of first", sample_size, "values:", total)

        # Demonstrate memory efficiency
        import os
        file_size = os.path.getsize(ipc_file)
        print("File size on disk:", file_size, "bytes")
        print("Memory efficiency: Data stored efficiently on disk")

        # Clean up
        os.remove(ipc_file)
        print("Zero-copy streaming demonstration completed successfully")

    except e:
        print("Zero-copy streaming demonstration failed:", String(e))


def demonstrate_memory_mapped_ipc():
    """
    Demonstrate memory-mapped IPC file operations.
    """
    print("\n=== Memory-Mapped IPC Operations ===")

    try:
        # Import PyArrow
        pyarrow = Python.import_module("pyarrow")
        pa = pyarrow

        # Create a moderately large dataset
        schema = Python.evaluate("import pyarrow as pa; pa.schema([('id', pa.int64()), ('category', pa.string()), ('value', pa.float64())])")

        # Create data
        categories_py = Python.list()
        for cat in ["A", "B", "C", "D", "E"]:
            categories_py.append(cat)
        var batches = Python.list()

        for i in range(20):  # 20 batches
            ids = Python.list()
            cats = Python.list()
            values = Python.list()

            for j in range(500):  # 500 rows per batch
                ids.append(i * 500 + j)
                cats.append(categories_py[(i + j) % len(categories_py)])
                values.append((i + j) * 1.5)

            id_array = pa.array(ids, type=pa.int64())
            cat_array = pa.array(cats, type=pa.string())
            val_array = pa.array(values, type=pa.float64())

            batch = pa.record_batch([id_array, cat_array, val_array], names=["id", "category", "value"])
            batches.append(batch)

        print("Created", len(batches), "batches with", batches[0].num_rows(), "rows each")
        total_rows = PythonObject(0)
        for batch in batches:
            total_rows += batch.num_rows()
        print("Total rows:", total_rows)

        # Write to IPC file
        mmap_file = "memory_mapped_demo.arrow"
        stream = pa.output_stream(mmap_file)
        writer = pa.ipc.new_file_writer(stream, schema)
        for batch in batches:
            writer.write_batch(batch)
        writer.close()
        stream.close()

        import os
        file_size = os.path.getsize(mmap_file)
        print("IPC file size:", file_size, "bytes")

        # Memory-map the file for reading
        print("\nMemory-mapping the IPC file...")
        mmap_stream = pa.memory_map(mmap_file)
        reader = pa.ipc.open_file(mmap_stream)

        print("Memory-mapped reader opened")
        print("Schema:", reader.schema)
        print("Number of batches:", reader.num_record_batches)

        # Demonstrate random access (memory-mapped)
        print("\nRandom access examples:")

        # Access first batch
        batch0 = reader.get_batch(0)
        print("Batch 0 - rows:", batch0.num_rows())
        print("  Sample IDs:", batch0.column(0).to_pylist()[:3])
        print("  Sample categories:", batch0.column(1).to_pylist()[:3])

        # Access middle batch
        middle_idx = reader.num_record_batches // 2
        batch_middle = reader.get_batch(middle_idx)
        print("Batch", middle_idx, "- rows:", batch_middle.num_rows())
        print("  Sample values:", batch_middle.column(2).to_pylist()[:3])

        # Access last batch
        last_idx = reader.num_record_batches - 1
        batch_last = reader.get_batch(last_idx)
        print("Batch", last_idx, "- rows:", batch_last.num_rows())

        # Demonstrate efficient querying (simulated)
        print("\nSimulating efficient category filtering:")
        category_a_count = 0
        for i in range(reader.num_record_batches):
            batch = reader.get_batch(i)
            categories = batch.column(1)
            for j in range(categories.length()):
                if categories[j].as_py() == "A":
                    category_a_count += 1

        print("Total records with category 'A':", category_a_count)

        # Close memory-mapped stream
        mmap_stream.close()

        # Clean up
        os.remove(mmap_file)
        print("Memory-mapped IPC demonstration completed successfully")

    except e:
        print("Memory-mapped IPC demonstration failed:", String(e))