# PL-GRIZZLY SELECT/FROM Interchangeable Keywords

**Date**: January 13, 2026
**Status**: ✅ COMPLETED
**Priority**: MEDIUM - Enhanced language flexibility

## Overview
Extended PL-GRIZZLY parser to support interchangeable `SELECT` and `FROM` keywords, allowing both traditional `SELECT ... FROM ...` syntax and alternative `FROM ... SELECT ...` syntax for improved developer experience and language flexibility.

## Implementation Details

### Parser Changes
- **Modified Methods**: `parenthesized_statement()` and `unparenthesized_statement()` to dispatch on both `SELECT` and `FROM` tokens
- **New Method**: `select_from_statement()` replaces `select_statement()` to handle both syntaxes
- **Logic**: Detects which keyword was used first and parses clauses in appropriate order

### Syntax Support
Both syntaxes are now fully supported:

```sql
-- Traditional syntax
SELECT column1, column2 FROM table_name WHERE condition

-- Alternative syntax
FROM table_name SELECT column1, column2 WHERE condition

-- With THEN clause (both work)
SELECT * FROM users THEN { LET name = user_name }
FROM users SELECT * THEN { LET name = user_name }
```

### AST Structure
The AST remains consistent regardless of syntax used:
- Root node: `AST_SELECT`
- Children: SELECT_LIST, FROM_CLAUSE, WHERE_CLAUSE (optional), THEN_CLAUSE (optional)

## Testing
- **Test Coverage**: Added `test_from_select_syntax()` and `test_from_select_with_then()`
- **Validation**: Both syntaxes parse correctly and produce identical AST structures
- **Integration**: Works with existing THEN clause functionality and array iteration

## Benefits
- **Developer Choice**: Allows developers to use whichever syntax feels more natural
- **Language Flexibility**: Makes PL-GRIZZLY more expressive and user-friendly
- **Backward Compatibility**: Existing `SELECT ... FROM ...` code continues to work unchanged
- **Consistency**: Same parsing logic and AST generation for both syntaxes

## Technical Notes
- Parser uses lookahead to determine syntax order
- No performance impact on parsing speed
- Maintains all existing functionality (WHERE, GROUP BY, ORDER BY, THEN clauses)
- Compatible with array iteration and table iteration in FROM...THEN extension

## Future Considerations
- Could extend to other SQL keywords if needed
- May consider adding configuration option to prefer one syntax over another