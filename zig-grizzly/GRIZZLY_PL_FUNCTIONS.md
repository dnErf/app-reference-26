# Grizzly PL Function Reference

## Overview

Grizzly PL (Programming Language) provides a powerful functional programming system integrated with SQL. Functions support advanced features including pattern matching, try/catch exception handling, binary operations with full operator precedence, and pipe-based function chaining. Functions can be used both at runtime (in queries) and compile-time (in templates), supporting both synchronous and asynchronous execution.

## Function Definition Syntax

### Basic Syntax
```sql
CREATE FUNCTION function_name(parameter_name parameter_type) RETURNS return_type {
    expression
}
```

### Complete Syntax
```sql
CREATE FUNCTION function_name(param1 type1, param2 type2, ...) RETURNS return_type [AS ASYNC|SYNC] {
    function_body
}
```

## Parameters

Functions can have zero or more parameters:

```sql
-- No parameters
CREATE FUNCTION get_current_timestamp() RETURNS TIMESTAMP {
    now()
}

-- Single parameter
CREATE FUNCTION double(x int64) RETURNS int64 {
    x * 2
}

-- Multiple parameters
CREATE FUNCTION calculate_discount(price FLOAT, tier TEXT) RETURNS FLOAT {
    price * 0.8
}
```

## Return Types

Functions can return any supported Grizzly data type:

- **Numeric**: `int8`, `int16`, `int32`, `int64`, `FLOAT`, `DOUBLE`
- **Text**: `TEXT`, `VARCHAR(n)`
- **Boolean**: `BOOLEAN`
- **Date/Time**: `DATE`, `TIME`, `TIMESTAMP`
- **Binary**: `BLOB`, `BYTEA`
- **Complex**: `JSON`, `ARRAY`, custom types via `CREATE TYPE`

## Execution Context

### Async (Default)
Functions execute asynchronously by default, allowing non-blocking operations:

```sql
CREATE FUNCTION process_data(data JSON) RETURNS JSON {
    let result = expensive_computation(data);
    result
}

-- Explicit async (same as default)
CREATE FUNCTION process_data(data JSON) RETURNS JSON AS ASYNC {
    let result = expensive_computation(data);
    result
}
```

### Sync (Explicit)
For blocking operations that must complete before proceeding:

```sql
CREATE FUNCTION sync_process(data JSON) RETURNS JSON AS SYNC {
    let result = expensive_computation(data);
    result
}
```

## Function Body Types

### Simple Expression Body
Direct expression evaluation:

```sql
CREATE FUNCTION add(x int64, y int64) RETURNS int64 {
    x + y
}

CREATE FUNCTION greet(name TEXT) RETURNS TEXT {
    "Hello, " + name + "!"
}
```

### Pattern Matching Body
Advanced control flow using pattern matching:

```sql
CREATE FUNCTION calculate_discount(price FLOAT, tier TEXT) RETURNS FLOAT {
    match tier {
        "gold" => price * 0.8,
        "silver" => price * 0.9,
        "bronze" => price * 0.95,
        _ => price
    }
}

CREATE FUNCTION classify_score(score int32) RETURNS TEXT {
    match score {
        90..100 => "A",
        80..89 => "B",
        70..79 => "C",
        60..69 => "D",
        _ => "F"
    }
}
```

### Try/Catch Exception Handling
Error handling with try/catch expressions:

```sql
CREATE FUNCTION safe_divide(x FLOAT, y FLOAT) RETURNS FLOAT {
    try x / y catch 0.0
}

CREATE FUNCTION process_data(data JSON) RETURNS JSON {
    try {
        expensive_computation(data)
    } catch {
        { error: "Processing failed", input: data }
    }
}
```

### Binary Operations
Full operator precedence with arithmetic, comparison, and logical operators:

```sql
CREATE FUNCTION complex_calculation(a int64, b int64, c FLOAT) RETURNS FLOAT {
    if a > b && c < 100.0 {
        (a + b) * c / 2.0
    } else {
        0.0
    }
}

CREATE FUNCTION validate_input(value int64, min_val int64, max_val int64) RETURNS BOOLEAN {
    value >= min_val && value <= max_val
}
```

### Pipe Operations
Function chaining with the pipe operator:

```sql
CREATE FUNCTION process_orders(orders JSON) RETURNS JSON {
    orders
    |> filter(order -> order.status == "completed")
    |> map(order -> {
        id: order.id,
        total: order.items |> sum(item -> item.price * item.quantity)
    })
}
```

