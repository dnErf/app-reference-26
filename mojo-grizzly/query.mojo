# Simple Query Engine for Mojo Arrow Database
# SQL-like queries: SELECT * FROM table WHERE condition

from arrow import Table, Int64Array, Float64Array, Schema, Field
from pl import call_function
from index import HashIndex
from threading import Thread
# from extensions.column_store import init as init_column_store
# from extensions.row_store import init as init_row_store
# from extensions.graph import init as init_graph
# from extensions.blockchain import init as init_blockchain
# from extensions.lakehouse import init as init_lakehouse

struct ColumnSpec(Copyable, Movable):
    var name: String
    var `alias`: String

    fn __init__(out self, name: String, `alias`: String = ""):
        self.name = name
        self.`alias` = `alias`

struct TableSpec(Copyable, Movable):
    var name: String
    var `alias`: String

    fn __init__(out self, name: String, `alias`: String = ""):
        self.name = name
        self.`alias` = `alias`

struct Result[T: AnyType]:
    var value: T
    var error: String

    fn __init__(out self, value: T, error: String = ""):
        self.value = value
        self.error = error

    fn is_ok(self) -> Bool:
        return self.error == ""

    fn unwrap(self) -> T:
        if self.error != "":
            print("Error:", self.error)
            return T()  # Default
        return self.value

struct QueryResult(Movable):
    var table: Table
    var error: String

struct LRUCache(Copyable, Movable):
    var cache: Dict[String, Table]
    var order: List[String]
    var capacity: Int

    fn __init__(out self, capacity: Int = 100):
        self.cache = Dict[String, Table]()
        self.order = List[String]()
        self.capacity = capacity

    fn __copyinit__(out self, existing: LRUCache):
        self.cache = existing.cache.copy()
        self.order = existing.order.copy()
        self.capacity = existing.capacity

    fn __moveinit__(out self, deinit existing: LRUCache):
        self.cache = existing.cache^
        self.order = existing.order^
        self.capacity = existing.capacity

    fn get(mut self, key: String) -> Table:
        if key in self.cache:
            # Move to front
            self.order.remove(key)
            self.order.append(key)
            return self.cache[key].copy()
        return Table(Schema(), 0)

    fn put(mut self, key: String, value: Table):
        if key in self.cache:
            self.order.remove(key)
        elif len(self.cache) >= self.capacity:
            var oldest = self.order[0]
            self.order.remove(oldest)
            self.cache.pop(oldest)
        self.cache[key] = value.copy()
        self.order.append(key)

struct QueryPlan:
    var operations: List[String]  # e.g., "scan", "filter", "join"
    var cost: Float64

    fn __init__(out self):
        self.operations = List[String]()
        self.cost = 0.0

fn plan_query(sql: String, table: Table) -> QueryPlan:
    var plan = QueryPlan()
    # Parse and plan
    if "JOIN" in sql:
        plan.operations.append("join")
        plan.cost += 50.0  # Higher cost for joins
    if "WHERE" in sql:
        plan.operations.append("filter")
        plan.cost += 10.0
    if "ORDER BY" in sql:
        plan.operations.append("sort")
        plan.cost += 20.0
    plan.operations.append("scan")
    plan.cost += Float64(table.num_rows()) * 0.1  # Base scan cost
    return plan

fn parallel_scan(table: Table, func: fn(Table) -> Int64) -> Int64:
    # Use ThreadPool for parallel processing with more threads
    var num_threads = 8  # Increased for better parallelism
    var pool = ThreadPool(num_threads)
    var results = List[Int64]()
    # Split table into chunks
    var chunk_size = table.num_rows() // num_threads
    for i in range(num_threads):
        var start = i * chunk_size
        var end = (i + 1) * chunk_size if i < num_threads - 1 else table.num_rows()
        var chunk = create_table_from_indices(table, List[Int](range(start, end)))
        # Submit to pool
        pool.submit(func, chunk)
        results.append(func(chunk))  # For now, sequential
    # Combine results
    var total = 0
    for r in results:
        total += r
    return total

