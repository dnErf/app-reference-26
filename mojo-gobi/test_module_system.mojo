#!/usr/bin/env mojo

from blob_storage import BlobStorage
from pl_grizzly_interpreter import PLGrizzlyInterpreter

fn main() raises:
    print("Testing PL-GRIZZLY Module System")
    print("=================================")

    # Initialize storage and interpreter
    var storage = BlobStorage(".")
    var interpreter = PLGrizzlyInterpreter(storage)

    # Test CREATE MODULE
    print("\n1. Testing CREATE MODULE:")
    var module_code = "CREATE MODULE math { fn add(a, b) { a + b } }"
    print("Code:", module_code)

    try:
        var result = interpreter.interpret(module_code)
        print("Result:", result.type, "-", result.value)
    except e:
        print("Error:", e)

    # Test IMPORT
    print("\n2. Testing IMPORT:")
    var import_code = "IMPORT math.add"
    print("Code:", import_code)

    try:
        result = interpreter.interpret(import_code)
        print("Result:", result.type, "-", result.value)
    except e:
        print("Error:", e)

    # Test function call
    print("\n3. Testing function call:")
    var call_code = "add(5, 3)"
    print("Code:", call_code)

    try:
        result = interpreter.interpret(call_code)
        print("Result:", result.type, "-", result.value)
    except e:
        print("Error:", e)

    print("\nModule system test completed!")