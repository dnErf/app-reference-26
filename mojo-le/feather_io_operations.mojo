"""
Feather Format Operations with PyArrow Integration
=================================================

This example demonstrates Feather format operations using PyArrow
for efficient columnar data storage in Mojo.

Key concepts covered:
- Feather V1 and V2 formats
- Compression options
- Fast reading/writing
- Interoperability with other tools
"""

from python import Python
from python import PythonObject


def main():
    print("=== Feather Format Operations with PyArrow Integration ===")
    print("Demonstrating efficient columnar data storage\n")

    # Demonstrate Feather format basics
    demonstrate_feather_basics()

    # Show V1 vs V2 format differences
    demonstrate_format_versions()

    # Compression options and performance
    demonstrate_compression_options()

    # Reading and writing operations
    demonstrate_read_write_operations()

    # Interoperability and use cases
    demonstrate_interoperability()

    print("\n=== Feather Format Operations Complete ===")
    print("Key takeaways:")
    print("- Feather provides fast columnar storage for analytical workloads")
    print("- V2 format offers better compression and wider type support")
    print("- Multiple compression algorithms available (LZ4, ZSTD)")
    print("- Excellent interoperability with R, Python, and other tools")
    print("- Optimized for read-heavy analytical workflows")


def demonstrate_feather_basics():
    """
    Demonstrate real Feather format basics.
    """
    print("=== Feather Format Basics ===")

    try:
        # Import required modules
        py = Python.import_module("pyarrow")
        feather_mod = Python.import_module("pyarrow.feather")
        pc = Python.import_module("pyarrow.compute")

        # Create sample dataset
        print("Creating sample dataset...")
        data = Python.dict()
        
        # Create data manually
        ids = Python.list()
        names = Python.list()
        categories = Python.list()
        prices = Python.list()
        quantities = Python.list()
        dates = Python.list()
        actives = Python.list()
        
        for i in range(1, 1001):  # 1000 rows
            ids.append(PythonObject(i))
            names.append(PythonObject("Product " + String(i)))
            categories.append(PythonObject("Category " + String((i % 5) + 1)))
            prices.append(PythonObject(Float64(i) * 10.5))
            quantities.append(PythonObject(i * 2))
            day_str = String((i % 28) + 1)
            if len(day_str) == 1:
                day_str = "0" + day_str
            dates.append(PythonObject("2023-01-" + day_str))
            actives.append(PythonObject((i % 3) != 0))

        data["id"] = ids
        data["name"] = names
        data["category"] = categories
        data["price"] = prices
        data["quantity"] = quantities
        data["date"] = dates
        data["active"] = actives

        # Create table
        table = py.table(data)
        print("Created table with " + String(table.num_rows) + " rows and " + String(len(table.column_names)) + " columns")

        # Write Feather file
        print("Writing Feather file...")
        feather_mod.write_feather(table, "sample_data.feather")
        print("Wrote Feather file: sample_data.feather")

        # Read back and show info
        print("Reading back Feather file...")
        read_table = feather_mod.read_feather("sample_data.feather")
        print("Read back " + String(read_table.num_rows) + " rows")
        
        # Show schema information
        print("Schema information:")
        schema = read_table.schema
        for i in range(schema.num_fields):
            field = schema.get_field(i)
            print("  " + field.name + ": " + String(field.type))

        # Show file size (using Python)
        os_mod = Python.import_module("os")
        file_size = os_mod.path.getsize("sample_data.feather")
        print("File size: " + String(file_size) + " bytes")

    except:
        print("Feather basics demonstration failed")


