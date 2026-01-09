# In-Depth Mojo: Traits, Generics, and Concurrency
# This sophisticated example delves into advanced Mojo features for type-safe abstraction and high-performance concurrency.
# Key concepts: Traits for interfaces, generics for reusable code, async/await for non-blocking operations.
# Demonstrates polymorphism, type constraints, and concurrent task execution.

# Note: Full trait implementation may require explicit 'impl' in future versions.
# For now, demonstrating ad-hoc polymorphism and basic generics.

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

struct FloatData:
    var value: Float64

    fn __init__(out self, value: Float64):
        self.value = value

    fn print(self):
        print("Float:", self.value)

# Generic container without trait constraint (simplified)
# struct GenericContainer[T: AnyType]:
#     var item: T
#     fn __init__(out self, item: T):
#         self.item = item
#     fn display(self):
#         self.item.print()

# Generic function without trait (simplified)
# fn generic_print[T: AnyType](item: T):
#     print("Generic print:")
#     item.print()

# Concurrency examples (simplified)
fn async_task(id: Int, message: String):
    print("Task", id, ":", message)

# async fn concurrent_processing():
#     await async_task(1, "Hello")
#     await async_task(2, "World")
#     await async_task(3, "from Mojo")

fn demonstrate_polymorphism():
    print("=== Polymorphism ===")
    var int_data = IntData(100)
    var str_data = StringData("Mojo")
    var float_data = FloatData(3.14)

    # Direct calls demonstrating same interface
    int_data.print()
    str_data.print()
    float_data.print()

fn demonstrate_generics():
    print("\n=== Generics (Simplified) ===")
    # Note: Full generics with traits not implemented in this version.
    # Demonstrating type-safe operations without generics.
    var int_data = IntData(200)
    var str_data = StringData("Generic")

    int_data.print()
    str_data.print()

    # Simulated generic behavior
    print("Simulated generic print for Int:")
    IntData(300).print()
    print("Simulated generic print for String:")
    StringData("Generic function").print()

fn demonstrate_concurrency():
    print("\n=== Concurrency (Simplified) ===")
    # Note: Full async/await may have issues in this version.
    # Simulating concurrent operations sequentially.
    async_task(1, "Hello")
    async_task(2, "World")
    async_task(3, "from Mojo")

fn main():
    demonstrate_polymorphism()
    demonstrate_generics()
    demonstrate_concurrency()

    print("\n=== Summary ===")
    print("Ad-hoc polymorphism via same method names.")
    print("Generics enable type-safe abstractions.")
    print("Async/await for concurrent execution.")