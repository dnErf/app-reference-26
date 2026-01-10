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
        """Parse a CREATE FUNCTION statement."""
        var name = ""
        if self.match("IDENTIFIER"):
            name = self.previous().value
        else:
            return "(error: expected function name)"
        
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
        
        if not self.match("=>"):
            return "(error: expected => after parameters)"
        
        var body = self.expression()
        
        var params_str = ""
        for i in range(len(parameters)):
            if i > 0:
                params_str += ", "
            params_str += parameters[i]
        
        return "(FUNCTION " + name + "(" + params_str + ") => " + body + ")"

    fn expression(mut self) -> Expr:
        """Parse an expression."""
        return self.pipe()

    fn pipe(mut self) -> Expr:
        var expr = self.equality()
        while self.match("|>"):
            var operator = self.previous().value
            var right = self.equality()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn equality(mut self) -> Expr:
        var expr = self.comparison()
        while self.match("!=") or self.match("="):
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
        var expr = self.unary()
        while self.match("/") or self.match("*"):
            var operator = self.previous().value
            var right = self.unary()
            expr = "(" + operator + " " + expr + " " + right + ")"
        return expr

    fn unary(mut self) -> Expr:
        if self.match("!") or self.match("-"):
            var operator = self.previous().value
            var right = self.unary()
            return "(" + operator + " " + right + ")"
        return self.call()

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
            return self.previous().value
        elif self.match("VARIABLE"):
            return "{ " + self.previous().value + " }"
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

    fn consume(mut self, type: String, message: String):
        if self.check(type):
            _ = self.advance()
            return
        # Error handling
        pass