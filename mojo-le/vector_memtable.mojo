# Vector Memtable - Dynamic array with O(N) operations but good cache performance
struct VectorMemtable:
    var entries: List[Tuple[String, String]]
    var size_bytes: Int
    var max_size: Int

    fn __init__(out self, max_size: Int = 1024 * 1024):  # 1MB default
        self.entries = List[Tuple[String, String]]()
        self.size_bytes = 0
        self.max_size = max_size

    fn put(mut self, key: String, value: String) raises -> Bool:
        """Insert or update with O(N) linear search. Returns True if memtable is full."""
        # Check if key exists
        for i in range(len(self.entries)):
            if self.entries[i][0] == key:
                # Update existing entry
                self.size_bytes -= len(self.entries[i][1])
                self.entries[i] = (key, value)
                self.size_bytes += len(value)
                return self.size_bytes >= self.max_size

        # Insert new entry
        self.entries.append((key, value))
        self.size_bytes += len(key) + len(value)

        return self.size_bytes >= self.max_size

    fn get(self, key: String) raises -> String:
        """Get value for key with O(N) linear search."""
        for entry in self.entries:
            if entry[0] == key:
                return entry[1]
        return ""

    fn is_empty(self) -> Bool:
        return len(self.entries) == 0

    fn clear(mut self):
        self.entries.clear()
        self.size_bytes = 0

    fn get_size_bytes(self) -> Int:
        return self.size_bytes

    fn get_entry_count(self) -> Int:
        return len(self.entries)

    fn get_all_entries(self) raises -> Dict[String, String]:
        var result = Dict[String, String]()
        for entry in self.entries:
            result[entry[0]] = entry[1]
        return result^

fn demo_vector_memtable() raises:
    """Demonstrate VectorMemtable operations."""
    print("=== VectorMemtable Demonstration ===\n")

    var memtable = VectorMemtable(1024)

    print("Inserting test data...")
    var test_data = List[Tuple[String, String]]()
    test_data.append(("key1", "value1"))
    test_data.append(("key2", "value2"))
    test_data.append(("key3", "value3"))

    for entry in test_data:
        var should_flush = memtable.put(entry[0], entry[1])
        print("Inserted:", entry[0], "=", entry[1], "(flush needed:", should_flush, ")")

    print("\nReading all keys...")
    for entry in test_data:
        var value = memtable.get(entry[0])
        print("Read:", entry[0], "=", value)

    print("\nStatistics:")
    print("Entries:", memtable.get_entry_count())
    print("Size bytes:", memtable.get_size_bytes())
    print("Max size:", memtable.max_size)

fn main() raises:
    demo_vector_memtable()