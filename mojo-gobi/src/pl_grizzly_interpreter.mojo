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
struct PLValue(Copyable, Movable, ImplicitlyCopyable):
    var type: String
    var value: String
    var closure_env: Optional[Environment]

    fn __init__(out self, type: String = "string", value: String = ""):
        self.type = type
        self.value = value
        self.closure_env = None

    fn __copyinit__(out self, other: PLValue):
        self.type = other.type
        self.value = other.value
        if other.closure_env:
            self.closure_env = other.closure_env.value().copy()
        else:
            self.closure_env = None

    # @staticmethod
    # fn struct(data: Dict[String, PLValue]) -> PLValue:
    #     var result = PLValue("struct", "")
    #     result.struct_data = data.copy()
    #     return result

    # @staticmethod
    # fn list(data: List[PLValue]) -> PLValue:
    #     var result = PLValue("list", "")
    #     result.list_data = data.copy()
    #     return result

    @staticmethod
    fn number(value: Int) -> PLValue:
        return PLValue("number", String(value))

    @staticmethod
    fn string(value: String) -> PLValue:
        return PLValue("string", value)

    @staticmethod
    fn bool(value: Bool) -> PLValue:
        return PLValue("bool", "true" if value else "false")

    @staticmethod
    fn error(message: String) -> PLValue:
        return PLValue("error", message)

    # fn is_struct(self) -> Bool:
    #     return self.type == "struct" and self.struct_data

    # fn is_list(self) -> Bool:
    #     return self.type == "list" and self.list_data

    fn is_error(self) -> Bool:
        return self.type == "error"

    # fn get_struct(self) -> Dict[String, PLValue]:
    #     if self.struct_data:
    #         return self.struct_data.value().copy()
    #     return Dict[String, PLValue]()

    # fn get_list(self) -> List[PLValue]:
    #     if self.list_data:
    #         return self.list_data.value().copy()
    #     return List[PLValue]()

    fn is_truthy(self) -> Bool:
        if self.is_error():
            return False
        if self.type == "bool":
            return self.value == "true"
        if self.type == "number":
            return self.value != "0"
        if self.type == "string":
            return self.value != ""
        # if self.type == "list":
        #     return len(self.get_list()) > 0
        # if self.type == "struct":
        #     return len(self.get_struct()) > 0
        return True

    fn __str__(self) raises -> String:
        if self.type == "string":
            return self.value
        elif self.type == "number":
            return self.value
        elif self.type == "bool":
            return self.value
        # elif self.type == "struct":
        #     if self.struct_data:
        #         var s = "{"
        #         var first = True
        #         for key in self.struct_data.value().keys():
        #             if not first:
        #                 s += ", "
        #             try:
        #                 s += key + ": " + self.struct_data.value()[key].__str__()
        #             except:
        #                 s += key + ": <error>"
        #             first = False
        #         s += "}"
        #         return s
        #     return "{}"
        # elif self.type == "list":
        #     if self.list_data:
        #         var s = "["
        #         var first = True
        #         for item in self.list_data.value():
        #             if not first:
        #                 s += ", "
        #             try:
        #                 s += item.__str__()
        #             except:
        #                 s += "<error>"
        #             first = False
        #         s += "]"
        #         return s
        #     return "[]"
        else:
            return self.type + ":" + self.value

    fn equals(self, other: PLValue) -> Bool:
        if self.type != other.type:
            return False
        return self.value == other.value

    fn greater_than(self, other: PLValue) raises -> Bool:
        if self.type == "number" and other.type == "number":
            return Int(self.value) > Int(other.value)
        return False

    fn less_than(self, other: PLValue) raises -> Bool:
        if self.type == "number" and other.type == "number":
            return Int(self.value) < Int(other.value)
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
        return PLValue("error", "undefined variable: " + name)

    fn assign(mut self, name: String, value: PLValue):
        self.values[name] = value

