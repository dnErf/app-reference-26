# PL-GRIZZLY Parser Implementation

## Overview
The PL-GRIZZLY parser builds Abstract Syntax Trees (AST) from tokenized PL-GRIZZLY code using recursive descent parsing. It handles expressions with proper operator precedence and supports functional programming constructs.

## Architecture
- **Recursive Descent Parser**: Top-down parsing with separate methods for each grammar rule
- **String-based AST**: Simplified AST representation using parenthesized expressions for easy visualization
- **Precedence Handling**: Correct operator precedence (multiplication before addition, etc.)
- **Error Recovery**: Basic error handling with error tokens

## Grammar Rules

### Statements
```
statement → SELECT select_clause | CREATE FUNCTION function_clause | expression
select_clause → * FROM expression (WHERE expression)?
function_clause → IDENTIFIER ( parameters ) => expression
parameters → IDENTIFIER ( , IDENTIFIER )*
```

### Expressions
```
expression → pipe
pipe → equality ( "|>" equality )*
equality → comparison ( ( "!=" | "=" ) comparison )*
comparison → term ( ( ">" | "<" | ">=" | "<=" ) term )*
term → factor ( ( "-" | "+" ) factor )*
factor → unary ( ( "/" | "*" ) unary )*
unary → ( "!" | "-" ) unary | call
call → primary ( "(" arguments? ")" )*
primary → NUMBER | STRING | TRUE | FALSE | IDENTIFIER | VARIABLE | "(" expression ")"
arguments → expression ( "," expression )*
```

### Operators (by precedence)
1. **Pipe**: `|>` (lowest precedence)
2. **Equality**: `==`, `!=`
3. **Comparison**: `>`, `<`, `>=`, `<=`
4. **Term**: `+`, `-`
5. **Factor**: `*`, `/`
6. **Unary**: `!`, `-`
7. **Call**: function calls
8. **Primary**: literals, identifiers, variables

## AST Representation
The parser generates string-based AST representations:

- Literals: `"42"`, `"hello"`, `"true"`
- Variables: `"{ users }"`
- Identifiers: `"filter"`, `"u"`
- Binary ops: `"(+ 1 2)"`, `"(== x y)"`
- Function calls: `"(call filter u)"`
- Pipes: `"(|> { users } (call filter u))"`
- SELECT: `"(SELECT from: { users } where: (== active true))"`
- FUNCTION: `"(FUNCTION add(a, b) => (+ a b))"`

## Implementation Details

### Core Methods
- `parse()`: Entry point returning parsed statement or expression
- `select_statement()`: Parse SELECT statements
- `function_statement()`: Parse CREATE FUNCTION statements
- `expression()`: Parse full expression with all operators
- `pipe()`: Handle pipe operations
- `equality()`: Equality operators
- `comparison()`: Comparison operators
- `term()`: Addition/subtraction
- `factor()`: Multiplication/division
- `unary()`: Unary operators
- `call()`: Function calls and primary expressions
- `primary()`: Basic literals and identifiers

### Token Handling
- `match(type)`: Consume token if matches
- `check(type)`: Check without consuming
- `advance()`: Move to next token
- `peek()`: Look ahead without consuming
- `previous()`: Get last consumed token

## Features Supported
- **Literals**: Numbers, strings, booleans
- **Variables**: `{variable}` syntax
- **Identifiers**: Variable and function names
- **Binary Operations**: All standard arithmetic and comparison operators
- **Function Calls**: `func(arg1, arg2)`
- **Pipe Operations**: `expr |> func`
- **SELECT Statements**: `SELECT * FROM {table} WHERE condition`
- **CREATE FUNCTION**: `CREATE FUNCTION name(params) => body`
- **Parenthesized Expressions**: `(expr)`

## Usage
Integrated into Godi REPL:

```
godi> parse 1 + 2 * 3
Parsed successfully
AST: (+ 1 (* 2 3))

godi> parse {users} |> filter(u) |> map(v => v.name)
Parsed successfully
AST: (|> (|> { users } (call filter u)) (call map v => v.name))

godi> parse SELECT * FROM {users} WHERE active == true
Parsed successfully
AST: (SELECT from: { users } where: (== active true))

godi> parse CREATE FUNCTION add(a, b) => a + b
Parsed successfully
AST: (FUNCTION add(a, b) => (+ a b))
```

## Limitations
- No complex SELECT clauses (only `SELECT *`)
- Arrow functions in expressions not fully parsed
- No semantic validation
- String-based AST limits advanced analysis
- Error messages are basic

## Future Extensions
- Statement parsing for SQL constructs
- Arrow function parsing
- Type annotations
- Error recovery and reporting
- Full AST node structures instead of strings
- Semantic analysis and validation

## Integration
- Located in `src/pl_grizzly_parser.mojo`
- Depends on `PLGrizzlyLexer` for tokenization
- REPL command: `parse <code>`
- No external dependencies

## Testing
Verified with various expressions:
- Arithmetic: `1 + 2 * 3` → `(+ 1 (* 2 3))`
- Pipes: `{users} |> filter` → `(|> { users } filter)`
- Function calls: `filter(u)` → `(call filter u)`
- Variables: `{users}` → `{ users }`
- Complex: `{users} |> filter(u)` → `(|> { users } (call filter u))`