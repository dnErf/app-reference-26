"""
PL-GRIZZLY Enhanced Error Handling Module

Comprehensive error handling system with categorized errors, context information,
stack traces, and debugging support for the PL-GRIZZLY language.
"""

from collections import List, Dict
from pl_grizzly_values import PLValue

# Error categories
alias ErrorCategory = String
alias CATEGORY_SYNTAX = "syntax"
alias CATEGORY_TYPE = "type"
alias CATEGORY_RUNTIME = "runtime"
alias CATEGORY_SEMANTIC = "semantic"
alias CATEGORY_SYSTEM = "system"
alias CATEGORY_IO = "io"
alias CATEGORY_NETWORK = "network"
alias CATEGORY_SECURITY = "security"

# Error severity levels
alias ErrorSeverity = String
alias SEVERITY_INFO = "info"
alias SEVERITY_WARNING = "warning"
alias SEVERITY_ERROR = "error"
alias SEVERITY_CRITICAL = "critical"

# Specific error codes
alias SYNTAX_UNEXPECTED_TOKEN = "SYNTAX_001"
alias SYNTAX_MISSING_PARENTHESIS = "SYNTAX_002"
alias SYNTAX_INVALID_IDENTIFIER = "SYNTAX_003"
alias SYNTAX_UNTERMINATED_STRING = "SYNTAX_004"

alias TYPE_MISMATCH = "TYPE_001"
alias TYPE_INCOMPATIBLE_OPERATION = "TYPE_002"
alias TYPE_UNDEFINED_TYPE = "TYPE_003"
alias TYPE_INVALID_CAST = "TYPE_004"

alias RUNTIME_DIVISION_BY_ZERO = "RUNTIME_001"
alias RUNTIME_INDEX_OUT_OF_BOUNDS = "RUNTIME_002"
alias RUNTIME_NULL_REFERENCE = "RUNTIME_003"
alias RUNTIME_STACK_OVERFLOW = "RUNTIME_004"

alias SEMANTIC_UNDEFINED_VARIABLE = "SEMANTIC_001"
alias SEMANTIC_UNDEFINED_FUNCTION = "SEMANTIC_002"
alias SEMANTIC_DUPLICATE_DEFINITION = "SEMANTIC_003"
alias SEMANTIC_INVALID_OPERATION = "SEMANTIC_004"

alias IO_FILE_NOT_FOUND = "IO_001"
alias IO_PERMISSION_DENIED = "IO_002"
alias IO_DISK_FULL = "IO_003"

alias NETWORK_CONNECTION_FAILED = "NETWORK_001"
alias NETWORK_TIMEOUT = "NETWORK_002"
alias NETWORK_INVALID_URL = "NETWORK_003"

