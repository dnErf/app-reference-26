# In-depth Mojo Parameters Example
# Based on https://docs.modular.com/mojo/manual/parameters/
# This example demonstrates compile-time parameterization in Mojo

from math import sqrt

# Parameterized function: repeat a message a compile-time constant number of times
fn repeat[count: Int, MsgType: Stringable](msg: MsgType):
    @parameter
    for i in range(count):
        print(String(msg))

# Parameterized struct: a simple parameterized struct
struct Pair:
    var first: Int
    var second: Int

    fn __init__(out self, first: Int, second: Int):
        self.first = first
        self.second = second

    fn sum(self) -> Int:
        return self.first + self.second

# Parametric comptime value
comptime AddOne[a: Int]: Int = a + 1

# Parameterized comptime value
comptime TwoOfAKind[dt: DType] = SIMD[dt, 2]

# Function using parametric comptime
fn rsqrt[dt: DType](x: Scalar[dt]) -> Scalar[dt]:
    return 1 / sqrt(x)

# Struct with parameters
struct MyComplicatedType[a: Int = 7, /, b: Int = 8, *, c: Int, d: Int = 9]:
    pass

# Infer-only parameters
fn dependent_type[dtype: DType, //, value: Scalar[dtype]]():
    print("Value: ", value)
    print("Value is floating-point: ", dtype.is_floating_point())

# Variadic parameters
fn sum_params[*values: Int]() -> Int:
    comptime list = VariadicList(values)
    var sum = 0
    for v in list:
        sum += v
    return sum

# Main function to demonstrate
fn main() raises:
    print("=== Parameterized Function ===")
    repeat[3]("Hello")

    print("\n=== Parameterized Struct ===")
    var pair = Pair(1, 2)
    print("Pair sum:", pair.sum())

    print("\n=== Parametric Comptime ===")
    comptime nine = AddOne[8]
    print("Nine:", nine)

    print("\n=== Parameterized Comptime Value ===")
    var floats = TwoOfAKind[DType.float32](1.0, 2.0)
    print("Floats:", floats)

    print("\n=== Parameter Inference ===")
    var v = Scalar[DType.float16](33.0)
    print("RSqrt result:", rsqrt(v))

    print("\n=== Infer-only Parameters ===")
    dependent_type[Float64(2.2)]()

    print("\n=== Variadic Parameters ===")
    print("Sum:", sum_params[1, 2, 3, 4, 5]())