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

# Profiling manager
struct ProfilingManager:
    var execution_counts: Dict[String, Int]
    var jit_compiled_functions: Dict[String, String]
    var profiling_enabled: Bool
    
    fn __init__(out self):
        self.execution_counts = Dict[String, Int]()
        self.jit_compiled_functions = Dict[String, String]()
        self.profiling_enabled = False
    
    fn enable_profiling(mut self):
        self.profiling_enabled = True
    
    fn disable_profiling(mut self):
        self.profiling_enabled = False
        self.execution_counts = Dict[String, Int]()
        self.jit_compiled_functions = Dict[String, String]()
    
    fn record_function_call(mut self, func_name: String):
        if self.profiling_enabled:
            var current_count = self.execution_counts.get(func_name, 0)
            self.execution_counts[func_name] = current_count + 1
    
    fn should_jit_compile(self, func_name: String) -> Bool:
        if func_name in self.jit_compiled_functions:
            return True
        var count = self.execution_counts.get(func_name, 0)
        return count >= 10
    
    fn add_jit_compilation(mut self, func_name: String, compiled_code: String):
        self.jit_compiled_functions[func_name] = compiled_code
    
    fn get_profile_stats(self) -> Dict[String, Int]:
        return self.execution_counts.copy()
    
    fn get_jit_stats(self) -> Dict[String, String]:
        return self.jit_compiled_functions.copy()

# Environment for variables
struct Environment(Copyable, Movable, ImplicitlyCopyable):
    var values: Dict[String, PLValue]

    fn __init__(out self):
        self.values = Dict[String, PLValue]()

    fn __copyinit__(out self, other: Environment):
        self.values = other.values.copy()

    fn define(mut self, name: String, value: PLValue):
        self.values[name] = value

    fn get(self, name: String) raises -> PLValue:
        if name in self.values:
            return self.values[name]
        # Error: undefined variable
        return "undefined"

    fn assign(mut self, name: String, value: PLValue):
        self.values[name] = value

