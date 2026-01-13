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

### Type Inspection
```pl-grizzly
@TypeOf(42)           # Returns "number"
@TypeOf("hello")      # Returns "string"  
@TypeOf(true)         # Returns "boolean"
@TypeOf([1,2,3])      # Returns "array"
```

## Variables and Data Types

### Basic Types
```pl-grizzly
let x = 42
let name = "hello"
let active = true
let error = ERROR("something went wrong")
```

### Struct Literals (Object Syntax)
```pl-grizzly
let user = {name: "John", age: 30, active: true}
# Note: Struct literals are parsed but field access is not fully implemented
```

### Array Types
```pl-grizzly
# Array creation - basic syntax
let empty_array = []
let numbers = [1, 2, 3, 4, 5]
let names = ["Alice", "Bob", "Charlie"]

# Note: Array indexing and operations are not fully implemented
```

### TYPE STRUCT Definitions and Literals
```pl-grizzly
# Define a struct type
TYPE STRUCT AS Person(id int, name string, active boolean)

# Create typed struct instances with type checking
type struct as Person { id: 1, name: "John", active: true }
# Returns: Person{id: 1, name: John, active: true}

# Type checking - missing field error
type struct as Person { id: 1, name: "John" }
# Error: Struct 'Person' is missing required fields: active

# Type checking - wrong type error
type struct as Person { id: "wrong", name: "John", active: true }
# Error: Field 'id' should be int, got string
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

## LINQ-Style Queries and Pipes

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

### CREATE TABLE Statements
```pl-grizzly
CREATE TABLE employees (
    id INT,
    name STRING,
    department STRING,
    salary FLOAT
)

CREATE TABLE products (
    id INT,
    name STRING,
    price FLOAT,
    stock INT
)
```

### SELECT Queries
```pl-grizzly
SELECT * FROM employees
SELECT name, department FROM employees WHERE salary > 70000
SELECT id, name FROM products WHERE stock > 0
```

### INSERT Operations
```pl-grizzly
INSERT INTO employees VALUES (1, "Alice", "Engineering", 75000.0)
INSERT INTO employees VALUES (2, "Bob", "Sales", 65000.0)
INSERT INTO products VALUES (101, "Widget A", 19.99, 100)
```

### UPDATE Operations
```pl-grizzly
UPDATE employees SET salary = 85000.0 WHERE name = "Alice"
UPDATE products SET price = 24.99, stock = 50 WHERE id = 101
```

### DELETE Operations
```pl-grizzly
DELETE FROM employees WHERE department = "Sales"
DELETE FROM products WHERE stock = 0
```

## Advanced Database Queries

### Complex WHERE Conditions
```pl-grizzly
SELECT * FROM employees
WHERE salary >= 70000 AND department = "Engineering"

SELECT name, price FROM products
WHERE price BETWEEN 10.0 AND 50.0 AND stock > 0
```

### Aggregation with Pipes
```pl-grizzly
# Calculate average salary by department
SELECT department, AVG(salary) as avg_salary
FROM employees
GROUP BY department

# Count products by price range
SELECT
    CASE
        WHEN price < 10 THEN "Budget"
        WHEN price < 50 THEN "Mid-range"
        ELSE "Premium"
    END as price_category,
    COUNT(*) as product_count
FROM products
GROUP BY price_category
```

### Joins (via correlated queries)
```pl-grizzly
# Find employees with their department info
SELECT e.name, e.salary, d.budget
FROM employees e
JOIN departments d ON e.department = d.name

# Products with low stock alerts
SELECT p.name, p.stock, s.location
FROM products p
JOIN stock_locations s ON p.id = s.product_id
WHERE p.stock < 10
```

## Module System

### Basic Module Loading
```pl-grizzly
LOAD math, io, database;
```

## Complete Examples

### Employee Management System
```pl-grizzly
# Create employee table
CREATE TABLE employees (
    id INT,
    name STRING,
    department STRING,
    salary FLOAT,
    active BOOLEAN
)

# Insert sample data
INSERT INTO employees VALUES (1, "Alice Johnson", "Engineering", 75000.0, true)
INSERT INTO employees VALUES (2, "Bob Smith", "Sales", 65000.0, true)
INSERT INTO employees VALUES (3, "Charlie Brown", "Engineering", 80000.0, true)
INSERT INTO employees VALUES (4, "Diana Prince", "HR", 60000.0, true)

# Define helper functions
FUNCTION find_employees_by_dept(dept) =>
    SELECT * FROM employees WHERE department = dept AND active = true

