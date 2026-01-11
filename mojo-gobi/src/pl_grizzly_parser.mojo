from collections import List
from pl_grizzly_lexer import Token, PLGrizzlyLexer

from collections import List
from pl_grizzly_lexer import Token, PLGrizzlyLexer

# AST Node Definition (simplified as string representation)
alias Expr = String

# Statement parsing
struct SelectStmt:
    var from_clause: String
    var select_list: List[String]
    var where_clause: String

struct FunctionStmt:
    var name: String
    var parameters: List[String]
    var body: String

# For now, use string-based statements
alias Stmt = String

# PL-GRIZZLY Parser
struct PLGrizzlyParser:
    var tokens: List[Token]
    var current: Int

    fn __init__(out self, tokens: List[Token]):
        self.tokens = tokens.copy()
        self.current = 0

    fn parse(mut self) raises -> String:
        """Parse the tokens into a statement or expression."""
        if self.match("SELECT"):
            return self.select_statement()
        elif self.match("CREATE"):
            if self.match("FUNCTION"):
                return self.function_statement()
            else:
                return "(error: expected FUNCTION after CREATE)"
        elif self.match("TRY"):
            return self.try_statement()
        elif self.match("TYPE"):
            return self.type_statement()
        elif self.match("INSERT"):
            return self.insert_statement()
        elif self.match("UPDATE"):
            return self.update_statement()
        elif self.match("DELETE"):
            return self.delete_statement()
        elif self.match("IMPORT"):
            return self.import_statement()
        elif self.match("MATCH"):
            return self.match_statement()
        elif self.match("FOR"):
            return self.for_statement()
        elif self.match("WHILE"):
            return self.while_statement()
        else:
            return self.expression()

    fn statement(mut self) -> Stmt:
        """Parse a statement."""
        if self.match("SELECT"):
            return self.select_statement()
        elif self.match("CREATE"):
            if self.match("FUNCTION"):
                return self.function_statement()
        # Default to expression statement or error
        return None  # For now

    fn select_statement(mut self) -> String:
        """Parse a SELECT statement."""
        var select_list = List[String]()
        if self.match("*"):
            select_list.append("*")
        else:
            return "(error: expected * or column list)"
        
        if not self.match("FROM"):
            return "(error: expected FROM)"
        
        var from_clause = self.expression()
        var where_clause = ""
        if self.match("WHERE"):
            where_clause = self.expression()
        
        var result = "(SELECT from: " + from_clause
        if where_clause != "":
            result += " where: " + where_clause
        result += ")"
        return result

    fn function_statement(mut self) -> String:
        """Parse a FUNCTION statement with optional receiver."""
        var name = ""
        if self.match("IDENTIFIER"):
            name = self.previous().value
        else:
            return "(error: expected function name)"
        
        var receiver = ""
        if self.match("["):
            # Parse receiver: var : type ]
            var receiver_var = ""
            if self.match("IDENTIFIER"):
                receiver_var = self.previous().value
            else:
                return "(error: expected receiver variable)"
            if not self.match(":"):
                return "(error: expected : after receiver var)"
            var receiver_type = ""
            if self.match("IDENTIFIER"):
                receiver_type = self.previous().value
            else:
                return "(error: expected receiver type)"
            if not self.match("]"):
                return "(error: expected ] after receiver)"
            receiver = receiver_var + ":" + receiver_type
        
        if not self.match("("):
            return "(error: expected ( after function name)"
        
        var parameters = List[String]()
        if not self.check(")"):
            if self.match("IDENTIFIER"):
                parameters.append(self.previous().value)
            while self.match(","):
                if self.match("IDENTIFIER"):
                    parameters.append(self.previous().value)
                else:
                    return "(error: expected parameter name)"
        
        if not self.match(")"):
            return "(error: expected ) after parameters)"
        
        if not self.match("{"):
            return "(error: expected { after parameters)"
        
        var body = self.expression()
        
        if not self.match("}"):
            return "(error: expected } after body)"
        
        var params_str = ""
        for i in range(len(parameters)):
            if i > 0:
                params_str += ", "
            params_str += parameters[i]
        
        var result = "(FUNCTION " + name
        if receiver != "":
            result += " [" + receiver + "]"
        result += "(" + params_str + ") { " + body + " })"
        return result

    fn try_statement(mut self) -> String:
        """Parse a TRY CATCH statement."""
        self.consume("LBRACE", "Expect { after TRY")
        var try_body = self.expression()
        self.consume("RBRACE", "Expect } after try body")
        
        self.consume("CATCH", "Expect CATCH after try block")
        self.consume("LBRACE", "Expect { after CATCH")
        var catch_body = self.expression()
        self.consume("RBRACE", "Expect } after catch body")
        
        return "(TRY " + try_body + " CATCH " + catch_body + ")"

    fn insert_statement(mut self) -> String:
        """Parse an INSERT statement."""
        self.consume("INTO", "Expect INTO after INSERT")
        if not self.match("IDENTIFIER"):
            return "error: expect table name"
        var table_name = self.previous().value
        if not self.match("VALUES"):
            return "error: expect VALUES"
        if not self.match("LPAREN"):
            return "error: expect ( after VALUES"
        var values = List[Expr]()
        if not self.check("RPAREN"):
            values.append(self.expression())
            while self.match(","):
                values.append(self.expression())
        if not self.match("RPAREN"):
            return "error: expect ) after values"
        var values_str = ""
        for i in range(len(values)):
            if i > 0:
                values_str += ", "
            values_str += values[i]
        return "(INSERT INTO " + table_name + " VALUES (" + values_str + "))"

    fn update_statement(mut self) -> String:
        """Parse an UPDATE statement."""
        var table_name = self.consume("IDENTIFIER", "Expect table name").value
        if not self.match("SET"):
            return "error: expect SET"
        var col = self.consume("IDENTIFIER", "Expect column name").value
        if not self.match("="):
            return "error: expect ="
        var val = self.expression()
        return "(UPDATE " + table_name + " SET " + col + " = " + val + ")"

    fn delete_statement(mut self) -> String:
        """Parse a DELETE statement."""
        if not self.match("FROM"):
            return "error: expect FROM"
        var table_name = self.consume("IDENTIFIER", "Expect table name").value
        return "(DELETE FROM " + table_name + ")"

    fn import_statement(mut self) -> String:
        """Parse an IMPORT statement."""
        var module_name = self.consume("IDENTIFIER", "Expect module name").value
        return "(IMPORT " + module_name + ")"

    fn type_statement(mut self) -> String:
        """Parse a TYPE statement."""
        if self.match("STRUCT"):
            if self.match("AS"):
                var name = self.consume("IDENTIFIER", "Expect type name").value
                if self.match("("):
                    var fields = List[String]()
                    while not self.check(")"):
                        var field_name = self.consume("IDENTIFIER", "Expect field name").value
                        self.consume(":", "Expect : after field name")
                        var field_type = self.consume("IDENTIFIER", "Expect field type").value
                        fields.append(field_name + ": " + field_type)
                        if not self.match(","):
                            break
                    self.consume(")", "Expect ) after fields")
                    var fields_str = ", ".join(fields)
                    return "(TYPE STRUCT AS " + name + " (" + fields_str + "))"
                else:
                    return "(error: expected ( after AS)"
            else:
                return "(error: expected AS after STRUCT)"
        else:
            return "(error: expected STRUCT after TYPE)"

    fn expression(mut self) -> Expr:
        """Parse an expression."""
        return self.coalesce()

    fn coalesce(mut self) -> Expr:
        var expr = self.pipe()
        while self.match("??"):
            var operator = self.previous().value
            var right = self.pipe()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn pipe(mut self) -> Expr:
        var expr = self.equality()
        while self.match("|>"):
            var operator = self.previous().value
            var right = self.equality()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn equality(mut self) -> Expr:
        var expr = self.logical()
        while self.match("!=") or self.match("="):
            var operator = self.previous().value
            var right = self.logical()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn logical(mut self) -> Expr:
        var expr = self.comparison()
        while self.match("and") or self.match("or"):
            var operator = self.previous().value
            var right = self.comparison()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn comparison(mut self) -> Expr:
        var expr = self.term()
        while self.match(">") or self.match("<") or self.match(">=") or self.match("<="):
            var operator = self.previous().value
            var right = self.term()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn term(mut self) -> Expr:
        var expr = self.factor()
        while self.match("-") or self.match("+"):
            var operator = self.previous().value
            var right = self.factor()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn factor(mut self) -> Expr:
        var expr = self.cast()
        while self.match("/") or self.match("*"):
            var operator = self.previous().value
            var right = self.cast()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn unary_op(mut self) -> Expr:
        if self.match("not") or self.match("!") or self.match("-"):
            var operator = self.previous().value
            var right = self.unary_op()
            return "(" + operator + " " + right + ")"
        return self.call()

    fn cast(mut self) -> Expr:
        var expr = self.unary_op()
        if self.match("as") or self.match("::"):
            var operator = self.previous().value
            var type_expr = self.unary_op()  # For now, allow expressions as types
            return "(" + expr + " " + operator + " " + type_expr + ")"
        return expr

    fn call(mut self) -> Expr:
        var expr = self.primary()
        while True:
            if self.match("("):
                expr = self.finish_call(expr)
            else:
                break
        return expr

    fn finish_call(mut self, callee: Expr) -> Expr:
        var arguments = List[Expr]()
        if not self.check(")"):
            arguments.append(self.expression())
            while self.match(","):
                arguments.append(self.expression())
        self.consume(")", "Expect ')' after arguments.")
        var args_str = ""
        for i in range(len(arguments)):
            if i > 0:
                args_str += " "
            args_str += arguments[i]
        return "(call " + callee + " " + args_str + ")"

    fn match_statement(mut self) -> String:
        """Parse a MATCH statement."""
        var expr = self.expression()
        if not self.match("LBRACE"):
            return "(error: expected { after MATCH expr)"
        var cases = List[String]()
        while not self.check("RBRACE") and not self.is_at_end():
            if self.match("CASE"):
                var pattern = self.expression()
                if not self.match("ARROW"):
                    return "(error: expected => after case pattern)"
                var body = self.expression()
                cases.append("case " + pattern + " => " + body)
            else:
                return "(error: expected CASE in match)"
            if not self.match(","):
                break
        if not self.match("RBRACE"):
            return "(error: expected } after match cases)"
        return "(MATCH " + expr + " {" + " ".join(cases) + " })"

    fn for_statement(mut self) -> String:
        """Parse a FOR statement."""
        if not self.match("IDENTIFIER"):
            return "(error: expected variable after FOR)"
        var var_name = self.previous().value
        if not self.match("IN"):
            return "(error: expected IN after variable)"
        var collection = self.expression()
        if not self.match("LBRACE"):
            return "(error: expected { after collection)"
        var body = self.expression()
        if not self.match("RBRACE"):
            return "(error: expected } after body)"
        return "(FOR " + var_name + " IN " + collection + " { " + body + " })"

    fn while_statement(mut self) -> String:
        """Parse a WHILE statement."""
        var condition = self.expression()
        if not self.match("LBRACE"):
            return "(error: expected { after condition)"
        var body = self.expression()
        if not self.match("RBRACE"):
            return "(error: expected } after body)"
        return "(WHILE " + condition + " { " + body + " })"

    fn parse_struct(mut self) -> Expr:
        var fields = List[Expr]()
        if not self.check("RBRACE"):
            var key = self.expression()
            self.consume(":", "Expect ':' after field name.")
            var value = self.expression()
            fields.append(key + ": " + value)
            while self.match(","):
                key = self.expression()
                self.consume(":", "Expect ':' after field name.")
                value = self.expression()
                fields.append(key + ": " + value)
        self.consume("RBRACE", "Expect '}' after struct fields.")
        var struct_str = "{"
        for i in range(len(fields)):
            if i > 0:
                struct_str += ", "
            struct_str += fields[i]
        struct_str += "}"
        return struct_str

    fn parse_list(mut self) -> Expr:
        var elements = List[Expr]()
        if not self.check("RBRACKET"):
            elements.append(self.expression())
            while self.match(","):
                elements.append(self.expression())
        self.consume("RBRACKET", "Expect ] after list elements.")
        var list_str = "["
        for i in range(len(elements)):
            if i > 0:
                list_str += ", "
            list_str += elements[i]
        list_str += "]"
        return list_str

    fn primary(mut self) -> Expr:
        if self.match("NUMBER"):
            return self.previous().value
        elif self.match("STRING"):
            return self.previous().value
        elif self.match("TRUE"):
            return "true"
        elif self.match("FALSE"):
            return "false"
        elif self.match("IDENTIFIER"):
            var id = self.previous().value
            if self.match("DOT"):
                # Method call: obj.method(args)
                if not self.match("IDENTIFIER"):
                    return "error: expect method name after ."
                var method = self.previous().value
                if not self.match("LPAREN"):
                    return "error: expect ( after method name"
                var args = List[Expr]()
                if not self.check("RPAREN"):
                    args.append(self.expression())
                    while self.match(","):
                        args.append(self.expression())
                if not self.match("RPAREN"):
                    return "error: expect ) after arguments"
                var call_str = "(call " + method + " " + id
                for arg in args:
                    call_str += " " + arg
                call_str += ")"
                return call_str
            else:
                return id
        elif self.match("VARIABLE"):
            return "{ " + self.previous().value + " }"
        elif self.match("LBRACE"):
            return self.parse_struct()
        elif self.match("LBRACKET"):
            return self.parse_list()
        elif self.match("EXCEPTION"):
            var message = self.expression()
            return "EXCEPTION " + message
        elif self.match("("):
            var expr = self.expression()
            self.consume(")", "Expect ')' after expression.")
            return expr
        else:
            return "error"

    # Helper methods
    fn match(mut self, type: String) -> Bool:
        if self.check(type):
            self.advance()
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

    fn consume(mut self, type: String, message: String) -> Token:
        if self.check(type):
            return self.advance()
        # Error handling - for now, return a dummy token
        return Token("", "", 0, 0)