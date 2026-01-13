"""
PL-GRIZZLY Lexer Implementation

This module provides lexical analysis for the PL-GRIZZLY programming language,
an enhanced SQL dialect with functional programming features.
"""

from collections import List, Dict

# Optimized keyword dictionary for O(1) lookup
fn get_keywords() -> Dict[String, String]:
    """Get the keyword dictionary for fast lookup."""
    var keywords = Dict[String, String]()
    keywords["select"] = SELECT
    keywords["SELECT"] = SELECT
    keywords["from"] = FROM
    keywords["FROM"] = FROM
    keywords["where"] = WHERE
    keywords["WHERE"] = WHERE
    keywords["create"] = CREATE
    keywords["CREATE"] = CREATE
    keywords["drop"] = DROP
    keywords["DROP"] = DROP
    keywords["index"] = INDEX
    keywords["INDEX"] = INDEX
    keywords["materialized"] = MATERIALIZED
    keywords["MATERIALIZED"] = MATERIALIZED
    keywords["view"] = VIEW
    keywords["VIEW"] = VIEW
    keywords["refresh"] = REFRESH
    keywords["REFRESH"] = REFRESH
    keywords["load"] = LOAD
    keywords["LOAD"] = LOAD
    keywords["update"] = UPDATE
    keywords["UPDATE"] = UPDATE
    keywords["delete"] = DELETE
    keywords["DELETE"] = DELETE
    keywords["login"] = LOGIN
    keywords["LOGIN"] = LOGIN
    keywords["logout"] = LOGOUT
    keywords["LOGOUT"] = LOGOUT
    keywords["begin"] = BEGIN
    keywords["BEGIN"] = BEGIN
    keywords["commit"] = COMMIT
    keywords["COMMIT"] = COMMIT
    keywords["rollback"] = ROLLBACK
    keywords["ROLLBACK"] = ROLLBACK
    keywords["macro"] = MACRO
    keywords["MACRO"] = MACRO
    keywords["join"] = JOIN
    keywords["JOIN"] = JOIN
    keywords["on"] = ON
    keywords["ON"] = ON
    keywords["attach"] = ATTACH
    keywords["ATTACH"] = ATTACH
    keywords["detach"] = DETACH
    keywords["DETACH"] = DETACH
    keywords["execute"] = EXECUTE
    keywords["EXECUTE"] = EXECUTE
    keywords["all"] = ALL
    keywords["ALL"] = ALL
    keywords["array"] = ARRAY
    keywords["ARRAY"] = ARRAY
    keywords["Array"] = ARRAY
    keywords["attached"] = ATTACHED
    keywords["ATTACHED"] = ATTACHED
    keywords["databases"] = DATABASES
    keywords["DATABASES"] = DATABASES
    keywords["as"] = AS
    keywords["AS"] = AS
    keywords["cache"] = CACHE
    keywords["CACHE"] = CACHE
    keywords["clear"] = CLEAR
    keywords["CLEAR"] = CLEAR
    keywords["distinct"] = DISTINCT
    keywords["DISTINCT"] = DISTINCT
    keywords["group"] = GROUP
    keywords["GROUP"] = GROUP
    keywords["order"] = ORDER
    keywords["ORDER"] = ORDER
    keywords["by"] = BY
    keywords["BY"] = BY
    keywords["sum"] = SUM
    keywords["SUM"] = SUM
    keywords["count"] = COUNT
    keywords["COUNT"] = COUNT
    keywords["avg"] = AVG
    keywords["AVG"] = AVG
    keywords["min"] = MIN
    keywords["MIN"] = MIN
    keywords["max"] = MAX
    keywords["MAX"] = MAX
    keywords["function"] = FUNCTION
    keywords["FUNCTION"] = FUNCTION
    keywords["type"] = TYPE
    keywords["TYPE"] = TYPE
    keywords["struct"] = STRUCT
    keywords["STRUCT"] = STRUCT
    keywords["structs"] = STRUCTS
    keywords["STRUCTS"] = STRUCTS
    keywords["typeof"] = TYPEOF
    keywords["TypeOf"] = TYPEOF
    keywords["exception"] = EXCEPTION
    keywords["EXCEPTION"] = EXCEPTION
    keywords["module"] = MODULE
    keywords["MODULE"] = MODULE
    keywords["returns"] = RETURNS
    keywords["RETURNS"] = RETURNS
    keywords["throws"] = THROWS
    keywords["THROWS"] = THROWS
    keywords["if"] = IF
    keywords["IF"] = IF
    keywords["else"] = ELSE
    keywords["ELSE"] = ELSE
    keywords["match"] = MATCH
    keywords["MATCH"] = MATCH
    keywords["for"] = FOR
    keywords["FOR"] = FOR
    keywords["while"] = WHILE
    keywords["WHILE"] = WHILE
    keywords["then"] = THEN
    keywords["THEN"] = THEN
    keywords["case"] = CASE
    keywords["CASE"] = CASE
    keywords["in"] = IN
    keywords["IN"] = IN
    keywords["try"] = TRY
    keywords["TRY"] = TRY
    keywords["catch"] = CATCH
    keywords["CATCH"] = CATCH
    keywords["let"] = LET
    keywords["LET"] = LET
    keywords["true"] = TRUE
    keywords["TRUE"] = TRUE
    keywords["false"] = FALSE
    keywords["FALSE"] = FALSE
    keywords["break"] = BREAK
    keywords["BREAK"] = BREAK
    keywords["continue"] = CONTINUE
    keywords["CONTINUE"] = CONTINUE
    keywords["and"] = AND
    keywords["AND"] = AND
    keywords["or"] = OR
    keywords["OR"] = OR
    keywords["not"] = NOT
    keywords["NOT"] = NOT
    keywords["insert"] = INSERT
    keywords["INSERT"] = INSERT
    keywords["into"] = INTO
    keywords["INTO"] = INTO
    keywords["values"] = VALUES
    keywords["VALUES"] = VALUES
    keywords["set"] = SET
    keywords["SET"] = SET
    keywords["show"] = SHOW
    keywords["SHOW"] = SHOW
    keywords["secret"] = SECRET
    keywords["SECRET"] = SECRET
    keywords["drop_secret"] = DROP_SECRET
    keywords["DROP_SECRET"] = DROP_SECRET
    keywords["secrets"] = SECRETS
    keywords["SECRETS"] = SECRETS
    keywords["install"] = INSTALL
    keywords["INSTALL"] = INSTALL
    keywords["httpfs"] = HTTPFS
    keywords["HTTPFS"] = HTTPFS
    keywords["with"] = WITH
    keywords["WITH"] = WITH
    keywords["https"] = HTTPS
    keywords["HTTPS"] = HTTPS
    keywords["extensions"] = EXTENSIONS
    keywords["EXTENSIONS"] = EXTENSIONS
    return keywords^