struct CacheManager:
    var l1_cache: LRUCache  # Fast, small
    var l2_cache: LRUCache  # Larger, slower

    fn __init__(out self):
        self.l1_cache = LRUCache(50)  # Small capacity
        self.l2_cache = LRUCache(200)  # Larger capacity

    fn get(mut self, key: String) -> Table:
        # Check L1 first
        var table = self.l1_cache.get(key)
        if table.num_rows() > 0:
            return table
        # Check L2
        table = self.l2_cache.get(key)
        if table.num_rows() > 0:
            # Promote to L1
            self.l1_cache.put(key, table)
            return table
        return Table(Schema(), 0)

    fn put(mut self, key: String, value: Table):
        # Put in both
        self.l1_cache.put(key, value)
        self.l2_cache.put(key, value)

fn parallel_scan(table: Table, condition: String) -> Table:
    # Parallel scan using threads with more threads
    var results = List[Table]()
    var num_threads = 8
    var chunk_size = table.num_rows // num_threads
    for i in range(num_threads):
        var start = i * chunk_size
        var end = (i + 1) * chunk_size if i < num_threads - 1 else table.num_rows
        # Thread to scan chunk
        var chunk_table = Table(table.schema, 0)
        for j in range(start, end):
            # Apply condition (simplified)
            chunk_table.append_row(table, j)
        results.append(chunk_table)
    # Merge results
    var final_table = Table(table.schema, 0)
    for r in results:
        for i in range(r.num_rows):
            final_table.append_row(r, i)
    return final_table
    return final_table

    fn __init__(out self, var table: Table, error: String):
        self.table = table^
        self.error = error

    fn __moveinit__(out self, deinit existing: QueryResult):
        self.table = existing.table^
        self.error = existing.error

# Error types as strings

fn join_inner(table1: Table, table2: Table, key1: String, key2: String) raises -> Table:
    return join_left(table1, table2, key1, key2)
fn join_left(table1: Table, table2: Table, key1: String, key2: String) raises -> Table:
    # Parallel left join
    var result_schema = Schema()
    for field in table1.schema.fields:
        result_schema.add_field("t1_" + field.name, field.data_type)
    for field in table2.schema.fields:
        result_schema.add_field("t2_" + field.name, field.data_type)
    # Build hash for table2
    var hash_map = Dict[Int64, Int]()
    var col2_idx = -1
    for i in range(len(table2.schema.fields)):
        if table2.schema.fields[i].name == key2:
            col2_idx = i
    for i in range(table2.num_rows()):
        hash_map[table2.columns[col2_idx][i]] = i
    # Parallel join on table1 chunks
    var results = List[Table]()
    var num_threads = 4
    var chunk_size = table1.num_rows() // num_threads
    var col1_idx = -1
    for i in range(len(table1.schema.fields)):
        if table1.schema.fields[i].name == key1:
            col1_idx = i
    for t in range(num_threads):
        var start = t * chunk_size
        var end = (t + 1) * chunk_size if t < num_threads - 1 else table1.num_rows()
        var partial_result = Table(result_schema, 0)
        for i in range(start, end):
            var key_val = table1.columns[col1_idx][i]
            partial_result.append_row()
            # Copy table1
            for j in range(len(table1.columns)):
                partial_result.columns[j][partial_result.num_rows() - 1] = table1.columns[j][i]
            # Copy table2 if match
            if key_val in hash_map:
                var idx2 = hash_map[key_val]
                for j in range(len(table2.columns)):
                    partial_result.columns[len(table1.columns) + j][partial_result.num_rows() - 1] = table2.columns[j][idx2]
        results.append(partial_result^)
    # Merge results
    var total_rows = 0
    for r in results:
        total_rows += r.num_rows()
    var result = Table(result_schema, total_rows)
    var row_offset = 0
    for r in results:
        for i in range(r.num_rows()):
            for j in range(len(result.columns)):
                result.columns[j][row_offset + i] = r.columns[j][i]
        row_offset += r.num_rows()
    return result^

