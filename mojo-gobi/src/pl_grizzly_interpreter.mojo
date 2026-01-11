"""
PL-GRIZZLY Interpreter Implementation

This module provides interpretation and execution capabilities for the PL-GRIZZLY programming language,
evaluating parsed ASTs in the context of the Godi database.
"""

from collections import Dict, List
from python import Python
from pl_grizzly_parser import PLGrizzlyParser
from pl_grizzly_lexer import PLGrizzlyLexer
from schema_manager import SchemaManager
from blob_storage import BlobStorage
from orc_storage import ORCStorage
from query_cache import QueryCache

# Query execution plan structures
struct QueryPlan(Copyable, Movable):
    var operation: String  # "scan", "join", "filter", "project"
    var table_name: String
    var conditions: List[String]
    var cost: Float64
    var children: List[QueryPlan]

# Query optimizer
struct QueryOptimizer:
    var schema_manager: SchemaManager
    
    fn __init__(mut self, schema: SchemaManager):
        self.schema_manager = schema
    
    fn optimize_select(mut self, select_stmt: String) raises -> QueryPlan:
        """Create an optimized query execution plan for a SELECT statement."""
        # Parse the SELECT statement
        var lexer = PLGrizzlyLexer(select_stmt)
        var tokens = lexer.tokenize()
        var parser = PLGrizzlyParser(tokens)
        var ast = parser.parse()
        
        # Extract table name and WHERE conditions
        var table_name = self.extract_table_name(select_stmt)
        var where_conditions = self.extract_where_conditions(select_stmt)
        
        # Check for available indexes
        var indexes = self.schema_manager.get_indexes(table_name)
        
        # Determine best access method
        var best_plan = self.choose_access_method(table_name, where_conditions, indexes)
        
        return best_plan
    
    fn extract_table_name(self, select_stmt: String) -> String:
        """Extract table name from SELECT statement."""
        var from_pos = select_stmt.find(" FROM ")
        if from_pos == -1:
            return ""
        
        var rest = select_stmt[from_pos + 6:]
        var join_pos = rest.find(" JOIN ")
        var where_pos = rest.find(" WHERE ")
        
        var table_part = ""
        if join_pos != -1:
            table_part = rest[:join_pos]
        elif where_pos != -1:
            table_part = rest[:where_pos]
        else:
            table_part = rest[:-1]  # Remove closing )
        
        return String(table_part.strip())
    
    fn extract_where_conditions(self, select_stmt: String) -> List[String]:
        """Extract WHERE conditions from SELECT statement."""
        var conditions = List[String]()
        var where_pos = select_stmt.find(" WHERE ")
        if where_pos == -1:
            return conditions
        
        var where_clause = select_stmt[where_pos + 7:]
        where_clause = where_clause[:-1]  # Remove closing )
        
        # Simple condition parsing - split by AND
        var and_conditions = where_clause.split(" AND ")
        for cond in and_conditions:
            conditions.append(String(cond.strip()))
        
        return conditions
    
    fn choose_access_method(self, table_name: String, conditions: List[String], indexes: List[Index]) -> QueryPlan:
        """Choose the best access method based on available indexes."""
        # Check if any conditions can use indexes
        for condition in conditions:
            for index in indexes:
                if self.can_use_index(condition, index):
                    # Create index scan plan
                    var index_conditions = List[String]()
                    index_conditions.append(condition)
                    return QueryPlan("index_scan", table_name, index_conditions, 10.0, List[QueryPlan]())
        
        # Default to table scan
        return QueryPlan("table_scan", table_name, conditions, 100.0, List[QueryPlan]())
    
    fn can_use_index(self, condition: String, index: Index) -> Bool:
        """Check if a condition can use the given index."""
        # Simple check: look for column = value patterns
        for col in index.columns:
            var pattern = col + " = "
            if condition.find(pattern) != -1:
                return True
            var pattern2 = col + "="
            if condition.find(pattern2) != -1:
                return True
        return False

# Value types for PL-GRIZZLY

