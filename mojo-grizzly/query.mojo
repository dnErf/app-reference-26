# Simple Query Engine for Mojo Arrow Database
# SQL-like queries: SELECT * FROM table WHERE condition

from arrow import Table, Int64Array, Schema
from pl import call_function
from index import HashIndex

struct QueryResult(Movable):
    var table: Table
    var error: String

    fn __init__(out self, var table: Table, error: String):
        self.table = table^
        self.error = error

    fn __moveinit__(out self, deinit existing: QueryResult):
        self.table = existing.table^
        self.error = existing.error

# Error types as strings
# enum QueryError:
#     ColumnNotFound
#     InvalidSQL
#     ParseError
#     TypeMismatch
#     SubqueryFailed

# Advanced JOINs
fn join_left(table1: Table, table2: Table, key1: String, key2: String) -> Table:
    # Left join: all from table1, matching from table2
    var result_schema = Schema()
    for field in table1.schema.fields:
        result_schema.add_field("t1_" + field.name, field.data_type)
    for field in table2.schema.fields:
        result_schema.add_field("t2_" + field.name, field.data_type)
    var result = Table(result_schema, 0)
    # Build hash for table2
    var hash_map = Dict[Int64, Int]()
    var col2_idx = -1
    for i in range(len(table2.schema.fields)):
        if table2.schema.fields[i].name == key2:
            col2_idx = i
    for i in range(table2.num_rows):
        hash_map[table2.columns[col2_idx][i]] = i
    # Join
    var col1_idx = -1
    for i in range(len(table1.schema.fields)):
        if table1.schema.fields[i].name == key1:
            col1_idx = i
    for i in range(table1.num_rows):
        let key_val = table1.columns[col1_idx][i]
        result.append_row()
        # Copy table1
        for j in range(len(table1.columns)):
            result.columns[j][result.num_rows-1] = table1.columns[j][i]
        # Copy table2 if match
        if key_val in hash_map:
            let idx2 = hash_map[key_val]
            for j in range(len(table2.columns)):
                result.columns[len(table1.columns) + j][result.num_rows-1] = table2.columns[j][idx2]
        # Else nulls
    return result

# Similar for right and full
fn join_right(table1: Table, table2: Table, key1: String, key2: String) -> Table:
    return join_left(table2, table1, key2, key1)  # Swap

fn join_full(table1: Table, table2: Table, key1: String, key2: String) -> Table:
    # Placeholder: combine left and right, remove duplicates
    let left = join_left(table1, table2, key1, key2)
    let right = join_right(table1, table2, key1, key2)
    # Merge (simplified)
    return left

# Subquery support
fn execute_subquery(sub_sql: String, table: Table) -> Table:
    # Simple: assume SELECT * FROM table WHERE ...
    if "WHERE" in sub_sql:
        let parts = sub_sql.split("WHERE")
        let condition = parts[1].strip()
        return filter_table(table, condition)
    return table

fn filter_table(table: Table, condition: String) -> Table:
    # Simplified filter
    if "==" in condition:
        let parts = condition.split("==")
        let col = parts[0].strip()
        let val_str = parts[1].strip()
        # Check type
        let col_idx = -1
        for i in range(len(table.schema.fields)):
            if table.schema.fields[i].name == col:
                col_idx = i
                break
        if col_idx == -1:
            return Table(Schema(), 0)
        let data_type = table.schema.fields[col_idx].data_type
        if data_type == "int64":
            let val = atol(val_str)
            return select_where_eq(table, col, val)[0]
        elif data_type == "date32":
            let val = atol(val_str)  # Assume days
            return select_where_eq(table, col, val)[0]
        # Add more types
    return table

fn select_where_greater(table: Table, column_name: String, value: Int64) -> Tuple[Table, String]:
    # Find column index
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return Table(Schema(), 0), "Column not found: " + column_name

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

    return new_table, ""
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
fn select_where_eq(var table: Table, column_name: String, value: Int64) raises -> Table:
    var filtered = Table(table.schema.clone(), 0)
    var col_index = -1
    for i in range(len(table.schema.field_names)):
        if table.schema.field_names[i] == column_name:
            col_index = i
            break
    if col_index == -1:
        return Table(table.schema, 0)
    # Use index if available
    if column_name in table.indexes:
        var row_indices = table.indexes[column_name].lookup(value)
        for row in row_indices:
            for c in range(len(table.columns)):
                filtered.columns[c].append(table.columns[c][row])
    else:
        for row in range(table.num_rows()):
            if table.columns[col_index][row] == value:
                for c in range(len(table.columns)):
                    filtered.columns[c].append(table.columns[c][row])
    return filtered^