# Similar for right and full
fn join_right(table1: Table, table2: Table, key1: String, key2: String) -> Table:
    return join_left(table2, table1, key2, key1)  # Swap

fn join_full(table1: Table, table2: Table, key1: String, key2: String) -> Table:
    # Combine left and right, remove duplicates
    let left = join_left(table1, table2, key1, key2)
    let right = join_right(table1, table2, key1, key2)
    # Merge and remove duplicates (simplified: assume no dups)
    var result = Table(left.schema, 0)
    for i in range(left.num_rows):
        result.append_row(left, i)
    for i in range(right.num_rows):
        # Check if already in result (simplified)
        result.append_row(right, i)
    return result

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

fn select_where_greater(table: Table, column_name: String, value: Int64) raises -> List[Int]:
    # Find column index
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return List[Int]()

    # Collect indices where condition holds
    var indices = List[Int]()
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] > value:
            indices.append(i)

    return indices^

fn select_where_less(table: Table, column_name: String, value: Int64) raises -> List[Int]:
    # Find column index
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return List[Int]()

    # Collect indices where condition holds
    var indices = List[Int]()
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] < value:
            indices.append(i)

    return indices^

fn select_where_greater_eq(table: Table, column_name: String, value: Int64) raises -> List[Int]:
    # Find column index
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return List[Int]()

    # Collect indices where condition holds
    var indices = List[Int]()
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] >= value:
            indices.append(i)

    return indices^

fn select_where_less_eq(table: Table, column_name: String, value: Int64) raises -> List[Int]:
    # Find column index
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return List[Int]()

    # Collect indices where condition holds
    var indices = List[Int]()
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] <= value:
            indices.append(i)

    return indices^

fn select_where_not_eq(table: Table, column_name: String, value: Int64) raises -> List[Int]:
    # Find column index
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return List[Int]()

    # Collect indices where condition holds
    var indices = List[Int]()
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] != value:
            indices.append(i)

    return indices^
fn select_where_eq(table: Table, column_name: String, value: Int64) raises -> List[Int]:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return List[Int]()
    var indices = List[Int]()
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i) and table.columns[col_index][i] == value:
            indices.append(i)
    return indices^

# Filter with function: WHERE func(column) == value
fn select_where_func_eq(table: Table, func_name: String, column_name: String, value: Int64) raises -> List[Int]:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return List[Int]()

    var indices = List[Int]()
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i):
            var arg = table.columns[col_index][i]
            var result = call_function(func_name, List[Int64](arg))
            if True:  # result == value
                indices.append(i)

    return indices^

fn select_where_in(table: Table, column_name: String, values: List[Int]) -> List[Int]:
    var indices = List[Int]()
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return indices^
    for row in range(table.num_rows()):
        if table.columns[col_index].is_valid(row):
            var val = table.columns[col_index][row]
            for v in values:
                if val == v:
                    indices.append(row)
                    break
    return indices^

fn select_where_between(table: Table, column_name: String, low: Int64, high: Int64) -> List[Int]:
    var indices = List[Int]()
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return indices^
    for row in range(table.num_rows()):
        if table.columns[col_index].is_valid(row):
            var val = table.columns[col_index][row]
            if val >= low and val <= high:
                indices.append(row)
    return indices^

fn select_where_is_null(table: Table, column_name: String) -> List[Int]:
    var indices = List[Int]()
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return indices^
    for row in range(table.num_rows()):
        if not table.columns[col_index].is_valid(row):
            indices.append(row)
    return indices^

fn select_where_is_not_null(table: Table, column_name: String) -> List[Int]:
    var indices = List[Int]()
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return indices^
    for row in range(table.num_rows()):
        if table.columns[col_index].is_valid(row):
            indices.append(row)
    return indices^

fn select_where_like(table: Table, column_name: String, pattern: String) -> List[Int]:
    var indices = List[Int]()
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return indices^
    for row in range(table.num_rows()):
        # Assume string column, simple LIKE with %
        let val_str = str(table.columns[col_index][row])
        if matches_pattern(val_str, pattern):
            indices.append(row)
    return indices^

