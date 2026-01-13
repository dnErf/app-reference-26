"""
PL-GRIZZLY Value Types Module

Core value types and operations for PL-GRIZZLY expressions.
"""

from collections import Dict, List
from pl_grizzly_environment import Environment
from pl_grizzly_errors import PLGrizzlyError, ErrorManager

# Forward declaration for lazy iterator
struct LazyIterator(Copyable, Movable):
    var data: List[List[String]]
    var index: Int
    
    fn __init__(out self, table_data: List[List[String]]):
        self.data = table_data.copy()
        self.index = 0
    
    fn next(mut self) -> Optional[List[String]]:
        if self.index < len(self.data):
            var row = self.data[self.index].copy()
            self.index += 1
            return row
        return None
    
    fn has_next(self) -> Bool:
        return self.index < len(self.data)

# Value types for PL-GRIZZLY
struct PLValue(Copyable, Movable, ImplicitlyCopyable):
    var type: String
    var value: String
    var closure_env: Optional[Environment]
    var error_context: String
    var enhanced_error_field: Optional[PLGrizzlyError]
    var lazy_iterator: Optional[LazyIterator]
    # var struct_data: Optional[Dict[String, PLValue]]
    # var list_data: Optional[List[PLValue]]

    fn __init__(out self, type: String = "string", value: String = ""):
        self.type = type
        self.value = value
        self.closure_env = None
        self.error_context = ""
        self.enhanced_error_field = None
        self.lazy_iterator = None

    fn __copyinit__(out self, other: PLValue):
        self.type = other.type
        self.value = other.value
        if other.closure_env:
            self.closure_env = other.closure_env.value().copy()
        else:
            self.closure_env = None
        self.error_context = other.error_context
        if other.enhanced_error_field:
            self.enhanced_error_field = other.enhanced_error_field.value()
        else:
            self.enhanced_error_field = None
        self.lazy_iterator = None  # Lazy iterators are not copyable

    @staticmethod
    fn struct(data: Dict[String, PLValue]) -> PLValue:
        var result = PLValue("struct", "")
        # result.struct_data = data
        return result

    @staticmethod
    fn list(data: List[PLValue]) -> PLValue:
        var result = PLValue("list", "")
        # result.list_data = data
        return result

    @staticmethod
    fn number(value: Int) -> PLValue:
        return PLValue("number", String(value))

    @staticmethod
    fn string(value: String) -> PLValue:
        return PLValue("string", value)

    @staticmethod
    fn lazy(var iterator: LazyIterator) -> PLValue:
        var result = PLValue("lazy", "iterator")
        result.lazy_iterator = iterator^
        return result

    @staticmethod
    fn bool(value: Bool) -> PLValue:
        return PLValue("boolean", String(value))

    @staticmethod
    fn error(message: String, context: String = "") -> PLValue:
        var result = PLValue("error", message)
        result.error_context = context
        return result

    @staticmethod
    fn enhanced_error(error: PLGrizzlyError) -> PLValue:
        var result = PLValue("error", error.message)
        result.enhanced_error_field = error
        result.error_context = error.context
        return result

    fn is_struct(self) -> Bool:
        return self.type == "struct"

    fn is_list(self) -> Bool:
        return self.type == "list"

    fn get_list(self) -> List[PLValue]:
        # TODO: Implement proper list storage
        return List[PLValue]()

    fn is_error(self) -> Bool:
        return self.type == "error"

    fn get_struct(self) -> Dict[String, PLValue]:
        if not self.is_struct():
            return Dict[String, PLValue]()
        # return self.struct_data.value()
        return Dict[String, PLValue]()

    fn get_enhanced_error(self) -> Optional[PLGrizzlyError]:
        """Get the enhanced error if available."""
        return self.enhanced_error_field

    fn is_truthy(self) raises -> Bool:
        if self.is_error():
            return False
        if self.type == "boolean":
            return self.value == "true"
        if self.type == "number":
            return atol(self.value) != 0
        if self.type == "string":
            return len(self.value) > 0
        return True

    fn __str__(self) raises -> String:
        if self.type == "error":
            if self.enhanced_error_field:
                return self.enhanced_error_field.value().__str__()
            else:
                var msg = "Error: " + self.value
                if self.error_context != "":
                    msg += " (" + self.error_context + ")"
                return msg
        elif self.type == "struct":
            return self.value

        elif self.type == "list":
            return "List(...)"

        else:
            return self.value

    fn equals(self, other: PLValue) -> Bool:
        return self.type == other.type and self.value == other.value

    fn greater_than(self, other: PLValue) raises -> Bool:
        if self.type == "number" and other.type == "number":
            return atol(self.value) > atol(other.value)
        return False

    fn less_than(self, other: PLValue) raises -> Bool:
        if self.type == "number" and other.type == "number":
            return atol(self.value) < atol(other.value)
        return False

    fn attempt_error_recovery(self, context: Dict[String, String]) raises -> Optional[PLValue]:
        """Attempt to recover from an enhanced error using recovery strategies."""
        if self.enhanced_error_field:
            from pl_grizzly_errors import ErrorRecovery
            return ErrorRecovery.attempt_recovery(self.enhanced_error_field.value(), context)
        return None

    fn can_recover_error(self) -> Bool:
        """Check if this error value can potentially be recovered from."""
        if self.enhanced_error_field:
            from pl_grizzly_errors import ErrorRecovery
            return ErrorRecovery.can_recover(self.enhanced_error_field.value())
        return False

    fn get_error_suggestions(self) -> List[String]:
        """Get recovery suggestions for this error value."""
        if self.enhanced_error_field:
            var error = self.enhanced_error_field.value()
            var suggestions = error.suggestions.copy()
            for i in range(len(error.recovery_suggestions)):
                suggestions.append(error.recovery_suggestions[i])
            return suggestions^
        return List[String]()

# Helper functions for operations
fn add_op(a: Int, b: Int) -> Int:
    return a + b

fn sub_op(a: Int, b: Int) -> Int:
    return a - b

fn mul_op(a: Int, b: Int) -> Int:
    return a * b

fn div_op(a: Int, b: Int) -> Int:
    return a // b

fn eq_op(a: Int, b: Int) -> Bool:
    return a == b

fn neq_op(a: Int, b: Int) -> Bool:
    return a != b

fn gt_op(a: Int, b: Int) -> Bool:
    return a > b

fn lt_op(a: Int, b: Int) -> Bool:
    return a < b

fn gte_op(a: Int, b: Int) -> Bool:
    return a >= b

fn lte_op(a: Int, b: Int) -> Bool:
    return a <= b