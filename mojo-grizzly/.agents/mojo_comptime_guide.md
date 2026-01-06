# Mojo Compile-Time Programming Guide

## Overview
Compile-time programming in Mojo enables powerful metaprogramming capabilities, allowing code to be generated, analyzed, and optimized at compile time. This guide covers Mojo's comptime features with practical examples.

## Core Concepts

### 1. Compile-Time Evaluation
Mojo can evaluate expressions at compile time using the `comptime` keyword and static assertions.

```mojo
# Compile-time constant
comptime PI = 3.14159

# Compile-time function evaluation
fn factorial(n: Int) -> Int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)

comptime FACT_5 = factorial(5)  # Evaluated at compile time

# Static assertion
static_assert(FACT_5 == 120, "Factorial calculation failed")
```

### 2. Parameterized Types (Generics)
Mojo supports type parameters for generic programming.

```mojo
struct Vector[T: CollectionElement]:
    var data: List[T]
    
    fn __init__(out self):
        self.data = List[T]()
    
    fn push(mut self, value: T):
        self.data.append(value)

# Usage
var int_vec = Vector[Int]()
var str_vec = Vector[String]()
```

### 3. Traits and Interfaces
Traits define contracts that types must implement.

```mojo
trait Printable:
    fn print(self): ...

trait Addable[T: Addable]:
    fn __add__(self, other: T) -> T: ...

struct Point[T: Addable]:
    var x: T
    var y: T
    
    fn __init__(out self, x: T, y: T):
        self.x = x
        self.y = y
    
    fn __add__(self, other: Point[T]) -> Point[T]:
        return Point[T](self.x + other.x, self.y + other.y)

# Implementation
impl Point[T: Addable] : Printable:
    fn print(self):
        print("Point(", self.x, ", ", self.y, ")")

impl Point[T: Addable] : Addable[Point[T]]:
    fn __add__(self, other: Point[T]) -> Point[T]:
        return Point[T](self.x + other.x, self.y + other.y)
```

### 4. Compile-Time Code Generation
Using conditional compilation and type introspection.

```mojo
# Type-based dispatch
fn process[T: AnyType](value: T):
    @parameter
    if T == Int:
        print("Processing integer:", value)
    elif T == String:
        print("Processing string:", value)
    else:
        print("Processing other type")

# Compile-time loops
fn create_array[T: AnyType, size: Int]() -> Array[T, size]:
    var result: Array[T, size]
    for i in range(size):
        result[i] = T()  # Default initialization
    return result
```

### 5. Advanced Metaprogramming

#### Type Introspection
```mojo
fn type_info[T: AnyType]():
    print("Type:", T.__name__)
    print("Size:", T.__size__)
    print("Alignment:", T.__align__)
    
    @parameter
    if T.has_trait(CollectionElement):
        print("Is collection element")
    if T.has_trait(Copyable):
        print("Is copyable")
```

#### Conditional Compilation
```mojo
@parameter
if target.os == "linux":
    alias PathSeparator = "/"
elif target.os == "windows":
    alias PathSeparator = "\\"
else:
    alias PathSeparator = "/"

@parameter
if target.arch == "x86_64":
    alias WordSize = 64
else:
    alias WordSize = 32
```

#### Compile-Time Strings and Code Generation
```mojo
# String manipulation at compile time
comptime def make_getter(field_name: String) -> String:
    return "fn get_" + field_name + "(self) -> " + field_name.type + ":\\n" +
           "    return self." + field_name

# This would generate getter methods at compile time
```

## Practical Examples

### 1. SIMD Vector Operations
```mojo
struct SIMDVector[T: SIMD, size: Int]:
    var data: SIMD[T, size]
    
    fn __init__(out self, values: Array[T, size]):
        self.data = SIMD[T, size]()
        for i in range(size):
            self.data[i] = values[i]
    
    fn add(self, other: SIMDVector[T, size]) -> SIMDVector[T, size]:
        return SIMDVector[T, size](self.data + other.data)
```

### 2. Generic Matrix Operations
```mojo
struct Matrix[T: Numeric, rows: Int, cols: Int]:
    var data: Array[T, rows * cols]
    
    fn __getitem__(self, row: Int, col: Int) -> T:
        return self.data[row * cols + col]
    
    fn __setitem__(mut self, row: Int, col: Int, value: T):
        self.data[row * cols + col] = value
    
    fn transpose(self) -> Matrix[T, cols, rows]:
        var result = Matrix[T, cols, rows]()
        for i in range(rows):
            for j in range(cols):
                result[j, i] = self[i, j]
        return result
```

### 3. Type-Safe Units
```mojo
struct Unit[T: AnyType, unit_name: String]:
    var value: T
    
    fn __init__(out self, value: T):
        self.value = value
    
    fn __add__(self, other: Unit[T, unit_name]) -> Unit[T, unit_name]:
        return Unit[T, unit_name](self.value + other.value)

# Usage
alias Meters = Unit[Int, "meters"]
alias Seconds = Unit[Int, "seconds"]

var distance = Meters(100)
var time = Seconds(10)
# distance + time  # Compile error: different units
```

## Best Practices

1. **Use comptime for performance**: Move calculations to compile time when possible
2. **Leverage traits**: Define clear interfaces for generic code
3. **Type safety**: Use parameterized types to prevent runtime errors
4. **Documentation**: Document comptime requirements and constraints
5. **Testing**: Test both compile-time and runtime behavior

## Common Patterns

### Builder Pattern with Compile-Time Validation
```mojo
struct QueryBuilder[T: AnyType]:
    var conditions: List[String]
    
    fn where(mut self, condition: String) -> Self:
        self.conditions.append(condition)
        return self
    
    fn execute(self) -> List[T]:
        # Compile-time validation of query structure
        static_assert(len(self.conditions) > 0, "Query must have at least one condition")
        # Runtime execution
        return List[T]()  # Placeholder
```

### Compile-Time Sorting Networks
```mojo
# Generate sorting network at compile time
fn sort_network[T: Comparable, n: Int](data: Array[T, n]) -> Array[T, n]:
    # Batcher odd-even mergesort network
    # Implementation would generate optimal comparison sequence
    return data  # Placeholder
```

This guide provides a foundation for understanding and using Mojo's compile-time programming features. Experiment with these concepts to build more efficient and type-safe code.</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/mojo-grizzly/.agents/mojo_comptime_guide.md