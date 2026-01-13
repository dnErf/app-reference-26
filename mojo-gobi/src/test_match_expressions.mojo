from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser

fn main() raises:
    print("🧪 Testing MATCH Expression Parsing")
    print("=" * 40)

    # Test basic MATCH expression parsing - just the expression part
    var sql = '"premium" MATCH { "premium" -> "VIP", "basic" -> "Standard", _ -> "Unknown" }'
    print("Testing SQL:", sql)

    var lexer = PLGrizzlyLexer(sql)
    var tokens = lexer.tokenize()
    print("Tokens parsed successfully")

    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    print("AST parsed successfully")

    print("AST node type:", ast.node_type)
    print("AST value:", ast.value)
    print("Number of children:", len(ast.children))

    if ast.node_type == "MATCH":
        print("✅ MATCH expression parsed correctly!")
        print("MATCH children:", len(ast.children))

        if len(ast.children) > 0:
            var match_expr = ast.children[0].copy()
            print("Match expression type:", match_expr.node_type)
            print("Match expression value:", match_expr.value)

        # Check for MATCH_CASE children
        for i in range(1, len(ast.children)):
            var case_node = ast.children[i].copy()
            print("Case", i, "type:", case_node.node_type)
            if case_node.node_type == "MATCH_CASE":
                print("  Case has", len(case_node.children), "children")
                if len(case_node.children) >= 2:
                    var pattern = case_node.children[0].copy()
                    var value = case_node.children[1].copy()
                    print("  Pattern:", pattern.value, "-> Value:", value.value)

    else:
        print("❌ Expected MATCH node, got:", ast.node_type)

    print("🎉 Basic MATCH parsing test completed!")