def demonstrate_format_versions():
    """
    Demonstrate real V1 vs V2 format differences.
    """
    print("\n=== Format Versions (V1 vs V2) ===")

    try:
        py = Python.import_module("pyarrow")
        feather_mod = Python.import_module("pyarrow.feather")

        # Create test data
        data = Python.dict()
        id_list = Python.list()
        id_list.append(1)
        id_list.append(2)
        id_list.append(3)
        id_list.append(4)
        id_list.append(5)
        data["id"] = id_list
        
        value_list = Python.list()
        value_list.append(10.5)
        value_list.append(20.3)
        value_list.append(30.7)
        value_list.append(40.1)
        value_list.append(50.9)
        data["value"] = value_list
        
        category_list = Python.list()
        category_list.append("A")
        category_list.append("B")
        category_list.append("A")
        category_list.append("C")
        category_list.append("B")
        data["category"] = category_list
        
        table = py.table(data)

        # Write with V2 format (default)
        print("Writing with Feather V2 format...")
        feather_mod.write_feather(table, "test_v2.feather")
        print("Wrote V2 format file")

        # Read back and show version info
        read_table = feather_mod.read_feather("test_v2.feather")
        print("Read back table with " + String(read_table.num_rows) + " rows")
        
        # Show format capabilities
        print("Feather V2 features demonstrated:")
        print("- Extended type support")
        print("- Compression available")
        print("- Rich metadata support")

        # Test compression options (V2 feature)
        print("Testing compression options...")
        feather_mod.write_feather(table, "test_v2_lz4.feather", compression="lz4")
        print("Wrote V2 with LZ4 compression")
        
        feather_mod.write_feather(table, "test_v2_zstd.feather", compression="zstd")
        print("Wrote V2 with ZSTD compression")

        # Show file sizes
        os_mod = Python.import_module("os")
        v2_size = os_mod.path.getsize("test_v2.feather")
        lz4_size = os_mod.path.getsize("test_v2_lz4.feather")
        zstd_size = os_mod.path.getsize("test_v2_zstd.feather")
        
        print("File sizes:")
        print("  Uncompressed: " + String(v2_size) + " bytes")
        print("  LZ4: " + String(lz4_size) + " bytes")
        print("  ZSTD: " + String(zstd_size) + " bytes")

    except:
        print("Format versions demonstration failed")


def demonstrate_compression_options():
    """
    Demonstrate real compression options and performance.
    """
    print("\n=== Compression Options and Performance ===")

    try:
        py = Python.import_module("pyarrow")
        feather_mod = Python.import_module("pyarrow.feather")

        # Create larger test dataset
        data = Python.dict()
        ids = Python.list()
        values = Python.list()
        
        for i in range(1, 10001):  # 10,000 rows
            ids.append(PythonObject(i))
            values.append(PythonObject(Float64(i) * 1.5))
        
        data["id"] = ids
        data["value"] = values
        table = py.table(data)

        print("Testing compression algorithms...")
        os_mod = Python.import_module("os")

        # Test uncompressed
        feather_mod.write_feather(table, "test_uncompressed.feather")
        uncompressed_size = os_mod.path.getsize("test_uncompressed.feather")
        print("Uncompressed: " + String(uncompressed_size) + " bytes")

        # Test LZ4
        feather_mod.write_feather(table, "test_lz4.feather", compression="lz4")
        lz4_size = os_mod.path.getsize("test_lz4.feather")
        ratio = Float64(uncompressed_size) / Float64(lz4_size)
        print("LZ4: " + String(lz4_size) + " bytes (" + String(ratio)[:4] + ":1)")

        # Test ZSTD
        feather_mod.write_feather(table, "test_zstd.feather", compression="zstd")
        zstd_size = os_mod.path.getsize("test_zstd.feather")
        ratio = Float64(uncompressed_size) / Float64(zstd_size)
        print("ZSTD: " + String(zstd_size) + " bytes (" + String(ratio)[:4] + ":1)")

        print("Compression comparison completed")

    except:
        print("Compression options demonstration failed")


