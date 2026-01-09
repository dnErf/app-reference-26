"""
Mojo Core Fundamentals Example

This file demonstrates the fundamental building blocks of Mojo programming:
- Basic syntax and variable declarations
- Data types (Int, Float64, String, Bool)
- Control flow (if/else, loops)
- Basic operations and expressions
"""

fn main():
    print("=== Mojo Core Fundamentals ===\n")

    # 1. Variable declarations and basic types
    print("1. Variable Declarations and Types")

    # Integer types
    var age: Int = 25
    var count: Int = 0
    print("Age:", age, "Count:", count)

    # Floating point types
    var pi: Float64 = 3.14159
    var temperature: Float64 = 98.6
    print("Pi:", pi, "Temperature:", temperature)

    # String type
    var name: String = "Mojo"
    var greeting: String = "Hello, World!"
    print("Name:", name, "Greeting:", greeting)

    # Boolean type
    var is_active: Bool = True
    var is_complete: Bool = False
    print("Is Active:", is_active, "Is Complete:", is_complete, "\n")

    # 2. Basic operations
    print("2. Basic Operations")

    # Arithmetic operations
    var a: Int = 10
    var b: Int = 3
    print("a =", a, "b =", b)
    print("a + b =", a + b)
    print("a - b =", a - b)
    print("a * b =", a * b)
    print("a / b =", a / b)  # Integer division
    print("a % b =", a % b, "\n")

    # Floating point operations
    var x: Float64 = 10.5
    var y: Float64 = 3.2
    print("x =", x, "y =", y)
    print("x + y =", x + y)
    print("x - y =", x - y)
    print("x * y =", x * y)
    print("x / y =", x / y, "\n")

    # String operations
    var first_name: String = "John"
    var last_name: String = "Doe"
    var full_name: String = first_name + " " + last_name
    print("Full name:", full_name)
    print("Name length:", len(full_name), "\n")

    # 3. Control flow - if/else statements
    print("3. Control Flow - If/Else Statements")

    var score: Int = 85
    if score >= 90:
        print("Grade: A")
    elif score >= 80:
        print("Grade: B")
    elif score >= 70:
        print("Grade: C")
    elif score >= 60:
        print("Grade: D")
    else:
        print("Grade: F")

    # Boolean logic
    var is_student: Bool = True
    var has_passed: Bool = score >= 60

    if is_student and has_passed:
        print("Student has passed the course")
    elif is_student and not has_passed:
        print("Student needs to retake the course")
    else:
        print("Not a student or unknown status", "\n")

    # 4. Loops
    print("4. Loops")

    # For loop with range
    print("Counting from 1 to 5:")
    for i in range(1, 6):
        print("Count:", i)

    print("\nEven numbers from 2 to 10:")
    for i in range(2, 11, 2):
        print("Even:", i)

    # While loop
    print("\nWhile loop countdown:")
    var counter: Int = 5
    while counter > 0:
        print("Counter:", counter)
        counter -= 1

    print("Blast off!", "\n")

    # 5. Lists and basic collections
    print("5. Basic Collections")

    # Create a list of integers
    var numbers = List[Int]()
    numbers.append(1)
    numbers.append(2)
    numbers.append(3)
    numbers.append(4)
    numbers.append(5)

    print("Numbers list:")
    for num in numbers:
        print("  ", num)

    print("List size:", len(numbers))
    print("First element:", numbers[0])
    print("Last element:", numbers[4], "\n")

    # 6. Type conversion
    print("6. Type Conversion")

    var int_value: Int = 42
    var float_value: Float64 = 3.14
    var bool_value: Bool = True

    # Int to Float64
    var converted_float: Float64 = Float64(int_value)
    print("Int to Float64:", int_value, "->", converted_float)

    # Float64 to Int (truncates)
    var converted_int: Int = Int(float_value)
    print("Float64 to Int:", float_value, "->", converted_int)

    # Bool to Int
    var bool_as_int: Int = Int(bool_value)
    print("Bool to Int:", bool_value, "->", bool_as_int, "\n")

    print("=== Core Fundamentals Examples Completed ===")