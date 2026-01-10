# PL-GRIZZLY Lexer Implementation

## Overview
The PL-GRIZZLY lexer provides lexical analysis for the PL-GRIZZLY programming language, an enhanced SQL dialect with functional programming features designed for Godi's programmable data platform.

## Features
- **Token Types**: Comprehensive token recognition including SQL keywords, operators, delimiters, literals, and PL-GRIZZLY specific constructs
- **Variable Syntax**: Support for `{variable}` interpolation syntax with intelligent detection
- **Pipe Operations**: Recognition of `|>` pipe operator for functional chaining
- **Arrow Functions**: Support for both `=>` and `->` arrow syntax for lambdas and function definitions
- **Flexible Parsing**: Handles complex expressions with nested structures and whitespace

## Token Categories

### Keywords
- SQL: `SELECT`, `FROM`, `WHERE`, `CREATE`, `FUNCTION`, `TYPE`, `AS`, `RETURNS`, `THROWS`
- Control Flow: `IF`, `ELSE`, `MATCH`, `TRY`, `CATCH`, `LET`
- Literals: `TRUE`, `FALSE`

### Operators
- Comparison: `=`, `!=`, `>`, `<`, `>=`, `<=`
- Logical: `&&`, `||`
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- PL-GRIZZLY: `|>`, `=>`, `->`

### Delimiters
- Braces: `{`, `}`
- Parentheses: `(`, `)`
- Brackets: `[`, `]`
- Punctuation: `,`, `;`, `:`, `.`

### Literals & Identifiers
- `IDENTIFIER`: Variable and function names
- `STRING`: Double-quoted string literals
- `NUMBER`: Integer and decimal numbers
- `VARIABLE`: Content of `{variable}` syntax

## Implementation Details

### Lexer Structure
```mojo
struct PLGrizzlyLexer:
    var source: String
    var tokens: List[Token]
    var start: Int
    var current: Int
    var line: Int
    var column: Int
```

### Key Methods
- `tokenize()`: Main tokenization loop
- `scan_token()`: Process individual characters
- `variable()`: Handle `{variable}` syntax
- `identifier()`: Parse identifiers and keywords
- `string()`, `number()`: Parse literals

### Variable Detection Logic
The lexer intelligently distinguishes between variable references and block delimiters:
- `{identifier}` → `VARIABLE` token
- `{` followed by non-identifier → `LBRACE` token

## Usage
Integrated into Godi REPL with `tokenize <code>` command:

```
godi> tokenize FROM {users} SELECT * |> filter(u -> u.active)
Tokens:
  FROM: 'FROM' (line 1, col 1)
  VARIABLE: 'users' (line 1, col 6)
  SELECT: 'SELECT' (line 1, col 14)
  *: '*' (line 1, col 21)
  |>: '|>' (line 1, col 23)
  IDENTIFIER: 'filter' (line 1, col 26)
  (: '(' (line 1, col 32)
  IDENTIFIER: 'u' (line 1, col 33)
  =>: '->' (line 1, col 35)
  IDENTIFIER: 'u' (line 1, col 38)
  .: '.' (line 1, col 39)
  IDENTIFIER: 'active' (line 1, col 40)
  ): ')' (line 1, col 46)
  EOF: '' (line 1, col 47)
```

## Error Handling
- Unterminated strings: Reports "Unterminated string"
- Unterminated variables: Reports "Unterminated variable"
- Unknown characters: Tokenized as `UNKNOWN`

## Integration
- Located in `src/pl_grizzly_lexer.mojo`
- Imported in `main.mojo` for REPL integration
- Provides foundation for PL-GRIZZLY parser development
- No external dependencies, pure Mojo implementation

## Testing
Thoroughly tested with various PL-GRIZZLY syntax patterns:
- Variable interpolation: `{users}`, `{table_name}`
- Pipe operations: `|> filter(...)`, `|> map(...)`
- Arrow functions: `u -> u.active`, `x => x * 2`
- Complex expressions: Nested function calls, mixed operators
- Block syntax: `{ return 42; }` vs `{variable}`

## Future Extensions
- Comment preservation in tokens
- Source location tracking improvements
- Unicode identifier support
- Custom operator definitions