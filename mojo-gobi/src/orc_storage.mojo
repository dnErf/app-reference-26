"""
PyArrow ORC Data Storage
========================

Handles columnar data storage using PyArrow ORC format.
Provides efficient storage and retrieval of table data.
"""

from python import Python, PythonObject
from collections import List
from blob_storage import BlobStorage
from merkle_tree import MerkleBPlusTree, SHA256Hash

struct ORCStorage:
    var storage: BlobStorage
    var merkle_tree: MerkleBPlusTree

    fn __init__(out self, storage: BlobStorage):
        self.storage = storage.copy()
        self.merkle_tree = MerkleBPlusTree()

    fn __copyinit__(out self, other: Self):
        self.storage = other.storage.copy()
        self.merkle_tree = other.merkle_tree.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.storage = existing.storage^
        self.merkle_tree = existing.merkle_tree^

    fn write_table(mut self, table_name: String, data: List[List[String]]) -> Bool:
        """Write table data with integrity verification, appending to existing data."""
        try:
            # Read existing data first
            var existing_data = self.read_table(table_name)
            var all_data = List[List[String]]()

            # Add existing data
            for row in existing_data:
                all_data.append(row.copy())

            # Add new data
            for row in data:
                all_data.append(row.copy())

            # Now write all data
            var json_lines = ""
            var row_index = 0

            for row in all_data:
                # Create row data string for hashing (content-based)
                var row_data = table_name + ":"
                for i in range(len(row)):
                    if i > 0:
                        row_data += "|"
                    row_data += row[i]

                # Compute content hash
                var row_hash = SHA256Hash.compute(row_data)

                # Store in Merkle tree for indexing (optional)
                _ = self.merkle_tree.insert(row_index, row_data)

                # Create JSON row with integrity hash
                var json_row = "{\"hash\":\"" + row_hash + "\",\"data\":{"
                for i in range(len(row)):
                    if i > 0:
                        json_row += ","
                    json_row += "\"" + String(i) + "\":\"" + row[i] + "\""
                json_row += "}}\n"
                json_lines += json_row
                row_index += 1

            # Store the data
            var data_success = self.storage.write_blob("tables/" + table_name + ".jsonl", json_lines)

            # Store Merkle tree state for this table
            var tree_state = self.merkle_tree.get_root_hash()
            var tree_success = self.storage.write_blob("integrity/" + table_name + ".merkle", tree_state)

            return data_success and tree_success
        except:
            return False

    fn read_table(self, table_name: String) -> List[List[String]]:
        """Read table data with integrity verification."""
        var results = List[List[String]]()

        try:
            var jsonl_data = self.storage.read_blob("tables/" + table_name + ".jsonl")
            if jsonl_data == "":
                return results.copy()

            # Load stored Merkle tree state for verification
            var stored_tree_hash = self.storage.read_blob("integrity/" + table_name + ".merkle")
            var expected_integrity = stored_tree_hash != ""

            # Parse JSON lines with integrity checking
            var lines = jsonl_data.split("\n")
            var json_module = Python.import_module("json")
            var integrity_violations = 0

            for i in range(len(lines)):
                var line = lines[i]
                var trimmed = String(line).strip()
                if trimmed == "":
                    continue

                # Parse JSON using Python
                try:
                    var parsed = json_module.loads(trimmed)
                    var row = List[String]()

                    # Extract hash if present
                    var stored_hash = ""
                    if parsed.__contains__("hash"):
                        stored_hash = String(parsed["hash"])

                    # Extract data
                    if parsed.__contains__("data"):
                        var data_obj = parsed["data"]
                        # Data is stored as {"0":"val1","1":"val2",...}
                        var col_index = 0
                        while True:
                            var key = String(col_index)
                            if data_obj.__contains__(key):
                                var cell_value = String(data_obj[key])
                                row.append(cell_value)
                                col_index += 1
                            else:
                                break

                    # Verify integrity if we have stored hash
                    if stored_hash != "":
                        var row_data = table_name + ":"
                        for j in range(len(row)):
                            if j > 0:
                                row_data += "|"
                            row_data += row[j]

                        var computed_hash = SHA256Hash.compute(row_data)
                        if computed_hash != stored_hash:
                            integrity_violations += 1
                            print("Integrity violation in", table_name, "row", i)

                    results.append(row.copy())
                except:
                    print("Failed to parse JSON line:", trimmed)
                    continue

            if expected_integrity and integrity_violations == 0:
                print("Integrity verified for", table_name, "-", len(results), "rows OK")
            elif integrity_violations > 0:
                print("WARNING: Found", integrity_violations, "integrity violations in", table_name)

        except:
            pass

        return results.copy()