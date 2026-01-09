"""
ORC I/O Operations with PyArrow Integration
===========================================

This example demonstrates ORC (Optimized Row Columnar) file operations
using PyArrow for high-performance columnar data processing in Mojo.

Key concepts covered:
- ORC file reading and writing
- Compression algorithms
- Stripe-based operations
- Metadata access
- Column projection
"""

from python import Python
from python import PythonObject


fn main() raises:
    print("=== ORC I/O Operations with PyArrow Integration ===")
    print("Demonstrating high-performance ORC file operations\n")

    # Demonstrate ORC file operations
    demonstrate_orc_file_operations()

    # Show compression options
    demonstrate_compression_options()

    # Stripe-based reading
    demonstrate_stripe_operations()

    # Metadata and schema operations
    demonstrate_metadata_operations()

    # Column projection and filtering
    demonstrate_column_projection()

    print("\n=== ORC I/O Operations Complete ===")
    print("Key takeaways:")
    print("- ORC provides efficient columnar storage for analytics")
    print("- Compression reduces storage costs and improves performance")
    print("- Stripe-based operations enable parallel processing")
    print("- Metadata operations provide file introspection")
    print("- Column projection optimizes query performance")


fn demonstrate_orc_file_operations() raises:
    """
    Demonstrate basic ORC file reading and writing operations.
    """
    print("=== REAL ORC File Operations ===")

    var pa = Python.import_module("pyarrow")
    var orc = Python.import_module("pyarrow.orc")
    var pd = Python.import_module("pandas")

    print("REAL CODE: PyArrow ORC modules imported")
    print("orc = Python.import_module('pyarrow.orc')")
    print("orc.__version__ = " + String(pa.__version__))

    # Create sample data
    print("\nREAL CODE: Creating sample dataset")
    var data_dict = Python.dict()
    data_dict['id'] = Python.list()
    data_dict['name'] = Python.list()
    data_dict['score'] = Python.list()
    data_dict['active'] = Python.list()

    var names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"]
    for i in range(1, 101):  # Create 100 rows
        data_dict['id'].append(i)
        var name_idx = (i - 1) % len(names)
        data_dict['name'].append(names[name_idx])
        data_dict['score'].append(85.0 + (i % 15))
        data_dict['active'].append((i % 3) != 0)

    print("REAL CODE: var df = pd.DataFrame(data_dict)")
    var df = pd.DataFrame(data_dict)
    print("REAL CODE: var table = pa.Table.from_pandas(df)")
    var table = pa.Table.from_pandas(df)

    print("Table created with:")
    print("  - Rows:", String(table.num_rows))
    print("  - Columns:", String(table.num_columns))
    print("  - Schema:", String(table.schema))

    # Write to ORC file
    print("\nREAL CODE: Writing table to ORC file")
    print("orc.write_table(table, 'sample_data.orc')")
    orc.write_table(table, "sample_data.orc")

    # Read back from ORC file
    print("\nREAL CODE: Reading back from ORC file")
    print("var orc_table = orc.read_table('sample_data.orc')")
    var orc_table = orc.read_table("sample_data.orc")

    print("ORC file read successfully:")
    print("  - Rows:", String(orc_table.num_rows))
    print("  - Columns:", String(orc_table.num_columns))
    print("  - Schema matches:", String(orc_table.schema.equals(table.schema)))


fn demonstrate_compression_options() raises:
    """
    Demonstrate ORC compression algorithms and their trade-offs.
    """
    print("\n=== REAL ORC Compression Options ===")

    var pa = Python.import_module("pyarrow")
    var orc = Python.import_module("pyarrow.orc")
    var pd = Python.import_module("pandas")

    # Create larger dataset for compression testing
    print("REAL CODE: Creating larger dataset for compression testing")
    var data_dict = Python.dict()
    data_dict['id'] = Python.list()
    data_dict['category'] = Python.list()
    data_dict['value'] = Python.list()
    data_dict['description'] = Python.list()

    var categories = ["A", "B", "C", "D", "E"]
    for i in range(1, 10001):  # 10,000 rows
        data_dict['id'].append(i)
        var cat_idx = (i - 1) % len(categories)
        data_dict['category'].append(categories[cat_idx])
        data_dict['value'].append(i * 1.5)
        data_dict['description'].append("Description for item " + String(i))

    var df = pd.DataFrame(data_dict)
    var table = pa.Table.from_pandas(df)

    # Test different compression algorithms
    var compressions = ["UNCOMPRESSED", "SNAPPY", "ZSTD", "LZ4"]

    print("\nREAL CODE: Testing compression algorithms")
    for compression in compressions:
        var filename = "test_compression_" + compression + ".orc"
        print("orc.write_table(table, '" + filename + "', compression='" + compression + "')")
        orc.write_table(table, filename, compression=compression)

        # Get file size (simplified - in real code you'd use os.path.getsize)
        print("Compression '" + compression + "' file created: " + filename)

    print("\nCompression algorithms tested: NONE, SNAPPY, ZSTD, LZ4")
    print("Each algorithm creates a separate ORC file with different compression")


