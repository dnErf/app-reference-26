#!/usr/bin/env mojo

from blob_storage import BlobStorage
from pl_grizzly_interpreter import PLGrizzlyInterpreter, Environment
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser

fn main() raises:
    print("Testing PL-GRIZZLY Module System")
    print("=================================")

    # Initialize storage and interpreter
    var storage = BlobStorage(".")
    var interpreter = PLGrizzlyInterpreter(storage)

    # Create a new environment for testing
    var env = Environment()
    env.values = interpreter.global_env.values.copy()

    # Test CREATE MODULE
    print("\n1. Testing CREATE MODULE:")
    var module_code = "CREATE MODULE math AS { fn add(a, b) { a + b } }"
    print("Code:", module_code)

    try:
        var lexer = PLGrizzlyLexer(module_code)
        var tokens = lexer.tokenize()
        print("Tokens:")
        for token in tokens:
            print("  " + token.type + ": '" + token.value + "'")
        var parser = PLGrizzlyParser(tokens)
        var ast = parser.parse()
        print("AST:", ast)
        var result = interpreter.evaluate(ast, env)
        print("Evaluating AST:", ast)
        print("Result:", result.type, "-", result.value)
    except e:
        print("Error:", e)

    # Test IMPORT
    print("\n2. Testing IMPORT:")
    var import_code = "IMPORT math"
    print("Code:", import_code)

    try:
        lexer = PLGrizzlyLexer(import_code)
        tokens = lexer.tokenize()
        parser = PLGrizzlyParser(tokens)
        ast = parser.parse()
        print("AST:", ast)
        result = interpreter.evaluate(ast, env)
        print("Result:", result.type, "-", result.value)
    except e:
        print("Error:", e)

    # Test function call
    print("\n3. Testing function call:")
    var call_code = "add(5, 3)"
    print("Code:", call_code)

    try:
        lexer = PLGrizzlyLexer(call_code)
        tokens = lexer.tokenize()
        parser = PLGrizzlyParser(tokens)
        ast = parser.parse()
        print("AST:", ast)
        result = interpreter.evaluate(ast, env)
        print("Result:", result.type, "-", result.value)
    except e:
        print("Error:", e)

    print("\nModule system test completed!")