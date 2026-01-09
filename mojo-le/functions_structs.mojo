"""
Mojo Functions and Structs Example

This file demonstrates:
- Function definitions with parameters and return values
- Struct definitions and usage
- Method definitions within structs
- Function overloading
- Basic object-oriented concepts in Mojo
"""

# 1. Basic function definitions
fn greet(name: String) -> String:
    """Return a greeting message."""
    return "Hello, " + name + "!"

fn add_numbers(a: Int, b: Int) -> Int:
    """Add two integers and return the result."""
    return a + b

fn calculate_area(length: Float64, width: Float64) -> Float64:
    """Calculate the area of a rectangle."""
    return length * width

fn is_even(number: Int) -> Bool:
    """Check if a number is even."""
    return number % 2 == 0

# 2. Function with multiple return values (using a struct)
struct Point:
    var x: Float64
    var y: Float64

    fn __init__(out self, x: Float64, y: Float64):
        self.x = x
        self.y = y

    fn distance_from_origin(self) -> Float64:
        """Calculate distance from origin (0,0) using Manhattan distance approximation."""
        var abs_x = self.x if self.x >= 0 else -self.x
        var abs_y = self.y if self.y >= 0 else -self.y
        return abs_x + abs_y

    fn to_string(self) -> String:
        """Convert point to string representation."""
        return "(" + String(self.x) + ", " + String(self.y) + ")"

# 3. Rectangle struct with methods
struct Rectangle:
    var length: Float64
    var width: Float64

    fn __init__(out self, length: Float64, width: Float64):
        self.length = length
        self.width = width

    fn area(self) -> Float64:
        """Calculate the area of the rectangle."""
        return self.length * self.width

    fn perimeter(self) -> Float64:
        """Calculate the perimeter of the rectangle."""
        return 2 * (self.length + self.width)

    fn is_square(self) -> Bool:
        """Check if the rectangle is a square."""
        return self.length == self.width

    fn scale(mut self, factor: Float64):
        """Scale the rectangle by a factor."""
        self.length *= factor
        self.width *= factor

# 4. Person struct demonstrating more complex data
struct Person:
    var name: String
    var age: Int
    var height: Float64  # in centimeters

    fn __init__(out self, name: String, age: Int, height: Float64):
        self.name = name
        self.age = age
        self.height = height

    fn introduce(self) -> String:
        """Return an introduction string."""
        return "Hi, I'm " + self.name + ", " + String(self.age) + " years old, " + String(self.height) + "cm tall."

    fn can_vote(self) -> Bool:
        """Check if the person can vote (age >= 18)."""
        return self.age >= 18

    fn birthday(mut self):
        """Increment age by 1."""
        self.age += 1

# 5. Function overloading (same name, different parameters)
fn calculate_area(radius: Float64) -> Float64:
    """Calculate the area of a circle."""
    return 3.14159 * radius * radius

fn calculate_triangle_area(base: Float64, height: Float64) -> Float64:
    """Calculate the area of a triangle."""
    return 0.5 * base * height

# 6. Functions that work with structs
fn compare_rectangles(rect1: Rectangle, rect2: Rectangle) -> String:
    """Compare two rectangles and return a description."""
    var area1 = rect1.area()
    var area2 = rect2.area()

    if area1 > area2:
        return "First rectangle is larger"
    elif area2 > area1:
        return "Second rectangle is larger"
    else:
        return "Rectangles have the same area"

fn create_square(side: Float64) -> Rectangle:
    """Create a square rectangle."""
    return Rectangle(side, side)

fn print_person_info(person: Person):
    """Print information about a person."""
    print("Name:", person.name)
    print("Age:", person.age)
    print("Height:", person.height, "cm")
    print("Can vote:", person.can_vote())
    print("Introduction:", person.introduce())
    print()

fn main():
    print("=== Mojo Functions and Structs ===\n")

    # 1. Basic function calls
    print("1. Basic Function Calls")
    print(greet("World"))
    print("5 + 3 =", add_numbers(5, 3))
    print("Area of 4x6 rectangle:", calculate_area(4.0, 6.0))
    print("Is 42 even?", is_even(42))
    print("Is 13 even?", is_even(13), "\n")

    # 2. Point struct usage
    print("2. Point Struct")
    var origin = Point(0.0, 0.0)
    var point1 = Point(3.0, 4.0)
    var point2 = Point(1.5, 2.5)

    print("Origin:", origin.to_string())
    print("Point1:", point1.to_string())
    print("Point1 distance from origin:", point1.distance_from_origin())
    print("Point2:", point2.to_string())
    print("Point2 distance from origin:", point2.distance_from_origin(), "\n")

    # 3. Rectangle struct usage
    print("3. Rectangle Struct")
    var rect1 = Rectangle(5.0, 3.0)
    var rect2 = Rectangle(4.0, 4.0)  # Square

    print("Rectangle 1: 5x3")
    print("  Area:", rect1.area())
    print("  Perimeter:", rect1.perimeter())
    print("  Is square:", rect1.is_square())

    print("Rectangle 2: 4x4")
    print("  Area:", rect2.area())
    print("  Perimeter:", rect2.perimeter())
    print("  Is square:", rect2.is_square(), "\n")

    # Rectangle scaling
    print("Scaling rectangle 1 by factor 2:")
    rect1.scale(2.0)
    print("  New dimensions: 10x6")
    print("  New area:", rect1.area())
    print("  New perimeter:", rect1.perimeter(), "\n")

    # 4. Person struct usage
    print("4. Person Struct")
    var person1 = Person("Alice", 25, 165.5)
    var person2 = Person("Bob", 17, 180.0)

    print("Person 1:")
    print_person_info(person1)

    print("Person 2:")
    print_person_info(person2)

    print("After Bob's birthday:")
    person2.birthday()
    print_person_info(person2)

    # 5. Function overloading
    print("5. Function Overloading")
    print("Circle with radius 5:", calculate_area(5.0))
    print("Rectangle 4x6:", calculate_area(4.0, 6.0))
    print("Triangle with base 4, height 3:", calculate_triangle_area(4.0, 3.0), "\n")

    # 6. Functions working with structs
    print("6. Functions with Structs")
    var rect_a = Rectangle(6.0, 4.0)
    var rect_b = Rectangle(5.0, 5.0)
    print(compare_rectangles(rect_a, rect_b))

    var square = create_square(7.0)
    print("Created square with side 7:")
    print("  Area:", square.area())
    print("  Is square:", square.is_square(), "\n")

    print("=== Functions and Structs Examples Completed ===")