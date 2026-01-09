# 260108 - Python Threading in Mojo

## Overview
This document describes the implementation of Python threading examples in Mojo, demonstrating how to use Python's threading module for concurrent programming without relying on Mojo's async syntax.

## Problem Statement
After exploring async programming in Mojo with uvloop and pure asyncio, we sought a simpler concurrency approach. Python threading provides a straightforward alternative to async complexity while still enabling concurrent execution.

## Solution
Created `threading_examples.mojo` that demonstrates Python threading integration using `Python.evaluate` with `exec()` to run multi-line Python code containing thread definitions and execution.

## Key Technical Details

### Python Interop Challenges
- Mojo doesn't support lambda expressions or direct function passing to Python threads
- `Python.evaluate` requires careful string formatting to avoid syntax errors
- Multi-line Python code must be properly formatted without leading newlines

### Implementation Approach
```mojo
// Using exec() to run multi-line Python threading code
var py_code = """
import threading
import time

def thread_work(duration):
    print('Thread starting work for', duration, 'seconds')
    time.sleep(duration)
    print('Thread finished work')

# Create and start threads
t1 = threading.Thread(target=thread_work, args=(1.0,))
t2 = threading.Thread(target=thread_work, args=(0.5,))
t1.start()
t2.start()
t1.join()
t2.join()
print('All threads completed!')
"""
Python.evaluate("exec('''" + py_code + "''')")
```

### Virtual Environment Requirement
Mojo projects require venv activation before CLI commands:
```bash
source .venv/bin/activate && mojo run threading_examples.mojo
```

## Examples Demonstrated

### 1. Basic Thread Creation
- Creates multiple threads with different work durations
- Demonstrates concurrent execution (threads start simultaneously)
- Shows thread joining to wait for completion

### 2. Custom Thread Functions
- Defines worker functions in Python space
- Creates threads targeting specific functions
- Demonstrates thread lifecycle management

## Test Results
```
=== Threading Examples in Mojo ===

1. Basic Thread Creation
Creating and starting threads...
Thread starting work for 1.0 seconds
Thread starting work for 0.5 seconds
Thread finished work
Thread finished work
All threads completed!
2. Thread with Custom Function
Worker thread: starting
Worker thread: done
Custom function thread completed!
=== Threading Examples Complete ===
```

## Key Observations
- **True Concurrency**: Both threads start work immediately, demonstrating parallel execution
- **No Async Complexity**: Threading provides simpler concurrency model than async programming
- **Python Interop**: Direct integration with Python's threading module works reliably
- **Performance**: Suitable for I/O-bound tasks and background processing

## Error Resolution
- **Issue**: `Python.evaluate` failed with multi-line strings due to leading newlines
- **Fix**: Used `exec('''...''')` pattern to properly execute multi-line Python code
- **Issue**: Function signature `def main() raises` caused parsing errors
- **Fix**: Changed to `fn main() raises` (Mojo function syntax)
- **Issue**: F-strings not supported in evaluated Python code
- **Fix**: Used string concatenation with `+` operator

## Future Extensions
- Thread synchronization with locks
- Thread pools with concurrent.futures
- Daemon threads for background tasks
- Shared data protection patterns

## Files Created
- `threading_examples.mojo` - Main implementation with working examples
- `test_python.mojo` - Simple test for Python.evaluate functionality

## Conclusion
Python threading provides a viable concurrency alternative in Mojo, offering simpler semantics than async programming while maintaining the ability to run tasks concurrently. The implementation demonstrates reliable Python interop and real concurrent execution.