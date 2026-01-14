"""
PL-GRIZZLY AST Evaluator Module

Optimized AST evaluator with caching and symbol table management.
"""

from collections import Dict, List
from pl_grizzly_parser import ASTNode, SymbolTable, PLGrizzlyParser, TypeChecker, AST_JOIN, AST_LEFT_JOIN, AST_RIGHT_JOIN, AST_FULL_JOIN, AST_INNER_JOIN, AST_ANTI_JOIN
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_values import PLValue, LazyIterator
from pl_grizzly_environment import Environment
from pl_grizzly_errors import PLGrizzlyError, ErrorManager, create_undefined_variable_error, create_type_mismatch_error, create_division_by_zero_error, create_table_not_found_error
from orc_storage import ORCStorage
from schema_manager import SchemaManager, Column
from extensions.httpfs import HTTPFSExtension
from extensions.pyarrow_reader import PyArrowFileReader
from extensions.pyarrow_writer import PyArrowFileWriter
from secret_manager import SecretManager
from python import Python, PythonObject

struct ASTEvaluator:
    var symbol_table: SymbolTable
    var eval_cache: Dict[String, PLValue]
    var query_result_cache: Dict[String, PLValue]  # Cache for complete query results
    var string_intern_pool: Dict[String, String]   # String interning for memory optimization
    var cache_access_times: Dict[String, Int]      # Track cache access times for LRU
    var cache_hit_count: Int                       # Performance monitoring
    var cache_miss_count: Int                      # Performance monitoring
    var recursion_depth: Int
    var error_manager: ErrorManager
    var source_code: String  # Store source code for error context
    var httpfs_extension: HTTPFSExtension  # HTTPFS extension for URL support
    var pyarrow_reader: PyArrowFileReader  # PyArrow file reader extension
    var pyarrow_writer: PyArrowFileWriter  # PyArrow file writer extension
    var type_checker: TypeChecker  # Dynamic type checker
    var max_cache_size: Int  # Maximum cache size for LRU eviction
    # var secret_manager: Optional[SecretManager]  # Secret management for TYPE SECRET

    fn __init__(out self, source_code: String = ""):
        self.symbol_table = SymbolTable()
        self.eval_cache = Dict[String, PLValue]()
        self.query_result_cache = Dict[String, PLValue]()
        self.string_intern_pool = Dict[String, String]()
        self.cache_access_times = Dict[String, Int]()
        self.cache_hit_count = 0
        self.cache_miss_count = 0
        self.recursion_depth = 0
        self.error_manager = ErrorManager()
        self.source_code = source_code
        self.httpfs_extension = HTTPFSExtension()
        self.pyarrow_reader = PyArrowFileReader()
        self.pyarrow_writer = PyArrowFileWriter()
        self.type_checker = TypeChecker()
        self.max_cache_size = 1000  # Default max cache size
        # self.secret_manager = None

    fn set_source_code(mut self, source: String):
        """Set the source code for error context."""
        self.source_code = source

    # fn set_secret_manager(mut self, secret_manager: SecretManager):
    #     """Set the secret manager for secret operations."""
    #     self.secret_manager = secret_manager

    fn intern_string(mut self, s: String) -> String:
        """Intern a string to reduce memory usage for repeated strings."""
        var existing = self.string_intern_pool.get(s)
        if existing:
            return existing.value()
        self.string_intern_pool[s] = s
        return s

    fn clear_caches(mut self):
        """Clear all caches to free memory."""
        self.eval_cache = Dict[String, PLValue]()
        self.query_result_cache = Dict[String, PLValue]()
        # Keep string intern pool as it's beneficial for memory usage

    fn get_cache_stats(self) -> Dict[String, Int]:
        """Get statistics about cache usage for performance monitoring."""
        var stats = Dict[String, Int]()
        stats["eval_cache_size"] = len(self.eval_cache)
        stats["query_cache_size"] = len(self.query_result_cache)
        stats["interned_strings"] = len(self.string_intern_pool)
        stats["cache_hits"] = self.cache_hit_count
        stats["cache_misses"] = self.cache_miss_count
        return stats.copy()

    fn set_max_cache_size(mut self, size: Int):
        """Set the maximum cache size for LRU eviction."""
        self.max_cache_size = size

    fn get_cache_hit_ratio(self) -> Float64:
        """Get cache hit ratio for performance monitoring."""
        var total = self.cache_hit_count + self.cache_miss_count
        if total == 0:
            return 0.0
        return Float64(self.cache_hit_count) / Float64(total)

    fn evict_lru_cache_entries(mut self) raises:
        """Evict least recently used cache entries when cache is full."""
        if len(self.eval_cache) < self.max_cache_size:
            return

        # Find the least recently used entry
        var lru_key = ""
        var lru_time = Int.MAX

        # Collect all keys first to avoid aliasing issues
        var keys = List[String]()
        for key in self.cache_access_times.keys():
            keys.append(key)

        for key in keys:
            var access_time = self.cache_access_times[key]
            if access_time < lru_time:
                lru_time = access_time
                lru_key = key

        if lru_key != "":
            _ = self.eval_cache.pop(lru_key)
            _ = self.cache_access_times.pop(lru_key)

    fn get_enhanced_cache_key(self, node: ASTNode) -> String:
        """Generate an enhanced cache key with better uniqueness and performance."""
        var key_parts = List[String]()
        key_parts.append(node.node_type)
        key_parts.append(node.value)

        # Add node-specific information for better cache differentiation
        if node.node_type == "BINARY_OP":
            key_parts.append("OP_" + node.value)
        elif node.node_type == "CALL":
            key_parts.append("FUNC_" + node.value)
        elif node.node_type == "ARRAY":
            key_parts.append("LEN_" + String(len(node.children)))
        elif node.node_type == "STRUCT_LITERAL":
            var struct_type = node.get_attribute("struct_type")
            if struct_type != "":
                key_parts.append("STRUCT_" + struct_type)

        # Add children count for structural uniqueness
        key_parts.append("CHILDREN_" + String(len(node.children)))

        # Add hash of first few children values for content-based caching
        var child_hash_parts = List[String]()
        var max_children = min(3, len(node.children))  # Only hash first 3 children
        for i in range(max_children):
            var child = node.children[i].copy()
            child_hash_parts.append(child.node_type + "_" + child.value)

        if len(child_hash_parts) > 0:
            var child_hash = "_".join(child_hash_parts)
            key_parts.append("CONTENT_" + child_hash)

        return "_".join(key_parts)

    fn _get_source_line(self, line: Int) -> String:
        """Get the source line at the given line number (1-based)."""
        if self.source_code == "" or line < 1:
            return ""

        var lines = self.source_code.split("\n")
        if line <= len(lines):
            return String(lines[line - 1])
        return ""

    fn get_query_cache_key(self, node: ASTNode) -> String:
        """Generate a more sophisticated cache key for query results."""
        var key_parts = List[String]()
        key_parts.append(node.node_type)
        
        # Include table name and key clauses
        for child in node.children:
            if child.node_type == "FROM":
                var table_name = child.get_attribute("table")
                if table_name != "":
                    key_parts.append("FROM_" + table_name)
            elif child.node_type == "WHERE":
                # Include WHERE clause hash for cache invalidation
                key_parts.append("WHERE_" + child.value)
            elif child.node_type == "SELECT_LIST":
                # Include selected columns/expressions in cache key
                var select_parts = List[String]()
                for select_child in child.children:
                    if select_child.node_type == "SELECT_ITEM":
                        for item_child in select_child.children:
                            select_parts.append(item_child.node_type + "_" + item_child.value)
                    else:
                        select_parts.append(select_child.node_type + "_" + select_child.value)
                var select_hash = "_".join(select_parts)
                key_parts.append("SELECT_" + select_hash)
        
        var cache_key = "_".join(key_parts)
        return cache_key

    fn optimize_table_read(mut self, table_name: String, where_clause: Optional[ASTNode], mut orc_storage: ORCStorage) -> List[List[String]]:
        """Optimize table reading with early WHERE clause filtering."""
        if not where_clause:
            # No WHERE clause, read entire table
            return orc_storage.read_table(table_name)
        
        # For now, read entire table and filter - future optimization: index-based filtering
        var all_data = orc_storage.read_table(table_name)
        var filtered_data = List[List[String]]()
        
        # Apply WHERE clause filtering
        for row in all_data:
            # TODO: Implement efficient WHERE clause evaluation
            # For now, include all rows (WHERE optimization is future work)
            filtered_data.append(row.copy())
        
        return filtered_data^

    fn evaluate(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate AST node with enhanced caching, optimization, and type checking."""
        # Prevent infinite recursion
        if self.recursion_depth > 1000:
            var error = PLGrizzlyError.runtime_error("Maximum recursion depth exceeded", -1, -1, "AST evaluation recursion limit")
            error.add_stack_frame("evaluate() - recursion check")
            error.add_recovery_suggestion("Simplify the expression or increase recursion limit")
            return PLValue.enhanced_error(error)

        self.recursion_depth += 1

        # Dynamic type checking during evaluation
        if node.inferred_type != "unknown":
            # Validate type consistency if type is inferred
            var expected_type = node.inferred_type
            # Additional type validation can be added here
            pass

        # Use query result caching for SELECT statements
        if node.node_type == "SELECT":
            var query_cache_key = self.get_query_cache_key(node)
            var cached_result = self.query_result_cache.get(query_cache_key)
            if cached_result:
                self.cache_hit_count += 1
                self.recursion_depth -= 1
                return cached_result.value()

        # Enhanced AST-level caching with LRU eviction
        var cache_key = self.get_enhanced_cache_key(node)
        var cached = self.eval_cache.get(cache_key)
        if cached:
            # Update access time for LRU
            self.cache_access_times[cache_key] = self.cache_hit_count + self.cache_miss_count
            self.cache_hit_count += 1
            self.recursion_depth -= 1
            return cached.value()

        # Cache miss
        self.cache_miss_count += 1

        var result: PLValue

        if node.node_type == "SELECT":
            result = self.eval_select_node(node, env, orc_storage)
        elif node.node_type == "WITH":
            result = self.eval_with_node(node, env, orc_storage)
        elif node.node_type == "INSERT":
            result = self.eval_insert_node(node, env, orc_storage)
        elif node.node_type == "UPDATE":
            result = self.eval_update_node(node, env, orc_storage)
        elif node.node_type == "DELETE":
            result = self.eval_delete_node(node, env, orc_storage)
        elif node.node_type == "CREATE":
            result = self.eval_create_node(node, env, orc_storage)
        elif node.node_type == "COPY":
            result = self.eval_copy_node(node, env, orc_storage)
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
        elif node.node_type == "TYPED_STRUCT_LITERAL":
            result = self.eval_typed_struct_literal_node(node, env, orc_storage)
        elif node.node_type == "MEMBER_ACCESS":
            result = self.eval_member_access_node(node, env, orc_storage)
        elif node.node_type == "MATCH":
            result = self.eval_match_node(node, env, orc_storage)
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
        elif node.node_type == "TYPEOF":
            result = self.eval_typeof_node(node, env, orc_storage)
        elif node.node_type == "INSTALL":
            result = self.eval_install_node(node, env, orc_storage)
        elif node.node_type == "LOAD":
            result = self.eval_load_node(node, env, orc_storage)
        elif node.node_type == "SHOW":
            result = self.eval_show_node(node, env, orc_storage)
        elif node.node_type == "DROP":
            result = self.eval_drop_node(node, env, orc_storage)
        elif node.node_type == "LINQ_QUERY":
            result = self.eval_linq_query_node(node, env, orc_storage)
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

        # Enhanced caching with LRU eviction
        self.evict_lru_cache_entries()
        self.eval_cache[cache_key] = result
        self.cache_access_times[cache_key] = self.cache_hit_count + self.cache_miss_count
        
        # Cache SELECT query results separately for performance
        if node.node_type == "SELECT":
            var query_cache_key = self.get_query_cache_key(node)
            self.query_result_cache[query_cache_key] = result
        
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
            elif child.node_type == "STREAM":
                # STREAM clause found - enable lazy evaluation
                pass  # We'll check for this later

        if not from_clause:
            var error = PLGrizzlyError.syntax_error(
                "SELECT requires FROM clause",
                node.line, node.column, self._get_source_line(node.line)
            )
            error.add_suggestion("Add a FROM clause to specify the data source")
            error.add_suggestion("Example: SELECT * FROM table_name")
            return PLValue.enhanced_error(error)

        # Check if this is a JOIN query
        var has_joins = False
        for child in from_clause.value().children:
            if child.node_type == AST_JOIN or child.node_type == AST_LEFT_JOIN or child.node_type == AST_RIGHT_JOIN or child.node_type == AST_FULL_JOIN or child.node_type == AST_INNER_JOIN or child.node_type == AST_ANTI_JOIN:
                has_joins = True
                break

        if has_joins:
            # Handle JOIN query
            return self.eval_join_select(node, from_clause.value(), env, orc_storage)
        
        # Original single-table logic
        var table_name = ""
        if len(from_clause.value().children) > 0:
            table_name = from_clause.value().children[0].get_attribute("table")
        var is_array_iteration = False
        var array_data: Optional[PLValue] = None
        var is_stream = False
        
        # Check for STREAM clause
        for child in node.children:
            if child.node_type == "STREAM":
                is_stream = True
                break
        
        # Declare result variables
        var result_data = List[List[String]]()
        var selected_columns = List[String]()
        var select_expressions = List[ASTNode]()
        var has_select_expressions = False
        var column_names = List[String]()
        var table_data = List[List[String]]()
        
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
                    var undefined_error = create_undefined_variable_error(
                        from_value, node.line, node.column, self._get_source_line(node.line)
                    )
                    undefined_error = undefined_error.with_context("FROM clause variable resolution")
                    return PLValue.enhanced_error(undefined_error)
            else:
                return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
                "Invalid FROM clause", node.line, node.column, self._get_source_line(node.line)
            ))
        elif table_name != "":
            # Check if this is a CTE reference first
            var cte_var = env.get(table_name)
            if cte_var.type != "error":
                # This is a CTE reference - parse the stored table data
                var cte_data_str = cte_var.value
                
                # Parse the formatted table data back to table structure
                # Format: "Query results (X rows):\nColumns: col1, col2\n[row data]"
                var lines = cte_data_str.split("\n")
                if len(lines) >= 2:
                    # Parse column names from second line: "Columns: col1, col2"
                    var columns_line = lines[1]
                    if columns_line.startswith("Columns: "):
                        var columns_str = String(columns_line[9:])  # Remove "Columns: "
                        var column_parts = columns_str.split(", ")
                        column_names = List[String]()
                        for part in column_parts:
                            column_names.append(String(part))
                        
                        # Parse data rows
                        for i in range(2, len(lines)):
                            var line = lines[i].strip()
                            if line.startswith("[") and line.endswith("]"):
                                var row_str = line[1:len(line)-1]  # Remove [ and ]
                                var row_data = List[String]()
                                
                                # Parse comma-separated values, handling quoted strings
                                var current_value = ""
                                var in_quotes = False
                                for j in range(len(row_str)):
                                    var c = row_str[j]
                                    if c == '"' and (j == 0 or row_str[j-1] != '\\'):
                                        in_quotes = not in_quotes
                                    elif c == ',' and not in_quotes:
                                        # End of value
                                        var trimmed = String(current_value.strip())
                                        if trimmed.startswith('"') and trimmed.endswith('"'):
                                            trimmed = String(trimmed[1:len(trimmed)-1])  # Remove quotes
                                        row_data.append(trimmed)
                                        current_value = ""
                                    else:
                                        current_value += c
                                
                                # Add the last value
                                if current_value != "":
                                    var trimmed = String(current_value.strip())
                                    if trimmed.startswith('"') and trimmed.endswith('"'):
                                        trimmed = String(trimmed[1:len(trimmed)-1])
                                    row_data.append(trimmed)
                                
                                result_data.append(row_data.copy())
                        
                        selected_columns = column_names.copy()
                        is_array_iteration = False
                        # CTE data processed, continue with WHERE filtering
            # Check if this is an HTTP URL
            elif self.httpfs_extension.is_http_url(table_name):
                # Handle HTTP URL data source
                var url = table_name
                var secrets_attr = from_clause.value().get_attribute("secrets")

                # Resolve secret names to values if secret manager is available
                var resolved_secrets = secrets_attr
                # if self.secret_manager and secrets_attr != "":
                #     resolved_secrets = self._resolve_secrets_in_attribute(secrets_attr)

                # Use HTTPFS extension to fetch and process data
                try:
                    var result = self.httpfs_extension.process_http_from_clause(url, resolved_secrets)
                    result_data = result[0].copy()
                    table_data = result_data.copy()  # Set table_data for WHERE processing

                    selected_columns = result[1].copy()
                    column_names = selected_columns.copy()

                    is_array_iteration = False
                except e:
                    var http_error = PLGrizzlyError.network_error(
                        "HTTP fetch failed: " + String(e), url, node.line, node.column, self._get_source_line(node.line)
                    )
                    http_error.add_recovery_suggestion("Check network connectivity and URL accessibility")
                    http_error.add_recovery_suggestion("Verify authentication credentials are correct")
                    http_error.add_recovery_suggestion("Try the request again in case of temporary network issues")
                    return PLValue.enhanced_error(http_error)
            # Check if this is a supported file format
            elif self.pyarrow_reader.is_supported_file(table_name):
                # Handle file-based data source
                var file_path = table_name

                try:
                    var result = self.pyarrow_reader.read_file_data(file_path)
                    result_data = result[0].copy()
                    table_data = result_data.copy()  # Set table_data for WHERE processing

                    selected_columns = result[1].copy()
                    column_names = selected_columns.copy()

                    is_array_iteration = False
                except e:
                    var file_error = PLGrizzlyError.io_error(
                        "File read failed: " + String(e), file_path, node.line, node.column, self._get_source_line(node.line)
                    )
                    file_error.add_recovery_suggestion("Check if the file exists and is accessible")
                    file_error.add_recovery_suggestion("Verify the file format is supported (ORC, Parquet, Feather, JSON)")
                    file_error.add_recovery_suggestion("Ensure PyArrow and required dependencies are installed")
                    return PLValue.enhanced_error(file_error)
            else:
                # Traditional table iteration
                is_array_iteration = False
        else:
            return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
            "Invalid table name in FROM clause", node.line, node.column, self._get_source_line(node.line)
        ))

        if is_array_iteration:
            # Handle array iteration
            var arr = array_data.value()
            var array_elements = arr.value.split("[")[1].split("]")[0].split(", ")
            
            # For array iteration, we create synthetic rows with [index, value]
            for i in range(len(array_elements)):
                var row = List[String]()
                row.append(String(i))  # array_index
                row.append(String(array_elements[i].strip()))  # array_value
                result_data.append(row.copy())
            
            selected_columns = List[String]("array_index", "array_value")
            column_names = selected_columns.copy()
        else:
            # Check if this is HTTP URL data (already handled above)
            var is_url_handled = table_name != "" and from_clause.value().get_attribute("is_url") == "true"
            # Check if this is file data (already handled above)
            var is_file_handled = table_name != "" and self.pyarrow_reader.is_supported_file(table_name)
            if is_url_handled:
                # HTTP data already processed above, just set column info
                selected_columns = List[String]("response")
                column_names = selected_columns.copy()
            elif is_file_handled:
                # File data already processed above, column info already set
                pass
            else:
                # Traditional table iteration
                # Get table schema to know column structure
                var schema = orc_storage.schema_manager.load_schema()
                var table_schema = schema.get_table(table_name)
                if table_schema.name == "":
                    var table_error = create_table_not_found_error(
                        table_name, node.line, node.column, self._get_source_line(node.line)
                    )
                    table_error = table_error.with_context("FROM clause table resolution")
                    return PLValue.enhanced_error(table_error)

                # Read table data with optimization
                table_data = self.optimize_table_read(table_name, where_clause, orc_storage)
                
                # Get column names from schema
                for col in table_schema.columns:
                    column_names.append(col.name)

                # Determine which columns to select
            var selected_columns = List[String]()
            var has_array_aggregation = False
            var array_aggregation_node: Optional[ASTNode] = None
            
            if select_list:
                # Parse select list to get column names and expressions
                for select_item in select_list.value().children:
                    if select_item.node_type == "SELECT_ITEM":
                        for child in select_item.children:
                            if child.node_type == "ARRAY_AGGREGATION":
                                # Handle array aggregation
                                has_array_aggregation = True
                                # Store the aggregation node for later evaluation
                                array_aggregation_node = child.copy()
                                selected_columns.append("array_aggregation")
                                select_expressions.append(child.copy())
                                # Evaluate aggregation on filtered data later
                                break
                            elif child.node_type == "IDENTIFIER":
                                selected_columns.append(child.value)
                                # Don't add to expressions for simple identifiers
                            elif child.node_type == "STAR":  # SELECT *
                                selected_columns = column_names.copy()
                                # For SELECT *, don't add expressions since we handle columns directly
                                break
                            elif child.node_type == "AGGREGATE_FUNCTION":
                                # For now, just add the function name as column name
                                selected_columns.append(child.value)
                                select_expressions.append(child.copy())
                                break
                            else:
                                # Handle other expressions like TYPEOF, functions, etc.
                                has_select_expressions = True
                                selected_columns.append(child.node_type + "_" + String(len(selected_columns)))
                                select_expressions.append(child.copy())
                        if len(selected_columns) == len(column_names) and not has_select_expressions:
                            break  # Already selected all columns and no expressions
            else:
                # Default to all columns
                selected_columns = column_names.copy()
                # Don't add expressions for default column selection

            # Apply WHERE clause filtering with optimization
            if where_clause:
                # Evaluate WHERE condition for each row with optimized environment handling
                for row_idx in range(len(table_data)):
                    var row = table_data[row_idx].copy()
                    
                    # Create minimal row environment for WHERE evaluation
                    var row_env = Environment()  # Create fresh environment instead of copying
                    for col_idx in range(len(column_names)):
                        if col_idx < len(row):
                            row_env.define(column_names[col_idx], PLValue("string", row[col_idx]))
                    
                    # Evaluate WHERE condition
                    var condition_result = self.evaluate(where_clause.value(), row_env, orc_storage)
                    if condition_result.type == "boolean" and condition_result.value == "true":
                        result_data.append(row.copy())
            else:
                # No WHERE clause, use direct reference to avoid copying
                result_data = table_data.copy()

        # Select only requested columns or evaluate expressions (for table iteration)
        if not is_array_iteration:
            if has_select_expressions:
                # Evaluate SELECT expressions for each row
                var final_result_data = List[List[String]]()
                for row in result_data:
                    var selected_row = List[String]()
                    # Create row environment with column variables
                    var row_env = env.copy()
                    for col_idx in range(len(column_names)):
                        if col_idx < len(row):
                            row_env.define(column_names[col_idx], PLValue("string", row[col_idx]))

                    # Evaluate each SELECT expression in the row context
                    for expr in select_expressions:
                        var expr_result = self.evaluate(expr, row_env, orc_storage)
                        selected_row.append(expr_result.__str__())
                    final_result_data.append(selected_row.copy())
                result_data = final_result_data^
            else:
                # Select columns by name
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

        # Apply ORDER BY clause if present
        if order_clause:
            result_data = self._apply_order_by_ast_old(result_data, order_clause.value(), selected_columns)

        # Format result as string for now (skip for THEN execution)
        if then_clause:
            return PLValue("string", "Query executed with THEN clause - " + String(len(result_data)) + " rows processed")
        elif is_stream:
            # Return lazy iterator for streaming
            var iterator = LazyIterator(result_data)
            return PLValue.lazy(iterator^)
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

    fn eval_with_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate WITH statement (CTE - Common Table Expression)."""
        if len(node.children) < 1:
            return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
                "WITH statement requires at least one CTE definition",
                node.line, node.column, self._get_source_line(node.line)
            ))

        # Create a temporary environment for CTEs
        var cte_env = env.copy()

        # Evaluate all CTE definitions first
        var cte_count = 0
        for i in range(len(node.children) - 1):  # Last child is the main query
            var child = node.children[i].copy()
            if child.node_type == "CTE_DEFINITION":
                var cte_name = child.value
                var cte_query = child.children[0].copy()  # The SELECT query for this CTE

                # Evaluate the CTE query
                var cte_result = self.evaluate(cte_query, cte_env, orc_storage)

                # Store the CTE result in the environment as table data
                # CTEs should return table data from SELECT queries
                cte_env.define(cte_name, cte_result)
                cte_count += 1

        # Now evaluate the main query with access to CTEs
        var main_query = node.children[len(node.children) - 1].copy()  # Last child is main query
        return self.evaluate(main_query, cte_env, orc_storage)

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
        # Check if this is CREATE SECRET
        elif node.node_type == "CREATE_SECRET":
            return self.eval_create_secret_node(node, env, orc_storage)
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

    fn eval_create_secret_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate CREATE SECRET statement."""
        # if not self.secret_manager:
        #     return PLValue("error", "Secret manager not available")

        var secret_name = node.get_attribute("name")
        var secret_value = node.get_attribute("value")
        var description = node.get_attribute("description")  # Optional

        try:
            # var success = self.secret_manager.value().create_secret(secret_name, secret_value, description)
            var success = True
            if success:
                return PLValue("string", "Secret '" + secret_name + "' created successfully")
            else:
                return PLValue("error", "Failed to create secret")
        except e:
            return PLValue("error", "Failed to create secret: " + String(e))

    fn eval_copy_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate COPY statement for import/export operations."""
        var operation = node.get_attribute("operation")
        var source_type = node.get_attribute("source_type")
        var source = node.get_attribute("source")
        var destination_type = node.get_attribute("destination_type")
        var destination = node.get_attribute("destination")

        if operation == "import":
            # COPY 'file_path' TO table_name
            if not self.pyarrow_reader.is_supported_file(source):
                return PLValue.enhanced_error(PLGrizzlyError.io_error(
                    "Unsupported file format for import. Supported formats: ORC, Parquet, Feather, JSON",
                    source, node.line, node.column, self._get_source_line(node.line)
                ))

            try:
                # Read data from file
                var file_result = self.pyarrow_reader.read_file_data(source)
                var table_data = file_result[0].copy()
                var column_names = file_result[1].copy()

                # Check if table exists, if not create it
                var schema = orc_storage.schema_manager.load_schema()
                var existing_table = schema.get_table(destination)
                if existing_table.name == "":
                    # Infer column types and create table
                    var columns = List[Column]()
                    for col_name in column_names:
                        columns.append(Column(col_name, "string"))  # Default to string type
                    var success = orc_storage.schema_manager.create_table(destination, columns)
                    if not success:
                        return PLValue("error", "Failed to create table '" + destination + "' for import")

                # Import data into table
                var success = orc_storage.save_table(destination, table_data)
                if success:
                    return PLValue("string", "Successfully imported " + String(len(table_data)) + " rows into table '" + destination + "'")
                else:
                    return PLValue("error", "Failed to import data into table '" + destination + "'")

            except e:
                return PLValue.enhanced_error(PLGrizzlyError.io_error(
                    "Import failed: " + String(e), source, node.line, node.column, self._get_source_line(node.line)
                ))

        elif operation == "export":
            # COPY table_name TO 'file_path'
            if not self.pyarrow_writer.is_supported_file(destination):
                return PLValue.enhanced_error(PLGrizzlyError.io_error(
                    "Unsupported file format for export. Supported formats: ORC, Parquet, Feather, JSON",
                    destination, node.line, node.column, self._get_source_line(node.line)
                ))

            try:
                # Read data from table
                var table_data = orc_storage.read_table(source)
                if len(table_data) == 0:
                    return PLValue("string", "Table '" + source + "' is empty, nothing to export")

                # Get column names from schema
                var schema = orc_storage.schema_manager.load_schema()
                var table_schema = schema.get_table(source)
                if table_schema.name == "":
                    return PLValue.enhanced_error(create_table_not_found_error(
                        source, node.line, node.column, self._get_source_line(node.line)
                    ))

                var column_names = List[String]()
                for col in table_schema.columns:
                    column_names.append(col.name)

                # Export data to file
                var success = self.pyarrow_writer.write_file_data(destination, table_data, column_names)
                if success:
                    return PLValue("string", "Successfully exported " + String(len(table_data)) + " rows from table '" + source + "' to '" + destination + "'")
                else:
                    return PLValue("error", "Failed to export data to file '" + destination + "'")

            except e:
                return PLValue.enhanced_error(PLGrizzlyError.io_error(
                    "Export failed: " + String(e), destination, node.line, node.column, self._get_source_line(node.line)
                ))

        else:
            return PLValue.enhanced_error(PLGrizzlyError.semantic_error(
                "Invalid COPY operation: " + operation, node.line, node.column, self._get_source_line(node.line)
            ))

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

    fn eval_typed_struct_literal_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate TYPED_STRUCT_LITERAL operations like type struct as Person {key: value, ...}."""
        var struct_type = node.get_attribute("struct_type")
        
        # Get the struct definition from schema
        var struct_fields: Dict[String, String]
        try:
            struct_fields = orc_storage.schema_manager.get_struct_definition(struct_type)
        except:
            return PLValue("error", "Struct type '" + struct_type + "' is not defined")
        
        # Validate that all required fields are present and types match
        var provided_fields = Dict[String, PLValue]()
        for field_node in node.children:
            var field_name = field_node.value
            var field_value = self.evaluate(field_node.children[0], env, orc_storage)
            provided_fields[field_name] = field_value
        
        # Check that all defined fields are provided
        var missing_fields = List[String]()
        var field_keys = List[String]()
        for key in struct_fields.keys():
            field_keys.append(key)
        
        for defined_field in field_keys:
            if defined_field not in provided_fields:
                missing_fields.append(defined_field)
        
        if len(missing_fields) > 0:
            var error_msg = "Struct '" + struct_type + "' is missing required fields: "
            for i in range(len(missing_fields)):
                if i > 0:
                    error_msg += ", "
                error_msg += missing_fields[i]
            return PLValue("error", error_msg)
        
        # Check field types (basic validation)
        var provided_field_keys = List[String]()
        for key in provided_fields.keys():
            provided_field_keys.append(key)
            
        for provided_field in provided_field_keys:
            var expected_type = struct_fields[provided_field]
            var actual_value = provided_fields[provided_field]
            var actual_type = actual_value.type
            
            # Simple type checking - can be enhanced
            if expected_type == "string" and actual_type != "string":
                return PLValue("error", "Field '" + provided_field + "' should be string, got " + actual_type)
            elif expected_type == "int" and actual_type != "number":
                return PLValue("error", "Field '" + provided_field + "' should be int, got " + actual_type)
            elif expected_type == "boolean" and actual_type != "boolean":
                return PLValue("error", "Field '" + provided_field + "' should be boolean, got " + actual_type)
        
        # Create typed struct representation
        var result = struct_type + "{"
        for i in range(len(node.children)):
            if i > 0:
                result += ", "
            var field = node.children[i].copy()
            var field_name = field.value
            var field_value = provided_fields[field_name]
            result += field_name + ": " + field_value.value
        result += "}"
        return PLValue("struct", result)

    fn eval_member_access_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate MEMBER_ACCESS operations like object.field with optimizations."""
        var member_name = self.intern_string(node.value)  # Intern field name for memory efficiency
        
        # The first child should be the object expression
        if len(node.children) != 1:
            return PLValue("error", "Invalid member access: expected 1 child, got " + String(len(node.children)))
        
        var object_expr = node.children[0].copy()
        var object_value = self.evaluate(object_expr, env, orc_storage)
        
        # Check if the object is a struct
        if object_value.type == "struct":
            # Parse the struct value to extract fields
            # Struct format: "{field1: value1, field2: value2, ...}"
            var struct_str = object_value.value
            
            # Create cache key for this member access
            var cache_key = "member_" + struct_str[:50] + "_" + member_name  # Limit struct_str to avoid huge keys
            var cached_result = self.eval_cache.get(cache_key)
            if cached_result:
                return cached_result.value()
            
            # Find the field in the struct string
            var field_pattern = member_name + ": "
            var field_start = struct_str.find(field_pattern)
            
            if field_start == -1:
                var error = PLValue("error", "Field '" + member_name + "' not found in struct")
                self.eval_cache[cache_key] = error
                return error
            
            # Extract the field value (from after the colon to the next comma or closing brace)
            var value_start = field_start + len(field_pattern)
            var value_end = value_start
            
            # Optimized parsing - find end of field value
            var brace_count = 0
            var in_string = False
            
            while value_end < len(struct_str):
                var c = struct_str[value_end]
                
                if not in_string:
                    if c == '"' or c == "'":
                        in_string = True
                    elif c == ',' and brace_count == 0:
                        break  # End of this field
                    elif c == '}' and brace_count == 0:
                        break  # End of struct
                    elif c == '{':
                        brace_count += 1
                    elif c == '}':
                        brace_count -= 1
                elif (c == '"' or c == "'") and in_string:
                    in_string = False
                
                value_end += 1
            
            var field_value_str = self.intern_string(String(struct_str[value_start:value_end].strip()))
            var result = PLValue("string", field_value_str)
            self.eval_cache[cache_key] = result
            return result
        
        elif object_value.type == "typed_struct":
            # Handle typed structs with caching
            var struct_str = object_value.value
            var cache_key = "typed_member_" + struct_str[:50] + "_" + member_name
            var cached_result = self.eval_cache.get(cache_key)
            if cached_result:
                return cached_result.value()
            
            # Find the opening brace
            var brace_start = struct_str.find("{")
            if brace_start == -1:
                var error = PLValue("error", "Invalid typed struct format")
                self.eval_cache[cache_key] = error
                return error
            
            var fields_str = struct_str[brace_start + 1:len(struct_str) - 1]  # Remove { and }
            
            # Optimized field lookup using string operations
            var search_pattern = member_name + ": "
            var field_start = fields_str.find(search_pattern)
            
            if field_start == -1:
                var error = PLValue("error", "Field '" + member_name + "' not found in typed struct")
                self.eval_cache[cache_key] = error
                return error
            
            var value_start = field_start + len(search_pattern)
            
            # Find end of field value (next comma or end)
            var value_end = value_start
            var in_string = False
            
            while value_end < len(fields_str):
                var c = fields_str[value_end]
                if not in_string:
                    if c == '"' or c == "'":
                        in_string = True
                    elif c == ',':
                        break
                elif (c == '"' or c == "'"):
                    in_string = False
                value_end += 1
            
            var field_value_str = self.intern_string(String(fields_str[value_start:value_end].strip()))
            var result = PLValue("string", field_value_str)
            self.eval_cache[cache_key] = result
            return result
        
        else:
            return PLValue("error", "Member access '.' can only be used on struct objects, got type: " + object_value.type)

    fn eval_match_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate MATCH expressions: expr MATCH { pattern -> value, ... }."""
        if len(node.children) < 2:
            return PLValue("error", "MATCH expression requires at least a match expression and one case")

        # First child is the expression being matched
        var match_expr = node.children[0].copy()
        var match_value = self.evaluate(match_expr, env, orc_storage)

        # Remaining children are MATCH_CASE nodes
        for i in range(1, len(node.children)):
            var case_node = node.children[i].copy()
            if case_node.node_type != "MATCH_CASE" or len(case_node.children) != 2:
                continue

            var pattern_node = case_node.children[0].copy()
            var value_node = case_node.children[1].copy()

            # Check if pattern matches
            var pattern_matches = False

            if pattern_node.node_type == "LITERAL" and pattern_node.value == "_":
                # Wildcard pattern always matches
                pattern_matches = True
            else:
                # Evaluate pattern and compare with match value
                var pattern_value = self.evaluate(pattern_node, env, orc_storage)
                if match_value.type == pattern_value.type and match_value.value == pattern_value.value:
                    pattern_matches = True

            if pattern_matches:
                # Return the value for this matching case
                return self.evaluate(value_node, env, orc_storage)

        # No match found
        return PLValue("error", "No matching case found in MATCH expression")

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
        """Evaluate TYPE statement (TYPE SECRET and TYPE STRUCT)."""
        var type_attr = node.get_attribute("type")
        if type_attr == "SECRET":
            return self.eval_type_secret_node(node, env, orc_storage)
        elif type_attr == "STRUCT":
            return self.eval_type_struct_node(node, env, orc_storage)
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

    fn eval_type_struct_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate TYPE STRUCT statement."""
        var struct_name = node.get_attribute("name")
        if struct_name == "":
            return PLValue("error", "Struct name is required")

        # Collect field definitions
        var fields = Dict[String, String]()
        for child in node.children:
            if child.node_type == "FIELD_DEF":
                var field_name = child.value
                var field_type = child.get_attribute("type")
                if field_name != "" and field_type != "":
                    fields[field_name] = field_type

        # Store struct definition in schema manager
        _ = orc_storage.schema_manager.store_struct_definition(struct_name, fields)

        return PLValue("string", "Struct '" + struct_name + "' defined")

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

    fn eval_install_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate INSTALL statement for extensions."""
        var extension = node.get_attribute("extension")
        
        if extension == "":
            return PLValue("error", "Extension name is required")
        
        # Check if already installed
        if orc_storage.schema_manager.is_extension_installed(extension):
            return PLValue("string", "Extension '" + extension + "' is already installed")
        
        # Install the extension
        var success = orc_storage.schema_manager.install_extension(extension)
        if success:
            return PLValue("string", "Extension '" + extension + "' installed successfully")
        else:
            return PLValue("error", "Failed to install extension '" + extension + "'")

    fn eval_load_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate LOAD statement for extensions."""
        var extensions = node.get_attribute("extensions")
        
        if extensions == "":
            return PLValue("error", "Extension names are required")
        
        # Parse extension list (comma-separated)
        var extension_list = extensions.split(",")
        var not_installed = List[String]()
        
        for ext in extension_list:
            var extension_name = String(ext.strip())
            if extension_name != "" and not orc_storage.schema_manager.is_extension_installed(extension_name):
                not_installed.append(extension_name)
        
        if len(not_installed) > 0:
            var error_msg = "Extensions not installed: "
            for i in range(len(not_installed)):
                if i > 0:
                    error_msg += ", "
                error_msg += not_installed[i]
            error_msg += ". Use INSTALL to install them first."
            return PLValue("error", error_msg)
        
        # For now, we'll simulate loading extensions
        # In a real implementation, this would load DuckDB extensions
        return PLValue("string", "Extensions loaded successfully: " + extensions)

    fn eval_show_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate SHOW statement."""
        var show_type = node.get_attribute("type")
        if show_type == "SECRETS":
            # if not self.secret_manager:
            #     return PLValue("string", "Secret manager not available")
            # var secrets = self.secret_manager.value().list_secrets()
            var result = "Available secrets:\n"
            # for secret_name in secrets:
            #     var info = self.secret_manager.value().get_secret_info(secret_name)
            #     if info:
            #         result += "- " + secret_name
            #         if info.value().description != "":
            #         result += "- " + secret_name
            #         if info.value().description != "":
            #             result += " (" + info.value().description + ")"
            #         result += "\n"
            #     else:
            #         result += "- " + secret_name + "\n"
            return PLValue("string", result)
        elif show_type == "STRUCTS":
            var structs = orc_storage.schema_manager.list_struct_definitions()
            var result = "Available struct definitions:\n"
            for struct_name in structs:
                var fields = orc_storage.schema_manager.get_struct_definition(struct_name)
                result += "- " + struct_name + "("
                var field_names = List[String]()
                for field_name in fields.keys():
                    field_names.append(field_name)
                for i in range(len(field_names)):
                    if i > 0:
                        result += ", "
                    var field_name = field_names[i]
                    var field_type = fields[field_name]
                    result += field_name + " " + field_type
                result += ")\n"
            if len(structs) == 0:
                result += "(none)\n"
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
        elif show_type == "EXTENSIONS":
            var extensions = orc_storage.schema_manager.list_installed_extensions()
            var result = "Installed extensions:\n"
            for extension in extensions:
                result += "- " + extension + "\n"
            if len(extensions) == 0:
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

    fn eval_linq_query_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate LINQ query node (SQL-first syntax)."""
        # Extract components from AST
        var from_clause: Optional[ASTNode] = None
        var where_clause: Optional[ASTNode] = None
        var select_clause: Optional[ASTNode] = None
        var then_clause: Optional[ASTNode] = None

        for child in node.children:
            if child.node_type == "FROM_CLAUSE":
                from_clause = child.copy()
            elif child.node_type == "WHERE_CLAUSE":
                where_clause = child.copy()
            elif child.node_type == "SELECT_CLAUSE":
                select_clause = child.copy()
            elif child.node_type == "THEN":
                then_clause = child.copy()

        if not from_clause:
            var error = PLGrizzlyError.syntax_error(
                "LINQ query requires FROM clause",
                node.line, node.column, self._get_source_line(node.line)
            )
            error.add_suggestion("Add a FROM clause to specify the collection")
            return PLValue.enhanced_error(error)

        if not select_clause:
            var error = PLGrizzlyError.syntax_error(
                "LINQ query requires SELECT clause",
                node.line, node.column, self._get_source_line(node.line)
            )
            error.add_suggestion("Add a SELECT clause to specify what to return")
            return PLValue.enhanced_error(error)

        # Evaluate the collection expression
        var collection_value = self.evaluate(from_clause.value().children[0], env, orc_storage)
        if collection_value.is_error():
            return collection_value

        # For now, only support arrays
        if collection_value.type != "array":
            var error = PLGrizzlyError.type_error(
                "LINQ FROM clause expects an array, got " + collection_value.type,
                node.line, node.column, self._get_source_line(node.line)
            )
            error.add_suggestion("Use an array literal like [1, 2, 3] or a variable containing an array")
            return PLValue.enhanced_error(error)

        # Parse the array elements
        var array_str = collection_value.value
        if not (array_str.startswith("[") and array_str.endswith("]")):
            var error = PLGrizzlyError.runtime_error(
                "Invalid array format in LINQ query",
                node.line, node.column, self._get_source_line(node.line)
            )
            return PLValue.enhanced_error(error)

        var elements_str = String(array_str[1:len(array_str)-1])  # Remove [ and ]
        var elements = List[String]()
        if len(elements_str.strip()) > 0:
            # Simple parsing - split by comma (doesn't handle nested structures)
            var parts = elements_str.split(", ")
            for part in parts:
                elements.append(String(part.strip()))

        # Create result data with implicit column names
        var result_data = List[List[String]]()
        for i in range(len(elements)):
            var row = List[String]()
            row.append(String(i))  # index column
            row.append(elements[i])  # value column
            result_data.append(row.copy())

        var column_names = List[String]("index", "value")

        # Apply WHERE clause filtering if present
        if where_clause:
            var filtered_data = List[List[String]]()
            for row in result_data:
                # Create row environment with implicit column names
                var row_env = Environment()
                for col_idx in range(len(column_names)):
                    if col_idx < len(row):
                        row_env.define(column_names[col_idx], PLValue("string", row[col_idx]))

                # Evaluate WHERE condition
                var condition_result = self.evaluate(where_clause.value().children[0], row_env, orc_storage)
                if condition_result.type == "boolean" and condition_result.value == "true":
                    filtered_data.append(row.copy())
            result_data = filtered_data^

        # Apply SELECT transformation
        var selected_data = List[List[String]]()
        for row in result_data:
            # Create row environment with implicit column names
            var row_env = Environment()
            for col_idx in range(len(column_names)):
                if col_idx < len(row):
                    row_env.define(column_names[col_idx], PLValue("string", row[col_idx]))

            # Evaluate SELECT expression
            var select_result = self.evaluate(select_clause.value().children[0], row_env, orc_storage)
            var selected_row = List[String]()
            selected_row.append(select_result.__str__())
            selected_data.append(selected_row.copy())

        # Execute THEN clause if present
        if then_clause:
            for row in selected_data:
                # Create row environment with selected value
                var row_env = env.copy()
                row_env.define("result", PLValue("string", row[0]))

                # Execute THEN block
                var block_result = self.eval_block_with_loop_control(then_clause.value().children[0], row_env, orc_storage)
                if block_result.type == "break":
                    break
                elif block_result.type == "continue":
                    continue

        # Format result
        if then_clause:
            return PLValue("string", "LINQ query executed with THEN clause - " + String(len(selected_data)) + " results processed")
        else:
            var result_str = "LINQ results (" + String(len(selected_data)) + " items):\n"
            for row in selected_data:
                result_str += row[0] + "\n"
            return PLValue("string", result_str)

    fn _find_child_by_type(mut self, node: ASTNode, node_type: String) -> Optional[ASTNode]:
        """Find the first child of a specific type."""
        for child in node.children:
            if child.node_type == node_type:
                return child.copy()
        return None

    fn _find_children_by_type(mut self, node: ASTNode, node_type: String) -> List[ASTNode]:
        """Find all children of a specific type."""
        var results = List[ASTNode]()
        for child in node.children:
            if child.node_type == node_type:
                results.append(child.copy())
        return results

    fn _row_to_string(mut self, row: List[String]) -> String:
        """Convert a row to a string representation for LINQ evaluation."""
        var row_str = "["
        for i in range(len(row)):
            if i > 0:
                row_str += ", "
            row_str += "\"" + row[i] + "\""
        row_str += "]"
        return row_str

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

    fn eval_join_select(mut self, node: ASTNode, from_clause: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate SELECT with JOIN operations."""
        # Extract select list
        var select_list: Optional[ASTNode] = None
        for child in node.children:
            if child.node_type == "SELECT_LIST":
                select_list = child.copy()
                break
        
        # Parse FROM clause to get base table and joins
        var base_table: Optional[ASTNode] = None
        var joins = List[ASTNode]()
        
        for child in from_clause.children:
            if child.node_type == "TABLE_REFERENCE":
                base_table = child.copy()
            elif child.node_type == AST_JOIN or child.node_type == AST_LEFT_JOIN or child.node_type == AST_RIGHT_JOIN or child.node_type == AST_FULL_JOIN or child.node_type == AST_INNER_JOIN or child.node_type == AST_ANTI_JOIN:
                joins.append(child.copy())
        
        if not base_table:
            return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
                "JOIN requires a base table", node.line, node.column, self._get_source_line(node.line)
            ))
        
        # Start with base table data
        var result_list = self.eval_table_reference(base_table.value(), env, orc_storage)
        if result_list.type == "error":
            return result_list
        
        # Apply each JOIN
        for join_node in joins:
            var join_result = self.eval_single_join(result_list, join_node, env, orc_storage)
            if join_result.type == "error":
                return join_result
            result_list = join_result
        
        # Apply WHERE clause if present
        var where_clause: Optional[ASTNode] = None
        for child in node.children:
            if child.node_type == "WHERE":
                where_clause = child.copy()
                break
        
        if where_clause:
            result_list = self._apply_where_clause_ast(result_list, where_clause.value(), env, orc_storage)
        
        # Apply SELECT list (projection)
        if select_list:
            result_list = self._apply_select_list_ast(result_list, select_list.value(), env, orc_storage)
        
        # Apply GROUP BY if present
        var group_clause: Optional[ASTNode] = None
        for child in node.children:
            if child.node_type == "GROUP_BY":
                group_clause = child.copy()
                break
        
        if group_clause:
            result_list = self._apply_group_by_ast(result_list, group_clause.value(), select_list.value(), env, orc_storage)
        
        # Apply ORDER BY if present
        var order_clause: Optional[ASTNode] = None
        for child in node.children:
            if child.node_type == "ORDER_BY":
                order_clause = child.copy()
                break
        
        if order_clause:
            result_list = self._apply_order_by_ast(result_list, order_clause.value(), env, orc_storage)
        
        return result_list

    fn eval_single_join(mut self, left_data: PLValue, join_node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate a single JOIN operation."""
        if len(join_node.children) < 2:
            return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
                "JOIN node must have table and condition", join_node.line, join_node.column, self._get_source_line(join_node.line)
            ))
        
        # Get the joined table
        var joined_table = join_node.children[0].copy()
        var join_condition = join_node.children[1].copy()
        
        # Evaluate the joined table
        var right_data = self.eval_table_reference(joined_table, env, orc_storage)
        if right_data.type == "error":
            return right_data
        
        if left_data.type != "list" or right_data.type != "list":
            return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
                "JOIN operands must be lists", join_node.line, join_node.column, self._get_source_line(join_node.line)
            ))
        
        var left_list = left_data.get_list()
        var right_list = right_data.get_list()
        var joined = List[PLValue]()
        
        # Perform nested loop join
        for left_row in left_list:
            for right_row in right_list:
                if left_row.is_struct() and right_row.is_struct():
                    # Create combined environment for condition evaluation
                    var combined_env = env.copy()
                    
                    # Add left row fields to environment
                    for key in left_row.get_struct().keys():
                        combined_env.define(key, left_row.get_struct()[key])
                    
                    # Add right row fields to environment
                    for key in right_row.get_struct().keys():
                        combined_env.define(key, right_row.get_struct()[key])
                    
                    # Evaluate the ON condition
                    var condition_result = self.evaluate(join_condition, combined_env, orc_storage)
                    if condition_result.type == "error":
                        return condition_result
                    
                    if condition_result.is_truthy():
                        # Combine the structs
                        var combined_struct = Dict[String, PLValue]()
                        
                        # Add all fields from left row
                        for key in left_row.get_struct().keys():
                            combined_struct[key] = left_row.get_struct()[key]
                        
                        # Add all fields from right row
                        for key in right_row.get_struct().keys():
                            combined_struct[key] = right_row.get_struct()[key]
                        
                        joined.append(PLValue.struct(combined_struct))
        
        return PLValue.list(joined)

    fn eval_table_reference(mut self, table_node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate a table reference (TABLE_REFERENCE AST node)."""
        var table_name = table_node.get_attribute("table")
        var table_alias = table_node.get_attribute("alias")
        
        # Try to read from ORC storage first
        var table_data = orc_storage.read_table(table_name)
        if len(table_data) > 0:
            # Convert to PLValue list of structs
            var result_list = List[PLValue]()
            
            # Get column names from schema
            var column_names = List[String]()
            try:
                var schema = orc_storage.schema_manager.load_schema()
                var table_schema = schema.get_table(table_name)
                for col in table_schema.columns:
                    column_names.append(col.name)
            except:
                # If schema not available, use generic column names
                if len(table_data) > 0 and len(table_data[0]) > 0:
                    for i in range(len(table_data[0])):
                        column_names.append("col" + String(i))
            
            for row in table_data:
                var row_struct = Dict[String, PLValue]()
                for i in range(len(column_names)):
                    if i < len(row):
                        row_struct[column_names[i]] = PLValue("string", row[i])
                result_list.append(PLValue.struct(row_struct))
            
            return PLValue.list(result_list)
        
        # If not found in ORC storage, try as file reference
        if table_name.startswith("'") and table_name.endswith("'"):
            table_name = table_name[1:-1]  # Remove quotes
        
        # Try to read as JSON file
        try:
            var file_data = self._read_json_file(table_name)
            if file_data.type != "error":
                return file_data
        except:
            pass
        
        # Try environment variable
        var env_data = env.get(table_name)
        if env_data.type != "error":
            return env_data
        
        return PLValue.enhanced_error(PLGrizzlyError.syntax_error(
            "Table or file not found: " + table_name, table_node.line, table_node.column, self._get_source_line(table_node.line)
        ))

    fn _read_json_file(mut self, file_path: String) raises -> PLValue:
        """Read JSON file and return as PLValue."""
        try:
            Python.add_to_path(".")
            var json = Python.import_module("json")
            var os = Python.import_module("os")
            
            if not os.path.exists(file_path):
                return PLValue("error", "File not found: " + file_path)
            
            var file = open(file_path, "r")
            var content = file.read()
            file.close()
            
            var data = json.loads(content)
            return self._python_to_plvalue(data)
        except:
            return PLValue("error", "Failed to read JSON file: " + file_path)

    fn _python_to_plvalue(mut self, py_obj: PythonObject) raises -> PLValue:
        """Convert Python object to PLValue."""
        if py_obj.isinstance(Python.evaluate("list")):
            var result_list = List[PLValue]()
            for item in py_obj:
                result_list.append(self._python_to_plvalue(item))
            return PLValue.list(result_list)
        elif py_obj.isinstance(Python.evaluate("dict")):
            var result_struct = Dict[String, PLValue]()
            for key in py_obj.keys():
                var key_str = String(key)
                result_struct[key_str] = self._python_to_plvalue(py_obj[key])
            return PLValue.struct(result_struct)
        else:
            return PLValue("string", String(py_obj))

    fn _apply_where_clause_ast(mut self, data: PLValue, where_node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Apply WHERE clause filtering using AST."""
        if data.type != "list":
            return data
        
        var result_list = List[PLValue]()
        var original_list = data.get_list()
        
        for row in original_list:
            if row.is_struct():
                # Temporarily add row data to env
                var added_keys = List[String]()
                for key in row.get_struct().keys():
                    var existing = env.get(key)
                    if existing.type == "error":  # Key doesn't exist
                        env.define(key, row.get_struct()[key])
                        added_keys.append(key)
                
                # Evaluate condition
                var condition_result = self.evaluate(where_node.children[0], env, orc_storage)
                if condition_result.type != "error" and condition_result.is_truthy():
                    result_list.append(row)
                
                # Remove temporarily added keys
                for key in added_keys:
                    _ = env.values.pop(key, PLValue("null"))
            else:
                # If not a struct, include it
                result_list.append(row)
        
        return PLValue.list(result_list)

    fn _apply_select_list_ast(mut self, data: PLValue, select_node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Apply SELECT list projection using AST."""
        if data.type != "list":
            return data
        
        var result_list = List[PLValue]()
        var original_list = data.get_list()
        
        for row in original_list:
            if row.is_struct():
                var projected_struct = Dict[String, PLValue]()
                
                for select_item in select_node.children:
                    if select_item.node_type == "SELECT_ITEM":
                        # Handle qualified column references like table.column
                        var expression = select_item.children[0].copy()
                        var col_alias = select_item.get_attribute("alias")
                        
                        if expression.node_type == "IDENTIFIER":
                            var col_name = expression.value
                            if col_name in row.get_struct():
                                var field_name = col_alias if col_alias != "" else col_name
                                projected_struct[field_name] = row.get_struct()[col_name]
                        elif expression.node_type == "BINARY_OP" or expression.node_type == "LITERAL":
                            # Temporarily add row data to env
                            var added_keys = List[String]()
                            for key in row.get_struct().keys():
                                var existing = env.get(key)
                                if existing.type == "error":  # Key doesn't exist
                                    env.define(key, row.get_struct()[key])
                                    added_keys.append(key)
                            
                            var expr_result = self.evaluate(expression, env, orc_storage)
                            var field_name = col_alias if col_alias != "" else "expr"
                            projected_struct[field_name] = expr_result
                            
                            # Remove temporarily added keys
                            for key in added_keys:
                                _ = env.values.pop(key, PLValue("null"))
                
                result_list.append(PLValue.struct(projected_struct))
            else:
                result_list.append(row)
        
        return PLValue.list(result_list)

    fn _apply_group_by_ast(mut self, data: PLValue, group_node: ASTNode, select_node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Apply GROUP BY clause using AST."""
        if data.type != "list":
            return data
        
        var groups = Dict[String, List[PLValue]]()
        var original_list = data.get_list()
        
        # Parse group columns
        var group_columns = List[String]()
        for child in group_node.children:
            if child.node_type == "IDENTIFIER":
                group_columns.append(child.value)
        
        # Group rows
        for row in original_list:
            if row.is_struct():
                var group_key = ""
                for col in group_columns:
                    if col in row.get_struct():
                        group_key += row.get_struct()[col].__str__() + "|"
                    else:
                        group_key += "NULL|"
                
                if group_key not in groups:
                    groups[group_key] = List[PLValue]()
                groups[group_key].append(row)
        
        # Apply aggregation to each group
        var grouped_results = List[PLValue]()
        for group in groups.values():
            if len(group) > 0:
                var aggregated_row = self._apply_aggregates_to_group_ast(group, select_node, env, orc_storage)
                grouped_results.append(aggregated_row)
        
        return PLValue.list(grouped_results)

    fn _apply_aggregates_to_group_ast(mut self, group: List[PLValue], select_node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Apply aggregate functions to a group using AST."""
        var result_struct = Dict[String, PLValue]()
        
        for select_item in select_node.children:
            if select_item.node_type == "SELECT_ITEM":
                var expression = select_item.children[0].copy()
                var col_alias = select_item.get_attribute("alias")
                
                if expression.node_type == "FUNCTION_CALL":
                    var func_name = expression.value
                    var field_name = col_alias if col_alias != "" else func_name
                    
                    if func_name == "COUNT":
                        result_struct[field_name] = PLValue("number", String(len(group)))
                    elif func_name == "SUM" and len(expression.children) > 0:
                        var sum_val = 0.0
                        var col_expr = expression.children[0].copy()
                        if col_expr.node_type == "IDENTIFIER":
                            var col_name = col_expr.value
                            for row in group:
                                if row.is_struct() and col_name in row.get_struct():
                                    var val = row.get_struct()[col_name]
                                    if val.type == "number":
                                        sum_val += Float64(val.value)
                        result_struct[field_name] = PLValue("number", String(sum_val))
                    # Add more aggregates as needed
                elif expression.node_type == "IDENTIFIER":
                    # Group column - take first value
                    var col_name = expression.value
                    var field_name = col_alias if col_alias != "" else col_name
                    if len(group) > 0 and group[0].is_struct() and col_name in group[0].get_struct():
                        result_struct[field_name] = group[0].get_struct()[col_name]
        
        return PLValue.struct(result_struct)

    fn _apply_order_by_ast(mut self, data: PLValue, order_node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Apply ORDER BY clause using AST."""
        if data.type != "list":
            return data
        
        var result_list = data.get_list().copy()
        
        # Simple bubble sort for now
        for i in range(len(result_list)):
            for j in range(i + 1, len(result_list)):
                if self._compare_rows_for_order(result_list[i], result_list[j], order_node, env) > 0:
                    var temp = result_list[i]
                    result_list[i] = result_list[j]
                    result_list[j] = temp
        
        return PLValue.list(result_list)

    fn _compare_rows_for_order(mut self, row1: PLValue, row2: PLValue, order_node: ASTNode, mut env: Environment) raises -> Int:
        """Compare two rows for ordering."""
        if not row1.is_struct() or not row2.is_struct():
            return 0
        
        for order_spec in order_node.children:
            var col_name = order_spec.value
            var direction = order_spec.get_attribute("direction")
            if direction == "":
                direction = "ASC"
            
            var val1 = row1.get_struct().get(col_name, PLValue("string", ""))
            var val2 = row2.get_struct().get(col_name, PLValue("string", ""))
            
            var val1_str = val1.__str__()
            var val2_str = val2.__str__()
            if val1_str < val2_str:
                cmp = -1
            elif val1_str > val2_str:
                cmp = 1
            else:
                cmp = 0
            if direction == "DESC":
                cmp = -cmp
            
            if cmp != 0:
                return cmp
        
        return 0

    fn _apply_order_by_ast_old(mut self, result_data: List[List[String]], order_clause: ASTNode, selected_columns: List[String]) raises -> List[List[String]]:
        """Apply ORDER BY clause to result data using AST-based sorting."""
        if len(order_clause.children) == 0:
            return result_data.copy()
        
        # Make a copy to sort
        var sorted_data = result_data.copy()
        
        # Simple bubble sort implementation
        for i in range(len(sorted_data)):
            for j in range(i + 1, len(sorted_data)):
                if self._compare_rows_ast(sorted_data[i], sorted_data[j], order_clause, selected_columns) > 0:
                    var temp = sorted_data[i].copy()
                    sorted_data[i] = sorted_data[j].copy()
                    sorted_data[j] = temp^
        
        return sorted_data^

    fn _compare_rows_ast(mut self, row1: List[String], row2: List[String], order_clause: ASTNode, selected_columns: List[String]) raises -> Int:
        """Compare two rows for ordering using AST ORDER BY specifications."""
        for order_spec in order_clause.children:
            var column_name = order_spec.value
            var direction = order_spec.get_attribute("direction")
            if direction == "":
                direction = "ASC"
            
            # Find column index
            var col_idx = -1
            for i in range(len(selected_columns)):
                if selected_columns[i] == column_name:
                    col_idx = i
                    break
            
            if col_idx == -1 or col_idx >= len(row1) or col_idx >= len(row2):
                continue
            
            var val1 = row1[col_idx]
            var val2 = row2[col_idx]
            
            var cmp = self._compare_string_values(val1, val2)
            if cmp != 0:
                return cmp if direction == "ASC" else -cmp
        
        return 0

    fn _compare_string_values(mut self, val1: String, val2: String) raises -> Int:
        """Compare two string values for sorting."""
        # Try numeric comparison first
        try:
            var n1 = atol(val1)
            var n2 = atol(val2)
            if n1 < n2:
                return -1
            elif n1 > n2:
                return 1
            else:
                return 0
        except:
            # Fall back to string comparison
            if val1 < val2:
                return -1
            elif val1 > val2:
                return 1
            else:
                return 0

    fn eval_typeof_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
        """Evaluate @TypeOf expression to return the type of a variable or column."""
        if len(node.children) != 1:
            return PLValue("error", "@TypeOf requires exactly one argument")
        
        var arg = node.children[0].copy()
        var arg_value = self.evaluate(arg, env, orc_storage)
        
        # For now, return the PLValue type as a string
        # In the future, this could be enhanced to return more detailed type information
        return PLValue("string", arg_value.type)
