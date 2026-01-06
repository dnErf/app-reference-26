# Simple Memory Access Implementation in Mojo
# Demonstrates allocation, deallocation, read/write with dynamic arrays
# Based on Mojo's List for memory management

struct MemoryAccess:
    var data: List[UInt8]
    var size: Int

    fn __init__(out self, size: Int):
        self.size = size
        self.data = List[UInt8]()
        self.data.resize(size, 0)

    fn write(mut self, offset: Int, value: UInt8) raises:
        if offset < 0 or offset >= self.size:
            raise "Offset out of bounds"
        self.data[offset] = value

    fn read(self, offset: Int) raises -> UInt8:
        if offset < 0 or offset >= self.size:
            raise "Offset out of bounds"
        return self.data[offset]

    fn write_int32(mut self, offset: Int, value: Int32) raises:
        if offset < 0 or offset + 4 > self.size:
            raise "Offset out of bounds"
        # Manual byte writing
        self.data[offset] = UInt8(value & 0xFF)
        self.data[offset + 1] = UInt8((value >> 8) & 0xFF)
        self.data[offset + 2] = UInt8((value >> 16) & 0xFF)
        self.data[offset + 3] = UInt8((value >> 24) & 0xFF)

    fn read_int32(self, offset: Int) raises -> Int32:
        if offset < 0 or offset + 4 > self.size:
            raise "Offset out of bounds"
        var value: Int32 = 0
        value |= Int32(self.data[offset])
        value |= Int32(self.data[offset + 1]) << 8
        value |= Int32(self.data[offset + 2]) << 16
        value |= Int32(self.data[offset + 3]) << 24
        return value

    fn copy_from(mut self, src: MemoryAccess, src_offset: Int, dest_offset: Int, length: Int) raises:
        if src_offset < 0 or dest_offset < 0 or length < 0:
            raise "Invalid parameters"
        if src_offset + length > src.size or dest_offset + length > self.size:
            raise "Out of bounds"
        for i in range(length):
            self.data[dest_offset + i] = src.data[src_offset + i]

# Example usage
fn main() raises:
    var mem = MemoryAccess(1024)
    mem.write(0, 42)
    print("Read:", mem.read(0))
    mem.write_int32(4, 12345)
    print("Read Int32:", mem.read_int32(4))
    # mem is automatically deallocated when it goes out of scope