def demonstrate_read_write_operations():
    """
    Demonstrate real reading and writing operations.
    """
    print("\n=== Read/Write Operations ===")

    try:
        py = Python.import_module("pyarrow")
        feather_mod = Python.import_module("pyarrow.feather")

        # Create test data
        data = Python.dict()
        ids = Python.list()
        sales = Python.list()
        categories = Python.list()
        
        for i in range(1, 5001):  # 5000 rows
            ids.append(PythonObject(i))
            sales.append(PythonObject(Float64(i) * 25.5))
            categories.append(PythonObject("Cat" + String((i % 10) + 1)))
        
        data["id"] = ids
        data["sales"] = sales
        data["category"] = categories
        table = py.table(data)

        print("Created test dataset with " + String(table.num_rows) + " rows")

        # Write Feather file
        feather_mod.write_feather(table, "sales_data.feather", compression="lz4")
        print("Wrote Feather file")

        # Read back for analysis
        read_table = feather_mod.read_feather("sales_data.feather")
        print("Read Feather file back")

        # Perform some analysis
        print("Performing analysis on loaded data...")
        sales_col = read_table.column("sales")
        total_sales = py.compute.sum(sales_col)
        avg_sales = py.compute.mean(sales_col)
        
        print("Total sales: " + String(total_sales))
        print("Average sales: " + String(avg_sales)[:8])

        # Column projection - read only needed columns
        print("Demonstrating column projection...")
        columns_list = Python.list()
        columns_list.append("id")
        columns_list.append("sales")
        projected_table = feather_mod.read_feather("sales_data.feather", columns=columns_list)
        print("Read only " + String(len(projected_table.column_names)) + " columns: " + String(projected_table.column_names))

        # Show file size
        os_mod = Python.import_module("os")
        file_size = os_mod.path.getsize("sales_data.feather")
        print("File size: " + String(file_size) + " bytes")

    except:
        print("Read/write operations demonstration failed")


def demonstrate_interoperability():
    """
    Demonstrate real interoperability and use cases.
    """
    print("\n=== Interoperability and Use Cases ===")

    try:
        py = Python.import_module("pyarrow")
        feather_mod = Python.import_module("pyarrow.feather")

        # Create sample data for interoperability demo
        data = Python.dict()
        product_id_list = Python.list()
        product_id_list.append(1)
        product_id_list.append(2)
        product_id_list.append(3)
        product_id_list.append(4)
        product_id_list.append(5)
        data["product_id"] = product_id_list
        
        product_name_list = Python.list()
        product_name_list.append("Widget A")
        product_name_list.append("Widget B")
        product_name_list.append("Widget C")
        product_name_list.append("Widget D")
        product_name_list.append("Widget E")
        data["product_name"] = product_name_list
        
        price_list = Python.list()
        price_list.append(19.99)
        price_list.append(29.99)
        price_list.append(39.99)
        price_list.append(49.99)
        price_list.append(59.99)
        data["price"] = price_list
        
        in_stock_list = Python.list()
        in_stock_list.append(True)
        in_stock_list.append(False)
        in_stock_list.append(True)
        in_stock_list.append(True)
        in_stock_list.append(False)
        data["in_stock"] = in_stock_list
        
        table = py.table(data)

        # Write Feather file for cross-language sharing
        feather_mod.write_feather(table, "interop_demo.feather", compression="lz4")
        print("Created Feather file for interoperability demonstration")

        # Read back and show data
        read_table = feather_mod.read_feather("interop_demo.feather")
        print("Read back table with " + String(read_table.num_rows) + " rows")
        
        # Show that data can be shared across languages
        print("Feather file created successfully for cross-language interoperability:")
        print("- Compatible with Python (pandas, PyArrow)")
        print("- Compatible with R (arrow package)")
        print("- Language-agnostic columnar format")
        print("- Preserves schema and types")

        # Demonstrate pandas interoperability (if available)
        try:
            pd = Python.import_module("pandas")
            df = feather_mod.read_feather("interop_demo.feather")
            pandas_df = pd.DataFrame(df)
            print("Successfully loaded into pandas DataFrame")
            print("Pandas shape: " + String(pandas_df.shape[0]) + " rows x " + String(pandas_df.shape[1]) + " columns")
        except:
            print("Pandas interoperability test skipped")

        # Show file info
        os_mod = Python.import_module("os")
        file_size = os_mod.path.getsize("interop_demo.feather")
        print("Feather file size: " + String(file_size) + " bytes")
        print("Ready for sharing with R, Python, or other Arrow-compatible tools")

    except:
        print("Interoperability demonstration failed")