# PL-GRIZZLY Interpreter with JIT capabilities
struct PLGrizzlyInterpreter:
    var schema_manager: SchemaManager
    var orc_storage: ORCStorage
    var profiler: ProfilingManager
    var global_env: Environment

    fn __init__(out self, storage: BlobStorage):
        self.schema_manager = SchemaManager(storage)
        self.orc_storage = ORCStorage(storage)
        self.profiler = ProfilingManager()
        self.global_env = Environment()

    fn enable_profiling(mut self):
        """Enable execution profiling."""
        self.profiler.enable_profiling()

    fn disable_profiling(mut self):
        """Disable execution profiling."""
        self.profiler.disable_profiling()

    fn get_profile_stats(self) -> Dict[String, Int]:
        """Get profiling statistics."""
        return self.profiler.get_profile_stats()

    fn get_jit_stats(self) -> Dict[String, String]:
        """Get JIT compilation statistics."""
        return self.profiler.get_jit_stats()

    fn clear_profile_stats(mut self):
        """Clear profiling statistics."""
        self.profiler.disable_profiling()

    fn jit_compile_function(mut self, func_name: String, func_def: String) raises -> Bool:
        """JIT compile a function if it's hot enough."""
        if self.profiler.should_jit_compile(func_name):
            return True  # Already compiled or not hot enough
        
        # Generate JIT code
        var compiled_code = self.generate_jit_code(func_def)
        self.profiler.add_jit_compilation(func_name, compiled_code)
        return True

    fn generate_jit_code(self, func_def: String) -> String:
        """Generate JIT compiled code for a function."""
        # Parse function definition
        var parts = func_def.split(":")
        if len(parts) < 4:
            return ""
        
        var name = String(parts[1])
        var params_str = String(parts[2])
        var body = String(parts[3])
        
        # Generate optimized code
        var jit_code = "jit_fn " + name + "(" + params_str + ") {\n"
        jit_code += "  return " + self.optimize_expression(String(body)) + ";\n"
        jit_code += "}"
        
        return jit_code

    fn optimize_expression(self, expr: String) -> String:
        """Optimize an expression for JIT compilation."""
        # Simple optimizations
        if expr.startswith("(") and expr.endswith(")"):
            var content = String(expr[1:expr.__len__() - 1].strip())
            var parts = self.split_expression(content)
            if len(parts) >= 3:
                var op = parts[0]
                if op == "+":
                    return "(" + parts[1] + " + " + parts[2] + ")"
                elif op == "-":
                    return "(" + parts[1] + " - " + parts[2] + ")"
                elif op == "*":
                    return "(" + parts[1] + " * " + parts[2] + ")"
                elif op == "/":
                    return "(" + parts[1] + " / " + parts[2] + ")"
        return expr

    fn execute_jit_function(self, func_name: String, args: List[String]) raises -> PLValue:
        """Execute a JIT compiled function."""
        var jit_stats = self.profiler.get_jit_stats()
        if func_name not in jit_stats:
            return "jit_error: function not compiled"
        
        # For now, simulate JIT execution by evaluating optimized code
        var jit_code = ""
        try:
            jit_code = jit_stats[func_name]
        except:
            return "jit_error: function not compiled"
        print("Executing JIT code:", jit_code)
        
        # Simple simulation: just return a mock result
        return "jit_result: " + func_name + " executed with " + String(len(args)) + " args"

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

    fn interpret(mut self, source: String) raises -> String:
        """Interpret PL-GRIZZLY source code with JIT capabilities."""
        
        var ast = source  # PL-GRIZZLY code is already AST-like
        var errors = self.analyze(ast)
        if len(errors) > 0:
            var error_str = "semantic errors: "
            for error in errors:
                error_str += error + "; "
            return error_str
        
        # Check if this is a function call for profiling
        if ast.startswith("(call ") and self.profiler.profiling_enabled:
            var call_parts = ast[6:ast.__len__() - 1].split(" ")
            if len(call_parts) >= 1:
                var func_name = String(call_parts[0])
                self.profiler.record_function_call(func_name)
                # Check if we should JIT compile this function
                if not (func_name in self.profiler.get_jit_stats()) and self.profiler.should_jit_compile(func_name):
                    var func_def = self.global_env.get(func_name)
                    if func_def.startswith("function:"):
                        _ = self.jit_compile_function(func_name, func_def)
        
        var result = self.evaluate(ast, self.global_env)
        if result.startswith("function:"):
            # Store the function and check for JIT compilation
            var parts_def = result.split(":")
            if len(parts_def) >= 2:
                var name = String(parts_def[1])
                self.global_env.define(name, result)
                # JIT compilation happens during function calls, not definition
                return "function " + name + " defined"
        return result

    fn evaluate_list(self, content: String, env: Environment) raises -> PLValue:
        """Evaluate a list expression like '+ 1 2'."""
        var parts = self.split_expression(String(content))
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
            # Check if JIT compiled version exists
            var jit_stats = self.profiler.get_jit_stats()
            if func_name in jit_stats:
                return self.execute_jit_function(func_name, args)
            
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
        # Parse name(params) => body
        # For now, simple parse
        var func_str = content.strip()
        if func_str.startswith("FUNCTION "):
            func_str = func_str[9:].strip()
        var arrow_pos = func_str.find(" => ")
        if arrow_pos == -1:
            return "error: no body"
        var name_and_params = func_str[:arrow_pos]
        var body = func_str[arrow_pos + 4:].strip()
        # Parse name and params
        var paren_pos = name_and_params.find("(")
        if paren_pos == -1:
            return "error: no params"
        var name = name_and_params[:paren_pos].strip()
        var params_str = name_and_params[paren_pos:]
        if not (params_str.startswith("(") and params_str.endswith(")")):
            return "error: invalid params"
        var params = params_str[1:params_str.__len__() - 1].strip().split(" ")
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
        return func_value
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
            var parts = self.split_expression(String(content))
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