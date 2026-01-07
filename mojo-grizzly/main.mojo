# Mojo Arrow Database Prototype
# High-performance columnar database using pure Mojo Arrow implementation
# Interoperable with JSONL, AVRO, ORC, etc.

from arrow import Schema, Table
from query import execute_query, join_inner
from formats import read_jsonl

fn demo() raises:
    print("Starting Mojo Arrow Database...")

    # Demo JSONL reading
    var jsonl_content1 = '{"id": 1, "value": 10}\n{"id": 2, "value": 20}\n{"id": 3, "value": 30}'
    var table1 = read_jsonl(jsonl_content1)

    var jsonl_content2 = '{"id": 1, "other": 100}\n{"id": 2, "other": 200}'
    var table2 = read_jsonl(jsonl_content2)

    var i = 0
    while i < table1.num_rows():
        print("Row", i, ": id =", table1.columns[0][i], ", value =", table1.columns[1][i])
        i += 1

    print("Loaded table2 from JSONL:")
    i = 0
    while i < table2.num_rows():
        print("Row", i, ": id =", table2.columns[0][i], ", other =", table2.columns[1][i])
        i += 1

    # Join: simulate SELECT * FROM table1 JOIN table2 ON table1.id == table2.id
    from query import join_inner
    var joined = join_inner(table1, table2, "id", "id")

    print("\nJoined table:")
    i = 0
    while i < joined.num_rows():
        print("Row", i, ": id =", joined.columns[0][i], ", value =", joined.columns[1][i], ", id2 =", joined.columns[2][i], ", other =", joined.columns[3][i])
        i += 1

    # Query: SELECT * FROM table WHERE value > 15
    var sql = "SELECT * FROM table WHERE value > 15"
    var tables = Dict[String, Table]()
    try:
        var result = execute_query(table1, sql, tables)
        print("\nQuery result (" + sql + "):")
        i = 0
        while i < result.num_rows():
            print("Row", i, ": id =", result.columns[0][i], ", value =", result.columns[1][i])
            i += 1
    except e:
        print("Query error:", e)

    print("JSONL reader and SQL parser implemented successfully!")

fn main():
    try:
        demo()
    except e:
        print("Error:", e)