FUNCTION calculate_dept_budget(dept) =>
    SELECT SUM(salary) as total_budget FROM employees
    WHERE department = dept AND active = true

FUNCTION give_raise(emp_id, percentage) =>
    UPDATE employees SET salary = salary * (1 + percentage/100)
    WHERE id = emp_id

# Usage examples
let engineers = find_employees_by_dept("Engineering")
let eng_budget = calculate_dept_budget("Engineering")
give_raise(1, 5.0)  # Give Alice a 5% raise

# Display results
SELECT name, department, salary FROM employees WHERE active = true
```

### E-commerce Analytics System
```pl-grizzly
# Create tables
CREATE TABLE products (
    id INT,
    name STRING,
    category STRING,
    price FLOAT,
    stock INT
)

CREATE TABLE orders (
    id INT,
    customer_id INT,
    product_id INT,
    quantity INT,
    order_date STRING,
    status STRING
)

# Insert sample data
INSERT INTO products VALUES (101, "Laptop Pro", "Electronics", 1299.99, 50)
INSERT INTO products VALUES (102, "Wireless Mouse", "Electronics", 29.99, 200)
INSERT INTO products VALUES (103, "Office Chair", "Furniture", 299.99, 25)

INSERT INTO orders VALUES (1001, 1, 101, 1, "2024-01-15", "completed")
INSERT INTO orders VALUES (1002, 2, 102, 2, "2024-01-16", "completed")
INSERT INTO orders VALUES (1003, 1, 103, 1, "2024-01-17", "pending")

# Analytics functions
FUNCTION total_revenue() =>
    SELECT SUM(p.price * o.quantity) as revenue
    FROM orders o
    JOIN products p ON o.product_id = p.id
    WHERE o.status = "completed"

FUNCTION top_products(limit) =>
    SELECT p.name, SUM(o.quantity) as total_sold, SUM(p.price * o.quantity) as revenue
    FROM orders o
    JOIN products p ON o.product_id = p.id
    WHERE o.status = "completed"
    GROUP BY p.id, p.name
    ORDER BY total_sold DESC
    LIMIT limit

FUNCTION low_stock_alerts() =>
    SELECT name, stock FROM products WHERE stock < 10

# Generate reports
let revenue = total_revenue()
let top_5 = top_products(5)
let alerts = low_stock_alerts()

# Display comprehensive report
SELECT
    'Total Revenue: $' + CAST(revenue as STRING),
    'Top Products: ' + CAST(COUNT(top_5) as STRING),
    'Low Stock Items: ' + CAST(COUNT(alerts) as STRING)
FROM dual
```

## Advanced PL-GRIZZLY SQL File Example

This example demonstrates a complete business intelligence dashboard implementation mixing all PL-GRIZZLY features as if writing a traditional SQL file with embedded functional programming.

```pl-grizzly
-- =====================================================
-- BUSINESS INTELLIGENCE DASHBOARD - PL-GRIZZLY SQL
-- Complete example mixing SQL operations, functions,
-- pipes, error handling, and complex analytics
-- =====================================================

-- Create core business tables
CREATE TABLE customers (
    id INT,
    name STRING,
    email STRING,
    signup_date STRING,
    status STRING,
    lifetime_value FLOAT
)

CREATE TABLE products (
    id INT,
    name STRING,
    category STRING,
    price FLOAT,
    cost FLOAT,
    stock INT,
    discontinued BOOLEAN
)

CREATE TABLE orders (
    id INT,
    customer_id INT,
    order_date STRING,
    status STRING,
    total_amount FLOAT,
    shipping_cost FLOAT
)

CREATE TABLE order_items (
    id INT,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price FLOAT,
    discount FLOAT
)

-- Insert sample business data
INSERT INTO customers VALUES (1, "Alice Johnson", "alice@email.com", "2024-01-01", "active", 1250.00)
INSERT INTO customers VALUES (2, "Bob Smith", "bob@email.com", "2024-01-15", "active", 890.50)
INSERT INTO customers VALUES (3, "Charlie Brown", "charlie@email.com", "2024-02-01", "inactive", 450.25)

INSERT INTO products VALUES (101, "Laptop Pro", "Electronics", 1299.99, 900.00, 25, false)
INSERT INTO products VALUES (102, "Wireless Mouse", "Electronics", 29.99, 15.00, 150, false)
INSERT INTO products VALUES (103, "Office Chair", "Furniture", 299.99, 150.00, 12, false)
INSERT INTO products VALUES (104, "Old Keyboard", "Electronics", 49.99, 25.00, 0, true)

