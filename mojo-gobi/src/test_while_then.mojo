"""
Test WHILE loops and FROM...THEN functionality
"""

from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from ast_evaluator import ASTEvaluator
from pl_grizzly_environment import Environment
from pl_grizzly_values import PLValue

fn test_while_loop() raises:
    """Test WHILE loop parsing and evaluation."""
    var lexer = PLGrizzlyLexer("WHILE true { LET x = 1 }")
    var tokens = lexer.tokenize()
    
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    
    print("WHILE AST parsed successfully")
    print("AST type:", ast.node_type)
    print("Children count:", len(ast.children))

fn test_then_clause() raises:
    """Test THEN clause parsing."""
    var lexer = PLGrizzlyLexer("SELECT * FROM test THEN { LET x = 1 }")
    var tokens = lexer.tokenize()
    
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    
    print("THEN clause parsed successfully")
    print("AST type:", ast.node_type)

fn test_array_iteration() raises:
    """Test array iteration with FROM...THEN."""
    var lexer = PLGrizzlyLexer("SELECT array_index, array_value FROM SomeArray THEN { LET result = array_index + \": \" + array_value }")
    var tokens = lexer.tokenize()
    
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    
    print("Array iteration parsed successfully")
    print("AST type:", ast.node_type)

fn test_from_select_syntax() raises:
    """Test FROM...SELECT syntax (interchangeable keywords)."""
    var lexer = PLGrizzlyLexer("FROM test SELECT *")
    var tokens = lexer.tokenize()
    
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    
    print("FROM...SELECT syntax parsed successfully")
    print("AST type:", ast.node_type)

fn test_from_select_with_then() raises:
    """Test FROM...SELECT with THEN clause."""
    var lexer = PLGrizzlyLexer("FROM users SELECT name, age THEN { LET full_name = name + \" (\" + age + \")\" }")
    var tokens = lexer.tokenize()
    
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    
    print("FROM...SELECT with THEN parsed successfully")
    print("AST type:", ast.node_type)

fn main() raises:
    print("Testing WHILE and THEN functionality...")
    
    test_while_loop()
    test_then_clause()
    test_array_iteration()
    test_from_select_syntax()
    test_from_select_with_then()
    
    print("Tests completed")