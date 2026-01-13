"""
PL-GRIZZLY AST Evaluator Module

Optimized AST evaluator with caching and symbol table management.
"""

from collections import Dict, List
from pl_grizzly_parser import ASTNode, SymbolTable, PLGrizzlyParser
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_values import PLValue
from pl_grizzly_environment import Environment
from pl_grizzly_errors import PLGrizzlyError, ErrorManager, create_undefined_variable_error, create_type_mismatch_error, create_division_by_zero_error, create_table_not_found_error
from orc_storage import ORCStorage
from schema_manager import SchemaManager, Column
from python import Python

struct ASTEvaluator:
    var symbol_table: SymbolTable
    var eval_cache: Dict[String, PLValue]
    var recursion_depth: Int
    var error_manager: ErrorManager
    var source_code: String  # Store source code for error context

    fn __init__(out self, source_code: String = ""):
        self.symbol_table = SymbolTable()
        self.eval_cache = Dict[String, PLValue]()
        self.recursion_depth = 0
        self.error_manager = ErrorManager()
        self.source_code = source_code

    fn set_source_code(mut self, source: String):
        """Set the source code for error context."""
        self.source_code = source

    fn _get_source_line(self, line: Int) -> String:
        """Get the source line at the given line number (1-based)."""
        if self.source_code == "" or line < 1:
            return ""

        var lines = self.source_code.split("\n")
        if line <= len(lines):
            return String(lines[line - 1])
        return ""

    fn evaluate(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate AST node with caching and optimization."""
        # Prevent infinite recursion
        if self.recursion_depth > 1000:
            var error = PLGrizzlyError.runtime_error("Maximum recursion depth exceeded")
            return PLValue.enhanced_error(error)

        self.recursion_depth += 1

        # Create cache key
        var cache_key = node.node_type + "_" + node.value + "_" + String(len(node.children))
        var cached = self.eval_cache.get(cache_key)
        if cached:
            self.recursion_depth -= 1
            return cached.value()

        var result: PLValue

        if node.node_type == "SELECT":
            result = self.eval_select_node(node, env, orc_storage)
        elif node.node_type == "INSERT":
            result = self.eval_insert_node(node, env, orc_storage)
        elif node.node_type == "UPDATE":
            result = self.eval_update_node(node, env, orc_storage)
        elif node.node_type == "DELETE":
            result = self.eval_delete_node(node, env, orc_storage)
        elif node.node_type == "CREATE":
            result = self.eval_create_node(node, env, orc_storage)
        elif node.node_type == "CREATE_TABLE":
            result = self.eval_create_table_node(node, env, orc_storage)
        elif node.node_type == "INDEX":
            if node.value == "index":
                result = self.eval_index_node(node, env, orc_storage)
            else:
                result = self.eval_create_index_node(node, env, orc_storage)
        elif node.node_type == "IF":
            result = self.eval_if_node(node, env, orc_storage)
        elif node.node_type == "ARRAY":
            result = self.eval_array_node(node, env, orc_storage)
        elif node.node_type == "STRUCT_LITERAL":
            result = self.eval_struct_literal_node(node, env, orc_storage)
        elif node.node_type == "TYPED_ARRAY":
            result = self.eval_typed_array_node(node, env, orc_storage)
        elif node.node_type == "ARRAY_AGGREGATION":
            result = self.eval_array_aggregation_node(node, env, orc_storage)
        elif node.node_type == "BINARY_OP":
            result = self.eval_binary_op(node, env, orc_storage)
        elif node.node_type == "UNARY_OP":
            result = self.eval_unary_op(node, env, orc_storage)
        elif node.node_type == "LITERAL":
            result = self.eval_literal(node)
        elif node.node_type == "IDENTIFIER":
            result = self.eval_identifier(node, env)
        elif node.node_type == "VARIABLE":
            result = self.eval_identifier(node, env)  # VARIABLE is like IDENTIFIER for lookup
        elif node.node_type == "LET":
            result = self.eval_let_node(node, env, orc_storage)
        elif node.node_type == "WHILE":
            result = self.eval_while_node(node, env, orc_storage)
        elif node.node_type == "BLOCK":
            result = self.eval_block_node(node, env, orc_storage)
        elif node.node_type == "FUNCTION":
            result = self.eval_function_node(node, env, orc_storage)
        elif node.node_type == "CALL":
            result = self.eval_call_node(node, env, orc_storage)
        elif node.node_type == "TYPE":
            result = self.eval_type_node(node, env, orc_storage)
        elif node.node_type == "ATTACH":
            result = self.eval_attach_node(node, env, orc_storage)
        elif node.node_type == "DETACH":
            result = self.eval_detach_node(node, env, orc_storage)
        elif node.node_type == "EXECUTE":
            result = self.eval_execute_node(node, env, orc_storage)
        elif node.node_type == "SHOW":
            result = self.eval_show_node(node, env, orc_storage)
        elif node.node_type == "DROP":
            result = self.eval_drop_node(node, env, orc_storage)
        elif node.node_type == "DROP_SECRET":
            result = self.eval_drop_secret_node(node, env, orc_storage)
        elif node.node_type == "BREAK":
            result = PLValue("break", "")
        elif node.node_type == "CONTINUE":
            result = PLValue("continue", "")
        else:
            var error = PLGrizzlyError.semantic_error(
                "Unknown AST node type: " + node.node_type,
                node.line, node.column, self._get_source_line(node.line)
            )
            error.add_suggestion("Check the PL-GRIZZLY language documentation for supported constructs")
            result = PLValue.enhanced_error(error)

        # Cache the result
        self.eval_cache[cache_key] = result
        self.recursion_depth -= 1
        return result

    fn eval_select_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate SELECT AST node."""
        # Extract components from AST
        var select_list: Optional[ASTNode] = None
        var from_clause: Optional[ASTNode] = None
        var where_clause: Optional[ASTNode] = None
        var group_clause: Optional[ASTNode] = None
        var order_clause: Optional[ASTNode] = None
        var then_clause: Optional[ASTNode] = None

        for child in node.children:
            if child.node_type == "SELECT_LIST":
                select_list = child.copy()
            elif child.node_type == "FROM":
                from_clause = child.copy()
            elif child.node_type == "WHERE":
                where_clause = child.copy()
            elif child.node_type == "GROUP_BY":
                group_clause = child.copy()
            elif child.node_type == "ORDER_BY":
                order_clause = child.copy()
            elif child.node_type == "THEN":
                then_clause = child.copy()

        if not from_clause:
            var error = PLGrizzlyError.syntax_error(
                "SELECT requires FROM clause",
                node.line, node.column, self._get_source_line(node.line)
            )
            error.add_suggestion("Add a FROM clause to specify the data source")
            error.add_suggestion("Example: SELECT * FROM table_name")
            return PLValue.enhanced_error(error)

        var table_name = from_clause.value().get_attribute("table")
        var is_array_iteration = False
        var array_data: Optional[PLValue] = None
        
        # Check if this is array iteration (variable reference) or table iteration
        if table_name == "":
            # Check if FROM clause contains a variable reference
            var from_value = from_clause.value().value
            if from_value != "":
                # Try to get the variable from environment
                var array_var = env.get(from_value)
                if array_var.type != "error" and array_var.type == "array":
                    is_array_iteration = True
                    array_data = array_var
                else:
                    return PLValue.enhanced_error(create_undefined_variable_error(
                        from_value, node.line, node.column, self._get_source_line(node.line)
                    ))
            else:
                return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
                "Invalid FROM clause", node.line, node.column, self._get_source_line(node.line)
            ))
        elif table_name != "":
            # Traditional table iteration
            is_array_iteration = False
        else:
            return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
            "Invalid table name in FROM clause", node.line, node.column, self._get_source_line(node.line)
        ))

        var result_data: List[List[String]]
        var selected_columns = List[String]()
        var column_names: List[String]

        if is_array_iteration:
            # Handle array iteration
            var arr = array_data.value()
            var array_elements = arr.value.split("[")[1].split("]")[0].split(", ")
            
            # For array iteration, we create synthetic rows with [index, value]
            result_data = List[List[String]]()
            for i in range(len(array_elements)):
                var row = List[String]()
                row.append(String(i))  # array_index
                row.append(String(array_elements[i].strip()))  # array_value
                result_data.append(row.copy())
            
            selected_columns = List[String]("array_index", "array_value")
            column_names = selected_columns.copy()
        else:
            # Traditional table iteration
            # Get table schema to know column structure
            var schema = orc_storage.schema_manager.load_schema()
            var table_schema = schema.get_table(table_name)
            if table_schema.name == "":
                return PLValue.enhanced_error(create_table_not_found_error(
                    table_name, node.line, node.column, self._get_source_line(node.line)
                ))

            # Read all data from the table
            var table_data = orc_storage.read_table(table_name)
            
            # Get column names from schema
            column_names = List[String]()
            for col in table_schema.columns:
                column_names.append(col.name)

            # Determine which columns to select
            var selected_columns = List[String]()
            var has_array_aggregation = False
            var array_aggregation_node: Optional[ASTNode] = None
            
            if select_list:
                # Parse select list to get column names
                for select_item in select_list.value().children:
                    if select_item.node_type == "SELECT_ITEM":
                        for child in select_item.children:
                            if child.node_type == "ARRAY_AGGREGATION":
                                # Handle array aggregation
                                has_array_aggregation = True
                                # Store the aggregation node for later evaluation
                                array_aggregation_node = child.copy()
                                selected_columns.append("array_aggregation")
                                # Evaluate aggregation on filtered data later
                                break
                            elif child.node_type == "IDENTIFIER":
                                selected_columns.append(child.value)
                            elif child.node_type == "STAR":  # SELECT *
                                selected_columns = column_names.copy()
                                break
                            elif child.node_type == "AGGREGATE_FUNCTION":
                                # For now, just add the function name as column name
                                selected_columns.append(child.value)
                                break
                        if len(selected_columns) == len(column_names):
                            break  # Already selected all columns
            else:
                # Default to all columns
                selected_columns = column_names.copy()

            # Apply WHERE clause filtering if present
            var filtered_data = List[List[String]]()
            if where_clause:
                # Evaluate WHERE condition for each row
                for row_idx in range(len(table_data)):
                    var row = table_data[row_idx].copy()
                    
                    # Create a row environment for WHERE evaluation
                    var row_env = env.copy()
                    for col_idx in range(len(column_names)):
                        if col_idx < len(row):
                            row_env.define(column_names[col_idx], PLValue("string", row[col_idx]))
                    
                    # Evaluate WHERE condition
                    var condition_result = self.evaluate(where_clause.value(), row_env, orc_storage)
                    if condition_result.type == "boolean" and condition_result.value == "true":
                        filtered_data.append(row.copy())
            else:
                # No WHERE clause, include all rows
                for row in table_data:
                    filtered_data.append(row.copy())
            
            result_data = filtered_data^

        # Select only requested columns (for table iteration)
        if not is_array_iteration:
            var final_result_data = List[List[String]]()
            for row in result_data:
                var selected_row = List[String]()
                for col_name in selected_columns:
                    var col_idx = -1
                    for i in range(len(column_names)):
                        if column_names[i] == col_name:
                            col_idx = i
                            break
                    if col_idx >= 0 and col_idx < len(row):
                        selected_row.append(row[col_idx])
                    else:
                        selected_row.append("")  # Empty value for missing columns
                final_result_data.append(selected_row.copy())
            result_data = final_result_data^

        # Evaluate array aggregation if present (table iteration only)
        var array_aggregation_result = PLValue("array", "[]")
        # TODO: Implement array aggregation
        # if not is_array_iteration and has_array_aggregation and array_aggregation_node:
        #     array_aggregation_result = self.eval_array_aggregation_on_data(array_aggregation_node.value(), result_data, column_names)

        # Execute THEN clause if present
        if then_clause:
            if is_array_iteration:
                # For array iteration, iterate over each element
                for row in result_data:
                    # Create row environment with array_index and array_value
                    var row_env = env.copy()
                    row_env.define("array_index", PLValue("string", row[0]))
                    row_env.define("array_value", PLValue("string", row[1]))
                    
                    # Execute THEN block with loop control handling
                    var block_result = self.eval_block_with_loop_control(then_clause.value().children[0], row_env, orc_storage)
                    if block_result.type == "break":
                        break
                    elif block_result.type == "continue":
                        continue
            # elif has_array_aggregation:
            #     # For array aggregations, execute THEN once with result
            #     var then_env = env.copy()
            #     then_env.define("result", array_aggregation_result)
            #     _ = self.eval_block_with_loop_control(then_clause.value().children[0], then_env, orc_storage)
            # else:
                # For table iteration, iterate over each row
                for row in result_data:
                    # Create row environment with column variables
                    var row_env = env.copy()
                    for col_idx in range(len(selected_columns)):
                        if col_idx < len(row):
                            row_env.define(selected_columns[col_idx], PLValue("string", row[col_idx]))
                    
                    # Execute THEN block with loop control handling
                    var block_result = self.eval_block_with_loop_control(then_clause.value().children[0], row_env, orc_storage)
                    if block_result.type == "break":
                        break
                    elif block_result.type == "continue":
                        continue

        # Format result as string for now (skip for THEN execution)
        if then_clause:
            return PLValue("string", "Query executed with THEN clause - " + String(len(result_data)) + " rows processed")
        # elif not is_array_iteration and has_array_aggregation:
        #     # For array aggregations, return the aggregated result
        #     return array_aggregation_result
        else:
            var result_str = "Query results (" + String(len(result_data)) + " rows):\n"
            result_str += "Columns: "
            for i in range(len(selected_columns)):
                if i > 0:
                    result_str += ", "
                result_str += selected_columns[i]
            result_str += "\n"
            
            for row in result_data:
                result_str += "["
                for i in range(len(row)):
                    if i > 0:
                        result_str += ", "
                    result_str += "\"" + row[i] + "\""
                result_str += "]\n"

            return PLValue("string", result_str)

    fn eval_binary_op(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate binary operation."""
        if len(node.children) != 2:
            var error = PLGrizzlyError.syntax_error(
                "Binary operation requires 2 operands",
                node.line, node.column, self._get_source_line(node.line)
            )
            error.add_suggestion("Ensure binary operators have exactly two operands")
            return PLValue.enhanced_error(error)

        var left = self.evaluate(node.children[0], env, orc_storage)
        var right = self.evaluate(node.children[1], env, orc_storage)

        if left.is_error() or right.is_error():
            # Propagate existing errors
            if left.is_error():
                return left
            return right

        var op = node.value

        if op == "+":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                return PLValue("number", String(left_val + right_val))
            elif left.type == "string" or right.type == "string":
                # String concatenation
                return PLValue("string", left.value + right.value)
        elif op == "-":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                return PLValue("number", String(left_val - right_val))
        elif op == "*":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                return PLValue("number", String(left_val * right_val))
        elif op == "/":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                if right_val == 0:
                    return PLValue.enhanced_error(create_division_by_zero_error(
                        node.line, node.column, self._get_source_line(node.line)
                    ))
                return PLValue("number", String(left_val // right_val))
        elif op == "%":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                if right_val == 0:
                    var error = create_division_by_zero_error(
                        node.line, node.column, self._get_source_line(node.line)
                    )
                    return PLValue.enhanced_error(error.with_context("Modulo operation"))
                return PLValue("number", String(left_val % right_val))
        elif op == "and" or op == "&&":
            if left.type == "boolean" and right.type == "boolean":
                if left.value == "true" and right.value == "true":
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
        elif op == "or" or op == "||":
            if left.type == "boolean" and right.type == "boolean":
                if left.value == "true" or right.value == "true":
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
        elif op == "=":
            if left.type == right.type:
                if left.value == right.value:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
            else:
                return PLValue("boolean", "false")
        elif op == "!=":
            if left.type == right.type:
                if left.value != right.value:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
            else:
                return PLValue("boolean", "true")
        elif op == "<":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                if left_val < right_val:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
            elif left.type == "string" and right.type == "string":
                if left.value < right.value:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
        elif op == ">":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                if left_val > right_val:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
            elif left.type == "string" and right.type == "string":
                if left.value > right.value:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
        elif op == "<=":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                if left_val <= right_val:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
            elif left.type == "string" and right.type == "string":
                if left.value <= right.value:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
        elif op == ">=":
            if left.type == "number" and right.type == "number":
                var left_val = atol(left.value)
                var right_val = atol(right.value)
                if left_val >= right_val:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")
            elif left.type == "string" and right.type == "string":
                if left.value >= right.value:
                    return PLValue("boolean", "true")
                else:
                    return PLValue("boolean", "false")

        return PLValue.enhanced_error(PLGrizzlyError.semantic_error(
            "Unsupported binary operation: " + op,
            node.line, node.column, self._get_source_line(node.line)
        ))

    fn eval_unary_op(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate unary operation."""
        if len(node.children) != 1:
            var error = PLGrizzlyError.syntax_error(
                "Unary operation requires 1 operand",
                node.line, node.column, self._get_source_line(node.line)
            )
            return PLValue.enhanced_error(error)

        var operand = self.evaluate(node.children[0], env, orc_storage)
        if operand.is_error():
            return operand

        var op = node.value

        if op == "not" or op == "!":
            if operand.type == "boolean":
                if operand.value == "true":
                    return PLValue("boolean", "false")
                else:
                    return PLValue("boolean", "true")
            else:
                return PLValue.enhanced_error(create_type_mismatch_error(
                    "boolean", operand.type, "NOT operation",
                    node.line, node.column, self._get_source_line(node.line)
                ))
        elif op == "-":
            if operand.type == "number":
                var val = atol(operand.value)
                return PLValue("number", String(-val))
            else:
                return PLValue.enhanced_error(create_type_mismatch_error(
                    "number", operand.type, "unary minus",
                    node.line, node.column, self._get_source_line(node.line)
                ))

        return PLValue.enhanced_error(PLGrizzlyError.semantic_error(
            "Unsupported unary operation: " + op,
            node.line, node.column, self._get_source_line(node.line)
        ))

    fn eval_literal(mut self, node: ASTNode) raises -> PLValue:
        """Evaluate literal value."""
        var value = node.value
        if value.startswith('"') and value.endswith('"'):
            return PLValue("string", value[1:-1])
        elif value == "true":
            return PLValue("boolean", "true")
        elif value == "false":
            return PLValue("boolean", "false")
        else:
            # Try to parse as number
            try:
                _ = atol(value)
                return PLValue("number", value)
            except:
                return PLValue("string", value)

    fn eval_identifier(mut self, node: ASTNode, mut env: Environment) raises -> PLValue:
        """Evaluate identifier/variable reference."""
        var name = node.value
        try:
            return env.get(name)
        except:
            return PLValue.enhanced_error(create_undefined_variable_error(
                name, node.line, node.column, self._get_source_line(node.line)
            ))

    fn eval_create_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate CREATE statement."""
        # Check if this is CREATE TABLE
        if node.node_type == "CREATE_TABLE":
            return self.eval_create_table_node(node, env, orc_storage)
        # Check if this is CREATE INDEX
        elif len(node.children) > 0 and node.children[0].node_type == "INDEX":
            return self.eval_index_node(node.children[0], env, orc_storage)
        else:
            return PLValue("string", "CREATE statement acknowledged")

    fn eval_create_table_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate CREATE TABLE statement."""
        if len(node.children) < 2:
            return PLValue("error", "CREATE TABLE requires table name and column definitions")

        var table_name = node.children[0].value
        var columns_node = node.children[1].copy()

        # Parse column definitions
        var columns = List[Column]()
        for col_node in columns_node.children:
            if len(col_node.children) >= 2:
                var col_name = col_node.children[0].value
                var col_type = col_node.children[1].value
                columns.append(Column(col_name, col_type))

        # Create table schema
        try:
            var success = orc_storage.schema_manager.create_table(table_name, columns)
            if success:
                return PLValue("string", "Table '" + table_name + "' created successfully")
            else:
                return PLValue("error", "Failed to create table")
        except e:
            return PLValue("error", "Failed to create table: " + String(e))

    fn eval_insert_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate INSERT statement."""
        var table_name = node.get_attribute("table")
        if table_name == "":
            return PLValue("error", "INSERT requires table name")

        # Find the VALUES node
        var values_node: Optional[ASTNode] = None
        for child in node.children:
            if child.node_type == "VALUES":
                values_node = child.copy()
                break

        if not values_node:
            return PLValue("error", "INSERT requires VALUES clause")

        # Parse values
        var new_row = List[String]()
        if values_node:
            for val_node in values_node.value().children:
                if val_node.node_type == "LITERAL":
                    new_row.append(val_node.value)
                else:
                    # Evaluate expression
                    var val = self.evaluate(val_node, env, orc_storage)
                    new_row.append(val.value)

        try:
            # Read current table data
            var table_data = orc_storage.read_table(table_name)
            # Append new row
            table_data.append(new_row.copy())
            # Write back
            var success = orc_storage.save_table(table_name, table_data)
            if success:
                return PLValue("number", String(len(table_data) - 1))  # Return row ID
            else:
                return PLValue("error", "Failed to save table after insert")
        except e:
            return PLValue("error", "Failed to insert row: " + String(e))

    fn eval_update_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate UPDATE statement."""
        if len(node.children) < 3:
            return PLValue("error", "UPDATE requires table name, SET clause, and WHERE clause")

        var table_name = node.children[0].value
        var set_clause = node.children[1].copy()
        var where_clause = node.children[2].copy()

        try:
            # Read current table data
            var table_data = orc_storage.read_table(table_name)
            if len(table_data) == 0:
                return PLValue("number", "0")  # No rows to update

            # Get schema to know column positions
            var schema = orc_storage.schema_manager.load_schema()
            var table = schema.get_table(table_name)
            var column_positions = Dict[String, Int]()
            for i in range(len(table.columns)):
                column_positions[table.columns[i].name] = i

            # Parse SET assignments
            var updates = Dict[String, String]()
            for assignment in set_clause.children:
                if len(assignment.children) == 2:
                    var col_name = assignment.children[0].value
                    var val_node = assignment.children[1].copy()
                    var value = self.evaluate(val_node, env, orc_storage).value
                    updates[col_name] = value

            # Apply updates to matching rows
            var updated_count = 0
            for row_idx in range(len(table_data)):
                var row = table_data[row_idx].copy()
                # Simple WHERE evaluation - for now, just update all rows
                # TODO: Implement proper WHERE clause evaluation
                for update_entry in updates.items():
                    var col_name = update_entry.key
                    var new_value = update_entry.value
                    if col_name in column_positions:
                        var col_pos = column_positions[col_name]
                        if col_pos < len(row):
                            row[col_pos] = new_value
                            updated_count += 1

            # Write back updated data
            var success = orc_storage.save_table(table_name, table_data)
            if success:
                return PLValue("number", String(updated_count))
            else:
                return PLValue("error", "Failed to save table after update")
        except e:
            return PLValue("error", "Failed to update rows: " + String(e))

    fn eval_delete_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate DELETE statement."""
        if len(node.children) < 2:
            return PLValue("error", "DELETE requires table name and WHERE clause")

        var table_name = node.children[0].value
        var where_clause = node.children[1].copy()

        try:
            # Read current table data
            var table_data = orc_storage.read_table(table_name)
            if len(table_data) == 0:
                return PLValue("number", "0")  # No rows to delete

            # For now, simple implementation - delete all rows
            # TODO: Implement proper WHERE clause evaluation
            var deleted_count = len(table_data)
            var empty_data = List[List[String]]()

            # Write back empty table
            var success = orc_storage.save_table(table_name, empty_data)
            if success:
                return PLValue("number", String(deleted_count))
            else:
                return PLValue("error", "Failed to save table after delete")
        except e:
            return PLValue("error", "Failed to delete rows: " + String(e))

    fn eval_create_index_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate CREATE INDEX statement."""
        if len(node.children) < 2:
            return PLValue("error", "CREATE INDEX requires index name and column")

        var index_name = node.get_attribute("name")
        var table_name = node.children[0].value
        var column_name = node.children[1].value

        try:
            # ORCStorage.create_index expects List[String] for columns
            var columns = List[String]()
            columns.append(column_name)

            var success = orc_storage.create_index(index_name, table_name, columns)
            if success:
                return PLValue("string", "Index '" + index_name + "' created on " + table_name + "." + column_name)
            else:
                return PLValue("error", "Failed to create index")
        except e:
            return PLValue("error", "Failed to create index: " + String(e))

    fn eval_if_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate IF conditional."""
        if len(node.children) < 2:
            return PLValue("error", "IF requires condition and then branch")

        var condition = self.evaluate(node.children[0], env, orc_storage)
        if condition.type == "boolean" and condition.value == "true":
            return self.evaluate(node.children[1], env, orc_storage)
        elif len(node.children) > 2:
            return self.evaluate(node.children[2], env, orc_storage)
        else:
            return PLValue("boolean", "false")

    fn eval_array_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate ARRAY operations."""
        if len(node.children) == 0:
            return PLValue("list", "[]")

        # For now, just return the list representation
        var result = "["
        for i in range(len(node.children)):
            if i > 0:
                result += ", "
            var item = self.evaluate(node.children[i], env, orc_storage)
            result += item.value
        result += "]"
        return PLValue("list", result)

    fn eval_struct_literal_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate STRUCT_LITERAL operations like {key: value, ...}."""
        if len(node.children) == 0:
            return PLValue("struct", "{}")

        # For now, just return a simple struct representation
        var result = "{"
        for i in range(len(node.children)):
            if i > 0:
                result += ", "
            var field = node.children[i].copy()
            var field_name = field.value
            var field_value = self.evaluate(field.children[0], env, orc_storage)
            result += field_name + ": " + field_value.value
        result += "}"
        return PLValue("struct", result)

    fn eval_typed_array_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate TYPED_ARRAY operations like Array<Type> as [...] or Array<Type>::[...]."""
        var type_name = node.get_attribute("type")
        var syntax = node.get_attribute("syntax")
        
        if syntax == "declaration":
            # Just Array<Type> without initialization
            return PLValue("typed_array", "Array<" + type_name + ">")
        
        # For initialized typed arrays, evaluate the array literal
        if len(node.children) > 0:
            var array_value = self.evaluate(node.children[0], env, orc_storage)
            return PLValue("typed_array", "Array<" + type_name + ">" + array_value.value)
        else:
            return PLValue("typed_array", "Array<" + type_name + ">[]")

    fn eval_array_aggregation_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate ARRAY_AGGREGATION operations like Array::(Distinct column)."""
        if len(node.children) == 0:
            return PLValue("error", "Array aggregation requires an expression")
        
        var agg_expr = node.children[0].copy()
        var function = agg_expr.get_attribute("function")
        
        if function == "DISTINCT":
            if len(agg_expr.children) == 0:
                return PLValue("error", "DISTINCT requires a column expression")
            
            var column_expr = agg_expr.children[0].copy()
            if column_expr.node_type == "IDENTIFIER":
                var column_name = column_expr.value
                
                # Get table data from current context (this would need to be passed in)
                # For now, return a placeholder that indicates the aggregation
                return PLValue("array", "Array::(Distinct " + column_name + ")")
            else:
                return PLValue("error", "DISTINCT requires a column name")
        else:
            # Handle other aggregation functions
            if len(agg_expr.children) == 0:
                return PLValue("error", "Aggregation function requires an expression")
            
            var column_expr = agg_expr.children[0].copy()
            if column_expr.node_type == "IDENTIFIER":
                var column_name = column_expr.value
                return PLValue("array", "Array::(" + function + "(" + column_name + "))")
            else:
                return PLValue("error", "Aggregation function requires a column name")

    fn eval_array_aggregation_on_data(mut self, node: ASTNode, filtered_data: List[List[String]], column_names: List[String]) raises -> PLValue:
        """Evaluate array aggregation on actual table data."""
        if len(node.children) == 0:
            return PLValue("error", "Array aggregation requires an expression")
        
        var agg_expr = node.children[0].copy()
        var function = agg_expr.get_attribute("function")
        
        if function == "DISTINCT":
            if len(agg_expr.children) == 0:
                return PLValue("error", "DISTINCT requires a column expression")
            
            var column_expr = agg_expr.children[0].copy()
            if column_expr.node_type == "IDENTIFIER":
                var column_name = column_expr.value
                
                # Find column index
                var col_idx = -1
                for i in range(len(column_names)):
                    if column_names[i] == column_name:
                        col_idx = i
                        break
                
                if col_idx == -1:
                    return PLValue("error", "Column '" + column_name + "' not found")
                
                # Collect distinct values
                var distinct_values = List[String]()
                for row in filtered_data:
                    if col_idx < len(row):
                        var value = row[col_idx]
                        var found = False
                        for existing in distinct_values:
                            if existing == value:
                                found = True
                                break
                        if not found:
                            distinct_values.append(value)
                
                # Format as array
                var result = "["
                for i in range(len(distinct_values)):
                    if i > 0:
                        result += ", "
                    result += "\"" + distinct_values[i] + "\""
                result += "]"
                
                return PLValue("array", result)
            else:
                return PLValue("error", "DISTINCT requires a column name")
        else:
            # Handle other aggregation functions (Count, Sum, etc.)
            return PLValue("error", "Aggregation function '" + function + "' not yet implemented for array aggregation")

    fn eval_let_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate LET statement: (LET var_name value)"""
        if len(node.children) != 2:
            return PLValue("error", "LET requires variable name and value")

        var var_name = node.children[0].value
        var value_expr = self.evaluate(node.children[1], env, orc_storage)

        env.define(var_name, value_expr)
        return value_expr

    fn eval_while_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate WHILE loop."""
        if len(node.children) < 2:
            return PLValue("error", "WHILE requires condition and body")

        var result = PLValue("null", "null")
        
        while True:
            # Evaluate condition
            var condition = self.evaluate(node.children[0], env, orc_storage)
            if condition.type != "boolean" or condition.value != "true":
                break
            
            # Execute body
            result = self.evaluate(node.children[1], env, orc_storage)
            
            # Check for recursion depth to prevent infinite loops
            self.recursion_depth += 1
            if self.recursion_depth > 10000:
                return PLValue("error", "Maximum recursion depth exceeded in while loop")

        self.recursion_depth -= 1
        return result

    fn eval_block_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate a block of statements."""
        var result = PLValue("null", "null")
        
        for child in node.children:
            result = self.evaluate(child, env, orc_storage)
            # Could add break/continue handling here if needed
        
        return result

    fn eval_block_with_loop_control(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate a block of statements with loop control flow handling."""
        var result = PLValue("null", "null")
        
        # If it's a single statement (not a BLOCK), evaluate it directly
        if node.node_type != "BLOCK":
            result = self.evaluate(node, env, orc_storage)
            return result
        
        # Evaluate each statement in the block
        for child in node.children:
            result = self.evaluate(child, env, orc_storage)
            # Check for loop control statements
            if result.type == "break" or result.type == "continue":
                return result
        
        return result

    fn eval_function_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate function definition."""
        var func_name = node.get_attribute("name")
        if func_name == "":
            return PLValue("error", "Function definition requires name")

        # Store function definition in environment
        env.define(func_name, PLValue("function", node.value))
        return PLValue("string", "function " + func_name + " defined")

    fn eval_call_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate function call."""
        var func_name = node.get_attribute("name")
        if func_name == "":
            return PLValue("error", "Function call requires name")

        # Check for built-in functions first
        if func_name == "len":
            return self.eval_builtin_len(node, env, orc_storage)
        elif func_name == "print":
            return self.eval_builtin_print(node, env, orc_storage)
        elif func_name == "abs":
            return self.eval_builtin_abs(node, env, orc_storage)
        elif func_name == "sqrt":
            return self.eval_builtin_sqrt(node, env, orc_storage)

        # Get function definition from environment
        var func_def = env.get(func_name)
        if func_def.type != "function":
            return PLValue("error", "Undefined function: " + func_name)

        # For user-defined functions, we need to execute the function body
        # The function definition is stored as the AST node value
        # We need to parse this back or store it differently
        # For now, return a placeholder
        return PLValue("string", "function " + func_name + " called with " + String(len(node.children)) + " arguments")

    fn eval_index_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate indexing operation: list[index]."""
        if len(node.children) != 2:
            return PLValue("error", "Index operation requires target and index")

        var target = self.evaluate(node.children[0], env, orc_storage)
        var index = self.evaluate(node.children[1], env, orc_storage)

        # For now, handle basic list indexing
        if target.type == "list" and index.type == "number":
            # Parse the list string representation to extract elements
            var list_str = target.value
            if list_str.startswith("[") and list_str.endswith("]"):
                var content = list_str[1:list_str.__len__() - 1]
                if content == "":
                    return PLValue("error", "Index out of bounds: empty list")

                # Split by comma and find the element
                var elements = content.split(",")
                var idx = atol(index.value)

                if idx < 0:
                    idx = len(elements) + idx  # Handle negative indexing

                if idx >= 0 and idx < len(elements):
                    var element_str = elements[idx]
                    # Try to parse as number first, then string
                    try:
                        _ = atol(String(element_str))
                        return PLValue("number", String(element_str))
                    except:
                        var trimmed = String(element_str).strip()
                        if trimmed.startswith("\"") and trimmed.endswith("\""):
                            return PLValue("string", String(trimmed[1:len(trimmed) - 1]))
                        else:
                            return PLValue("string", String(trimmed))
                else:
                    return PLValue("error", "Index out of bounds: " + String(idx))
            else:
                return PLValue("error", "Invalid list format")
        else:
            return PLValue("error", "Index operation requires list and number index")

    fn eval_builtin_len(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate len() built-in function."""
        if len(node.children) != 1:
            return PLValue("error", "len() requires exactly 1 argument")

        var arg = self.evaluate(node.children[0], env, orc_storage)
        if arg.type == "list":
            # Parse list string to count elements
            var list_str = arg.value
            if list_str == "[]":
                return PLValue("number", "0")
            # Count commas + 1 for non-empty lists
            var count = 1
            for i in range(len(list_str)):
                if list_str[i] == ",":
                    count += 1
            return PLValue("number", String(count))
        elif arg.type == "string":
            return PLValue("number", String(len(arg.value)))
        else:
            return PLValue("error", "len() can only be applied to lists or strings")

    fn eval_builtin_print(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate print() built-in function."""
        var result = ""
        for i in range(len(node.children)):
            if i > 0:
                result += " "
            var arg = self.evaluate(node.children[i], env, orc_storage)
            result += arg.value

        print(result)
        return PLValue("string", result)

    fn eval_builtin_abs(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate abs() built-in function."""
        if len(node.children) != 1:
            return PLValue("error", "abs() requires exactly 1 argument")

        var arg = self.evaluate(node.children[0], env, orc_storage)
        if arg.type == "number":
            try:
                var num = atol(arg.value)
                var abs_val = num if num >= 0 else -num
                return PLValue("number", String(abs_val))
            except:
                return PLValue("error", "Invalid number for abs()")
        else:
            return PLValue("error", "abs() requires a number argument")

    fn eval_builtin_sqrt(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate sqrt() built-in function."""
        if len(node.children) != 1:
            return PLValue("error", "sqrt() requires exactly 1 argument")

        var arg = self.evaluate(node.children[0], env, orc_storage)
        if arg.type == "number":
            try:
                var num = atol(arg.value)
                if num < 0:
                    return PLValue("error", "sqrt() requires non-negative number")
                # Simple integer square root approximation
                var result = 0
                var i = 1
                while i * i <= num:
                    result = i
                    i += 1
                return PLValue("number", String(result))
            except:
                return PLValue("error", "Invalid number for sqrt()")
        else:
            return PLValue("error", "sqrt() requires a number argument")

    fn eval_type_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate TYPE statement (currently only TYPE SECRET)."""
        var type_attr = node.get_attribute("type")
        if type_attr == "SECRET":
            return self.eval_type_secret_node(node, env, orc_storage)
        else:
            return PLValue("error", "Unknown TYPE: " + type_attr)

    fn eval_type_secret_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate TYPE SECRET statement."""
        var secret_name = node.get_attribute("name")
        if secret_name == "":
            return PLValue("error", "Secret name is required")
        
        # Collect key-value pairs
        var secrets = Dict[String, String]()
        for child in node.children:
            if child.node_type == "KEY_VALUE":
                var key = child.get_attribute("key")
                var value = child.get_attribute("value")
                if key != "" and value != "":
                    # TODO: Implement proper encryption here
                    # For now, using simple base64-like encoding as placeholder
                    secrets[key] = self.simple_encrypt(value)
        
        # Store secret in schema manager (per-database storage)
        _ = orc_storage.schema_manager.store_secret(secret_name, secrets)
        
        return PLValue("string", "Secret '" + secret_name + "' defined")

    fn eval_attach_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate ATTACH statement."""
        var db_path = node.get_attribute("path")
        var `alias` = node.get_attribute("alias")
        
        if db_path == "":
            return PLValue("error", "Path is required")
        
        if `alias` == "":
            return PLValue("error", "Alias is required")
        
        # Check if it's a SQL file (ends with .sql)
        if db_path.endswith(".sql"):
            # Handle SQL file attachment
            var attached_sqls = orc_storage.schema_manager.list_attached_sql_files()
            if `alias` in attached_sqls:
                return PLValue("error", "SQL file alias '" + `alias` + "' is already attached")
            
            # Attach the SQL file
            if orc_storage.schema_manager.attach_sql_file(`alias`, db_path):
                return PLValue("string", "SQL file '" + `alias` + "' attached successfully from '" + db_path + "'")
            else:
                return PLValue("error", "Failed to attach SQL file '" + `alias` + "' from '" + db_path + "'")
        else:
            # Handle database attachment
            var attached_dbs = orc_storage.schema_manager.list_attached_databases()
            if `alias` in attached_dbs:
                return PLValue("error", "Database alias '" + `alias` + "' is already attached")
            
            # Attach the database
            if orc_storage.schema_manager.attach_database(`alias`, db_path):
                return PLValue("string", "Database '" + `alias` + "' attached successfully from '" + db_path + "'")
            else:
                return PLValue("error", "Failed to attach database '" + `alias` + "' from '" + db_path + "'")

    fn eval_detach_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate DETACH statement."""
        var `alias` = node.get_attribute("name")
        
        if `alias` == "":
            return PLValue("error", "Database alias is required")
        
        # Check if alias exists
        var attached_dbs = orc_storage.schema_manager.list_attached_databases()
        if `alias` not in attached_dbs:
            return PLValue("error", "Database alias '" + `alias` + "' is not attached")
        
        # Detach the database
        if orc_storage.schema_manager.detach_database(`alias`):
            return PLValue("string", "Database '" + `alias` + "' detached successfully")
        else:
            return PLValue("error", "Failed to detach database '" + `alias` + "'")

    fn eval_execute_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate EXECUTE statement."""
        var `alias` = node.get_attribute("alias")
        
        if `alias` == "":
            return PLValue("error", "SQL file alias is required")
        
        # Check if SQL file alias exists
        var attached_sqls = orc_storage.schema_manager.list_attached_sql_files()
        if `alias` not in attached_sqls:
            return PLValue("error", "SQL file alias '" + `alias` + "' is not attached")
        
        # Get the file path
        var file_path = attached_sqls[`alias`]
        
        # Read the SQL file content using Python interop
        try:
            var sql_content = self._read_file_content(file_path)
            
            # Tokenize and parse the SQL content
            var lexer = PLGrizzlyLexer(sql_content)
            var tokens = lexer.tokenize()
            var parser = PLGrizzlyParser(tokens)
            var ast = parser.parse()
            
            # Execute the parsed AST
            var result = self.evaluate(ast, env, orc_storage)
            
            return PLValue("string", "SQL file '" + `alias` + "' executed successfully")
            
        except:
            return PLValue("error", "Failed to execute SQL file '" + `alias` + "' from '" + file_path + "'")

    fn eval_show_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate SHOW statement."""
        var show_type = node.get_attribute("type")
        if show_type == "SECRETS":
            var secrets = orc_storage.schema_manager.list_secrets()
            var result = "Available secrets:\n"
            for secret_name in secrets:
                result += "- " + secret_name + "\n"
            return PLValue("string", result)
        elif show_type == "ATTACHED_DATABASES":
            var attached_dbs = orc_storage.schema_manager.list_attached_databases()
            var result = "Attached databases:\n"
            var aliases = List[String]()
            for `alias` in attached_dbs.keys():
                aliases.append(`alias`)
            for `alias` in aliases:
                var path = attached_dbs[`alias`]
                result += "- " + `alias` + " -> " + path + "\n"
            if len(aliases) == 0:
                result += "(none)\n"
            return PLValue("string", result)
        else:
            return PLValue("error", "Unknown SHOW type: " + show_type)

    fn eval_drop_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate DROP statement."""
        var drop_type = node.get_attribute("type")
        if drop_type == "SECRET":
            return self.eval_drop_secret_node(node, env, orc_storage)
        elif drop_type == "INDEX":
            return self.eval_drop_index_node(node, env, orc_storage)
        elif drop_type == "VIEW":
            return self.eval_drop_view_node(node, env, orc_storage)
        else:
            return PLValue("error", "Unknown DROP type: " + drop_type)

    fn eval_drop_secret_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate DROP SECRET statement."""
        var secret_name = node.get_attribute("name")
        if secret_name == "":
            return PLValue("error", "Secret name is required")
        
        var success = orc_storage.schema_manager.delete_secret(secret_name)
        if success:
            return PLValue("string", "Secret '" + secret_name + "' deleted")
        else:
            return PLValue("error", "Secret '" + secret_name + "' not found")

    fn eval_drop_index_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate DROP INDEX statement."""
        var index_name = node.get_attribute("name")
        # TODO: Implement index dropping logic
        return PLValue("string", "Index '" + index_name + "' dropped (not yet implemented)")

    fn eval_drop_view_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate DROP VIEW statement."""
        var view_name = node.get_attribute("name")
        # TODO: Implement view dropping logic
        return PLValue("string", "View '" + view_name + "' dropped (not yet implemented)")

    fn simple_encrypt(mut self, value: String) -> String:
        """Simple encryption placeholder - TODO: Replace with proper AES encryption."""
        # This is just a placeholder - in production, use proper encryption
        var encrypted = ""
        for i in range(len(value)):
            var char = ord(value[i])
            # Simple XOR with a key for demonstration
            var encrypted_char = char ^ 0x5A
            encrypted += chr(encrypted_char)
        return encrypted

    fn simple_decrypt(mut self, value: String) -> String:
        """Simple decryption placeholder - TODO: Replace with proper AES decryption."""
        # This is just a placeholder - in production, use proper decryption
        return self.simple_encrypt(value)  # XOR is symmetric

    fn _read_file_content(mut self, file_path: String) raises -> String:
        """Read content from a file using Python interop."""
        try:
            var py_file = Python.evaluate("open('" + file_path + "', 'r')")
            var content = py_file.read()
            py_file.close()
            return String(content)
        except:
            raise Error("Failed to read file: " + file_path)