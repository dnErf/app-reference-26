# 20240109 - Enhanced PL-Grizzly Design

## Overview
Design for implementing an enhanced Programming Language (PL) inspired by Grizzly PL within the Mojo Kodiak DB. This PL extends the basic SQL interface with advanced functional programming features, flexible syntax, and type receivers, making it as concise as Lua while providing powerful database scripting capabilities.

## Core Principles
- **Conciseness**: Syntax as minimal as Lua
- **Flexibility**: Interchangeable keywords (SELECT/FROM)
- **Type Safety**: Strong typing with custom types and exceptions
- **Functional**: Pattern matching, pipes, higher-order functions
- **Integrated**: Seamless execution within database queries

## Syntax Extensions

### Variable Declaration and Usage
```sql
-- Variable assignment
SET myvar1 = "users";
SET myjson = { "key1": "value1", "key2": 42 };

-- Variable interpolation in queries
SELECT id, name FROM {myvar1} WHERE active = true;
SELECT * FROM {myvar1} WHERE data = {myjson};
```

### Flexible Query Structure
```sql
-- Traditional SQL
SELECT id, name FROM users WHERE age > 25;

-- Interchangeable keywords
FROM users SELECT id, name WHERE age > 25;
SELECT id, name WHERE age > 25 FROM users;

-- Mixed with variables
FROM {myvar1} SELECT * WHERE status = {mystatus};
```

### Type Definitions
```sql
-- Struct types
CREATE TYPE UserProfile AS STRUCT(
    id: INT64,
    name: TEXT,
    email: TEXT,
    metadata: JSON
);

-- Exception types
CREATE TYPE ValidationError AS EXCEPTION("Data validation failed");
CREATE TYPE NetworkError AS EXCEPTION("Network operation failed");
```

## Function System with Receivers

### Function Definition Syntax
```sql
-- Regular functions
CREATE FUNCTION calculate_discount(price: FLOAT, tier: TEXT) RETURNS FLOAT {
    MATCH tier {
        "gold" => price * 0.8,
        "silver" => price * 0.9,
        _ => price
    }
}

-- Functions with receivers (method-style)
CREATE FUNCTION [UserProfile] is_valid(self) RETURNS BOOLEAN {
    self.name != "" && self.email CONTAINS "@"
}

-- Functions with exceptions
CREATE FUNCTION [UserProfile] validate(self) RETURNS BOOLEAN RAISE ValidationError {
    IF self.age < 0 {
        RAISE ValidationError("Age cannot be negative")
    }
    TRUE
}

-- Async functions
CREATE FUNCTION process_data(data: JSON) RETURNS JSON AS ASYNC {
    TRY expensive_computation(data) CATCH {
        { error: "Processing failed", input: data }
    }
}
```

### Function Usage
```sql
-- Regular calls
SELECT id, calculate_discount(price, tier) FROM products;

-- Method calls (receivers)
SELECT * FROM users WHERE user_profile.is_valid();

-- Chaining with pipes
SELECT users
    |> filter(u -> u.is_valid())
    |> map(u -> { id: u.id, name: u.name })
FROM users;
```

## Advanced Language Features

### Pattern Matching
```sql
CREATE FUNCTION classify_user(user: UserProfile) RETURNS TEXT {
    MATCH user.tier {
        "premium" => "VIP",
        "basic" => "Standard",
        _ => "Unknown"
    }
}

CREATE FUNCTION process_score(score: INT32) RETURNS TEXT {
    MATCH score {
        90..100 => "A",
        80..89 => "B",
        70..79 => "C",
        _ => "F"
    }
}
```

### Try/Catch Exception Handling
```sql
CREATE FUNCTION safe_operation(data: JSON) RETURNS JSON {
    TRY process_data(data) CATCH {
        ValidationError => {
            { error: "Validation failed", details: data }
        }
        NetworkError => {
            { error: "Network issue", retry: true }
        }
        _ => {
            { error: "Unknown error" }
        }    
    }
}
```

