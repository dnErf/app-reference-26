# Pure Asyncio Examples in Mojo

This directory contains comprehensive asynchronous programming examples using pure asyncio in Mojo. These examples demonstrate real async functionality without uvloop dependency.

## Files

### `intermediate_async_direct.mojo`
Basic async concepts with direct uvloop imports:
- Concurrent task execution
- Multiple await patterns
- Error handling in async code
- Real async functionality demonstration

### `advanced_async_direct.mojo`
Advanced async patterns with direct uvloop imports:
- Channel-based producer-consumer patterns
- Task groups for structured concurrency
- Task cancellation patterns
- Complex async coordination

### `expert_async_direct.mojo`
Expert-level async concepts with direct uvloop imports:
- Custom async iterators and generators
- Semaphore implementation for concurrency control
- Performance benchmarking (sync vs async)
- Advanced async primitives

## Key Features

- **Direct uvloop Integration**: Uses `uvloop.new_event_loop()` and `asyncio.set_event_loop()` for direct uvloop event loop creation instead of policy setting
- **Real Async Execution**: Demonstrates actual concurrent execution and performance benefits
- **Python Interop**: Uses `Python.evaluate()` with `exec()` for complex async code execution
- **Comprehensive Coverage**: From basic concurrency to expert-level async patterns

## Running Examples

```bash
mojo run intermediate_async_direct.mojo
mojo run advanced_async_direct.mojo
mojo run expert_async_direct.mojo
```

## Dependencies

- asyncio (Python standard library)

## Technical Notes

- Uses `asyncio.run()` for executing async code
- Python interop via `Python.evaluate()` for async syntax execution
- Demonstrates standard asyncio functionality without external dependencies