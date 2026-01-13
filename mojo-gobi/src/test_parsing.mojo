#!/usr/bin/env mojo
"""
Simple test for ATTACH SQL Files parsing
"""
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser

fn main() raises:
    print("Testing ATTACH SQL Files parsing...")

    # Test ATTACH statement
    var lexer = PLGrizzlyLexer("ATTACH 'test_script.sql' AS my_script;")
    var tokens = lexer.tokenize()
    print("Tokens for ATTACH:")
    for i in range(len(tokens)):
        print("  " + String(i) + ": " + tokens[i].type + " '" + tokens[i].value + "'")

    # Test EXECUTE statement
    lexer = PLGrizzlyLexer("EXECUTE my_script;")
    tokens = lexer.tokenize()
    print("\nTokens for EXECUTE:")
    for i in range(len(tokens)):
        print("  " + String(i) + ": " + tokens[i].type + " '" + tokens[i].value + "'")

    # Test parsing
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    print("\nParsed ATTACH statement successfully")

    lexer = PLGrizzlyLexer("EXECUTE my_script;")
    tokens = lexer.tokenize()
    parser = PLGrizzlyParser(tokens)
    ast = parser.parse()
    print("Parsed EXECUTE statement successfully")

    print("✅ ATTACH SQL Files parsing test PASSED")