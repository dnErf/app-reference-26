# Intermediate SIMD Example
# This example demonstrates basic SIMD types, operations, and vectorized math for performance gains.
# SIMD (Single Instruction, Multiple Data) allows processing multiple values in parallel.

from math import sqrt, sin

# Basic SIMD creation and operations
fn basic_simd():
    print("=== Basic SIMD Types and Operations ===")

    # Create SIMD vectors
    var vec1 = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
    var vec2 = SIMD[DType.float32, 4](5.0, 6.0, 7.0, 8.0)

    print("vec1:", vec1)
    print("vec2:", vec2)

    # Element-wise operations
    var sum_vec = vec1 + vec2
    var diff_vec = vec2 - vec1
    var prod_vec = vec1 * vec2
    var div_vec = vec2 / vec1

    print("Sum:", sum_vec)
    print("Difference:", diff_vec)
    print("Product:", prod_vec)
    print("Division:", div_vec)

    # Scalar operations
    var scaled = vec1 * 2.0
    print("Scaled by 2:", scaled)

# Vectorized math functions
fn vectorized_math():
    print("\n=== Vectorized Math Functions ===")

    var angles = SIMD[DType.float32, 4](0.0, 1.57, 3.14, 4.71)  # 0, pi/2, pi, 3pi/2

    var sines = sin(angles)
    var sqrts = sqrt(SIMD[DType.float32, 4](1.0, 4.0, 9.0, 16.0))

    print("Angles:", angles)
    print("Sines:", sines)
    print("Square roots:", sqrts)

# Performance demonstration: vectorized operations
fn performance_demo():
    print("\n=== Performance Demonstration ===")

    # Vectorized sum of squares
    var vec = SIMD[DType.float32, 8](1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
    var squared = vec * vec
    var sum_sq = squared[0] + squared[1] + squared[2] + squared[3] + squared[4] + squared[5] + squared[6] + squared[7]

    print("Vector:", vec)
    print("Squared:", squared)
    print("Sum of squares:", sum_sq)

    print("Note: SIMD processes all elements in parallel, unlike scalar loops.")

# Different data types
fn different_dtypes():
    print("\n=== Different Data Types ===")

    # Integer SIMD
    var int_vec = SIMD[DType.int32, 4](1, 2, 3, 4)
    print("Int32 SIMD:", int_vec)
    print("Int operations:", int_vec * 2)

    # Float64 SIMD
    var double_vec = SIMD[DType.float64, 2](1.5, 2.5)
    print("Float64 SIMD:", double_vec)

# Main function
fn main():
    basic_simd()
    vectorized_math()
    performance_demo()
    different_dtypes()

    print("\n=== Summary ===")
    print("SIMD enables parallel processing of multiple data elements.")
    print("Benefits: Performance gains on modern CPUs with SIMD instructions.")
    print("Use cases: Numerical computations, image processing, scientific simulations.")