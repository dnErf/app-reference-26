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
    var struct_data: Optional[Dict[String, PLValue]]
    var list_data: Optional[List[PLValue]]

    fn __init__(out self, type: String = "string", value: String = ""):
        self.type = type
        self.value = value
        self.struct_data = None
        self.list_data = None

    fn __copyinit__(out self, other: PLValue):
        self.type = other.type
        self.value = other.value
        if other.struct_data:
            self.struct_data = other.struct_data.value().copy()
        else:
            self.struct_data = None
        if other.list_data:
            self.list_data = other.list_data.value().copy()
        else:
            self.list_data = None

    @staticmethod
    fn struct(data: Dict[String, PLValue]) -> PLValue:
        var result = PLValue("struct", "")
        result.struct_data = data
        return result

    @staticmethod
    fn list(data: List[PLValue]) -> PLValue:
        var result = PLValue("list", "")
        result.list_data = data
        return result

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

    fn is_struct(self) -> Bool:
        return self.type == "struct" and self.struct_data

    fn is_list(self) -> Bool:
        return self.type == "list" and self.list_data

    fn is_error(self) -> Bool:
        return self.type == "error"

    fn get_struct(self) -> Dict[String, PLValue]:
        if self.struct_data:
            return self.struct_data.value()
        return Dict[String, PLValue]()

    fn get_list(self) -> List[PLValue]:
        if self.list_data:
            return self.list_data.value()
        return List[PLValue]()

    fn __str__(self) -> String:
        if self.type == "string":
            return self.value
        elif self.type == "number":
            return self.value
        elif self.type == "bool":
            return self.value
        elif self.type == "struct":
            if self.struct_data:
                var s = "{"
                var first = True
                for key in self.struct_data.value().keys():
                    if not first:
                        s += ", "
                    s += key + ": " + self.struct_data.value()[key].__str__()
                    first = False
                s += "}"
                return s
            return "{}"
        elif self.type == "list":
            if self.list_data:
                var s = "["
                var first = True
                for item in self.list_data.value():
                    if not first:
                        s += ", "
                    s += item.__str__()
                    first = False
                s += "]"
                return s
            return "[]"
        else:
            return self.type + ":" + self.value

    fn equals(self, other: PLValue) -> Bool:
        if self.type != other.type:
            return False
        return self.value == other.value

    fn greater_than(self, other: PLValue) -> Bool:
        if self.type == "number" and other.type == "number":
            return Int(self.value) > Int(other.value)
        return False

    fn less_than(self, other: PLValue) -> Bool:
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
            return PLValue.list(List[PLValue]())
        
        var rows = List[PLValue]()
        for i in range(len(data)):
            var struct_dict = Dict[String, PLValue]()
            for j in range(len(table_schema.columns)):
                var col_name = table_schema.columns[j].name
                var col_value = data[i][j] if j < len(data[i]) else ""
                # Assume string for now, but could parse to number
                struct_dict[col_name] = PLValue.string(col_value)
            rows.append(PLValue.struct(struct_dict))
        return PLValue.list(rows)

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
        elif expr.startswith("(UPDATE "):
            return self.eval_update(expr, env)
        elif expr.startswith("(DELETE "):
            return self.eval_delete(expr, env)
        elif expr.startswith("(IMPORT "):
            return self.eval_import(expr)
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
                    if func_def.type == "string" and func_def.value.startswith("function:"):
                        _ = self.jit_compile_function(func_name, func_def.value)
        
        var result = self.evaluate(ast, self.global_env.copy())
        if result.type == "string" and result.value.startswith("function:"):
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
        elif op == "SELECT":
            return self.eval_select(content, env)
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
        if func_def.type == "string" and func_def.value.startswith("function:"):
            # Check if JIT compiled version exists
            var jit_stats = self.profiler.get_jit_stats()
            if func_name in jit_stats:
                return self.execute_jit_function(func_name, args)
            
            # Parse function
            var parts_def = func_def.value.split(":")
            if len(parts_def) < 4:
                return PLValue("error", "invalid function")
            var name = parts_def[1]
            var params_str = parts_def[2]
            var body = parts_def[3]
            var params = params_str.split(",")
            if len(params) != len(args):
                return PLValue("error", "arg count mismatch")
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
        # Parse (UPDATE table_name SET col1 = val1, col2 = val2 WHERE condition)
        var parts = expr.split("SET ")
        if len(parts) != 2:
            return PLValue.error("Invalid UPDATE syntax")
        var table_part = parts[0][8:-1].strip()  # Remove (UPDATE and space
        var set_where = parts[1][:-1].strip()  # Remove )
        
        var where_parts = set_where.split(" WHERE ")
        var set_clause = where_parts[0].strip()
        var where_clause = where_parts[1].strip() if len(where_parts) > 1 else ""
        
        # Parse SET clauses: col1 = val1, col2 = val2
        var set_assignments = List[Tuple[String, String]]()
        for assignment in set_clause.split(","):
            var eq_parts = assignment.strip().split(" = ")
            if len(eq_parts) == 2:
                set_assignments.append((eq_parts[0].strip(), eq_parts[1].strip()))
        
        # Query the table
        var query_result = self.query_table(table_part, env)
        if query_result.is_error():
            return query_result
        
        # Apply WHERE filter if present
        var filtered_rows = List[PLValue]()
        if where_clause:
            for row in query_result.get_list():
                if self.eval_condition(where_clause, row, env):
                    filtered_rows.append(row)
        else:
            filtered_rows = query_result.get_list()
        
        # Apply updates
        var updated_rows = List[PLValue]()
        for row in filtered_rows:
            var updated_row = row  # Copy
            for assignment in set_assignments:
                var col_name = assignment[0]
                var val_expr = assignment[1]
                var new_val = self.evaluate(val_expr, env)
                # Update the struct field
                if updated_row.is_struct():
                    var struct_val = updated_row.get_struct()
                    struct_val[col_name] = new_val
                    updated_row = PLValue.struct(struct_val)
            updated_rows.append(updated_row)
        
        # Save back to ORC
        self.orc_storage.save_table(table_part, updated_rows)
        
        return PLValue.number(len(updated_rows))  # Return number of updated rows

    fn eval_delete(mut self, expr: String, env: Environment) raises -> PLValue:
        # Parse (DELETE FROM table_name WHERE condition)
        var from_pos = expr.find(" FROM ")
        var where_pos = expr.find(" WHERE ")
        if from_pos == -1:
            return PLValue.error("Invalid DELETE syntax")
        var table_name = expr[from_pos + 7:where_pos if where_pos != -1 else expr.__len__() - 1].strip()
        var where_clause = expr[where_pos + 7:expr.__len__() - 1].strip() if where_pos != -1 else ""
        
        # Query the table
        var query_result = self.query_table(table_name, env)
        if query_result.is_error():
            return query_result
        
        # Apply WHERE filter if present
        var remaining_rows = List[PLValue]()
        var deleted_count = 0
        if where_clause:
            for row in query_result.get_list():
                if not self.eval_condition(where_clause, row, env):
                    remaining_rows.append(row)
                else:
                    deleted_count += 1
        else:
            # If no WHERE, delete all
            deleted_count = len(query_result.get_list())
            remaining_rows = List[PLValue]()
        
        # Save back to ORC
        self.orc_storage.save_table(table_name, remaining_rows)
        
        return PLValue.number(deleted_count)  # Return number of deleted rows

    fn eval_import(mut self, expr: String) raises -> PLValue:
        # Parse (IMPORT module_name)
        var module_name = expr[8:expr.__len__() - 1].strip()
        
        # Check if module exists in self.modules
        if module_name in self.modules:
            # For now, just mark as imported
            return PLValue.string("imported " + module_name)
        else:
            return PLValue.error("module '" + module_name + "' not found")

    fn eval_condition(self, condition: String, row: PLValue, env: Environment) raises -> Bool:
        # Simple condition evaluation for WHERE clauses
        # For now, support column == value, column > value, etc.
        # Assume condition like "id == 1" or "name == 'john'"
        var parts = condition.split(" ")
        if len(parts) == 3:
            var left = parts[0].strip()
            var op = parts[1].strip()
            var right_str = parts[2].strip()
            
            # Get value from row
            if row.is_struct():
                var struct_val = row.get_struct()
                if left in struct_val:
                    var left_val = struct_val[left]
                    var right_val = self.evaluate(right_str, env)
                    
                    if op == "==":
                        return left_val.equals(right_val)
                    elif op == "!=":
                        return not left_val.equals(right_val)
                    elif op == ">":
                        return left_val.greater_than(right_val)
                    elif op == "<":
                        return left_val.less_than(right_val)
                    elif op == ">=":
                        return left_val.greater_than(right_val) or left_val.equals(right_val)
                    elif op == "<=":
                        return left_val.less_than(right_val) or left_val.equals(right_val)
        return False

    fn eval_function(mut self, content: String, env: Environment) raises -> PLValue:
        # Parse name(params) => body
        # For now, simple parse
        var func_str = content.strip()
        if func_str.startswith("FUNCTION "):
            func_str = func_str[9:].strip()
        var arrow_pos = func_str.find(" => ")
        if arrow_pos == -1:
            return PLValue("error", "error: no body")
        var name_and_params = func_str[:arrow_pos]
        var body = func_str[arrow_pos + 4:].strip()
        # Parse name and params
        var paren_pos = name_and_params.find("(")
        if paren_pos == -1:
            return PLValue("error", "error: no params")
        var name = name_and_params[:paren_pos].strip()
        var params_str = name_and_params[paren_pos:]
        if not (params_str.startswith("(") and params_str.endswith(")")):
            return PLValue("error", "error: invalid params")
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
        return PLValue("string", func_value)
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

    fn is_numeric(self, s: String) -> Bool:
        """Check if string is numeric."""
        try:
            _ = Int(s)
            return True
        except:
            return False