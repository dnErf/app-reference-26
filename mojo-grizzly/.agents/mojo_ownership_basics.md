# Basic Ownership Features in Mojo

## Overview
Mojo's ownership system is inspired by Rust, providing memory safety and performance without garbage collection. It ensures that each value has exactly one owner at a time, preventing data races and dangling pointers.

## Core Concepts

### 1. Ownership
- Every value in Mojo has an owner
- Only one owner exists at any time
- When the owner goes out of scope, the value is automatically deallocated (RAII)

### 2. Ownership Transfer (Move)
- Transfer ownership using the `^` operator
- After transfer, the original variable becomes invalid
```mojo
var a = List[Int](1, 2, 3)
var b = a^  # a is now invalid, b owns the list
```

### 3. Borrowing
- Borrow a value without taking ownership
- Immutable borrow: `&value`
- Mutable borrow: `&mut value`
- Borrows must not outlive the borrowed value

### 4. Lifetimes
- Compiler ensures borrowed references don't outlive their source
- Prevents use-after-free and dangling pointers

## Key Rules

1. **Single Ownership**: One owner per value
2. **Borrow Checking**: No mutable borrows if immutable borrows exist
3. **No Dangling References**: Lifetimes prevent invalid references
4. **RAII**: Automatic cleanup when scope ends

## Common Patterns

### Function Parameters
- `owned`: Takes ownership (default for structs)
- `borrowed`: Borrows the value
- `mut`: Allows mutation

### Struct Fields
- Owned fields: Transfer ownership
- Reference fields: Must be borrowed with lifetimes

### Collections
- `List[T]`, `Dict[K, V]`: Own their elements
- Transfer elements in/out using `^`

## Detailed Examples

### 1. Function Ownership Transfer
```mojo
fn process_data(owned data: List[Int]) -> Int:
    # Takes ownership of data
    return len(data)

fn main():
    var my_list = List[Int](1, 2, 3)
    var result = process_data(my_list^)  # my_list is invalid after this
    print(result)  # Output: 3
```

### 2. Borrowing for Read-Only Access
```mojo
fn print_length(borrowed data: List[Int]):
    # Borrows data, doesn't take ownership
    print(len(data))

fn main():
    var my_list = List[Int](1, 2, 3, 4)
    print_length(my_list)  # my_list still valid
    print_length(my_list)  # Can use again
```

### 3. Mutable Borrowing
```mojo
fn add_element(inout data: List[Int]):
    # Mutable borrow
    data.append(5)

fn main():
    var my_list = List[Int](1, 2, 3)
    add_element(my_list)  # Modifies my_list
    print(len(my_list))  # Output: 4
```

### 4. Struct Ownership
```mojo
struct Container:
    var data: List[Int]

    fn __init__(out self, owned data: List[Int]):
        self.data = data^  # Take ownership

    fn get_data(self) -> List[Int]:
        return self.data^  # Transfer ownership out

fn main():
    var list = List[Int](1, 2, 3)
    var container = Container(list^)  # list is invalid
    var retrieved = container.get_data()  # container.data is invalid
    print(len(retrieved))  # Output: 3
```

### 5. Lifetime and Borrowing Rules
```mojo
fn get_first(borrowed arr: List[Int]) -> Int:
    return arr[0]

fn main():
    var arr = List[Int](10, 20, 30)
    var first = get_first(arr)  # OK: borrow doesn't outlive arr
    print(first)  # Output: 10
```

### 6. Common Ownership Errors
```mojo
# Error: Use after move
var a = List[Int](1, 2)
var b = a^  # a is invalid
# print(len(a))  # Compile error: use of moved value

# Error: Multiple mutable borrows
fn bad_function(inout x: List[Int], inout y: List[Int]):
    pass

# Error: Borrow outlives owner
fn dangling() -> &List[Int]:
    var local = List[Int](1, 2)
    return &local  # Error: local dies at function end
```

### 7. Collections and Ownership
```mojo
fn main():
    var dict = Dict[String, List[Int]]()
    var list = List[Int](1, 2, 3)
    dict["key"] = list^  # Transfer ownership to dict
    
    # To get it back:
    var retrieved = dict["key"]^  # Move out of dict
    print(len(retrieved))  # Output: 3
    # dict["key"] is now invalid
```

## Memory Safety Benefits
- No null pointer dereferences
- No double frees
- No data races (when following rules)
- Predictable performance

## Best Practices
- Use ownership transfer for large data structures
- Borrow for temporary access
- Minimize mutable borrows
- Design APIs with ownership in mind

This foundation enables Mojo's high-performance, safe systems programming paradigm.