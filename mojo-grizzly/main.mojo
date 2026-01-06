# Mojo Arrow Database Prototype
# High-performance columnar database using pure Mojo Arrow implementation
# Interoperable with JSONL, AVRO, ORC, etc.

from arrow import Schema, Table
from query import execute_query
from formats import read_jsonl

fn main():
    print("Starting Mojo Arrow Database...")

    # Demo JSONL reading
    var jsonl_content = '{"id": 1, "value": 10}\n{"id": 2, "value": 20}\n{"id": 3, "value": 30}'
    var table = read_jsonl(jsonl_content)

    print("Loaded table from JSONL:")
    for i in range(table.columns[0].length):
        print("Row", i, ": id =", table.columns[0][i], ", value =", table.columns[1][i])

    # Query: SELECT * FROM table WHERE value > 15
    var sql = "SELECT * FROM table WHERE value > 15"
    var result = execute_query(table, sql)

    print("\nQuery result (" + sql + "):")
    for i in range(result.columns[0].length):
        print("Row", i, ": id =", result.columns[0][i], ", value =", result.columns[1][i])

    print("JSONL reader and SQL parser implemented successfully!")