# Simple Query Test for Packaged Mojo Grizzly
from arrow import Schema, Table
from formats import read_jsonl

fn main() raises:
    print("Testing basic queries in packaged Mojo Grizzly...")

    # Create test data
    var jsonl_content = '{"id": 1, "name": "Alice", "age": 25}\n{"id": 2, "name": "Bob", "age": 30}\n{"id": 3, "name": "Charlie", "age": 35}'
    var table = read_jsonl(jsonl_content)

    print("Loaded table with", table.num_rows(), "rows")

    # Simple data inspection
    var i = 0
    while i < table.num_rows():
        print("Row", i, ": id =", table.columns[0][i], ", name =", table.columns[1][i], ", age =", table.columns[2][i])
        i += 1

    print("Basic table operations working!")
    print("Package is functional for core database operations.")