INSERT INTO orders VALUES (1001, 1, "2024-01-10", "completed", 1329.98, 15.00)
INSERT INTO orders VALUES (1002, 2, "2024-01-20", "completed", 59.98, 5.00)
INSERT INTO orders VALUES (1003, 1, "2024-02-05", "pending", 299.99, 20.00)

INSERT INTO order_items VALUES (1, 1001, 101, 1, 1299.99, 0.00)
INSERT INTO order_items VALUES (2, 1001, 102, 1, 29.99, 0.00)
INSERT INTO order_items VALUES (3, 1002, 102, 2, 29.99, 0.00)
INSERT INTO order_items VALUES (4, 1003, 103, 1, 299.99, 0.00)

-- Define business logic functions (using basic expressions)
FUNCTION calculate_profit_margin(price, cost) =>
    CASE
        WHEN price > 0 THEN (price - cost) / price * 100
        ELSE 0.0
    END

FUNCTION get_customer_segment(lifetime_value) =>
    CASE
        WHEN lifetime_value >= 1000 THEN "VIP"
        WHEN lifetime_value >= 500 THEN "Gold"
        WHEN lifetime_value >= 100 THEN "Silver"
        ELSE "Bronze"
    END

FUNCTION safe_divide(numerator, denominator) =>
    CASE
        WHEN denominator != 0 THEN numerator / denominator
        ELSE 0.0
    END

-- Complex analytics queries with mixed syntax

-- 1. Customer Lifetime Value Analysis with Segmentation
SELECT
    c.name,
    c.lifetime_value,
    get_customer_segment(c.lifetime_value) as segment,
    COUNT(o.id) as total_orders,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id AND o.status = "completed"
WHERE c.status = "active"
GROUP BY c.id, c.name, c.lifetime_value
ORDER BY c.lifetime_value DESC

-- 2. Product Performance Dashboard with Profit Analysis
SELECT
    p.name as product_name,
    p.category,
    p.price,
    p.stock,
    calculate_profit_margin(p.price, p.cost) as profit_margin,
    SUM(oi.quantity) as units_sold,
    SUM(oi.quantity * oi.unit_price) as revenue,
    SUM(oi.quantity * (oi.unit_price - p.cost)) as profit,
    CASE
        WHEN p.stock < 10 THEN "Low Stock"
        WHEN p.stock < 50 THEN "Medium Stock"
        ELSE "Well Stocked"
    END as stock_status
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.id AND o.status = "completed"
WHERE p.discontinued = false
GROUP BY p.id, p.name, p.category, p.price, p.cost, p.stock
HAVING units_sold > 0
ORDER BY revenue DESC

-- 3. Monthly Sales Summary (SQL-based)
let monthly_sales = SELECT
    SUBSTRING(o.order_date, 1, 7) as month,
    SUM(o.total_amount) as total_revenue,
    COUNT(o.id) as order_count,
    COUNT(DISTINCT o.customer_id) as unique_customers
FROM orders o
WHERE o.status = "completed"
GROUP BY SUBSTRING(o.order_date, 1, 7)
ORDER BY month

-- 4. Inventory Management with Alerts
SELECT
    p.name,
    p.stock,
    p.price,
    CASE
        WHEN p.stock = 0 THEN "OUT OF STOCK"
        WHEN p.stock < 5 THEN "CRITICAL"
        WHEN p.stock < 20 THEN "LOW"
        ELSE "OK"
    END as alert_level,
    p.price * p.stock as inventory_value
FROM products
WHERE discontinued = false AND stock <= 20
ORDER BY stock ASC, inventory_value DESC

-- 5. Customer Order Summary
SELECT
    c.name as customer_name,
    c.email,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date,
    MIN(o.order_date) as first_order_date,
    get_customer_segment(c.lifetime_value) as segment
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id AND o.status = "completed"
GROUP BY c.id, c.name, c.email, c.lifetime_value
ORDER BY total_spent DESC

-- 6. Comprehensive Business Metrics Dashboard
let monthly_sales = monthly_sales_report()

let current_metrics = SELECT
    COUNT(DISTINCT c.id) as total_customers,
    COUNT(DISTINCT p.id) as total_products,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value
FROM customers c
CROSS JOIN products p
CROSS JOIN orders o
WHERE o.status = "completed"

