"""
JSON I/O Operations with PyArrow Integration
===========================================

This example demonstrates JSON reading operations using PyArrow
for efficient processing of JSON data in Mojo.

Key concepts covered:
- JSON reading with type inference
- Nested structure handling
- Incremental reading
- Schema inference
- Performance optimization
"""

from python import Python
from python import PythonObject


def main():
    print("=== JSON I/O Operations with PyArrow Integration ===")
    print("Demonstrating efficient JSON data processing\n")

    # Demonstrate JSON reading operations
    demonstrate_json_reading()

    # Show nested structure handling
    demonstrate_nested_structures()

    # Incremental reading operations
    demonstrate_incremental_json_reading()

    # Schema inference and validation
    demonstrate_schema_inference()

    # Performance optimization techniques
    demonstrate_performance_optimization()

    print("\n=== JSON I/O Operations Complete ===")
    print("Key takeaways:")
    print("- PyArrow provides fast JSON processing with automatic type inference")
    print("- Support for nested JSON structures and arrays")
    print("- Incremental reading enables processing large JSON files")
    print("- Schema inference creates structured data from JSON")
    print("- Performance optimizations for large-scale JSON processing")


def demonstrate_json_reading():
    """
    Demonstrate JSON reading operations with real PyArrow integration.
    """
    print("=== JSON Reading Operations ===")

    try:
        # Import PyArrow JSON module
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.json")

        # Create sample JSON Lines data
        jsonl_content = """{"user_id": 1, "event": "login", "timestamp": "2023-01-15T10:30:00Z", "metadata": {"ip": "192.168.1.1", "user_agent": "Chrome/91.0"}}
{"user_id": 2, "event": "purchase", "timestamp": "2023-01-15T10:35:00Z", "metadata": {"product_id": 123, "amount": 99.99}}
{"user_id": 1, "event": "logout", "timestamp": "2023-01-15T11:00:00Z", "metadata": {"session_duration": 1800}}"""

        # Write to temporary file
        json_file = "sample_events.jsonl"
        with open(json_file, "w") as f:
            f.write(jsonl_content)

        print("Created sample JSON Lines file:", json_file)

        # Read JSON with PyArrow
        table = pq.read_json(json_file)
        print("Successfully read JSON file")
        print("Table shape:", table.num_rows, "rows,", table.num_columns, "columns")
        print("Schema:", table.schema)
        print("Column names:", table.column_names)

        # Show sample data
        print("\nSample data:")
        num_rows = table.num_rows
        display_count = 3 if num_rows > 3 else num_rows
        for i in range(display_count):
            row = table.take([i])
            row_data = Python.list()
            col_names = table.column_names
            columns = row.columns
            for j in range(len(col_names)):
                col_name = col_names[j]
                col = columns[j]
                row_data.append(col_name + ": " + String(col.to_pylist()[0]))
            print("Row", i, ":", "{" + ", ".join(row_data) + "}")

        # Clean up
        import os
        os.remove(json_file)
        print("JSON reading demonstration completed successfully")

    except e:
        print("JSON reading demonstration failed:", String(e))


