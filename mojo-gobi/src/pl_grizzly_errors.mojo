"""
PL-GRIZZLY Enhanced Error Handling Module

Comprehensive error handling system with categorized errors, context information,
stack traces, and debugging support for the PL-GRIZZLY language.
"""

from collections import List, Dict

# Error severity levels
alias ErrorSeverity = String
alias SEVERITY_INFO = "info"
alias SEVERITY_WARNING = "warning"
alias SEVERITY_ERROR = "error"
alias SEVERITY_CRITICAL = "critical"

# Error categories
alias ErrorCategory = String
alias CATEGORY_SYNTAX = "syntax"
alias CATEGORY_TYPE = "type"
alias CATEGORY_RUNTIME = "runtime"
alias CATEGORY_SEMANTIC = "semantic"
alias CATEGORY_SYSTEM = "system"

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

        # Suggestions
        if len(self.suggestions) > 0:
            result += "Suggestions:\n"
            for i in range(len(self.suggestions)):
                result += "  • " + self.suggestions[i] + "\n"

        # Stack trace
        if len(self.stack_trace) > 0:
            result += "Stack trace:\n"
            for i in range(len(self.stack_trace)):
                result += "  " + String(i + 1) + ". " + self.stack_trace[i] + "\n"

        return result

    @staticmethod
    fn syntax_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a syntax error."""
        var error = PLGrizzlyError(message, CATEGORY_SYNTAX, SEVERITY_ERROR, line, column, source, "", "SYNTAX_001")
        error.add_suggestion("Check the syntax against PL-GRIZZLY language specification")
        error.add_suggestion("Ensure all parentheses are properly balanced")
        return error

    @staticmethod
    fn type_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a type error."""
        var error = PLGrizzlyError(message, CATEGORY_TYPE, SEVERITY_ERROR, line, column, source, "", "TYPE_001")
        error.add_suggestion("Check variable types and ensure type compatibility")
        error.add_suggestion("Use explicit type conversions when necessary")
        return error

    @staticmethod
    fn runtime_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a runtime error."""
        var error = PLGrizzlyError(message, CATEGORY_RUNTIME, SEVERITY_ERROR, line, column, source, "", "RUNTIME_001")
        error.add_suggestion("Check variable values and operation validity")
        error.add_suggestion("Ensure resources are properly initialized")
        return error

    @staticmethod
    fn semantic_error(message: String, line: Int = -1, column: Int = -1, source: String = "") -> PLGrizzlyError:
        """Create a semantic error."""
        var error = PLGrizzlyError(message, CATEGORY_SEMANTIC, SEVERITY_ERROR, line, column, source, "", "SEMANTIC_001")
        error.add_suggestion("Review the logic and ensure semantic correctness")
        error.add_suggestion("Check for undefined variables or incorrect usage")
        return error

    @staticmethod
    fn system_error(message: String, context: String = "") -> PLGrizzlyError:
        """Create a system error."""
        var error = PLGrizzlyError(message, CATEGORY_SYSTEM, SEVERITY_CRITICAL, -1, -1, "", context, "SYSTEM_001")
        error.add_suggestion("Check system resources and permissions")
        error.add_suggestion("Contact system administrator if issue persists")
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