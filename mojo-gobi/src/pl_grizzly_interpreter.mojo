"""
PL-GRIZZLY Interpreter Implementation

This module provides interpretation and execution capabilities for the PL-GRIZZLY programming language,
evaluating parsed ASTs in the context of the Godi database.
"""

from collections import Dict, List
from pl_grizzly_parser import PLGrizzlyParser
from pl_grizzly_lexer import PLGrizzlyLexer
from schema_manager import SchemaManager
from blob_storage import BlobStorage
from orc_storage import ORCStorage

# Value types for PL-GRIZZLY
alias PLValue = String

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

# Environment for variables
struct Environment:
    var values: Dict[String, PLValue]

    fn __init__(out self):
        self.values = Dict[String, PLValue]()

    fn define(mut self, name: String, value: PLValue):
        self.values[name] = value

    fn get(self, name: String) raises -> PLValue:
        if name in self.values:
            return self.values[name]
        # Error: undefined variable
        return "undefined"

    fn assign(mut self, name: String, value: PLValue):
        if name in self.values:
            self.values[name] = value
        else:
            # Error: undefined variable
            pass

# PL-GRIZZLY Interpreter
struct PLGrizzlyInterpreter:
    var global_env: Environment
    var schema_manager: SchemaManager
    var orc_storage: ORCStorage

    fn __init__(out self, storage: BlobStorage):
        self.global_env = Environment()
        self.schema_manager = SchemaManager(storage)
        self.orc_storage = ORCStorage(storage)

    fn interpret(mut self, source: String) raises -> String:
        """Interpret PL-GRIZZLY source code."""
        var lexer = PLGrizzlyLexer(source)
        var tokens = lexer.tokenize()
        var parser = PLGrizzlyParser(tokens)
        var ast = parser.parse()
        var errors = self.analyze(ast)
        if len(errors) > 0:
            var error_str = "semantic errors: "
            for error in errors:
                error_str += error + "; "
            return error_str
        var result = self.evaluate(ast, self.global_env)
        if result.startswith("function:"):
            # Store the function
            var parts_def = result.split(":")
            if len(parts_def) >= 2:
                var name = String(parts_def[1])
                self.global_env.define(name, result)
                return "function " + name + " defined"
        return result

    fn evaluate(self, expr: String, env: Environment) raises -> PLValue:
        """Evaluate an expression in the given environment."""
        if expr == "":
            return "empty"
        
        # Parse the string AST
        if expr.startswith("(") and expr.endswith(")"):
            return self.evaluate_list(String(expr[1:expr.__len__() - 1].strip()), env)
        elif expr.startswith("{ ") and expr.endswith(" }"):
            # Variable reference
            var var_name = String(expr[2:expr.__len__() - 2].strip())
            return env.get(var_name)
        elif expr == "true":
            return "true"
        elif expr == "false":
            return "false"
        elif expr.isdigit():
            return expr
        else:
            # Try as number first
            try:
                _ = Int(expr)
                return expr
            except:
                # Identifier or string
                if expr.startswith("\"") and expr.endswith("\""):
                    return expr[1:expr.__len__() - 1]
                else:
                    # Identifier
                    return env.get(expr)

    fn evaluate_list(self, content: String, env: Environment) raises -> PLValue:
        """Evaluate a list expression like '+ 1 2'."""
        var parts = self.split_expression(content)
        if len(parts) == 0:
            return "empty"
        
        var op = parts[0]
        if op == "+":
            return self.eval_binary_op(parts, env, add_op)
        elif op == "-":
            return self.eval_binary_op(parts, env, sub_op)
        elif op == "*":
            return self.eval_binary_op(parts, env, mul_op)
        elif op == "/":
            return self.eval_binary_op(parts, env, div_op)
        elif op == "==":
            return self.eval_comparison_op(parts, env, eq_op)
        elif op == "!=":
            return self.eval_comparison_op(parts, env, neq_op)
        elif op == ">":
            return self.eval_comparison_op(parts, env, gt_op)
        elif op == "<":
            return self.eval_comparison_op(parts, env, lt_op)
        elif op == ">=":
            return self.eval_comparison_op(parts, env, gte_op)
        elif op == "<=":
            return self.eval_comparison_op(parts, env, lte_op)
        elif op == "call":
            return self.eval_call(parts, env)
        elif op == "|>":
            return self.eval_pipe(parts, env)
        elif op == "SELECT":
            return self.eval_select(content, env)
        elif op == "FUNCTION":
            return self.eval_function(content, env)
        else:
            return "unknown op: " + op

    fn split_expression(self, content: String) -> List[String]:
        """Split expression content into parts, handling nested parens."""
        var parts = List[String]()
        var current = ""
        var paren_depth = 0
        
        for c in content:
            if c == " " and paren_depth == 0:
                if current != "":
                    parts.append(current)
                    current = ""
            elif c == "(":
                paren_depth += 1
                current += c
            elif c == ")":
                paren_depth -= 1
                current += c
            else:
                current += c
        
        if current != "":
            parts.append(current)
        
        return parts.copy()

    fn eval_binary_op(self, parts: List[String], env: Environment, op_fn: fn(Int, Int) -> Int) raises -> PLValue:
        if len(parts) < 3:
            return "error: not enough args"
        var left = self.evaluate(parts[1], env)
        var right = self.evaluate(parts[2], env)
        # Parse as Int
        try:
            var left_val = Int(left)
            var right_val = Int(right)
            return String(op_fn(left_val, right_val))
        except:
            return "error: type mismatch"

    fn eval_comparison_op(self, parts: List[String], env: Environment, op_fn: fn(Int, Int) -> Bool) raises -> PLValue:
        if len(parts) < 3:
            return "error: not enough args"
        var left = self.evaluate(parts[1], env)
        var right = self.evaluate(parts[2], env)
        # Parse as Int
        try:
            var left_val = Int(left)
            var right_val = Int(right)
            var result = op_fn(left_val, right_val)
            return "true" if result else "false"
        except:
            return "error: type mismatch"

    fn eval_call(self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) < 2:
            return "error: call needs function"
        var func_name = parts[1]
        var args = List[String]()
        for i in range(2, len(parts)):
            args.append(self.evaluate(parts[i], env))
        # Check if function
        var func_def = env.get(func_name)
        if func_def.startswith("function:"):
            # Parse function
            var parts_def = func_def.split(":")
            if len(parts_def) < 4:
                return "error: invalid function"
            var name = parts_def[1]
            var params_str = parts_def[2]
            var body = parts_def[3]
            var params = params_str.split(",")
            if len(params) != len(args):
                return "error: arg count mismatch"
            # Create new env with params bound
            var new_env = Environment()
            for i in range(len(params)):
                new_env.define(String(params[i]), args[i])
            # Evaluate body in new env
            return self.evaluate(String(body), new_env)
        # For now, only support built-in functions
        if func_name == "print":
            # Print args
            for arg in args:
                print(arg)
            return "printed"
        else:
            return "unknown function: " + func_name

    fn eval_pipe(self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) < 3:
            return "error: pipe needs left and right"
        var left = self.evaluate(parts[1], env)
        # For pipe, the right should be a call, pass left as first arg
        var right_expr = parts[2]
        # Modify right_expr to include left as first arg
        if right_expr.startswith("(call "):
            var call_content = right_expr[6:right_expr.__len__() - 1]
            var new_call = "(call " + call_content.split(" ")[0] + " " + left + " " + " ".join(call_content.split(" ")[1:])
            return self.evaluate(new_call, env)
        else:
            return "error: pipe right must be call"

    fn eval_select(self, content: String, env: Environment) raises -> PLValue:
        # Parse SELECT from: {table} where: condition
        # For now, return mock result
        return "SELECT result from " + content

    fn eval_function(self, content: String, env: Environment) raises -> PLValue:
        # Parse FUNCTION name(params) => body
        # For now, simple parse
        var func_str = content.strip()
        if not func_str.startswith("FUNCTION "):
            return "error: not a function"
        var after_func = func_str[9:].strip()
        var paren_pos = after_func.find("(")
        if paren_pos == -1:
            return "error: no params"
        var name = after_func[:paren_pos].strip()
        var after_name = after_func[paren_pos:]
        var arrow_pos = after_name.find(" => ")
        if arrow_pos == -1:
            return "error: no body"
        var params_str = after_name[:arrow_pos]
        var body = after_name[arrow_pos + 4:].strip()
        # Parse params
        if not (params_str.startswith("(") and params_str.endswith(")")):
            return "error: invalid params"
        var params = params_str[1:params_str.__len__() - 1].split(",")
        var param_list = List[String]()
        for p in params:
            param_list.append(String(p.strip()))
        # Store as function:name:param1,param2:...:body
        var func_value = "function:" + name + ":"
        for i in range(len(param_list)):
            if i > 0:
                func_value += ","
            func_value += param_list[i]
        func_value += ":" + body
        # But since env is passed by value, can't modify global
        # For now, return the func_value, but actually need to store in global_env
        # Since interpret has mut self, I can modify self.global_env
        # But since evaluate is not mut, I can't.
        # Problem.
        # To fix, make evaluate mut self again, but earlier it had aliasing issue.
        # Perhaps make the env &mut Environment or something.
        # For now, since it's simple, let's assume functions are global, and store in global_env.
        # But since evaluate takes env by value, to modify, I need to pass by reference.
        # Let's change back to mut self for evaluate, and see if the aliasing is fixed by not modifying self in evaluate.
        # Since evaluate doesn't modify self, only calls other methods that don't modify self.
        # The eval_ methods don't modify self.
        # So, the aliasing was because evaluate is mut self, but since it doesn't modify self, perhaps the compiler is wrong.
        # Let me try making evaluate mut self again.
        # Earlier I removed mut to fix aliasing.
        # But if I make it mut self, and don't modify self, perhaps it works.
        # Let's try. 

        # For now, return func_value, and in interpret, if result starts with "function:", store it.
        return func_value

    fn analyze(self, ast: String) -> List[String]:
        """Analyze AST for semantic errors."""
        var errors = List[String]()
        if ast.startswith("(") and ast.endswith(")"):
            var content = String(ast[1:ast.__len__() - 1].strip())
            var parts = self.split_expression(content)
            if len(parts) > 0:
                var op = parts[0]
                if op == "+" or op == "-" or op == "*" or op == "/":
                    for i in range(1, len(parts)):
                        if not self.is_numeric(parts[i]):
                            errors.append("argument " + String(i) + " to " + op + " is not numeric")
                elif op == "==" or op == "!=" or op == ">" or op == "<" or op == ">=" or op == "<=":
                    if len(parts) != 3:
                        errors.append(op + " requires exactly 2 arguments")
        return errors.copy()

    fn is_numeric(self, s: String) -> Bool:
        """Check if string is numeric."""
        try:
            _ = Int(s)
            return True
        except:
            return False