alias SELECT = "SELECT"
alias FROM = "FROM"
alias WHERE = "WHERE"
alias CREATE = "CREATE"
alias DROP = "DROP"
alias INDEX = "INDEX"
alias MATERIALIZED = "MATERIALIZED"
alias VIEW = "VIEW"
alias REFRESH = "REFRESH"
alias LOAD = "LOAD"
alias UPDATE = "UPDATE"
alias DELETE = "DELETE"
alias LOGIN = "LOGIN"
alias LOGOUT = "LOGOUT"
alias BEGIN = "BEGIN"
alias COMMIT = "COMMIT"
alias ROLLBACK = "ROLLBACK"
alias MACRO = "MACRO"
alias JOIN = "JOIN"
alias ON = "ON"
alias ATTACH = "ATTACH"
alias DETACH = "DETACH"
alias EXECUTE = "EXECUTE"
alias ALL = "ALL"
alias ARRAY = "ARRAY"
alias ATTACHED = "ATTACHED"
alias DATABASES = "DATABASES"
alias AS = "AS"
alias CACHE = "CACHE"
alias CLEAR = "CLEAR"
alias DISTINCT = "DISTINCT"
alias GROUP = "GROUP"
alias ORDER = "ORDER"
alias BY = "BY"
alias SUM = "SUM"
alias COUNT = "COUNT"
alias AVG = "AVG"
alias MIN = "MIN"
alias MAX = "MAX"
alias FUNCTION = "FUNCTION"
alias TYPE = "TYPE"
alias STRUCT = "STRUCT"
alias STRUCTS = "STRUCTS"
alias TYPEOF = "TYPEOF"
alias EXCEPTION = "EXCEPTION"
alias MODULE = "MODULE"
alias DOUBLE_COLON = "::"
alias RETURNS = "RETURNS"
alias THROWS = "THROWS"
alias IF = "IF"
alias ELSE = "ELSE"
alias MATCH = "MATCH"
alias FOR = "FOR"
alias WHILE = "WHILE"
alias THEN = "THEN"
alias CASE = "CASE"
alias IN = "IN"
alias TRY = "TRY"
alias CATCH = "CATCH"
alias LET = "LET"
alias TRUE = "TRUE"
alias FALSE = "FALSE"
alias BREAK = "BREAK"
alias CONTINUE = "CONTINUE"
alias INSTALL = "INSTALL"
alias HTTPFS = "HTTPFS"
alias WITH = "WITH"
alias HTTPS = "HTTPS"
alias EXTENSIONS = "EXTENSIONS"

