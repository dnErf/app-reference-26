# Advanced Query Features Documentation

## Overview
Mojo-Grizzly now supports advanced SQL query features including subqueries, Common Table Expressions (CTEs), window functions, and recursive queries.

## Features

### Subqueries
- **WHERE Subqueries**: Support for `IN (SELECT ...)`, `EXISTS (SELECT ...)`, and scalar comparisons
- **FROM Subqueries**: Derived tables with `(SELECT ...) AS alias`
- **SELECT Subqueries**: Scalar subqueries in SELECT list

### Common Table Expressions (CTEs)
- **Syntax**: `WITH cte_name AS (SELECT ...) SELECT ...`
- **Execution**: CTEs are executed first and stored for use in main query

### Window Functions
- **ROW_NUMBER()**: Assigns sequential numbers
- **RANK()**: Assigns ranks with tie handling
- **Syntax**: `ROW_NUMBER() OVER (PARTITION BY col ORDER BY col)`

### Recursive Queries
- **Syntax**: `WITH RECURSIVE cte AS (...) SELECT ...`
- **Support**: Framework for recursive CTE execution

### Query Hints
- **Syntax**: `/*+ hint */ SELECT ...`
- **Support**: Placeholder for hint parsing

## Examples

### CTE
```sql
WITH high_sales AS (
    SELECT * FROM sales WHERE amount > 1000
)
SELECT * FROM high_sales WHERE region = 'US'
```

### Window Function
```sql
SELECT name, salary, ROW_NUMBER() OVER (ORDER BY salary DESC) as rank
FROM employees
```

### Subquery in WHERE
```sql
SELECT * FROM products
WHERE id IN (SELECT product_id FROM orders WHERE quantity > 10)
```

## Implementation Details

### Files
- **query.mojo**: Extended parser for WITH, subqueries, window functions
- Added `execute_subquery()`, `row_number()`, `rank()` functions

### Limitations
- Basic parsing and execution
- No full recursive query implementation yet
- Window functions are placeholders