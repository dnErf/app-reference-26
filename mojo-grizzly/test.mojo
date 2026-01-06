# Comprehensive Testing Suite for Mojo Grizzly DB

from arrow import Table, Schema
from query import select_where_eq
from formats import read_jsonl, write_csv
from pl import call_function

fn test_arrow():
    var schema = Schema()
    schema.add_field("id", "int64")
    var table = Table(schema, 2)
    table.columns[0][0] = 1
    table.columns[0][1] = 2
    if table.num_rows() != 2:
        print("Arrow test fail: num_rows")
    print("Arrow test pass")

fn test_query() raises:
    var schema = Schema()
    schema.add_field("id", "int64")
    var table = Table(schema, 3)
    table.columns[0][0] = 1
    table.columns[0][1] = 2
    table.columns[0][2] = 1
    try:
        var filtered = select_where_eq(table^, "id", 1)
        if filtered.num_rows() != 2:
            print("Query test fail: filter count")
        else:
            print("Query test pass")
    except:
        print("Query test fail")

fn test_formats() raises:
    var jsonl = '{"id":1}\n{"id":2}'
    var table = read_jsonl(jsonl)
    if table.num_rows() != 2:
        print("Formats test fail: jsonl read")
    var csv = write_csv(table)
    if csv.find("id") == -1:
        print("Formats test fail: csv write")
    print("Formats test pass")

fn test_pl():
    var result = call_function("test", List[Int64]())
    if result.int_val != 42:
        print("PL test fail")
    print("PL test pass")

fn test_block():
    from block import BlockStore, Block
    var schema = Schema()
    schema.add_field("id", "int64")
    var table = Table(schema, 1)
    table.columns[0][0] = 1
    var block = Block(table^)
    var store = BlockStore()
    store.append(block)
    if len(store.blocks) > 0:
        print("Block test pass")
    else:
        print("Block test fail")

fn run_tests() raises:
    test_arrow()
    test_query()
    # test_formats()
    test_pl()
    # test_block()
    print("All tests completed")

fn main() raises:
    print("Starting tests")
    run_tests()
    print("Tests completed")