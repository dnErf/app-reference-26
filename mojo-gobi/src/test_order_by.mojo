"""
Simple test for ORDER BY clause functionality in PL-GRIZZLY
"""

from pl_grizzly_interpreter import PLGrizzlyInterpreter, Environment
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from orc_storage import ORCStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage
from blob_storage import BlobStorage
from collections import Dict


fn test_order_by_clause() raises:
    """Test ORDER BY clause functionality."""
    print("Testing ORDER BY clause functionality...")

    # Initialize storage components
    var storage = BlobStorage("test_db")
    var schema_manager = SchemaManager(storage)
    var index_storage = IndexStorage(storage)
    var bloom_cols = List[String]()
    var orc_storage = ORCStorage(storage^, schema_manager^, index_storage^, "none", True, 10000, 65536, bloom_cols^)

    # Initialize interpreter
    var interpreter = PLGrizzlyInterpreter(orc_storage^)

    # Create a simple table
    var create_result = interpreter.evaluate("CREATE TABLE test_table (id INTEGER, name STRING, age INTEGER)", Environment())
    print("CREATE TABLE result:", create_result.__str__())

    # Insert some test data
    var insert1 = interpreter.evaluate("INSERT INTO test_table VALUES (1, 'Alice', 25)", Environment())
    var insert2 = interpreter.evaluate("INSERT INTO test_table VALUES (2, 'Bob', 30)", Environment())
    var insert3 = interpreter.evaluate("INSERT INTO test_table VALUES (3, 'Charlie', 20)", Environment())
    print("Insert results completed")

    # Test ORDER BY clause with different directions
    print("\n--- Testing ORDER BY clauses ---")

    # ORDER BY ASC (default)
    var order_asc = interpreter.evaluate("SELECT name FROM test_table ORDER BY age", Environment())
    print("SELECT name FROM test_table ORDER BY age:", order_asc.__str__())

    # ORDER BY DESC
    var order_desc = interpreter.evaluate("SELECT name FROM test_table ORDER BY age DESC", Environment())
    print("SELECT name FROM test_table ORDER BY age DESC:", order_desc.__str__())

    # Test new syntax: ORDER BY ASC column
    var order_asc_new = interpreter.evaluate("SELECT name FROM test_table ORDER BY ASC age", Environment())
    print("SELECT name FROM test_table ORDER BY ASC age:", order_asc_new.__str__())

    # Test new syntax: ORDER BY DESC column
    var order_desc_new = interpreter.evaluate("SELECT name FROM test_table ORDER BY DESC age", Environment())
    print("SELECT name FROM test_table ORDER BY DESC age:", order_desc_new.__str__())

    # ORDER BY multiple columns
    var order_multi = interpreter.evaluate("SELECT name FROM test_table ORDER BY age DESC, name ASC", Environment())
    print("SELECT name FROM test_table ORDER BY age DESC, name ASC:", order_multi.__str__())

    print("ORDER BY clause testing completed!")


fn main() raises:
    test_order_by_clause()