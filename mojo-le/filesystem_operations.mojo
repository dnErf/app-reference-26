"""
Filesystem Operations with PyArrow Integration
=============================================

This example demonstrates filesystem operations using PyArrow for
efficient data access in Mojo.

Key concepts covered:
- Local filesystem operations
- File listing and metadata
- Input/output streams
"""

from python import Python
from python import PythonObject


def main():
    print("=== Filesystem Operations with PyArrow Integration ===")
    print("Demonstrating efficient data access in Mojo\n")

    # Demonstrate local filesystem operations
    demonstrate_local_filesystem()

    # File listing and metadata operations
    demonstrate_file_listing()

    # Input/output stream operations
    demonstrate_io_streams()

    print("\n=== Filesystem Operations Complete ===")
    print("Key takeaways:")
    print("- PyArrow provides unified filesystem interface")
    print("- Local filesystem operations are efficient and platform-independent")
    print("- File metadata and listing enable efficient data discovery")
    print("- I/O streams support both reading and writing operations")


def demonstrate_local_filesystem():
    """
    Demonstrate local filesystem operations.
    """
    print("=== Local Filesystem Operations ===")

    try:
        # Import PyArrow filesystem module
        pyarrow = Python.import_module("pyarrow")
        fs_mod = Python.import_module("pyarrow.fs")
        LocalFileSystem = fs_mod.LocalFileSystem

        # Create local filesystem instance
        fs = LocalFileSystem()

        print("Created LocalFileSystem instance")

        # Test file operations
        test_file = "test_data.txt"

        # Create a test file
        with open(test_file, "w") as f:
            f.write("id,name,value\n1,Alice,100\n2,Bob,200\n3,Charlie,300\n")

        # Check if file exists
        file_info = fs.get_file_info(test_file)
        print("File exists:", test_file, "->", file_info.type.name == "File")

        # Get file size
        print("File size:", test_file, "->", file_info.size, "bytes")

        # Get file type
        print("File type:", file_info.type.name)

        # Test directory operations
        test_dir = "test_dir"
        import os
        os.makedirs(test_dir, exist_ok=True)

        # List directory
        dir_info = fs.get_file_info(test_dir)
        print("Directory exists:", test_dir, "->", dir_info.type.name == "Directory")

        # Create files in directory
        with open(test_dir + "/file1.txt", "w") as f:
            f.write("File 1 content")
        with open(test_dir + "/file2.txt", "w") as f:
            f.write("File 2 content")

        # List directory contents
        file_selector = fs_mod.FileSelector(test_dir, recursive=False)
        file_infos = fs.get_file_info(file_selector)
        print("Directory contents:")
        for info in file_infos:
            var path_part = String(info.path.split('/')[-1])
            var type_part = String(info.type.name)
            var size_part = String(info.size)
            print("  - " + path_part + " (" + type_part + ", " + size_part + " bytes)")

        # Clean up
        var shutil = Python.import_module("shutil")
        shutil.rmtree(test_dir)
        os.remove(test_file)

        print("Local filesystem operations completed successfully")

    except e:
        print("Local filesystem demonstration failed:", String(e))