def demonstrate_nested_structures():
    """
    Demonstrate nested structure handling with real PyArrow operations.
    """
    print("\n=== Nested Structure Handling ===")

    try:
        # Import PyArrow JSON module
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.json")

        # Create sample nested JSON data
        nested_json = """{"user": {"name": "John", "age": 30}, "active": true}
{"user": {"name": "Jane", "age": 25}, "active": false, "tags": ["admin", "developer"]}
{"company": {"name": "TechCorp", "departments": [{"name": "Engineering", "employees": [{"name": "Alice", "role": "Engineer"}, {"name": "Bob", "role": "Manager"}]}]}}"""

        # Write to temporary file
        nested_file = "nested_data.jsonl"
        with open(nested_file, "w") as f:
            f.write(nested_json)

        print("Created nested JSON file:", nested_file)

        # Read nested JSON with PyArrow
        table = pq.read_json(nested_file)
        print("Successfully read nested JSON")
        print("Table shape:", table.num_rows, "rows,", table.num_columns, "columns")
        print("Schema:", table.schema)

        # Show nested structure access
        print("\nNested structure access:")
        num_rows = table.num_rows
        for i in range(num_rows):
            row = table.take([i])
            print("Row", i, "data:")
            # Iterate through columns manually
            col_names = table.column_names
            columns = row.columns
            for j in range(len(col_names)):
                col_name = col_names[j]
                col = columns[j]
                print("  ", col_name, ":", col.to_pylist()[0])

        # Demonstrate struct field access
        if "user" in table.column_names:
            user_col = table.column("user")
            print("\nUser struct details:")
            user_len = user_col.length()
            for i in range(user_len):
                user_struct = user_col[i]
                if user_struct.is_valid:
                    print("  User", i, ":", user_struct.as_py())

        # Clean up
        import os
        os.remove(nested_file)
        print("Nested structures demonstration completed successfully")

    except e:
        print("Nested structures demonstration failed:", String(e))


def demonstrate_incremental_json_reading():
    """
    Demonstrate incremental JSON reading operations with real PyArrow chunked reading.
    """
    print("\n=== Incremental JSON Reading ===")

    try:
        # Import PyArrow JSON module
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.json")

        # Create larger sample JSON Lines data
        json_records = Python.list()
        for i in range(100):  # Create 100 records
            record = Python.dict()
            record["id"] = i
            record["value"] = i * 1.5
            record["category"] = "type_" + String(i % 10)
            json_records.append(record)

        # Import json module
        json_mod = Python.import_module("json")

        # Convert to JSON lines
        json_lines = Python.list()
        for record in json_records:
            json_str = json_mod.dumps(record)
            json_lines.append(json_str)  # Keep as Python string

        # Join with newlines using Python
        newline = Python.evaluate("'\\n'")
        jsonl_content = newline.join(json_lines)

        print("Sample JSON content:")
        lines = String(jsonl_content).split("\n")
        for i in range(min(3, len(lines))):
            print("  ", lines[i])

        # Write to temporary file
        large_json_file = "large_events.jsonl"
        with open(large_json_file, "w") as f:
            f.write(String(jsonl_content))

        print("Created large JSON Lines file:", large_json_file)
        print("Records:", len(json_records))

        # Read JSON with chunked reading
        table = pq.read_json(large_json_file)
        print("Successfully read JSON file with", table.num_rows, "records")

        # Demonstrate chunked processing
        chunk_size = 100
        total_count = PythonObject(0)

        print("\nProcessing in chunks of", chunk_size, "records:")
        table_rows = table.num_rows
        num_chunks = (table_rows + chunk_size - 1) // chunk_size  # Ceiling division
        for chunk_idx in range(num_chunks):
            start_idx = chunk_idx * chunk_size
            remaining = table_rows - start_idx
            actual_chunk_size = chunk_size if remaining > chunk_size else remaining
            chunk = table.slice(start_idx, actual_chunk_size)

            chunk_count = chunk.num_rows
            total_count += chunk_count

            print("  Chunk", chunk_idx + 1, ": records", start_idx, "-", start_idx + actual_chunk_size - 1,
                  ", processed =", chunk_count, "records")

        print("\nTotal processed:", total_count, "records")

        # Clean up
        import os
        os.remove(large_json_file)
        print("Incremental JSON reading demonstration completed successfully")

    except e:
        print("Incremental JSON reading demonstration failed:", String(e))


