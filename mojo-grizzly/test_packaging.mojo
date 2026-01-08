# Test Packaging
from packaging import init, package_init, add_python_dep, package_build

fn main():
    init()
    package_init("mojo-grizzly", "1.0.0")
    add_python_dep("numpy")
    add_python_dep("pandas")
    package_build()
    print("Packaging test completed!")