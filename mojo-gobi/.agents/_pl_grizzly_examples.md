# PL-GRIZZLY Language Examples

## Overview
PL-GRIZZLY is a functional programming language designed for data processing and database operations. It combines SQL-like syntax with functional programming constructs, pipes, and direct database integration.

## Basic Expressions

### Arithmetic Operations
```pl-grizzly
1 + 2 * 3          # Returns 7 (multiplication has higher precedence)
(1 + 2) * 3        # Returns 9
10 / 2 + 5         # Returns 10
```

### Comparison Operations
```pl-grizzly
5 > 3              # Returns true
10 == 10           # Returns true
"x" != "y"         # Returns true
```

### Logical Operations
```pl-grizzly
true and false     # Returns false
true or false      # Returns true
not true           # Returns false
!false             # Returns true (same as not false)
```

### Coalescing Operations
```pl-grizzly
let name = user.name ?? "Anonymous"    # Returns user.name if not empty/error, otherwise "Anonymous"
let age = user.age ?? 18               # Returns user.age if not zero/error, otherwise 18
let config = get_config() ?? default_config()  # Returns get_config() result if not error, otherwise default
```

### Casting Operations
```pl-grizzly
let x = 42
let y = x as string    # Casts 42 to "42"
let z = "123" :: int   # Casts "123" to 123
```

## Variables and Data Types

### Basic Types
```pl-grizzly
let x = 42
let name = "hello"
let active = true
let error = ERROR("something went wrong")
```

### Type Declarations
```pl-grizzly
type struct as Person (
    name: string,
    age: int
)

let a = type struct as Person {
    name: "John", 
    age: 30, 
    active: true
}

let b = type struct :: Person {
    name: "Jane", 
    age: 25
}
```

### Struct Types
```pl-grizzly
let user = {name: "John", age: 30, active: true}
user.name          # Returns "John"
user.age           # Returns 30
```

### List Types
```pl-grizzly
let numbers = [1, 2, 3, 4, 5]
let names = ["Alice", "Bob", "Charlie"]
```

## Functions

### Function Definition
```pl-grizzly
FUNCTION add(a, b) => a + b
FUNCTION greet(name) => "Hello, " + name
FUNCTION is_even(n) => n % 2 == 0
```

### Function Calls
```pl-grizzly
add(5, 3)          # Returns 8
greet("World")     # Returns "Hello, World"
is_even(4)         # Returns true
```

### Method-Style Syntax
```pl-grizzly
let user = {name: "John", age: 30}
user.get_name()    # Equivalent to get_name(user)
user.is_adult()    # Equivalent to is_adult(user)
```

## Control Flow

### Try/Catch Error Handling
```pl-grizzly
TRY
    risky_operation()
CATCH
    handle_error()
```

### Exception Types
```pl-grizzly
let ex = EXCEPTION("Invalid input")
throw ex
```

## LINQ-Style Queries and Pipes

### Basic Pipes
```pl-grizzly
[1, 2, 3, 4, 5] |> filter(x => x > 3)    # Returns [4, 5]
[1, 2, 3] |> map(x => x * 2)             # Returns [2, 4, 6]
```

### Complex Queries
```pl-grizzly
{users}
|> filter(u => u.active)
|> map(u => u.name)
|> sort()
|> take(10)
```

### Chained Operations
```pl-grizzly
{orders}
|> filter(o => o.status == "pending")
|> map(o => o.total)
|> sum()
```

## Database Operations

### SELECT Queries
```pl-grizzly
SELECT * FROM {users}
SELECT * FROM {users} WHERE active == true
SELECT * FROM {products} WHERE price > 100
```

### INSERT Operations
```pl-grizzly
INSERT INTO {users} VALUES ("John", 30, true)
INSERT INTO {products} VALUES ("Widget", 19.99, 100)
```

### UPDATE Operations
```pl-grizzly
UPDATE {users} SET age = 31 WHERE name == "John"
UPDATE {products} SET price = 24.99, stock = 50 WHERE id == 123
```

### DELETE Operations
```pl-grizzly
DELETE FROM {users} WHERE age < 18
DELETE FROM {products} WHERE stock == 0
```