### Complex Expressions with Variables
Using `let` bindings for local variables:

```sql
CREATE FUNCTION process_user(user JSON) RETURNS JSON {
    let name = user.name;
    let age = user.age;

    {
        name: name,
        age: age,
        processed_at: now()
    }
}
```

## Usage in Queries

Functions can be called from SQL queries:

```sql
-- Simple function call
SELECT id, double(price) as doubled_price FROM products;

-- Function in WHERE clause
SELECT * FROM users WHERE classify_age(age) = 'adult';

-- Function with complex parameters
SELECT id, calculate_discount(price, membership_tier) as final_price
FROM products p
JOIN users u ON p.user_id = u.id;
```

## Usage in Templates

Functions work in CREATE MODEL templates for dynamic SQL generation:

```sql
CREATE MODEL user_summary AS {
    let table_name = 'users';
    let active_only = true;

    SELECT id, name, email
    FROM {table_name}
    WHERE {if active_only then 'active = true' else 'true' end}
};
```

## Advanced Patterns

### Recursive Functions
```sql
CREATE FUNCTION factorial(n int64) RETURNS int64 {
    match n {
        0 => 1,
        1 => 1,
        _ => n * factorial(n - 1)
    }
}
```

### Higher-Order Functions
```sql
CREATE FUNCTION apply_discount(prices ARRAY<FLOAT>, discount_rate FLOAT) RETURNS ARRAY<FLOAT> {
    prices |> map(price -> price * (1 - discount_rate))
}
```

### Data Transformation Pipelines
```sql
CREATE FUNCTION process_orders(orders JSON) RETURNS JSON {
    orders
    |> filter(order -> order.status = 'completed')
    |> map(order -> {
        id: order.id,
        total: order.items |> map(item -> item.price * item.quantity) |> sum(),
        customer: order.customer
    })
}
```

## Error Handling

Functions support comprehensive error handling with try/catch expressions:

```sql
CREATE FUNCTION safe_divide(x FLOAT, y FLOAT) RETURNS FLOAT {
    try x / y catch 0.0
}

CREATE FUNCTION process_with_fallback(data JSON) RETURNS JSON {
    try {
        expensive_operation(data)
    } catch {
        { status: "error", message: "Operation failed", data: data }
    }
}
```

Functions can also return errors using the error handling system:

```sql
CREATE FUNCTION validate_input(value int64) RETURNS int64 {
    if value < 0 then error('Value must be non-negative') else value end
}
```

## Function Management

### Listing Functions
```sql
SHOW FUNCTIONS;
```

### Dropping Functions
```sql
DROP FUNCTION function_name;
```

### Function Metadata
Functions are stored with their signatures and can be introspected:

```sql
DESCRIBE FUNCTION function_name;
```

## Best Practices

1. **Naming**: Use descriptive names with snake_case
2. **Parameters**: Keep parameter lists reasonable (max 5-7 parameters)
3. **Return Types**: Be specific about return types for better type safety
4. **Documentation**: Add comments for complex functions
5. **Testing**: Test functions with various input combinations
6. **Performance**: Consider async/sync based on blocking behavior

## Examples

### Data Validation Function
```sql
CREATE FUNCTION validate_email(email TEXT) RETURNS BOOLEAN {
    match email {
        /.*@.*\..*/ => true,
        _ => false
    }
}
```

### Business Logic Function
```sql
CREATE FUNCTION calculate_customer_lifetime_value(orders JSON) RETURNS FLOAT {
    let total_spent = orders |> map(order -> order.total) |> sum();
    let order_count = orders |> length();
    let avg_order_value = total_spent / order_count;

    total_spent * (1 + (order_count / 10))
}
```

### Template Helper Function
```sql
CREATE FUNCTION build_where_clause(filters JSON) RETURNS TEXT {
    let conditions = filters |> map(filter ->
        filter.field + ' ' + filter.operator + ' ' + filter.value
    ) |> join(' AND ');

    match conditions {
        "" => "",
        _ => 'WHERE ' + conditions
    }
}
```

This function system provides a powerful way to extend Grizzly's capabilities with custom logic while maintaining the performance and safety characteristics of the database engine.</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/zig-grizzly/GRIZZLY_PL_FUNCTIONS.md