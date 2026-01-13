"""
Enhanced Error Handling Test Suite

Comprehensive testing of PL-GRIZZLY's enhanced error handling system including:
- Error chaining and propagation
- Recovery strategies
- Detailed error reporting
- Context tracking and suggestions
"""

from pl_grizzly_errors import (
    PLGrizzlyError, ErrorManager, ErrorRecovery,
    CATEGORY_SYNTAX, CATEGORY_TYPE, CATEGORY_RUNTIME, CATEGORY_SEMANTIC,
    SYNTAX_UNEXPECTED_TOKEN, TYPE_MISMATCH, RUNTIME_DIVISION_BY_ZERO,
    SEMANTIC_UNDEFINED_VARIABLE, IO_FILE_NOT_FOUND, NETWORK_CONNECTION_FAILED
)
from pl_grizzly_values import PLValue

def test_error_chaining():
    """Test error chaining functionality."""
    print("=== Error Chaining Test ===")

    # Create a root cause error
    var root_cause = PLGrizzlyError.io_error(
        "File not found: config.json",
        "file read operation"
    )

    # Create a secondary error that chains to the root cause
    var secondary_error = PLGrizzlyError.runtime_error(
        "Failed to load configuration", -1, -1, "Configuration loading"
    )
    secondary_error = secondary_error.with_cause(root_cause)

    secondary_error.add_recovery_suggestion("Check if config.json exists in the current directory")
    secondary_error.add_recovery_suggestion("Ensure proper file permissions")

    print("Chained Error:")
    print(secondary_error.__str__())
    print()

def test_error_recovery():
    """Test error recovery strategies."""
    print("=== Error Recovery Test ===")

    # Test division by zero recovery
    var div_error = PLGrizzlyError.runtime_error(
        "Division by zero", -1, -1, "Arithmetic operation"
    )
    div_error.error_code = RUNTIME_DIVISION_BY_ZERO

    var context = Dict[String, String]()
    var recovered = ErrorRecovery.attempt_recovery(div_error, context)

    print("Division by Zero Error:")
    print(div_error.__str__())
    print("Can recover: " + String(ErrorRecovery.can_recover(div_error)))
    if recovered:
        print("Recovered value: " + recovered.value().__str__())
    print()

    # Test undefined variable recovery
    var undef_error = PLGrizzlyError.semantic_error(
        "Undefined variable: 'missing_var'", -1, -1, "Variable resolution"
    )
    undef_error.error_code = SEMANTIC_UNDEFINED_VARIABLE

    context["missing_var_default"] = "default_value"
    recovered = ErrorRecovery.attempt_recovery(undef_error, context)

    print("Undefined Variable Error:")
    print(undef_error.__str__())
    print("Can recover: " + String(ErrorRecovery.can_recover(undef_error)))
    if recovered:
        print("Recovered value: " + recovered.value().__str__())
    print()

def test_enhanced_error_manager():
    """Test enhanced error manager capabilities."""
    print("=== Enhanced Error Manager Test ===")

    var manager = ErrorManager()

    # Add various types of errors
    var syntax_error = PLGrizzlyError.unexpected_token_error("}", "expression")
    var type_error = PLGrizzlyError.type_error("Cannot add string to number")
    var runtime_error = PLGrizzlyError.runtime_error("Index out of bounds")

    manager.add_error(syntax_error)
    manager.add_error(type_error)
    manager.add_error(runtime_error)

    # Add warnings
    var warning1 = PLGrizzlyError(
        "Variable 'x' is unused", CATEGORY_SEMANTIC, "warning"
    )
    var warning2 = PLGrizzlyError(
        "Deprecated function usage", CATEGORY_RUNTIME, "warning"
    )

    manager.add_warning(warning1)
    manager.add_warning(warning2)

    print("Basic Summary:")
    print(manager.get_summary())
    print()

    print("Detailed Summary:")
    print(manager.get_detailed_summary())
    print()

    print("JSON Export:")
    try:
        print(manager.export_to_json())
    except e:
        print("JSON export failed: " + String(e))
    print()

def test_plvalue_error_recovery():
    """Test PLValue error recovery methods."""
    print("=== PLValue Error Recovery Test ===")

    # Create an enhanced error PLValue
    var error = PLGrizzlyError.runtime_error("Division by zero")
    error.error_code = RUNTIME_DIVISION_BY_ZERO

    var error_value = PLValue.enhanced_error(error)

    print("Error PLValue:")
    print(error_value.__str__())
    print()

    print("Can recover error: " + String(error_value.can_recover_error()))

    var suggestions = error_value.get_error_suggestions()
    print("Recovery suggestions:")
    for i in range(len(suggestions)):
        print("  " + String(i + 1) + ". " + suggestions[i])

    var context = Dict[String, String]()
    var recovered = error_value.attempt_error_recovery(context)
    if recovered:
        print("Recovered to: " + recovered.value().__str__())
    else:
        print("No recovery possible")
    print()

def test_comprehensive_error_scenario():
    """Test a comprehensive error scenario with chaining and recovery."""
    print("=== Comprehensive Error Scenario Test ===")

    # Simulate a complex error scenario: HTTP request failure leading to data processing error

    # Root cause: Network failure
    var network_error = PLGrizzlyError.network_error(
        "Connection timeout", "https://api.example.com/data"
    )
    network_error.error_code = NETWORK_CONNECTION_FAILED

    # Intermediate error: Data fetch failure
    var fetch_error = PLGrizzlyError.io_error(
        "Failed to fetch required data from external API",
        "HTTP GET request"
    )
    fetch_error = fetch_error.with_cause(network_error)

    # Final error: Query execution failure
    var query_error = PLGrizzlyError.runtime_error(
        "Query execution failed due to missing data source",
        -1, -1, "Query execution"
    )
    query_error = query_error.with_cause(fetch_error)

    query_error.add_recovery_suggestion("Check network connectivity")
    query_error.add_recovery_suggestion("Verify API endpoint is accessible")
    query_error.add_recovery_suggestion("Consider using cached data if available")

    print("Complete Error Chain:")
    print(query_error.__str__())
    print()

    # Test recovery
    var context = Dict[String, String]()
    context["cached_data"] = '[{"id": 1, "name": "cached"}]'

    var can_recover = ErrorRecovery.can_recover(query_error.get_root_cause())
    print("Can recover from root cause: " + String(can_recover))

    if can_recover:
        var recovered = ErrorRecovery.attempt_recovery(query_error.get_root_cause(), context)
        if recovered:
            print("Recovered data: " + recovered.value().__str__())

def run_all_tests():
    """Run all enhanced error handling tests."""
    print("🧪 PL-GRIZZLY Enhanced Error Handling Test Suite")
    print("=" * 60)
    print()

    test_error_chaining()
    test_error_recovery()
    test_enhanced_error_manager()
    test_plvalue_error_recovery()
    test_comprehensive_error_scenario()

    print("✅ All Enhanced Error Handling Tests Completed!")
    print()
    print("Key Features Demonstrated:")
    print("  • Error chaining with root cause analysis")
    print("  • Automatic error recovery strategies")
    print("  • Enhanced error reporting with categories")
    print("  • JSON export for error logging")
    print("  • PLValue integration with recovery methods")
    print("  • Comprehensive context and suggestions")

def main():
    run_all_tests()