def demonstrate_schema_inference():
    """
    Demonstrate schema inference and validation with real PyArrow operations.
    """
    print("\n=== Schema Inference and Validation ===")

    try:
        # Import PyArrow JSON module
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.json")

        # Create sample JSON with varying structures
        varied_json = """{"name": "Alice", "age": 30, "active": true, "score": 95.5}
{"name": "Bob", "age": 25, "active": false, "tags": ["developer", "python"]}
{"name": "Charlie", "age": 35, "score": 87.2, "department": "Engineering"}
{"name": "Diana", "age": 28, "active": true, "tags": ["designer"], "department": "Design", "score": null}"""

        # Write to temporary file
        schema_file = "varied_schema.jsonl"
        with open(schema_file, "w") as f:
            f.write(varied_json)

        print("Created JSON file with varying schema:", schema_file)

        # Read JSON and show inferred schema
        table = pq.read_json(schema_file)
        print("Successfully read JSON with schema inference")
        print("Inferred schema:")
        print(table.schema)

        print("\nField-by-field analysis:")
        for field in table.schema:
            print("  ", field.name, ":", field.type)

        print("\nData sample:")
        table_rows = table.num_rows
        for i in range(table_rows):
            row = table.take([i])
            row_dict = Python.dict()
            col_names = table.column_names
            columns = row.columns
            for j in range(len(col_names)):
                col_name = col_names[j]
                col = columns[j]
                row_dict[col_name] = col.to_pylist()[0]
            print("  Row", i, ":", row_dict)

        # Demonstrate null handling
        print("\nNull value analysis:")
        for col_name in table.column_names:
            col = table.column(col_name)
            null_count = col.null_count
            print("  ", col_name, ": nulls =", null_count, "/", col.length())

        # Clean up
        import os
        os.remove(schema_file)
        print("Schema inference demonstration completed successfully")

    except e:
        print("Schema inference demonstration failed:", String(e))


def demonstrate_performance_optimization():
    """
    Demonstrate performance optimization techniques with real PyArrow operations.
    """
    print("\n=== Performance Optimization ===")

    try:
        # Import PyArrow and time modules
        pyarrow = Python.import_module("pyarrow")
        pq = Python.import_module("pyarrow.json")
        time_mod = Python.import_module("time")

        # Create test data
        test_records = Python.list()
        for i in range(1000):  # 1k records for performance testing
            record = Python.dict()
            record["id"] = i
            record["value"] = i * 1.1
            record["category"] = "cat_" + String(i % 100)
            test_records.append(record)

        # Import json module
        json_mod = Python.import_module("json")

        # Convert to JSON lines
        test_json_lines = Python.list()
        for record in test_records:
            json_str = json_mod.dumps(record)
            test_json_lines.append(json_str)  # Keep as Python string

        # Join with newlines using Python
        newline = Python.evaluate("'\\n'")
        test_json = newline.join(test_json_lines)

        print("Sample test JSON content:")
        lines = String(test_json).split("\n")
        for i in range(min(3, len(lines))):
            print("  ", lines[i])

        # Write to temporary file
        perf_file = "performance_test.jsonl"
        with open(perf_file, "w") as f:
            f.write(String(test_json))

        print("Created performance test file:", perf_file)
        print("Records:", len(test_records))

        # Measure read performance
        start_time = time_mod.time()
        table = pq.read_json(perf_file)
        end_time = time_mod.time()

        read_time = end_time - start_time
        throughput = (len(test_json) / 1024 / 1024) / read_time  # MB/s

        print("Performance results:")
        print("  Records read:", table.num_rows)
        print("  Read time:", read_time, "seconds")
        print("  Throughput:", throughput, "MB/s")
        print("  Schema:", table.schema)

        # Demonstrate basic column operations
        print("\nColumn operations:")
        id_col = table.column("id")
        value_col = table.column("value")

        print("  ID column length:", id_col.length())
        print("  Value column length:", value_col.length())

        # Simple filtering
        print("\nFiltering operations:")
        category_col = table.column("category")
        filtered_count = 0
        cat_len = category_col.length()
        sample_size = 1000
        for i in range(sample_size):  # Check first 1000
            cat_value = category_col[i].as_py()
            cat_str = String(cat_value)
            if "cat_5" in cat_str:
                filtered_count += 1

        print("  Records with category containing 'cat_5' (first 1000):", filtered_count)

        # Clean up
        import os
        os.remove(perf_file)
        print("Performance optimization demonstration completed successfully")

    except e:
        print("Performance optimization demonstration failed:", String(e))