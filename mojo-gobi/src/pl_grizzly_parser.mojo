"""
PL-GRIZZLY Parser Implementation

Optimized recursive descent parser with memoization and efficient AST representation.
"""

from collections import List, Dict
from pl_grizzly_lexer import Token, PLGrizzlyLexer, SELECT, FROM, WHERE, CREATE, DROP, INDEX, MATERIALIZED, VIEW, REFRESH, LOAD, UPDATE, UPSERT, DELETE, LOGIN, LOGOUT, BEGIN, COMMIT, ROLLBACK, MACRO, JOIN, LEFT, RIGHT, FULL, INNER, ANTI, ON, ATTACH, DETACH, EXECUTE, ALL, ARRAY, ATTACHED, DATABASES, AS, CACHE, CLEAR, DISTINCT, GROUP, ORDER, BY, HAVING, OVER, PARTITION, RANGE, ROWS, BETWEEN, PRECEDING, FOLLOWING, UNBOUNDED, CURRENT, EXCLUDE, TIES, GROUPS, SUM, COUNT, AVG, MIN, MAX, FUNCTION, TYPE, STRUCT, STRUCTS, TYPEOF, EXCEPTION, MODULE, DOUBLE_COLON, RETURNS, IF, ELSE, MATCH, WHILE, THEN, CASE, IN, TRY, CATCH, LET, TRUE, FALSE, BREAK, CONTINUE, INSTALL, WITH, HTTPS, EXTENSIONS, STREAM, COPY, TO, EQUALS, NOT_EQUALS, GREATER, LESS, GREATER_EQUAL, LESS_EQUAL, AND, OR, NOT, BANG, COALESCE, PLUS, MINUS, MULTIPLY, DIVIDE, MODULO, PIPE, PROCEDURE, TRIGGER, SCHEDULE, CALL, ASYNC, SYNC, ENABLE_TOKEN, DISABLE_TOKEN, ARROW, DOT, LPAREN, RPAREN, LBRACE, RBRACE, LBRACKET, RBRACKET, LANGLE, RANGLE, COMMA, SEMICOLON, COLON, INSERT, INTO, VALUES, SET, SHOW, SECRET, SECRETS, DROP_SECRET, IDENTIFIER, STRING, NUMBER, VARIABLE, UNDERSCORE, EOF, UNKNOWN
from pl_grizzly_errors import PLGrizzlyError

# Optimized AST Node types using enum-like constants
alias AST_SELECT = "SELECT"
alias AST_FROM = "FROM"
alias AST_WHERE = "WHERE"
alias AST_CREATE = "CREATE"
alias AST_DROP = "DROP"
alias AST_INDEX = "INDEX"
alias AST_FUNCTION = "FUNCTION"
alias AST_BINARY_OP = "BINARY_OP"
alias AST_UNARY_OP = "UNARY_OP"
alias AST_LITERAL = "LITERAL"
alias AST_IDENTIFIER = "IDENTIFIER"
alias AST_CALL = "CALL"
alias AST_ARRAY = "ARRAY"
alias AST_DICT = "DICT"
alias AST_BREAK = "BREAK"
alias AST_CONTINUE = "CONTINUE"
alias AST_MATCH = "MATCH"
alias AST_EXECUTE = "EXECUTE"
alias AST_INSTALL = "INSTALL"
alias AST_LOAD = "LOAD"
alias AST_WITH = "WITH"
alias AST_STREAM = "STREAM"
alias AST_MEMBER_ACCESS = "MEMBER_ACCESS"
alias AST_INDEX_ACCESS = "INDEX_ACCESS"
alias AST_STRUCT_LITERAL = "STRUCT_LITERAL"
alias AST_TUPLE = "TUPLE"
alias AST_COPY = "COPY"
alias AST_JOIN = "JOIN"
alias AST_LEFT_JOIN = "LEFT_JOIN"
alias AST_RIGHT_JOIN = "RIGHT_JOIN"
alias AST_FULL_JOIN = "FULL_JOIN"
alias AST_INNER_JOIN = "INNER_JOIN"
alias AST_ANTI_JOIN = "ANTI_JOIN"
alias AST_PROCEDURE = "PROCEDURE"
alias AST_UPSERT_PROCEDURE = "UPSERT_PROCEDURE"
alias AST_TRIGGER = "TRIGGER"
alias AST_UPSERT_TRIGGER = "UPSERT_TRIGGER"
alias AST_UPSERT_SCHEDULE = "UPSERT_SCHEDULE"
alias AST_ENABLE_TRIGGER = "ENABLE_TRIGGER"
alias AST_DISABLE_TRIGGER = "DISABLE_TRIGGER"
alias AST_LINQ_QUERY = "LINQ_QUERY"

# Efficient AST Node using Dict for flexible representation
struct ASTNode(Copyable, Movable):
    var node_type: String
    var value: String
    var children: List[ASTNode]
    var attributes: Dict[String, String]
    var line: Int
    var column: Int
    var inferred_type: String  # Dynamic type inference

    fn __init__(out self, node_type: String, value: String = "", line: Int = -1, column: Int = -1):
        self.node_type = node_type
        self.value = value
        self.children = List[ASTNode]()
        self.attributes = Dict[String, String]()
        self.line = line
        self.column = column
        self.inferred_type = "unknown"

    fn add_child(mut self, child: ASTNode) raises:
        self.children.append(child.copy())

    fn set_attribute(mut self, key: String, value: String):
        self.attributes[key] = value

    fn get_attribute(self, key: String) -> String:
        return self.attributes.get(key, "")

# Type System for Dynamic Semantic Analysis
struct TypeInfo(Copyable, Movable):
    var type_name: String
    var is_nullable: Bool
    var constraints: List[String]  # e.g., ["min:0", "max:100"]

    fn __init__(out self, type_name: String, is_nullable: Bool = False):
        self.type_name = type_name
        self.is_nullable = is_nullable
        self.constraints = List[String]()

    fn add_constraint(mut self, constraint: String):
        self.constraints.append(constraint)

# User-defined struct type definition
struct StructDefinition(Copyable, Movable):
    var name: String
    var fields: Dict[String, String]  # field_name -> field_type

    fn __init__(out self, name: String):
        self.name = name
        self.fields = Dict[String, String]()

    fn add_field(mut self, field_name: String, field_type: String):
        self.fields[field_name] = field_type

    fn get_field_type(self, field_name: String) -> String:
        return self.fields.get(field_name, "unknown")

    fn has_field(self, field_name: String) -> Bool:
        return field_name in self.fields

