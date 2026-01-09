struct StringWrapper:
    var data: String

    fn __init__(out self, data: String):
        self.data = data

    fn print(self):
        print(self.data)

struct IntWrapper:
    var value: Int

    fn __init__(out self, value: Int):
        self.value = value

    fn print(self):
        print("Int:", self.value)

async fn async_task():
    print("Running async task")

fn main():
    var str_wrapper = StringWrapper("Hello Mojo")
    var int_wrapper = IntWrapper(42)

    str_wrapper.print()
    int_wrapper.print()

    await async_task()