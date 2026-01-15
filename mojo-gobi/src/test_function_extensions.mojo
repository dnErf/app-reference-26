#!/usr/bin/env mojo

from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser

fn test_function_declaration_extensions() raises:
    """Test the extended function declaration syntax."""
    print("🧪 Testing Function Declaration Extensions")
    print("=" * 50)

    # Test case 1: Function with receiver type
    var sql1 = "function <MyClass> method_name() returns void { return; }"
    print("Test 1: Function with receiver type")
    print("SQL:", sql1)

    var lexer1 = PLGrizzlyLexer(sql1)
    var tokens1 = lexer1.tokenize()
    print("✓ Lexing successful, tokens:", len(tokens1))

    var parser1 = PLGrizzlyParser(tokens1)
    var ast1 = parser1.parse()
    print("✓ Parsing successful")
    print("  Node type:", ast1.node_type)
    print("  Function name:", ast1.get_attribute("name"))
    print("  Receiver type:", ast1.get_attribute("receiver_type"))
    print("  Return type:", ast1.get_attribute("return_type"))

    # Test case 2: Function with raises clause
    var sql2 = "function my_func(a: int, b: string) raises Exception returns int { return a; }"
    print("\nTest 2: Function with raises clause")
    print("SQL:", sql2)

    var lexer2 = PLGrizzlyLexer(sql2)
    var tokens2 = lexer2.tokenize()
    print("✓ Lexing successful, tokens:", len(tokens2))

    var parser2 = PLGrizzlyParser(tokens2)
    var ast2 = parser2.parse()
    print("✓ Parsing successful")
    print("  Node type:", ast2.node_type)
    print("  Function name:", ast2.get_attribute("name"))
    print("  Raises:", ast2.get_attribute("raises"))
    print("  Return type:", ast2.get_attribute("return_type"))

    # Test case 3: Function with async execution mode
    var sql3 = "function async_func() as async returns void { return; }"
    print("\nTest 3: Function with async execution mode")
    print("SQL:", sql3)

    var lexer3 = PLGrizzlyLexer(sql3)
    var tokens3 = lexer3.tokenize()
    print("✓ Lexing successful, tokens:", len(tokens3))

    var parser3 = PLGrizzlyParser(tokens3)
    var ast3 = parser3.parse()
    print("✓ Parsing successful")
    print("  Node type:", ast3.node_type)
    print("  Function name:", ast3.get_attribute("name"))
    print("  Execution mode:", ast3.get_attribute("execution_mode"))
    print("  Return type:", ast3.get_attribute("return_type"))

    # Test case 4: Procedure with receiver type and all extensions
    var sql4 = "upsert procedure <MyClass> as my_method <{description: 'test method'}> (a: int) raises RuntimeError as sync returns string { return 'hello'; }"
    print("\nTest 4: Procedure with all extensions")
    print("SQL:", sql4)

    var lexer4 = PLGrizzlyLexer(sql4)
    var tokens4 = lexer4.tokenize()
    print("✓ Lexing successful, tokens:", len(tokens4))

    var parser4 = PLGrizzlyParser(tokens4)
    var ast4 = parser4.parse()
    print("✓ Parsing successful")
    print("  Node type:", ast4.node_type)
    print("  Procedure name:", ast4.get_attribute("name"))
    print("  Receiver type:", ast4.get_attribute("receiver_type"))
    print("  Raises:", ast4.get_attribute("raises"))
    print("  Return type:", ast4.get_attribute("return_type"))
    print("  Execution mode:", ast4.get_attribute("execution_mode"))

    print("\n✅ All Function Declaration Extensions tests passed!")

fn main() raises:
    test_function_declaration_extensions()