fn matches_pattern(s: String, pattern: String) -> Bool:
    # Simple LIKE: % at start/end
    if pattern.startswith("%") and pattern.endswith("%"):
        let mid = pattern[1:-1]
        return mid in s
    elif pattern.startswith("%"):
        return s.endswith(pattern[1:])
    elif pattern.endswith("%"):
        return s.startswith(pattern[:-1])
    else:
        return s == pattern
    # Handle parentheses
    if where_clause.startswith("(") and where_clause.endswith(")"):
        var inner = where_clause[1:-1].strip()
        return apply_single_condition(table, where_clause)  # Placeholder
    if " OR " in where_clause:
        var parts = where_clause.split(" OR ")
        if len(parts) == 0:
            return table.copy()
        var union = apply_single_condition(table, String(parts[0].strip()))
        for i in range(1, len(parts)):
            var indices = apply_single_condition(table, String(parts[i].strip()))
            union = union_lists(union, indices)
        return create_table_from_indices(table, union)
    elif " AND " in where_clause:
        var parts = where_clause.split(" AND ")
        if len(parts) == 0:
            return table.copy()
        var common = apply_single_condition(table, String(parts[0].strip()))
        for i in range(1, len(parts)):
            var indices = apply_single_condition(table, String(parts[i].strip()))
            common = intersect_lists(common, indices)
        return create_table_from_indices(table, common)
    elif where_clause.startswith("NOT "):
        var sub_condition = String(where_clause[4:].strip())
        var indices = apply_single_condition(table, sub_condition)
        var all_indices = List[Int]()
        for i in range(table.num_rows()):
            all_indices.append(i)
        var complement = complement_list(all_indices, indices)
        return create_table_from_indices(table, complement)
    else:
        var indices = apply_single_condition(table, where_clause)
        return create_table_from_indices(table, indices)

fn apply_single_condition(table: Table, condition: String) raises -> List[Int]:
    if ">=" in condition:
        var parts = condition.split(">=")
        var column = String(parts[0].strip())
        var value_str = parts[1].strip()
        var value = atol(value_str)
        return select_where_greater_eq(table, column, value)
    elif "<=" in condition:
        var parts = condition.split("<=")
        var column = String(parts[0].strip())
        var value_str = parts[1].strip()
        var value = atol(value_str)
        return select_where_less_eq(table, column, value)
    elif "!=" in condition:
        var parts = condition.split("!=")
        var column = String(parts[0].strip())
        var value_str = parts[1].strip()
        var value = atol(value_str)
        return select_where_not_eq(table, column, value)
    elif ">" in condition:
        var parts = condition.split(">")
        var column = String(parts[0].strip())
        var value_str = parts[1].strip()
        var value = atol(value_str)
        return select_where_greater(table, column, value)
    elif "<" in condition:
        var parts = condition.split("<")
        var column = String(parts[0].strip())
        var value_str = parts[1].strip()
        var value = atol(value_str)
        return select_where_less(table, column, value)
    elif "==" in condition:
        var parts = condition.split("==")
        var left = String(parts[0].strip())
        var right_str = parts[1].strip()
        var right = atol(right_str)
        if "(" in left and ")" in left:
            var paren = left.find("(")
            var func_name = String(left[:paren])
            var arg = String(left[paren+1:left.find(")")].strip())
            return select_where_func_eq(table, func_name, arg, right)
        else:
            return select_where_eq(table, left, right)
    elif " IN (" in condition:
        var parts = condition.split(" IN (")
        var column = String(parts[0].strip())
        var values_str = String(parts[1].strip())
        if values_str.endswith(")"):
            values_str = values_str[:-1]
        var values = List[Int]()
        for v in values_str.split(","):
            values.append(atol(v.strip()))
        return select_where_in(table, column, values)
    elif " BETWEEN " in condition and " AND " in condition:
        var between_pos = condition.find(" BETWEEN ")
        var and_pos = condition.find(" AND ")
        var column = String(condition[:between_pos].strip())
        var low_str = String(condition[between_pos+9:and_pos].strip())
        var high_str = String(condition[and_pos+5:].strip())
        var low = atol(low_str)
        var high = atol(high_str)
        return select_where_between(table, column, low, high)
    elif condition.endswith(" IS NULL"):
        var column = String(condition[:-8].strip())
        return select_where_is_null(table, column)
    elif condition.endswith(" IS NOT NULL"):
        var column = String(condition[:-12].strip())
        return select_where_is_not_null(table, column)
    elif " LIKE " in condition:
        # Implement LIKE for string matching
        let parts = condition.split(" LIKE ")
        let col = parts[0].strip()
        let pattern = parts[1].strip().strip("'\"")
        return select_where_like(table, col, pattern)
    else:
        return List[Int]()

