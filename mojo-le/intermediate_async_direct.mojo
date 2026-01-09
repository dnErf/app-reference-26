"""
Pure Asyncio Intermediate Async Example in Mojo

This example demonstrates basic asynchronous programming concepts in Mojo
using pure asyncio (no uvloop dependency).

Key concepts:
- Pure asyncio integration
- async/await syntax for non-blocking operations
- Coroutines and concurrent execution
- Task management and scheduling
"""

from python import Python

fn run_concurrent_example_direct() raises:
    """Run concurrent async example using pure asyncio (no uvloop)."""
    print("=== Pure Asyncio Concurrent Example ===")

    # Import asyncio directly - no uvloop needed!
    var asyncio = Python.import_module("asyncio")
    print("Using pure asyncio event loop")

    # Execute async code - Python.evaluate is still needed for async syntax
    Python.evaluate("""
exec('''
import asyncio

async def concurrent_example():
    print("Starting concurrent tasks...")
    task1 = asyncio.create_task(asyncio.sleep(0.5))
    task2 = asyncio.create_task(asyncio.sleep(0.3))
    await asyncio.gather(task1, task2)
    print("All tasks completed concurrently!")

asyncio.run(concurrent_example())
''')
""")

    print("Pure asyncio concurrent example completed!")

fn sync_task_a() raises -> String:
    """Synchronous task A that simulates async behavior."""
    print("Starting task: Task A")
    Python.import_module("time").sleep(0.5)
    print("Completed task: Task A")
    return "Task A done"

fn sync_task_b() raises -> String:
    """Synchronous task B that simulates async behavior."""
    print("Starting task: Task B")
    Python.import_module("time").sleep(0.3)
    print("Completed task: Task B")
    return "Task B done"

fn sync_compute() raises -> Int:
    """Synchronous computation."""
    Python.import_module("time").sleep(0.1)
    return 5 * 5

fn run_multiple_awaits_example_direct() raises:
    """Run multiple awaits example using pure asyncio."""
    print("=== Pure Asyncio Multiple Awaits Example ===")

    var asyncio = Python.import_module("asyncio")

    Python.evaluate("""
exec('''
async def multiple_awaits_example():
    print("Multiple awaits example:")
    import asyncio
    task1 = asyncio.create_task(asyncio.sleep(0.1))
    task2 = asyncio.create_task(asyncio.sleep(0.2))
    await task1
    await task2
    print("All awaits completed!")

asyncio.run(multiple_awaits_example())
''')
""")

    print("Pure asyncio multiple awaits example completed!")

fn run_error_handling_example_direct() raises:
    """Run error handling example using pure asyncio."""
    print("=== Pure Asyncio Error Handling Example ===")

    var asyncio = Python.import_module("asyncio")

    Python.evaluate("""
exec('''
async def error_handling_example():
    print("Error handling example:")
    import asyncio
    try:
        await asyncio.sleep(0.1)
        raise ValueError("test error")
    except ValueError as e:
        print("Caught error:", e)

asyncio.run(error_handling_example())
''')
""")

    print("Pure asyncio error handling example completed!")

# Conceptual examples for comparison (same as before)
fn simple_async_task_concept(name: String, delay: Float64) -> String:
    """Conceptual async task for comparison."""
    print("Starting task:", name)
    # sleep(delay)  # Would simulate async delay
    print("Completed task:", name)
    return name + " done"

fn compute_async_concept(value: Int) -> Int:
    """Conceptual async computation."""
    var result = value * value
    # sleep(0.1)  # Small async delay
    return result

fn concurrent_example_concept():
    """Concurrent execution concept for comparison."""
    print("Starting concurrent tasks...")
    var task1 = simple_async_task_concept("Task A", 0.5)
    var task2 = simple_async_task_concept("Task B", 0.3)
    var task3 = compute_async_concept(5)
    print("Result 1:", task1)
    print("Result 2:", task2)
    print("Result 3:", task3)

fn main() raises:
    print("=== Pure Asyncio Intermediate Async Example ===\n")

    print("\n--- Real Async Examples with Pure Asyncio ---")
    run_concurrent_example_direct()
    print()
    run_multiple_awaits_example_direct()
    print()
    run_error_handling_example_direct()

    print("\n--- Conceptual Examples (for comparison) ---")
    print("--- Concurrent Example Concept ---")
    concurrent_example_concept()

    print("\nPure asyncio async concepts demonstrated with real functionality!")