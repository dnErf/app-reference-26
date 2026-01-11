#!/usr/bin/env mojo

from pl_grizzly_lexer import Lexer
from pl_grizzly_parser import Parser
from pl_grizzly_interpreter import Interpreter

fn main() raises:
    var interpreter = Interpreter()

    # Test CREATE MODULE
    var module_code = "CREATE MODULE math { fn add(a, b) { a + b } }"
    print("Testing CREATE MODULE:")
    print("Code:", module_code)

    var lexer = Lexer(module_code)
    lexer.tokenize()
    var parser = Parser(lexer.tokens)
    var ast = parser.parse()
    print("AST:", ast)

    var result = interpreter.evaluate(ast, Environment())
    print("Result:", result.type, result.value)
    print()

    # Test IMPORT
    var import_code = "IMPORT math.add"
    print("Testing IMPORT:")
    print("Code:", import_code)

    lexer = Lexer(import_code)
    lexer.tokenize()
    parser = Parser(lexer.tokens)
    ast = parser.parse()
    print("AST:", ast)

    result = interpreter.evaluate(ast, Environment())
    print("Result:", result.type, result.value)
    print()

    # Test using imported function
    var use_code = "add(5, 3)"
    print("Testing function call:")
    print("Code:", use_code)

    lexer = Lexer(use_code)
    lexer.tokenize()
    parser = Parser(lexer.tokens)
    ast = parser.parse()
    print("AST:", ast)

    result = interpreter.evaluate(ast, Environment())
    print("Result:", result.type, result.value)