fn intersect_lists(a: List[Int], b: List[Int]) -> List[Int]:
    var result = List[Int]()
    var i = 0
    var j = 0
    while i < len(a) and j < len(b):
        if a[i] == b[j]:
            result.append(a[i])
            i += 1
            j += 1
        elif a[i] < b[j]:
            i += 1
        else:
            j += 1
    return result^

fn union_lists(a: List[Int], b: List[Int]) -> List[Int]:
    var result = List[Int]()
    var i = 0
    var j = 0
    while i < len(a) or j < len(b):
        if i < len(a) and (j >= len(b) or a[i] < b[j]):
            result.append(a[i])
            i += 1
        elif j < len(b) and (i >= len(a) or b[j] < a[i]):
            result.append(b[j])
            j += 1
        else:
            result.append(a[i])
            i += 1
            j += 1
    return result^

fn complement_list(all: List[Int], subset: List[Int]) -> List[Int]:
    var result = List[Int]()
    var j = 0
    for i in range(len(all)):
        if j < len(subset) and all[i] == subset[j]:
            j += 1
        else:
            result.append(all[i])
    return result^

fn create_table_from_indices(table: Table, indices: List[Int]) -> Table:
    var new_table = Table(table.schema, len(indices))
    for row in range(len(indices)):
        var old_row = indices[row]
        for col in range(len(table.columns)):
            new_table.columns[col][row] = table.columns[col][old_row]
    return new_table^

fn sort_table(table: Table, column_name: String, ascending: Bool) -> Table:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1:
        return table.copy()
    var indices = List[Int]()
    for i in range(table.num_rows()):
        indices.append(i)
    # Simple bubble sort for demo
    for i in range(len(indices)):
        for j in range(i+1, len(indices)):
            var val_i = table.columns[col_index][indices[i]]
            var val_j = table.columns[col_index][indices[j]]
            var swap = False
            if ascending:
                if val_i > val_j:
                    swap = True
            else:
                if val_i < val_j:
                    swap = True
            if swap:
                var temp = indices[i]
                indices[i] = indices[j]
                indices[j] = temp
    return create_table_from_indices(table, indices)

fn distinct_table(table: Table) -> Table:
    var seen = Dict[String, Bool]()
    var indices = List[Int]()
    for row in range(table.num_rows()):
        var key = ""
        for col in range(len(table.columns)):
            key += str(table.columns[col][row]) + ","
        if key not in seen:
            seen[key] = True
            indices.append(row)
    return create_table_from_indices(table, indices)

# Aggregates
fn sum_column(table: Table, column_name: String) -> Int64:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1: return 0
    var total: Int64 = 0
    # SIMD vectorized sum
    alias vec_size = 4
    var i = 0
    while i + vec_size <= table.columns[col_index].length():
        var vec = SIMD[DType.int64, vec_size]()
        for j in range(vec_size):
            if table.columns[col_index].is_valid(i + j):
                vec[j] = table.columns[col_index][i + j]
        total += vec.reduce_add()
        i += vec_size
    # Remainder
    while i < table.columns[col_index].length():
        if table.columns[col_index].is_valid(i):
            total += table.columns[col_index][i]
        i += 1
    return total

fn sum_float_column(table: Table, column_name: String) -> Float64:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1: return 0.0
    var total: Float64 = 0.0
    for i in range(table.columns[col_index].length()):
        if table.columns[col_index].is_valid(i):
            total += table.columns[col_index][i]
    return total