## Advanced Database Queries

### Complex WHERE Conditions
```pl-grizzly
SELECT * FROM {users}
WHERE age >= 18 && active == true && role == "admin"
```

### Joins (via multiple queries)
```pl-grizzly
let orders = {orders} |> filter(o => o.user_id == user_id)
let products = {products} |> filter(p => p.id in order.product_ids)
```

### Aggregation
```pl-grizzly
{orders}
|> filter(o => o.status == "completed")
|> map(o => o.total)
|> sum()
```

## Module System

### Basic Imports
```pl-grizzly
IMPORT math
IMPORT io
IMPORT database
```

## Complete Examples

### User Management System
```pl-grizzly
# Define user functions
FUNCTION create_user(name, email) =>
    INSERT INTO {users} VALUES (name, email, true, "user")

FUNCTION find_active_users() =>
    SELECT * FROM {users} WHERE active == true

FUNCTION deactivate_user(user_id) =>
    UPDATE {users} SET active = false WHERE id == user_id

FUNCTION delete_inactive_users() =>
    DELETE FROM {users} WHERE active == false

# Usage
create_user("Alice", "alice@example.com")
let active_users = find_active_users()
active_users |> map(u => u.name) |> print()
```

### E-commerce Analytics
```pl-grizzly
# Calculate total revenue
FUNCTION total_revenue() =>
    {orders}
    |> filter(o => o.status == "completed")
    |> map(o => o.total)
    |> sum()

# Find top products
FUNCTION top_products(limit) =>
    {order_items}
    |> group_by(oi => oi.product_id)
    |> map(group => {
        product_id: group.key,
        total_sold: group.items |> map(oi => oi.quantity) |> sum()
    })
    |> sort_by(p => p.total_sold, descending)
    |> take(limit)

# Usage
let revenue = total_revenue()
let top_5 = top_products(5)
```

### Data Processing Pipeline
```pl-grizzly
# Process user data
{raw_users}
|> filter(u => u.email != "")
|> map(u => {
    name: u.name,
    email: u.email.lower(),
    age: calculate_age(u.birth_date),
    active: true
})
|> validate_user_data()
|> save_to_table("processed_users")
```

## Error Handling Patterns

### Safe Division
```pl-grizzly
FUNCTION safe_divide(a, b) =>
    TRY
        a / b
    CATCH
        0  # Return 0 on division by zero

safe_divide(10, 2)    # Returns 5
safe_divide(10, 0)    # Returns 0
```

### Database Error Handling
```pl-grizzly
FUNCTION safe_query(table_name) =>
    TRY
        SELECT * FROM {table_name}
    CATCH
        []  # Return empty list on error

let users = safe_query("users")
let orders = safe_query("nonexistent_table")  # Returns []
```

## Current Language Status

### ✅ Implemented Features
- Basic expressions (arithmetic, comparisons, logic)
- Variable binding and scoping
- Function definitions and calls
- Method-style syntax
- STRUCT and EXCEPTION types
- Try/catch error handling
- LINQ-style pipes and queries
- Full CRUD database operations
- WHERE conditions with complex expressions
- Basic module imports

### 🔄 Partially Implemented
- Module system (basic imports only)
- Error handling (basic try/catch)

### ❌ Not Yet Implemented
- Pattern matching
- Closures and higher-order functions
- Advanced control structures (if/else, loops)
- Type annotations
- Generics
- Async/await
- Macros/metaprogramming

## REPL Usage Examples

```
godi> 1 + 2 * 3
7

godi> FUNCTION add(a, b) => a + b
function:add(a,b):a + b

godi> add(5, 3)
8

godi> {users} |> filter(u => u.active) |> map(u => u.name)
["Alice", "Bob", "Charlie"]

godi> SELECT * FROM {users} WHERE age > 25
[{name: "Alice", age: 30, active: true}, {name: "Bob", age: 28, active: true}]

godi> UPDATE {users} SET age = 31 WHERE name == "Alice"
1

godi> IMPORT math
imported math
```

This document represents the current state of PL-GRIZZLY as of January 12, 2026.</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/mojo-gobi/.agents/_pl_grizzly_examples.md