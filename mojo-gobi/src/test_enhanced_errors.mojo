"""
Test Enhanced Error Handling & Debugging

Demonstrates the improved error handling system with detailed context,
suggestions, and debugging information for PL-GRIZZLY.
"""

from pl_grizzly_errors import PLGrizzlyError, ErrorManager, CATEGORY_SYNTAX, CATEGORY_TYPE, CATEGORY_RUNTIME, SEVERITY_ERROR

def test_enhanced_errors():
    """Test enhanced error handling capabilities."""
    print("=== Enhanced Error Handling Test ===\n")

    # Create error manager
    var error_manager = ErrorManager()

    # Test 1: Syntax Error
    print("Test 1: Syntax Error")
    print("-" * 30)
    var syntax_error = PLGrizzlyError(
        message="Unexpected token '}'",
        category=CATEGORY_SYNTAX,
        severity=SEVERITY_ERROR,
        line=5,
        column=12,
        source_code="function test() { return x + }",
        context="Parsing function body",
        error_code="SYN001"
    )
    syntax_error.add_suggestion("Add missing expression after '+' operator")
    syntax_error.add_suggestion("Check for unmatched parentheses")
    syntax_error.add_stack_frame("parse_expression()")
    syntax_error.add_stack_frame("parse_function_body()")

    error_manager.add_error(syntax_error)
    print(syntax_error.__str__())
    print()

    # Test 2: Type Error
    print("Test 2: Type Error")
    print("-" * 30)
    var type_error = PLGrizzlyError(
        message="Cannot add string to number",
        category=CATEGORY_TYPE,
        severity=SEVERITY_ERROR,
        line=10,
        column=8,
        source_code="result = 42 + \"hello\"",
        context="Type checking binary operation",
        error_code="TYPE002"
    )
    type_error.add_suggestion("Convert number to string: str(42) + \"hello\"")
    type_error.add_suggestion("Convert string to number: 42 + int(\"hello\")")

    error_manager.add_error(type_error)
    print(type_error.__str__())
    print()

    # Test 3: Runtime Error
    print("Test 3: Runtime Error")
    print("-" * 30)
    var runtime_error = PLGrizzlyError(
        message="Division by zero",
        category=CATEGORY_RUNTIME,
        severity=SEVERITY_ERROR,
        line=15,
        column=10,
        source_code="ratio = total / 0",
        context="Evaluating division operation",
        error_code="RUNTIME003"
    )
    runtime_error.add_suggestion("Add zero check: if denominator != 0: ratio = total / denominator")
    runtime_error.add_suggestion("Use safe division function")

    error_manager.add_error(runtime_error)
    print(runtime_error.__str__())
    print()

    # Test 4: Error Manager Summary
    print("Test 4: Error Manager Summary")
    print("-" * 30)
    print(error_manager.get_summary())
    print()

    print("=== Test Completed Successfully ===")

def test_error_manager():
    """Test error manager functionality."""
    print("=== Error Manager Test ===\n")

    var manager = ErrorManager()

    # Add multiple errors
    for i in range(3):
        var error = PLGrizzlyError(
            message="Test error " + String(i + 1),
            category=CATEGORY_RUNTIME,
            severity=SEVERITY_ERROR,
            line=i + 1,
            column=5,
            source_code="test code line " + String(i + 1),
            error_code="TEST" + String(i + 1).rjust(3, "0")
        )
        manager.add_error(error)

    print("Error Summary:")
    print(manager.get_summary())
    print()

    print("=== Error Manager Test Completed ===")

def test_error_suggestions():
    """Test error suggestions functionality."""
    print("=== Error Suggestions Test ===\n")

    var error = PLGrizzlyError(
        message="Undefined variable 'count'",
        category=CATEGORY_RUNTIME,
        severity=SEVERITY_ERROR,
        line=8,
        column=15,
        source_code="total = price * count",
        context="Variable resolution",
        error_code="VAR001"
    )

    error.add_suggestion("Define variable: count = 1")
    error.add_suggestion("Check variable name spelling")
    error.add_suggestion("Import variable from module")

    print("Error with suggestions:")
    print(error.__str__())
    print()

    print("=== Error Suggestions Test Completed ===")

# Run all tests
def main():
    test_enhanced_errors()
    print()
    test_error_manager()
    print()
    test_error_suggestions()

fn run_tests() raises:
    main()