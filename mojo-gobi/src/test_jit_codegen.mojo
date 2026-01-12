"""
Test script for JIT Compiler Codegen functionality
"""

from jit_compiler import JITCompiler, CodeGenerator
from pl_grizzly_parser import PLGrizzlyParser, ASTNode
from pl_grizzly_lexer import PLGrizzlyLexer, Token
from pl_grizzly_values import PLValue

fn run_tests() raises:
    """Test the codegen functionality."""
    print("Testing JIT Compiler Codegen...")

    # Test function to compile
    var test_function = """
    CREATE FUNCTION add_numbers(a, b) RETURNS number { a + b }
    """

    print("Parsing function:", test_function.strip())

    # Create JIT compiler
    var jit = JITCompiler()

    # Create parser and lexer with proper initialization
    var lexer = PLGrizzlyLexer(test_function)
    var tokens = lexer.tokenize()
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()

    if len(ast.children) > 0:
        # The root AST is the FUNCTION node
        var func_ast = ast.copy()

        print("Compiling function...")

        # Compile function
        var success = jit.compile_function("add_numbers", func_ast)

        if success:
            print("✓ Function compiled successfully!")

            # Check generated code
            var compiled_opt = jit.get_compiled_function("add_numbers")
            if compiled_opt:
                var compiled = compiled_opt.value()
                print("Generated Mojo code:")
                print(compiled.mojo_code)

            # Test execution (simulation mode)
            var args = List[PLValue]()
            args.append(PLValue("number", "5"))
            args.append(PLValue("number", "3"))

            print("Testing execution (simulation mode)...")
            var result = jit.execute_compiled_function("add_numbers", args)
            print("Result:", result.value, "(type:", result.type + ")")

        else:
            print("✗ Function compilation failed")

    # Print stats
    var stats = jit.get_stats()
    print("\nJIT Compiler Stats:")
    for entry in stats.items():
        print("  " + entry.key + ":", entry.value)

fn test_code_generator():
    """Test the code generator directly."""
    print("\nTesting Code Generator...")

    var code_gen = CodeGenerator()

    # Create a simple function AST manually for testing
    var params = List[ASTNode]()
    var param_a = ASTNode("PARAMETER")
    param_a.value = "a"
    params.append(param_a.copy())

    var param_b = ASTNode("PARAMETER")
    param_b.value = "b"
    params.append(param_b.copy())

    # Create a simple return statement
    var return_stmt = ASTNode("BINARY_OP")
    return_stmt.value = "+"

    var literal_a = ASTNode("IDENTIFIER")
    literal_a.value = "a"
    return_stmt.children.append(literal_a.copy())

    var literal_b = ASTNode("IDENTIFIER")
    literal_b.value = "b"
    return_stmt.children.append(literal_b.copy())

    var generated_code = code_gen.generate_function("test_add", params, "number", return_stmt)

    print("Generated Mojo code:")
    print(generated_code)

fn main() raises:
    run_tests()
    test_code_generator()