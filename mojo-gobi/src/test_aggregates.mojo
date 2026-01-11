#!/usr/bin/env mojo

from pl_grizzly_interpreter import PLGrizzlyInterpreter
from blob_storage import BlobStorage

fn main() raises:
    print("Testing PL-GRIZZLY aggregate functions")

    # Initialize storage and interpreter
    var storage = BlobStorage(".")
    var interpreter = PLGrizzlyInterpreter(storage)

    # Test basic evaluation
    print("Testing basic evaluation...")
    var result = interpreter.evaluate("(+ 1 2)", interpreter.global_env)
    print("1 + 2 =", result.__str__())

    # Test SELECT parsing (this will test if our parser changes work)
    print("Testing SELECT with aggregates parsing...")
    var select_result = interpreter.evaluate("(SELECT SUM(amount) FROM test_table)", interpreter.global_env)
    print("SELECT result:", select_result.__str__())

    print("Basic aggregate function test completed!")