"""
SSTable Implementation in Mojo
==============================

This file implements SSTable (Sorted String Table) using PyArrow Parquet
for persistent, immutable storage in the LSM Tree system.

Key Features:
- PyArrow Parquet integration for efficient columnar storage
- Immutable SSTable files with metadata
- Bloom filters for fast key existence checks
- Range queries and point lookups
- Automatic file management and naming

Performance Characteristics:
- Write: Batches data for efficient Parquet writing
- Read: Fast columnar access with predicate pushdown
- Storage: Compressed columnar format
- Memory: Minimal memory footprint for metadata

Use Cases:
- Persistent storage layer for LSM trees
- Immutable data snapshots
- Efficient range and point queries
- Data archival and backup
"""

from python import Python, PythonObject
from collections import List, Dict
from os import path

# SSTable implementation using PyArrow Parquet
struct SSTableMetadata(Movable):
    var filename: String
    var min_key: String
    var max_key: String
    var num_entries: Int
    var file_size: Int
    var created_at: Int64
    var level: Int

    fn __init__(out self, filename: String, min_key: String, max_key: String,
                num_entries: Int, file_size: Int, level: Int = 0):
        self.filename = filename
        self.min_key = min_key
        self.max_key = max_key
        self.num_entries = num_entries
        self.file_size = file_size
        self.created_at = Int64(0)  # Placeholder - will be set when saved
        self.level = level

struct SSTable(Movable):
    var metadata: SSTableMetadata
    var pyarrow_table: PythonObject  # PyArrow Table object
    var bloom_filter: Dict[String, Bool]  # Simple bloom filter simulation

    fn __init__(out self, data: Dict[String, String], level: Int = 0) raises:
        """Create SSTable from key-value data dictionary."""
        # Initialize PyArrow
        var pa = Python.import_module("pyarrow")
        var pq = Python.import_module("pyarrow.parquet")

        # Convert data to PyArrow table
        var keys = List[String]()
        var values = List[String]()

        for key in data.keys():
            keys.append(key)
            try:
                values.append(data[key])
            except:
                values.append("")

        # Convert Mojo lists to Python lists
        var py_keys = Python.evaluate("[]")
        for key in keys:
            py_keys.append(key)
        
        var py_values = Python.evaluate("[]")
        for value in values:
            py_values.append(value)

        # Create PyArrow arrays
        var key_array = pa.array(py_keys)
        var value_array = pa.array(py_values)

        # Create table
        var py_schema = Python.evaluate("[('key', 'string'), ('value', 'string')]")
        var schema = pa.schema(py_schema)
        self.pyarrow_table = pa.Table.from_arrays([key_array, value_array], names=["key", "value"])

        # Generate filename
        var timestamp = "1234567890"  # Placeholder timestamp
        var filename = "sstable_L" + String(level) + "_" + timestamp + ".parquet"

        # Calculate metadata
        var min_key = ""
        var max_key = ""
        if len(keys) > 0:
            min_key = keys[0]
            max_key = keys[0]
            for key in keys:
                if key < min_key:
                    min_key = key
                if key > max_key:
                    max_key = key

        self.metadata = SSTableMetadata(
            filename, min_key, max_key, len(keys), 0, level
        )

        # Initialize simple bloom filter (for demonstration)
        self.bloom_filter = Dict[String, Bool]()
        for key in keys:
            self.bloom_filter[key] = True

    fn save(mut self, directory: String) raises -> String:
        """Save SSTable to Parquet file and return full path."""
        var pq = Python.import_module("pyarrow.parquet")
        var full_path = path.join(directory, self.metadata.filename)

        # Write to Parquet
        pq.write_table(self.pyarrow_table, full_path)

        # Update file size in metadata
        # Note: In real implementation, you'd get actual file size
        self.metadata.file_size = 1024  # Placeholder

        return full_path

    @staticmethod
    fn load(filename: String) raises -> SSTable:
        """Load SSTable from Parquet file."""
        var pq = Python.import_module("pyarrow.parquet")

        # Read Parquet file
        var table = pq.read_table(filename)

        # Extract metadata from filename (basic parsing)
        var basename = path.basename(filename)
        var level = 0
        if basename.startswith("sstable_L"):
            # Extract level from filename
            var level_str = basename.split("_")[0][8:]  # Remove "sstable_L"
            try:
                level = Int(level_str)
            except:
                level = 0

        # Get min/max keys from table
        var keys = table.column("key").to_pylist()
        var min_key = String(keys[0]) if len(keys) > 0 else ""
        var max_key = String(keys[0]) if len(keys) > 0 else ""

        for key in keys:
            var key_str = String(key)
            if key_str < min_key:
                min_key = key_str
            if key_str > max_key:
                max_key = key_str

        var metadata = SSTableMetadata(
            basename, min_key, max_key, len(keys), 0, level
        )

        # Create empty data dict for constructor (will be replaced)
        var dummy_data = Dict[String, String]()
        var sstable = SSTable(dummy_data, level)
        sstable.metadata = metadata^
        sstable.pyarrow_table = table

        # Rebuild bloom filter
        sstable.bloom_filter = Dict[String, Bool]()
        for key in keys:
            sstable.bloom_filter[String(key)] = True

        return sstable^

    fn get(self, key: String) raises -> String:
        """Get value for key, returns empty string if not found."""
        # Check bloom filter first
        try:
            var _ = self.bloom_filter[key]
        except:
            return ""  # Key definitely not in SSTable

        # Query PyArrow table
        var pa = Python.import_module("pyarrow.compute")

        # Create filter for exact key match
        var key_filter = pa.equal(self.pyarrow_table.column("key"), key)

        # Apply filter
        var filtered_table = self.pyarrow_table.filter(key_filter)

        if filtered_table.num_rows > 0:
            var values = filtered_table.column("value").to_pylist()
            return String(values[0])

        return ""

    fn range_query(self, start_key: String, end_key: String) raises -> List[Tuple[String, String]]:
        """Get all key-value pairs in range [start_key, end_key]."""
        var result = List[Tuple[String, String]]()

        # Query PyArrow table with range filter
        var pa = Python.import_module("pyarrow.compute")

        # Create range filter: key >= start_key AND key <= end_key
        var start_filter = pa.greater_equal(self.pyarrow_table.column("key"), start_key)
        var end_filter = pa.less_equal(self.pyarrow_table.column("key"), end_key)
        var range_filter = pa.and_(start_filter, end_filter)

        # Apply filter
        var filtered_table = self.pyarrow_table.filter(range_filter)

        if filtered_table.num_rows > 0:
            var keys = filtered_table.column("key").to_pylist()
            var values = filtered_table.column("value").to_pylist()

            for i in range(len(keys)):
                result.append((String(keys[i]), String(values[i])))

        return result^

    fn contains_key(self, key: String) -> Bool:
        """Check if key exists using bloom filter."""
        try:
            return self.bloom_filter[key]
        except:
            return False

    fn get_stats(self) -> String:
        """Get SSTable statistics."""
        return "SSTable: " + self.metadata.filename +
               ", Level: " + String(self.metadata.level) +
               ", Entries: " + String(self.metadata.num_entries) +
               ", Size: " + String(self.metadata.file_size) + " bytes" +
               ", Key range: [" + self.metadata.min_key + ", " + self.metadata.max_key + "]"

