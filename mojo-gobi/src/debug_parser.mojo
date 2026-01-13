from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser

fn main() raises:
    # Test basic SELECT
    var source1 = "SELECT name, department FROM employees"
    print("Testing:", source1)
    test_parsing(source1)
    
    # Test LOAD instead of IMPORT
    var source2 = "LOAD io, math, httpfs"
    print("\nTesting:", source2)
    test_parsing(source2)
    
    # Test TYPE SECRET
    var source3 = "TYPE SECRET AS Github_Token (kind: 'https', key: 'authentication', value: 'bearer ghp_your_github_token_here')"
    print("\nTesting:", source3)
    test_parsing(source3)
    
    # Test TYPE SECRET without kind field (should fail)
    var source3_invalid = "TYPE SECRET AS Test_Token (key: 'test', value: 'test_value')"
    print("\nTesting invalid TYPE SECRET (missing kind):", source3_invalid)
    test_parsing_invalid(source3_invalid)
    
    # Test SHOW SECRETS
    var source4 = "SHOW SECRETS"
    print("\nTesting:", source4)
    test_parsing(source4)
    
    # Test DROP SECRET
    var source5 = "DROP SECRET Github_Token"
    print("\nTesting:", source5)
    test_parsing(source5)
    
    # Test ATTACH
    var source6 = "ATTACH 'other_database.db'"
    print("\nTesting:", source6)
    test_parsing(source6)
    
    # Test ATTACH with alias
    var source6_alias = "ATTACH 'other_database.db' AS other_db"
    print("\nTesting:", source6_alias)
    test_parsing(source6_alias)
    
    # Test DETACH
    var source7 = "DETACH other_db"
    print("\nTesting:", source7)
    test_parsing(source7)
    
    # Test SHOW ATTACHED DATABASES
    var source8 = "SHOW ATTACHED DATABASES"
    print("\nTesting:", source8)
    test_parsing(source8)
    
    # Test BREAK and CONTINUE in THEN block
    var source9 = "FROM employees SELECT name THEN { break; continue; }"
    print("\nTesting:", source9)
    test_parsing(source9)

fn test_parsing(source: String) raises:
    var lexer = PLGrizzlyLexer(source)
    var tokens = lexer.tokenize()
    print("Tokens:")
    for i in range(len(tokens)):
        print("  Token", i, ":", tokens[i].type, tokens[i].value)

    var parser = PLGrizzlyParser(tokens)
    var ast = parser.parse()
    print("Parsed successfully")

fn test_parsing_invalid(source: String) raises:
    var lexer = PLGrizzlyLexer(source)
    var tokens = lexer.tokenize()
    print("Tokens:")
    for i in range(len(tokens)):
        print("  Token", i, ":", tokens[i].type, tokens[i].value)

    var parser = PLGrizzlyParser(tokens)
    try:
        var ast = parser.parse()
        print("Parsed successfully (unexpected)")
    except:
        print("Parse error (expected): TYPE SECRET requires 'kind' field")