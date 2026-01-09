# Async and Concurrency Examples in Mojo

Date: 241008 (Updated: 241008 with uvloop interop)  
Task: Create comprehensive async and concurrency examples for Mojo learning with real async functionality

## Overview

This document covers the async and concurrency programming examples created for the Mojo learning series. These examples now demonstrate **real asynchronous programming** using Python interop with asyncio and uvloop for high-performance async functionality in Mojo.

## Examples Created

### 1. Intermediate Async Example (`intermediate_async.mojo`)

**Purpose**: Introduce basic asynchronous programming concepts including async/await, coroutines, and concurrent execution patterns using real async functionality.

**Key Concepts**:
- async/await syntax for non-blocking operations (via Python interop)
- Coroutines and task management with uvloop
- Concurrent vs sequential execution
- Error handling in async contexts

**Code Highlights**:
- Real async function execution using Python asyncio
- Concurrent task execution with uvloop event loop
- Sequential vs concurrent performance comparison
- Error handling with async exception propagation

**Learning Outcomes**:
- Understanding async programming paradigms
- Basic concurrent execution patterns
- Error propagation in async code
- uvloop performance benefits

### 2. Advanced Async Example (`advanced_async.mojo`)

**Purpose**: Demonstrate advanced async features including channels, task groups, structured concurrency, cancellation, and timeouts using real async implementations.

**Key Concepts**:
- Channels for inter-task communication (asyncio.Queue)
- Task groups and structured concurrency (asyncio.gather)
- Cancellation tokens and cooperative cancellation
- Timeout patterns for bounded operations

**Code Highlights**:
- Producer-consumer patterns with real channels
- Task group management with asyncio.gather
- Cancellation implementation with asyncio.CancelledError
- Nested task groups and structured concurrency

**Learning Outcomes**:
- Advanced concurrency patterns
- Structured concurrency principles
- Resource management in async code
- Timeout and cancellation handling

### 3. Expert Async Example (`expert_async.mojo`)

**Purpose**: Explore expert-level async programming with custom primitives, iterators, benchmarking, and real-world patterns using high-performance async implementations.

**Key Concepts**:
- Custom async primitives (Semaphore, custom iterators)
- Async iterators and generators
- Performance benchmarking techniques
- Advanced concurrency patterns
- Memory management and scaling

**Code Highlights**:
- Custom semaphore implementation
- Async iterator classes with __aiter__ and __anext__
- Performance benchmarking with uvloop
- Error handling with custom exception types
- Sync vs async performance comparison

**Learning Outcomes**:
- Building custom async abstractions
- Performance optimization techniques
- Scaling async applications
- Testing async code
- uvloop vs standard asyncio performance

## Technical Details

### Async Programming Implementation

These examples use Python interop to provide real async functionality:

```python
# Python async utilities (async_utils.py, advanced_async_utils.py, expert_async_utils.py)
import asyncio
import uvloop

# Install uvloop for high performance
asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

async def concurrent_example():
    # Real async execution
    task1 = simple_async_task("Task A", 0.5)
    task2 = simple_async_task("Task B", 0.3)
    results = await asyncio.gather(task1, task2)
    return results
```

```mojo
// Mojo wrapper functions
fn run_concurrent_example() raises:
    var async_utils = Python.import_module("async_utils")
    async_utils.run_concurrent_example()
```

### Key Async Concepts Demonstrated

1. **Coroutines**: Real async functions using asyncio
2. **Tasks**: Concurrent work units managed by uvloop event loop
3. **Event Loop**: uvloop provides high-performance scheduling
4. **Channels**: asyncio.Queue for typed inter-task communication
5. **Task Groups**: asyncio.gather for structured concurrency
6. **Cancellation**: asyncio.CancelledError for cooperative termination
7. **Async Iterators**: Custom classes implementing async iteration
8. **Performance Benchmarking**: Real timing comparisons

### uvloop Performance Benefits

- **Faster Event Loop**: uvloop provides Cython-optimized event loop
- **Better Scalability**: Handles more concurrent connections
- **Lower Latency**: Reduced context switching overhead
- **Memory Efficient**: Optimized memory usage for async operations

## Testing and Validation

All examples were tested and verified:

- **Compilation**: All Mojo files compile successfully with Python interop
- **Execution**: Real async functionality demonstrated with uvloop
- **Performance**: uvloop provides measurable performance improvements
- **Error Handling**: Proper exception propagation through interop layer

## Educational Value

These examples provide a comprehensive learning path:

1. **Intermediate**: Real async execution with concurrent tasks
2. **Advanced**: Complex patterns like channels and task groups  
3. **Expert**: Custom primitives and performance optimization

The combination of conceptual explanations and real implementations makes this a complete async programming resource.

## Python Dependencies

Required Python packages:
- `asyncio` (built-in)
- `uvloop` (high-performance event loop)

Install with: `pip install uvloop`

## Related Documentation

- SIMD Examples: `260108-simd-examples.md`
- GPU Examples: `241008-gpu-examples.md`
- Basic Mojo Examples: `26010801-mojo-examples.md` through `26010803-mojo-examples.md`
- Mojo Parameters: `241008-mojo-parameters-example.md`