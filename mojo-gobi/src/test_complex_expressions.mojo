#!/usr/bin/env mojo

from blob_storage import BlobStorage
from schema_manager import SchemaManager, DatabaseSchema, TableSchema
from index_storage import IndexStorage
from orc_storage import ORCStorage
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from ast_evaluator import ASTEvaluator
from pl_grizzly_environment import Environment
from pl_grizzly_values import PLValue

fn test_complex_expressions() raises:
    print("Testing Complex Expressions & Function Calls")
    print("=" * 50)

    # Initialize components
    var storage = BlobStorage("test_db")
    var schema_manager = SchemaManager(storage)
    var index_storage = IndexStorage(storage)
    var orc_storage = ORCStorage(storage.copy(), schema_manager.copy(), index_storage.copy())
    var env = Environment()
    var evaluator = ASTEvaluator()

    # Test cases
    var test_cases = List[String]()
    test_cases.append("len([1, 2, 3])")  # Should return 3
    test_cases.append("abs(-5)")  # Should return 5
    test_cases.append("sqrt(9)")  # Should return 3
    test_cases.append("1 + 2 * 3")  # Should return 7 (precedence)
    test_cases.append("(1 + 2) * 3")  # Should return 9
    test_cases.append("not true")  # Should return false
    test_cases.append("!false")  # Should return true
    test_cases.append("-5 + 10")  # Should return 5
    test_cases.append("5 % 3")  # Should return 2
    test_cases.append("true and false")  # Should return false
    test_cases.append("true or false")  # Should return true

    for test_case in test_cases:
        print("Testing: " + test_case)

        # Tokenize
        var lexer = PLGrizzlyLexer(test_case)
        var tokens = lexer.tokenize()

        # Parse
        var parser = PLGrizzlyParser(tokens)
        var ast = parser.parse()

        # Evaluate
        var result = evaluator.evaluate(ast, env, orc_storage, schema_manager)
        print("Result: " + result.value + " (type: " + result.type + ")")
        print("")

fn main() raises:
    test_complex_expressions()