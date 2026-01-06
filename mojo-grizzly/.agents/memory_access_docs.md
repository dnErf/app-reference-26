# Memory Access in Mojo

This project includes a simple `MemoryAccess` struct (`memory_access.mojo`) demonstrating low-level memory management in Mojo. Key concepts:

- **Allocation/Deallocation**: Uses `List[UInt8]` for dynamic memory, resized on init.
- **Read/Write Operations**: Bounds-checked access to individual bytes or multi-byte values (e.g., Int32).
- **Copy Operations**: Efficient bulk copying between buffers.
- **Ownership & Safety**: Automatic deallocation via RAII; raises on out-of-bounds access.

Example:
```mojo
var mem = MemoryAccess(1024)
mem.write(0, 42)
print(mem.read(0))  # 42
mem.write_int32(4, 12345)
print(mem.read_int32(4))  # 12345
```

This serves as a foundation for understanding Mojo's memory model, crucial for fixing ownership issues in the main codebase.