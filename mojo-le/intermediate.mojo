fn main():
    var x = MyStruct(10)
    x.print()
    var result = add(5, 3)
    print("Add result:", result)
    try:
        divide(10, 0)
    except:
        print("Caught division by zero")

struct MyStruct:
    var value: Int

    fn __init__(out self, value: Int):
        self.value = value

    fn print(self):
        print("Value:", self.value)

fn add(a: Int, b: Int) -> Int:
    return a + b

fn divide(a: Int, b: Int) raises -> Int:
    if b == 0:
        raise "Division by zero"
    return a // b