fn demonstrate_stripe_operations() raises:
    """
    Demonstrate stripe-based ORC operations for parallel processing.
    """
    print("\n=== REAL ORC Stripe Operations ===")

    var pa = Python.import_module("pyarrow")
    var orc = Python.import_module("pyarrow.orc")

    print("REAL CODE: Creating ORC file with multiple stripes")
    # Create a larger table that will have multiple stripes
    var data_dict = Python.dict()
    data_dict['id'] = Python.list()
    data_dict['data'] = Python.list()

    for i in range(1, 50001):  # 50,000 rows to ensure multiple stripes
        data_dict['id'].append(i)
        data_dict['data'].append("Data value " + String(i))

    var pd = Python.import_module("pandas")
    var df = pd.DataFrame(data_dict)
    var table = pa.Table.from_pandas(df)

    # Write with specific stripe size
    print("orc.write_table(table, 'striped_data.orc', stripe_size=1024*64)")  # 64KB stripes
    orc.write_table(table, "striped_data.orc", stripe_size=1024*64)

    # Read using ORCFile for stripe access
    print("\nREAL CODE: Reading stripe information")
    print("var orc_file = orc.ORCFile('striped_data.orc')")
    var orc_file = orc.ORCFile("striped_data.orc")

    print("ORC file stripe information:")
    print("  - Number of stripes:", String(orc_file.nstripes))
    print("  - File metadata available:", String(orc_file.metadata is not None))

    # Read individual stripes (concept demonstration)
    print("\nStripe-based reading concepts:")
    print("  - orc_file.read_stripe(stripe_index) - read individual stripes")
    print("  - Parallel processing across stripes")
    print("  - Memory-efficient large file handling")


fn demonstrate_metadata_operations() raises:
    """
    Demonstrate ORC metadata access and file introspection.
    """
    print("\n=== REAL ORC Metadata Operations ===")

    var pa = Python.import_module("pyarrow")
    var orc = Python.import_module("pyarrow.orc")

    # Create sample file with metadata
    var data_dict = Python.dict()
    data_dict['id'] = Python.list()
    data_dict['name'] = Python.list()
    data_dict['score'] = Python.list()

    for i in range(1, 1001):  # 1000 rows
        data_dict['id'].append(i)
        data_dict['name'].append("Item_" + String(i))
        data_dict['score'].append(i % 100)

    var pd = Python.import_module("pandas")
    var df = pd.DataFrame(data_dict)
    var table = pa.Table.from_pandas(df)

    orc.write_table(table, "metadata_test.orc")

    # Read metadata
    print("REAL CODE: Reading ORC file metadata")
    print("var orc_file = orc.ORCFile('metadata_test.orc')")
    var orc_file = orc.ORCFile("metadata_test.orc")

    print("ORC File Metadata:")
    print("  - Schema:", String(orc_file.schema))
    print("  - Number of rows:", String(orc_file.nrows))
    print("  - Number of stripes:", String(orc_file.nstripes))
    print("  - Compression:", String(orc_file.compression))

    # Read the table and show column information
    var read_table = orc.read_table("metadata_test.orc")
    print("\nTable column information:")
    for i in range(read_table.num_columns):
        var col = read_table.column(i)
        print("  - Column", String(i) + ":", String(col._name), "(" + String(col.type) + ")")


fn demonstrate_column_projection() raises:
    """
    Demonstrate column projection for optimized ORC reading.
    """
    print("\n=== REAL ORC Column Projection ===")

    var pa = Python.import_module("pyarrow")
    var orc = Python.import_module("pyarrow.orc")
    var pd = Python.import_module("pandas")

    # Create wide table with many columns
    var data_dict = Python.dict()
    var columns = ["id", "name", "email", "phone", "address", "city", "state", "zip", "score", "active"]

    for col in columns:
        data_dict[col] = Python.list()

    for i in range(1, 1001):  # 1000 rows
        data_dict['id'].append(i)
        data_dict['name'].append("Name_" + String(i))
        data_dict['email'].append("email" + String(i) + "@example.com")
        var phone_num = i % 100
        var phone_str = String(phone_num)
        if phone_num < 10:
            phone_str = "0" + phone_str
        data_dict['phone'].append("555-010" + phone_str)
        data_dict['address'].append("Address " + String(i))
        data_dict['city'].append("City_" + String(i % 10))
        data_dict['state'].append("State_" + String(i % 5))
        data_dict['zip'].append(String(10000 + i))
        data_dict['score'].append(i % 100)
        data_dict['active'].append((i % 2) == 0)

    var df = pd.DataFrame(data_dict)
    var table = pa.Table.from_pandas(df)

    # Write the full table
    orc.write_table(table, "wide_table.orc")

    # Read with column projection
    print("REAL CODE: Reading with column projection")
    print("var columns_to_read = ['id', 'name', 'score']")
    var columns_to_read = Python.list()
    columns_to_read.append("id")
    columns_to_read.append("name")
    columns_to_read.append("score")

    print("var projected_table = orc.read_table('wide_table.orc', columns=columns_to_read)")
    var projected_table = orc.read_table("wide_table.orc", columns=columns_to_read)

    print("Column projection results:")
    print("  - Original table columns:", String(table.num_columns))
    print("  - Projected table columns:", String(projected_table.num_columns))
    print("  - Projected column names:", String(projected_table.column_names))
    print("  - Rows preserved:", String(projected_table.num_rows))

    # Demonstrate filtering with projection
    print("\nREAL CODE: Combined projection and filtering")
    var pc = Python.import_module("pyarrow.compute")
    var score_col = projected_table.column("score")
    var mask = pc.greater(score_col, 90)
    var filtered_table = projected_table.filter(mask)

    print("Filtered results (score > 90):")
    print("  - Rows after filtering:", String(filtered_table.num_rows))
    print("  - Columns maintained:", String(filtered_table.num_columns))