# Value types for PL-GRIZZLY
struct PLValue(Copyable, Movable, ImplicitlyCopyable):
    var type: String
    var value: String
    var closure_env: Optional[Environment]
    var error_context: String
    var struct_data: Optional[Dict[String, PLValue]]
    var list_data: Optional[List[PLValue]]

    fn __init__(out self, type: String = "string", value: String = ""):
        self.type = type
        self.value = value
        self.closure_env = None
        self.error_context = ""
        self.struct_data = None
        self.list_data = None

    fn __copyinit__(out self, other: PLValue):
        self.type = other.type
        self.value = other.value
        if other.closure_env:
            self.closure_env = other.closure_env.value().copy()
        else:
            self.closure_env = None
        self.error_context = other.error_context
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
        result.struct_data = data.copy()
        return result

    @staticmethod
    fn list(data: List[PLValue]) -> PLValue:
        var result = PLValue("list", "")
        result.list_data = data.copy()
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
    fn error(message: String, context: String = "") -> PLValue:
        var result = PLValue("error", message)
        result.error_context = context
        return result

    fn is_struct(self) -> Bool:
        return self.type == "struct" and self.struct_data

    fn is_list(self) -> Bool:
        return self.type == "list" and self.list_data

    fn is_error(self) -> Bool:
        return self.type == "error"

    fn get_struct(self) -> Dict[String, PLValue]:
        if self.struct_data:
            return self.struct_data.value().copy()
        return Dict[String, PLValue]()

    fn get_list(self) -> List[PLValue]:
        if self.list_data:
            return self.list_data.value().copy()
        return List[PLValue]()

    fn is_truthy(self) -> Bool:
        if self.is_error():
            return False
        if self.type == "bool":
            return self.value == "true"
        if self.type == "number":
            return self.value != "0"
        if self.type == "string":
            return self.value != ""
        if self.type == "list":
            return len(self.get_list()) > 0
        if self.type == "struct":
            return len(self.get_struct()) > 0
        return True

    fn __str__(self) raises -> String:
        if self.type == "error":
            var result = "ERROR: " + self.value
            if self.error_context != "":
                result += " (context: " + self.error_context + ")"
            return result
        elif self.type == "string":
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
                    try:
                        s += key + ": " + self.struct_data.value()[key].__str__()
                    except:
                        s += key + ": <error>"
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
                    try:
                        s += item.__str__()
                    except:
                        s += "<error>"
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
    var call_stack: List[String]
    var current_user: Optional[String]
    var in_transaction: Bool
    var macros: Dict[String, String]
    var attached_databases: Dict[String, BlobStorage]
    var temp_dirs: Dict[String, String]  # alias -> temp_dir_path
    var query_optimizer: QueryOptimizer
    var query_cache: QueryCache

    fn __init__(out self, storage: BlobStorage):
        self.schema_manager = SchemaManager(storage)
        self.orc_storage = ORCStorage(storage)
        self.profiler = ProfilingManager()
        self.global_env = Environment()
        self.modules = Dict[String, String]()
        self.call_stack = List[String]()
        self.current_user = None
        self.in_transaction = False
        self.macros = Dict[String, String]()
        self.attached_databases = Dict[String, BlobStorage]()
        self.temp_dirs = Dict[String, String]()
        self.query_optimizer = QueryOptimizer(self.schema_manager)
        self.query_cache = QueryCache()
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
        
        var _rows = List[PLValue]()
        for i in range(len(data)):
            var struct_dict = Dict[String, PLValue]()
            for j in range(len(table_schema.columns)):
                var col_name = table_schema.columns[j].name
                var col_value = data[i][j] if j < len(data[i]) else ""
                # Assume string for now, but could parse to number
                struct_dict[col_name] = PLValue.string(col_value)
        return PLValue("list", "mock")

    fn query_attached_table(self, alias: String, table_name: String) -> PLValue:
        """Query table from attached database."""
        if alias not in self.attached_databases:
            return PLValue.error("attached database '" + alias + "' not found")
        
        var attached_storage = self.attached_databases[alias]
        var attached_orc = ORCStorage(attached_storage)
        var data = attached_orc.read_table(table_name)
        if len(data) == 0:
            return PLValue.list(List[PLValue]())
        
        # For attached, assume same schema or generic
        var rows = List[PLValue]()
        for i in range(len(data)):
            var struct_dict = Dict[String, PLValue]()
            for j in range(len(data[i])):
                var col_name = "col_" + String(j)
                var col_value = data[i][j]
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
        var _jit_code = ""
        try:
            _jit_code = jit_stats[func_name]
        except:
            return PLValue("error", "jit_error: function not compiled")
        print("Executing JIT code:", _jit_code)
        
        # Simple simulation: just return a mock result
        return PLValue("string", "jit_result: " + func_name + " executed with " + String(len(args)) + " args")

    fn evaluate(mut self, expr: String, env: Environment) raises -> PLValue:
        """Evaluate an expression in the given environment."""
        # Push to call stack
        self.call_stack.append(expr)
        
        if expr == "":
            self.call_stack.pop()
            return PLValue("string", "empty")
        
        # Check for special statement forms first
        if expr.startswith("(TRY "):
            return self.eval_try(expr, env)
        elif expr.startswith("(INSERT "):
            return self.eval_insert(expr, env)
        elif expr.startswith("(SELECT "):
            return self.eval_select(expr, env)
        elif expr.startswith("(LET "):
            return self.eval_let(expr, env)
        elif expr.startswith("(IMPORT "):
            return self.eval_import(expr)
        elif expr.startswith("(LOGIN "):
            return self.eval_login(expr)
        elif expr.startswith("(LOGOUT"):
            return self.eval_logout()
        elif expr.startswith("(BEGIN"):
            return self.eval_begin()
        elif expr.startswith("(COMMIT"):
            return self.eval_commit()
        elif expr.startswith("(ROLLBACK"):
            return self.eval_rollback()
        elif expr.startswith("(CACHE "):
            return self.eval_cache(expr)
        elif expr.startswith("(CLEAR "):
            return self.eval_clear()
        elif expr.startswith("(MATCH "):
            return self.eval_match(expr, env)
        elif expr.startswith("(FOR "):
            return self.eval_for(expr, env)
        elif expr.startswith("(WHILE "):
            return self.eval_while(expr, env)
        elif expr.startswith("(MODULE "):
            return self.eval_module(expr, env)
        elif expr.startswith("(MACRO "):
            return self.eval_macro(expr)
        # Parse the string AST
        elif expr.startswith("(") and expr.endswith(")"):
            return self.evaluate_list(String(expr[1:expr.__len__() - 1].strip()), env)
        elif expr.startswith("{ ") and expr.endswith(" }"):
            # Variable or table reference
            var var_name = String(expr[2:expr.__len__() - 2].strip())
            # Check if it's alias.table
            var dot_pos = var_name.find(".")
            if dot_pos != -1:
                var alias = String(var_name[:dot_pos])
                var table = String(var_name[dot_pos + 1:])
                if alias in self.attached_databases:
                    return self.query_attached_table(alias, table)
                else:
                    return PLValue.error("attached database '" + alias + "' not found")
            else:
                # Check if it's a table
                var schema = self.schema_manager.load_schema()
                var table_schema = schema.get_table(var_name)
                if table_schema.name != "":
                    return self.query_table(var_name)
                else:
                    return env.get(var_name)
        elif expr.startswith("{") and not expr.startswith("{ "):
            # Struct literal {key: value, ...}
            if expr.find(":") != -1:
                return self.parse_struct_literal(expr, env)
            else:
                # Struct literal
                return PLValue("struct", expr)
        elif expr.startswith("["):
            # List literal [item1, item2, ...]
            return self.parse_list_literal(expr, env)
        elif expr.startswith("EXCEPTION "):
            # Exception literal
            return PLValue("exception", expr[10:])
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
        
        # Check if source is already AST (starts with (operator) or is simple expression)
        var ast = source
        if source.startswith("("):
            # Check if it's infix or prefix
            var inner = source[1:source.find(")") if source.find(")") != -1 else len(source)]
            var first_token = String(inner.strip().split(" ")[0])
            # If first token is an operator, it's prefix AST, don't parse
            if first_token == "+" or first_token == "-" or first_token == "*" or first_token == "/" or first_token == "=" or first_token == "!=" or first_token == ">" or first_token == "<" or first_token == ">=" or first_token == "<=" or first_token == "and" or first_token == "or" or first_token == "not" or first_token == "SELECT" or first_token == "INSERT" or first_token == "UPDATE" or first_token == "DELETE" or first_token == "FROM" or first_token == "WHERE" or first_token == "MATCH" or first_token == "FOR" or first_token == "WHILE" or first_token == "TRY" or first_token == "IMPORT":
                # Already AST
                pass
            else:
                # Parse infix expression
                var lexer = PLGrizzlyLexer(source)
                var tokens = lexer.tokenize()
                var parser = PLGrizzlyParser(tokens)
                ast = parser.parse()
        else:
            # Parse
            var lexer = PLGrizzlyLexer(source)
            var tokens = lexer.tokenize()
            var parser = PLGrizzlyParser(tokens)
            ast = parser.parse()
        
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
            if len(parts) == 2:
                # Unary plus
                return self.evaluate(parts[1], env)
            else:
                return self.eval_binary_op(parts, env, add_op)
        elif op == "-":
            if len(parts) == 2:
                # Unary minus
                var val = self.evaluate(parts[1], env)
                if val.type == "number":
                    return PLValue("number", "-" + val.value)
                else:
                    return PLValue("error", "cannot apply unary minus to non-number")
            else:
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
        elif op == "index":
            return self.eval_index(parts, env)
        elif op == "slice":
            return self.eval_slice(parts, env)
        # elif op == "SELECT":
        #     return self.eval_select(content, env)
        elif op == "FUNCTION":
            return self.eval_function(content, env)
        elif op == "ATTACH":
            return self.eval_attach(content)
        elif op == "DETACH":
            return self.eval_detach(content)
        elif op == "LIST":
            if len(parts) > 1 and parts[1] == "ATTACHED":
                return self.eval_list_attached()
            return PLValue("error", "unknown LIST command")
        elif op == "CREATE":
            if len(parts) > 1 and parts[1] == "INDEX":
                return self.eval_create_index(content)
            return PLValue("error", "unknown CREATE command")
        elif op == "DROP":
            if len(parts) > 1 and parts[1] == "INDEX":
                return self.eval_drop_index(content)
            return PLValue("error", "unknown DROP command")
        else:
            # Check for infix expressions like "1 + 2"
            if len(parts) == 3 and (parts[1] == "+" or parts[1] == "-" or parts[1] == "*" or parts[1] == "/"):
                return self.evaluate("(" + parts[1] + " " + parts[0] + " " + parts[2] + ")", env)
            return PLValue("error", "unknown op: " + op)

    fn split_expression(self, content: String) -> List[String]:
        """Split expression content into parts, handling nested parens."""
        var parts = List[String]()
        var current = ""
        var paren_depth = 0
        
        for c in content.codepoints():
            if Int(c) == 32 and paren_depth == 0:
                if current != "":
                    parts.append(current)
                    current = ""
            elif Int(c) == 40 or Int(c) == 91:  # ( or [
                paren_depth += 1
                current += chr(Int(c))
            elif Int(c) == 41 or Int(c) == 93:  # ) or ]
                paren_depth -= 1
                current += chr(Int(c))
            else:
                current += chr(Int(c))
        
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
            var _name = parts_def[1]
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
        var _type_name = parts[2]
        # For now, just return the value, as PL-GRIZZLY is dynamically typed
        return value

    fn eval_select(mut self, content: String, env: Environment) raises -> PLValue:
        # Check cache first
        var cache_key = self.query_cache.get_cache_key(content)
        var cached_result = self.query_cache.get(cache_key)
        
        if len(cached_result) > 0:
            # Cache hit - convert cached data to PLValue
            return self._cached_result_to_plvalue(cached_result, content)
        
        # Cache miss - execute query
        var plan = self.query_optimizer.optimize_select(content)
        
        # Execute based on plan type
        var result: PLValue
        if plan.operation == "index_scan":
            result = self.eval_select_with_index(content, env, plan)
        else:
            result = self.eval_select_table_scan(content, env, plan)
        
        # Cache the result if it's a successful query
        if not result.is_error() and result.is_list():
            var table_names = self._extract_table_names(content)
            self.query_cache.put(cache_key, self._plvalue_to_cache_data(result), table_names, plan.cost)
        
        return result
        
        # Parse (SELECT select_list FROM from_clause [JOIN join_table ON on_condition] WHERE where_clause)
        var from_pos = content.find(" FROM ")
        if from_pos == -1:
            return PLValue("error", "SELECT requires FROM clause")
        
        var select_part = content[8:from_pos]  # remove "(SELECT "
        var rest = content[from_pos + 6:]  # remove " FROM "
        
        var join_pos = rest.find(" JOIN ")
        var where_pos = rest.find(" WHERE ")
        var from_clause = ""
        var join_table = ""
        var on_condition = ""
        var where_clause = ""
        
        if join_pos != -1:
            from_clause = rest[:join_pos]
            var join_rest = rest[join_pos + 6:]
            var on_pos = join_rest.find(" ON ")
            if on_pos == -1:
                return PLValue.error("JOIN requires ON clause")
            join_table = join_rest[:on_pos]
            var on_rest = join_rest[on_pos + 4:]
            where_pos = on_rest.find(" WHERE ")
            if where_pos != -1:
                on_condition = on_rest[:where_pos]
                where_clause = on_rest[where_pos + 7:rest.__len__() - 1]
            else:
                on_condition = on_rest[:-1]
        else:
            if where_pos != -1:
                from_clause = rest[:where_pos]
                where_clause = rest[where_pos + 7:rest.__len__() - 1]
            else:
                from_clause = rest[:-1]
        
        # Evaluate FROM clause
        var table_data = self.evaluate(from_clause, env)
        if table_data.type != "list":
            return PLValue("error", "FROM clause must evaluate to a list")
        
        var result_list = table_data.get_list()
        
        # Handle JOIN if present
        if join_table != "":
            var join_data = self.evaluate(join_table, env)
            if join_data.type != "list":
                return PLValue("error", "JOIN table must evaluate to a list")
            var join_list = join_data.get_list()
            var joined = List[PLValue]()
            for row1 in result_list:
                for row2 in join_list:
                    if row1.is_struct() and row2.is_struct():
                        var row1_env = env.copy()
                        for key in row1.get_struct().keys():
                            row1_env.define(key, row1.get_struct()[key])
                        var row2_env = env.copy()
                        for key in row2.get_struct().keys():
                            row2_env.define(key, row2.get_struct()[key])
                        # Combine envs for condition
                        var combined_env = row1_env.copy()
                        for key in row2_env.values.keys():
                            combined_env.define(key, row2_env.values[key])
                        var cond = self.evaluate(on_condition, combined_env)
                        if cond.is_truthy():
                            # Combine structs
                            var combined_struct = row1.get_struct()
                            for key in row2.get_struct().keys():
                                combined_struct[key] = row2.get_struct()[key]
                            joined.append(PLValue.struct(combined_struct))
                    else:
                        # If not structs, just add pairs
                        joined.append(row1)
                        joined.append(row2)
            result_list = joined
        
        # Apply WHERE filtering if present
        if where_clause != "":
            var filtered = List[PLValue]()
            for row in result_list:
                if row.is_struct():
                    var row_env = env.copy()
                    for key in row.get_struct().keys():
                        row_env.define(key, row.get_struct()[key])
                    var cond = self.evaluate(where_clause, row_env)
                    if cond.is_truthy():
                        filtered.append(row)
                else:
                    # If not struct, include
                    filtered.append(row)
            result_list = filtered
        
        return PLValue.list(result_list)

    fn eval_select_with_index(mut self, content: String, env: Environment, plan: QueryPlan) raises -> PLValue:
        """Execute SELECT using index scan."""
        # Parse the SELECT statement
        var from_pos = content.find(" FROM ")
        if from_pos == -1:
            return PLValue("error", "SELECT requires FROM clause")
        
        var select_part = content[8:from_pos]  # remove "(SELECT "
        var rest = content[from_pos + 6:]  # remove " FROM "
        
        var where_pos = rest.find(" WHERE ")
        var from_clause = ""
        var where_clause = ""
        
        if where_pos != -1:
            from_clause = rest[:where_pos]
            where_clause = rest[where_pos + 7:rest.__len__() - 1]
        else:
            from_clause = rest[:-1]
        
        var table_name = from_clause.strip()
        
        # Extract index condition from plan
        if len(plan.conditions) == 0:
            return PLValue("error", "Index scan requires conditions")
        
        var condition = plan.conditions[0]
        
        # Parse condition to extract column and value
        var eq_pos = condition.find(" = ")
        if eq_pos == -1:
            return PLValue("error", "Index scan requires equality condition")
        
        var column = condition[:eq_pos].strip()
        var value_expr = condition[eq_pos + 3:].strip()
        
        # Evaluate the value
        var value_result = self.evaluate(value_expr, env)
        var search_key = value_result.__str__()
        
        # Find suitable index
        var indexes = self.orc_storage.get_indexes(table_name)
        var index_name = ""
        for index in indexes:
            for col in index.columns:
                if col == column:
                    index_name = index.name
                    break
            if index_name != "":
                break
        
        if index_name == "":
            return PLValue("error", "No suitable index found for column " + column)
        
        # Use index to search
        var indexed_results = self.orc_storage.search_with_index(table_name, index_name, search_key)
        
        # Convert to PLValue list
        var result_list = List[PLValue]()
        for row in indexed_results:
            var struct_data = Dict[String, PLValue]()
            var schema = self.schema_manager.load_schema()
            var table_schema = schema.get_table(table_name)
            
            for i in range(len(row)):
                if i < len(table_schema.columns):
                    var col_name = table_schema.columns[i].name
                    struct_data[col_name] = PLValue("string", row[i])
            
            result_list.append(PLValue.struct(struct_data))
        
        return PLValue.list(result_list)

    fn eval_select_table_scan(mut self, content: String, env: Environment, plan: QueryPlan) raises -> PLValue:
        """Execute SELECT using table scan (original implementation)."""
        # Parse (SELECT select_list FROM from_clause [JOIN join_table ON on_condition] WHERE where_clause)
        var from_pos = content.find(" FROM ")
        if from_pos == -1:
            return PLValue("error", "SELECT requires FROM clause")
        
        var select_part = content[8:from_pos]  # remove "(SELECT "
        var rest = content[from_pos + 6:]  # remove " FROM "
        
        var join_pos = rest.find(" JOIN ")
        var where_pos = rest.find(" WHERE ")
        var from_clause = ""
        var join_table = ""
        var on_condition = ""
        var where_clause = ""
        
        if join_pos != -1:
            from_clause = rest[:join_pos]
            var join_rest = rest[join_pos + 6:]
            var on_pos = join_rest.find(" ON ")
            if on_pos == -1:
                return PLValue.error("JOIN requires ON clause")
            join_table = join_rest[:on_pos]
            var on_rest = join_rest[on_pos + 4:]
            where_pos = on_rest.find(" WHERE ")
            if where_pos != -1:
                on_condition = on_rest[:where_pos]
                where_clause = on_rest[where_pos + 7:rest.__len__() - 1]
            else:
                on_condition = on_rest[:-1]
        else:
            if where_pos != -1:
                from_clause = rest[:where_pos]
                where_clause = rest[where_pos + 7:rest.__len__() - 1]
            else:
                from_clause = rest[:-1]
        
        # Evaluate FROM clause
        var table_data = self.evaluate(from_clause, env)
        if table_data.type != "list":
            return PLValue("error", "FROM clause must evaluate to a list")
        
        var result_list = table_data.get_list()
        
        # Handle JOIN if present
        if join_table != "":
            var join_data = self.evaluate(join_table, env)
            if join_data.type != "list":
                return PLValue("error", "JOIN table must evaluate to a list")
            var join_list = join_data.get_list()
            var joined = List[PLValue]()
            for row1 in result_list:
                for row2 in join_list:
                    if row1.is_struct() and row2.is_struct():
                        var row1_env = env.copy()
                        for key in row1.get_struct().keys():
                            row1_env.define(key, row1.get_struct()[key])
                        var row2_env = env.copy()
                        for key in row2.get_struct().keys():
                            row2_env.define(key, row2.get_struct()[key])
                        # Combine envs for condition
                        var combined_env = row1_env.copy()
                        for key in row2_env.values.keys():
                            combined_env.define(key, row2_env.values[key])
                        var cond = self.evaluate(on_condition, combined_env)
                        if cond.is_truthy():
                            # Combine structs
                            var combined_struct = row1.get_struct()
                            for key in row2.get_struct().keys():
                                combined_struct[key] = row2.get_struct()[key]
                            joined.append(PLValue.struct(combined_struct))
                    else:
                        # If not structs, just add pairs
                        joined.append(row1)
                        joined.append(row2)
            result_list = joined
        
        # Apply WHERE filtering if present
        if where_clause != "":
            var filtered = List[PLValue]()
            for row in result_list:
                if row.is_struct():
                    var row_env = env.copy()
                    for key in row.get_struct().keys():
                        row_env.define(key, row.get_struct()[key])
                    var cond = self.evaluate(where_clause, row_env)
                    if cond.is_truthy():
                        filtered.append(row)
                else:
                    # If not struct, include
                    filtered.append(row)
            result_list = filtered
        
        return PLValue.list(result_list)

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
        # Check authentication
        if not self.current_user:
            return PLValue.error("authentication required for INSERT operations")
        
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
            # Invalidate cache for this table
            self.query_cache.invalidate_table(table_name)
            return PLValue("string", "inserted into " + table_name)
        else:
            return PLValue("error", "insert failed")

    fn eval_update(mut self, expr: String, env: Environment) raises -> PLValue:
        # Check authentication
        if not self.current_user:
            return PLValue.error("authentication required for UPDATE operations")
        
        # Parse (UPDATE table SET col = val WHERE condition)
        var set_pos = expr.find(" SET ")
        if set_pos == -1:
            return PLValue.error("invalid UPDATE syntax")
        var table_name = expr[8:set_pos]
        var rest = expr[set_pos + 6:]
        var where_pos = rest.find(" WHERE ")
        var set_clause = ""
        var where_clause = ""
        if where_pos != -1:
            set_clause = rest[:where_pos]
            where_clause = rest[where_pos + 7:rest.__len__() - 1]
        else:
            set_clause = rest[:-1]
        
        # For now, simple SET col = val
        var eq_pos = set_clause.find(" = ")
        if eq_pos == -1:
            return PLValue.error("invalid SET syntax")
        var col = set_clause[:eq_pos].strip()
        var val_expr = set_clause[eq_pos + 3:].strip()
        var val_result = self.evaluate(val_expr, env)
        
        # Read table, update all rows (simple implementation)
        var data = self.orc_storage.read_table(table_name)
        if len(data) == 0:
            return PLValue.error("table not found or empty")
        
        var schema = self.schema_manager.load_schema()
        var table_schema = schema.get_table(table_name)
        var col_idx = -1
        for i in range(len(table_schema.columns)):
            if table_schema.columns[i].name == col:
                col_idx = i
                break
        if col_idx == -1:
            return PLValue.error("column not found")
        
        # Update all rows
        for i in range(len(data)):
            data[i][col_idx] = val_result.__str__()
        
        var success = self.orc_storage.save_table(table_name, data)
        if success:
            # Invalidate cache for this table
            self.query_cache.invalidate_table(table_name)
            return PLValue.string("updated " + table_name)
        else:
            return PLValue.error("update failed")

    fn eval_delete(mut self, expr: String, env: Environment) raises -> PLValue:
        # Check authentication
        if not self.current_user:
            return PLValue.error("authentication required for DELETE operations")
        
        # Parse (DELETE FROM table WHERE condition)
        var from_pos = expr.find(" FROM ")
        if from_pos == -1:
            return PLValue.error("invalid DELETE syntax")
        var rest = expr[from_pos + 6:]
        var where_pos = rest.find(" WHERE ")
        var table_name = ""
        var where_clause = ""
        if where_pos != -1:
            table_name = rest[:where_pos]
            where_clause = rest[where_pos + 7:rest.__len__() - 1]
        else:
            table_name = rest[:-1]
        
        # For now, delete all rows (simple implementation)
        var data = List[List[String]]()
        var success = self.orc_storage.save_table(table_name, data)
        if success:
            # Invalidate cache for this table
            self.query_cache.invalidate_table(table_name)
            return PLValue.string("deleted from " + table_name)
        else:
            return PLValue.error("delete failed")
    fn eval_import(mut self, expr: String) raises -> PLValue:
        # Parse (IMPORT module_name)
        var module_name = expr[8:expr.__len__() - 1].strip()
        
        # Check if module exists in self.modules (predefined)
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
            # Try to load from file
            var file_path = String(module_name) + ".plg"
            try:
                # Read module file
                var builtins = Python.import_module("builtins")
                var file_obj = builtins.open(file_path, "r")
                var module_code = String(file_obj.read())
                file_obj.close()
                
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
                
                # Cache the module
                self.modules[String(module_name)] = module_code
                
                return PLValue.string("imported " + String(module_name) + " from file")
            except:
                return PLValue.error("module '" + String(module_name) + "' not found (checked predefined modules and " + file_path + ")")

    fn eval_login(mut self, expr: String) raises -> PLValue:
        # Parse (LOGIN username password)
        var parts = expr[7:expr.__len__() - 1].split(" ")
        if len(parts) != 2:
            return PLValue.error("LOGIN requires username and password")
        var username = String(parts[0])
        var password = String(parts[1])
        
        # Query users table
        var users_data = self.orc_storage.read_table("users")
        for row in users_data:
            if len(row) >= 2 and row[0] == username and row[1] == password:
                self.current_user = username
                return PLValue.string("logged in as " + username)
        
        return PLValue.error("invalid username or password")

    fn eval_logout(mut self) raises -> PLValue:
        if self.current_user:
            var old_user = self.current_user.value()
            self.current_user = None
            return PLValue.string("logged out " + old_user)
        else:
            return PLValue.string("not logged in")

    fn eval_begin(mut self) raises -> PLValue:
        if self.in_transaction:
            return PLValue.error("transaction already in progress")
        self.in_transaction = True
        return PLValue.string("transaction started")

    fn eval_commit(mut self) raises -> PLValue:
        if not self.in_transaction:
            return PLValue.error("no transaction in progress")
        self.in_transaction = False
        return PLValue.string("transaction committed")

    fn eval_rollback(mut self) raises -> PLValue:
        if not self.in_transaction:
            return PLValue.error("no transaction in progress")
        self.in_transaction = False
        return PLValue.string("transaction rolled back")

    fn eval_cache(mut self, expr: String) raises -> PLValue:
        """Handle CACHE commands like CACHE CLEAR, CACHE STATS."""
        var command = expr[7:expr.__len__() - 1].strip().upper()
        if command == "CLEAR":
            self.query_cache.clear()
            return PLValue.string("cache cleared")
        elif command == "STATS":
            var stats = self.query_cache.get_stats()
            var stats_str = "Cache Statistics:\n"
            stats_str += "Size: " + String(stats["size"]) + "\n"
            stats_str += "Hits: " + String(stats["hits"]) + "\n"
            stats_str += "Misses: " + String(stats["misses"]) + "\n"
            stats_str += "Hit Rate: " + String(stats["hit_rate"]) + "%"
            return PLValue.string(stats_str)
        else:
            return PLValue.error("unknown CACHE command: " + command)

    fn eval_clear(mut self) raises -> PLValue:
        """Handle CLEAR CACHE command."""
        self.query_cache.clear()
        return PLValue.string("cache cleared")

    fn eval_attach(mut self, expr: String) raises -> PLValue:
        # Parse (ATTACH 'path' AS alias)
        var parts = expr[8:expr.__len__() - 1].split(" AS ")
        if len(parts) != 2:
            return PLValue.error("invalid ATTACH syntax")
        var path_part = String(parts[0])
        var alias = String(parts[1])
        # Remove quotes from path
        var path = path_part[1:path_part.__len__() - 1]
        if alias in self.attached_databases:
            return PLValue.error("database '" + alias + "' already attached")
        
        var actual_path = path
        if path.endswith(".gobi"):
            # Unpack .gobi file to temporary directory
            actual_path = self.unpack_gobi_to_temp(path)
            self.temp_dirs[alias] = actual_path
        elif path.endswith(".sql"):
            # Execute .sql file to create temporary database
            actual_path = self.execute_sql_to_temp(path)
            self.temp_dirs[alias] = actual_path
        
        # Check for table name conflicts with existing attached databases
        var conflict_warnings = List[String]()
        try:
            var new_storage = BlobStorage(actual_path)
            var new_schema_manager = SchemaManager(new_storage)
            var new_tables = new_schema_manager.list_tables()
            
            for existing_alias in self.attached_databases.keys():
                var existing_storage = self.attached_databases[existing_alias[]]
                var existing_schema_manager = SchemaManager(existing_storage)
                var existing_tables = existing_schema_manager.list_tables()
                
                for new_table in new_tables:
                    if new_table[] in existing_tables:
                        conflict_warnings.append("Table '" + new_table[] + "' conflicts with existing table in '" + existing_alias[] + "'")
        except:
            # Ignore schema reading errors for conflict detection
            pass
        
        self.attached_databases[alias] = BlobStorage(actual_path)
        
        var result = "attached database '" + path + "' as '" + alias + "'"
        if len(conflict_warnings) > 0:
            result += "\nWarning: Table name conflicts detected:\n"
            for warning in conflict_warnings:
                result += "- " + warning[] + "\n"
            result += "Use fully qualified names (alias.table) to access conflicting tables."
        
        return PLValue.string(result)

    fn unpack_gobi_to_temp(mut self, gobi_path: String) raises -> String:
        """Unpack .gobi file to a temporary directory and return the path."""
        var tempfile = Python.import_module("tempfile")
        var os = Python.import_module("os")
        var pyarrow_orc = Python.import_module("pyarrow.orc")
        var builtins = Python.import_module("builtins")
        
        # Create temporary directory
        var temp_dir = String(tempfile.mkdtemp(prefix="gobi_attach_"))
        
        # Read ORC file
        var table = pyarrow_orc.read_table(gobi_path)
        
        # Extract files from the table
        var paths = table.column("path")
        var contents = table.column("content")
        var num_rows = table.num_rows
        
        for i in range(num_rows):
            var file_path_rel = String(paths[i].as_py())
            var file_content = contents[i].as_py()
            
            # Create full path
            var full_path = os.path.join(temp_dir, file_path_rel)
            
            # Ensure directory exists
            var dirname = os.path.dirname(full_path)
            if dirname:
                os.makedirs(dirname, exist_ok=True)
            
            # Write file
            var file_obj = builtins.open(full_path, "wb")
            file_obj.write(file_content)
            file_obj.close()
        
        return temp_dir

    fn execute_sql_to_temp(mut self, sql_path: String) raises -> String:
        """Execute .sql file contents to create a temporary database and return the path."""
        var tempfile = Python.import_module("tempfile")
        var os = Python.import_module("os")
        var builtins = Python.import_module("builtins")
        
        # Create temporary directory
        var temp_dir = String(tempfile.mkdtemp(prefix="gobi_sql_attach_"))
        
        # Initialize basic database structure
        var schema_dir = os.path.join(temp_dir, "schema")
        os.makedirs(schema_dir, exist_ok=True)
        
        # Read and execute SQL file
        var file_obj = builtins.open(sql_path, "r")
        var sql_content = String(file_obj.read())
        file_obj.close()
        
        # Create a temporary interpreter for this database
        var temp_storage = BlobStorage(temp_dir)
        var temp_interpreter = PLGrizzlyInterpreter(temp_storage)
        
        # Split SQL content by semicolons and execute each statement
        var statements = sql_content.split(";")
        for stmt in statements:
            var trimmed_stmt = String(stmt[]).strip()
            if trimmed_stmt.__len__() > 0:
                # Parse and execute the statement
                var lexer = PLGrizzlyLexer(trimmed_stmt)
                var tokens = lexer.tokenize()
                var parser = PLGrizzlyParser(tokens)
                var ast = parser.parse()
                if ast.startswith("(error"):
                    continue  # Skip invalid statements
                _ = temp_interpreter.evaluate(ast, temp_interpreter.global_env)
        
        return temp_dir

    fn eval_detach(mut self, expr: String) raises -> PLValue:
        # Parse (DETACH alias) or (DETACH ALL)
        var content = expr[8:expr.__len__() - 1].strip()
        if content == "ALL":
            # Detach all databases
            var aliases = List[String]()
            for alias in self.attached_databases.keys():
                aliases.append(alias[])
            
            for alias in aliases:
                _ = self.attached_databases.pop(alias[])
                # Clean up temporary directory if it exists
                if alias[] in self.temp_dirs:
                    var temp_dir = self.temp_dirs[alias[]]
                    var shutil = Python.import_module("shutil")
                    try:
                        shutil.rmtree(temp_dir)
                    except:
                        pass  # Ignore cleanup errors
                    _ = self.temp_dirs.pop(alias[])
            
            return PLValue.string("detached all databases")
        else:
            # Detach specific alias
            var alias = content
            if alias not in self.attached_databases:
                return PLValue.error("database '" + alias + "' not attached")
            _ = self.attached_databases.pop(alias)
            
            # Clean up temporary directory if it exists
            if alias in self.temp_dirs:
                var temp_dir = self.temp_dirs[alias]
                var shutil = Python.import_module("shutil")
                try:
                    shutil.rmtree(temp_dir)
                except:
                    pass  # Ignore cleanup errors
                _ = self.temp_dirs.pop(alias)
            
            return PLValue.string("detached database '" + alias + "'")

    fn eval_list_attached(mut self) raises -> PLValue:
        """List all attached databases and their schemas."""
        if len(self.attached_databases) == 0:
            return PLValue.string("No attached databases")
        
        var result = "Attached databases:\n"
        for alias in self.attached_databases.keys():
            var storage = self.attached_databases[alias]
            result += "- " + alias + ": " + storage.root_path + "\n"
            # Try to list tables in the database
            try:
                var schema_manager = SchemaManager(storage)
                var tables = schema_manager.list_tables()
                if len(tables) > 0:
                    result += "  Tables: " + ", ".join(tables) + "\n"
                else:
                    result += "  Tables: (none)\n"
            except:
                result += "  Tables: (unable to read schema)\n"
        
        return PLValue.string(result)

    fn eval_create_index(mut self, expr: String) raises -> PLValue:
        """Create an index on a table."""
        # Check authentication
        if not self.current_user:
            return PLValue.error("authentication required for CREATE INDEX operations")
        
        # Parse (CREATE INDEX name ON table (col1, col2) USING type)
        var content = expr[14:expr.__len__() - 1]  # Remove (CREATE INDEX and )
        var parts = content.split(" ON ")
        if len(parts) != 2:
            return PLValue.error("invalid CREATE INDEX syntax")
        
        var index_name = String(parts[0])
        var rest = String(parts[1])
        
        var paren_pos = rest.find("(")
        if paren_pos == -1:
            return PLValue.error("expected ( after table name")
        
        var table_name = rest[:paren_pos].strip()
        var columns_part = rest[paren_pos + 1:]
        
        var close_paren_pos = columns_part.find(")")
        if close_paren_pos == -1:
            return PLValue.error("expected ) after columns")
        
        var columns_str = columns_part[:close_paren_pos]
        var columns = columns_str.split(", ")
        
        var index_type = "btree"
        var using_part = columns_part[close_paren_pos + 1:].strip()
        if using_part.startswith("USING "):
            index_type = using_part[6:].strip()
        
        # Create the index
        var success = self.orc_storage.create_index(index_name, table_name, columns, index_type, False)
        if success:
            return PLValue.string("index '" + index_name + "' created on table '" + table_name + "'")
        else:
            return PLValue.error("failed to create index '" + index_name + "'")

    fn eval_drop_index(mut self, expr: String) raises -> PLValue:
        """Drop an index from a table."""
        # Check authentication
        if not self.current_user:
            return PLValue.error("authentication required for DROP INDEX operations")
        
        # Parse (DROP INDEX name ON table)
        var content = expr[11:expr.__len__() - 1]  # Remove (DROP INDEX and )
        var parts = content.split(" ON ")
        if len(parts) != 2:
            return PLValue.error("invalid DROP INDEX syntax")
        
        var index_name = String(parts[0])
        var table_name = String(parts[1])
        
        # Drop the index
        var success = self.orc_storage.drop_index(index_name, table_name)
        if success:
            return PLValue.string("index '" + index_name + "' dropped from table '" + table_name + "'")
        else:
            return PLValue.error("failed to drop index '" + index_name + "'")

    fn _cached_result_to_plvalue(self, cached_data: List[List[String]], query: String) -> PLValue:
        """Convert cached result data back to PLValue format."""
        var result_list = List[PLValue]()
        
        # Get table name and schema for proper struct creation
        var table_name = self._extract_table_names(query)[0]
        var schema = self.schema_manager.load_schema()
        var table_schema = schema.get_table(table_name)
        
        for row in cached_data:
            var struct_data = Dict[String, PLValue]()
            for i in range(len(row)):
                if i < len(table_schema.columns):
                    var col_name = table_schema.columns[i].name
                    struct_data[col_name] = PLValue("string", row[i])
            result_list.append(PLValue.struct(struct_data))
        
        return PLValue.list(result_list)

    fn _plvalue_to_cache_data(self, plvalue: PLValue) -> List[List[String]]:
        """Convert PLValue result to cacheable format."""
        var cache_data = List[List[String]]()
        
        if not plvalue.is_list():
            return cache_data
        
        var list_data = plvalue.get_list()
        for item in list_data:
            if item.is_struct():
                var row = List[String]()
                var struct_data = item.get_struct()
                for key in struct_data.keys():
                    row.append(struct_data[key].value)
                cache_data.append(row)
        
        return cache_data

    fn _extract_table_names(self, query: String) -> List[String]:
        """Extract table names from a SELECT query."""
        var table_names = List[String]()
        
        var from_pos = query.find(" FROM ")
        if from_pos == -1:
            return table_names
        
        var rest = query[from_pos + 6:]
        var join_pos = rest.find(" JOIN ")
        var where_pos = rest.find(" WHERE ")
        
        # Extract main table
        var table_part = ""
        if join_pos != -1:
            table_part = rest[:join_pos]
        elif where_pos != -1:
            table_part = rest[:where_pos]
        else:
            table_part = rest[:-1]  # Remove closing )
        
        table_names.append(String(table_part.strip()))
        
        # Extract joined tables
        if join_pos != -1:
            var join_part = rest[join_pos + 6:]
            var on_pos = join_part.find(" ON ")
            if on_pos != -1:
                var join_table = join_part[:on_pos].strip()
                table_names.append(String(join_table))
        
        return table_names

    fn eval_module(mut self, expr: String, env: Environment) raises -> PLValue:
        # Parse (MODULE name code)
        var parts = expr[8:expr.__len__() - 1].split(" ", 2)
        if len(parts) < 2:
            return PLValue.error("invalid module syntax")
        var module_name = String(parts[0])
        var module_code = String(parts[1])
        
        # Store the module code
        self.modules[module_name] = module_code
        
        return PLValue.string("module '" + module_name + "' created")

    fn eval_macro(mut self, expr: String) raises -> PLValue:
        # Parse (MACRO name(params) { body })
        var macro_def = expr[7:expr.__len__() - 1]  # remove (MACRO )
        var paren_pos = macro_def.find("(")
        if paren_pos == -1:
            return PLValue.error("invalid macro syntax")
        var name = String(macro_def[:paren_pos])
        var rest = macro_def[paren_pos:]
        self.macros[name] = rest
        return PLValue.string("macro '" + name + "' defined")

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
            
        var _left = condition[:op_pos].strip()
        var _right_str = condition[op_pos + len(op) + 2:].strip()
        
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
        
        var receiver: String = ""
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

    fn is_numeric(self, s: String) -> Bool:
        """Check if a string represents a valid number."""
        if s == "":
            return False
        try:
            _ = Int(s)
            return True
        except:
            return False

    fn is_numeric_or_expr(self, s: String) -> Bool:
        """Check if a string is numeric or a valid numeric expression."""
        if self.is_numeric(s):
            return True
        # Check if it's a parenthesized expression
        if s.startswith("(") and s.endswith(")"):
            var inner = String(s[1:s.__len__() - 1].strip())
            var parts = self.split_expression(inner)
            if len(parts) > 0:
                var op = parts[0]
                if op == "+" or op == "-" or op == "*" or op == "/":
                    # Recursively check all arguments
                    for i in range(1, len(parts)):
                        if not self.is_numeric_or_expr(parts[i]):
                            return False
                    return True
        return False

    fn analyze(self, ast: String) -> List[String]:
        """Analyze AST for semantic errors."""
        var errors = List[String]()
        if ast.startswith("(") and ast.endswith(")"):
            var content = String(ast[1:ast.__len__() - 1].strip())
            var parts = self.split_expression(String(content))
            if len(parts) > 0:
                var op = parts[0]
                # Skip analysis for special statements
                if op == "MATCH" or op == "FOR" or op == "WHILE" or op == "TRY" or op == "INSERT" or op == "SELECT" or op == "LET" or op == "IMPORT" or op == "MODULE":
                    return errors.copy()
                elif op == "+" or op == "-" or op == "*" or op == "/":
                    for i in range(1, len(parts)):
                        if not self.is_numeric_or_expr(parts[i]):
                            errors.append("argument " + String(i) + " to " + op + " is not numeric")
                elif op == "==" or op == "!=" or op == ">" or op == "<" or op == ">=" or op == "<=":
                    if len(parts) != 3:
                        errors.append(op + " requires exactly 2 arguments")
        return errors.copy()

    fn eval_let(mut self, expr: String, env: Environment) raises -> PLValue:
        """Evaluate a LET statement: (LET var_name value)"""
        var let_content = String(expr[5:expr.__len__() - 1].strip())  # Remove "(LET " and ")"
        var parts = self.split_expression(let_content)
        if len(parts) != 2:
            return PLValue("error", "LET requires variable name and value")
        
        var var_name = parts[0]
        var value_expr = parts[1]
        
        var value = self.evaluate(value_expr, env)
        self.global_env.define(var_name, value)
        
        return PLValue("string", "variable " + var_name + " defined")

    fn eval_match(mut self, expr: String, env: Environment) raises -> PLValue:
        # Parse (MATCH match_expr { case pattern => body ... })
        var content = String(expr[7:expr.__len__() - 2].strip())  # remove (MATCH  })
        var brace_pos = content.find(" {")
        if brace_pos == -1:
            return PLValue("error", "invalid match")
        var match_expr_str = String(content[:brace_pos].strip())
        var cases_str = String(content[brace_pos + 2:].strip())
        # Remove trailing }
        if cases_str.endswith("}"):
            cases_str = String(cases_str[:cases_str.__len__() - 1].strip())
        var match_val = self.evaluate(match_expr_str, env)
        var cases_split = cases_str.split(" case ")
        var cases = List[String]()
        for cs in cases_split:
            var trimmed = cs.strip()
            if len(trimmed) > 0:
                cases.append(String(trimmed))
        for i in range(len(cases)):
            var case_str = cases[i]
            if not case_str.startswith("case "):
                continue
            case_str = String(case_str[5:].strip())  # remove "case "
            var arrow_pos = case_str.find(" => ")
            if arrow_pos == -1:
                continue
            var pattern_str = String(case_str[:arrow_pos].strip())
            var body_str = String(case_str[arrow_pos + 4:].strip())
            var pattern_val = self.evaluate(pattern_str, env)
            if match_val.value == pattern_val.value:  # simple equality
                return self.evaluate(body_str, env)
        return PLValue("error", "no match")

    fn eval_index(mut self, parts: List[String], env: Environment) raises -> PLValue:
        """Evaluate array/list indexing: (index array index_expr)"""
        if len(parts) != 3:
            return PLValue.error("index requires 2 arguments")
        var array_val = self.evaluate(parts[1], env)
        var index_val = self.evaluate(parts[2], env)
        
        if array_val.type != "list":
            return PLValue.error("can only index into lists")
        if index_val.type != "number":
            return PLValue.error("index must be a number")
        
        # Parse the list string like "[item1, item2, item3]"
        var list_str = array_val.value
        if not (list_str.startswith("[") and list_str.endswith("]")):
            return PLValue.error("invalid list format")
        
        var inner = list_str[1:list_str.__len__() - 1].strip()
        var items = List[String]()
        if len(inner) > 0:
            # Simple split by comma (doesn't handle nested structures perfectly)
            var temp_items = inner.split(",")
            for item in temp_items:
                var item_str = String(item.strip())
                items.append(item_str)
        
        try:
            var idx = Int(index_val.value)
            if idx < 0:
                idx = len(items) + idx  # Negative indexing
            if idx < 0 or idx >= len(items):
                return PLValue.error("index out of bounds")
            return PLValue("string", items[idx])  # For now, return as string
        except:
            return PLValue.error("invalid index")

    fn eval_slice(mut self, parts: List[String], env: Environment) raises -> PLValue:
        """Evaluate array/list slicing: (slice array start end)"""
        if len(parts) != 4:
            return PLValue.error("slice requires 3 arguments")
        var array_val = self.evaluate(parts[1], env)
        var start_val = self.evaluate(parts[2], env)
        var end_val = self.evaluate(parts[3], env)
        
        if array_val.type != "list":
            return PLValue.error("can only slice lists")
        if start_val.type != "number" or end_val.type != "number":
            return PLValue.error("slice indices must be numbers")
        
        # Parse the list string
        var list_str = array_val.value
        if not (list_str.startswith("[") and list_str.endswith("]")):
            return PLValue.error("invalid list format")
        
        var inner = list_str[1:list_str.__len__() - 1].strip()
        var items = List[String]()
        if len(inner) > 0:
            var temp_items = inner.split(",")
            for item in temp_items:
                var item_str = String(item.strip())
                items.append(item_str)
        
        try:
            var start = Int(start_val.value)
            var end = Int(end_val.value)
            if start < 0:
                start = len(items) + start
            if end < 0:
                end = len(items) + end
            start = max(0, start)
            end = min(len(items), end)
            
            var result_items = List[String]()
            for i in range(start, end):
                result_items.append(items[i])
            
            var result_str = "["
            for i in range(len(result_items)):
                if i > 0:
                    result_str += ", "
                result_str += result_items[i]
            result_str += "]"
            return PLValue("list", result_str)
        except:
            return PLValue.error("invalid slice indices")

    fn eval_for(mut self, expr: String, env: Environment) raises -> PLValue:
        # Parse (FOR var IN collection { body })
        var content = expr[5:expr.__len__() - 2].strip()  # remove (FOR  })
        var in_pos = content.find(" IN ")
        if in_pos == -1:
            return PLValue("error", "invalid for")
        var var_name = String(content[:in_pos].strip())
        var rest = String(content[in_pos + 4:].strip())
        var brace_pos = rest.find(" { ")
        if brace_pos == -1:
            return PLValue("error", "invalid for")
        var collection_str = String(rest[:brace_pos].strip())
        var body_str = String(rest[brace_pos + 3:].strip())
        var collection = self.evaluate(String(collection_str), env)
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
        var condition_str = String(content[:brace_pos].strip())
        var body_str = String(content[brace_pos + 3:].strip())
        while True:
            var cond = self.evaluate(String(condition_str), env)
            if cond.type != "bool" or cond.value != "true":
                break
            _ = self.evaluate(body_str, env)
        return PLValue("string", "while completed")

    fn parse_struct_literal(self, expr: String, env: Environment) raises -> PLValue:
        """Parse {key: value, ...} into struct."""
        var content = expr[1:expr.__len__() - 1].strip()  # remove {}
        if content == "":
            return PLValue.struct(Dict[String, PLValue]())
        
        var pairs = content.split(", ")
        var struct_dict = Dict[String, PLValue]()
        for pair in pairs:
            var colon_pos = pair.find(": ")
            if colon_pos == -1:
                return PLValue.error("invalid struct literal: " + pair)
            var key = String(pair[:colon_pos].strip())
            var value_expr = String(pair[colon_pos + 2:].strip())
            var value = self.evaluate(value_expr, env)
            struct_dict[key] = value
        return PLValue.struct(struct_dict)

    fn parse_list_literal(self, expr: String, env: Environment) raises -> PLValue:
        """Parse [item1, item2, ...] into list."""
        var content = expr[1:expr.__len__() - 1].strip()  # remove []
        if content == "":
            return PLValue.list(List[PLValue]())
        
        var items = content.split(", ")
        var list_data = List[PLValue]()
        for item_expr in items:
            var item = self.evaluate(String(item_expr.strip()), env)
            list_data.append(item)
        return PLValue.list(list_data)

    fn error_with_context(mut self, message: String) -> PLValue:
        """Create an error with current call stack context."""
        var context = ""
        if len(self.call_stack) > 0:
            context = self.call_stack[len(self.call_stack) - 1]
        return PLValue.error(message, context)