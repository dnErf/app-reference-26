# PL-GRIZZLY Parser Implementation

## Overview
The PL-GRIZZLY parser builds Abstract Syntax Trees (AST) from tokenized PL-GRIZZLY code using recursive descent parsing. It handles expressions with proper operator precedence and supports functional programming constructs.

## Architecture
- **Recursive Descent Parser**: Top-down parsing with separate methods for each grammar rule
- **String-based AST**: Simplified AST representation using parenthesized expressions for easy visualization
- **Precedence Handling**: Correct operator precedence (multiplication before addition, etc.)
- **Error Recovery**: Basic error handling with error tokens

## Grammar Rules

### Expressions
```
expression → pipe
pipe → call ( "|>" call )*
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

## Implementation Details

### Core Methods
- `parse()`: Entry point returning parsed expression
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
- **Parenthesized Expressions**: `(expr)`

## Usage
Integrated into Godi REPL:

```
godi> parse 1 + 2 * 3
Parsed successfully
AST: (+ 1 (* 2 3))

godi> parse {users} |> filter(u -> u.active)
Parsed successfully
AST: (|> { users } (call filter u))
```

## Limitations
- No statement parsing (SELECT, CREATE FUNCTION) yet
- Arrow functions (`->`, `=>`) not fully parsed in expressions
- No error reporting with line/column information
- String-based AST limits semantic analysis capabilities

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