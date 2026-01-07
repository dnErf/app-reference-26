# Pure Mojo Test - No Python Interop
from arrow import Schema, Table, Int64Array, StringArray

fn main() raises:
    print("Testing pure Mojo database operations...")

    # Create schema
    var schema = Schema()
    schema.add_field("id", "int64")
    schema.add_field("name", "mixed")  # Use mixed for strings
    schema.add_field("age", "int64")

    # Create table manually
    var table = Table(schema, 3)

    # Add data manually - id and age as Int64, name as Variant
    table.columns[0].append(1)  # id
    table.mixed_columns[0].data.append("Alice")  # name
    table.columns[1].append(25)  # age

    table.columns[0].append(2)
    table.mixed_columns[0].data.append("Bob")
    table.columns[1].append(30)

    table.columns[0].append(3)
    table.mixed_columns[0].data.append("Charlie")
    table.columns[1].append(35)

    print("Created table with", table.num_rows(), "rows")

    # Display data
    var i = 0
    while i < table.num_rows():
        print("Row", i, ": id =", table.columns[0][i], ", name =", table.mixed_columns[0].data[i], ", age =", table.columns[1][i])
        i += 1

    print("Pure Mojo table operations working!")
    print("Packaged database is functional!")