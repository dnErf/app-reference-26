"""
PyArrow ORC Data Storage
========================

Handles columnar data storage using PyArrow ORC format.
Provides efficient storage and retrieval of table data.
"""

from python import Python
from collections import List
from blob_storage import BlobStorage

struct ORCStorage:
    var storage: BlobStorage

    fn __init__(out self, storage: BlobStorage):
        self.storage = storage.copy()

    fn write_table(self, table_name: String, data: List[List[String]]) -> Bool:
        """Write table data in simplified format (JSON lines for now)."""
        try:
            var json_lines = ""
            for row in data:
                var json_row = "{"
                for i in range(len(row)):
                    if i > 0:
                        json_row += ","
                    json_row += "\"" + String(i) + "\":\"" + row[i] + "\""
                json_row += "}\n"
                json_lines += json_row

            return self.storage.write_blob("tables/" + table_name + ".jsonl", json_lines)
        except:
            return False

    fn read_table(self, table_name: String) -> List[List[String]]:
        """Read table data from simplified format."""
        var results = List[List[String]]()

        try:
            var jsonl_data = self.storage.read_blob("tables/" + table_name + ".jsonl")
            if jsonl_data == "":
                return results.copy()

            # Parse JSON lines (very basic parsing)
            var lines = jsonl_data.split("\n")
            for line in lines:
                var trimmed = String(line).strip()
                if trimmed == "":
                    continue

                var row = List[String]()
                # Very basic JSON parsing - extract values between quotes
                var in_value = False
                var current_value = ""
                var i = 0
                while i < len(trimmed):
                    var char = trimmed[i]
                    if char == "\"":
                        if in_value:
                            row.append(current_value)
                            current_value = ""
                        in_value = not in_value
                    elif in_value:
                        current_value += char
                    i += 1

                if len(row) > 0:
                    results.append(row.copy())

        except:
            pass

        return results.copy()