"""
PL-GRIZZLY Value Types Module

Core value types and operations for PL-GRIZZLY expressions.
"""

from collections import Dict, List
from pl_grizzly_environment import Environment
from pl_grizzly_errors import PLGrizzlyError, ErrorManager

# Value types for PL-GRIZZLY
struct PLValue(Copyable, Movable, ImplicitlyCopyable):
    var type: String
    var value: String
    var closure_env: Optional[Environment]
    var error_context: String
    var enhanced_error_field: Optional[PLGrizzlyError]
    # var struct_data: Optional[Dict[String, PLValue]]
    # var list_data: Optional[List[PLValue]]

    fn __init__(out self, type: String = "string", value: String = ""):
        self.type = type
        self.value = value
        self.closure_env = None
        self.error_context = ""
        self.enhanced_error_field = None

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
            return "Struct(...)"

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