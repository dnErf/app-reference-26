from python import Python

fn test_uvloop_direct_import() raises:
    """Test importing uvloop directly in Mojo"""
    print("Testing direct uvloop import in Mojo...")
    var uvloop = Python.import_module("uvloop")
    print("uvloop imported successfully!")
    print("uvloop version:", uvloop.__version__)

    # Try to set event loop policy
    var asyncio = Python.import_module("asyncio")
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
    print("Event loop policy set!")

fn main() raises:
    test_uvloop_direct_import()