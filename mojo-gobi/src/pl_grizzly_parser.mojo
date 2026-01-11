"""
PL-GRIZZLY Parser Implementation

Optimized recursive descent parser with memoization and efficient AST representation.
"""

from collections import List, Dict
from pl_grizzly_lexer import Token, PLGrizzlyLexer, SELECT, FROM, WHERE, CREATE, DROP, INDEX, MATERIALIZED, VIEW, REFRESH, IMPORT, UPDATE, DELETE, LOGIN, LOGOUT, BEGIN, COMMIT, ROLLBACK, MACRO, JOIN, ON, ATTACH, DETACH, ALL, LIST, ATTACHED, AS, CACHE, CLEAR, DISTINCT, GROUP, ORDER, BY, SUM, COUNT, AVG, MIN, MAX, FUNCTION, TYPE, STRUCT, EXCEPTION, MODULE, DOUBLE_COLON, RETURNS, THROWS, IF, ELSE, MATCH, FOR, WHILE, CASE, IN, TRY, CATCH, LET, TRUE, FALSE, EQUALS, NOT_EQUALS, GREATER, LESS, GREATER_EQUAL, LESS_EQUAL, AND, OR, NOT, BANG, COALESCE, PLUS, MINUS, MULTIPLY, DIVIDE, MODULO, PIPE, ARROW, DOT, LPAREN, RPAREN, LBRACE, RBRACE, LBRACKET, RBRACKET, COMMA, SEMICOLON, COLON, IDENTIFIER, STRING, NUMBER, VARIABLE, EOF, UNKNOWN, INSERT, INTO, VALUES, SET

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
alias AST_LIST = "LIST"
alias AST_DICT = "DICT"

