"""
Mojo Memory Ownership Basic Example

This file demonstrates basic memory ownership concepts in Mojo.
Note: Automatic cleanup may not work as expected in current version.
"""

# Example 1: Basic Resource
struct SafeResource:
    """A resource that manages its own data."""

    var data: List[Int]
    var name: String

    fn __init__(out self, name: String, size: Int):
        """Initialize resource."""
        self.name = name
        self.data = List[Int]()
        for i in range(size):
            self.data.append(i * 10)
        print("SafeResource '", self.name, "' created with", size, "elements")

    fn print_data(self):
        """Print the resource data."""
        print("Resource '", self.name, "' data: [", end="")
        for i in range(len(self.data)):
            if i > 0:
                print(", ", end="")
            print(self.data[i], end="")
        print("]")


# Example 2: Function that creates resources
fn create_resource(name: String, size: Int) -> SafeResource:
    """Create a new resource."""
    return SafeResource(name, size)


# Example 3: Function that processes resources
fn process_resource(mut resource: SafeResource):
    """Process a resource (modifies it)."""
    print("Processing resource '", resource.name, "'")
    # Add a value to demonstrate modification
    resource.data.append(999)
    resource.print_data()


fn main() raises:
    print("=== Mojo Memory Ownership Basic Examples ===\n")

    # Example 1: Resource Creation
    print("1. Resource Creation")
    var res1 = SafeResource("First", 3)
    res1.print_data()
    print()

    # Example 2: Resource Creation via Function
    print("2. Resource Creation via Function")
    var res2 = create_resource("Second", 4)
    res2.print_data()
    print()

    # Example 3: Resource Processing
    print("3. Resource Processing")
    process_resource(res1)
    print()

    # Example 4: Multiple Resources
    print("4. Multiple Resources")
    _ = create_resource("Third", 2)
    _ = create_resource("Fourth", 2)
    print("Resources created\n")

    print("=== Memory Ownership Examples Completed ===")
    print("Note: Automatic cleanup not demonstrated in current Mojo version")