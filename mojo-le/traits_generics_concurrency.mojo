"""
Mojo Traits, Generics, and Concurrency Basic Example

This file demonstrates basic concepts combining traits, generics, and concurrency in Mojo.
Current Mojo version has limited trait and generic support.
"""

from python import Python

# Example 1: Basic Structs (simulating traits)
struct Circle:
    """A circle shape."""

    var radius: Float64

    fn __init__(out self, radius: Float64):
        self.radius = radius

    fn draw(self):
        print("Drawing circle with radius", self.radius)

    fn get_area(self) -> Float64:
        return 3.14159 * self.radius * self.radius

    fn resize(mut self, factor: Float64):
        self.radius *= factor
        print("Circle resized to radius", self.radius)


struct Rectangle:
    """A rectangle shape."""

    var width: Float64
    var height: Float64

    fn __init__(out self, width: Float64, height: Float64):
        self.width = width
        self.height = height

    fn draw(self):
        print("Drawing rectangle", self.width, "x", self.height)

    fn get_area(self) -> Float64:
        return self.width * self.height

    fn resize(mut self, factor: Float64):
        self.width *= factor
        self.height *= factor
        print("Rectangle resized to", self.width, "x", self.height)


# Example 2: Generic-like processing (using function overloading)
fn process_shape(shape: Circle):
    """Process a circle."""
    shape.draw()
    print("  Area:", shape.get_area())

fn process_shape(shape: Rectangle):
    """Process a rectangle."""
    shape.draw()
    print("  Area:", shape.get_area())


# Example 3: Concurrency simulation (simplified)
fn concurrent_processing():
    """Demonstrate concurrency concepts (simplified for current Mojo version)."""
    print("Starting concurrent processing simulation...")

    # Simulate concurrent tasks
    print("Worker 1: Starting task")
    print("Worker 1: Task completed")
    print("Worker 2: Starting task")
    print("Worker 2: Task completed")
    print("Worker 3: Starting task")
    print("Worker 3: Task completed")
    print("All concurrent tasks completed")
    print("Note: True concurrency requires Python interop or future Mojo async features")


fn main() raises:
    print("=== Mojo Traits, Generics, and Concurrency ===\n")

    # Example 1: Basic Shape Operations
    print("1. Basic Shape Operations")
    var circle = Circle(5.0)
    var rectangle = Rectangle(4.0, 6.0)

    circle.draw()
    print("Circle area:", circle.get_area())
    rectangle.draw()
    print("Rectangle area:", rectangle.get_area(), "\n")

    # Example 2: Polymorphism-like behavior
    print("2. Polymorphism-like Processing")
    process_shape(circle)
    process_shape(rectangle)
    print()

    # Example 3: Resizing
    print("3. Resizing Shapes")
    circle.resize(2.0)
    rectangle.resize(1.5)
    print("After resizing:")
    circle.draw()
    rectangle.draw()
    print()

    # Example 4: Concurrency
    print("4. Concurrency Demonstration")
    concurrent_processing()
    print()

    print("=== Traits, Generics, and Concurrency Examples Completed ===")
    print("Note: Advanced features require future Mojo versions")