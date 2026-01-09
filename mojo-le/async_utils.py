import asyncio
import time

# Note: uvloop event loop is created directly in Mojo code

async def simple_async_task(name: str, delay: float) -> str:
    """A simple async task that simulates work with a delay"""
    print(f"Starting task: {name}")
    await asyncio.sleep(delay)  # Async delay
    print(f"Completed task: {name}")
    return name + " done"

async def compute_async(value: int) -> int:
    """Async function that performs computation"""
    result = value * value
    await asyncio.sleep(0.1)  # Small async delay
    return result

async def concurrent_example():
    """Demonstrate running multiple async tasks concurrently"""
    print("Starting concurrent tasks...")

    # Create async tasks
    task1 = simple_async_task("Task A", 0.5)
    task2 = simple_async_task("Task B", 0.3)
    task3 = compute_async(5)

    # Use gather for true concurrent execution
    results = await asyncio.gather(task1, task2, task3)

    print("All tasks completed:")
    for i, result in enumerate(results, 1):
        print("Result", i, ":", result)

async def multiple_awaits_example():
    """Example of awaiting multiple tasks in sequence"""
    print("Multiple awaits example:")

    # First batch
    batch1_task1 = compute_async(2)
    batch1_task2 = compute_async(3)
    sum1 = (await batch1_task1) + (await batch1_task2)
    print("Batch 1 sum:", sum1)

    # Second batch
    batch2_task1 = compute_async(4)
    batch2_task2 = compute_async(5)
    sum2 = (await batch2_task1) + (await batch2_task2)
    print("Batch 2 sum:", sum2)

    print("Total sum:", sum1 + sum2)

async def async_with_error(value: int) -> int:
    """Async function that can raise an error"""
    if value < 0:
        raise ValueError("negative value not allowed")
    await asyncio.sleep(0.1)
    return value * 2

async def error_handling_example():
    """Demonstrate error handling in async context"""
    print("Error handling example:")

    try:
        result1 = await async_with_error(5)
        print("Result 1:", result1)
    except Exception as e:
        print("Error:", e)

    try:
        result2 = await async_with_error(-1)
        print("Result 2:", result2)
    except Exception as e:
        print("Error:", e)

def run_concurrent_example():
    """Run the concurrent example"""
    asyncio.run(concurrent_example())

def run_multiple_awaits_example():
    """Run the multiple awaits example"""
    asyncio.run(multiple_awaits_example())

def run_error_handling_example():
    """Run the error handling example"""
    asyncio.run(error_handling_example())

# Advanced async examples

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

def run_channel_example():
    """Run the channel example"""
    asyncio.run(channel_example())

def run_task_group_example():
    """Run the task group example"""
    asyncio.run(task_group_example())

def run_cancellation_example():
    """Run the cancellation example"""
    asyncio.run(cancellation_example())

# Expert async examples

class AsyncRange:
    def __init__(self, start, end, step=1):
        self.start = start
        self.end = end
        self.step = step
        self.current = start

    def __aiter__(self):
        return self

    async def __anext__(self):
        if self.current >= self.end:
            raise StopAsyncIteration
        value = self.current
        self.current += self.step
        await asyncio.sleep(0.01)
        return value

async def async_range_example():
    print("Async Iterator Example:")
    async for i in AsyncRange(0, 5):
        print("Got from async iterator:", i)
    print("Async iterator completed")

class Semaphore:
    def __init__(self, value=1):
        self.value = value
        self.waiters = []

    async def acquire(self):
        if self.value > 0:
            self.value -= 1
            return True
        else:
            future = asyncio.Future()
            self.waiters.append(future)
            await future
            return True

    def release(self):
        self.value += 1
        if self.waiters:
            waiter = self.waiters.pop(0)
            waiter.set_result(True)

async def semaphore_task(name, semaphore):
    print("Task", name, "waiting for semaphore...")
    await semaphore.acquire()
    print("Task", name, "acquired semaphore")
    await asyncio.sleep(0.2)
    print("Task", name, "releasing semaphore")
    semaphore.release()

async def semaphore_example():
    print("Custom Semaphore Example:")
    semaphore = Semaphore(2)

    tasks = [
        semaphore_task("A", semaphore),
        semaphore_task("B", semaphore),
        semaphore_task("C", semaphore),
        semaphore_task("D", semaphore)
    ]

    await asyncio.gather(*tasks)
    print("Semaphore example completed")

async def performance_comparison():
    print("Performance Comparison: Sync vs Async with uvloop")

    iterations = 100

    # Sync operation
    start = time.time()
    for i in range(iterations):
        time.sleep(0.001)
    sync_time = time.time() - start
    print("Sync time:", sync_time)

    # Async operation
    start = time.time()
    for i in range(iterations):
        await asyncio.sleep(0.001)
    async_time = time.time() - start
    print("Async time:", async_time)

    if async_time < sync_time:
        speedup = sync_time / async_time
        print("Async is", speedup, "x faster!")
    else:
        slowdown = async_time / sync_time
        print("Async is", slowdown, "x slower")

def run_async_iterator_example():
    """Run the async iterator example"""
    asyncio.run(async_range_example())

def run_semaphore_example():
    """Run the semaphore example"""
    asyncio.run(semaphore_example())

def run_performance_comparison():
    """Run the performance comparison"""
    asyncio.run(performance_comparison())