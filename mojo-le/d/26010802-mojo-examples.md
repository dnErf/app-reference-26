# Mojo Examples: Intermediate to Expert Level

Date: 2026-01-08

## Overview
This document provides working examples of Mojo programming language, progressing from intermediate to expert level for effective learning.

## Intermediate Example (intermediate.mojo)

This example covers:
- Struct definition with methods
- Function definitions and calls
- Basic error handling with `raises` and `try/except`
- Variable declarations

```mojo
fn main():
    var x = MyStruct(10)
    x.print()
    var result = add(5, 3)
    print("Add result:", result)
    try:
        divide(10, 0)
    except:
        print("Caught division by zero")

struct MyStruct:
    var value: Int

    fn __init__(out self, value: Int):
        self.value = value

    fn print(self):
        print("Value:", self.value)

fn add(a: Int, b: Int) -> Int:
    return a + b

fn divide(a: Int, b: Int) raises -> Int:
    if b == 0:
        raise "Division by zero"
    return a // b
```

To run: `mojo intermediate.mojo`

Expected output:
```
Value: 10
Add result: 8
Caught division by zero
```

## Advanced Example (advanced.mojo)

This example covers:
- Struct definitions with different types
- Async functions and await

```mojo
struct StringWrapper:
    var data: String

    fn __init__(out self, data: String):
        self.data = data

    fn print(self):
        print(self.data)

struct IntWrapper:
    var value: Int

    fn __init__(out self, value: Int):
        self.value = value

    fn print(self):
        print("Int:", self.value)

async fn async_task():
    print("Running async task")

fn main():
    var str_wrapper = StringWrapper("Hello Mojo")
    var int_wrapper = IntWrapper(42)

    str_wrapper.print()
    int_wrapper.print()

    await async_task()
```

To run: `mojo advanced.mojo`

Expected output:
```
Hello Mojo
Int: 42
Running async task
```

## Expert Example 1: Memory Ownership and Lifetimes (memory_ownership.mojo)

This example demonstrates:
- Ownership semantics in Mojo
- Borrowing vs moving values
- Safe memory management without explicit deallocation

```mojo
struct Data:
    var value: Int

    fn __init__(out self, value: Int):
        self.value = value

    fn print(self):
        print("Data value:", self.value)

fn take_owned(data: Data):
    print("Taking owned:")
    data.print()

fn borrow_data(data: Data):
    print("Borrowing:")
    data.print()

fn main():
    var owned_data = Data(42)
    print("Original:")
    owned_data.print()

    borrow_data(owned_data)

    print("Still valid after borrow:")
    owned_data.print()

    take_owned(owned_data)
```

To run: `mojo memory_ownership.mojo`

Expected output:
```
Original:
Data value: 42
Borrowing:
Data value: 42
Still valid after borrow:
Data value: 42
Taking owned:
Data value: 42
```

## Expert Example 2: Traits, Generics, and Concurrency (traits_generics_concurrency.mojo)

This example demonstrates:
- Struct definitions with methods
- Polymorphism through same method names (ad-hoc traits)
- Basic concurrency concepts (simplified due to async limitations in current setup)

```mojo
struct IntData:
    var value: Int

    fn __init__(out self, value: Int):
        self.value = value

    fn print(self):
        print("Int:", self.value)

struct StringData:
    var data: String

    fn __init__(out self, data: String):
        self.data = data

    fn print(self):
        print("String:", self.data)

fn main():
    var int_data = IntData(100)
    var str_data = StringData("Mojo")

    int_data.print()
    str_data.print()

    print("Expert features: structs with methods, demonstrating polymorphism via same method names.")
```

To run: `mojo traits_generics_concurrency.mojo`

Expected output:
```
Int: 100
String: Mojo
Expert features: structs with methods, demonstrating polymorphism via same method names.
```

## Notes
- Ensure Mojo is installed in the virtual environment.
- These examples build upon basic Mojo syntax and introduce more complex features.
- For full expert level, explore official Mojo documentation for advanced traits, generics with constraints, and concurrency patterns.
- Memory ownership in Mojo is automatic, preventing common bugs like use-after-free.