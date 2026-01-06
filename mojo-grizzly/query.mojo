# Simple Query Engine for Mojo Arrow Database
# SQL-like queries: SELECT * FROM table WHERE condition

from arrow import Table, Int64Array, Schema
from pl import call_function

# Simple filter: SELECT * FROM table WHERE column > value
fn select_where_greater(table: Table, column_name: String, value: Int64) -> Table:
    # Find column index
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        # Error, but for now return empty
        return Table(Schema(), 0)

    # Collect indices where condition holds
    var indices = List[Int]()
    for i in range(table.columns[col_index].length):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] > value:
            indices.append(i)

    # Create new table with filtered rows
    var new_table = Table(table.schema, len(indices))
    for row in range(len(indices)):
        let old_row = indices[row]
        for col in range(len(table.columns)):
            new_table.columns[col][row] = table.columns[col][old_row]

    return new_table

# Simple filter: SELECT * FROM table WHERE column == value
fn select_where_eq(table: Table, column_name: String, value: Int64) -> Table:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return Table(Schema(), 0)

    var indices = List[Int]()
    for i in range(table.columns[col_index].length):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] == value:
            indices.append(i)

    var new_table = Table(table.schema, len(indices))
    for row in range(len(indices)):
        let old_row = indices[row]
        for col in range(len(table.columns)):
            new_table.columns[col][row] = table.columns[col][old_row]

    return new_table

# Filter with function: WHERE func(column) == value
fn select_where_func_eq(table: Table, func_name: String, column_name: String, value: Int64) -> Table:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return Table(Schema(), 0)

    var indices = List[Int]()
    for i in range(table.columns[col_index].length):
        if table.columns[col_index].is_valid(i):
            let arg = table.columns[col_index][i]
            let result = await call_function(func_name, List[Int64](arg))
            if result == value:
                indices.append(i)

    var new_table = Table(table.schema, len(indices))
    for row in range(len(indices)):
        let old_row = indices[row]
        for col in range(len(table.columns)):
            new_table.columns[col][row] = table.columns[col][old_row]

    return new_table

# Basic SQL parser for "SELECT * FROM table WHERE column > value" or "WHERE func(column) == value"
fn parse_and_execute_sql(table: Table, sql: String) -> Table:
    # Simple parsing: split by spaces
    var parts = sql.split(" ")
    if len(parts) < 7 or parts[0] != "SELECT" or parts[1] != "*" or parts[2] != "FROM" or parts[4] != "WHERE":
        # Invalid, return original
        return table

    var table_name = parts[3]
    var condition = " ".join(parts[5:])  # Rest is condition
    # Assume condition like "column > value" or "func(column) == value"

    # For now, handle simple > and func == 
    if ">" in condition:
        var cond_parts = condition.split(">")

        var column = cond_parts[0].strip()
        var value_str = cond_parts[1].strip()
        var value = atol(value_str)
        return select_where_greater(table, column, value)
    elif "==" in condition:
        var cond_parts = condition.split("==")
        var left = cond_parts[0].strip()
        var right_str = cond_parts[1].strip()
        var right = atol(right_str)
        if "(" in left and ")" in left:
            # Function call: func(column)
            var paren = left.find("(")
            var func_name = left[:paren]
            var arg = left[paren+1:left.find(")")].strip()
            return select_where_func_eq(table, func_name, arg, right)
        else:
            # Column == value
            return select_where_eq(table, left, right)
    else:
        return table  # Unsupported

# General execute query
fn execute_query(table: Table, sql: String) -> Table:
    return parse_and_execute_sql(table, sql)