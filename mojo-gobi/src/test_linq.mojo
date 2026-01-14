"""
Test LINQ-style query expressions in PL-GRIZZLY
"""

from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from ast_evaluator import ASTEvaluator
from pl_grizzly_environment import Environment
from orc_storage import ORCStorage
from blob_storage import BlobStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage

fn test_linq_queries() raises:
    """Test LINQ-style query functionality."""
    print("Testing LINQ-style queries...")

    # Test 1: Basic LINQ query (SQL-first syntax)
    var source1 = 'FROM [1, 2, 3, 4, 5] WHERE value > 3 SELECT value * 2'
    print("Test 1 - Basic LINQ:", source1)

    var lexer1 = PLGrizzlyLexer(source1)
    var tokens1 = lexer1.tokenize()
    var parser1 = PLGrizzlyParser(tokens1)
    var ast1 = parser1.parse()

    # For now, just test parsing
    print("LINQ parsing tests completed!")

    # Test 2: LINQ with table data (would need actual table)
    var source2 = 'FROM users WHERE age > 18 SELECT name'
    print("Test 2 - Table LINQ:", source2)

    var lexer2 = PLGrizzlyLexer(source2)
    var tokens2 = lexer2.tokenize()
    var parser2 = PLGrizzlyParser(tokens2)
    var ast2 = parser2.parse()

    print("AST Type:", ast2.node_type)
    print("Parsed successfully!")

    print("LINQ parsing tests completed!")

fn main() raises:
    test_linq_queries()