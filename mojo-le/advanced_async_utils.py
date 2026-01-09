import asyncio
import uvloop
import time
from typing import List, Any

# Install uvloop as the event loop
asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

# Simple channel implementation using asyncio.Queue
class Channel:
    def __init__(self):
        self.queue = asyncio.Queue()

    async def send(self, item):
        await self.queue.put(item)

    async def receive(self):
        return await self.queue.get()

async def producer(channel: Channel, name: str, items: List[int]):
    """Producer that sends items to a channel"""
    print(f"Producer {name} starting...")
    for item in items:
        print(f"Producer {name} sending: {item}")
        await channel.send(item)
        await asyncio.sleep(0.1)  # Simulate work
    print(f"Producer {name} finished")

async def consumer(channel: Channel, name: str, num_items: int):
    """Consumer that receives items from a channel"""
    print(f"Consumer {name} starting...")
    results = []
    for _ in range(num_items):
        item = await channel.receive()
        print(f"Consumer {name} received: {item}")
        results.append(item * 2)  # Process item
        await asyncio.sleep(0.05)  # Simulate processing time
    print(f"Consumer {name} finished with results: {results}")
    return results

async def channel_example():
    """Demonstrate producer-consumer pattern with channels"""
    print("Channel Example: Producer-Consumer Pattern")
    channel = Channel()

    # Start producer and consumer concurrently
    producer_task = producer(channel, "P1", [1, 2, 3, 4, 5])
    consumer_task = consumer(channel, "C1", 5)

    # Wait for both to complete
    await asyncio.gather(producer_task, consumer_task)
    print("Channel example completed")

# Task group simulation using asyncio.gather
async def task_in_group(name: str, delay: float) -> str:
    """A task that runs as part of a group"""
    print(f"Task {name} starting...")
    await asyncio.sleep(delay)
    print(f"Task {name} completed")
    return f"Task {name} result"

async def task_group_example():
    """Demonstrate structured concurrency with task groups"""
    print("Task Group Example: Structured Concurrency")

    # Create a group of tasks
    tasks = [
        task_in_group("A", 0.3),
        task_in_group("B", 0.2),
        task_in_group("C", 0.4),
        task_in_group("D", 0.1)
    ]

    # Run all tasks concurrently and wait for completion
    results = await asyncio.gather(*tasks)

    print("All tasks in group completed:")
    for result in results:
        print(f"- {result}")

    print("Task group example completed")

# Nested task groups
async def nested_task(name: str, value: int) -> int:
    """A nested task"""
    print(f"Nested task {name} processing {value}")
    await asyncio.sleep(0.1)
    return value * 10

async def outer_task(name: str) -> List[int]:
    """Outer task that spawns nested tasks"""
    print(f"Outer task {name} starting...")

    nested_tasks = [
        nested_task(f"{name}-1", 1),
        nested_task(f"{name}-2", 2),
        nested_task(f"{name}-3", 3)
    ]

    results = await asyncio.gather(*nested_tasks)
    print(f"Outer task {name} completed with results: {results}")
    return results

async def nested_groups_example():
    """Demonstrate nested task groups"""
    print("Nested Task Groups Example")

    outer_tasks = [
        outer_task("Group1"),
        outer_task("Group2")
    ]

    all_results = await asyncio.gather(*outer_tasks)

    print("All nested groups completed:")
    for i, results in enumerate(all_results):
        print(f"Group {i+1}: {results}")

# Cancellation example
async def cancellable_task(name: str, duration: float):
    """A task that can be cancelled"""
    try:
        print(f"Task {name} starting (will run for {duration}s)...")
        await asyncio.sleep(duration)
        print(f"Task {name} completed normally")
        return f"{name} success"
    except asyncio.CancelledError:
        print(f"Task {name} was cancelled!")
        raise

async def cancellation_example():
    """Demonstrate task cancellation"""
    print("Cancellation Example")

    # Create tasks with different durations
    task1 = cancellable_task("Fast", 0.2)
    task2 = cancellable_task("Slow", 1.0)

    # Start both tasks
    task1_handle = asyncio.create_task(task1)
    task2_handle = asyncio.create_task(task2)

    # Wait a bit then cancel the slow task
    await asyncio.sleep(0.1)
    print("Cancelling slow task...")
    task2_handle.cancel()

    # Wait for results
    try:
        result1 = await task1_handle
        print(f"Task 1 result: {result1}")
    except Exception as e:
        print(f"Task 1 error: {e}")

    try:
        result2 = await task2_handle
        print(f"Task 2 result: {result2}")
    except asyncio.CancelledError:
        print("Task 2 was cancelled as expected")
    except Exception as e:
        print(f"Task 2 error: {e}")

def run_channel_example():
    """Run the channel example"""
    asyncio.run(channel_example())

def run_task_group_example():
    """Run the task group example"""
    asyncio.run(task_group_example())

def run_nested_groups_example():
    """Run the nested groups example"""
    asyncio.run(nested_groups_example())

def run_cancellation_example():
    """Run the cancellation example"""
    asyncio.run(cancellation_example())