### Binary Operations and Expressions
```sql
CREATE FUNCTION complex_calc(a: INT64, b: INT64, c: FLOAT) RETURNS FLOAT {
    IF a > b && c < 100.0 {
        (a + b) * c / 2.0
    } ELSE {
        0.0
    }
}
```

### Pipe Operations
```sql
CREATE FUNCTION process_orders(orders: JSON) RETURNS JSON {
    orders
    |> FILTER(order -> order.status == "completed")
    |> MAP(order -> {
        id: order.id,
        total: order.items |> SUM(item -> item.price * item.quantity)
    })
}
```

## Type System Integration

### Built-in Types
- **Numeric**: INT8, INT16, INT32, INT64, FLOAT, DOUBLE
- **Text**: TEXT, VARCHAR(n)
- **Boolean**: BOOLEAN
- **Date/Time**: DATE, TIME, TIMESTAMP
- **Complex**: JSON, ARRAY<T>, STRUCT fields
- **Binary**: BLOB, BYTEA

### Custom Types
```sql
CREATE TYPE Address AS STRUCT(
    street: TEXT,
    city: TEXT,
    zip: TEXT
);

CREATE TYPE Order AS STRUCT(
    id: INT64,
    items: ARRAY<Item>,
    total: FLOAT,
    shipping: Address
);
```

### Type Receivers
Methods can be defined on types:

```sql
CREATE FUNCTION [Address] format(self) RETURNS TEXT {
    self.street + ", " + self.city + " " + self.zip
}

-- Usage
SELECT order.shipping.format() FROM orders;
```

## Integration with Database

### PL Execution Context
- **Query-time**: Functions executed during query processing
- **Compile-time**: Template expansion for dynamic SQL
- **Stored Procedures**: Persistent PL code in database

### Variable Scope
- **Session Variables**: SET commands persist per connection
- **Query Variables**: Local to query execution
- **Global Variables**: Database-wide configuration

### Error Propagation
- PL exceptions bubble up to SQL error handling
- TRY/CATCH blocks in PL functions
- Custom exception types for domain-specific errors

## Implementation Plan

### Phase 1: Core Parser Extensions
- Extend query_parser.mojo to handle PL syntax
- Add variable resolution in queries
- Implement flexible keyword ordering

### Phase 2: Type System
- Add CREATE TYPE parsing and storage
- Implement STRUCT and EXCEPTION types
- Type checking for function signatures

### Phase 3: Function System
- Function definition parsing and storage
- Receiver syntax implementation
- Basic execution engine for PL expressions

### Phase 4: Advanced Features
- Pattern matching implementation
- Pipe operator support
- Exception handling integration

### Phase 5: Optimization and Integration
- Performance optimization for PL execution
- Full integration with existing database operations
- REPL enhancements for PL development

## Challenges and Solutions

### Syntax Parsing
**Challenge**: Parsing flexible SQL with PL extensions
**Solution**: Use recursive descent parser with backtracking for keyword interchange

### Type Safety
**Challenge**: Ensuring type safety in dynamic PL execution
**Solution**: Compile-time type checking with runtime validation

### Performance
**Challenge**: PL execution overhead in query processing
**Solution**: JIT compilation for frequently used functions, caching of parsed expressions

### Integration
**Challenge**: Seamless PL/SQL interoperability
**Solution**: Unified AST representation for both SQL and PL constructs

## Examples

### Complete PL-Enhanced Query
```sql
SET active_users = "users";
SET min_age = 18;

FROM {active_users}
SELECT id, name, profile
WHERE age >= {min_age} && profile.is_valid()
ORDER BY profile.calculate_score() DESC;
```

### Function with Receivers
```sql
CREATE TYPE User AS STRUCT(id: INT64, name: TEXT, score: FLOAT);

CREATE FUNCTION [User] calculate_score(self) RETURNS FLOAT {
    MATCH self.score {
        0.0..50.0 => self.score * 1.1,
        50.0..100.0 => self.score * 1.05,
        _ => self.score
    }
};

SELECT user.calculate_score() FROM users;
```

This design provides a powerful, flexible PL that enhances the database's capabilities while maintaining performance and safety.