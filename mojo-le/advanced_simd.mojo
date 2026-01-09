# Advanced SIMD Example
# This example shows SIMD with custom structs, masks, and compile-time parameterization for optimized algorithms.

from math import sqrt

# Custom struct containing SIMD vectors
struct Vector3D:
    var x: SIMD[DType.float32, 4]
    var y: SIMD[DType.float32, 4]
    var z: SIMD[DType.float32, 4]

    fn __init__(out self):
        self.x = SIMD[DType.float32, 4](0.0)
        self.y = SIMD[DType.float32, 4](0.0)
        self.z = SIMD[DType.float32, 4](0.0)

    fn __init__(out self, x: SIMD[DType.float32, 4], y: SIMD[DType.float32, 4], z: SIMD[DType.float32, 4]):
        self.x = x
        self.y = y
        self.z = z

    fn magnitude_squared(self) -> SIMD[DType.float32, 4]:
        return self.x * self.x + self.y * self.y + self.z * self.z

    fn magnitude(self) -> SIMD[DType.float32, 4]:
        return sqrt(self.magnitude_squared())

    fn __add__(self, other: Self) -> Self:
        return Self(self.x + other.x, self.y + other.y, self.z + other.z)

# SIMD masks for conditional operations
fn masked_operations():
    print("=== SIMD Masks and Conditional Operations ===")

    var vec = SIMD[DType.float32, 4](1.0, -2.0, 3.0, -4.0)
    print("Vector:", vec)

    # For demonstration, manual conditional
    var abs_vec = SIMD[DType.float32, 4](0.0)
    for i in range(4):
        if vec[i] >= 0.0:
            abs_vec[i] = vec[i]
        else:
            abs_vec[i] = -vec[i]

    print("Absolute values (manual):", abs_vec)

# Compile-time parameterized SIMD functions
fn dot_product[dt: DType, size: Int](a: SIMD[dt, size], b: SIMD[dt, size]) -> SIMD[dt, 1]:
    return (a * b).reduce_add()

fn vector_sum[dt: DType, size: Int](vec: SIMD[dt, size]) -> SIMD[dt, 1]:
    return vec.reduce_add()

fn normalize[dt: DType, size: Int](vec: SIMD[dt, size]) -> SIMD[dt, size]:
    var mag_sq = (vec * vec).reduce_add()
    var mag = sqrt(mag_sq)
    return vec / mag

# Optimized algorithm: vectorized filtering
fn filter_values[dt: DType, size: Int](vec: SIMD[dt, size], threshold: SIMD[dt, 1]) -> SIMD[dt, size]:
    var result = SIMD[dt, size](0.0)
    for i in range(size):
        if vec[i] > threshold[0]:
            result[i] = vec[i]
    return result

# Advanced: SIMD with compile-time loops
fn polynomial_eval[dt: DType, size: Int, degree: Int](x: SIMD[dt, size], coeffs: SIMD[dt, degree + 1]) -> SIMD[dt, size]:
    var result = SIMD[dt, size](coeffs[degree])
    @parameter
    for i in range(degree):
        result = result * x + coeffs[degree - 1 - i]
    return result

# Main demonstration
fn main():
    print("=== Custom Struct with SIMD ===")
    var v1 = Vector3D(
        SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0),
        SIMD[DType.float32, 4](0.0, 1.0, 0.0, 1.0),
        SIMD[DType.float32, 4](0.0, 0.0, 1.0, 1.0)
    )
    var v2 = Vector3D(
        SIMD[DType.float32, 4](1.0, 1.0, 1.0, 1.0),
        SIMD[DType.float32, 4](0.0, 0.0, 0.0, 0.0),
        SIMD[DType.float32, 4](0.0, 0.0, 0.0, 0.0)
    )

    var sum_vec = v1 + v2
    print("V1 X:", v1.x, "Y:", v1.y, "Z:", v1.z)
    print("Sum magnitudes:", sum_vec.magnitude())

    masked_operations()

    print("\n=== Compile-time Parameterized Functions ===")
    var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
    var b = SIMD[DType.float32, 4](5.0, 6.0, 7.0, 8.0)
    var dot = dot_product(a, b)
    print("Dot product:", dot)

    var norm_a = normalize(a)
    print("Normalized A:", norm_a)
    var mag_check = sqrt((norm_a * norm_a).reduce_add())
    print("Magnitude check:", mag_check)

    print("\n=== Optimized Filtering ===")
    var data = SIMD[DType.float32, 8](1.0, 5.0, 2.0, 8.0, 3.0, 1.0, 9.0, 4.0)
    var filtered = filter_values(data, SIMD[DType.float32, 1](3.0))
    print("Original:", data)
    print("Filtered (>3):", filtered)

    print("\n=== Polynomial Evaluation ===")
    var x_vals = SIMD[DType.float32, 4](0.0, 1.0, 2.0, 3.0)
    # Coefficients for x^3 + 2x^2 + x + 1 (example)
    var coeffs = SIMD[DType.float32, 4](1.0, 1.0, 2.0, 1.0)
    var poly_result = polynomial_eval[DType.float32, 4, 3](x_vals, coeffs)
    print("x values:", x_vals)
    print("Polynomial result:", poly_result)

    print("\n=== Summary ===")
    print("Advanced SIMD: Custom structs, masks, parameterization enable complex optimized algorithms.")
    print("Benefits: Compile-time optimization, conditional processing, vectorized computations.")