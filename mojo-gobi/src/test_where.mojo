"""
Simple test for WHERE clause functionality in PL-GRIZZLY
"""

from pl_grizzly_interpreter import PLGrizzlyInterpreter, Environment
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from orc_storage import ORCStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage
from blob_storage import BlobStorage
from collections import Dict


fn test_where_clause() raises:
    """Test WHERE clause functionality."""
    print("Testing WHERE clause functionality...")

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
    var insert3 = interpreter.evaluate("INSERT INTO test_table VALUES (3, 'Charlie', 35)", Environment())
    print("Insert results:", insert1.__str__(), insert2.__str__(), insert3.__str__())

    # Test WHERE clause with different conditions
    print("\n--- Testing WHERE clauses ---")

    # First test without WHERE
    var select_all = interpreter.evaluate("SELECT * FROM test_table", Environment())
    print("SELECT * FROM test_table:", select_all.__str__())
    
    # WHERE with equality
    var where_eq = interpreter.evaluate("SELECT * FROM test_table WHERE age = 30", Environment())
    print("SELECT * FROM test_table WHERE age = 30:", where_eq.__str__())

    # WHERE with greater than
    var where_gt = interpreter.evaluate("SELECT name FROM test_table WHERE age > 25", Environment())
    print("SELECT name FROM test_table WHERE age > 25:", where_gt.__str__())

    # WHERE with AND
    var where_and = interpreter.evaluate("SELECT * FROM test_table WHERE age > 20 AND age < 35", Environment())
    print("SELECT * FROM test_table WHERE age > 20 AND age < 35:", where_and.__str__())

    # WHERE with OR
    var where_or = interpreter.evaluate("SELECT name FROM test_table WHERE age = 25 OR age = 35", Environment())
    print("SELECT name FROM test_table WHERE age = 25 OR age = 35:", where_or.__str__())

    # WHERE with NOT
    var where_not = interpreter.evaluate("SELECT name FROM test_table WHERE NOT age = 30", Environment())
    print("SELECT name FROM test_table WHERE NOT age = 30:", where_not.__str__())

    print("WHERE clause testing completed!")


fn main() raises:
    test_where_clause()