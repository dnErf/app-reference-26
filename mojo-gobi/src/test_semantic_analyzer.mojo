"""
Test Semantic Analysis and Type Checking in PL-GRIZZLY
"""

from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from semantic_analyzer import SemanticAnalyzer, SemanticAnalysisResult

fn main() raises:
    print("Testing Semantic Analysis and Type Checking")
    print("=" * 60)

    # Test 1: Basic function definition and call
    var source1 = """
    CREATE FUNCTION add_numbers(a, b) RETURNS number { a + b }
    SELECT add_numbers(5, 3) FROM dummy
    """
    print("Test 1: Function definition and call")
    test_semantic_analysis(source1)

    # Test 2: Simple expressions
    var source2 = """
    SELECT 10 + 5 FROM dummy
    """
    print("\nTest 2: Simple expressions")
    test_semantic_analysis(source2)

    # Test 3: Type mismatches
    var source3 = """
    SELECT "hello" + 5 FROM dummy
    """
    print("\nTest 3: Type mismatch detection")
    test_semantic_analysis(source3)

    # Test 4: Function calls
    var source4 = """
    SELECT count(*) FROM dummy
    """
    print("\nTest 4: Function calls")
    test_semantic_analysis(source4)

    print("\nSemantic analysis testing completed!")

fn test_semantic_analysis(source: String) raises:
    """Test semantic analysis on a source string."""
    # Parse the source
    var lexer = PLGrizzlyLexer(source)
    var tokens = lexer.tokenize()
    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()

    # Perform semantic analysis
    var analyzer = SemanticAnalyzer()
    var result = analyzer.analyze(ast)

    # Report results
    print("  Source parsed successfully")
    print("  Semantic analysis result:")
    print("    Valid:", result.is_valid)
    print("    Errors:", len(result.errors))
    print("    Warnings:", len(result.warnings))

    if len(result.errors) > 0:
        print("    Errors:")
        for i in range(len(result.errors)):
            print("      -", result.errors[i])

    if len(result.warnings) > 0:
        print("    Warnings:")
        for i in range(len(result.warnings)):
            print("      -", result.warnings[i])