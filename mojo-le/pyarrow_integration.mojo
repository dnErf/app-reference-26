from python import Python
from python import PythonObject

fn demonstrate_basic_pyarrow():
    """Demonstrate basic PyArrow operations."""
    print("=== PyArrow Integration with Mojo ===")

    try:
        var py = Python.import_module("pyarrow")
        print("PyArrow successfully imported")

        # Create a simple array
        var arr = py.array([1, 2, 3, 4, 5])
        print("Created PyArrow array with 5 elements")
        print("Array type:", arr.type)
        print("Array length:", arr.length())

        # Create a simple table
        var data = Python.evaluate("{'name': ['Alice', 'Bob', 'Charlie'], 'age': [25, 30, 35]}")
        var table = py.Table.from_pydict(data)
        print("Created table with", table.num_rows, "rows and", table.num_columns, "columns")

        # Show column names
        var columns = table.column_names
        print("Column names:", columns)

    except:
        print("PyArrow operations failed - please ensure PyArrow is installed")

fn demonstrate_data_import():
    """Demonstrate data import operations."""
    print("\n=== Data Import Operations ===")

    try:
        var py = Python.import_module("pyarrow")

        # Create sample data using Python evaluation
        var csv_data = Python.evaluate("""
import io
csv_content = '''name,age,city
Alice,25,NYC
Bob,30,LA
Charlie,35,Chicago'''
import pandas as pd
df = pd.read_csv(io.StringIO(csv_content))
df
""")

        var table = py.Table.from_pandas(csv_data)
        print("Imported CSV data into PyArrow table")
        print("Table shape:", table.shape)
        print("Columns:", table.column_names)

        # Basic operations
        var age_col = table.column("age")
        print("Age column type:", age_col.type)

    except:
        print("Data import operations failed")

fn demonstrate_columnar_benefits():
    """Demonstrate columnar processing benefits."""
    print("\n=== Columnar Processing Benefits ===")

    try:
        var py = Python.import_module("pyarrow")

        # Create larger dataset
        var large_data = Python.evaluate("""
import pyarrow as pa
import numpy as np

# Create 10,000 rows of data
n = 10000
data = {
    'id': np.arange(n),
    'value': np.random.randn(n),
    'category': np.random.randint(0, 5, n)
}
pa.Table.from_pydict(data)
""")

        print("Created large table with", large_data.num_rows, "rows")

        # Demonstrate filtering (conceptual)
        print("Columnar processing allows:")
        print("- Efficient column-wise operations")
        print("- Vectorized computations")
        print("- Reduced memory access patterns")
        print("- Better compression ratios")
        print("- Parallel processing capabilities")

    except:
        print("Columnar processing demonstration failed")

fn main():
    """Main demonstration function."""
    print("=== PyArrow Integration with Mojo ===")
    print("Demonstrating high-performance columnar data processing")
    print()

    # Demonstrate basic PyArrow operations
    demonstrate_basic_pyarrow()

    # Demonstrate data import
    demonstrate_data_import()

    # Demonstrate columnar benefits
    demonstrate_columnar_benefits()

    print("\n=== PyArrow Integration Complete ===")
    print("Key takeaways:")
    print("- PyArrow enables efficient columnar data processing in Mojo")
    print("- Zero-copy integration through Python interop")
    print("- High-performance analytics on large datasets")
    print("- Interoperability with existing Python data ecosystem")
    print("- Memory-efficient processing with compression support")