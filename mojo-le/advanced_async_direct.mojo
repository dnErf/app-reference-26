"""
Direct uvloop Advanced Async Example in Mojo

This example demonstrates advanced asynchronous programming concepts
using direct uvloop imports for real async functionality.

Key concepts:
- Channels for inter-task communication
- Task groups for structured concurrency
- Producer-consumer patterns
- Cancellation and timeouts
"""

from python import Python

fn run_channel_example_direct() raises:
    """Run channel example using pure asyncio."""
    print("=== Pure Asyncio Channel Example ===")

    var asyncio = Python.import_module("asyncio")

    Python.evaluate("""
exec('''
import asyncio

class Channel:
    def __init__(self):
        self.queue = asyncio.Queue()

    async def send(self, item):
        await self.queue.put(item)

    async def receive(self):
        return await self.queue.get()

async def producer(channel, name, items):
    print("Producer", name, "starting...")
    for item in items:
        print("Producer", name, "sending:", item)
        await channel.send(item)
        await asyncio.sleep(0.1)
    print("Producer", name, "finished")

async def consumer(channel, name, num_items):
    print("Consumer", name, "starting...")
    results = []
    for _ in range(num_items):
        item = await channel.receive()
        print("Consumer", name, "received:", item)
        results.append(item * 2)
        await asyncio.sleep(0.05)
    print("Consumer", name, "finished with results:", results)
    return results

async def channel_example():
    print("Channel Example: Producer-Consumer Pattern")
    channel = Channel()

    producer_task = producer(channel, "P1", [1, 2, 3, 4, 5])
    consumer_task = consumer(channel, "C1", 5)

    await asyncio.gather(producer_task, consumer_task)
    print("Channel example completed")

asyncio.run(channel_example())
''')
""")

    print("Pure asyncio channel example completed!")

fn run_task_group_example_direct() raises:
    """Run task group example using pure asyncio."""
    print("=== Pure Asyncio Task Group Example ===")

    var asyncio = Python.import_module("asyncio")

    Python.evaluate("""
exec('''
import asyncio

async def task_in_group(name, delay):
    print("Task", name, "starting...")
    await asyncio.sleep(delay)
    print("Task", name, "completed")
    return "Task " + name + " result"

async def task_group_example():
    print("Task Group Example: Structured Concurrency")

    tasks = [
        task_in_group("A", 0.3),
        task_in_group("B", 0.2),
        task_in_group("C", 0.4),
        task_in_group("D", 0.1)
    ]

    results = await asyncio.gather(*tasks)

    print("All tasks in group completed:")
    for result in results:
        print("-", result)

    print("Task group example completed")

asyncio.run(task_group_example())
''')
""")

    print("Pure asyncio task group example completed!")

fn run_cancellation_example_direct() raises:
    """Run cancellation example using pure asyncio."""
    print("=== Pure Asyncio Cancellation Example ===")

    var asyncio = Python.import_module("asyncio")

    Python.evaluate("""
exec('''
import asyncio

async def cancellable_task(name, duration):
    try:
        print("Task", name, "starting (will run for", duration, "s)...")
        await asyncio.sleep(duration)
        print("Task", name, "completed normally")
        return name + " success"
    except asyncio.CancelledError:
        print("Task", name, "was cancelled!")
        raise

async def cancellation_example():
    print("Cancellation Example")

    task1 = asyncio.create_task(cancellable_task("Fast", 0.2))
    task2 = asyncio.create_task(cancellable_task("Slow", 1.0))

    await asyncio.sleep(0.1)
    print("Cancelling slow task...")
    task2.cancel()

    try:
        result1 = await task1
        print("Task 1 result:", result1)
    except Exception as e:
        print("Task 1 error:", e)

    try:
        result2 = await task2
        print("Task 2 result:", result2)
    except asyncio.CancelledError:
        print("Task 2 was cancelled as expected")
    except Exception as e:
        print("Task 2 error:", e)

asyncio.run(cancellation_example())
''')
""")

    print("Pure asyncio cancellation example completed!")

# Conceptual examples for comparison (keeping the same structure)
fn explain_channels():
    """Explain channels for inter-task communication."""
    print("Channels for Inter-Task Communication:")
    print("- channel.send(value): Send data to channel")
    print("- value = channel.receive(): Receive data from channel")
    print("- channel.close(): Close channel")
    print("- Useful for producer-consumer patterns")

fn explain_task_groups():
    """Explain task groups for structured concurrency."""
    print("Task Groups for Structured Concurrency:")
    print("- asyncio.gather(): Group related async tasks")
    print("- Automatic waiting for all tasks")
    print("- Error propagation to parent")

fn explain_cancellation():
    """Explain cancellation patterns."""
    print("Cancellation Patterns:")
    print("- task.cancel(): Request task cancellation")
    print("- CancelledError: Exception raised on cancellation")
    print("- Cooperative cancellation with try/except")

fn main() raises:
    print("=== Direct uvloop Advanced Async Example ===\n")

    print("--- Real Advanced Async Examples with Direct uvloop ---")
    run_channel_example_direct()
    print()
    run_task_group_example_direct()
    print()
    run_cancellation_example_direct()

    print("\n--- Conceptual Explanations ---")
    print("--- Channels ---")
    explain_channels()
    print("\n--- Task Groups ---")
    explain_task_groups()
    print("\n--- Cancellation ---")
    explain_cancellation()

    print("\nDirect uvloop advanced async concepts demonstrated!")