# Operators
alias EQUALS = "="
alias NOT_EQUALS = "!="
alias GREATER = ">"
alias LESS = "<"
alias GREATER_EQUAL = ">="
alias LESS_EQUAL = "<="
alias AND = "and"
alias OR = "or"
alias NOT = "not"
alias BANG = "!"
alias COALESCE = "??"
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
alias LANGLE = "<"
alias RANGLE = ">"
alias COMMA = ","
alias SEMICOLON = ";"
alias COLON = ":"

# Additional keywords
alias INSERT = "INSERT"
alias INTO = "INTO"
alias VALUES = "VALUES"
alias SET = "SET"
alias SHOW = "SHOW"
alias SECRET = "SECRET"
alias DROP_SECRET = "DROP_SECRET"
alias SECRETS = "SECRETS"

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
    var keywords: Dict[String, String]

    fn __init__(out self, source: String):
        self.source = source
        self.tokens = List[Token]()
        self.start = 0
        self.current = 0
        self.line = 1
        self.column = 1
        self.keywords = get_keywords()

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
            # Check if this is a variable {identifier} or just a brace
            if self.is_variable_syntax():
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
            if self.match(":"):
                self.add_token(DOUBLE_COLON)
            else:
                self.add_token(COLON)
        elif c == "@":
            self.at_function()
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
                self.add_token(BANG)
        elif c == ">":
            if self.match("="):
                self.add_token(GREATER_EQUAL)
            else:
                self.add_token(RANGLE)
        elif c == "<":
            if self.match("="):
                self.add_token(LESS_EQUAL)
            else:
                self.add_token(LESS)
        elif c == "~":
            if self.match("f"):
                self.add_token(FUNCTION)
            else:
                # For now, treat ~ as error or skip
                pass
        elif c == "|":
            if self.match(">"):
                self.add_token(PIPE)
            else:
                self.add_token(UNKNOWN, "|")
        elif c == "?":
            if self.match("?"):
                self.add_token(COALESCE)
            else:
                self.add_token(UNKNOWN, "?")
        elif c == "\"" or c == "'":
            self.string(c)
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

    fn is_variable_syntax(mut self) -> Bool:
        """Check if this is a variable syntax {identifier}."""
        var saved_current = self.current
        var saved_column = self.column
        
        # Skip the {
        _ = self.advance()
        
        # Check if followed by identifier
        if not self.is_alpha(self.peek()):
            # Restore position
            self.current = saved_current
            self.column = saved_column
            return False
        
        # Consume identifier
        while self.is_alphanumeric(self.peek()):
            _ = self.advance()
        
        # Check if followed by }
        if self.peek() != "}":
            # Restore position
            self.current = saved_current
            self.column = saved_column
            return False
        
        # Restore position
        self.current = saved_current
        self.column = saved_column
        return True

    fn string(mut self, quote_char: String):
        """Parse a string literal."""
        while self.peek() != quote_char and not self.is_at_end():
            if self.peek() == "\n":
                self.line += 1
                self.column = 1
            _ = self.advance()

        if self.is_at_end():
            self.add_token(UNKNOWN, "Unterminated string")
            return

        _ = self.advance()  # consume the closing quote
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

    fn at_function(mut self):
        """Parse an @function like @TypeOf."""
        while self.is_alphanumeric(self.peek()):
            _ = self.advance()

        var text = String(self.source[self.start + 1:self.current])  # Skip the @
        var type = self.keywords.get(text, IDENTIFIER)
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

    fn is_alphanumeric(self, c: String) -> Bool:
        return self.is_alpha(c) or self.is_digit(c)

    fn get_keyword_type(self, text: String) -> String:
        """Get the token type for keywords using O(1) dictionary lookup."""
        return self.keywords.get(text, IDENTIFIER)