# Filter with function: WHERE func(column) == value
async fn select_where_func_eq(table: Table, func_name: String, column_name: String, value: Int64) -> Table:
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
            var arg = table.columns[col_index][i]
            var result = await call_function(func_name, List[Int64](arg))
            if result == value:
                indices.append(i)

    var new_table = Table(table.schema, len(indices))
    for row in range(len(indices)):
        let old_row = indices[row]
        for col in range(len(table.columns)):
            new_table.columns[col][row] = table.columns[col][old_row]

    return new_table

# Aggregates
fn sum_column(table: Table, column_name: String) -> Int64:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1: return 0
    var total = 0
    for i in range(table.columns[col_index].length):
        if table.columns[col_index].is_valid(i):
            total += table.columns[col_index][i]
    return total

fn count_rows(table: Table) -> Int64:
    return table.columns[0].length

fn avg_column(table: Table, column_name: String) -> Float64:
    let s = sum_column(table, column_name)
    let c = count_rows(table)
    return Float64(s) / Float64(c)

fn min_column(table: Table, column_name: String) -> Int64:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1: return 0
    var min_val = 9223372036854775807  # max int64
    for i in range(table.columns[col_index].length):
        if table.columns[col_index].is_valid(i):
            min_val = min(min_val, table.columns[col_index][i])
    return min_val

fn max_column(table: Table, column_name: String) -> Int64:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1: return 0
    var max_val = -9223372036854775808  # min int64
    for i in range(table.columns[col_index].length):
        if table.columns[col_index].is_valid(i):
            max_val = max(max_val, table.columns[col_index][i])
    return max_val

# Basic SQL parser for "SELECT * FROM table WHERE column > value" or "WHERE func(column) == value"
async fn parse_and_execute_sql(table: Table, sql: String) -> Table:
    # Simple parsing: split by spaces
    var parts = sql.split(" ")
    if "SUM(" in sql:
        let sum_start = sql.find("SUM(") + 4
        let sum_end = sql.find(")", sum_start)
        let column = sql[sum_start:sum_end].strip()
        let result = sum_column(table, column)
        var schema = Schema()
        schema.fields = List[Field](Field("sum", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table
    elif "COUNT(*)" in sql:
        let result = count_rows(table)
        var schema = Schema()
        schema.fields = List[Field](Field("count", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table
    elif "AVG(" in sql:
        let avg_start = sql.find("AVG(") + 4
        let avg_end = sql.find(")", avg_start)
        let column = sql[avg_start:avg_end].strip()
        let result = avg_column(table, column)
        var schema = Schema()
        schema.fields = List[Field](Field("avg", "float64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Float64Array](Float64Array(1))
        result_table.columns[0][0] = result
        return result_table
    elif "MIN(" in sql:
        let min_start = sql.find("MIN(") + 4
        let min_end = sql.find(")", min_start)
        let column = sql[min_start:min_end].strip()
        let result = min_column(table, column)
        var schema = Schema()
        schema.fields = List[Field](Field("min", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table
    elif "MAX(" in sql:
        let max_start = sql.find("MAX(") + 4
        let max_end = sql.find(")", max_start)
        let column = sql[max_start:max_end].strip()
        let result = max_column(table, column)
        var schema = Schema()
        schema.fields = List[Field](Field("max", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table
    elif "GROUP BY" in sql:
        # Simple: SELECT SUM(col) FROM table GROUP BY group_col
        let sum_start = sql.find("SUM(") + 4
        let sum_end = sql.find(")", sum_start)
        let sum_col = sql[sum_start:sum_end].strip()
        let group_start = sql.find("GROUP BY ") + 9
        let group_col = sql[group_start:].strip()
        # Group
        var groups = Dict[Int64, Int64]()
        var group_idx = -1
        for i in range(len(table.schema.fields)):
            if table.schema.fields[i].name == group_col:
                group_idx = i
                break
        var sum_idx = -1
        for i in range(len(table.schema.fields)):
            if table.schema.fields[i].name == sum_col:
                sum_idx = i
                break
        for i in range(table.columns[0].length):
            if table.columns[group_idx].is_valid(i) and table.columns[sum_idx].is_valid(i):
                let g = table.columns[group_idx][i]
                let s = table.columns[sum_idx][i]
                if g not in groups:
                    groups[g] = 0
                groups[g] += s
        # Return table
        var schema = Schema()
        schema.fields = List[Field](Field(group_col, "int64"), Field("sum", "int64"))
        var result_table = Table(schema, len(groups))
        result_table.columns = List[Int64Array](Int64Array(len(groups)), Int64Array(len(groups)))
        var row = 0
        for g in groups:
            result_table.columns[0][row] = g[]
            result_table.columns[1][row] = groups[g[]]
            row += 1
        return result_table
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
            return await select_where_func_eq(table, func_name, arg, right)
        else:
            # Column == value
            return select_where_eq(table, left, right)
    else:
        return table  # Unsupported

# General execute query
async fn execute_query(table: Table, sql: String) -> Table:
    return await parse_and_execute_sql(table, sql)