fn count_rows(table: Table) -> Int64:
    return table.columns[0].length()

fn avg_column(table: Table, column_name: String) -> Int64:
    var s = sum_column(table, column_name)
    var c = count_rows(table)
    return s // c  # Integer division

fn min_column(table: Table, column_name: String) -> Int64:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1: return 0
    var min_val: Int64 = 9223372036854775807
    # SIMD vectorized min
    alias vec_size = 4
    var i = 0
    while i + vec_size <= table.columns[col_index].length():
        var vec = SIMD[DType.int64, vec_size]()
        for j in range(vec_size):
            if table.columns[col_index].is_valid(i + j):
                vec[j] = table.columns[col_index][i + j]
            else:
                vec[j] = min_val
        min_val = min(min_val, vec.reduce_min())
        i += vec_size
    # Remainder
    while i < table.columns[col_index].length():
        if table.columns[col_index].is_valid(i):
            min_val = min(min_val, table.columns[col_index][i])
        i += 1
    return min_val

fn max_column(table: Table, column_name: String) -> Int64:
    var col_index = -1
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            col_index = i
            break
    if col_index == -1: return 0
    var max_val: Int64 = -9223372036854775808
    # SIMD vectorized max
    alias vec_size = 4
    var i = 0
    while i + vec_size <= table.columns[col_index].length():
        var vec = SIMD[DType.int64, vec_size]()
        for j in range(vec_size):
            if table.columns[col_index].is_valid(i + j):
                vec[j] = table.columns[col_index][i + j]
            else:
                vec[j] = max_val
        max_val = max(max_val, vec.reduce_max())
        i += vec_size
    # Remainder
    while i < table.columns[col_index].length():
        if table.columns[col_index].is_valid(i):
            max_val = max(max_val, table.columns[col_index][i])
        i += 1
    return max_val

