"""
Mojo SIMD Basics Example

This file demonstrates Single Instruction, Multiple Data (SIMD) operations in Mojo:
- SIMD types and vectorized operations
- Basic arithmetic with SIMD vectors
- Performance comparisons
- SIMD width and data types
"""

# 1. Basic SIMD operations
fn basic_simd_operations():
    """Demonstrate basic SIMD vector operations."""
    print("=== Basic SIMD Operations ===")

    # Create SIMD vectors of different sizes
    var vec4_int = SIMD[DType.int32, 4](1, 2, 3, 4)
    var vec8_float = SIMD[DType.float32, 8](1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)

    print("Int32 vector (size 4):", vec4_int)
    print("Float32 vector (size 8):", vec8_float)

    # Arithmetic operations (performed on all elements simultaneously)
    var doubled = vec4_int * 2
    var squared = vec8_float * vec8_float

    print("Original * 2:", doubled)
    print("Original squared:", squared)

    # Element-wise operations
    var added = vec4_int + SIMD[DType.int32, 4](10, 20, 30, 40)
    print("Element-wise addition:", added)

    # Reduction operations
    var sum_all = vec4_int.reduce_add()
    var max_val = vec8_float.reduce_max()
    var min_val = vec8_float.reduce_min()

    print("Sum of all elements (int):", sum_all)
    print("Max value (float):", max_val)
    print("Min value (float):", min_val, "\n")

# 2. SIMD width and data types
fn simd_types_and_widths():
    """Explore different SIMD data types and vector widths."""
    print("=== SIMD Types and Widths ===")

    # Different data types
    var int8_vec = SIMD[DType.int8, 16](1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
    var int16_vec = SIMD[DType.int16, 8](100, 200, 300, 400, 500, 600, 700, 800)
    var float64_vec = SIMD[DType.float64, 4](1.1, 2.2, 3.3, 4.4)

    print("Int8 vector (16 elements):", int8_vec)
    print("Int16 vector (8 elements):", int16_vec)
    print("Float64 vector (4 elements):", float64_vec)

    # Check SIMD width (number of elements)
    print("Int8 vector width:", len(int8_vec))
    print("Int16 vector width:", len(int16_vec))
    print("Float64 vector width:", len(float64_vec), "\n")

# 3. Vectorized math operations
fn vectorized_math():
    """Demonstrate vectorized mathematical operations."""
    print("=== Vectorized Math Operations ===")

    # Create input vectors
    var x = SIMD[DType.float32, 8](0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5)
    var y = SIMD[DType.float32, 8](1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)

    print("Input x:", x)
    print("Input y:", y)

    # Basic arithmetic
    var sum_xy = x + y
    var diff_xy = x - y
    var prod_xy = x * y
    var quot_xy = y / x  # Note: careful with division by zero

    print("x + y:", sum_xy)
    print("x - y:", diff_xy)
    print("x * y:", prod_xy)
    print("y / x:", quot_xy)

    # Mathematical functions (if available)
    # Note: Current Mojo version may have limited math functions
    # These would typically include sin, cos, exp, log, etc.

    print()

# 4. Masked operations
fn masked_operations():
    """Demonstrate masked SIMD operations."""
    print("=== Masked Operations ===")

    var data = SIMD[DType.int32, 8](1, 2, 3, 4, 5, 6, 7, 8)
    print("Original data:", data)

    # Create a mask (boolean vector) - using SIMD comparison
    # Note: Current Mojo version may have limited mask operations
    print("Mask operations require SIMD.gt() or similar functions")
    print("This demonstrates the concept of conditional vector operations", "\n")

# 5. Performance comparison (conceptual)
fn performance_comparison():
    """Conceptual performance comparison between scalar and SIMD operations."""
    print("=== Performance Comparison (Conceptual) ===")

    # Scalar operations (one at a time)
    print("Scalar operations:")
    var scalar_sum = 0
    for i in range(8):
        scalar_sum += i + 1
    print("Scalar sum (1+2+...+8):", scalar_sum)

    # SIMD operations (parallel)
    print("SIMD operations:")
    var vector = SIMD[DType.int32, 8](1, 2, 3, 4, 5, 6, 7, 8)
    var vector_sum = vector.reduce_add()
    print("SIMD sum (same values):", vector_sum)

    print("Both approaches give the same result:", scalar_sum == Int(vector_sum))
    print("SIMD can process multiple elements simultaneously for better performance", "\n")

# 6. Practical SIMD example: array operations
fn array_operations():
    """Demonstrate SIMD operations on arrays."""
    print("=== Array Operations with SIMD ===")

    # Create two arrays and print their contents
    print("Array 1: [1, 2, 3, 4, 5, 6, 7, 8]")
    print("Array 2: [2, 4, 6, 8, 10, 12, 14, 16]")

    # Convert to SIMD vectors for parallel operations
    var vec1 = SIMD[DType.int32, 8](1, 2, 3, 4, 5, 6, 7, 8)
    var vec2 = SIMD[DType.int32, 8](2, 4, 6, 8, 10, 12, 14, 16)

    # Perform vectorized operations
    var sum_vec = vec1 + vec2
    var prod_vec = vec1 * vec2

    print("Element-wise sum:", sum_vec)
    print("Element-wise product:", prod_vec)
    print("Total sum:", sum_vec.reduce_add())
    print("Total product:", prod_vec.reduce_add(), "\n")

fn main():
    print("=== Mojo SIMD Basics ===\n")

    basic_simd_operations()
    simd_types_and_widths()
    vectorized_math()
    masked_operations()
    performance_comparison()
    array_operations()

    print("=== SIMD Examples Completed ===")
    print("Note: SIMD provides significant performance improvements for")
    print("data-parallel operations by processing multiple elements simultaneously")
    print("Current Mojo version supports basic SIMD operations")
    print("Advanced SIMD features may be available in future versions")