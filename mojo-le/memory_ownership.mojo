# In-Depth Mojo: Memory Ownership and Lifetimes
# This comprehensive example explores Mojo's ownership model in depth, demonstrating how it prevents common memory errors.
# Key concepts: Ownership transfer, borrowing, references, lifetimes, and safe memory management.
# Mojo's ownership is implicit and enforced at compile-time, similar to Rust but integrated with Python interop.

struct Data:
    var value: Int

    fn __init__(out self, value: Int):
        # Constructor: 'out self' indicates we're initializing a new instance.
        # Ownership of 'value' is transferred to 'self.value'.
        self.value = value

    fn print(self):
        # Immutable borrow of self for reading.
        print("Data value:", self.value)

fn consume_data(data: Data):
    # This function takes ownership, consuming the data.
    print("Consuming data:")
    data.print()
    # 'data' is deallocated here.

fn process_borrowed(data: Data):
    # Receive a borrowed reference.
    print("Processing borrowed data:")
    data.print()

fn demonstrate_ownership():
    print("=== Basic Ownership ===")
    var owned_data = Data(42)
    print("Original data:")
    owned_data.print()

    # Borrow explicitly using ^
    process_borrowed(owned_data^)

    # Still valid after borrow
    print("Still valid after borrow:")
    owned_data.print()

    # Move ownership
    consume_data(owned_data^)
    # owned_data is now invalid

struct Container:
    var data: Data

    fn __init__(out self, value: Int):
        self.data = Data(value)

    fn print_data(self):
        self.data.print()

fn demonstrate_lifetimes():
    print("\n=== Lifetimes ===")
    var owner = Data(200)
    print("Owner created")

    # Borrow directly
    process_borrowed(owner^)

    # owner remains valid
    print("After borrow, owner still valid:")
    owner.print()

fn demonstrate_nested():
    print("\n=== Nested Ownership ===")
    var container = Container(100)
    print("Container created with data 100")
    container.print_data()

    # Borrow the data
    process_borrowed(container.data^)

    # Container's data is still valid
    print("Container's data after borrow:")
    container.print_data()

fn main():
    demonstrate_ownership()
    demonstrate_lifetimes()
    demonstrate_nested()

    print("\n=== Summary ===")
    print("Mojo's ownership prevents dangling pointers, double-frees, and use-after-free.")
    print("Use ^ for explicit borrowing, implicit for moving.")
    print("Lifetimes are managed automatically, ensuring memory safety.")