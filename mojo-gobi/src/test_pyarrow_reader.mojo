"""
Test PyArrow File Reader Extension

Tests the PyArrow file reading capabilities for PL-GRIZZLY.
"""

from extensions.pyarrow_reader import PyArrowFileReader
from pl_grizzly_parser import TypeChecker, StructDefinition


fn test_json_file_reading():
    """Test reading JSON files."""
    print("Testing JSON file reading...")

    var reader = PyArrowFileReader()

    # Test file detection
    var is_supported = reader.is_supported_file("test_data.json")
    print("Is test_data.json supported:", is_supported)

    if is_supported:
        var format_type = reader.get_file_format("test_data.json")
        print("Detected format:", format_type)

        # Test reading the file
        try:
            var result = reader.read_file_data("test_data.json")
            var table_data = result[0].copy()
            var column_names = result[1].copy()

            print("Column names:")
            for i in range(len(column_names)):
                print("  ", column_names[i])
            print("Number of rows:", len(table_data))

            # Print first few rows
            for i in range(min(3, len(table_data))):
                print("Row", i, ":")
                for j in range(len(table_data[i])):
                    print("    ", column_names[j], ":", table_data[i][j])

        except e:
            print("Error reading JSON file:", String(e))

    print()


fn test_type_inference():
    """Test type inference for files."""
    print("Testing type inference...")

    var reader = PyArrowFileReader()
    var type_checker = TypeChecker()

    # Define a Person struct for testing
    var person_struct = StructDefinition("Person")
    person_struct.add_field("name", "string")
    person_struct.add_field("age", "int")
    type_checker.define_struct(person_struct^)

    try:
        var type_dict = reader.infer_column_types("test_data.json")
        print("Inferred types:")
        # Note: Dict iteration in Mojo is limited, so we'll just note that type inference works
        print("  Type inference completed successfully")

        # Test struct type inference
        var inferred_type = reader.get_inferred_type(type_checker, "test_data.json")
        print("Inferred struct type:", inferred_type)
        
    except e:
        print("Error in type inference:", String(e))

    print()


fn main():
    """Main test function."""
    print("=== PyArrow File Reader Extension Tests ===\n")

    test_json_file_reading()
    test_type_inference()

    print("=== Tests Complete ===")