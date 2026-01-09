"""
Intermediate Async Programming Example in Mojo

This example demonstrates basic asynchronous programming concepts in Mojo
using Python interop with asyncio and uvloop for real async functionality.

Key concepts:
- async/await syntax for non-blocking operations
- Coroutines and concurrent execution
- Task management and scheduling
- Python interop for async capabilities
"""

from python import Python

# Wrapper functions to call Python async functions from Mojo
fn run_concurrent_example() raises:
    """Run concurrent async example using Python interop."""
    print("Running concurrent async example with uvloop...")
    var async_utils = Python.import_module("async_utils")
    async_utils.run_concurrent_example()
    print("Concurrent example completed!")

fn run_multiple_awaits_example() raises:
    """Run multiple awaits example using Python interop."""
    print("Running multiple awaits example with uvloop...")
    var async_utils = Python.import_module("async_utils")
    async_utils.run_multiple_awaits_example()
    print("Multiple awaits example completed!")

fn run_error_handling_example() raises:
    """Run error handling example using Python interop."""
    print("Running error handling example with uvloop...")
    var async_utils = Python.import_module("async_utils")
    async_utils.run_error_handling_example()
    print("Error handling example completed!")

# Conceptual async function (for comparison)
fn simple_async_task_concept(name: String, delay: Float64) -> String:
    """
    Conceptual async task that simulates work with a delay.
    In real async code: async fn simple_async_task(name: String, delay: Float64) -> String
    """
    print("Starting task:", name)
    # sleep(delay)  # Would simulate async delay
    print("Completed task:", name)
    return name + " done"

# Conceptual async computation
fn compute_async_concept(value: Int) -> Int:
    """
    Conceptual async computation.
    In real code: async fn compute_async(value: Int) -> Int
    """
    var result = value * value
    # sleep(0.1)  # Small async delay
    return result

# Concurrent execution concept (for comparison)
fn concurrent_example_concept():
    """
    Demonstrate concurrent execution concepts.
    In real async code, tasks would run concurrently.
    """
    print("Starting concurrent tasks...")

    # Create conceptual async tasks
    var task1 = simple_async_task_concept("Task A", 0.5)
    var task2 = simple_async_task_concept("Task B", 0.3)
    var task3 = compute_async_concept(5)

    # In real async: await task1, task2, task3 would allow concurrent execution
    print("In async code, tasks would run concurrently here")
    print("Result 1:", task1)
    print("Result 2:", task2)
    print("Result 3:", task3)

# Sequential execution for comparison
fn sequential_example():
    """Sequential execution for comparison"""
    print("Starting sequential tasks...")

    # Sequential execution (blocking)
    var result1 = simple_async_task_concept("Seq A", 0.5)
    var result2 = simple_async_task_concept("Seq B", 0.3)
    var result3 = compute_async_concept(5)

    print("Sequential tasks completed")

# Multiple awaits concept (for comparison)
fn multiple_awaits_example_concept():
    """
    Example of awaiting multiple tasks in sequence.
    In real async: async fn multiple_awaits_example()
    """
    print("Multiple awaits example:")

    # First batch
    var batch1_task1 = compute_async_concept(2)
    var batch1_task2 = compute_async_concept(3)
    # In async: var sum1 = (await batch1_task1) + (await batch1_task2)
    var sum1 = batch1_task1 + batch1_task2
    print("Batch 1 sum:", sum1)

    # Second batch
    var batch2_task1 = compute_async_concept(4)
    var batch2_task2 = compute_async_concept(5)
    var sum2 = batch2_task1 + batch2_task2
    print("Batch 2 sum:", sum2)

    print("Total sum:", sum1 + sum2)

# Error handling concept (for comparison)
fn async_with_error_concept(value: Int) -> Int:
    """
    Conceptual async function with error handling.
    In real async: async fn async_with_error(value: Int) -> Result[Int, String]
    """
    if value < 0:
        print("Error: negative value not allowed")
        return 0
    return value * 2

fn error_handling_example_concept():
    """Demonstrate error handling concepts"""
    print("Error handling example:")

    var result1 = async_with_error_concept(5)
    print("Result 1:", result1)

    var result2 = async_with_error_concept(-1)
    print("Result 2:", result2)

# Async programming concepts explanation
fn explain_async_concepts():
    """
    Explain key async programming concepts:
    - async/await: Non-blocking syntax
    - Coroutines: Functions that can be paused/resumed
    - Tasks: Units of concurrent work
    - Event loop: Scheduler for async tasks
    """
    print("Async Programming Concepts:")
    print("- async fn: Marks function as asynchronous")
    print("- await: Pauses execution until async operation completes")
    print("- Coroutines: Functions that can yield control")
    print("- Tasks: Concurrent units of work")
    print("- Event Loop: Manages task scheduling")
    print("- uvloop: High-performance event loop for asyncio")

# Benefits of async programming
fn async_benefits():
    """
    Benefits of asynchronous programming:
    - Non-blocking I/O operations
    - Better resource utilization
    - Improved responsiveness
    - Scalable concurrent applications
    """
    print("Benefits of Async Programming:")
    print("- Non-blocking: Other work can proceed during I/O")
    print("- Scalable: Handle many concurrent connections")
    print("- Efficient: Better CPU utilization")
    print("- Responsive: UI/main thread stays responsive")
    print("- uvloop: Faster event loop for better performance")

fn main() raises:
    print("=== Intermediate Async Programming Example ===\n")

    print("--- Real Async Examples with uvloop ---")
    run_concurrent_example()
    print()
    run_multiple_awaits_example()
    print()
    run_error_handling_example()

    print("\n--- Conceptual Examples (for comparison) ---")
    print("--- Concurrent Example Concept ---")
    concurrent_example_concept()

    print("\n--- Sequential Example ---")
    sequential_example()

    print("\n--- Multiple Awaits Example Concept ---")
    multiple_awaits_example_concept()

    print("\n--- Error Handling Example Concept ---")
    error_handling_example_concept()

    print("\n--- Async Concepts ---")
    explain_async_concepts()

    print("\n--- Async Benefits ---")
    async_benefits()

    print("\nAsync programming demonstrated with real uvloop interop and conceptual examples!")
    print("Note: Python interop enables real async functionality in Mojo")