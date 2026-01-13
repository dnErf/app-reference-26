"""
Test PL-GRIZZLY file reading with PyArrow extension
"""

from pl_grizzly_interpreter import PLGrizzlyInterpreter
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from orc_storage import ORCStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage
from blob_storage import BlobStorage
from extensions.pyarrow_reader import PyArrowFileReader
from collections import Dict


fn test_file_reading() raises:
    """Test file reading functionality."""
    print("Testing PL-GRIZZLY file reading...")

    # Initialize storage components
    var storage = BlobStorage("test_db")
    var schema_manager = SchemaManager(storage)
    var index_storage = IndexStorage(storage)
    var bloom_cols = List[String]()
    var orc_storage = ORCStorage(storage^, schema_manager^, index_storage^, "none", True, 10000, 65536, bloom_cols^)

    # Initialize interpreter
    var interpreter = PLGrizzlyInterpreter(orc_storage^)
    
    # Test PyArrow reader directly
    var reader = PyArrowFileReader()
    var is_supported = reader.is_supported_file("test_data.json")
    print("Is test_data.json supported by PyArrow reader:", is_supported)
    
    # Test file in subdirectory
    var is_supported_subdir = reader.is_supported_file("models/test_data_copy.json")
    print("Is models/test_data_copy.json supported by PyArrow reader:", is_supported_subdir)
    
    # Test absolute path
    var abs_path = "/home/lnx/Dev/app-reference-26/mojo-gobi/test_data.json"
    var is_supported_abs = reader.is_supported_file(abs_path)
    print("Is absolute path supported by PyArrow reader:", is_supported_abs)

    # Test SQL execution - current directory
    var sql1 = "SELECT * FROM 'test_data.json'"
    print("\nExecuting SQL:", sql1)

    try:
        var result1 = interpreter.interpret(sql1)
        print("Result type:", result1.type)
        print("Result value:", result1.value)

        if result1.type == "string":
            print("Query executed successfully!")
            print("Result:")
            print(result1.value)

    except e:
        print("Error executing SQL:", String(e))
    
    # Test SQL execution - subdirectory
    var sql2 = "SELECT * FROM 'models/test_data_copy.json'"
    print("\nExecuting SQL:", sql2)

    try:
        var result2 = interpreter.interpret(sql2)
        print("Result type:", result2.type)
        print("Result value:", result2.value)

        if result2.type == "string":
            print("Query executed successfully!")
            print("Result:")
            print(result2.value)

    except e:
        print("Error executing SQL:", String(e))
    
    # Test SQL execution - absolute path
    var sql3 = "SELECT * FROM '/home/lnx/Dev/app-reference-26/mojo-gobi/test_data.json'"
    print("\nExecuting SQL:", sql3)

    try:
        var result3 = interpreter.interpret(sql3)
        print("Result type:", result3.type)
        print("Result value:", result3.value)

        if result3.type == "string":
            print("Query executed successfully!")
            print("Result:")
            print(result3.value)

    except e:
        print("Error executing SQL:", String(e))
    
    # Test @TypeOf on file data
    var sql_typeof = "SELECT @TypeOf(name) FROM 'test_data.json'"
    print("\nExecuting SQL:", sql_typeof)

    try:
        var result_typeof = interpreter.interpret(sql_typeof)
        print("Result type:", result_typeof.type)
        print("Result value:", result_typeof.value)

        if result_typeof.type == "string":
            print("Query executed successfully!")
            print("Result:")
            print(result_typeof.value)

    except e:
        print("Error executing SQL:", String(e))


fn main() raises:
    """Main test function."""
    print("=== PL-GRIZZLY File Reading Test ===\n")

    test_file_reading()

    print("\n=== Test Complete ===")