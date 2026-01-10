"""
Unit tests for query parsing operations.
"""

from extensions.query_parser import parse_query, Query

fn test_parse_create_table() raises -> Bool:
    """Test parsing CREATE TABLE queries."""
    print("Testing CREATE TABLE parsing...")

    var sql = "CREATE TABLE users"
    var query = parse_query(sql)

    if query.query_type != "CREATE":
        print(f"ERROR: Expected query_type 'CREATE', got '{query.query_type}'")
        return False

    if query.table_name != "users":
        print(f"ERROR: Expected table_name 'users', got '{query.table_name}'")
        return False

    print("✓ CREATE TABLE parsing test passed")
    return True

fn test_parse_select() raises -> Bool:
    """Test parsing SELECT queries."""
    print("Testing SELECT parsing...")

    var sql = "SELECT * FROM users"
    var query = parse_query(sql)

    if query.query_type != "SELECT":
        print(f"ERROR: Expected query_type 'SELECT', got '{query.query_type}'")
        return False

    if query.table_name != "users":
        print(f"ERROR: Expected table_name 'users', got '{query.table_name}'")
        return False

    if len(query.columns) != 1 or query.columns[0] != "*":
        print("ERROR: Expected columns ['*']")
        return False

    print("✓ SELECT parsing test passed")
    return True

fn test_parse_insert() raises -> Bool:
    """Test parsing INSERT queries."""
    print("Testing INSERT parsing...")

    var sql = "INSERT INTO users VALUES (1, 'Alice', 25)"
    var query = parse_query(sql)

    if query.query_type != "INSERT":
        print(f"ERROR: Expected query_type 'INSERT', got '{query.query_type}'")
        return False

    if query.table_name != "users":
        print(f"ERROR: Expected table_name 'users', got '{query.table_name}'")
        return False

    if len(query.values) != 3:
        print(f"ERROR: Expected 3 values, got {len(query.values)}")
        return False

    print("✓ INSERT parsing test passed")
    return True

fn test_parse_pl_expression() raises -> Bool:
    """Test parsing PL expressions."""
    print("Testing PL expression parsing...")

    var sql = "SELECT 1 + 2 * 3"
    var query = parse_query(sql)

    if query.query_type != "PL":
        print(f"ERROR: Expected query_type 'PL', got '{query.query_type}'")
        return False

    if query.pl_code != sql:
        print(f"ERROR: PL code not preserved correctly")
        return False

    print("✓ PL expression parsing test passed")
    return True

fn test_parse_create_function() raises -> Bool:
    """Test parsing CREATE FUNCTION queries."""
    print("Testing CREATE FUNCTION parsing...")

    var sql = "CREATE FUNCTION test_func() RETURNS TEXT { return 'hello' }"
    var query = parse_query(sql)

    if query.query_type != "CREATE_FUNCTION":
        print(f"ERROR: Expected query_type 'CREATE_FUNCTION', got '{query.query_type}'")
        return False

    if query.func_name != "test_func":
        print(f"ERROR: Expected func_name 'test_func', got '{query.func_name}'")
        return False

    if query.func_returns != "TEXT":
        print(f"ERROR: Expected func_returns 'TEXT', got '{query.func_returns}'")
        return False

    print("✓ CREATE FUNCTION parsing test passed")
    return True

fn test_parse_invalid_query() raises -> Bool:
    """Test parsing invalid queries."""
    print("Testing invalid query handling...")

    try:
        var sql = ""
        var query = parse_query(sql)
        print("ERROR: Should have raised error for empty query")
        return False
    except:
        # Expected error for empty query
        pass

    print("✓ Invalid query handling test passed")
    return True

fn test_query_parser() raises -> Bool:
    """Run all query parser tests."""
    if not test_parse_create_table():
        return False
    if not test_parse_select():
        return False
    if not test_parse_insert():
        return False
    if not test_parse_pl_expression():
        return False
    if not test_parse_create_function():
        return False
    if not test_parse_invalid_query():
        return False

    return True