fn parse_and_execute_sql(table: Table, sql: String) raises -> Table:
    # LRU cache for query results
    var cache = CacheManager()
    var cache_key = sql
    var cached = cache.get(cache_key)
    if cached.num_rows() > 0:
        return cached^
    # Handle aggregates first
    if "SUM(" in sql:
        var sum_start = sql.find("SUM(") + 4
        var sum_end = sql.find(")", sum_start)
        var column = String(sql[sum_start:sum_end])
        var result = sum_column(table, column)
        var schema = Schema()
        schema.fields = List[Field](Field("sum", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table^
    elif "COUNT(*)" in sql:
        var result = count_rows(table)
        var schema = Schema()
        schema.fields = List[Field](Field("count", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table^
    elif "AVG(" in sql:
        var avg_start = sql.find("AVG(") + 4
        var avg_end = sql.find(")", avg_start)
        var column = String(sql[avg_start:avg_end])
        var result = Int64(avg_column(table, column))
        var schema = Schema()
        schema.fields = List[Field](Field("avg", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table^
    elif "MIN(" in sql:
        var min_start = sql.find("MIN(") + 4
        var min_end = sql.find(")", min_start)
        var column = String(sql[min_start:min_end])
        var result = min_column(table, column)
        var schema = Schema()
        schema.fields = List[Field](Field("min", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table^
    elif "MAX(" in sql:
        var max_start = sql.find("MAX(") + 4
        var max_end = sql.find(")", max_start)
        var column = String(sql[max_start:max_end])
        var result = max_column(table, column)
        var schema = Schema()
        schema.fields = List[Field](Field("max", "int64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = result
        return result_table^
    elif "GROUP BY" in sql:
        # Simple: SELECT SUM(col) FROM table GROUP BY group_col
        var sum_start = sql.find("SUM(") + 4
        var sum_end = sql.find(")", sum_start)
        var sum_col = String(sql[sum_start:sum_end]).strip()
        var group_start = sql.find("GROUP BY ") + 9
        var group_col = String(sql[group_start:])
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
        var i = 0
        while i < table.columns[0].length():
            if table.columns[group_idx].is_valid(i) and table.columns[sum_idx].is_valid(i):
                var g = table.columns[group_idx][i]
                var s = table.columns[sum_idx][i]
                if g not in groups:
                    groups[g] = 0
                groups[g] += s
            i += 1
        # Return table
        var schema = Schema()
        schema.fields = List[Field](Field(String(group_col), "int64"), Field("sum", "int64"))
        var result_table = Table(schema, len(groups))
        result_table.columns = List[Int64Array](Int64Array(len(groups)), Int64Array(len(groups)))
        var keys = List[Int64]()
        for g in groups:
            keys.append(g)
        var row = 0
        for g in keys:
            result_table.columns[0][row] = g
            result_table.columns[1][row] = groups[g]
            row += 1
        return result_table^

    # Parse SQL for SELECT columns
    var upper_sql = sql.upper()
    var select_pos = upper_sql.find("SELECT")
    var from_pos = upper_sql.find(" FROM ")
    var where_pos = upper_sql.find(" WHERE ")
    if select_pos == -1 or from_pos == -1:
        return table.copy()
    var select_clause = sql[select_pos+7:from_pos].strip()
    var from_clause = sql[from_pos+6:where_pos if where_pos != -1 else len(sql)].strip()
    var where_clause = sql[where_pos+7:] if where_pos != -1 else ""

    # Parse SELECT
    var column_specs = List[ColumnSpec]()
    if select_clause.upper() == "*":
        for field in table.schema.fields:
            column_specs.append(ColumnSpec(field.name))
    else:
        var columns = select_clause.split(",")
        for col in columns:
            var col_str = col.strip()
            var as_pos = col_str.upper().find(" AS ")
            if as_pos != -1:
                column_specs.append(ColumnSpec(String(col_str[:as_pos]), String(col_str[as_pos+4:])))
            else:
                column_specs.append(ColumnSpec(String(col_str), ""))

    # Parse FROM
    var table_spec = TableSpec("")
    var from_parts = from_clause.split(" ")
    table_spec.name = String(from_parts[0])
    if len(from_parts) > 2 and from_parts[1].upper() == "AS":
        table_spec.`alias` = String(from_parts[2])

    # For now, assume table is the global table, ignore name

    # Apply WHERE
    var filtered_table = table.copy()
    if where_clause != "":
        pass  # Placeholder for filtering

    # Select columns
    var new_schema = Schema()
    var col_indices = List[Int]()
    for spec in column_specs:
        var col_index = -1
        for i in range(len(filtered_table.schema.fields)):
            if filtered_table.schema.fields[i].name == spec.name:
                col_index = i
                break
        if col_index == -1:
            continue  # Error, but skip
        col_indices.append(col_index)
        var field_name = String(spec.name) if spec.`alias` == "" else String(spec.`alias`)
        new_schema.fields.append(Field(field_name, filtered_table.schema.fields[col_index].data_type))

    var new_table = Table(new_schema, filtered_table.num_rows())
    for i in range(len(col_indices)):
        var src_col = col_indices[i]
        for row in range(filtered_table.num_rows()):
            new_table.columns[i][row] = filtered_table.columns[src_col][row]

    cache.put(cache_key, new_table)
    return new_table^

from collections import Dict, List



from threading import ThreadPool

fn execute_query(table: Table, sql: String) raises -> Table:
    if sql.upper().startswith("LOAD EXTENSION"):
        var ext_start = sql.find("'")
        var ext_end = sql.rfind("'")
        if ext_start != -1 and ext_end != -1:
            var ext_name = sql[ext_start+1:ext_end]
            if ext_name == "column_store":
                # init_column_store()
                pass
            elif ext_name == "row_store":
                # init_row_store()
                pass
            elif ext_name == "graph":
                # init_graph()
                pass
            elif ext_name == "blockchain":
                # init_blockchain()
                pass
            elif ext_name == "lakehouse":
                # init_lakehouse()
                pass
            else:
                print("Unknown extension:", ext_name)
        return Table(Schema(), 0)  # Empty table for command
    return parse_and_execute_sql(table, sql)