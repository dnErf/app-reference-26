from arrow import Table, Schema
from index import BTreeIndex

fn main() raises:
    var schema = Schema()
    schema.add_field("id", "int64")
    var table = Table(schema, 0)
    table.append_row(List[Int64](1))
    table.append_row(List[Int64](2))
    table.append_row(List[Int64](3))
    table.build_index("id")
    try:
        var index = table.indexes["id"].copy()
        var rows = index.lookup(2)
        print("Rows for 2: len =", len(rows))
        var range_rows = index.lookup_range(1, 3)
        print("Rows for 1-3: len =", len(range_rows))
    except:
        print("Error accessing index")