"""
Minimal JSON test
"""

from python import Python
from python import PythonObject


def main():
    print("Testing JSON reading...")

    try:
        # Import PyArrow JSON module
        pq = Python.import_module("pyarrow.json")

        # Create sample JSON Lines data
        jsonl_content = """{"user_id": 1, "event": "login", "timestamp": "2023-01-15T10:30:00Z", "metadata": {"ip": "192.168.1.1", "user_agent": "Chrome/91.0"}}
{"user_id": 2, "event": "purchase", "timestamp": "2023-01-15T10:35:00Z", "metadata": {"product_id": 123, "amount": 99.99}}
{"user_id": 1, "event": "logout", "timestamp": "2023-01-15T11:00:00Z", "metadata": {"session_duration": 1800}}"""

        # Write to temporary file
        json_file = "sample_events.jsonl"
        with open(json_file, "w") as f:
            f.write(jsonl_content)

        print("Created sample JSON Lines file:", json_file)

        # Read JSON with PyArrow
        table = pq.read_json(json_file)
        print("Successfully read JSON file")
        print("Table shape:", table.num_rows, "rows,", table.num_columns, "columns")

        # Clean up
        import os
        os.remove(json_file)
        print("Test completed successfully")

    except e:
        print("Test failed:", String(e))


main()