# SQL WHERE Clause Enhancements Documentation

## Overview
Enhanced the SQL parser in Mojo Grizzly to support additional comparison operators in WHERE clauses, improving query capabilities beyond the basic > operator.

## Implemented Features

### Equality Conditions
- **Operator**: `=`
- **Implementation**: Supports `==` in SQL syntax for equality comparisons
- **Example**: `SELECT * FROM table WHERE id == 5`
- **Function**: `select_where_eq(table, column_name, value)`

### Comparison Operators
- **Greater Than**: `>` (already supported)
- **Less Than**: `<`
- **Greater Than or Equal**: `>=`
- **Less Than or Equal**: `<=`
- **Not Equal**: `!=`

All comparison operators work with integer columns and filter rows based on the specified condition.

## Usage Examples

```sql
-- Equality
SELECT * FROM table WHERE value == 10

-- Less than
SELECT * FROM table WHERE value < 25

-- Greater than or equal
SELECT * FROM table WHERE id >= 5

-- Not equal
SELECT * FROM table WHERE status != 0
```

## Implementation Details

### Parser Logic
The parser in `parse_and_execute_sql()` checks for operators in order of specificity:
1. `>=` (before `>`)
2. `>`
3. `<=` (before `<`)
4. `<`
5. `!=`
6. `==`

### Filter Functions
Each operator has a corresponding filter function:
- `select_where_greater()`
- `select_where_less()`
- `select_where_greater_eq()`
- `select_where_less_eq()`
- `select_where_not_eq()`

These functions:
1. Find the column index by name
2. Iterate through rows checking the condition
3. Collect matching row indices
4. Create a new table with filtered rows
5. Return the filtered table

### Performance Notes
- Filtering is done in-memory
- Creates new table instances for results
- No indexing optimization yet (marked for future enhancement)

## Testing
Test the enhancements by running queries with the new operators in the CLI or main demo.

## Future Work
- Logical operators (AND, OR, NOT)
- String comparisons
- NULL handling
- Index utilization for faster filtering