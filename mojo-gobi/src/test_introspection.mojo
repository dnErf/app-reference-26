from pl_grizzly_interpreter import PLGrizzlyInterpreter, PLValue
from blob_storage import BlobStorage

fn main() raises:
    # Create a simple storage for testing
    var storage = BlobStorage("test.db")
    var interpreter = PLGrizzlyInterpreter(storage)

    # Test SHOW TABLES
    print("Testing SHOW TABLES...")
    var result = interpreter.evaluate("(SHOW TABLES)", interpreter.global_env)
    if result.is_error():
        print("Error:", result.__str__())
    else:
        print("Success:", result.__str__())

    # Test SHOW SCHEMA
    print("Testing SHOW SCHEMA...")
    result = interpreter.evaluate("(SHOW SCHEMA)", interpreter.global_env)
    if result.is_error():
        print("Error:", result.__str__())
    else:
        print("Success:", result.__str__())