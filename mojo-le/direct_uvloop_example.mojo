from python import Python

fn run_async_with_direct_uvloop() raises:
    """Run async operations using uvloop imported directly in Mojo."""
    print("Running async with direct uvloop import...")

    # Import required modules directly
    var asyncio = Python.import_module("asyncio")
    var uvloop = Python.import_module("uvloop")

    # Set uvloop as event loop policy
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
    print("uvloop event loop policy set")

    # Try to call a simple uvloop function
    print("uvloop version:", uvloop.__version__)

    # Try to create a simple async operation
    var loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    print("Created uvloop-based event loop")

    # Simple test
    var result = loop.run_until_complete(asyncio.sleep(0.1))
    print("Simple async operation completed")

fn main() raises:
    run_async_with_direct_uvloop()