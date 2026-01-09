# Mojo Examples: Intermediate to Advanced

Date: 2026-01-08

## Overview
This document provides working examples of Mojo programming language, progressing from intermediate to advanced concepts. These examples demonstrate key features for learning Mojo effectively.

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
- Object-oriented programming with methods

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

## Notes
- Ensure Mojo is installed in the virtual environment.
- These examples build upon basic Mojo syntax and introduce more complex features.
- For full expert level, explore traits, generics, memory ownership, and concurrency in Mojo documentation.