# Enhanced error structure with comprehensive context
struct PLGrizzlyError(Copyable, Movable, ImplicitlyCopyable):
    var message: String
    var category: ErrorCategory
    var severity: ErrorSeverity
    var line: Int
    var column: Int
    var source_code: String
    var context: String
    var suggestions: List[String]
    var stack_trace: List[String]
    var error_code: String
    var timestamp: String  # ISO format timestamp
    var cause_message: String  # Store cause as message only to avoid recursion
    var recovery_suggestions: List[String]  # Specific recovery actions

    fn __init__(out self,
                message: String,
                category: ErrorCategory = CATEGORY_RUNTIME,
                severity: ErrorSeverity = SEVERITY_ERROR,
                line: Int = -1,
                column: Int = -1,
                source_code: String = "",
                context: String = "",
                error_code: String = ""):
        self.message = message
        self.category = category
        self.severity = severity
        self.line = line
        self.column = column
        self.source_code = source_code
        self.context = context
        self.suggestions = List[String]()
        self.stack_trace = List[String]()
        self.error_code = error_code
        self.cause_message = ""
        self.recovery_suggestions = List[String]()
        # Initialize timestamp with default, then update
        self.timestamp = "2026-01-13T12:00:00Z"
        self.timestamp = PLGrizzlyError._get_current_timestamp()

    fn __copyinit__(out self, other: PLGrizzlyError):
        self.message = other.message
        self.category = other.category
        self.severity = other.severity
        self.line = other.line
        self.column = other.column
        self.source_code = other.source_code
        self.context = other.context
        self.suggestions = other.suggestions.copy()
        self.stack_trace = other.stack_trace.copy()
        self.error_code = other.error_code
        self.timestamp = other.timestamp
        self.cause_message = other.cause_message
        self.recovery_suggestions = other.recovery_suggestions.copy()

    @staticmethod
    fn _get_current_timestamp() -> String:
        """Get current timestamp in ISO format (simplified implementation)."""
        # In a real implementation, this would use proper datetime
        return "2026-01-13T12:00:00Z"

    fn add_suggestion(mut self, suggestion: String):
        """Add a suggestion for fixing the error."""
        self.suggestions.append(suggestion)

    fn add_stack_frame(mut self, frame: String):
        """Add a frame to the stack trace."""
        self.stack_trace.append(frame)

    fn with_line_info(mut self, line: Int, column: Int, source: String) -> Self:
        """Create a copy with line information."""
        var copy = self
        copy.line = line
        copy.column = column
        copy.source_code = source
        return copy

    fn with_context(mut self, context: String) -> Self:
        """Create a copy with additional context."""
        var copy = self
        copy.context = context
        return copy

    fn with_cause(mut self, cause: PLGrizzlyError) -> Self:
        """Create a copy with a root cause for error chaining."""
        var copy = self
        copy.cause_message = cause.message
        return copy

    fn add_recovery_suggestion(mut self, suggestion: String):
        """Add a specific recovery action suggestion."""
        self.recovery_suggestions.append(suggestion)

    fn get_root_cause(self) -> PLGrizzlyError:
        """Get the root cause of this error (simplified - returns self since we can't chain recursively)."""
        return self

    fn __str__(self) raises -> String:
        """Format error as a rich string with all context information."""
        var result = String()

        # Error header with category and severity
        result += "[" + self.category.upper() + " " + self.severity.upper() + "] "

        # Error code if present
        if self.error_code != "":
            result += "(" + self.error_code + ") "

        result += self.message + "\n"

        # Location information
        if self.line >= 0:
            result += "  at line " + String(self.line)
            if self.column >= 0:
                result += ", column " + String(self.column)
            result += "\n"

        # Source code snippet
        if self.source_code != "":
            result += "  " + self.source_code + "\n"
            if self.column >= 0:
                # Add caret pointing to error location
                var caret = "  "
                for _ in range(self.column):
                    caret += " "
                caret += "^"
                result += caret + "\n"
            else:
                result += "  ^\n"

        # Context information
        if self.context != "":
            result += "Context: " + self.context + "\n"

        # Recovery suggestions
        if len(self.recovery_suggestions) > 0:
            result += "Recovery Actions:\n"
            for i in range(len(self.recovery_suggestions)):
                result += "  • " + self.recovery_suggestions[i] + "\n"

        # Suggestions
        if len(self.suggestions) > 0:
            result += "Suggestions:\n"
            for i in range(len(self.suggestions)):
                result += "  • " + self.suggestions[i] + "\n"

        # Root cause
        if self.cause_message != "":
            result += "Caused by:\n"
            result += "  " + self.cause_message + "\n"

        # Stack trace
        if len(self.stack_trace) > 0:
            result += "Stack trace:\n"
            for i in range(len(self.stack_trace)):
                result += "  " + String(i + 1) + ". " + self.stack_trace[i] + "\n"

        return result

    @staticmethod
    fn syntax_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a syntax error."""
        var error = PLGrizzlyError(message, CATEGORY_SYNTAX, SEVERITY_ERROR, line, column, source, "", SYNTAX_UNEXPECTED_TOKEN)
        error.add_suggestion("Check the syntax against PL-GRIZZLY language specification")
        error.add_suggestion("Ensure all parentheses are properly balanced")
        error.add_recovery_suggestion("Review the code around the error location")
        return error

    @staticmethod
    fn unexpected_token_error(token: String, expected: String = "", line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create an unexpected token error."""
        var message = "Unexpected token: '" + token + "'"
        if expected != "":
            message += ", expected: " + expected
        var error = PLGrizzlyError(message, CATEGORY_SYNTAX, SEVERITY_ERROR, line, column, source, "Token parsing", SYNTAX_UNEXPECTED_TOKEN)
        error.add_suggestion("Check for missing or extra punctuation")
        error.add_suggestion("Ensure proper keyword usage")
        error.add_recovery_suggestion("Replace the unexpected token with the correct syntax")
        return error

    @staticmethod
    fn type_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a type error."""
        var error = PLGrizzlyError(message, CATEGORY_TYPE, SEVERITY_ERROR, line, column, source, "", TYPE_MISMATCH)
        error.add_suggestion("Check variable types and ensure type compatibility")
        error.add_suggestion("Use explicit type conversions when necessary")
        error.add_recovery_suggestion("Add type annotations or conversions")
        return error

    @staticmethod
    fn runtime_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a runtime error."""
        var error = PLGrizzlyError(message, CATEGORY_RUNTIME, SEVERITY_ERROR, line, column, source, "", RUNTIME_STACK_OVERFLOW)
        error.add_suggestion("Check variable values and operation validity")
        error.add_suggestion("Ensure resources are properly initialized")
        error.add_recovery_suggestion("Add input validation before operations")
        return error

    @staticmethod
    fn semantic_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a semantic error."""
        var error = PLGrizzlyError(message, CATEGORY_SEMANTIC, SEVERITY_ERROR, line, column, source, "", SEMANTIC_INVALID_OPERATION)
        error.add_suggestion("Review the logic and ensure semantic correctness")
        error.add_suggestion("Check for undefined variables or incorrect usage")
        error.add_recovery_suggestion("Define missing variables or correct usage")
        return error

    @staticmethod
    fn io_error(message: String, operation: String = "", line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create an I/O error."""
        var error = PLGrizzlyError(message, CATEGORY_IO, SEVERITY_ERROR, line, column, source, "File operation: " + operation, IO_FILE_NOT_FOUND)
        error.add_suggestion("Check file paths and permissions")
        error.add_suggestion("Ensure the file exists and is accessible")
        error.add_recovery_suggestion("Verify file path and create missing directories if needed")
        return error

    @staticmethod
    fn network_error(message: String, url: String = "", line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a network error."""
        var error = PLGrizzlyError(message, CATEGORY_NETWORK, SEVERITY_ERROR, line, column, source, "Network request to: " + url, NETWORK_CONNECTION_FAILED)
        error.add_suggestion("Check network connectivity and URL validity")
        error.add_suggestion("Verify authentication credentials if required")
        error.add_recovery_suggestion("Retry the operation or check network settings")
        return error

    @staticmethod
    fn system_error(message: String, context: String = "") -> PLGrizzlyError:
        """Create a system error."""
        var error = PLGrizzlyError(message, CATEGORY_SYSTEM, SEVERITY_CRITICAL, -1, -1, "", context, "SYSTEM_001")
        error.add_suggestion("Check system resources and permissions")
        error.add_suggestion("Contact system administrator if issue persists")
        error.add_recovery_suggestion("Restart the application or check system logs")
        return error

# Error collection and management
struct ErrorManager:
    var errors: List[PLGrizzlyError]
    var warnings: List[PLGrizzlyError]
    var max_errors: Int

    fn __init__(out self, max_errors: Int = 50):
        self.errors = List[PLGrizzlyError]()
        self.warnings = List[PLGrizzlyError]()
        self.max_errors = max_errors

    fn add_error(mut self, error: PLGrizzlyError):
        """Add an error to the collection."""
        if len(self.errors) < self.max_errors:
            self.errors.append(error)

    fn add_warning(mut self, warning: PLGrizzlyError):
        """Add a warning to the collection."""
        if len(self.warnings) < self.max_errors:
            self.warnings.append(warning)

    fn has_errors(self) -> Bool:
        """Check if there are any errors."""
        return len(self.errors) > 0

    fn has_warnings(self) -> Bool:
        """Check if there are any warnings."""
        return len(self.warnings) > 0

    fn clear(mut self):
        """Clear all errors and warnings."""
        self.errors = List[PLGrizzlyError]()
        self.warnings = List[PLGrizzlyError]()

    fn get_summary(self) -> String:
        """Get a summary of errors and warnings."""
        var error_count = len(self.errors)
        var warning_count = len(self.warnings)

        if error_count == 0 and warning_count == 0:
            return "No errors or warnings"

        var summary = String()
        if error_count > 0:
            summary += String(error_count) + " error"
            if error_count != 1:
                summary += "s"
        if warning_count > 0:
            if error_count > 0:
                summary += ", "
            summary += String(warning_count) + " warning"
            if warning_count != 1:
                summary += "s"

        return summary

    fn get_detailed_summary(self) raises -> String:
        """Get a detailed summary with error categories."""
        var error_count = len(self.errors)
        var warning_count = len(self.warnings)

        if error_count == 0 and warning_count == 0:
            return "✅ No errors or warnings detected"

        var summary = String("Error Summary:\n")
        summary += "=" * 50 + "\n"

        # Simple counting without complex Dict operations
        var syntax_errors = 0
        var type_errors = 0
        var runtime_errors = 0
        var semantic_errors = 0
        var other_errors = 0

        for i in range(len(self.errors)):
            var error = self.errors[i]
            if error.category == CATEGORY_SYNTAX:
                syntax_errors += 1
            elif error.category == CATEGORY_TYPE:
                type_errors += 1
            elif error.category == CATEGORY_RUNTIME:
                runtime_errors += 1
            elif error.category == CATEGORY_SEMANTIC:
                semantic_errors += 1
            else:
                other_errors += 1

        # Format error summary
        if error_count > 0:
            summary += "Errors (" + String(error_count) + "):\n"
            if syntax_errors > 0:
                summary += "  SYNTAX: " + String(syntax_errors) + "\n"
            if type_errors > 0:
                summary += "  TYPE: " + String(type_errors) + "\n"
            if runtime_errors > 0:
                summary += "  RUNTIME: " + String(runtime_errors) + "\n"
            if semantic_errors > 0:
                summary += "  SEMANTIC: " + String(semantic_errors) + "\n"
            if other_errors > 0:
                summary += "  OTHER: " + String(other_errors) + "\n"

        # Similar for warnings
        var syntax_warnings = 0
        var type_warnings = 0
        var runtime_warnings = 0
        var semantic_warnings = 0
        var other_warnings = 0

        for i in range(len(self.warnings)):
            var warning = self.warnings[i]
            if warning.category == CATEGORY_SYNTAX:
                syntax_warnings += 1
            elif warning.category == CATEGORY_TYPE:
                type_warnings += 1
            elif warning.category == CATEGORY_RUNTIME:
                runtime_warnings += 1
            elif warning.category == CATEGORY_SEMANTIC:
                semantic_warnings += 1
            else:
                other_warnings += 1

        if warning_count > 0:
            summary += "Warnings (" + String(warning_count) + "):\n"
            if syntax_warnings > 0:
                summary += "  SYNTAX: " + String(syntax_warnings) + "\n"
            if type_warnings > 0:
                summary += "  TYPE: " + String(type_warnings) + "\n"
            if runtime_warnings > 0:
                summary += "  RUNTIME: " + String(runtime_warnings) + "\n"
            if semantic_warnings > 0:
                summary += "  SEMANTIC: " + String(semantic_warnings) + "\n"
            if other_warnings > 0:
                summary += "  OTHER: " + String(other_warnings) + "\n"

        return summary

    fn export_to_json(self) raises -> String:
        """Export all errors and warnings to JSON format."""
        var json_output = String('{"errors":[')

        # Export errors
        for i in range(len(self.errors)):
            if i > 0:
                json_output += ","
            var error = self.errors[i]
            json_output += '{"message":"' + error.message.replace('"', '\\"') + '"'
            json_output += ',"category":"' + error.category + '"'
            json_output += ',"severity":"' + error.severity + '"'
            json_output += ',"line":' + String(error.line)
            json_output += ',"column":' + String(error.column)
            json_output += ',"error_code":"' + error.error_code + '"'
            json_output += ',"timestamp":"' + error.timestamp + '"}'

        json_output += '],"warnings":['

        # Export warnings
        for i in range(len(self.warnings)):
            if i > 0:
                json_output += ","
            var warning = self.warnings[i]
            json_output += '{"message":"' + warning.message.replace('"', '\\"') + '"'
            json_output += ',"category":"' + warning.category + '"'
            json_output += ',"severity":"' + warning.severity + '"'
            json_output += ',"line":' + String(warning.line)
            json_output += ',"column":' + String(warning.column)
            json_output += ',"error_code":"' + warning.error_code + '"'
            json_output += ',"timestamp":"' + warning.timestamp + '"}'

        json_output += ']}'
        return json_output

# Error Recovery Strategies
struct ErrorRecovery:
    """Handles error recovery strategies for common failure scenarios."""

    @staticmethod
    fn attempt_recovery(error: PLGrizzlyError, context: Dict[String, String]) raises -> Optional[PLValue]:
        """Attempt to recover from an error based on its type and context."""
        if error.category == CATEGORY_RUNTIME and error.error_code == RUNTIME_DIVISION_BY_ZERO:
            return ErrorRecovery._recover_division_by_zero(error, context)
        elif error.category == CATEGORY_SEMANTIC and error.error_code == SEMANTIC_UNDEFINED_VARIABLE:
            return ErrorRecovery._recover_undefined_variable(error, context)
        elif error.category == CATEGORY_IO and error.error_code == IO_FILE_NOT_FOUND:
            return ErrorRecovery._recover_file_not_found(error, context)
        elif error.category == CATEGORY_NETWORK and error.error_code == NETWORK_CONNECTION_FAILED:
            return ErrorRecovery._recover_network_failure(error, context)

        return None  # No recovery possible

    @staticmethod
    fn _recover_division_by_zero(error: PLGrizzlyError, context: Dict[String, String]) -> Optional[PLValue]:
        """Recover from division by zero by returning a default value."""
        # Return 0.0 as a safe default for division by zero
        return PLValue("number", "0.0")

    @staticmethod
    fn _recover_undefined_variable(error: PLGrizzlyError, context: Dict[String, String]) raises -> Optional[PLValue]:
        """Attempt to recover from undefined variable by providing a default."""
        # Extract variable name from error message
        var message = error.message
        if message.find("'") != -1 and message.rfind("'") != message.find("'"):
            var start = message.find("'") + 1
            var end = message.rfind("'")
            var var_name = message[start:end]

            # Check if we have a default value in context
            if var_name + "_default" in context:
                return PLValue("string", context[var_name + "_default"])

        return None

    @staticmethod
    fn _recover_file_not_found(error: PLGrizzlyError, context: Dict[String, String]) -> Optional[PLValue]:
        """Attempt to recover from file not found by creating an empty result."""
        # Return empty array as safe default
        return PLValue("array", "[]")

    @staticmethod
    fn _recover_network_failure(error: PLGrizzlyError, context: Dict[String, String]) raises -> Optional[PLValue]:
        """Attempt to recover from network failure with cached data."""
        # Check if we have cached data
        if "cached_data" in context:
            return PLValue("string", context["cached_data"])

        return None

    @staticmethod
    fn can_recover(error: PLGrizzlyError) -> Bool:
        """Check if an error can potentially be recovered from."""
        var recoverable_codes = List[String](
            RUNTIME_DIVISION_BY_ZERO,
            SEMANTIC_UNDEFINED_VARIABLE,
            IO_FILE_NOT_FOUND,
            NETWORK_CONNECTION_FAILED
        )

        return error.error_code in recoverable_codes

    fn format_all(self) raises -> String:
        """Format all errors and warnings as a single string."""
        var result = String()

        # Format errors
        for i in range(len(self.errors)):
            result += "Error " + String(i + 1) + ":\n"
            result += self.errors[i].__str__() + "\n"

        # Format warnings
        for i in range(len(self.warnings)):
            result += "Warning " + String(i + 1) + ":\n"
            result += self.warnings[i].__str__() + "\n"

        return result

# Helper functions for common error patterns
fn create_undefined_variable_error(var_name: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
    """Create an error for undefined variables."""
    var error = PLGrizzlyError.semantic_error(
        "Undefined variable: '" + var_name + "'",
        line, column, source
    )
    error.add_suggestion("Define the variable using LET before using it")
    error.add_suggestion("Check for typos in variable name")
    return error

fn create_type_mismatch_error(expected: String, actual: String, operation: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
    """Create an error for type mismatches."""
    var error = PLGrizzlyError.type_error(
        "Type mismatch in " + operation + ": expected " + expected + ", got " + actual,
        line, column, source
    )
    error.add_suggestion("Convert types explicitly using appropriate functions")
    error.add_suggestion("Check operation requirements for correct types")
    return error

fn create_division_by_zero_error(line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
    """Create an error for division by zero."""
    var error = PLGrizzlyError.runtime_error(
        "Division by zero",
        line, column, source
    )
    error.add_suggestion("Check divisor value before division")
    error.add_suggestion("Use conditional logic to handle zero divisors")
    return error

fn create_table_not_found_error(table_name: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
    """Create an error for missing tables."""
    var error = PLGrizzlyError.runtime_error(
        "Table not found: '" + table_name + "'",
        line, column, source
    )
    error.add_suggestion("Check table name spelling")
    error.add_suggestion("Ensure table exists in current database")
    error.add_suggestion("Use SHOW TABLES to list available tables")
    return error