import asyncio
import uvloop
import time
from typing import AsyncIterator, List, Any
import statistics

# Install uvloop as the event loop
asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

# Custom async iterator
class AsyncRange:
    def __init__(self, start: int, end: int, step: int = 1):
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
        await asyncio.sleep(0.01)  # Simulate async work
        return value

async def async_range_example():
    """Demonstrate custom async iterator"""
    print("Async Iterator Example:")
    async for i in AsyncRange(0, 5):
        print(f"Got from async iterator: {i}")
    print("Async iterator completed")

# Async generator function
async def async_generator(limit: int) -> AsyncIterator[int]:
    """Async generator that yields squares"""
    for i in range(limit):
        await asyncio.sleep(0.05)
        yield i * i

async def async_generator_example():
    """Demonstrate async generator usage"""
    print("Async Generator Example:")
    async for square in async_generator(5):
        print(f"Square: {square}")
    print("Async generator completed")

# Custom async primitives
class Semaphore:
    def __init__(self, value: int = 1):
        self.value = value
        self.waiters = []

    async def acquire(self):
        if self.value > 0:
            self.value -= 1
            return True
        else:
            # Wait for release
            future = asyncio.Future()
            self.waiters.append(future)
            await future
            return True

    def release(self):
        self.value += 1
        if self.waiters:
            waiter = self.waiters.pop(0)
            waiter.set_result(True)

async def semaphore_task(name: str, semaphore: Semaphore):
    """Task that uses semaphore for resource control"""
    print(f"Task {name} waiting for semaphore...")
    await semaphore.acquire()
    print(f"Task {name} acquired semaphore")
    await asyncio.sleep(0.2)  # Simulate work
    print(f"Task {name} releasing semaphore")
    semaphore.release()

async def semaphore_example():
    """Demonstrate custom semaphore"""
    print("Custom Semaphore Example:")
    semaphore = Semaphore(2)  # Allow 2 concurrent tasks

    tasks = [
        semaphore_task("A", semaphore),
        semaphore_task("B", semaphore),
        semaphore_task("C", semaphore),
        semaphore_task("D", semaphore)
    ]

    await asyncio.gather(*tasks)
    print("Semaphore example completed")

# Benchmarking async operations
async def benchmark_task(name: str, iterations: int) -> float:
    """Benchmark async operation"""
    start_time = time.time()
    for i in range(iterations):
        await asyncio.sleep(0.001)  # Small async operation
    end_time = time.time()
    duration = end_time - start_time
    print(".4f")
    return duration

async def async_benchmarking():
    """Demonstrate async operation benchmarking"""
    print("Async Benchmarking Example:")

    # Run multiple benchmark tasks
    tasks = [
        benchmark_task("Task1", 100),
        benchmark_task("Task2", 100),
        benchmark_task("Task3", 100)
    ]

    durations = await asyncio.gather(*tasks)

    avg_duration = statistics.mean(durations)
    print(".4f")
    print(".4f")

# Advanced error handling with async
class AsyncError(Exception):
    pass

async def failing_async_task(name: str, should_fail: bool = False) -> str:
    """Async task that can fail"""
    await asyncio.sleep(0.1)
    if should_fail:
        raise AsyncError(f"Task {name} failed!")
    return f"Task {name} succeeded"

async def error_handling_example():
    """Demonstrate advanced error handling"""
    print("Advanced Error Handling Example:")

    tasks = [
        failing_async_task("A", False),
        failing_async_task("B", True),
        failing_async_task("C", False)
    ]

    results = []
    for coro in asyncio.as_completed(tasks):
        try:
            result = await coro
            results.append(result)
            print(f"Success: {result}")
        except AsyncError as e:
            print(f"Error: {e}")

    print(f"Completed tasks: {len(results)}")
    print("Error handling example completed")

# Performance comparison: sync vs async
def sync_operation(iterations: int) -> float:
    """Synchronous version for comparison"""
    start = time.time()
    for i in range(iterations):
        time.sleep(0.001)  # Blocking sleep
    return time.time() - start

async def async_operation(iterations: int) -> float:
    """Asynchronous version"""
    start = time.time()
    for i in range(iterations):
        await asyncio.sleep(0.001)  # Non-blocking sleep
    return time.time() - start

async def performance_comparison():
    """Compare sync vs async performance"""
    print("Performance Comparison: Sync vs Async")

    iterations = 100

    # Run sync version
    sync_time = sync_operation(iterations)
    print(".4f")

    # Run async version
    async_time = await async_operation(iterations)
    print(".4f")

    if async_time < sync_time:
        speedup = sync_time / async_time
        print(".2f")
    else:
        print("Async was slower (possibly due to overhead)")

def run_async_range_example():
    """Run async range example"""
    asyncio.run(async_range_example())

def run_async_generator_example():
    """Run async generator example"""
    asyncio.run(async_generator_example())

def run_semaphore_example():
    """Run semaphore example"""
    asyncio.run(semaphore_example())

def run_async_benchmarking():
    """Run async benchmarking"""
    asyncio.run(async_benchmarking())

def run_error_handling_example():
    """Run error handling example"""
    asyncio.run(error_handling_example())

def run_performance_comparison():
    """Run performance comparison"""
    asyncio.run(performance_comparison())