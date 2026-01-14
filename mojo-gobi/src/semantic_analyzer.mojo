"""
PL-GRIZZLY Semantic Analyzer

This module provides basic semantic analysis for PL-GRIZZLY programs,
including type checking and symbol validation.
"""

from collections import Dict, List
from pl_grizzly_parser import ASTNode, TypeChecker, SymbolTable
from pl_grizzly_values import PLValue

# Semantic Analysis Result
struct SemanticAnalysisResult(Movable):
    var errors: List[String]
    var warnings: List[String]
    var is_valid: Bool

    fn __init__(out self):
        self.errors = List[String]()
        self.warnings = List[String]()
        self.is_valid = True

    fn add_error(mut self, error: String):
        self.errors.append(error)
        self.is_valid = False

    fn add_warning(mut self, warning: String):
        self.warnings.append(warning)

# Basic Semantic Analyzer
struct SemanticAnalyzer:
    var type_checker: TypeChecker
    var symbol_table: SymbolTable

    fn __init__(out self):
        self.type_checker = TypeChecker()
        self.symbol_table = SymbolTable()

    fn analyze(mut self, ast: ASTNode) raises -> SemanticAnalysisResult:
        """Perform basic semantic analysis on an AST."""
        var result = SemanticAnalysisResult()

        try:
            self.analyze_node(ast, result)
        except e:
            result.add_error("Semantic analysis failed: " + String(e))

        return result^

    fn analyze_node(mut self, node: ASTNode, mut result: SemanticAnalysisResult) raises:
        """Analyze a single AST node."""
        if node.node_type == "SELECT":
            self.analyze_select(node, result)
        elif node.node_type == "CREATE_FUNCTION":
            self.analyze_function_definition(node, result)
        elif node.node_type == "FUNCTION_CALL":
            self.analyze_function_call(node, result)
        elif node.node_type == "BINARY_OP":
            self.analyze_binary_op(node, result)

        # Recursively analyze children
        for i in range(len(node.children)):
            self.analyze_node(node.children[i], result)

    fn analyze_select(mut self, node: ASTNode, mut result: SemanticAnalysisResult) raises:
        """Analyze a SELECT statement."""
        # Check WHERE clause for type consistency
        for i in range(len(node.children)):
            if node.children[i].node_type == "WHERE":
                # WHERE should contain a condition
                if len(node.children[i].children) > 0:
                    var cond_type = self.type_checker.infer_type(node.children[i].children[0], self.symbol_table)
                    if cond_type != "boolean" and cond_type != "unknown":
                        result.add_error("WHERE clause must evaluate to boolean type, got: " + cond_type)

    fn analyze_function_definition(mut self, node: ASTNode, mut result: SemanticAnalysisResult) raises:
        """Analyze a function definition."""
        var func_name = node.get_attribute("name")
        var return_type = node.get_attribute("return_type")

        if func_name == "":
            result.add_error("Function definition missing name")
            return

        if return_type == "":
            result.add_warning("Function '" + func_name + "' has no explicit return type")

        # Check for duplicate parameters (basic check)
        var param_names = List[String]()
        for i in range(len(node.children)):
            if node.children[i].node_type == "PARAMETER":
                var param_name = node.children[i].get_attribute("name")
                if param_name != "":
                    for j in range(len(param_names)):
                        if param_names[j] == param_name:
                            result.add_error("Duplicate parameter name: " + param_name)
                            break
                    param_names.append(param_name)

    fn analyze_function_call(mut self, node: ASTNode, mut result: SemanticAnalysisResult) raises:
        """Analyze a function call."""
        var func_name = node.get_attribute("name")

        if func_name == "":
            result.add_error("Function call missing function name")
            return

        # Check if it's a known built-in function
        if func_name == "print" or func_name == "sum" or func_name == "avg" or func_name == "count":
            # These are valid
            pass
        else:
            result.add_warning("Unknown function '" + func_name + "' - not in built-in list")

    fn analyze_binary_op(mut self, node: ASTNode, mut result: SemanticAnalysisResult) raises:
        """Analyze a binary operation."""
        if len(node.children) >= 2:
            var left_type = self.type_checker.infer_type(node.children[0], self.symbol_table)
            var right_type = self.type_checker.infer_type(node.children[1], self.symbol_table)
            var op = node.value

            # Basic type checking for arithmetic operations
            if op == "+" or op == "-" or op == "*" or op == "/":
                if left_type == "string" or right_type == "string":
                    # String concatenation is allowed
                    pass
                elif left_type != right_type and left_type != "unknown" and right_type != "unknown":
                    result.add_warning("Type mismatch in " + op + " operation: " + left_type + " vs " + right_type)

            # Comparison operations should return boolean
            elif op == "==" or op == "!=" or op == "<" or op == ">" or op == "<=" or op == ">=":
                # Result should be boolean, but we can't check the result type here
                pass