# Efficient AST Node using Dict for flexible representation
struct ASTNode(Copyable, Movable):
    var node_type: String
    var value: String
    var children: List[ASTNode]
    var attributes: Dict[String, String]

    fn __init__(out self, node_type: String, value: String = ""):
        self.node_type = node_type
        self.value = value
        self.children = List[ASTNode]()
        self.attributes = Dict[String, String]()

    fn add_child(mut self, child: ASTNode) raises:
        self.children.append(child.copy())

    fn set_attribute(mut self, key: String, value: String):
        self.attributes[key] = value

    fn get_attribute(self, key: String) -> String:
        return self.attributes.get(key, "")

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

    fn __init__(out self, tokens: List[Token]):
        self.tokens = tokens.copy()
        self.current = 0
        self.cache = ParserCache()
        self.symbol_table = SymbolTable()

    fn parse(mut self) raises -> ASTNode:
        """Parse tokens into optimized AST."""
        if len(self.tokens) == 0:
            return ASTNode(AST_LITERAL, "empty")^

        # Try to parse as statement
        return self.statement()

    fn statement(mut self) raises -> ASTNode:
        """Parse a statement."""
        var result: ASTNode
        if self.match(SELECT):
            result = self.select_statement()
        elif self.match(CREATE):
            result = self.create_statement()
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
        else:
            result = self.expression_statement()

        return result^

    fn select_statement(mut self) raises -> ASTNode:
        """Parse SELECT statement with optimizations."""
        var node = ASTNode(AST_SELECT)

        # Parse SELECT clause
        var select_list = self.parse_select_list()
        node.add_child(select_list)

        # Parse FROM clause
        if self.match(FROM):
            var from_clause = self.parse_from_clause()
            node.add_child(from_clause)

        # Parse WHERE clause
        if self.match(WHERE):
            var where_clause = self.parse_where_clause()
            node.add_child(where_clause)

        # Parse GROUP BY clause
        if self.match(GROUP):
            self.consume(BY, "Expected 'BY' after GROUP")
            var group_clause = self.parse_group_by_clause()
            node.add_child(group_clause)

        # Parse ORDER BY clause
        if self.match(ORDER):
            self.consume(BY, "Expected 'BY' after ORDER")
            var order_clause = self.parse_order_by_clause()
            node.add_child(order_clause)

        return node^

    fn parse_select_list(mut self) raises -> ASTNode:
        """Parse select list with aggregate function detection."""
        var node = ASTNode("SELECT_LIST")
        var has_aggregates = False

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
        """Parse select item, detecting aggregate functions."""
        var node = ASTNode("SELECT_ITEM")

        # Check for aggregate functions
        if self.check(SUM) or self.check(COUNT) or self.check(AVG) or self.check(MIN) or self.check(MAX):
            var func_name = self.advance().value
            self.consume(LPAREN, "Expected '(' after aggregate function")
            var expr = self.expression()
            self.consume(RPAREN, "Expected ')' after aggregate function argument")

            var func_node = ASTNode("AGGREGATE_FUNCTION", func_name)
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
        """Parse FROM clause."""
        var node = ASTNode(AST_FROM)
        var table_name = self.consume(IDENTIFIER, "Expected table name after FROM").value
        node.set_attribute("table", table_name)

        # Check for alias
        if self.match(AS):
            var alias_token = self.consume(IDENTIFIER, "Expected alias after AS")
            node.set_attribute("alias", alias_token.value)
        elif self.check(IDENTIFIER):
            var alias_token = self.advance()
            node.set_attribute("alias", alias_token.value)

        return node^

    fn parse_where_clause(mut self) raises -> ASTNode:
        """Parse WHERE clause."""
        var node = ASTNode(AST_WHERE)
        var condition = self.expression()
        node.add_child(condition)
        return node^

    fn parse_group_by_clause(mut self) raises -> ASTNode:
        """Parse GROUP BY clause."""
        var node = ASTNode("GROUP_BY")

        while True:
            var col = self.expression()
            node.add_child(col)
            if not self.match(COMMA):
                break

        return node^

    fn parse_order_by_clause(mut self) raises -> ASTNode:
        """Parse ORDER BY clause."""
        var node = ASTNode("ORDER_BY")

        while True:
            var col = self.expression()
            var direction = "ASC"

            if self.match("ASC") or self.match("DESC"):
                direction = self.previous().value

            col.set_attribute("direction", direction)
            node.add_child(col)

            if not self.match(COMMA):
                break

        return node^

    fn expression(mut self) raises -> ASTNode:
        """Parse expression with precedence climbing."""
        return self.parse_expression(0)^

    fn parse_expression(mut self, precedence: Int) raises -> ASTNode:
        """Parse expression with operator precedence."""
        var left = self.primary()

        while not self.is_at_end():
            var op_precedence = self.get_operator_precedence()
            if op_precedence < precedence:
                break

            var operator = self.advance().value
            var right = self.parse_expression(op_precedence + 1)

            var binary_node = ASTNode(AST_BINARY_OP, operator)
            binary_node.add_child(left)
            binary_node.add_child(right)
            left = binary_node^

        return left^

    fn primary(mut self) raises -> ASTNode:
        """Parse primary expressions."""
        if self.match(LPAREN):
            var expr = self.expression()
            self.consume(RPAREN, "Expected ')' after expression")
            return expr^
        elif self.match(NUMBER):
            return ASTNode(AST_LITERAL, self.previous().value)^
        elif self.match(STRING):
            return ASTNode(AST_LITERAL, self.previous().value)^
        elif self.match(TRUE) or self.match(FALSE):
            return ASTNode(AST_LITERAL, self.previous().value)^
        elif self.match(IDENTIFIER):
            var name = self.previous().value
            var var_type = self.symbol_table.lookup(name)
            var node = ASTNode(AST_IDENTIFIER, name)
            node.set_attribute("type", var_type)
            return node^
        elif self.match(VARIABLE):
            var name = self.previous().value
            var node = ASTNode("VARIABLE", name)
            return node^

        # Error case
        self.advance()  # Skip unknown token
        return ASTNode("ERROR", "Unexpected token")^

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
        return 0

    fn create_statement(mut self) raises -> ASTNode:
        """Parse CREATE statement."""
        var node = ASTNode(AST_CREATE)

        if self.match(FUNCTION):
            return self.function_statement()
        elif self.match(INDEX):
            return self.index_statement()
        elif self.match(VIEW):
            return self.view_statement()
        else:
            self.error("Expected FUNCTION, INDEX, or VIEW after CREATE")
            return node^

    fn function_statement(mut self) raises -> ASTNode:
        """Parse function definition."""
        var node = ASTNode(AST_FUNCTION)

        var func_name = self.consume(IDENTIFIER, "Expected function name").value
        node.set_attribute("name", func_name)

        self.consume(LPAREN, "Expected '(' after function name")

        # Parse parameters
        if not self.check(RPAREN):
            while True:
                var param_name = self.consume(IDENTIFIER, "Expected parameter name").value
                var param_node = ASTNode("PARAMETER", param_name)
                node.add_child(param_node)
                if not self.match(COMMA):
                    break

        self.consume(RPAREN, "Expected ')' after parameters")
        self.consume(RETURNS, "Expected RETURNS")
        var return_type = self.consume(IDENTIFIER, "Expected return type").value
        node.set_attribute("return_type", return_type)

        self.consume(LBRACE, "Expected '{' before function body")
        var body = self.expression()
        self.consume(RBRACE, "Expected '}' after function body")

        node.add_child(body)

        return node^

    fn index_statement(mut self) raises -> ASTNode:
        """Parse CREATE INDEX statement."""
        var node = ASTNode(AST_INDEX)

        var index_name = self.consume(IDENTIFIER, "Expected index name").value
        node.set_attribute("name", index_name)

        self.consume(ON, "Expected ON")
        var table_name = self.consume(IDENTIFIER, "Expected table name").value
        node.set_attribute("table", table_name)

        self.consume(LPAREN, "Expected '('")
        var columns = List[String]()

        while True:
            var col = self.consume(IDENTIFIER, "Expected column name").value
            columns.append(col)
            if not self.match(COMMA):
                break

        self.consume(RPAREN, "Expected ')'")

        for col in columns:
            var col_node = ASTNode("COLUMN", col)
            node.add_child(col_node)

        return node^

    fn view_statement(mut self) raises -> ASTNode:
        """Parse CREATE VIEW statement."""
        var node = ASTNode("CREATE_VIEW")

        var view_name = self.consume(IDENTIFIER, "Expected view name").value
        node.set_attribute("name", view_name)

        self.consume(AS, "Expected AS")
        var select_stmt = self.select_statement()
        node.add_child(select_stmt)

        return node^

    fn drop_statement(mut self) raises -> ASTNode:
        """Parse DROP statement."""
        var node = ASTNode(AST_DROP)

        if self.match(INDEX):
            var index_name = self.consume(IDENTIFIER, "Expected index name").value
            node.set_attribute("type", "INDEX")
            node.set_attribute("name", index_name)
        elif self.match(VIEW):
            var view_name = self.consume(IDENTIFIER, "Expected view name").value
            node.set_attribute("type", "VIEW")
            node.set_attribute("name", view_name)
        else:
            self.error("Expected INDEX or VIEW after DROP")

        return node^

    fn insert_statement(mut self) raises -> ASTNode:
        """Parse INSERT statement."""
        var node = ASTNode("INSERT")

        self.consume(INTO, "Expected INTO")
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
            self.consume(RPAREN, "Expected ')'")

            for col in columns:
                var col_node = ASTNode("COLUMN", col)
                node.add_child(col_node)

        self.consume(VALUES, "Expected VALUES")
        self.consume(LPAREN, "Expected '('")

        while True:
            var val = self.expression()
            node.add_child(val)
            if not self.match(COMMA):
                break

        self.consume(RPAREN, "Expected ')'")

        return node^

    fn update_statement(mut self) raises -> ASTNode:
        """Parse UPDATE statement."""
        var node = ASTNode(UPDATE)

        var table_name = self.consume(IDENTIFIER, "Expected table name").value
        node.set_attribute("table", table_name)

        self.consume(SET, "Expected SET")

        while True:
            var col = self.consume(IDENTIFIER, "Expected column name").value
            self.consume(EQUALS, "Expected '='")
            var val = self.expression()

            var assign_node = ASTNode("ASSIGNMENT")
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
        var node = ASTNode(DELETE)

        self.consume(FROM, "Expected FROM")
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

        self.consume(EQUALS, "Expected '='")
        var value = self.expression()
        node.add_child(value)

        # Add to symbol table
        self.symbol_table.define(var_name, "variable")

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

    fn advance(mut self) -> Token:
        if not self.is_at_end():
            self.current += 1
        return self.previous()

    fn is_at_end(self) -> Bool:
        return self.current >= len(self.tokens)

    fn peek(self) -> Token:
        return self.tokens[self.current].copy()

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

    fn is_keyword(self, text: String) -> Bool:
        # Quick check for common keywords
        return text in [String("select"), String("from"), String("where"), String("create"), String("drop"), String("insert"), String("update"), String("delete"), String("let"), String("function"), String("index"), String("view"), String("table"), String("as"), String("and"), String("or"), String("not"), String("true"), String("false"), String("null"), String("distinct"), String("group"), String("order"), String("by"), String("sum"), String("count"), String("avg"), String("min"), String("max"), String("join"), String("on"), String("into"), String("values"), String("set")]