let inventory_health = SELECT
    COUNT(CASE WHEN stock = 0 THEN 1 END) as out_of_stock,
    COUNT(CASE WHEN stock < 10 THEN 1 END) as low_stock,
    SUM(price * stock) as total_inventory_value
FROM products
WHERE discontinued = false

-- Display executive summary
SELECT
    "EXECUTIVE DASHBOARD SUMMARY" as report_title,
    CAST(current_metrics.total_customers as STRING) + " customers" as customer_base,
    "$" + CAST(current_metrics.total_revenue as STRING) as total_revenue,
    CAST(current_metrics.total_orders as STRING) + " orders" as order_volume,
    "$" + CAST(current_metrics.avg_order_value as STRING) as avg_order_value,
    CAST(inventory_health.out_of_stock as STRING) + " items OOS" as stock_alerts,
    "$" + CAST(inventory_health.total_inventory_value as STRING) as inventory_value
FROM dual

-- Simple order processing function
FUNCTION calculate_order_total(product_id, quantity) =>
    let product = SELECT price FROM products WHERE id = product_id AND discontinued = false
    CASE
        WHEN product THEN product.price * quantity
        ELSE 0.0
    END

-- Usage example
let order_total = calculate_order_total(101, 2)
SELECT "Order total: $" + CAST(order_total as STRING) FROM dual

-- =====================================================
-- END OF BUSINESS INTELLIGENCE DASHBOARD EXAMPLE
-- This example demonstrates:
-- ✅ SQL-style DDL and DML operations
-- ✅ Complex queries with JOINs, aggregations, subqueries
-- ✅ User-defined functions with CASE expressions
-- ✅ Type casting and string operations
-- ✅ Business logic implementation
-- ✅ Variable assignment and reuse
-- =====================================================
```

## Current Language Status

### ✅ Implemented Features
- Basic expressions (arithmetic, comparisons, logic)
- Variable binding and scoping
- Function definitions and calls
- **Full SQL-style CRUD operations**: CREATE TABLE, SELECT, INSERT, UPDATE, DELETE
- **Schema persistence**: Tables persist across sessions with JSON metadata
- **Data persistence**: ORCStorage with integrity verification
- WHERE conditions with complex expressions
- JOIN operations (correlated subqueries)
- Aggregation functions (SUM, COUNT, AVG)
- GROUP BY and ORDER BY clauses
- LIMIT clause for result pagination
- CASE expressions for conditional logic
- CAST operations for type conversion
- BETWEEN, IN, and other SQL operators
- TYPE SECRET for security configuration
- TYPE STRUCT definitions and typed struct literals
- Struct literals (`{key: value}` syntax)
- HTTP URL support in FROM clauses (via HTTPFS extension)

### 🔄 Partially Implemented
- UPDATE/DELETE parsing (AST evaluation works, but parser methods not implemented)
- Advanced aggregation functions (basic SUM/COUNT/AVG work)
- Complex JOIN syntax (works via correlated queries)

### ❌ Not Yet Implemented
- Method-style syntax (object.method() calls)
- Pattern matching
- Closures and higher-order functions
- Advanced control structures (if/else, loops)
- Type annotations and generics
- Async/await operations
- Macros/metaprogramming
- Stored procedures and triggers
- Transaction management
- Index creation and optimization
- LINQ-style pipe operations (filter, map, etc.)
- Array operations and indexing
- TRY/CATCH error handling
- PIPE operator (`|>`)
- EXCEPTION types and throwing

## REPL Usage Examples

```
godi> CREATE TABLE test_users (id INT, name STRING, age INT)
Table 'test_users' created successfully

godi> INSERT INTO test_users VALUES (1, "Alice", 30)
1

godi> INSERT INTO test_users VALUES (2, "Bob", 25)
1

godi> SELECT * FROM test_users
Query results (2 rows):
Columns: id, name, age
["1", "Alice", "30"]
["2", "Bob", "25"]

godi> SELECT name FROM test_users WHERE age > 26
Query results (1 rows):
Columns: name
["Alice"]

godi> UPDATE test_users SET age = 31 WHERE name = "Alice"
1

godi> SELECT * FROM test_users WHERE name = "Alice"
Query results (1 rows):
Columns: id, name, age
["1", "Alice", "31"]

godi> FUNCTION greet(name) => "Hello, " + name
function:greet(name):"Hello, " + name

godi> greet("World")
"Hello, World"

godi> 1 + 2 * 3
7
```

This document represents the current state of PL-GRIZZLY as of January 12, 2026.</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/mojo-gobi/.agents/_pl_grizzly_examples.md