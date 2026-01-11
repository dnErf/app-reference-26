"""
PL-GRIZZLY Lexer Implementation

This module provides lexical analysis for the PL-GRIZZLY programming language,
an enhanced SQL dialect with functional programming features.
"""

from collections import List

# Token types for PL-GRIZZLY (using string constants)
alias SELECT = "SELECT"
alias FROM = "FROM"
alias WHERE = "WHERE"
alias CREATE = "CREATE"
alias FUNCTION = "FUNCTION"
alias TYPE = "TYPE"
alias STRUCT = "STRUCT"
alias EXCEPTION = "EXCEPTION"
alias AS = "AS"
alias RETURNS = "RETURNS"
alias THROWS = "THROWS"
alias IF = "IF"
alias ELSE = "ELSE"
alias MATCH = "MATCH"
alias TRY = "TRY"
alias CATCH = "CATCH"
alias LET = "LET"
alias TRUE = "TRUE"
alias FALSE = "FALSE"

# Operators
alias EQUALS = "="
alias NOT_EQUALS = "!="
alias GREATER = ">"
alias LESS = "<"
alias GREATER_EQUAL = ">="
alias LESS_EQUAL = "<="
alias AND = "and"
alias OR = "or"
alias PLUS = "+"
alias MINUS = "-"
alias MULTIPLY = "*"
alias DIVIDE = "/"
alias MODULO = "%"
alias PIPE = "|>"
alias ARROW = "=>"
alias DOT = "."

# Delimiters
alias LPAREN = "("
alias RPAREN = ")"
alias LBRACE = "{"
alias RBRACE = "}"
alias LBRACKET = "["
alias RBRACKET = "]"
alias COMMA = ","
alias SEMICOLON = ";"
alias COLON = ":"

# Literals and identifiers
alias IDENTIFIER = "IDENTIFIER"
alias STRING = "STRING"
alias NUMBER = "NUMBER"
alias VARIABLE = "VARIABLE"  # For {variable} syntax

# Special
alias EOF = "EOF"
alias UNKNOWN = "UNKNOWN"

# Token structure
struct Token(Copyable, Movable):
    var type: String
    var value: String
    var line: Int
    var column: Int

    fn __init__(out self, type: String, value: String, line: Int, column: Int):
        self.type = type
        self.value = value
        self.line = line
        self.column = column