# Demonstration functions
fn demo_sstable() raises:
    """Demonstrate SSTable operations."""
    print("=== SSTable Demonstration ===\n")

    # Create test data
    var test_data = Dict[String, String]()
    test_data["apple"] = "red fruit"
    test_data["banana"] = "yellow fruit"
    test_data["cherry"] = "red fruit"
    test_data["date"] = "brown fruit"
    test_data["elderberry"] = "purple fruit"

    print("Creating SSTable with test data...")
    var sstable = SSTable(test_data, level=1)

    print("SSTable metadata:")
    print(sstable.get_stats())
    print()

    # Test point lookups
    print("Point lookups:")
    var test_keys = List[String]()
    test_keys.append("apple")
    test_keys.append("banana")
    test_keys.append("grape")  # Not in SSTable

    for key in test_keys:
        var value = sstable.get(key)
        var exists = sstable.contains_key(key)
        print("  ", key, "=", value, "(exists:", exists, ")")

    print()

    # Test range queries
    print("Range queries:")
    var ranges = List[Tuple[String, String]]()
    ranges.append(("apple", "cherry"))
    ranges.append(("banana", "date"))
    ranges.append(("fig", "grape"))  # No matches expected

    for range_query in ranges:
        var results = sstable.range_query(range_query[0], range_query[1])
        print("  Range [" + range_query[0] + ", " + range_query[1] + "]:")
        for result in results:
            print("    ", result[0], "=", result[1])
        if len(results) == 0:
            print("    (no results)")

    print()

    # Save SSTable
    print("Saving SSTable...")
    var save_path = sstable.save(".")
    print("Saved to:", save_path)

    print()

    # Load SSTable
    print("Loading SSTable from file...")
    var loaded_sstable = SSTable.load(save_path)
    print("Loaded SSTable:")
    print(loaded_sstable.get_stats())

    # Verify loaded data
    print("\nVerifying loaded data:")
    var apple_value = loaded_sstable.get("apple")
    print("  apple =", apple_value)

    var range_results = loaded_sstable.range_query("banana", "date")
    print("  Range query results:", len(range_results))

fn main() raises:
    """Main entry point."""
    demo_sstable()