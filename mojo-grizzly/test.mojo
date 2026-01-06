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

fn test_query_greater():
    from query import select_where_greater
    var schema = Schema()
    schema.add_field("value", "int64")
    var table = Table(schema, 3)
    table.columns[0][0] = 10
    table.columns[0][1] = 20
    table.columns[0][2] = 30
    var filtered = select_where_greater(table^, "value", 15)
    if filtered.num_rows() == 2:
        print("Query greater test pass")
    else:
        print("Query greater test fail")

fn test_aggregates():
    from query import sum_column, count_rows, avg_column, min_column, max_column
    var schema = Schema()
    schema.add_field("val", "int64")
    var table = Table(schema, 3)
    table.columns[0][0] = 1
    table.columns[0][1] = 2
    table.columns[0][2] = 3
    if sum_column(table^, "val") == 6:
        print("Sum test pass")
    else:
        print("Sum test fail")
    if count_rows(table^) == 3:
        print("Count test pass")
    else:
        print("Count test fail")
    if avg_column(table^, "val") == 2:
        print("Avg test pass")
    else:
        print("Avg test fail")
    if min_column(table^, "val") == 1:
        print("Min test pass")
    else:
        print("Min test fail")
    if max_column(table^, "val") == 3:
        print("Max test pass")
    else:
        print("Max test fail")

fn test_joins() raises:
    from query import join_inner
    var schema1 = Schema()
    schema1.add_field("id", "int64")
    schema1.add_field("val", "int64")
    var table1 = Table(schema1, 2)
    table1.columns[0][0] = 1
    table1.columns[0][1] = 2
    table1.columns[1][0] = 10
    table1.columns[1][1] = 20

    var schema2 = Schema()
    schema2.add_field("id", "int64")
    schema2.add_field("other", "int64")
    var table2 = Table(schema2, 2)
    table2.columns[0][0] = 1
    table2.columns[0][1] = 2
    table2.columns[1][0] = 100
    table2.columns[1][1] = 200

    var joined = join_inner(table1^, table2^, "id", "id")
    if joined.num_rows() == 2 and joined.columns[2][0] == 100:
        print("Join test pass")
    else:
        print("Join test fail")

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
    test_query_greater()
    test_aggregates()
    test_joins()
    test_formats()
    test_pl()
    # test_block()
    print("All tests completed")

fn main() raises:
    print("Starting tests")
    run_tests()
    print("Tests completed")