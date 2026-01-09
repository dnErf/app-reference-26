"""
Mojo Parameters Basic Example

This file demonstrates basic compile-time parameterization concepts in Mojo.
Current Mojo version has limited parameter support compared to the documentation.
"""

# Example 1: Basic parameterized struct
struct Container[size: Int]:
    """A container with compile-time size."""

    var data: List[Int]

    fn __init__(out self):
        """Initialize container with zeros."""
        self.data = List[Int]()
        for i in range(size):
            self.data.append(0)

    fn set_value(mut self, index: Int, value: Int):
        """Set value at index."""
        if index >= 0 and index < size:
            self.data[index] = value

    fn get_value(self, index: Int) -> Int:
        """Get value at index."""
        if index >= 0 and index < size:
            return self.data[index]
        return 0

    fn print(self):
        """Print all values."""
        print("Container[size=", size, "]: [", end="")
        for i in range(size):
            if i > 0:
                print(", ", end="")
            print(self.data[i], end="")
        print("]")


# Example 2: Simple parameterized function
fn create_range(start: Int, end: Int) -> List[Int]:
    """Create a list with range of values."""
    var result = List[Int]()
    for i in range(start, end):
        result.append(i)
    return result^


fn main() raises:
    print("=== Mojo Parameters Basic Examples ===\n")

    # Example 1: Parameterized Structs
    print("1. Parameterized Structs")
    var container = Container[5]()
    container.set_value(0, 10)
    container.set_value(1, 20)
    container.set_value(2, 30)
    container.print()
    print("Value at index 1:", container.get_value(1), "\n")

    # Example 2: Basic Functions
    print("2. Basic Functions")
    var range_list = create_range(1, 6)
    print("create_range(1, 6) = [", end="")
    for i in range(len(range_list)):
        if i > 0:
            print(", ", end="")
        print(range_list[i], end="")
    print("]\n")

    print("=== Basic Parameter Examples Completed ===")
    print("Note: Advanced parameter features require future Mojo versions")