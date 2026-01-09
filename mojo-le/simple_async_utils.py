"""
Simple async utility functions for Mojo uvloop examples.
"""

import asyncio

async def simple_async_task(name, delay):
    """A simple async task that simulates work with a delay"""
    print("Starting task:", name)
    await asyncio.sleep(delay)
    print("Completed task:", name)
    return name + " done"

async def compute_async(value):
    """Async function that performs computation"""
    result = value * value
    await asyncio.sleep(0.1)
    return result

async def concurrent_example():
    """Demonstrate running multiple async tasks concurrently"""
    print("Starting concurrent tasks...")

    task1 = simple_async_task("Task A", 0.5)
    task2 = simple_async_task("Task B", 0.3)
    task3 = compute_async(5)

    results = await asyncio.gather(task1, task2, task3)

    print("All tasks completed:")
    for i, result in enumerate(results, 1):
        print("Result", i, ":", result)

def run_concurrent_example():
    """Run the concurrent example"""
    asyncio.run(concurrent_example())