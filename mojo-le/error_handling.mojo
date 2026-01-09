"""
Mojo Error Handling Example

This file demonstrates error handling in Mojo:
- Functions that can raise errors (raises keyword)
- Try/except blocks for error handling
- Error propagation
- Safe error handling patterns
"""

# 1. Basic error handling with raises
fn divide_numbers(a: Float64, b: Float64) raises -> Float64:
    """Divide two numbers, raises error if dividing by zero."""
    if b == 0.0:
        raise Error("Division by zero is not allowed")
    return a / b

fn safe_divide(a: Float64, b: Float64) -> Float64:
    """Safe division that returns 0.0 on error instead of raising."""
    try:
        return divide_numbers(a, b)
    except:
        print("Warning: Division by zero, returning 0.0")
        return 0.0

# 2. File operations that can raise errors
fn read_file_content(filename: String) raises -> String:
    """Read content from a file, raises error if file doesn't exist."""
    # Note: In current Mojo version, file operations are limited
    # This is a conceptual example
    if filename == "nonexistent.txt":
        raise Error("File '" + filename + "' not found")
    return "Content of " + filename

# 3. Custom error handling with validation
fn validate_age(age: Int) raises:
    """Validate that age is reasonable, raises error if invalid."""
    if age < 0:
        raise Error("Age cannot be negative")
    if age > 150:
        raise Error("Age cannot be greater than 150")

fn create_person(name: String, age: Int) raises -> String:
    """Create a person record with validation."""
    if name == "":
        raise Error("Name cannot be empty")

    validate_age(age)

    return "Person created: " + name + ", age " + String(age)

# 4. Multiple error handling patterns
fn process_data(data: String) raises -> String:
    """Process data with multiple potential error points."""
    if data == "":
        raise Error("Data cannot be empty")

    if len(data) < 3:
        raise Error("Data must be at least 3 characters long")

    # Simulate processing
    return "Processed: " + data.upper()

fn safe_process_data(data: String) -> String:
    """Safely process data with comprehensive error handling."""
    try:
        return process_data(data)
    except e:
        return "Error processing data: " + String(e)

# 5. Error propagation in function chains
fn step1(value: Int) raises -> Int:
    """First processing step."""
    if value < 0:
        raise Error("Value must be non-negative in step 1")
    return value * 2

fn step2(value: Int) raises -> Int:
    """Second processing step."""
    if value > 100:
        raise Error("Value too large for step 2")
    return value + 10

fn step3(value: Int) raises -> String:
    """Third processing step."""
    if value % 2 != 0:
        raise Error("Value must be even in step 3")
    return "Final result: " + String(value)

fn process_pipeline(input: Int) raises -> String:
    """Complete processing pipeline that propagates errors."""
    var result1 = step1(input)
    var result2 = step2(result1)
    var result3 = step3(result2)
    return result3

# 6. Complex error handling with recovery
fn robust_division(a: Float64, b: Float64) -> String:
    """Robust division with detailed error reporting."""
    try:
        var result = divide_numbers(a, b)
        return "Success: " + String(a) + " / " + String(b) + " = " + String(result)
    except e:
        return "Error: " + String(e) + " (a=" + String(a) + ", b=" + String(b) + ")"

fn main():
    print("=== Mojo Error Handling ===\n")

    # 1. Basic error handling
    print("1. Basic Error Handling")
    print("Safe divide 10/2:", safe_divide(10.0, 2.0))
    print("Safe divide 10/0:", safe_divide(10.0, 0.0))

    # Direct division with try/catch
    try:
        var result = divide_numbers(15.0, 3.0)
        print("Direct divide 15/3:", result)
    except e:
        print("Error in direct division:", e)

    try:
        var result = divide_numbers(10.0, 0.0)
        print("This won't print")
    except e:
        print("Caught division by zero:", e)
    print()

    # 2. File operation simulation
    print("2. File Operation Simulation")
    try:
        var content = read_file_content("data.txt")
        print("File content:", content)
    except e:
        print("File error:", e)

    try:
        var content = read_file_content("nonexistent.txt")
        print("This won't print")
    except e:
        print("File error:", e)
    print()

    # 3. Validation and custom errors
    print("3. Validation and Custom Errors")
    var valid_names = List[String]()
    valid_names.append("Alice")
    valid_names.append("")
    valid_names.append("Bob")

    var valid_ages = List[Int]()
    valid_ages.append(25)
    valid_ages.append(-5)
    valid_ages.append(200)

    for i in range(len(valid_names)):
        try:
            var person = create_person(valid_names[i], valid_ages[i])
            print("✓", person)
        except e:
            print("✗ Error creating person:", e)
    print()

    # 4. Data processing with error handling
    print("4. Data Processing")
    var test_data = List[String]()
    test_data.append("hello")
    test_data.append("")
    test_data.append("hi")

    for data in test_data:
        var result = safe_process_data(data)
        print("Input: '" + data + "' -> " + result)
    print()

    # 5. Error propagation in pipelines
    print("5. Processing Pipeline")
    var test_inputs = List[Int]()
    test_inputs.append(5)   # Should work: 5 -> 10 -> 20 -> "Final result: 20"
    test_inputs.append(-1)  # Should fail: negative value
    test_inputs.append(25)  # Should fail: too large after step 1 (50 > 100)
    test_inputs.append(6)   # Should fail: odd number in step 3

    for input_val in test_inputs:
        try:
            var result = process_pipeline(input_val)
            print("✓ Pipeline success for", input_val, ":", result)
        except e:
            print("✗ Pipeline failed for", input_val, ":", e)
    print()

    # 6. Robust error handling
    print("6. Robust Error Handling")
    var division_tests = List[Float64]()
    division_tests.append(10.0)
    division_tests.append(5.0)
    division_tests.append(0.0)
    division_tests.append(8.0)

    for i in range(0, len(division_tests), 2):
        var a = division_tests[i]
        var b = division_tests[i + 1]
        print(robust_division(a, b))
    print()

    print("=== Error Handling Examples Completed ===")
    print("Note: Current Mojo version has limited error handling features")
    print("Advanced error types and exception hierarchies require future versions")