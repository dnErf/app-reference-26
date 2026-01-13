"""
Test script for JOIN functionality in PL-GRIZZLY.
"""

from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser

fn test_join_parsing():
    """Test JOIN parsing functionality."""
    print("Testing JOIN functionality")
    print("=" * 40)

    # Test INNER JOIN
    var sql1 = "SELECT n.*, r.* FROM l_nations n JOIN l_regions r ON (n_regionkey = r_regionkey)"
    print("Testing SQL:", sql1)

    try:
        var lexer = PLGrizzlyLexer(sql1)
        var tokens = lexer.tokenize()
        print("✓ Lexing successful, tokens:", len(tokens))

        var parser = PLGrizzlyParser(tokens)
        print("Starting parse...")
        var ast = parser.parse()
        print("✓ Parsing successful, AST node type:", ast.node_type)

        if ast.node_type == "SELECT":
            print("✓ SELECT statement correctly parsed")
            
            # Check FROM clause
            for child in ast.children:
                if child.node_type == "FROM":
                    print("  FROM clause found with", len(child.children), "children")
                    for i in range(len(child.children)):
                        var subchild = child.children[i].copy()
                        print("    Child", i, ":", subchild.node_type)
                        if subchild.node_type == "TABLE_REFERENCE":
                            print("      Table:", subchild.get_attribute("table"), "Alias:", subchild.get_attribute("alias"))
                        elif subchild.node_type == "JOIN":
                            print("      JOIN found")
                            if len(subchild.children) >= 2:
                                var join_table = subchild.children[0].copy()
                                print("        Joined table:", join_table.get_attribute("table"), "Alias:", join_table.get_attribute("alias"))
        else:
            print("✗ Expected SELECT node, got:", ast.node_type)

    except e:
        print("✗ Error during JOIN test:", String(e))

    print("\nTesting LEFT JOIN...")
    
    # Test LEFT JOIN
    var sql2 = "SELECT n.*, r.* FROM l_nations n LEFT JOIN l_regions r ON (n_regionkey = r_regionkey)"
    print("Testing SQL:", sql2)

    try:
        var lexer2 = PLGrizzlyLexer(sql2)
        var tokens2 = lexer2.tokenize()
        print("✓ Lexing successful, tokens:", len(tokens2))

        var parser2 = PLGrizzlyParser(tokens2)
        var ast2 = parser2.parse()
        print("✓ Parsing successful, AST node type:", ast2.node_type)

        if ast2.node_type == "SELECT":
            print("✓ LEFT JOIN SELECT statement correctly parsed")
        else:
            print("✗ Expected SELECT node, got:", ast2.node_type)

    except e:
        print("✗ Error during LEFT JOIN test:", String(e))

fn main():
    test_join_parsing()