# PL-GRIZZLY Lexer
struct PLGrizzlyLexer:
    var source: String
    var tokens: List[Token]
    var start: Int
    var current: Int
    var line: Int
    var column: Int

    fn __init__(out self, source: String):
        self.source = source
        self.tokens = List[Token]()
        self.start = 0
        self.current = 0
        self.line = 1
        self.column = 1

    fn tokenize(mut self) raises -> List[Token]:
        """Tokenize the source code into a list of tokens."""
        while not self.is_at_end():
            self.start = self.current
            self.scan_token()

        self.tokens.append(Token(type=EOF, value="", line=self.line, column=self.column))
        return self.tokens.copy()

    fn is_at_end(self) -> Bool:
        return self.current >= len(self.source)

    fn scan_token(mut self):
        """Scan the next token."""
        var c = self.advance()
        if c == "(":
            self.add_token(LPAREN)
        elif c == ")":
            self.add_token(RPAREN)
        elif c == "{":
            # Check if this is a variable {name} or just a brace
            if self.is_alpha(self.peek()):
                self.variable()
            else:
                self.add_token(LBRACE)
        elif c == "}":
            self.add_token(RBRACE)
        elif c == "[":
            self.add_token(LBRACKET)
        elif c == "]":
            self.add_token(RBRACKET)
        elif c == ".":
            self.add_token(DOT)
        elif c == ",":
            self.add_token(COMMA)
        elif c == ";":
            self.add_token(SEMICOLON)
        elif c == ":":
            self.add_token(COLON)
        elif c == ".":
            self.add_token(DOT)
        elif c == "+":
            self.add_token(PLUS)
        elif c == "-":
            if self.match(">"):
                self.add_token(ARROW)
            else:
                self.add_token(MINUS)
        elif c == "*":
            self.add_token(MULTIPLY)
        elif c == "/":
            if self.match("/"):
                # Single line comment
                while self.peek() != "\n" and not self.is_at_end():
                    _ = self.advance()
            elif self.match("*"):
                # Multi-line comment
                while not (self.peek() == "*" and self.peek_next() == "/") and not self.is_at_end():
                    if self.peek() == "\n":
                        self.line += 1
                        self.column = 1
                    _ = self.advance()
                if not self.is_at_end():
                    _ = self.advance()  # consume *
                    _ = self.advance()  # consume /
            else:
                self.add_token(DIVIDE)
        elif c == "%":
            self.add_token(MODULO)
        elif c == "=":
            if self.match("="):
                self.add_token(EQUALS)
            elif self.match(">"):
                self.add_token(ARROW)
            else:
                self.add_token(EQUALS)
        elif c == "!":
            if self.match("="):
                self.add_token(NOT_EQUALS)
            else:
                self.add_token(UNKNOWN, "!")
        elif c == ">":
            if self.match("="):
                self.add_token(GREATER_EQUAL)
            else:
                self.add_token(GREATER)
        elif c == "<":
            if self.match("="):
                self.add_token(LESS_EQUAL)
            else:
                self.add_token(LESS)
        elif c == "|":
            if self.match(">"):
                self.add_token(PIPE)
            else:
                self.add_token(UNKNOWN, "|")
        elif c == "\"":
            self.string()
        elif self.is_digit(c):
            self.number()
        elif self.is_alpha(c):
            self.identifier()
        elif c == "{":
            self.variable()
        elif c == " " or c == "\r" or c == "\t":
            # Skip whitespace
            pass
        elif c == "\n":
            self.line += 1
            self.column = 1
        else:
            self.add_token(UNKNOWN, String(c))

    fn advance(mut self) -> String:
        """Advance to the next character."""
        self.current += 1
        self.column += 1
        return String(self.source[self.current - 1])

    fn match(mut self, expected: String) -> Bool:
        """Check if the next character matches expected."""
        if self.is_at_end():
            return False
        if String(self.source[self.current]) != expected:
            return False
        self.current += 1
        self.column += 1
        return True

    fn peek(self) -> String:
        """Look at the current character without advancing."""
        if self.is_at_end():
            return "\0"
        return String(self.source[self.current])

    fn peek_next(self) -> String:
        """Look at the next character without advancing."""
        if self.current + 1 >= len(self.source):
            return "\0"
        return String(self.source[self.current + 1])

    fn add_token(mut self, type: String, literal: String = ""):
        """Add a token to the list."""
        var text = String(self.source[self.start:self.current])
        var token_value = literal
        if token_value == "":
            token_value = text
        self.tokens.append(Token(type=type, value=token_value, line=self.line, column=self.column - (self.current - self.start)))

    fn is_digit(self, c: String) -> Bool:
        return c >= "0" and c <= "9"

    fn is_alpha(self, c: String) -> Bool:
        return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"

    fn is_alphanumeric(self, c: String) -> Bool:
        return self.is_alpha(c) or self.is_digit(c)

    fn string(mut self):
        """Parse a string literal."""
        while self.peek() != "\"" and not self.is_at_end():
            if self.peek() == "\n":
                self.line += 1
                self.column = 1
            _ = self.advance()

        if self.is_at_end():
            self.add_token(UNKNOWN, "Unterminated string")
            return

        _ = self.advance()  # consume the closing "
        var value = String(self.source[self.start + 1:self.current - 1])
        self.add_token(STRING, value)

    fn number(mut self):
        """Parse a number literal."""
        while self.is_digit(self.peek()):
            _ = self.advance()

        if self.peek() == "." and self.is_digit(self.peek_next()):
            _ = self.advance()  # consume the "."
            while self.is_digit(self.peek()):
                _ = self.advance()

        self.add_token(NUMBER)

    fn identifier(mut self):
        """Parse an identifier or keyword."""
        while self.is_alphanumeric(self.peek()):
            _ = self.advance()

        var text = String(self.source[self.start:self.current])
        var type = self.get_keyword_type(text)
        self.add_token(type)

    fn variable(mut self):
        """Parse a variable reference like {variable}."""
        while self.peek() != "}" and not self.is_at_end():
            _ = self.advance()

        if self.is_at_end():
            self.add_token(UNKNOWN, "Unterminated variable")
            return

        _ = self.advance()  # consume the closing }
        var value = String(self.source[self.start + 1:self.current - 1])
        self.add_token(VARIABLE, value)

    fn get_keyword_type(self, text: String) -> String:
        """Get the token type for keywords."""
        if text == "select" or text == "SELECT":
            return SELECT
        elif text == "from" or text == "FROM":
            return FROM
        elif text == "where" or text == "WHERE":
            return WHERE
        elif text == "create" or text == "CREATE":
            return CREATE
        elif text == "function" or text == "FUNCTION":
            return FUNCTION
        elif text == "type" or text == "TYPE":
            return TYPE
        elif text == "struct" or text == "STRUCT":
            return STRUCT
        elif text == "exception" or text == "EXCEPTION":
            return EXCEPTION
        elif text == "as" or text == "AS":
            return AS
        elif text == "returns" or text == "RETURNS":
            return RETURNS
        elif text == "throws" or text == "THROWS":
            return THROWS
        elif text == "if" or text == "IF":
            return IF
        elif text == "else" or text == "ELSE":
            return ELSE
        elif text == "match" or text == "MATCH":
            return MATCH
        elif text == "try" or text == "TRY":
            return TRY
        elif text == "catch" or text == "CATCH":
            return CATCH
        elif text == "let" or text == "LET":
            return LET
        elif text == "true" or text == "TRUE":
            return TRUE
        elif text == "false" or text == "FALSE":
            return FALSE
        elif text == "and" or text == "AND":
            return AND
        elif text == "or" or text == "OR":
            return OR
        else:
            return IDENTIFIER