# Dynamic Type Checker
struct TypeChecker:
    var type_table: Dict[String, TypeInfo]
    var function_signatures: Dict[String, Dict[String, String]]  # func_name -> {param: type}
    var struct_definitions: Dict[String, StructDefinition]  # struct_name -> definition

    fn __init__(out self):
        self.type_table = Dict[String, TypeInfo]()
        self.function_signatures = Dict[String, Dict[String, String]]()
        self.struct_definitions = Dict[String, StructDefinition]()
        self.initialize_builtin_types()

    fn initialize_builtin_types(mut self):
        self.type_table["int"] = TypeInfo("int")
        self.type_table["float"] = TypeInfo("float")
        self.type_table["string"] = TypeInfo("string")
        self.type_table["boolean"] = TypeInfo("boolean")
        self.type_table["array"] = TypeInfo("array")
        self.type_table["struct"] = TypeInfo("struct")

    fn define_struct(mut self, var struct_def: StructDefinition):
        """Register a user-defined struct type."""
        self.struct_definitions[struct_def.name] = struct_def^

    fn get_struct_definition(self, struct_name: String) -> Optional[StructDefinition]:
        """Get a struct definition by name."""
        return self.struct_definitions.get(struct_name)

    fn is_struct_type(self, type_name: String) -> Bool:
        """Check if a type is a user-defined struct."""
        return type_name in self.struct_definitions

    fn create_array_type(self, element_type: String) -> String:
        """Create an array type string."""
        return "Array<" + element_type + ">"

    fn infer_type(self, node: ASTNode, symbol_table: SymbolTable) raises -> String:
        """Infer type for an AST node with enhanced type inference."""
        if node.node_type == AST_LITERAL:
            return self.infer_literal_type(node.value)
        elif node.node_type == AST_IDENTIFIER:
            return self.infer_identifier_type(node.value, symbol_table)
        elif node.node_type == AST_BINARY_OP:
            return self.infer_binary_op_type(node, symbol_table)
        elif node.node_type == AST_UNARY_OP:
            return self.infer_unary_op_type(node, symbol_table)
        elif node.node_type == AST_CALL:
            return self.infer_call_type(node, symbol_table)
        elif node.node_type == AST_ARRAY:
            return self.infer_array_type(node, symbol_table)
        elif node.node_type == AST_DICT:
            return "Dict<string, unknown>"
        elif node.node_type == AST_MEMBER_ACCESS:
            return self.infer_member_access_type(node, symbol_table)
        elif node.node_type == AST_INDEX:
            return self.infer_index_access_type(node, symbol_table)
        elif node.node_type == AST_STRUCT_LITERAL:
            return self.infer_struct_literal_type(node)
        elif node.node_type == AST_TUPLE:
            return "Tuple"
        return "unknown"

    fn infer_literal_type(self, value: String) -> String:
        """Enhanced literal type inference with timestamp support."""
        if value.isdigit():
            return "int"
        elif value.startswith("-") and value[1:].isdigit():
            return "int"
        elif self.is_float_literal(value):
            return "float"
        elif value == "true" or value == "false":
            return "boolean"
        elif (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            var inner = value[1:-1]
            if self.is_timestamp_literal(inner):
                return "timestamp"
            return "string"
        else:
            return "string"  # Default to string for complex literals

    fn is_timestamp_literal(self, value: String) -> Bool:
        """Check if a string represents a timestamp literal."""
        # Check for ISO 8601 format: 2024-01-01T00:00:00Z
        if len(value) >= 20 and value[10] == 'T' and value.endswith('Z'):
            # Basic format validation: YYYY-MM-DDTHH:MM:SSZ
            return value[4] == '-' and value[7] == '-' and value[13] == ':' and value[16] == ':'
        return False

    fn is_float_literal(self, value: String) -> Bool:
        """Check if a string represents a float literal."""
        return value.find(".") != -1 or value.lower().find("e") != -1

    fn infer_identifier_type(self, name: String, symbol_table: SymbolTable) -> String:
        """Enhanced identifier type inference with fallback."""
        try:
            var type_info = symbol_table.lookup(name)
            return type_info
        except:
            # Check if it's a built-in function or constant
            if name == "true" or name == "false":
                return "boolean"
            elif name == "null":
                return "null"
            return "unknown"

    fn infer_binary_op_type(self, node: ASTNode, symbol_table: SymbolTable) raises -> String:
        """Enhanced binary operation type inference."""
        if len(node.children) < 2:
            return "unknown"

        var left_type = self.infer_type(node.children[0], symbol_table)
        var right_type = self.infer_type(node.children[1], symbol_table)

        return self.resolve_binary_op_type_enhanced(left_type, right_type, node.value)

    fn resolve_binary_op_type_enhanced(self, left: String, right: String, op: String) -> String:
        """Enhanced binary operation type resolution with better type promotion."""
        # Arithmetic operations
        if op == "+" or op == "-" or op == "*" or op == "/":
            # String concatenation
            if left == "string" or right == "string":
                return "string"
            # Numeric operations
            elif left == "float" or right == "float":
                return "float"
            elif left == "int" and right == "int":
                return "int"
            else:
                return "unknown"

        # Comparison operations
        elif op == "==" or op == "!=" or op == "<" or op == ">" or op == "<=" or op == ">=":
            return "boolean"

        # Logical operations
        elif op == "and" or op == "or":
            if left == "boolean" and right == "boolean":
                return "boolean"
            else:
                return "unknown"

        # Modulo operation
        elif op == "%":
            if left == "int" and right == "int":
                return "int"
            else:
                return "unknown"

        return "unknown"

    fn infer_unary_op_type(self, node: ASTNode, symbol_table: SymbolTable) raises -> String:
        """Infer type for unary operations."""
        if len(node.children) < 1:
            return "unknown"

        var operand_type = self.infer_type(node.children[0], symbol_table)

        if node.value == "not":
            return "boolean"  # Logical not always returns boolean
        elif node.value == "-":
            return operand_type  # Negation preserves type
        elif node.value == "+":
            return operand_type  # Unary plus preserves type

        return "unknown"

    fn infer_call_type(self, node: ASTNode, symbol_table: SymbolTable) raises -> String:
        """Enhanced function call type inference."""
        var func_name = node.value

        # Built-in functions
        if func_name == "len":
            return "int"
        elif func_name == "abs" or func_name == "sqrt" or func_name == "sin" or func_name == "cos" or func_name == "tan":
            return "float"
        elif func_name == "min" or func_name == "max" or func_name == "sum":
            # Infer from arguments
            if len(node.children) > 0:
                return self.infer_type(node.children[0], symbol_table)
            return "unknown"
        elif func_name == "print":
            return "void"
        elif func_name == "type":
            return "string"  # Type introspection returns string

        # Check user-defined functions
        var func_sig_opt = self.function_signatures.get(func_name)
        if func_sig_opt:
            var func_sig = func_sig_opt.value().copy()
            var return_type_opt = func_sig.get("return")
            if return_type_opt:
                return return_type_opt.value()

        return "unknown"

    fn infer_array_type(self, node: ASTNode, symbol_table: SymbolTable) raises -> String:
        """Infer array type from elements."""
        if len(node.children) == 0:
            return "Array<unknown>"

        # Infer type from first element
        var element_type = self.infer_type(node.children[0], symbol_table)
        return self.create_array_type(element_type)

    fn infer_member_access_type(self, node: ASTNode, symbol_table: SymbolTable) raises -> String:
        """Infer type for member access operations."""
        if len(node.children) < 1:
            return "unknown"

        var object_type = self.infer_type(node.children[0], symbol_table)
        var member_name = node.value

        # Handle struct member access
        if object_type.startswith("struct:"):
            var struct_name = object_type[7:]  # Remove "struct:" prefix
            var struct_def_opt = self.struct_definitions.get(struct_name)
            if struct_def_opt:
                var struct_def = struct_def_opt.value().copy()
                var field_type_opt = struct_def.fields.get(member_name)
                if field_type_opt:
                    return field_type_opt.value()
        elif object_type.startswith("Array<"):
            # Array methods
            if member_name == "length" or member_name == "size":
                return "int"
            elif member_name == "get" or member_name == "set":
                # Extract element type from Array<type>
                var start_idx = object_type.find("<")
                var end_idx = object_type.find(">")
                if start_idx != -1 and end_idx != -1:
                    return object_type[start_idx + 1:end_idx]

        return "unknown"

    fn infer_index_access_type(self, node: ASTNode, symbol_table: SymbolTable) raises -> String:
        """Infer type for index access operations."""
        if len(node.children) < 1:
            return "unknown"

        var collection_type = self.infer_type(node.children[0], symbol_table)

        if collection_type.startswith("Array<"):
            # Extract element type from Array<type>
            var start_idx = collection_type.find("<")
            var end_idx = collection_type.find(">")
            if start_idx != -1 and end_idx != -1:
                return collection_type[start_idx + 1:end_idx]
        elif collection_type.startswith("Dict<"):
            # Dict access returns value type
            var first_comma = collection_type.find(",")
            var end_bracket = collection_type.find(">")
            if first_comma != -1 and end_bracket != -1:
                return String(collection_type[first_comma + 1:end_bracket].strip())

        return "unknown"

    fn infer_struct_literal_type(self, node: ASTNode) -> String:
        """Infer type for struct literals."""
        var struct_type = node.get_attribute("struct_type")
        if struct_type != "":
            return "struct:" + struct_type
        return "struct:anonymous"

    fn check_type_compatibility(self, expected: String, actual: String) raises:
        """Check if types are compatible."""
        if expected != actual and expected != "unknown" and actual != "unknown":
            if not (expected == "float" and actual == "int"):  # int can be promoted to float
                raise Error("Type mismatch: expected " + expected + ", got " + actual)

    fn perform_semantic_analysis(mut self, node: ASTNode, mut symbol_table: SymbolTable) raises:
        """Perform dynamic semantic analysis on AST."""
        if node.node_type == "TYPE" and node.get_attribute("type") == "STRUCT":
            # Handle struct type definition
            var struct_name = node.get_attribute("name")
            var struct_def = StructDefinition(struct_name)
            
            # Collect field definitions
            for i in range(len(node.children)):
                var child = node.children[i].copy()
                if child.node_type == "FIELD_DEF":
                    var field_name = child.value
                    var field_type = child.get_attribute("type")
                    struct_def.add_field(field_name, field_type)
            
            # Register the struct definition
            self.define_struct(struct_def^)
            print("Registered struct type:", struct_name)
        elif node.node_type == AST_BINARY_OP:
            var left_type = self.infer_type(node.children[0], symbol_table)
            var right_type = self.infer_type(node.children[1], symbol_table)
            var result_type = self.resolve_binary_op_type_enhanced(left_type, right_type, node.value)
            # Note: ASTNode is not mutable, so we can't modify inferred_type here
            # Type checking is done during evaluation instead
        elif node.node_type == "LET":  # Use string instead of undefined constant
            var expr_type = self.infer_type(node.children[0], symbol_table)
            symbol_table.define(node.value, expr_type)
        elif node.node_type == AST_FUNCTION:
            # Analyze function parameters and body
            for i in range(len(node.children)):
                self.perform_semantic_analysis(node.children[i], symbol_table)

        # Recursively analyze children
        for i in range(len(node.children)):
            self.perform_semantic_analysis(node.children[i], symbol_table)

    fn try_to_infer_type(self, node: ASTNode, symbol_table: SymbolTable) -> String:
        """Try to infer the type of an expression, returning 'unknown' if inference fails."""
        try:
            return self.infer_type(node, symbol_table)
        except:
            return "unknown"

    fn validate_procedure_parameters(self, procedure_node: ASTNode, symbol_table: SymbolTable) raises:
        """Validate procedure parameters with enhanced type checking."""
        var parameters = procedure_node.get_attribute("parameters")
        if parameters != "":
            # Parse parameter list and validate each parameter
            var param_list = parameters.split(",")
            for i in range(len(param_list)):
                var param = param_list[i]
                var param_parts = param.strip().split(":")
                if len(param_parts) == 2:
                    var param_name = param_parts[0].strip()
                    var param_type = param_parts[1].strip()
                    
                    # Check if type is explicitly declared
                    if param_type == "auto":
                        # Try to infer type from usage in procedure body
                        var inferred_type = self.try_to_infer_type_from_procedure_body(procedure_node, String(param_name), symbol_table)
                        if inferred_type != "unknown":
                            print("Inferred parameter type for", param_name, ":", inferred_type)
                        else:
                            raise Error("Cannot infer type for parameter '" + String(param_name) + "' - please specify explicit type")
                    else:
                        # Validate explicit type declaration
                        if not self.is_valid_type(String(param_type)):
                            raise Error("Invalid parameter type '" + String(param_type) + "' for parameter '" + String(param_name) + "'")

    fn try_to_infer_type_from_procedure_body(self, procedure_node: ASTNode, param_name: String, symbol_table: SymbolTable) -> String:
        """Try to infer parameter type from its usage in the procedure body."""
        # Look through the procedure body for usage of the parameter
        for i in range(len(procedure_node.children)):
            var child = procedure_node.children[i].copy()
            if child.node_type == "BLOCK" or child.node_type == "BODY":
                var inferred = self.infer_type_from_block(child, param_name, symbol_table)
                if inferred != "unknown":
                    return inferred
        return "unknown"

    fn infer_type_from_block(self, block_node: ASTNode, param_name: String, symbol_table: SymbolTable) -> String:
        """Infer parameter type from expressions in a block."""
        for i in range(len(block_node.children)):
            var child = block_node.children[i].copy()
            if child.node_type == AST_IDENTIFIER and child.value == param_name:
                # Found usage - try to infer from context
                # This is a simplified version; in practice, we'd need more context
                return "unknown"  # Placeholder for more sophisticated inference
            elif child.node_type == AST_BINARY_OP:
                # Check if parameter is used in binary operation
                var left_type = self.try_to_infer_type(child.children[0].copy(), symbol_table)
                var right_type = self.try_to_infer_type(child.children[1].copy(), symbol_table)
                if left_type == param_name or right_type == param_name:
                    # Parameter is used in operation - infer from other operand
                    var other_type = left_type if right_type == param_name else right_type
                    if other_type != "unknown":
                        return other_type
        return "unknown"

    fn validate_procedure_return_type(self, procedure_node: ASTNode, symbol_table: SymbolTable) raises:
        """Validate procedure return type."""
        var return_type = procedure_node.get_attribute("return_type")
        if return_type != "" and return_type != "void":
            if not self.is_valid_type(return_type):
                raise Error("Invalid return type '" + return_type + "' for procedure")

    fn is_valid_type(self, type_name: String) -> Bool:
        """Check if a type name is valid."""
        var valid_types = List[String]("int", "float", "string", "bool", "array", "struct", "void", "unknown")
        return type_name in valid_types

    fn perform_procedure_type_checking(mut self, procedure_node: ASTNode, mut symbol_table: SymbolTable) raises:
        """Perform comprehensive type checking for procedures."""
        # Validate parameters
        self.validate_procedure_parameters(procedure_node, symbol_table)
        
        # Validate return type
        self.validate_procedure_return_type(procedure_node, symbol_table)
        
        # Check body for type consistency
        self.check_procedure_body_types(procedure_node, symbol_table)

    fn check_procedure_body_types(mut self, procedure_node: ASTNode, mut symbol_table: SymbolTable) raises:
        """Check types in procedure body for consistency."""
        for i in range(len(procedure_node.children)):
            var child = procedure_node.children[i].copy()
            if child.node_type == "BLOCK" or child.node_type == "BODY":
                self.perform_semantic_analysis(child, symbol_table)


# Memoization cache for parser expressions - simplified for non-copyable ASTNode
struct ParserCache:
    var memo: Dict[String, Bool]  # Just track if we've seen this key

    fn __init__(out self):
        self.memo = Dict[String, Bool]()

    fn has(self, key: String) -> Bool:
        return key in self.memo

    fn mark(mut self, key: String):
        self.memo[key] = True

# Symbol table for efficient identifier resolution
struct SymbolTable:
    var symbols: Dict[String, String]  # name -> type

    fn __init__(out self):
        self.symbols = Dict[String, String]()

    fn define(mut self, name: String, type: String):
        self.symbols[name] = type

    fn lookup(self, name: String) raises -> String:
        # Check current scope
        if name in self.symbols:
            return self.symbols[name]
        
        return "unknown"

# Optimized PL-GRIZZLY Parser with memoization and symbol table
struct PLGrizzlyParser:
    var tokens: List[Token]
    var current: Int
    var cache: ParserCache
    var symbol_table: SymbolTable
    var type_checker: TypeChecker

    fn __init__(out self, tokens: List[Token]):
        self.tokens = tokens.copy()
        self.current = 0
        self.cache = ParserCache()
        self.symbol_table = SymbolTable()
        self.type_checker = TypeChecker()

    fn set_tokens(mut self, var tokens: List[Token]):
        self.tokens = tokens^

    fn parse(mut self) raises -> ASTNode:
        """Parse tokens into optimized AST with semantic analysis."""
        if len(self.tokens) == 0:
            return ASTNode(AST_LITERAL, "empty")

        # Parse the statement
        var ast = self.statement()

        # Perform dynamic semantic analysis and type checking
        self.type_checker.perform_semantic_analysis(ast, self.symbol_table)

        return ast.copy()

    fn statement(mut self) raises -> ASTNode:
        """Parse a statement."""
        # Handle parenthesized statements (Lisp-style)
        if self.match(LPAREN):
            return self.parenthesized_statement()
        else:
            return self.unparenthesized_statement()

    fn parenthesized_statement(mut self) raises -> ASTNode:
        """Parse a parenthesized statement."""
        var result: ASTNode
        if self.match(STREAM):
            # STREAM keyword found, now expect SELECT or FROM
            if self.match(SELECT) or self.match(FROM):
                result = self.select_from_statement(True)  # Pass flag indicating STREAM was present
            else:
                # Invalid syntax after STREAM
                var error = PLGrizzlyError.syntax_error(
                    "Expected SELECT or FROM after STREAM",
                    self.previous().line, self.previous().column, ""
                )
                error.add_suggestion("Use '(STREAM SELECT ...)' or '(STREAM FROM ... SELECT ...)'")
                return ASTNode("ERROR", "Invalid STREAM syntax")
        elif self.match(SELECT) or self.match(FROM):
            result = self.select_from_statement(False)  # No STREAM
        elif self.match(CREATE):
            result = self.create_statement()
        elif self.match(DROP):
            if self.match(SECRET):
                result = self.drop_secret_statement()
            else:
                result = self.drop_statement()
        elif self.match(INSERT):
            result = self.insert_statement()
        elif self.match(UPDATE):
            result = self.update_statement()
        elif self.match(DELETE):
            result = self.delete_statement()
        elif self.match(LET):
            result = self.let_statement()
        elif self.match(FUNCTION):
            result = self.function_statement()
        elif self.match(WHILE):
            result = self.while_statement()
        elif self.match(BREAK):
            result = self.break_statement()
        elif self.match(CONTINUE):
            result = self.continue_statement()
        else:
            result = self.expression_statement()
        _ = self.consume(RPAREN, "Expected ')' after statement")
        return result^

    fn unparenthesized_statement(mut self) raises -> ASTNode:
        """Parse an unparenthesized statement (for SQL-like syntax)."""
        var result: ASTNode
        if self.match(STREAM):
            # STREAM keyword found, now expect SELECT or FROM
            if self.match(SELECT) or self.match(FROM):
                result = self.select_from_statement(True)  # Pass flag indicating STREAM was present
            else:
                # Invalid syntax after STREAM
                var error = PLGrizzlyError.syntax_error(
                    "Expected SELECT or FROM after STREAM",
                    self.previous().line, self.previous().column, ""
                )
                error.add_suggestion("Use 'STREAM SELECT ...' or 'STREAM FROM ... SELECT ...'")
                return ASTNode("ERROR", "Invalid STREAM syntax")
        elif self.check(FROM) and (self.check_next(LBRACKET) or self.check_next(LPAREN) or (self.check_next(IDENTIFIER) and not self.is_keyword(self.peek_next_type()))):
            # LINQ-style query: FROM collection (SQL-first syntax)
            result = self.linq_query_statement()
        elif self.match(WITH):
            result = self.with_statement()
        elif self.match(SELECT) or self.match(FROM):
            result = self.select_from_statement(False)  # No STREAM
        elif self.match(CREATE):
            result = self.create_statement()
        elif self.match(ENABLE_TOKEN):
            if self.match(TRIGGER):
                result = self.enable_trigger_statement()
            else:
                var error = PLGrizzlyError.syntax_error(
                    "Expected TRIGGER after ENABLE",
                    self.previous().line, self.previous().column, ""
                )
                error.add_suggestion("Use 'ENABLE TRIGGER trigger_name'")
                return ASTNode("ERROR", "Invalid ENABLE syntax")
        elif self.match(DISABLE_TOKEN):
            if self.match(TRIGGER):
                result = self.disable_trigger_statement()
            else:
                var error = PLGrizzlyError.syntax_error(
                    "Expected TRIGGER after DISABLE",
                    self.previous().line, self.previous().column, ""
                )
                error.add_suggestion("Use 'DISABLE TRIGGER trigger_name'")
                return ASTNode("ERROR", "Invalid DISABLE syntax")
        elif self.match(UPSERT):
            if self.match(PROCEDURE):
                result = self.upsert_procedure_statement()
            elif self.match(TRIGGER):
                result = self.upsert_trigger_statement()
            elif self.match(SCHEDULE):
                result = self.upsert_schedule_statement()
            else:
                var error = PLGrizzlyError.syntax_error(
                    "Expected PROCEDURE, TRIGGER, or SCHEDULE after UPSERT",
                    self.previous().line, self.previous().column, ""
                )
                error.add_suggestion("Use 'UPSERT PROCEDURE ...', 'UPSERT TRIGGER ...', or 'UPSERT SCHEDULE ...'")
                return ASTNode("ERROR", "Invalid UPSERT syntax")
        elif self.match(COPY):
            result = self.copy_statement()
        elif self.match(DROP):
            result = self.drop_statement()
        elif self.match(INSERT):
            result = self.insert_statement()
        elif self.match(UPDATE):
            result = self.update_statement()
        elif self.match(DELETE):
            result = self.delete_statement()
        elif self.match(LET):
            result = self.let_statement()
        elif self.match(FUNCTION):
            result = self.function_statement()
        elif self.match(TYPE):
            result = self.type_statement()
        elif self.match(ATTACH):
            result = self.attach_statement()
        elif self.match(DETACH):
            result = self.detach_statement()
        elif self.match(EXECUTE):
            result = self.execute_statement()
        elif self.match(INSTALL):
            result = self.install_statement()
        elif self.match(LOAD):
            result = self.load_statement()
        elif self.match(SHOW):
            result = self.show_statement()
        elif self.match(DROP):
            if self.match(SECRET):
                result = self.drop_secret_statement()
            else:
                result = self.drop_statement()
        elif self.match(WHILE):
            result = self.while_statement()
        elif self.match(BREAK):
            result = self.break_statement()
        elif self.match(CONTINUE):
            result = self.continue_statement()
        else:
            result = self.expression_statement()

        return result^

    fn select_from_statement(mut self, is_stream: Bool = False, require_from: Bool = True) raises -> ASTNode:
        """Parse SELECT/FROM statement with interchangeable keywords."""
        var node = ASTNode(AST_SELECT, "", self.previous().line, self.previous().column)
        
        # Add STREAM attribute if present
        if is_stream:
            node.add_child(ASTNode(AST_STREAM, "stream", self.previous().line, self.previous().column))
        
        var started_with_select = self.previous().type == SELECT
        var started_with_from = self.previous().type == FROM

        # If we started with SELECT, parse SELECT clause first
        if started_with_select:
            var select_list = self.parse_select_list()
            node.add_child(select_list)

        # Parse FROM clause
        if started_with_from or require_from:
            if not started_with_from:
                _ = self.consume(FROM, "Expected FROM clause")
            var from_clause = self.parse_from_clause()
            node.add_child(from_clause)

        # If we started with FROM, parse SELECT clause now
        if started_with_from:
            _ = self.consume(SELECT, "Expected SELECT clause after FROM")
            var select_list = self.parse_select_list()
            node.add_child(select_list)

        # Parse WHERE clause
        if self.match(WHERE):
            var where_clause = self.parse_where_clause()
            node.add_child(where_clause)

        # Parse GROUP BY clause
        if self.match(GROUP):
            _ = self.consume(BY, "Expected 'BY' after GROUP")
            var group_clause = self.parse_group_by_clause()
            node.add_child(group_clause)

            # Parse HAVING clause (only valid after GROUP BY)
            if self.match(HAVING):
                var having_clause = self.parse_having_clause()
                node.add_child(having_clause)

        # Parse ORDER BY clause
        if self.match(ORDER):
            _ = self.consume(BY, "Expected 'BY' after ORDER")
            var order_clause = self.parse_order_by_clause()
            node.add_child(order_clause)

        # Parse THEN clause for iteration
        if self.match(THEN):
            var then_clause = self.parse_then_clause()
            node.add_child(then_clause)

        return node^

    fn with_statement(mut self) raises -> ASTNode:
        """Parse WITH statement (CTE - Common Table Expression)."""
        var node = ASTNode(AST_WITH, "", self.previous().line, self.previous().column)

        # Parse CTE definitions
        var cte_list = List[ASTNode]()
        while True:
            var cte_name = self.consume(IDENTIFIER, "Expected CTE name").value
            _ = self.consume(AS, "Expected AS after CTE name")

            # Parse the CTE query (subquery)
            _ = self.consume(LPAREN, "Expected '(' after AS")
            # The CTE query should be a SELECT statement
            _ = self.consume(SELECT, "Expected SELECT in CTE query")
            var cte_query = self.select_from_statement(False, False)  # FROM is optional for CTE queries
            _ = self.consume(RPAREN, "Expected ')' after CTE query")

            # Create CTE definition node
            var cte_def = ASTNode("CTE_DEFINITION", cte_name)
            cte_def.add_child(cte_query)
            cte_list.append(cte_def^)

            # Check for comma (more CTEs) or end
            if not self.match(COMMA):
                break

        # Add all CTE definitions to the WITH node
        for cte in cte_list:
            node.add_child(cte)

        # Parse the main query
        # The main query can be either SELECT ... FROM ... or FROM ... SELECT ...
        var main_query = self.statement()
        node.add_child(main_query)

        return node^

    fn parse_select_list(mut self) raises -> ASTNode:
        """Parse select list with aggregate function detection."""
        var node = ASTNode("SELECT_LIST", "", self.previous().line, self.previous().column)
        _ = False  # has_aggregates placeholder

        while not self.is_at_end() and not self.check(FROM) and not self.check(WHERE) and not self.check(GROUP) and not self.check(ORDER):
            if self.match(DISTINCT):
                node.set_attribute("distinct", "true")
                continue

            var item = self.parse_select_item()
            node.add_child(item)

            if not self.match(COMMA):
                break

        return node^

    fn parse_select_item(mut self) raises -> ASTNode:
        """Parse select item, detecting aggregate functions and array aggregations."""
        var node = ASTNode("SELECT_ITEM", "", self.peek().line, self.peek().column)

        # Check for Array::(expression) syntax
        if self.check(ARRAY) and self.peek_next_type() == DOUBLE_COLON:
            var array_agg_node = self.parse_array_aggregation()
            node.add_child(array_agg_node)
        # Check for qualified column references like table.* or table.column
        elif self.check(IDENTIFIER) and self.peek_next_type() == DOT:
            var qualifier = self.consume(IDENTIFIER, "Expected table/alias name")
            _ = self.consume(DOT, "Expected '.' after qualifier")
            
            if self.match(MULTIPLY):
                # table.*
                var qualified_star = ASTNode("QUALIFIED_STAR", qualifier.value, qualifier.line, qualifier.column)
                node.add_child(qualified_star)
            else:
                # table.column
                var column = self.consume(IDENTIFIER, "Expected column name after '.'")
                var qualified_column = ASTNode("QUALIFIED_IDENTIFIER", qualifier.value + "." + column.value, qualifier.line, qualifier.column)
                node.add_child(qualified_column)
        # Check for aggregate functions
        elif self.check(SUM) or self.check(COUNT) or self.check(AVG) or self.check(MIN) or self.check(MAX):
            var func_name = self.advance().value
            _ = self.consume(LPAREN, "Expected '(' after aggregate function")
            var expr = self.expression()
            _ = self.consume(RPAREN, "Expected ')' after aggregate function argument")

            var func_node = ASTNode("AGGREGATE_FUNCTION", func_name, self.previous().line, self.previous().column)
            func_node.add_child(expr)
            node.add_child(func_node)
        else:
            var expr = self.expression()
            node.add_child(expr)

        # Check for alias
        if self.match(AS):
            var alias_token = self.consume(IDENTIFIER, "Expected identifier after AS")
            node.set_attribute("alias", alias_token.value)
        elif self.check(IDENTIFIER) and not self.is_at_end():
            # Check if next token is an alias (simple heuristic)
            var next_token = self.peek()
            if next_token.type == IDENTIFIER and not self.is_keyword(next_token.value):
                var alias_token = self.advance()
                node.set_attribute("alias", alias_token.value)

        return node^

    fn parse_from_clause(mut self) raises -> ASTNode:
        """Parse FROM clause with JOIN support."""
        var node = ASTNode(AST_FROM, "", self.previous().line, self.previous().column)
        
        # Parse the first table
        var first_table = self.parse_table_reference()
        node.add_child(first_table)
        
        # Parse optional JOIN clauses
        while self.is_join_keyword():
            var join_node = self.parse_join_clause()
            node.add_child(join_node)
        
        return node^

    fn parse_table_reference(mut self) raises -> ASTNode:
        """Parse a table reference (table name with optional alias and secrets)."""
        var node = ASTNode("TABLE_REFERENCE", "", self.previous().line, self.previous().column)
        
        # Support identifiers (table names), strings (HTTP URLs or quoted file names), or file paths
        var table_name: String
        if self.check(STRING):
            var string_token = self.consume(STRING, "Expected table name, URL, or file path")
            table_name = string_token.value
            # Check if this is actually an HTTP URL
            if table_name.startswith("http://") or table_name.startswith("https://"):
                node.set_attribute("is_url", "true")
            else:
                node.set_attribute("is_url", "false")
        else:
            # Parse table name or file path (allow dots in file names)
            table_name = self.parse_table_or_file_name()
            node.set_attribute("is_url", "false")
        
        node.set_attribute("table", table_name)

        # Check for alias
        if self.match(AS):
            var alias_token = self.consume(IDENTIFIER, "Expected alias after AS")
            node.set_attribute("alias", alias_token.value)
        elif self.check(IDENTIFIER):
            var alias_token = self.advance()
            node.set_attribute("alias", alias_token.value)

        # Check for time travel clauses (AS OF, SINCE/UNTIL)
        if self.match(AS):
            if self.match("OF"):  # AS OF
                var time_clause = self.parse_time_travel_clause()
                node.add_child(time_clause)
                node.set_attribute("has_time_travel", "true")
            else:
                self.error("Expected 'OF' after 'AS'")
        elif self.check(IDENTIFIER) and self.peek().value == "SINCE":
            var time_clause = self.parse_time_travel_clause()
            node.add_child(time_clause)
            node.set_attribute("has_time_travel", "true")

        # Check for WITH SECRET clause
        if self.match(WITH):
            _ = self.consume(SECRET, "Expected SECRET after WITH")
            _ = self.consume(LBRACKET, "Expected '[' after SECRET")

            var secrets = List[String]()
            secrets.append(self.consume(IDENTIFIER, "Expected secret name").value)
            while self.match(COMMA):
                secrets.append(self.consume(IDENTIFIER, "Expected secret name").value)
            
            _ = self.consume(RBRACKET, "Expected ']' after secret names")
            
            var secret_list = String(", ").join(secrets)
            node.set_attribute("secrets", secret_list)

        return node^

    fn is_join_keyword(mut self) -> Bool:
        """Check if the next token is a JOIN keyword."""
        return self.check(JOIN) or self.check(LEFT) or self.check(RIGHT) or self.check(FULL) or self.check(INNER) or self.check(ANTI)

    fn parse_join_clause(mut self) raises -> ASTNode:
        """Parse a JOIN clause."""
        var join_type = self.determine_join_type()
        
        # Create appropriate AST node based on join type
        var node: ASTNode
        if join_type == "LEFT":
            node = ASTNode(AST_LEFT_JOIN, "", self.previous().line, self.previous().column)
        elif join_type == "RIGHT":
            node = ASTNode(AST_RIGHT_JOIN, "", self.previous().line, self.previous().column)
        elif join_type == "FULL":
            node = ASTNode(AST_FULL_JOIN, "", self.previous().line, self.previous().column)
        elif join_type == "INNER":
            node = ASTNode(AST_INNER_JOIN, "", self.previous().line, self.previous().column)
        elif join_type == "ANTI":
            node = ASTNode(AST_ANTI_JOIN, "", self.previous().line, self.previous().column)
        else:
            node = ASTNode(AST_JOIN, "", self.previous().line, self.previous().column)
        
        # Parse the joined table
        var joined_table = self.parse_table_reference()
        node.add_child(joined_table)
        
        # Parse ON clause
        _ = self.consume(ON, "Expected ON clause after JOIN")
        var on_condition = self.expression()
        node.add_child(on_condition)
        
        return node^

    fn determine_join_type(mut self) raises -> String:
        """Determine the type of JOIN and consume the tokens."""
        if self.match(LEFT):
            _ = self.consume(JOIN, "Expected JOIN after LEFT")
            return "LEFT"
        elif self.match(RIGHT):
            _ = self.consume(JOIN, "Expected JOIN after RIGHT")
            return "RIGHT"
        elif self.match(FULL):
            _ = self.consume(JOIN, "Expected JOIN after FULL")
            return "FULL"
        elif self.match(INNER):
            _ = self.consume(JOIN, "Expected JOIN after INNER")
            return "INNER"
        elif self.match(ANTI):
            _ = self.consume(JOIN, "Expected JOIN after ANTI")
            return "ANTI"
        else:
            _ = self.consume(JOIN, "Expected JOIN keyword")
            return "INNER"  # Default to INNER JOIN

    fn parse_table_or_file_name(mut self) raises -> String:
        """Parse table name or file path (allows dots in file names)."""
        var name_parts = List[String]()
        
        # Consume first identifier
        var first_token = self.consume(IDENTIFIER, "Expected table name or file path after FROM")
        name_parts.append(first_token.value)
        
        # Allow additional identifiers separated by dots
        while self.match(DOT):
            var next_token = self.consume(IDENTIFIER, "Expected identifier after dot")
            name_parts.append(".")
            name_parts.append(next_token.value)
        
        return String("").join(name_parts)

    fn parse_where_clause(mut self) raises -> ASTNode:
        """Parse WHERE clause."""
        var node = ASTNode(AST_WHERE, "", self.previous().line, self.previous().column)
        var condition = self.expression()
        node.add_child(condition)
        return node^

    fn parse_group_by_clause(mut self) raises -> ASTNode:
        """Parse GROUP BY clause."""
        var node = ASTNode("GROUP_BY", "", self.previous().line, self.previous().column)

        while True:
            var col = self.expression()
            node.add_child(col)
            if not self.match(COMMA):
                break

        return node^

fn parse_having_clause(mut self) raises -> ASTNode:
    """Parse HAVING clause (filters grouped results)."""
    var node = ASTNode("HAVING", "", self.previous().line, self.previous().column)

    # Parse the HAVING condition (similar to WHERE)
    var condition = self.expression()
    node.add_child(condition)

    return node^

# Window Function AST Nodes
enum FrameType:
    ROWS, RANGE

enum FrameBoundType:
    UNBOUNDED_PRECEDING, CURRENT_ROW, UNBOUNDED_FOLLOWING, PRECEDING, FOLLOWING

struct FrameBound(Movable):
    var type: FrameBoundType
    var offset: Optional[Int]  # For numeric offsets

    fn __init__(out self, bound_type: FrameBoundType, offset: Optional[Int] = None):
        self.type = bound_type
        self.offset = offset

enum FrameExclusion:
    NO_EXCLUSION, EXCLUDE_CURRENT_ROW, EXCLUDE_GROUP, EXCLUDE_TIES, EXCLUDE_NO_OTHERS

struct WindowFrame(Movable):
    var type: FrameType
    var start_bound: FrameBound
    var end_bound: FrameBound
    var exclusion: FrameExclusion

    fn __init__(out self, frame_type: FrameType, start: FrameBound, end: FrameBound, exclusion: FrameExclusion = FrameExclusion.NO_EXCLUSION):
        self.type = frame_type
        self.start_bound = start
        self.end_bound = end
        self.exclusion = exclusion

struct WindowSpec(Movable):
    var partition_by: List[ASTNode]
    var order_by: List[ASTNode]
    var frame: Optional[WindowFrame]

    fn __init__(out self):
        self.partition_by = List[ASTNode]()
        self.order_by = List[ASTNode]()
        self.frame = None

struct WindowFunction(Movable):
    var function_name: String
    var arguments: List[ASTNode]
    var window_spec: WindowSpec

    fn __init__(out self, name: String):
        self.function_name = name
        self.arguments = List[ASTNode]()
        self.window_spec = WindowSpec()

fn parse_window_function(mut self) raises -> ASTNode:
    """Parse window function like @RowNumber() OVER (...)"""
    var node = ASTNode("WINDOW_FUNCTION", "", self.previous().line, self.previous().column)

    # Parse function name (should start with @)
    var func_name = self.previous().value
    node.set_attribute("function_name", func_name)

    # Parse arguments
    _ = self.consume(LPAREN, "Expected '(' after window function name")

    var args = List[ASTNode]()
    if not self.check(RPAREN):
        args.append(self.expression())
        while self.match(COMMA):
            args.append(self.expression())

    _ = self.consume(RPAREN, "Expected ')' after window function arguments")

    # Parse OVER clause
    _ = self.consume(OVER, "Expected OVER after window function")
    _ = self.consume(LPAREN, "Expected '(' after OVER")

    var window_spec = parse_window_specification(self)
    node.add_child(window_spec)

    _ = self.consume(RPAREN, "Expected ')' after window specification")

    return node^

fn parse_window_specification(mut self) raises -> ASTNode:
    """Parse window specification: PARTITION BY ... ORDER BY ... [frame]"""
    var node = ASTNode("WINDOW_SPEC", "", self.previous().line, self.previous().column)

    # Parse PARTITION BY (optional)
    if self.match(PARTITION):
        _ = self.consume(BY, "Expected BY after PARTITION")
        var partition_node = ASTNode("PARTITION_BY", "", self.previous().line, self.previous().column)

        var partition_cols = List[ASTNode]()
        partition_cols.append(self.expression())
        while self.match(COMMA):
            partition_cols.append(self.expression())

        for col in partition_cols:
            partition_node.add_child(col^)

        node.add_child(partition_node^)

    # Parse ORDER BY (optional)
    if self.match(ORDER):
        _ = self.consume(BY, "Expected BY after ORDER")
        var order_node = ASTNode("ORDER_BY", "", self.previous().line, self.previous().column)

        var order_specs = List[ASTNode]()
        order_specs.append(self.parse_order_spec())
        while self.match(COMMA):
            order_specs.append(self.parse_order_spec())

        for spec in order_specs:
            order_node.add_child(spec^)

        node.add_child(order_node^)

    # Parse window frame (optional)
    if self.match(ROWS) or self.match(RANGE):
        var frame_node = self.parse_window_frame()
        node.add_child(frame_node)

    return node^

fn parse_window_frame(mut self) raises -> ASTNode:
    """Parse window frame: ROWS|RANGE [GROUPS] BETWEEN start_bound AND end_bound [EXCLUDE clause]"""
    var node = ASTNode("WINDOW_FRAME", "", self.previous().line, self.previous().column)

    # Determine frame type
    if self.previous().type == "ROWS":
        node.set_attribute("frame_type", "ROWS")
    elif self.previous().type == "RANGE":
        node.set_attribute("frame_type", "RANGE")
    elif self.previous().type == "GROUPS":
        node.set_attribute("frame_type", "GROUPS")
        # GROUPS frames not yet implemented - treated as ROWS for now
    else:
        node.set_attribute("frame_type", "ROWS")  # Default

    # Expect BETWEEN
    _ = self.consume(BETWEEN, "Expected BETWEEN after frame type")

    # Parse start bound
    var start_bound = self.parse_frame_bound()
    node.add_child(start_bound)

    # Expect AND
    _ = self.consume_custom("AND", "Expected AND between frame bounds")

    # Parse end bound
    var end_bound = self.parse_frame_bound()
    node.add_child(end_bound)

    # Parse optional EXCLUDE clause
    if self.match(EXCLUDE):
        var exclude_node = self.parse_exclude_clause()
        node.add_child(exclude_node)

    return node^

fn parse_exclude_clause(mut self) raises -> ASTNode:
    """Parse EXCLUDE clause: EXCLUDE CURRENT ROW | GROUP | TIES | NO OTHERS"""
    var node = ASTNode("EXCLUDE_CLAUSE", "", self.previous().line, self.previous().column)

    if self.match(CURRENT):
        _ = self.consume(ROW, "Expected ROW after CURRENT")
        node.set_attribute("exclude_type", "CURRENT_ROW")
    elif self.match_custom("GROUP"):
        node.set_attribute("exclude_type", "GROUP")
    elif self.match(TIES):
        node.set_attribute("exclude_type", "TIES")
    elif self.match(NO):
        _ = self.consume_custom("OTHERS", "Expected OTHERS after NO")
        node.set_attribute("exclude_type", "NO_OTHERS")
    else:
        self.error("Expected CURRENT ROW, GROUP, TIES, or NO OTHERS after EXCLUDE")

    return node^

fn parse_frame_bound(mut self) raises -> ASTNode:
    """Parse frame bound: UNBOUNDED PRECEDING | CURRENT ROW | n PRECEDING | n FOLLOWING | UNBOUNDED FOLLOWING | INTERVAL '...' PRECEDING/FOLLOWING"""
    var node = ASTNode("FRAME_BOUND", "", self.previous().line, self.previous().column)

    if self.match(UNBOUNDED):
        if self.match(PRECEDING):
            node.set_attribute("bound_type", "UNBOUNDED_PRECEDING")
        elif self.match(FOLLOWING):
            node.set_attribute("bound_type", "UNBOUNDED_FOLLOWING")
        else:
            self.error("Expected PRECEDING or FOLLOWING after UNBOUNDED")
    elif self.match(CURRENT):
        _ = self.consume(ROW, "Expected ROW after CURRENT")
        node.set_attribute("bound_type", "CURRENT_ROW")
    elif self.match_custom("INTERVAL"):
        # INTERVAL 'value unit' PRECEDING/FOLLOWING
        var interval_str = self.parse_string_literal()
        var interval_value = self.parse_interval_value(interval_str)

        if self.match(PRECEDING):
            node.set_attribute("bound_type", "PRECEDING")
            node.set_attribute("interval", interval_value)
        elif self.match(FOLLOWING):
            node.set_attribute("bound_type", "FOLLOWING")
            node.set_attribute("interval", interval_value)
        else:
            self.error("Expected PRECEDING or FOLLOWING after INTERVAL")
    else:
        # Numeric offset
        var offset_token = self.consume(NUMBER, "Expected number for offset")
        var offset = Int(offset_token.value)

        if self.match(PRECEDING):
            node.set_attribute("bound_type", "PRECEDING")
            node.set_attribute("offset", String(offset))
        elif self.match(FOLLOWING):
            node.set_attribute("bound_type", "FOLLOWING")
            node.set_attribute("offset", String(offset))
        else:
            self.error("Expected PRECEDING or FOLLOWING after numeric offset")

    return node^

fn parse_interval_value(self, interval_str: String) raises -> String:
    """Parse interval string like '7 days' into a standardized format."""
    # Basic parsing - could be enhanced for more complex intervals
    if interval_str.startswith("'") and interval_str.endswith("'"):
        return interval_str[1:-1]  # Remove quotes
    return interval_str

fn match_custom(mut self, keyword: String) -> Bool:
    """Match a custom keyword (not predefined token)."""
    if self.check(IDENTIFIER) and self.peek().value == keyword:
        _ = self.advance()
        return True
    return False

fn consume_custom(mut self, keyword: String, message: String) raises:
    """Consume a custom keyword."""
    if not self.match_custom(keyword):
        self.error(message)

fn parse_order_spec(mut self) raises -> ASTNode:
    """Parse order specification: column ASC|DESC"""
    var node = ASTNode("ORDER_SPEC", "", self.previous().line, self.previous().column)

    var expr = self.expression()
    node.add_child(expr)

    if self.match("ASC") or self.match("DESC") or self.match("DSC"):
        var direction = self.previous().value
        node.set_attribute("direction", direction)
    else:
        node.set_attribute("direction", "ASC")  # Default

    return node^

fn parse_potential_window_function(mut self, name: String) raises -> ASTNode:
    """Parse potential window function (starts with @)."""
    var start_pos = self.current - 1  # We already consumed the identifier

    # Parse function call first
    var func_call = self.parse_function_call(name)

    # Check if followed by OVER (indicating window function)
    if self.check(OVER):
        # Convert to window function
        var window_node = ASTNode("WINDOW_FUNCTION", "", func_call.line, func_call.column)
        window_node.set_attribute("function_name", name)

        # Extract arguments from function call
        if func_call.children.size > 0:
            for i in range(func_call.children.size):
                window_node.add_child(func_call.children[i])

        # Parse OVER clause
        _ = self.consume(OVER, "Expected OVER after window function")
        _ = self.consume(LPAREN, "Expected '(' after OVER")

        var window_spec = self.parse_window_specification()
        window_node.add_child(window_spec)

        _ = self.consume(RPAREN, "Expected ')' after window specification")

        return window_node^
    else:
        # Regular function call
        return func_call

    fn parse_order_by_clause(mut self) raises -> ASTNode:
        """Parse ORDER BY clause."""
        var node = ASTNode("ORDER_BY", "", self.previous().line, self.previous().column)

        while True:
            var direction = "ASC"
            var col: Optional[ASTNode] = None

            # Check if direction comes first (ASC|DESC column)
            if self.match("ASC") or self.match("DESC") or self.match("DSC"):
                direction = self.previous().value
                if direction == "DSC":
                    direction = "DESC"  # Handle typo
                col = self.expression()
            else:
                # Check if it's column [ASC|DESC] (original syntax)
                col = self.expression()
                if self.match("ASC") or self.match("DESC") or self.match("DSC"):
                    direction = self.previous().value
                    if direction == "DSC":
                        direction = "DESC"  # Handle typo

            if col:
                col.value().set_attribute("direction", direction)
                node.add_child(col.value())
            else:
                # Handle case like "ORDER BY ASC" without column
                # This is invalid SQL but we'll handle it gracefully
                var dummy_col = ASTNode("IDENTIFIER", "*", self.previous().line, self.previous().column)
                dummy_col.set_attribute("direction", direction)
                node.add_child(dummy_col)

            if not self.match(COMMA):
                break

        return node^

    fn parse_then_clause(mut self) raises -> ASTNode:
        """Parse THEN clause for iteration over query results."""
        var node = ASTNode("THEN", "", self.previous().line, self.previous().column)

        # Parse the block of statements to execute for each row
        if self.match(LBRACE):
            var block_node = ASTNode("BLOCK", "", self.previous().line, self.previous().column)
            while not self.check(RBRACE) and not self.is_at_end():
                var stmt = self.statement()
                block_node.add_child(stmt)
            _ = self.consume(RBRACE, "Expected '}' after THEN body")
            node.add_child(block_node)
        else:
            var body = self.statement()
            node.add_child(body)

        return node^

    fn expression(mut self) raises -> ASTNode:
        """Parse expression with precedence climbing."""
        return self.parse_expression(0)

    fn parse_expression(mut self, precedence: Int) raises -> ASTNode:
        """Parse expression with operator precedence."""
        var left = self.parse_unary()

        # Handle postfix operations (indexing)
        left = self.parse_postfix(left)

        while not self.is_at_end():
            var op_precedence = self.get_operator_precedence()
            if op_precedence < 0 or op_precedence < precedence:
                break

            var operator = self.advance().value
            var right = self.parse_expression(op_precedence + 1)

            var binary_node = ASTNode(AST_BINARY_OP, operator, self.previous().line, self.previous().column)
            binary_node.add_child(left)
            binary_node.add_child(right)
            left = binary_node^

        return left^

    fn parse_unary(mut self) raises -> ASTNode:
        """Parse unary expressions."""
        if self.match(NOT) or self.match(BANG) or self.match(MINUS):
            var operator = self.previous().value
            var operand = self.parse_unary()  # Allow chaining like !!x or --x
            var unary_node = ASTNode(AST_UNARY_OP, operator, self.previous().line, self.previous().column)
            unary_node.add_child(operand)
            return unary_node^
        else:
            return self.primary()

    fn parse_postfix(mut self, expr: ASTNode) raises -> ASTNode:
        """Parse postfix operations like indexing, member access, and MATCH expressions."""
        var result = expr.copy()

        while True:
            if self.match(LBRACKET):
                # Parse indexing operation
                var index_expr = self.expression()
                _ = self.consume(RBRACKET, "Expected ']' after index expression")

                var index_node = ASTNode("INDEX", "index", self.previous().line, self.previous().column)
                index_node.add_child(result)
                index_node.add_child(index_expr)
                result = index_node^
            elif self.match(DOT):
                # Parse member access operation
                _ = self.consume(IDENTIFIER, "Expected identifier after '.'")

                var member_name = self.previous().value
                var member_node = ASTNode(AST_MEMBER_ACCESS, member_name, self.previous().line, self.previous().column)
                member_node.add_child(result)
                result = member_node^
            elif self.match(MATCH):
                # Parse MATCH expression
                result = self.parse_match_expression(result)
            else:
                break

        return result^

    fn parse_match_expression(mut self, match_expr: ASTNode) raises -> ASTNode:
        """Parse MATCH expression: expr MATCH { pattern -> value, ... }."""
        var match_node = ASTNode(AST_MATCH, "match", self.previous().line, self.previous().column)
        match_node.add_child(match_expr)  # The expression being matched

        _ = self.consume(LBRACE, "Expected '{' after MATCH")

        # Parse match cases: pattern -> value
        while not self.check(RBRACE) and not self.is_at_end():
            # Parse pattern (can be literal, identifier, or _ for wildcard)
            var pattern: ASTNode
            if self.match(UNDERSCORE):
                pattern = ASTNode(AST_LITERAL, "_", self.previous().line, self.previous().column)
            else:
                pattern = self.expression()

            _ = self.consume(ARROW, "Expected '->' after pattern in MATCH case")

            # Parse value expression
            var value = self.expression()

            # Create case node with pattern and value
            var case_node = ASTNode("MATCH_CASE", "case")
            case_node.add_child(pattern)
            case_node.add_child(value)
            match_node.add_child(case_node)

            # Check for comma (optional for last case)
            if not self.match(COMMA):
                break

        _ = self.consume(RBRACE, "Expected '}' after MATCH cases")
        return match_node^

    fn primary(mut self) raises -> ASTNode:
        """Parse primary expressions."""
        if self.match(LPAREN):
            var expr = self.expression()
            _ = self.consume(RPAREN, "Expected ')' after expression")
            return expr^
        elif self.match(LBRACKET):
            # Handle array literals like [] or [item1, item2, ...]
            return self.parse_array_literal()
        elif self.match(LBRACE):
            # Handle struct literals like {} or {key: value, ...}
            return self.parse_struct_literal()
        elif self.match(NUMBER):
            return ASTNode(AST_LITERAL, self.previous().value, self.previous().line, self.previous().column)
        elif self.match(STRING):
            return ASTNode(AST_LITERAL, self.previous().value, self.previous().line, self.previous().column)
        elif self.match(TRUE) or self.match(FALSE):
            return ASTNode(AST_LITERAL, self.previous().value, self.previous().line, self.previous().column)
        elif self.match(UNDERSCORE):
            return ASTNode(AST_LITERAL, "_", self.previous().line, self.previous().column)
        elif self.match(IDENTIFIER):
            var name = self.previous().value
            var var_type = self.symbol_table.lookup(name)
            
            # Check if this is Array<Type> syntax
            if name == "Array" and self.check(LANGLE):
                return self.parse_typed_array()
            # Check if this is a window function (starts with @ and followed by OVER)
            elif name.startswith("@") and self.check(LPAREN):
                # Parse as window function
                var func_token = self.previous()
                _ = self.advance()  # Consume the identifier again? Wait, let me fix this
                # Actually, let me rewind and handle this differently
                return self.parse_potential_window_function(name)
            else:
                var node = ASTNode(AST_IDENTIFIER, name, self.previous().line, self.previous().column)
                node.set_attribute("type", var_type)
                return node^
        elif self.match(TYPEOF):
            # Handle @TypeOf function
            _ = self.consume(LPAREN, "Expected '(' after @TypeOf")
            var arg = self.expression()
            _ = self.consume(RPAREN, "Expected ')' after @TypeOf argument")
            var node = ASTNode("TYPEOF", "@TypeOf", self.previous().line, self.previous().column)
            node.add_child(arg)
            return node^
        elif self.match(ARRAY):
            # Handle Array<Type> syntax when Array is tokenized as keyword
            if self.check(LANGLE):
                return self.parse_typed_array()
            else:
                # Just Array keyword without generics
                return ASTNode(AST_IDENTIFIER, "Array", self.previous().line, self.previous().column)
        elif self.match(VARIABLE):
            var name = self.previous().value
            var node = ASTNode("VARIABLE", name, self.previous().line, self.previous().column)
            return node^

        # Error case
        _ = self.advance()  # Skip unknown token
        return ASTNode("ERROR", "Unexpected token", self.previous().line, self.previous().column)

    fn parse_array_literal(mut self) raises -> ASTNode:
        """Parse array literal expressions like [] or [item1, item2, ...]."""
        var node = ASTNode(AST_ARRAY, "", self.previous().line, self.previous().column)
        
        # Check if this is an empty array []
        if self.match(RBRACKET):
            # Empty array
            return node^
        
        # Parse array elements
        while True:
            var element = self.expression()
            node.add_child(element)
            
            if not self.match(COMMA):
                break
        
        _ = self.consume(RBRACKET, "Expected ']' after array elements")
        return node^

    fn parse_struct_literal(mut self) raises -> ASTNode:
        """Parse struct literal expressions like {} or {key: value, ...}."""
        var node = ASTNode("STRUCT_LITERAL", "", self.previous().line, self.previous().column)
        
        # Check if this is an empty struct {}
        if self.match(RBRACE):
            return node^
        
        # Parse struct fields
        while True:
            var key = self.consume(IDENTIFIER, "Expected field name").value
            _ = self.consume(COLON, "Expected ':' after field name")
            var value = self.expression()
            
            var field_node = ASTNode("FIELD", key)
            field_node.add_child(value)
            node.add_child(field_node)
            
            if not self.match(COMMA):
                break
        
        _ = self.consume(RBRACE, "Expected '}' after struct fields")
        return node^

    fn parse_time_travel_clause(mut self) raises -> ASTNode:
        """Parse time travel clauses: AS OF timestamp or SINCE start UNTIL end."""
        var node = ASTNode("TIME_TRAVEL_CLAUSE")

        if self.match("AS"):
            if not self.match("OF"):
                self.error("Expected 'OF' after 'AS'")
            node.add_attribute("mode", "AS_OF")
            var timestamp_node = self.parse_timestamp_value()
            node.add_child(timestamp_node)
        elif self.match("SINCE"):
            node.add_attribute("mode", "SINCE_UNTIL")
            var start_ts = self.parse_timestamp_value()
            node.add_child(start_ts)

            if self.match("UNTIL"):
                var end_ts = self.parse_timestamp_value()
                node.add_child(end_ts)
            # If no UNTIL, end timestamp remains unbounded
        else:
            self.error("Expected AS OF or SINCE clause")

        return node

    fn parse_timestamp_value(mut self) raises -> ASTNode:
        """Parse timestamp value (number, string literal, or identifier)."""
        var node = ASTNode("TIMESTAMP_VALUE")

        if self.current_token.type == "NUMBER":
            # Unix timestamp number
            var literal_node = self.parse_number_literal()
            node.add_child(literal_node)
            node.add_attribute("format", "unix")
        elif self.current_token.type == "STRING":
            # ISO 8601 string
            var literal_node = self.parse_string_literal()
            node.add_child(literal_node)
            node.add_attribute("format", "iso8601")
        elif self.current_token.type == "IDENTIFIER":
            # Identifier (could be column reference or function)
            var ident_node = self.parse_identifier()
            node.add_child(ident_node)
            node.add_attribute("format", "identifier")
        else:
            self.error("Expected timestamp number, string, or identifier")

        return node

    fn parse_struct_literal_content(mut self) raises -> ASTNode:
        """Parse the content of a struct literal (fields only, without outer braces)."""
        var node = ASTNode("STRUCT_LITERAL", "", self.previous().line, self.previous().column)
        
        # Check if this is an empty struct
        if self.match(RBRACE):
            return node^
        
        # Parse struct fields
        while True:
            var key = self.consume(IDENTIFIER, "Expected field name").value
            _ = self.consume(COLON, "Expected ':' after field name")
            var value = self.expression()
            
            var field_node = ASTNode("FIELD", key)
            field_node.add_child(value)
            node.add_child(field_node)
            
            if not self.match(COMMA):
                break
        
        _ = self.consume(RBRACE, "Expected '}' after struct fields")
        return node^

    fn parse_typed_array(mut self) raises -> ASTNode:
        """Parse typed array expressions like Array<Type> or Array<Type>::[...] or Array<Type> as [...]"""
        var node = ASTNode("TYPED_ARRAY", "", self.previous().line, self.previous().column)
        
        # Parse the type parameter
        _ = self.consume(LANGLE, "Expected '<' after Array")
        var type_name = self.consume(IDENTIFIER, "Expected type name").value
        node.set_attribute("type", type_name)
        _ = self.consume(RANGLE, "Expected '>' after type name")
        
        # Check for constructor syntax Array<Type>::[...]
        if self.match(DOUBLE_COLON):
            _ = self.consume(LBRACKET, "Expected '[' after '::'")
            var array_literal = self.parse_array_literal()
            node.add_child(array_literal)
            node.set_attribute("syntax", "constructor")
        # Check for 'as' syntax Array<Type> as [...]
        elif self.match(AS):
            _ = self.consume(LBRACKET, "Expected '[' after 'as'")
            var array_literal = self.parse_array_literal()
            node.add_child(array_literal)
            node.set_attribute("syntax", "as")
        else:
            # Just Array<Type> without initialization
            node.set_attribute("syntax", "declaration")
        
        return node^

    fn parse_array_aggregation(mut self) raises -> ASTNode:
        """Parse array aggregation expressions like Array::(Distinct column) or Array::(Count(*))"""
        var node = ASTNode("ARRAY_AGGREGATION", "", self.peek().line, self.peek().column)
        
        # Consume ARRAY
        _ = self.consume(ARRAY, "Expected 'Array'")
        # Consume ::
        _ = self.consume(DOUBLE_COLON, "Expected '::' after Array")
        # Consume (
        _ = self.consume(LPAREN, "Expected '(' after '::'")
        
        # Parse the aggregation expression
        var agg_expr = self.parse_aggregation_expression()
        node.add_child(agg_expr)
        
        # Consume )
        _ = self.consume(RPAREN, "Expected ')' after aggregation expression")
        
        return node^

    fn parse_aggregation_expression(mut self) raises -> ASTNode:
        """Parse aggregation expressions like Distinct column or Count(*)"""
        var node = ASTNode("AGGREGATION_EXPR", "", self.peek().line, self.peek().column)
        
        # Check for DISTINCT
        if self.match(DISTINCT):
            node.set_attribute("function", "DISTINCT")
            var expr = self.expression()
            node.add_child(expr)
        # Check for aggregate functions
        elif self.check(SUM) or self.check(COUNT) or self.check(AVG) or self.check(MIN) or self.check(MAX):
            var func_name = self.advance().value
            node.set_attribute("function", func_name)
            _ = self.consume(LPAREN, "Expected '(' after aggregate function")
            var expr = self.expression()
            node.add_child(expr)
            _ = self.consume(RPAREN, "Expected ')' after aggregate function argument")
        else:
            # Default to DISTINCT if no function specified
            node.set_attribute("function", "DISTINCT")
            var expr = self.expression()
            node.add_child(expr)
        
        return node^

    fn parse_function_call(mut self, func_name: String) raises -> ASTNode:
        """Parse function call expression."""
        var node = ASTNode(AST_CALL, func_name, self.previous().line, self.previous().column)
        node.set_attribute("name", func_name)

        _ = self.consume(LPAREN, "Expected '(' after function name")

        # Parse arguments
        if not self.check(RPAREN):
            while True:
                var arg = self.expression()
                node.add_child(arg)
                if not self.match(COMMA):
                    break

        _ = self.consume(RPAREN, "Expected ')' after function arguments")

        return node^

    fn get_operator_precedence(self) -> Int:
        """Get operator precedence level."""
        if self.check(OR):
            return 1
        elif self.check(AND):
            return 2
        elif self.check(EQUALS) or self.check(NOT_EQUALS):
            return 3
        elif self.check(LESS) or self.check(GREATER) or self.check(LESS_EQUAL) or self.check(GREATER_EQUAL):
            return 4
        elif self.check(PLUS) or self.check(MINUS):
            return 5
        elif self.check(MULTIPLY) or self.check(DIVIDE) or self.check(MODULO):
            return 6
        elif self.check(PIPE):
            return 7
        return -1  # Not an operator

    fn create_statement(mut self) raises -> ASTNode:
        """Parse CREATE statement."""
        var node = ASTNode(AST_CREATE, "", self.previous().line, self.previous().column)

        if self.check(IDENTIFIER) and self.peek().value == "TABLE":
            _ = self.advance()  # consume TABLE
            return self.create_table_statement()
        elif self.match(SECRET):
            return self.create_secret_statement()
        elif self.match(FUNCTION):
            return self.function_statement()
        elif self.match(INDEX):
            return self.index_statement()
        elif self.match(VIEW):
            return self.view_statement()
        else:
            self.error("Expected TABLE, SECRET, FUNCTION, INDEX, or VIEW after CREATE")
            return node^

    fn create_table_statement(mut self) raises -> ASTNode:
        """Parse CREATE TABLE statement."""
        var node = ASTNode("CREATE_TABLE", "", self.previous().line, self.previous().column)

        # Parse table name
        var table_name = self.consume(IDENTIFIER, "Expected table name").value
        var table_node = ASTNode("TABLE_NAME", table_name, self.previous().line, self.previous().column)
        node.add_child(table_node)

        # Parse column definitions
        _ = self.consume(LPAREN, "Expected '(' after table name")

        var columns_node = ASTNode("COLUMNS", "", self.previous().line, self.previous().column)
        if not self.check(RPAREN):
            while True:
                var col_node = self.parse_column_definition()
                columns_node.add_child(col_node)
                if not self.match(COMMA):
                    break

        _ = self.consume(RPAREN, "Expected ')' after column definitions")
        node.add_child(columns_node)

        return node^

    fn parse_column_definition(mut self) raises -> ASTNode:
        """Parse a column definition: column_name column_type"""
        var col_name = self.consume(IDENTIFIER, "Expected column name").value

        # Check for TYPE SECRET syntax
        var col_type: String
        if self.match(TYPE):
            col_type = "TYPE " + self.consume(SECRET, "Expected SECRET after TYPE").value
        else:
            col_type = self.consume(IDENTIFIER, "Expected column type").value

        var col_node = ASTNode("COLUMN", "", self.previous().line, self.previous().column)
        col_node.add_child(ASTNode("COLUMN_NAME", col_name, self.previous().line, self.previous().column))
        col_node.add_child(ASTNode("COLUMN_TYPE", col_type, self.previous().line, self.previous().column))

        return col_node^

    fn function_statement(mut self) raises -> ASTNode:
        """Parse function definition with extended syntax support."""
        var node = ASTNode(AST_FUNCTION, "", self.previous().line, self.previous().column)

        # Check for receiver syntax: <ReceiverType>
        var receiver_type: String = ""
        if self.match(LANGLE):
            receiver_type = self.consume(IDENTIFIER, "Expected receiver type").value
            _ = self.consume(RANGLE, "Expected '>' after receiver type")
            node.set_attribute("receiver_type", receiver_type)

        var func_name = self.consume(IDENTIFIER, "Expected function name").value
        node.set_attribute("name", func_name)

        _ = self.consume(LPAREN, "Expected '(' after function name")

        # Parse parameters with optional type annotations
        if not self.check(RPAREN):
            while True:
                var param_name = self.consume(IDENTIFIER, "Expected parameter name").value
                var param_node = ASTNode("PARAMETER", param_name, self.previous().line, self.previous().column)

                # Optional type annotation
                if self.match(COLON):
                    var param_type = self.consume(IDENTIFIER, "Expected parameter type").value
                    param_node.set_attribute("type", param_type)

                node.add_child(param_node)
                if not self.match(COMMA):
                    break

        _ = self.consume(RPAREN, "Expected ')' after parameters")

        # Optional raises clause
        if self.check(IDENTIFIER) and self.peek().value == "raises":
            _ = self.consume(IDENTIFIER, "Expected 'raises'")  # This will consume "raises"
            var exception_type = self.consume(IDENTIFIER, "Expected exception type").value
            node.set_attribute("raises", exception_type)

        # Optional execution mode: as async|sync
        if self.match(AS):
            if self.match(ASYNC):
                node.set_attribute("execution_mode", "async")
            elif self.match(SYNC):
                node.set_attribute("execution_mode", "sync")
            else:
                self.error("Expected 'async' or 'sync' after 'as'")

        # Optional returns clause
        if self.match(RETURNS):
            var return_type = self.consume(IDENTIFIER, "Expected return type").value
            node.set_attribute("return_type", return_type)

        _ = self.consume(LBRACE, "Expected '{' before function body")
        var block_node = ASTNode("BLOCK", "", self.previous().line, self.previous().column)
        while not self.check(RBRACE) and not self.is_at_end():
            var stmt = self.statement()
            block_node.add_child(stmt)
        _ = self.consume(RBRACE, "Expected '}' after function body")

        node.add_child(block_node)

        return node^

    fn upsert_procedure_statement(mut self) raises -> ASTNode:
        """Parse UPSERT PROCEDURE statement."""
        var node = ASTNode(AST_UPSERT_PROCEDURE, "", self.previous().line, self.previous().column)

        # Check for receiver syntax: <ReceiverType>
        var receiver_type: String = ""
        if self.match(LANGLE) and not self.check(LBRACE):  # Make sure it's not the metadata block
            receiver_type = self.consume(IDENTIFIER, "Expected receiver type").value
            _ = self.consume(RANGLE, "Expected '>' after receiver type")
            node.set_attribute("receiver_type", receiver_type)
            # After receiver, expect 'as'
            _ = self.consume(AS, "Expected AS after receiver type")
        else:
            # Expect 'as'
            _ = self.consume(AS, "Expected AS after PROCEDURE")

        # Parse procedure name
        var proc_name = self.consume(IDENTIFIER, "Expected procedure name").value
        node.set_attribute("name", proc_name)

        # Parse metadata block <{ ... }>
        _ = self.consume(LANGLE, "Expected '<' before procedure metadata")
        _ = self.consume(LBRACE, "Expected '{' after '<'")

        # Parse metadata key-value pairs
        var metadata = ASTNode("METADATA", "")
        while not self.check(RBRACE):
            var key = self.consume(IDENTIFIER, "Expected metadata key").value
            _ = self.consume(COLON, "Expected ':' after metadata key")
            var value = self.consume(STRING, "Expected string value for metadata").value
            metadata.set_attribute(key, value)

            # Allow comma-separated metadata
            if not self.match(COMMA):
                break

        _ = self.consume(RBRACE, "Expected '}' after metadata")
        _ = self.consume(RANGLE, "Expected '>' after metadata block")

        node.add_child(metadata)

        # Parse parameters ()
        _ = self.consume(LPAREN, "Expected '(' after procedure metadata")

        # Parse parameters (optional) and collect them as a string
        var param_list = List[String]()
        if not self.check(RPAREN):
            while True:
                var param_name = self.consume(IDENTIFIER, "Expected parameter name").value
                var param_type = "auto"  # Default to auto-inference

                # Optional type annotation
                if self.match(COLON):
                    param_type = self.consume(IDENTIFIER, "Expected parameter type").value

                param_list.append(param_name + ":" + param_type)
                if not self.match(COMMA):
                    break

        _ = self.consume(RPAREN, "Expected ')' after parameters")

        # Set parameters as a comma-separated string attribute
        if len(param_list) > 0:
            var param_str = ""
            for i in range(len(param_list)):
                if i > 0:
                    param_str += ","
                param_str += param_list[i]
            node.set_attribute("parameters", param_str)

        # Optional raises clause
        if self.check(IDENTIFIER) and self.peek().value == "raises":
            _ = self.consume(IDENTIFIER, "Expected 'raises'")  # This will consume "raises"
            var exception_type = self.consume(IDENTIFIER, "Expected exception type").value
            node.set_attribute("raises", exception_type)

        # Optional execution mode: as async|sync
        if self.match(AS):
            if self.match(ASYNC):
                node.set_attribute("execution_mode", "async")
            elif self.match(SYNC):
                node.set_attribute("execution_mode", "sync")
            else:
                self.error("Expected 'async' or 'sync' after 'as'")

        # Optional returns clause
        if self.match(RETURNS):
            var return_type = self.consume(IDENTIFIER, "Expected return type").value
            node.set_attribute("return_type", return_type)

        # Parse procedure body
        _ = self.consume(LBRACE, "Expected '{' before procedure body")
        var block_node = ASTNode("BLOCK", "", self.previous().line, self.previous().column)
        while not self.check(RBRACE) and not self.is_at_end():
            var stmt = self.statement()
            block_node.add_child(stmt)
        _ = self.consume(RBRACE, "Expected '}' after procedure body")

        node.add_child(block_node)

        return node^

    fn upsert_trigger_statement(mut self) raises -> ASTNode:
        """Parse UPSERT TRIGGER statement."""
        var node = ASTNode(AST_UPSERT_TRIGGER, "", self.previous().line, self.previous().column)

        # Expect 'as'
        _ = self.consume(AS, "Expected AS after TRIGGER")

        # Parse trigger name
        var trigger_name = self.consume(IDENTIFIER, "Expected trigger name").value
        node.set_attribute("name", trigger_name)

        # Parse parameters ()
        _ = self.consume(LPAREN, "Expected '(' after trigger name")

        # Parse trigger parameters: timing, event, target
        while not self.check(RPAREN):
            if self.match(IDENTIFIER):
                var param_name = self.previous().value
                if param_name == "timing":
                    _ = self.consume(COLON, "Expected ':' after timing")
                    if self.match(IDENTIFIER):
                        var timing = self.previous().value
                        if timing == "before" or timing == "after":
                            node.set_attribute("timing", timing)
                        else:
                            self.error("Expected 'before' or 'after' for timing")
                elif param_name == "event":
                    _ = self.consume(COLON, "Expected ':' after event")
                    if self.match(IDENTIFIER):
                        var event = self.previous().value
                        if event == "insert" or event == "update" or event == "delete" or event == "upsert":
                            node.set_attribute("event", event)
                        else:
                            self.error("Expected 'insert', 'update', 'delete', or 'upsert' for event")
                elif param_name == "target":
                    _ = self.consume(COLON, "Expected ':' after target")
                    var target = self.consume(STRING, "Expected target collection name").value
                    node.set_attribute("target", target)
                else:
                    self.error("Unknown trigger parameter: " + param_name)

            if not self.match(COMMA):
                break

        _ = self.consume(RPAREN, "Expected ')' after trigger parameters")

        # Parse CALL procedure_name
        _ = self.consume(CALL, "Expected CALL after trigger parameters")
        var procedure_name = self.consume(IDENTIFIER, "Expected procedure name after CALL").value
        node.set_attribute("procedure", procedure_name)

        return node^

    fn upsert_schedule_statement(mut self) raises -> ASTNode:
        """Parse UPSERT SCHEDULE statement."""
        var node = ASTNode(AST_UPSERT_SCHEDULE, "", self.previous().line, self.previous().column)

        # Expect 'as'
        _ = self.consume(AS, "Expected AS after SCHEDULE")

        # Parse schedule name
        var schedule_name = self.consume(IDENTIFIER, "Expected schedule name").value
        node.set_attribute("name", schedule_name)

        # Parse parameters ()
        _ = self.consume(LPAREN, "Expected '(' after schedule name")

        # Parse schedule parameters: sched, exe, call
        while not self.check(RPAREN):
            if self.match(IDENTIFIER):
                var param_name = self.previous().value
                if param_name == "sched":
                    _ = self.consume(COLON, "Expected ':' after sched")
                    var cron_expr = self.consume(STRING, "Expected cron expression").value
                    node.set_attribute("sched", cron_expr)
                elif param_name == "exe":
                    _ = self.consume(COLON, "Expected ':' after exe")
                    if self.match(IDENTIFIER):
                        var exe_type = self.previous().value
                        if exe_type == "pipeline" or exe_type == "procedure":
                            node.set_attribute("exe", exe_type)
                        else:
                            self.error("Expected 'pipeline' or 'procedure' for exe")
                elif param_name == "call":
                    _ = self.consume(COLON, "Expected ':' after call")
                    var call_ref = self.consume(IDENTIFIER, "Expected function/procedure reference").value
                    node.set_attribute("call", call_ref)
                else:
                    self.error("Unknown schedule parameter: " + param_name)

            if not self.match(COMMA):
                break

        _ = self.consume(RPAREN, "Expected ')' after schedule parameters")

        return node^

    fn enable_trigger_statement(mut self) raises -> ASTNode:
        """Parse ENABLE TRIGGER statement."""
        var node = ASTNode(AST_ENABLE_TRIGGER, "", self.previous().line, self.previous().column)

        # Parse trigger name
        var trigger_name = self.consume(IDENTIFIER, "Expected trigger name").value
        node.set_attribute("name", trigger_name)

        return node^

    fn disable_trigger_statement(mut self) raises -> ASTNode:
        """Parse DISABLE TRIGGER statement."""
        var node = ASTNode(AST_DISABLE_TRIGGER, "", self.previous().line, self.previous().column)

        # Parse trigger name
        var trigger_name = self.consume(IDENTIFIER, "Expected trigger name").value
        node.set_attribute("name", trigger_name)

        return node^

    fn index_statement(mut self) raises -> ASTNode:
        """Parse CREATE INDEX statement."""
        var node = ASTNode(AST_INDEX, "", self.previous().line, self.previous().column)

        var index_name = self.consume(IDENTIFIER, "Expected index name").value
        node.set_attribute("name", index_name)

        _ = self.consume(ON, "Expected ON")
        var table_name = self.consume(IDENTIFIER, "Expected table name").value
        node.set_attribute("table", table_name)

        _ = self.consume(LPAREN, "Expected '('")
        var columns = List[String]()

        while True:
            var col = self.consume(IDENTIFIER, "Expected column name").value
            columns.append(col)
            if not self.match(COMMA):
                break

        _ = self.consume(RPAREN, "Expected ')'")

        for col in columns:
            var col_node = ASTNode("COLUMN", col)
            node.add_child(col_node)

        return node^

    fn view_statement(mut self) raises -> ASTNode:
        """Parse CREATE VIEW statement."""
        var node = ASTNode("CREATE_VIEW", "", self.previous().line, self.previous().column)

        var view_name = self.consume(IDENTIFIER, "Expected view name").value
        node.set_attribute("name", view_name)

        _ = self.consume(AS, "Expected AS")
        var select_stmt = self.select_from_statement()
        node.add_child(select_stmt)

        return node^

    fn drop_statement(mut self) raises -> ASTNode:
        """Parse DROP statement."""
        var node = ASTNode(AST_DROP, "", self.previous().line, self.previous().column)

        if self.match(SECRET):
            var secret_name = self.consume(IDENTIFIER, "Expected secret name").value
            node.set_attribute("type", "SECRET")
            node.set_attribute("name", secret_name)
        elif self.match(INDEX):
            var index_name = self.consume(IDENTIFIER, "Expected index name").value
            node.set_attribute("type", "INDEX")
            node.set_attribute("name", index_name)
        elif self.match(VIEW):
            var view_name = self.consume(IDENTIFIER, "Expected view name").value
            node.set_attribute("type", "VIEW")
            node.set_attribute("name", view_name)
        else:
            self.error("Expected SECRET, INDEX or VIEW after DROP")

        return node^

    fn insert_statement(mut self) raises -> ASTNode:
        """Parse INSERT statement."""
        var node = ASTNode("INSERT", "", self.previous().line, self.previous().column)

        _ = self.consume(INTO, "Expected INTO")
        var table_name = self.consume(IDENTIFIER, "Expected table name").value
        node.set_attribute("table", table_name)

        if self.match(LPAREN):
            # Parse column list
            var columns = List[String]()
            while True:
                var col = self.consume(IDENTIFIER, "Expected column name").value
                columns.append(col)
                if not self.match(COMMA):
                    break
            _ = self.consume(RPAREN, "Expected ')'")

            for col in columns:
                var col_node = ASTNode("COLUMN", col, self.previous().line, self.previous().column)
                node.add_child(col_node)

        _ = self.consume(VALUES, "Expected VALUES")
        _ = self.consume(LPAREN, "Expected '('")

        # Parse values list
        var values_node = ASTNode("VALUES", "", self.previous().line, self.previous().column)
        while True:
            if self.match(NUMBER):
                values_node.add_child(ASTNode(AST_LITERAL, self.previous().value, self.previous().line, self.previous().column))
            elif self.match(STRING):
                values_node.add_child(ASTNode(AST_LITERAL, self.previous().value, self.previous().line, self.previous().column))
            else:
                # For now, just support literals
                self.error("Expected literal value in VALUES")

            if not self.match(COMMA):
                break

        _ = self.consume(RPAREN, "Expected ')'")
        node.add_child(values_node)

        return node^

    fn update_statement(mut self) raises -> ASTNode:
        """Parse UPDATE statement."""
        var node = ASTNode(UPDATE, "", self.previous().line, self.previous().column)

        var table_name = self.consume(IDENTIFIER, "Expected table name").value
        node.set_attribute("table", table_name)

        _ = self.consume(SET, "Expected SET")

        while True:
            var col = self.consume(IDENTIFIER, "Expected column name").value
            _ = self.consume(EQUALS, "Expected '='")
            var val = self.expression()

            var assign_node = ASTNode("ASSIGNMENT", "", self.previous().line, self.previous().column)
            assign_node.set_attribute("column", col)
            assign_node.add_child(val)
            node.add_child(assign_node)

            if not self.match(COMMA):
                break

        if self.match(WHERE):
            var where_clause = self.parse_where_clause()
            node.add_child(where_clause)

        return node^

    fn delete_statement(mut self) raises -> ASTNode:
        """Parse DELETE statement."""
        var node = ASTNode(DELETE, "", self.previous().line, self.previous().column)

        _ = self.consume(FROM, "Expected FROM")
        var table_name = self.consume(IDENTIFIER, "Expected table name").value
        node.set_attribute("table", table_name)

        if self.match(WHERE):
            var where_clause = self.parse_where_clause()
            node.add_child(where_clause)

        return node^

    fn let_statement(mut self) raises -> ASTNode:
        """Parse LET statement."""
        var node = ASTNode("LET")

        var var_name = self.consume(IDENTIFIER, "Expected variable name").value
        node.set_attribute("name", var_name)

        _ = self.consume(EQUALS, "Expected '='")
        var value = self.expression()
        node.add_child(value)

        # Add to symbol table
        self.symbol_table.define(var_name, "variable")

        return node^

    fn while_statement(mut self) raises -> ASTNode:
        """Parse WHILE statement."""
        var node = ASTNode("WHILE")

        # Parse condition
        var condition = self.expression()
        node.add_child(condition)

        # Parse body - expect a block or single statement
        if self.match(LBRACE):
            var block_node = ASTNode("BLOCK")
            while not self.check(RBRACE) and not self.is_at_end():
                var stmt = self.statement()
                block_node.add_child(stmt)
            _ = self.consume(RBRACE, "Expected '}' after while body")
            node.add_child(block_node)
        else:
            var body = self.statement()
            node.add_child(body)

        return node^

    fn break_statement(mut self) raises -> ASTNode:
        """Parse BREAK statement."""
        return ASTNode(AST_BREAK, "", self.previous().line, self.previous().column)

    fn continue_statement(mut self) raises -> ASTNode:
        """Parse CONTINUE statement."""
        return ASTNode(AST_CONTINUE, "", self.previous().line, self.previous().column)

    fn type_statement(mut self) raises -> ASTNode:
        """Parse TYPE statement (including TYPE SECRET and TYPE STRUCT)."""
        var node = ASTNode("TYPE", "", self.previous().line, self.previous().column)

        if self.match(SECRET):
            node.set_attribute("type", "SECRET")
            _ = self.consume(AS, "Expected AS after TYPE SECRET")
            var secret_name = self.consume(IDENTIFIER, "Expected secret name").value
            node.set_attribute("name", secret_name)

            _ = self.consume(LPAREN, "Expected '(' after secret name")

            # Parse key-value pairs - kind is required as first field
            var has_kind = False
            while not self.check(RPAREN) and not self.is_at_end():
                var key = self.consume(IDENTIFIER, "Expected key name").value
                _ = self.consume(COLON, "Expected ':' after key")
                var value = self.consume(STRING, "Expected string value").value

                var kv_node = ASTNode("KEY_VALUE", "", self.previous().line, self.previous().column)
                kv_node.set_attribute("key", key)
                kv_node.set_attribute("value", value)
                node.add_child(kv_node)

                if key == "kind":
                    has_kind = True

                if not self.match(COMMA):
                    break

            # Validate that kind is present
            if not has_kind:
                self.error("TYPE SECRET requires 'kind' field (e.g., kind: 'https')")

            _ = self.consume(RPAREN, "Expected ')' after secret definition")
        elif self.match(STRUCT):
            node.set_attribute("type", "STRUCT")
            _ = self.consume(AS, "Expected AS after TYPE STRUCT")
            var struct_name = self.consume(IDENTIFIER, "Expected struct name").value
            node.set_attribute("name", struct_name)

            if self.match(LPAREN):
                # Parse field definitions: field_name field_type, ...
                while not self.check(RPAREN) and not self.is_at_end():
                    var field_name = self.consume(IDENTIFIER, "Expected field name").value
                    var field_type = self.consume(IDENTIFIER, "Expected field type").value

                    var field_node = ASTNode("FIELD_DEF", field_name)
                    field_node.set_attribute("type", field_type)
                    node.add_child(field_node)

                    if not self.match(COMMA):
                        break

                _ = self.consume(RPAREN, "Expected ')' after struct field definitions")
            elif self.match(LBRACE):
                # Parse typed struct literal: { field: value, ... }
                node.node_type = "TYPED_STRUCT_LITERAL"
                node.set_attribute("struct_type", struct_name)
                
                # Check if this is an empty struct
                if self.match(RBRACE):
                    return node^
                
                # Parse struct fields
                while True:
                    var key = self.consume(IDENTIFIER, "Expected field name").value
                    _ = self.consume(COLON, "Expected ':' after field name")
                    var value = self.expression()
                    
                    var field_node = ASTNode("FIELD", key)
                    field_node.add_child(value)
                    node.add_child(field_node)
                    
                    if not self.match(COMMA):
                        break
                
                _ = self.consume(RBRACE, "Expected '}' after struct fields")
            else:
                self.error("Expected '(' for struct definition or '{' for struct literal after TYPE STRUCT AS name")
        else:
            # Handle other TYPE statements (future extension)
            self.error("Expected SECRET or STRUCT after TYPE")

        return node^

    fn copy_statement(mut self) raises -> ASTNode:
        """Parse COPY statement for importing/exporting data."""
        var node = ASTNode(AST_COPY, "", self.previous().line, self.previous().column)

        # Check if first token is a string (file path) or identifier (table name)
        if self.match(STRING):
            # COPY 'file_path' TO table_name (import)
            var file_path = self.previous().value
            node.set_attribute("source_type", "file")
            node.set_attribute("source", file_path)
            
            _ = self.consume(TO, "Expected TO")
            var table_name = self.consume(IDENTIFIER, "Expected table name").value
            node.set_attribute("destination_type", "table")
            node.set_attribute("destination", table_name)
            node.set_attribute("operation", "import")
        elif self.match(IDENTIFIER):
            # COPY table_name TO 'file_path' (export)
            var table_name = self.previous().value
            node.set_attribute("source_type", "table")
            node.set_attribute("source", table_name)
            
            _ = self.consume(TO, "Expected TO")
            var file_path = self.consume(STRING, "Expected file path").value
            node.set_attribute("destination_type", "file")
            node.set_attribute("destination", file_path)
            node.set_attribute("operation", "export")
        else:
            self.error("Expected file path (string) or table name (identifier) after COPY")

        return node^

    fn attach_statement(mut self) raises -> ASTNode:
        """Parse ATTACH statement."""
        var node = ASTNode("ATTACH", "", self.previous().line, self.previous().column)
        var db_path = self.consume(STRING, "Expected database path").value
        node.set_attribute("path", db_path)
        
        # Optional AS alias
        if self.match(AS):
            var alias_token = self.consume(IDENTIFIER, "Expected alias after AS")
            node.set_attribute("alias", alias_token.value)
        else:
            # Use the filename as default alias (without extension)
            node.set_attribute("alias", "default_db")
        
        return node^

    fn detach_statement(mut self) raises -> ASTNode:
        """Parse DETACH statement."""
        var node = ASTNode("DETACH", "", self.previous().line, self.previous().column)
        var db_name = self.consume(IDENTIFIER, "Expected database name").value
        node.set_attribute("name", db_name)
        return node^

    fn execute_statement(mut self) raises -> ASTNode:
        """Parse EXECUTE statement."""
        var node = ASTNode(AST_EXECUTE, "", self.previous().line, self.previous().column)
        var sql_alias = self.consume(IDENTIFIER, "Expected SQL file alias").value
        node.set_attribute("alias", sql_alias)
        return node^

    fn install_statement(mut self) raises -> ASTNode:
        """Parse INSTALL statement for extensions."""
        var node = ASTNode(AST_INSTALL, "", self.previous().line, self.previous().column)
        var extension_name = self.consume(IDENTIFIER, "Expected extension name").value
        node.set_attribute("extension", extension_name)
        return node^

    fn load_statement(mut self) raises -> ASTNode:
        """Parse LOAD statement for extensions."""
        var node = ASTNode(AST_LOAD, "", self.previous().line, self.previous().column)
        var extensions = List[String]()
        extensions.append(self.consume(IDENTIFIER, "Expected extension name").value)
        while self.match(COMMA):
            extensions.append(self.consume(IDENTIFIER, "Expected extension name").value)
        node.set_attribute("extensions", String(", ").join(extensions))
        return node^

    fn show_statement(mut self) raises -> ASTNode:
        """Parse SHOW statement."""
        var node = ASTNode("SHOW", "", self.previous().line, self.previous().column)
        
        if self.match(SECRETS):
            node.set_attribute("type", "SECRETS")
        elif self.match(STRUCTS):
            node.set_attribute("type", "STRUCTS")
        elif self.match(ATTACHED):
            _ = self.consume(DATABASES, "Expected DATABASES after ATTACHED")
            node.set_attribute("type", "ATTACHED_DATABASES")
        elif self.match(EXTENSIONS):
            node.set_attribute("type", "EXTENSIONS")
        else:
            self.error("Expected SECRETS, STRUCTS, ATTACHED DATABASES, or EXTENSIONS after SHOW")
        
        return node^

    fn drop_secret_statement(mut self) raises -> ASTNode:
        """Parse DROP SECRET statement."""
        var node = ASTNode("DROP_SECRET", "", self.previous().line, self.previous().column)
        var secret_name = self.consume(IDENTIFIER, "Expected secret name").value
        node.set_attribute("name", secret_name)
        return node^

    fn create_secret_statement(mut self) raises -> ASTNode:
        """Parse CREATE SECRET statement."""
        var node = ASTNode("CREATE_SECRET", "", self.previous().line, self.previous().column)
        var secret_name = self.consume(IDENTIFIER, "Expected secret name").value
        node.set_attribute("name", secret_name)

        # Parse TYPE SECRET
        _ = self.consume(TYPE, "Expected TYPE after secret name")
        _ = self.consume(SECRET, "Expected SECRET after TYPE")

        # Parse AS value
        _ = self.consume(AS, "Expected AS after SECRET")
        var secret_value = self.consume(STRING, "Expected string value after AS").value
        node.set_attribute("value", secret_value)

        return node^

    fn expression_statement(mut self) raises -> ASTNode:
        """Parse expression statement."""
        return self.expression()

    # Utility methods
    fn match(mut self, type: String) -> Bool:
        if self.check(type):
            _ = self.advance()
            return True
        return False

    fn check(self, type: String) -> Bool:
        if self.is_at_end():
            return False
        return self.peek().type == type

    fn check_next(mut self, type: String) -> Bool:
        """Check if the next token (after current) matches the given type."""
        if self.current + 1 >= len(self.tokens):
            return False
        return self.tokens[self.current + 1].type == type

    fn check_next_next(mut self, type: String) -> Bool:
        """Check if the token after next matches the given type."""
        if self.current + 2 >= len(self.tokens):
            return False
        return self.tokens[self.current + 2].type == type

    fn advance(mut self) -> Token:
        if not self.is_at_end():
            self.current += 1
        return self.previous()

    fn is_at_end(self) -> Bool:
        return self.current >= len(self.tokens)

    fn peek(self) -> Token:
        return self.tokens[self.current].copy()

    fn peek_next_type(mut self) -> String:
        """Look at the type of the next token without advancing."""
        if self.current + 1 >= len(self.tokens):
            return ""
        return self.tokens[self.current + 1].type

    fn previous(self) -> Token:
        return self.tokens[self.current - 1].copy()

    fn consume(mut self, type: String, message: String) raises -> Token:
        if self.check(type):
            return self.advance()

        self.error(message)
        return Token("", "", 0, 0)

    fn error(self, message: String) raises:
        var token = self.peek()
        raise Error("Parse error at line " + String(token.line) + ", column " + String(token.column) + ": " + message)

    fn linq_query_statement(mut self) raises -> ASTNode:
        """Parse LINQ-style query expression (SQL-first syntax)."""
        var node = ASTNode(AST_LINQ_QUERY, "", self.peek().line, self.peek().column)

        # Parse FROM collection
        _ = self.consume(FROM, "Expected FROM in LINQ query")
        
        # Parse collection expression
        var collection_expr = self.expression()
        var from_clause = ASTNode("FROM_CLAUSE", "", self.previous().line, self.previous().column)
        from_clause.add_child(collection_expr)
        node.add_child(from_clause)

        # Parse optional WHERE clause
        if self.match(WHERE):
            var where_expr = self.expression()
            var where_clause = ASTNode("WHERE_CLAUSE", "", self.previous().line, self.previous().column)
            where_clause.add_child(where_expr)
            node.add_child(where_clause)

        # Parse optional JOIN clauses
        while self.match(JOIN):
            var join_type = "INNER"  # Default
            if self.match(LEFT):
                join_type = "LEFT"
            elif self.match(RIGHT):
                join_type = "RIGHT"
            elif self.match(FULL):
                join_type = "FULL"
            elif self.match(INNER):
                join_type = "INNER"
            elif self.match(ANTI):
                join_type = "ANTI"

            _ = self.consume(JOIN, "Expected JOIN after join type")

            var join_variable = self.consume(IDENTIFIER, "Expected variable name in JOIN").value
            _ = self.consume(IN, "Expected IN after join variable")

            var join_collection = self.expression()
            _ = self.consume(ON, "Expected ON after join collection")

            var join_condition = self.expression()

            var join_clause = ASTNode("JOIN_CLAUSE", join_type, self.previous().line, self.previous().column)
            join_clause.set_attribute("variable", join_variable)
            join_clause.add_child(join_collection)
            join_clause.add_child(join_condition)
            node.add_child(join_clause)

        # Parse optional LET clauses for intermediate computations
        while self.match(LET):
            var let_variable = self.consume(IDENTIFIER, "Expected variable name after LET").value
            _ = self.consume(EQUALS, "Expected = after LET variable")
            var let_expr = self.expression()

            var let_clause = ASTNode("LET_CLAUSE", let_variable, self.previous().line, self.previous().column)
            let_clause.add_child(let_expr)
            node.add_child(let_clause)

        # Parse optional ORDER BY clause
        if self.match(ORDER):
            _ = self.consume(BY, "Expected BY after ORDER")
            var order_expr = self.expression()
            var order_clause = ASTNode("ORDER_CLAUSE", "", self.previous().line, self.previous().column)
            order_clause.add_child(order_expr)
            node.add_child(order_clause)

        # Parse optional GROUP BY clause
        if self.match(GROUP):
            _ = self.consume(BY, "Expected BY after GROUP")
            var group_expr = self.expression()
            var group_clause = ASTNode("GROUP_CLAUSE", "", self.previous().line, self.previous().column)
            group_clause.add_child(group_expr)
            node.add_child(group_clause)

        # Parse SELECT clause (required for LINQ)
        _ = self.consume(SELECT, "Expected SELECT clause in LINQ query")
        var select_expr = self.expression()
        var select_clause = ASTNode("SELECT_CLAUSE", "", self.previous().line, self.previous().column)
        select_clause.add_child(select_expr)
        node.add_child(select_clause)

        return node^

    fn is_keyword(self, text: String) -> Bool:
        # Quick check for common keywords
        return text in [String("select"), String("from"), String("where"), String("create"), String("drop"), String("insert"), String("update"), String("delete"), String("let"), String("function"), String("index"), String("view"), String("table"), String("as"), String("and"), String("or"), String("not"), String("true"), String("false"), String("null"), String("distinct"), String("group"), String("order"), String("by"), String("sum"), String("count"), String("avg"), String("min"), String("max"), String("join"), String("on"), String("into"), String("values"), String("set")]