# PL-GRIZZLY Interpreter with JIT capabilities
struct PLGrizzlyInterpreter:
    var schema_manager: SchemaManager
    var orc_storage: ORCStorage
    var profiler: ProfilingManager
    var global_env: Environment
    var modules: Dict[String, String]

    fn __init__(out self, storage: BlobStorage):
        self.schema_manager = SchemaManager(storage)
        self.orc_storage = ORCStorage(storage)
        self.profiler = ProfilingManager()
        self.global_env = Environment()
        self.modules = Dict[String, String]()
        self.modules["math"] = "FUNCTION add(a, b) => (+ a b) FUNCTION mul(a, b) => (* a b)"

    fn query_table(self, table_name: String) -> PLValue:
        """Query table data and return as list of structs."""
        var schema = self.schema_manager.load_schema()
        var table_schema = schema.get_table(table_name)
        if table_schema.name == "":
            return PLValue.error("table not found: " + table_name)
        
        var data = self.orc_storage.read_table(table_name)
        if len(data) == 0:
            return PLValue("list", "mock")
        
        var rows = List[PLValue]()
        for i in range(len(data)):
            var struct_dict = Dict[String, PLValue]()
            for j in range(len(table_schema.columns)):
                var col_name = table_schema.columns[j].name
                var col_value = data[i][j] if j < len(data[i]) else ""
                # Assume string for now, but could parse to number
                struct_dict[col_name] = PLValue.string(col_value)
        # return PLValue.list(rows)
        return PLValue("list", "mock")
        return PLValue("list", "mock")

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

    fn execute_jit_function(self, func_name: String, args: List[PLValue]) raises -> PLValue:
        """Execute a JIT compiled function."""
        var jit_stats = self.profiler.get_jit_stats()
        if func_name not in jit_stats:
            return PLValue("error", "jit_error: function not compiled")
        
        # For now, simulate JIT execution by evaluating optimized code
        var jit_code = ""
        try:
            jit_code = jit_stats[func_name]
        except:
            return PLValue("error", "jit_error: function not compiled")
        print("Executing JIT code:", jit_code)
        
        # Simple simulation: just return a mock result
        return PLValue("string", "jit_result: " + func_name + " executed with " + String(len(args)) + " args")

    fn evaluate(mut self, expr: String, env: Environment) raises -> PLValue:
        """Evaluate an expression in the given environment."""
        if expr == "":
            return PLValue("string", "empty")
        
        # Parse the string AST
        if expr.startswith("(") and expr.endswith(")"):
            return self.evaluate_list(String(expr[1:expr.__len__() - 1].strip()), env)
        elif expr.startswith("{ ") and expr.endswith(" }"):
            # Variable or table reference
            var var_name = String(expr[2:expr.__len__() - 2].strip())
            # Check if it's a table
            var schema = self.schema_manager.load_schema()
            var table_schema = schema.get_table(var_name)
            if table_schema.name != "":
                return self.query_table(var_name)
            else:
                return env.get(var_name)
        elif expr.startswith("{") and not expr.startswith("{ "):
            # Struct literal
            return PLValue("struct", expr)
        elif expr.startswith("["):
            # List literal
            return PLValue("list", expr)
        elif expr.startswith("EXCEPTION "):
            # Exception literal
            return PLValue("exception", expr[10:])
        elif expr.startswith("(TRY "):
            return self.eval_try(expr, env)
        elif expr.startswith("(INSERT "):
            return self.eval_insert(expr, env)
        # elif expr.startswith("(UPDATE "):
        #     return self.eval_update(expr, env)
        # elif expr.startswith("(DELETE "):
        #     return self.eval_delete(expr, env)
        elif expr.startswith("(IMPORT "):
            return self.eval_import(expr)
        elif expr.startswith("(MATCH "):
            return self.eval_match(expr, env)
        elif expr.startswith("(FOR "):
            return self.eval_for(expr, env)
        elif expr.startswith("(WHILE "):
            return self.eval_while(expr, env)
        elif expr == "true":
            return PLValue("bool", "true")
        elif expr == "false":
            return PLValue("bool", "false")
        elif expr.isdigit():
            return PLValue("number", expr)
        else:
            # Try as number first
            try:
                _ = Int(expr)
                return PLValue("number", expr)
            except:
                # Identifier or string
                if expr.startswith("\"") and expr.endswith("\""):
                    return PLValue("string", expr[1:expr.__len__() - 1])
                else:
                    # Identifier
                    return env.get(expr)

    fn interpret(mut self, source: String) raises -> PLValue:
        """Interpret PL-GRIZZLY source code with JIT capabilities."""
        
        var ast = source  # PL-GRIZZLY code is already AST-like
        var errors = self.analyze(ast)
        if len(errors) > 0:
            var error_str = "semantic errors: "
            for error in errors:
                error_str += error + "; "
            return PLValue("error", error_str)
        
        # Check if this is a function call for profiling
        if ast.startswith("(call ") and self.profiler.profiling_enabled:
            var call_parts = ast[6:ast.__len__() - 1].split(" ")
            if len(call_parts) >= 1:
                var func_name = String(call_parts[0])
                self.profiler.record_function_call(func_name)
                # Check if we should JIT compile this function
                if not (func_name in self.profiler.get_jit_stats()) and self.profiler.should_jit_compile(func_name):
                    var func_def = self.global_env.get(func_name)
                    if func_def.type == "function":
                        _ = self.jit_compile_function(func_name, func_def.value)
        
        var result = self.evaluate(ast, self.global_env.copy())
        if result.type == "function":
            # Store the function and check for JIT compilation
            var parts_def = result.value.split(":")
            if len(parts_def) >= 2:
                var name = String(parts_def[1])
                self.global_env.define(name, result)
                # JIT compilation happens during function calls, not definition
                return PLValue("string", "function " + name + " defined")
        return result

    fn evaluate_list(mut self, content: String, env: Environment) raises -> PLValue:
        """Evaluate a list expression like '+ 1 2'."""
        var parts = self.split_expression(String(content))
        if len(parts) == 0:
            return PLValue("error", "empty")
        
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
        elif op == "and":
            return self.eval_logical_and(parts, env)
        elif op == "or":
            return self.eval_logical_or(parts, env)
        elif op == "not":
            return self.eval_logical_not(parts, env)
        elif op == "!":
            return self.eval_logical_not(parts, env)
        elif op == "??":
            return self.eval_coalesce(parts, env)
        elif op == "as":
            return self.eval_cast(parts, env)
        elif op == "::":
            return self.eval_cast(parts, env)
        # elif op == "SELECT":
        #     return self.eval_select(content, env)
        elif op == "FUNCTION":
            return self.eval_function(content, env)
        else:
            return PLValue("error", "unknown op: " + op)

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

    fn eval_binary_op(mut self, parts: List[String], env: Environment, op: fn(Int, Int) -> Int) raises -> PLValue:
        if len(parts) < 3:
            return PLValue("error", "not enough args")
        var left = self.evaluate(parts[1], env)
        var right = self.evaluate(parts[2], env)
        # Check types
        if left.type != "number" or right.type != "number":
            return PLValue("error", "type mismatch")
        # Parse as Int
        try:
            var left_val = Int(left.value)
            var right_val = Int(right.value)
            return PLValue("number", String(op(left_val, right_val)))
        except:
            return PLValue("error", "invalid number")

    fn eval_comparison_op(mut self, parts: List[String], env: Environment, op: fn(Int, Int) -> Bool) raises -> PLValue:
        if len(parts) < 3:
            return PLValue("error", "not enough args")
        var left = self.evaluate(parts[1], env)
        var right = self.evaluate(parts[2], env)
        # Check types
        if left.type != "number" or right.type != "number":
            return PLValue("error", "type mismatch")
        # Parse as Int
        try:
            var left_val = Int(left.value)
            var right_val = Int(right.value)
            var result = op(left_val, right_val)
            return PLValue("bool", "true" if result else "false")
        except:
            return PLValue("error", "invalid number")

    fn eval_call(mut self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) < 2:
            return PLValue("error", "call needs function")
        var func_name = parts[1]
        
        var args = List[PLValue]()
        for i in range(2, len(parts)):
            args.append(self.evaluate(parts[i], env))
        # Check if function
        var func_def = env.get(func_name)
        if func_def.type == "function":
            # Check if JIT compiled version exists
            var jit_stats = self.profiler.get_jit_stats()
            if func_name in jit_stats:
                return self.execute_jit_function(func_name, args)
            
            # Parse function
            var parts_def = func_def.value.split(":")
            if len(parts_def) < 5:
                return PLValue("error", "invalid function")
            var name = parts_def[1]
            var receiver = String(parts_def[2])
            var params_str = String(parts_def[3])
            var body = String(parts_def[4])
            # Create new env with closure
            var new_env = Environment()
            if func_def.closure_env:
                new_env = func_def.closure_env.value().copy()
            if receiver != "":
                # receiver is var:type
                var receiver_parts = receiver.split(":")
                if len(receiver_parts) != 2:
                    return PLValue("error", "invalid receiver")
                var receiver_var = String(receiver_parts[0])
                if len(args) == 0:
                    return PLValue("error", "receiver function needs receiver arg")
                new_env.define(receiver_var, args[0])
                var params = params_str.split(",")
                if len(params) != len(args) - 1:
                    return PLValue("error", "arg count mismatch")
                for i in range(len(params)):
                    new_env.define(String(params[i]), args[i+1])
            else:
                var params = params_str.split(",")
                if len(params) != len(args):
                    return PLValue("error", "arg count mismatch")
                for i in range(len(params)):
                    new_env.define(String(params[i]), args[i])
            # Evaluate body in new env
            return self.evaluate(String(body), new_env)
        # For now, only support built-in functions
        if func_name == "print":
            # Print args
            for arg in args:
                print(arg.__str__())
            return PLValue("string", "printed")
        else:
            return PLValue("error", "unknown function: " + func_name)

    fn eval_pipe(mut self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) < 3:
            return PLValue("error", "pipe needs left and right")
        var left = self.evaluate(parts[1], env)
        # For pipe, the right should be a call, pass left as first arg
        var right_expr = parts[2]
        # Modify right_expr to include left as first arg
        if right_expr.startswith("(call "):
            var call_content = right_expr[6:right_expr.__len__() - 1]
            var new_call = "(call " + call_content.split(" ")[0] + " " + left.__str__() + " " + " ".join(call_content.split(" ")[1:])
            return self.evaluate(new_call, env)
        else:
            return PLValue("error", "pipe right must be call")

    fn eval_logical_and(mut self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) != 3:
            return PLValue.error("and requires 2 arguments")
        var left = self.evaluate(parts[1], env)
        if left.is_error() or not left.is_truthy():
            return left
        var right = self.evaluate(parts[2], env)
        return right

    fn eval_logical_or(mut self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) != 3:
            return PLValue.error("or requires 2 arguments")
        var left = self.evaluate(parts[1], env)
        if left.is_truthy():
            return left
        var right = self.evaluate(parts[2], env)
        return right

    fn eval_logical_not(mut self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) != 2:
            return PLValue.error("not requires 1 argument")
        var value = self.evaluate(parts[1], env)
        if value.is_error():
            return value
        return PLValue.bool(not value.is_truthy())

    fn eval_coalesce(mut self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) != 3:
            return PLValue.error("?? requires 2 arguments")
        var left = self.evaluate(parts[1], env)
        if left.is_truthy():
            return left
        var right = self.evaluate(parts[2], env)
        return right

    fn eval_cast(mut self, parts: List[String], env: Environment) raises -> PLValue:
        if len(parts) != 3:
            return PLValue.error("cast requires 2 arguments")
        var value = self.evaluate(parts[1], env)
        var type_name = parts[2]
        # For now, just return the value, as PL-GRIZZLY is dynamically typed
        return value

    fn eval_select(mut self, content: String, env: Environment) raises -> PLValue:
        # Parse SELECT from: {table} where: condition
        var where_pos = content.find(" where: ")
        if where_pos != -1:
            var from_part = content[6:where_pos]  # remove "from: "
            var where_part = content[where_pos + 8:]
            var table_data = self.evaluate(from_part, env)
            if table_data.type == "list":
                # TODO: Apply where condition to filter the list
                return table_data
            else:
                return PLValue("error", "from clause must be table")
        else:
            var from_part = content[6:]  # remove "from: "
            var table_data = self.evaluate(from_part, env)
            return table_data

    fn eval_try(mut self, content: String, env: Environment) raises -> PLValue:
        # Parse (TRY body CATCH handler)
        var try_part = content[5:]  # remove (TRY 
        var catch_pos = try_part.find(" CATCH ")
        if catch_pos == -1:
            return PLValue("error", "invalid try syntax")
        var try_body = try_part[:catch_pos]
        var catch_body = try_part[catch_pos + 7:]  # remove CATCH 
        catch_body = catch_body[:-1]  # remove )
        
        # Evaluate try body
        var result = self.evaluate(try_body, env)
        if result.type == "error":
            # Execute catch body
            return self.evaluate(catch_body, env)
        else:
            return result

    fn eval_insert(mut self, content: String, env: Environment) raises -> PLValue:
        # Parse (INSERT INTO table VALUES (val1, val2))
        var into_pos = content.find(" INTO ")
        var values_pos = content.find(" VALUES (")
        if into_pos == -1 or values_pos == -1:
            return PLValue("error", "invalid INSERT syntax")
        var table_name = content[into_pos + 7:values_pos]
        var values_str = content[values_pos + 9:content.__len__() - 2]  # remove ))
        var values = values_str.split(", ")
        var row = List[String]()
        for val in values:
            # Evaluate each value
            var val_result = self.evaluate(String(val.strip()), env)
            row.append(val_result.__str__())  # For now, use string representation
        var data = List[List[String]]()
        data.append(row.copy())
        var success = self.orc_storage.write_table(table_name, data)
        if success:
            return PLValue("string", "inserted into " + table_name)
        else:
            return PLValue("error", "insert failed")

    fn eval_update(mut self, expr: String, env: Environment) raises -> PLValue:
        return PLValue("error", "update not implemented")

    fn eval_delete(mut self, expr: String, env: Environment) raises -> PLValue:
        return PLValue("error", "delete not implemented")
    fn eval_import(mut self, expr: String) raises -> PLValue:
        # Parse (IMPORT module_name)
        var module_name = expr[8:expr.__len__() - 1].strip()
        
        # Check if module exists in self.modules
        if String(module_name) in self.modules:
            var module_code = self.modules[String(module_name)]
            # Parse and add functions to global_env
            var functions = module_code.split("FUNCTION ")
            for i in range(1, len(functions)):  # Skip first empty
                var func_str = "FUNCTION " + functions[i].strip()
                var func_value = self.eval_function(func_str, self.global_env.copy())
                if func_value.type == "function":
                    var parts = func_value.value.split(":")
                    if len(parts) >= 2:
                        var func_name = String(parts[1])
                        self.global_env.assign(func_name, func_value)
            return PLValue.string("imported " + String(module_name))
        else:
            return PLValue.error("module '" + String(module_name) + "' not found")

    fn eval_condition(mut self, condition: String, row: PLValue, env: Environment) raises -> Bool:
        # Simple condition evaluation for WHERE clauses
        # For now, support column == value, column > value, etc.
        # Assume condition like "id == 1" or "name == 'john'"
        
        # Find the operator
        var eq_pos = condition.find(" == ")
        var neq_pos = condition.find(" != ")
        var gt_pos = condition.find(" > ")
        var lt_pos = condition.find(" < ")
        var gte_pos = condition.find(" >= ")
        var lte_pos = condition.find(" <= ")
        
        var op = ""
        var op_pos = -1
        if eq_pos != -1:
            op = "=="
            op_pos = eq_pos
        elif neq_pos != -1:
            op = "!="
            op_pos = neq_pos
        elif gte_pos != -1:
            op = ">="
            op_pos = gte_pos
        elif lte_pos != -1:
            op = "<="
            op_pos = lte_pos
        elif gt_pos != -1:
            op = ">"
            op_pos = gt_pos
        elif lt_pos != -1:
            op = "<"
            op_pos = lt_pos
        
        if op_pos == -1:
            return False
            
        var left = condition[:op_pos].strip()
        var right_str = condition[op_pos + len(op) + 2:].strip()
        
        # Get value from row
        # if row.is_struct():
        #     var struct_val = row.get_struct()
        #     if String(left) in struct_val:
        #             var left_val = struct_val[String(left)]
        #             var right_val = self.evaluate(String(right_str), env)
                    
        #             if op == "==":
        #                 return left_val.equals(right_val)
        #             elif op == "!=":
        #                 return not left_val.equals(right_val)
        #             elif op == ">":
        #                 return left_val.greater_than(right_val)
        #             elif op == "<":
        #                 return left_val.less_than(right_val)
        #             elif op == ">=":
        #                 return left_val.greater_than(right_val) or left_val.equals(right_val)
        #             elif op == "<=":
        #                 return left_val.less_than(right_val) or left_val.equals(right_val)
        return False

    fn eval_function(mut self, content: String, env: Environment) raises -> PLValue:
        # Parse (FUNCTION name [receiver](params) { body })
        var func_str: String = String(content.strip())
        if func_str.startswith("(FUNCTION "):
            func_str = String(func_str[10:].strip())
        if not func_str.endswith(")"):
            return PLValue("error", "error: invalid function")
        func_str = String(func_str[:-1].strip())  # remove )
        
        # Find name
        var space_pos = func_str.find(" ")
        if space_pos == -1:
            return PLValue("error", "error: no name")
        var name = String(func_str[:space_pos].strip())
        func_str = String(func_str[space_pos + 1:].strip())
        
        var remaining = func_str
        if func_str.startswith("["):
            var bracket_end = func_str.find("]")
            if bracket_end == -1:
                return PLValue("error", "error: invalid receiver")
            receiver = String(func_str[1:bracket_end].strip())
            remaining = String(func_str[bracket_end + 1:].strip())
        
        if not remaining.startswith("("):
            return PLValue("error", "error: no params")
        var paren_end = remaining.find(")")
        if paren_end == -1:
            return PLValue("error", "error: invalid params")
        var params_str = String(remaining[1:paren_end].strip())
        var after_params = String(remaining[paren_end + 1:].strip())
        
        var params = params_str.split(", ")
        var param_list = List[String]()
        for p in params:
            var ps = String(p.strip())
            if ps != "":
                param_list.append(ps)
        
        if not after_params.startswith("{ "):
            return PLValue("error", "error: no body")
        if not after_params.endswith(" }"):
            return PLValue("error", "error: invalid body")
        var body = String(after_params[2:after_params.__len__() - 2].strip())
        
        # Store as function:name:receiver:param1,param2:...:body
        var func_value = "function:" + name + ":" + receiver + ":"
        for i in range(len(param_list)):
            if i > 0:
                func_value += ","
            func_value += param_list[i]
        func_value += ":" + body
        var result = PLValue("function", func_value)
        result.closure_env = env
        return result
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
        return PLValue("string", func_value)

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

    fn eval_match(mut self, expr: String, env: Environment) raises -> PLValue:
        # Parse (MATCH match_expr { case pattern => body ... })
        var content = expr[7:expr.__len__() - 2].strip()  # remove (MATCH  })
        var brace_pos = content.find(" {")
        if brace_pos == -1:
            return PLValue("error", "invalid match")
        var match_expr_str = content[:brace_pos].strip()
        var cases_str = content[brace_pos + 2:].strip()
        var match_val = self.evaluate(match_expr_str, env)
        var cases = cases_str.split(" case ")
        for i in range(1, len(cases)):  # skip first empty
            var case = cases[i].strip()
            var arrow_pos = case.find(" => ")
            if arrow_pos == -1:
                continue
            var pattern_str = case[:arrow_pos].strip()
            var body_str = case[arrow_pos + 4:].strip()
            var pattern_val = self.evaluate(pattern_str, env)
            if match_val.value == pattern_val.value:  # simple equality
                return self.evaluate(body_str, env)
        return PLValue("error", "no match")

    fn eval_for(mut self, expr: String, env: Environment) raises -> PLValue:
        # Parse (FOR var IN collection { body })
        var content = expr[5:expr.__len__() - 2].strip()  # remove (FOR  })
        var in_pos = content.find(" IN ")
        if in_pos == -1:
            return PLValue("error", "invalid for")
        var var_name = content[:in_pos].strip()
        var rest = content[in_pos + 4:].strip()
        var brace_pos = rest.find(" { ")
        if brace_pos == -1:
            return PLValue("error", "invalid for")
        var collection_str = rest[:brace_pos].strip()
        var body_str = rest[brace_pos + 3:].strip()
        var collection = self.evaluate(collection_str, env)
        if collection.type == "list":
            # Assume list is comma separated
            var items = collection.value.split(",")
            for item in items:
                var item_val = PLValue("string", String(item.strip()))
                var new_env = Environment()
                new_env.values = env.values.copy()
                new_env.define(var_name, item_val)
                _ = self.evaluate(body_str, new_env)  # ignore result
        return PLValue("string", "for completed")

    fn eval_while(mut self, expr: String, env: Environment) raises -> PLValue:
        # Parse (WHILE condition { body })
        var content = expr[7:expr.__len__() - 2].strip()  # remove (WHILE  })
        var brace_pos = content.find(" { ")
        if brace_pos == -1:
            return PLValue("error", "invalid while")
        var condition_str = content[:brace_pos].strip()
        var body_str = content[brace_pos + 3:].strip()
        while True:
            var cond = self.evaluate(condition_str, env)
            if cond.type != "bool" or cond.value != "true":
                break
            _ = self.evaluate(body_str, env)
        return PLValue("string", "while completed")

    fn is_numeric(self, s: String) -> Bool:
        """Check if string is numeric."""
        try:
            _ = Int(s)
            return True
        except:
            return False