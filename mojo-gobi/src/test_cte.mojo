"""
Test script for CTE (Common Table Expression) functionality in PL-GRIZZLY.
"""

from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser

fn test_cte_basic():
    """Test basic CTE functionality."""
    print("Testing CTE (Common Table Expression) functionality")
    print("=" * 55)

    # Test the basic CTE syntax parsing
    var sql = "WITH cte AS (SELECT 42 AS x) SELECT * FROM cte"
    print("Testing SQL:", sql)

    try:
        # Just test that the parser can handle WITH statements
        var lexer = PLGrizzlyLexer(sql)
        var tokens = lexer.tokenize()
        print("✓ Lexing successful, tokens:", len(tokens))

        # Debug: print tokens
        print("Tokens:")
        for i in range(len(tokens)):
            var token = tokens[i].copy()
            print("  " + token.type + ": '" + token.value + "'")

        var parser = PLGrizzlyParser(tokens)
        print("Starting parse...")
        var ast = parser.parse()
        print("✓ Parsing successful, AST node type:", ast.node_type)

        if ast.node_type == "WITH":
            print("✓ WITH statement correctly parsed")
            print("  CTE definitions:", len(ast.children) - 1)
            print("  Main query present:", len(ast.children) > 0)

            # Print some details about the parsed structure
            for i in range(len(ast.children)):
                var child = ast.children[i].copy()
                if child.node_type == "CTE_DEFINITION":
                    print("  CTE '" + child.value + "' defined")
                elif child.node_type == "SELECT":
                    print("  Main SELECT query present")
        else:
            print("✗ Expected WITH node, got:", ast.node_type)

    except e:
        print("✗ Error during CTE test:", String(e))

    print("\nCTE Basic implementation completed!")
    print("Note: Full CTE evaluation requires table data storage implementation")

fn main():
    test_cte_basic()