def demonstrate_file_listing():
    """
    Demonstrate file listing and metadata operations.
    """
    print("\n=== File Listing and Metadata ===")

    try:
        # Import PyArrow filesystem module
        pyarrow = Python.import_module("pyarrow")
        fs_mod = Python.import_module("pyarrow.fs")
        LocalFileSystem = fs_mod.LocalFileSystem

        # Create local filesystem instance
        fs = LocalFileSystem()

        # Create test directory structure
        import os

        test_dir = "test_warehouse"
        os.makedirs(test_dir, exist_ok=True)
        os.makedirs(test_dir + "/products", exist_ok=True)
        os.makedirs(test_dir + "/products/books", exist_ok=True)

        # Create test files
        with open(test_dir + "/sales_2023.parquet", "w") as f:
            f.write("dummy parquet content")
        with open(test_dir + "/customers.csv", "w") as f:
            f.write("id,name,email\n1,Alice,a@example.com\n")
        with open(test_dir + "/products/electronics.parquet", "w") as f:
            f.write("electronics data")
        with open(test_dir + "/products/clothing.parquet", "w") as f:
            f.write("clothing data")
        with open(test_dir + "/products/books/fiction.parquet", "w") as f:
            f.write("fiction books")
        with open(test_dir + "/products/books/nonfiction.parquet", "w") as f:
            f.write("nonfiction books")

        # Get single file info
        file_info = fs.get_file_info(test_dir + "/sales_2023.parquet")
        print("Single File Info:")
        print("  Path:", file_info.path)
        print("  Type:", file_info.type.name)
        print("  Size:", file_info.size, "bytes")

        # List directory (non-recursive)
        file_selector = fs_mod.FileSelector(test_dir, recursive=False)
        file_infos = fs.get_file_info(file_selector)
        print("\nDirectory Listing (non-recursive):")
        print("  Path:", test_dir + "/")
        for info in file_infos:
            var path_parts = String(info.path).split('/')
            var filename = path_parts[len(path_parts) - 1]
            print("    " + filename + " (" + String(info.type.name) + ", " + String(info.size) + " bytes)")

        # Recursive listing
        file_selector_recursive = fs_mod.FileSelector(test_dir + "/products", recursive=True)
        file_infos_recursive = fs.get_file_info(file_selector_recursive)
        print("\nRecursive Listing:")
        print("  Path:", test_dir + "/products/")
        for info in file_infos_recursive:
            var full_path = String(info.path)
            var prefix = test_dir + "/products/"
            var rel_path = full_path.replace(prefix, "")
            print("    " + rel_path + " (" + String(info.type.name) + ", " + String(info.size) + " bytes)")

        # Calculate total size for parquet files
        total_size = 0
        parquet_count = 0
        for info in file_infos_recursive:
            if info.path.endswith(".parquet"):
                total_size += atol(String(info.size))
                parquet_count += 1

        print("\nFiltered Listing (parquet files):")
        print("  Results: " + String(parquet_count) + " parquet files found")
        print("  Total size: " + String(total_size) + " bytes")

        # Clean up
        var shutil = Python.import_module("shutil")
        shutil.rmtree(test_dir)

        print("File listing operations completed successfully")

    except e:
        print("File listing demonstration failed:", String(e))


def demonstrate_io_streams():
    """
    Demonstrate input/output stream operations.
    """
    print("\n=== I/O Stream Operations ===")

    try:
        # Import PyArrow filesystem module
        pyarrow = Python.import_module("pyarrow")
        fs_mod = Python.import_module("pyarrow.fs")
        LocalFileSystem = fs_mod.LocalFileSystem

        # Create local filesystem instance
        fs = LocalFileSystem()

        # Create test data
        test_input = "input_data.csv"
        test_output = "processed_data.txt"

        # Create input file with sample data
        with open(test_input, "w") as f:
            f.write("id,name,email,score\n")
            var i = 0
            while i < 100:
                f.write(String(i+1) + ",User" + String(i) + ",user" + String(i) + "@example.com," + String((i%100)+1) + "\n")
                i += 1
        # Open input stream and read data
        input_stream = fs.open_input_stream(test_input)
        data = input_stream.readall()
        input_stream.close()

        print("Read", len(data), "bytes from input stream")

        # Process data (simple example: count lines)
        lines = data.decode('utf-8').split('\n')
        header = lines[0]
        data_lines = [line for line in lines[1:] if line.strip()]

        print("Header:", header)
        print("Data records:", len(data_lines))

        # Simple aggregation: count scores > 50
        var high_scores = 0
        for line in data_lines:
            if line:
                var parts = line.split(',')
                if len(parts) > 3:
                    var score = atol(String(parts[3]))
                    if score > 50:
                        high_scores += 1

        # Open output stream and write processed data
        output_stream = fs.open_output_stream(test_output)

        # Write processed results
        var py_str1 = Python.evaluate('"Processed Results\\n"')
        var py_str2 = Python.evaluate('"Total records: ' + String(len(data_lines)) + '\\n"')
        var py_str3 = Python.evaluate('"High scores (>50): ' + String(high_scores) + '\\n"')
        
        output_stream.write(py_str1.encode('utf-8'))
        output_stream.write(py_str2.encode('utf-8'))
        output_stream.write(py_str3.encode('utf-8'))

        output_stream.close()

        print("Wrote processed data to:", test_output)

        # Verify output file
        output_info = fs.get_file_info(test_output)
        print("Output file size:", output_info.size, "bytes")

        # Read back output file to verify
        output_stream_read = fs.open_input_stream(test_output)
        output_data = output_stream_read.readall()
        output_stream_read.close()

        print("Output content preview:")
        print(output_data.decode('utf-8')[:200] + "...")

        # Clean up
        import os
        os.remove(test_input)
        os.remove(test_output)

        print("I/O stream operations completed successfully")

    except e:
        print("I/O streams demonstration failed:", String(e))

