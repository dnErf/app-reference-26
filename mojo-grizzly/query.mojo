# Simple Query Engine for Mojo Arrow Database
# SQL-like queries: SELECT * FROM table WHERE condition

from arrow import Table, Int64Array, Float64Array, Schema, Field
from pl import call_function
from index import BTreeIndex
from threading import Thread
from network import RemoteNode, query_remote
from python import Python
# from extensions.ml import predict
# from extensions.packaging import package_init, package_build, package_install, pixi_init, pixi_add_dep, hatch_init
# from extensions.scm import scm_init, scm_add, scm_commit, scm_status, scm_log, scm_push, scm_pull
import time
# from extensions.column_store import init as init_column_store

struct QueryCache:
    var cache: Dict[String, Table]
    var order: List[String]  # For LRU
    var capacity: Int

    fn __init__(out self, capacity: Int = 100):
        self.cache = Dict[String, Table]()
        self.order = List[String]()
        self.capacity = capacity

    fn get(mut self, key: String) -> Table:
        if key in self.cache:
            # Move to end (most recent)
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

    fn invalidate(mut self, table_name: String):
        # Invalidate all queries on this table
        var to_remove = List[String]()
        for key in self.cache.keys():
            if table_name in key:
                to_remove.append(key)
        for key in to_remove:
            if key in self.cache:
                self.cache.pop(key)
            if key in self.order:
                self.order.remove(key)

# Global cache instance
# var query_cache = QueryCache()

# Security functions inline
fn sanitize_input(input: String) -> String:
    # Basic sanitization: remove quotes, etc.
    return input.replace("'", "").replace("\"", "").replace(";", "")

fn audit_log(action: String, user: String, details: String):
    try:
        var py_time = Python.import_module("time")
        var timestamp = String(py_time.time())
        with open("audit.log", "a") as f:
            f.write(timestamp + " | " + user + " | " + action + " | " + details + "\n")
    except:
        pass  # Silent fail

fn check_rls(table: String, user: String) -> Bool:
    # Placeholder: always allow
    return True

# Analytics functions inline
import math

fn percentile(values: List[Float64], p: Float64) -> Float64:
    # Simple sort placeholder
    var sorted_values = values.copy()  # Assume sorted
    var index = (len(values) - 1) * p
    var lower = Int(index)
    var upper = lower + 1
    var weight = index - lower
    if upper >= len(values):
        return sorted_values[lower]
    return sorted_values[lower] * (1 - weight) + sorted_values[upper] * weight

fn mean(values: List[Float64]) -> Float64:
    var sum = 0.0
    for v in values:
        sum += v
    return sum / len(values)

fn std_dev(values: List[Float64]) -> Float64:
    var m = mean(values)
    var sum_sq = 0.0
    for v in values:
        sum_sq += (v - m) ** 2
    return math.sqrt(sum_sq / len(values))

fn data_quality_check(table: Table) -> String:
    var null_count = 0
    # Placeholder
    return "Nulls: " + String(null_count) + ", Total rows: " + String(table.num_rows())

fn get_float_column(table: Table, column_name: String) -> List[Float64]:
    for i in range(len(table.schema.fields)):
        if table.schema.fields[i].name == column_name:
            var values = List[Float64]()
            for j in range(table.num_rows()):
                values.append(Float64(table.columns[i][j]))
            return values^
    return List[Float64]()
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

struct AttachedDBRegistry(Copyable, Movable):
    var dbs: Dict[String, Table]

    fn __init__(out self):
        self.dbs = Dict[String, Table]()

    fn attach(mut self, alias: String, table: Table) -> Bool:
        if alias in self.dbs:
            return False  # Already exists
        self.dbs[alias] = table.copy()
        return True

    fn detach(mut self, alias: String) -> Bool:
        if alias not in self.dbs:
            return False  # Not found
        self.dbs.pop(alias)
        return True

    fn get(self, alias: String) -> Table:
        if alias in self.dbs:
            return self.dbs[alias].copy()
        return Table(Schema(), 0)

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
            # self.order.remove(key)
            self.order.append(key)
            return self.cache[key] # .copy()
        return Table(Schema(), 0)

    fn put(mut self, key: String, value: Table):
        if key in self.cache:
            # self.order.remove(key)
            pass
        elif len(self.cache) >= self.capacity:
            var oldest = self.order[0]
            # self.order.remove(oldest)
            # self.cache.pop(oldest)
            pass
        self.cache[key] = value # .copy()
        self.order.append(key)

struct QueryPlan:
    var operations: List[String]  # e.g., "scan", "filter", "join"
    var cost: Float64
    var execution_times: Dict[String, Float64]  # Learn from past executions

    fn __init__(out self):
        self.operations = List[String]()
        self.cost = 0.0
        self.execution_times = Dict[String, Float64]()

    fn record_execution_time(mut self, operation: String, time: Float64):
        self.execution_times[operation] = time

    fn adapt_plan(mut self, sql: String, table: Table):
        # Adaptive: adjust based on past performance
        if "WHERE" in sql and "index_scan" in self.execution_times:
            if self.execution_times["index_scan"] < self.execution_times.get("scan", 1000.0):
                self.operations[0] = "index_scan"
                self.cost -= 5.0

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
    # Optimizer: choose best plan (for now, simple)
    # Could add alternatives like index scan if index exists
    if "WHERE" in sql and len(table.indexes) > 0:
        plan.operations[0] = "index_scan"  # Prefer index
        plan.cost -= 5.0  # Lower cost
    return plan

fn parallel_scan(table: Table, func: fn(Table) -> Int64) -> Int64:
    # Use Mojo threading for parallel processing
    var num_threads = 8
    var results = List[Int64](capacity=num_threads)
    for _ in range(num_threads):
        results.append(0)
    var threads = List[Thread[fn(Int64) -> None]](capacity=num_threads)
    # Split table into chunks
    var chunk_size = table.num_rows() // num_threads
    for i in range(num_threads):
        var start = i * chunk_size
        var end = (i + 1) * chunk_size if i < num_threads - 1 else table.num_rows()
        var chunk = create_table_from_indices(table, List[Int](range(start, end)))
        # Create thread function
        fn thread_func(idx: Int64):
            results[int(idx)] = func(chunk)
        var t = Thread(thread_func, i)
        threads.append(t^)
        t^.start()
    # Wait for all
    for t in threads:
        t^.join()
    # Combine results
    var total = 0
    for r in results:
        total += r
    return total

fn parallel_execute_query(sql: String, table: Table) -> Table:
    # Parallelize query execution pipeline
    var plan = plan_query(sql, table)
    var result = table.copy()
    # Parallel filter if WHERE
    if "filter" in plan.operations:
        result = parallel_filter(result, sql)
    # Parallel sort if ORDER BY
    if "sort" in plan.operations:
        result = parallel_sort(result, sql)
    # Parallel join if JOIN
    if "join" in plan.operations:
        # Assume simple self-join for demo
        result = parallel_join(result, result, sql)
    return result

fn parallel_filter(table: Table, sql: String) -> Table:
    # Extract WHERE condition
    var where_start = sql.find("WHERE") + 6
    var where_clause = sql[where_start:].split("ORDER BY")[0].strip()
    # Parallel filter
    var num_threads = 4
    var results = List[Table]()
    var chunk_size = table.num_rows() // num_threads
    var threads = List[Thread[fn(Int) -> None]]()
    for i in range(num_threads):
        var start = i * chunk_size
        var end = (i + 1) * chunk_size if i < num_threads - 1 else table.num_rows()
        fn thread_func(idx: Int):
            var chunk = create_table_from_indices(table, List[Int](range(start, end)))
            var filtered = filter_table(chunk, where_clause)
            results.append(filtered)
        var t = Thread(thread_func, i)
        threads.append(t^)
        t^.start()
    for t in threads:
        t^.join()
    # Merge results
    var merged = Table(table.schema, 0)
    for r in results:
        for row in range(r.num_rows()):
            merged.append_row(r.get_row_values(row))
    return merged

fn parallel_sort(table: Table, sql: String) -> Table:
    # Simple parallel sort simulation
    return table  # Placeholder

fn parallel_join(left: Table, right: Table, sql: String) -> Table:
    # Simple parallel join simulation
    return left  # Placeholder

struct HealthMetrics:
    var query_count: Int64
    var error_count: Int64
    var avg_response_time: Float64
    var active_connections: Int

    fn __init__(out self):
        self.query_count = 0
        self.error_count = 0
        self.avg_response_time = 0.0
        self.active_connections = 0

    fn record_query(mut self, response_time: Float64, success: Bool):
        self.query_count += 1
        if not success:
            self.error_count += 1
        self.avg_response_time = (self.avg_response_time * (self.query_count - 1) + response_time) / self.query_count

    fn get_health_report(self) -> String:
        return "Queries: " + String(self.query_count) + ", Errors: " + String(self.error_count) + ", Avg Time: " + String(self.avg_response_time) + "ms, Connections: " + String(self.active_connections)

# Global metrics
# var health_metrics = HealthMetrics()

struct Config:
    var nodes: List[RemoteNode]
    var max_connections: Int
    var cache_size: Int

    fn __init__(out self):
        self.nodes = List[RemoteNode]()
        self.max_connections = 10
        self.cache_size = 100

    fn load_from_file(mut self, filename: String):
        try:
            with open(filename, "r") as f:
                var content = f.read()
            # Simple JSON-like parsing
            if "max_connections" in content:
                # Parse
                self.max_connections = 20  # Example
            print("Config loaded from", filename)
        except:
            print("Failed to load config")

# Global config
# var db_config = Config()

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
            # Copy table1
            for j in range(len(table1.columns)):
                partial_result.columns[j].append(table1.columns[j][i])
            # Copy table2 if match
            if key_val in hash_map:
                var idx2 = hash_map[key_val]
                for j in range(len(table2.columns)):
                    partial_result.columns[len(table1.columns) + j].append(table2.columns[j][idx2])
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
        var parts = sub_sql.split("WHERE")
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

fn parse_and_execute_sql(table: Table, sql: String, tables: Dict[String, Table]) raises -> Table:
    # Handle WITH (CTE)
    # var cte_tables = Dict[String, Table]()
    # if sql.upper().startswith("WITH"):
    #     var with_end = sql.upper().find(" SELECT")
    #     if with_end != -1:
    #         var with_clause = sql[:with_end].strip()
    #         var main_sql = sql[with_end:].strip()
    #         # Parse CTEs: WITH cte AS (SELECT ...), cte2 AS (SELECT ...)
    #         var ctes = with_clause[5:].split(",")
    #         for cte in ctes:
    #             var as_pos = cte.upper().find(" AS ")
    #             if as_pos != -1:
    #                 var cte_name = String(cte[:as_pos].strip())
    #                 var sub_sql_start = cte.find("(")
    #                 var sub_sql_end = cte.rfind(")")
    #                 if sub_sql_start != -1 and sub_sql_end != -1:
    #                     var sub_sql = cte[sub_sql_start+1:sub_sql_end].strip()
    #                     var cte_table = execute_subquery(sub_sql, table, tables)
    #                     cte_tables[cte_name] = cte_table
    #         # Execute main query with CTEs
    #         return parse_and_execute_sql_with_cte(table, main_sql, tables, cte_tables)
    # LRU cache for query results
    # var cache = CacheManager()
    # var cache_key = sql
    # var cached = cache.get(cache_key)
    # if cached.num_rows() > 0:
    #     return cached^
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
    elif "PERCENTILE(" in sql:
        var perc_start = sql.find("PERCENTILE(") + 11
        var perc_end = sql.find(")", perc_start)
        var column = String(sql[perc_start:perc_end].split(",")[0].strip())
        var p_str = sql[perc_start:perc_end].split(",")[1].strip()
        var p = atof(p_str)
        var values = get_float_column(table, column)
        var result = percentile(values, p)
        var schema = Schema()
        schema.fields = List[Field](Field("percentile", "float64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1))
        result_table.columns[0][0] = 0
        return result_table^
    elif "STATS(" in sql:
        var stats_start = sql.find("STATS(") + 6
        var stats_end = sql.find(")", stats_start)
        var column = String(sql[stats_start:stats_end])
        var values = get_float_column(table, column)
        var m = mean(values)
        var s = std_dev(values)
        var schema = Schema()
        schema.fields = List[Field](Field("mean", "float64"), Field("std_dev", "float64"))
        var result_table = Table(schema, 1)
        result_table.columns = List[Int64Array](Int64Array(1), Int64Array(1))
        result_table.columns[0][0] = 0
        result_table.columns[1][0] = 0
        return result_table^
    elif "DATA_QUALITY" in sql:
        var quality = data_quality_check(table)
        var schema = Schema()
        schema.fields = List[Field](Field("quality", "string"))
        var result_table = Table(schema, 1)
        # Placeholder for string column
        return result_table^
        # PREDICT(model, column) - commented out due to import issues
        # var predict_start = sql.find("PREDICT(") + 8
        # var predict_end = sql.find(")", predict_start)
        # var args = sql[predict_start:predict_end].split(",")
        # if len(args) == 2:
        #     var model_name = args[0].strip().strip("'\"")
        #     var column = args[1].strip()
        #     # For demo, predict on first row
        #     var data = List[Float64]()
        #     for i in range(table.num_rows()):
        #         data.append(Float64(table.columns[0][i]))  # Assume first column
        #     var result = predict(model_name, data)
        #     var schema = Schema()
        #     schema.fields = List[Field](Field("predict", "int64"))
        #     var result_table = Table(schema, 1)
        #     var result_table = Table(schema, 1)
        #     result_table.columns = List[Int64Array](Int64Array(1))
        #     result_table.columns[0][0] = 0
        #     return result_table^
        return Table(Schema(), 0)
    elif sql.startswith("SCM INIT"):
        # SCM INIT <path>
        var parts = sql.split(" ")
        if len(parts) >= 3:
            var path = parts[2]
            # scm_init(path)
            print("SCM INIT not available")
        else:
            print("Usage: SCM INIT <path>")
        return Table(Schema(), 0)
    elif sql.startswith("SCM ADD"):
        # SCM ADD <file>
        var parts = sql.split(" ")
        if len(parts) >= 3:
            var file = parts[2]
            # scm_add(file)
            print("SCM ADD not available")
        else:
            print("Usage: SCM ADD <file>")
        return Table(Schema(), 0)
    elif sql.startswith("SCM COMMIT"):
        # SCM COMMIT <message>
        var message = sql[11:]  # After "SCM COMMIT "
        # scm_commit(message)
        print("SCM COMMIT not available")
        return Table(Schema(), 0)
    elif sql == "SCM STATUS":
        # scm_status()
        print("SCM STATUS not available")
        return Table(Schema(), 0)
    elif sql == "SCM LOG":
        # scm_log()
        print("SCM LOG not available")
        return Table(Schema(), 0)
    elif sql.startswith("SCM PUSH"):
        # SCM PUSH <remote>
        var parts = sql.split(" ")
        if len(parts) >= 3:
            var remote = parts[2]
            # scm_push(remote)
            print("SCM PUSH not available")
        else:
            print("Usage: SCM PUSH <remote>")
        return Table(Schema(), 0)
    elif sql.startswith("SCM PULL"):
        # SCM PULL <remote>
        var parts = sql.split(" ")
        if len(parts) >= 3:
            var remote = parts[2]
            # scm_pull(remote)
            print("SCM PULL not available")
        else:
            print("Usage: SCM PULL <remote>")
        return Table(Schema(), 0)
    elif sql.startswith("PACKAGE INIT"):
        # PACKAGE INIT name version
        var parts = sql.split(" ")
        if len(parts) >= 4:
            var name = parts[2]
            var version = parts[3]
            # package_init(name, version)
            print("PACKAGE INIT not available")
        else:
            print("Usage: PACKAGE INIT <name> <version>")
        return Table(Schema(), 0)
    elif sql.startswith("PACKAGE BUILD"):
        # package_build()
        print("PACKAGE BUILD not available")
        return Table(Schema(), 0)
    elif sql.startswith("PACKAGE INSTALL"):
        # package_install()
        print("PACKAGE INSTALL not available")
        return Table(Schema(), 0)
    elif sql.startswith("PACKAGE PIXI INIT"):
        # pixi_init()
        print("PACKAGE PIXI INIT not available")
        return Table(Schema(), 0)
    elif sql.startswith("PACKAGE HATCH INIT"):
        # hatch_init()
        print("PACKAGE HATCH INIT not available")
        return Table(Schema(), 0)
    elif sql.startswith("PACKAGE ADD DEP"):
        # PACKAGE ADD DEP <dep>
        var parts = sql.split(" ")
        if len(parts) >= 4:
            var dep = parts[3]
            # pixi_add_dep(dep)
            print("PACKAGE ADD DEP not available")
        else:
            print("Usage: PACKAGE ADD DEP <dep>")
        return Table(Schema(), 0)
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

    # Parse FROM first to determine query_table
    var table_spec = TableSpec("")
    var from_parts = from_clause.split(" ")
    table_spec.name = String(from_parts[0])
    if len(from_parts) > 2 and from_parts[1].upper() == "AS":
        table_spec.`alias` = String(from_parts[2])

    # Handle cross-DB queries: alias.table or just alias
    var query_table = table.copy()
    if "." in table_spec.name:
        var parts = table_spec.name.split(".")
        if len(parts) == 2:
            var db_alias = String(parts[0])
            table_spec.name = String(parts[1])
            if db_alias in tables:
                query_table = tables[db_alias].copy()
            else:
                print("Attached database '" + db_alias + "' not found")
                return Table(Schema(), 0)
        else:
            print("Invalid table name: " + table_spec.name)
            return Table(Schema(), 0)
    elif table_spec.name in tables:
        query_table = tables[table_spec.name].copy()
    elif "@" in table_spec.name:
        var parts = table_spec.name.split("@")
        if len(parts) == 2:
            var node_str = String(parts[0])
            table_spec.name = String(parts[1])
            var node_parts = node_str.split(":")
            if len(node_parts) == 2:
                var host = String(node_parts[0])
                var port = atol(node_parts[1])
                var node = RemoteNode(host, port)
                # Fetch remote table
                var remote_sql = "SELECT * FROM " + table_spec.name
                query_table = query_remote(node, remote_sql)
            else:
                print("Invalid node format: " + node_str)
                return Table(Schema(), 0)
        else:
            print("Invalid remote table format: " + table_spec.name)
            return Table(Schema(), 0)

    # Parse SELECT
    var column_specs = List[ColumnSpec]()
    if select_clause.upper() == "*":
        for field in query_table.schema.fields:
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

    # For now, assume table is the global table, ignore name

    # Apply WHERE
    var filtered_table = query_table.copy()
    if where_clause != "":
        pass  # Placeholder for filtering

    # Select columns
    var new_schema = Schema()
    var col_indices = List[Int]()
    for spec in column_specs:
        var col_index = -1
        for i in range(len(query_table.schema.fields)):
            if query_table.schema.fields[i].name == spec.name:
                col_index = i
                break
        if col_index == -1:
            continue  # Error, but skip
        col_indices.append(col_index)
        var field_name = String(spec.name) if spec.`alias` == "" else String(spec.`alias`)
        new_schema.fields.append(Field(field_name, query_table.schema.fields[col_index].data_type))

    var new_table = Table(new_schema, query_table.num_rows())
    for i in range(len(col_indices)):
        var src_col = col_indices[i]
        for row in range(query_table.num_rows()):
            new_table.columns[i][row] = query_table.columns[src_col][row]

    # cache.put(cache_key, new_table)
    return new_table^

from collections import Dict, List



from threading import ThreadPool

fn execute_query(table: Table, sql: String, tables: Dict[String, Table], user: String = "admin") raises -> Table:
    var py_time = Python.import_module("time")
    var start_time = py_time.time()
    var sanitized_sql = sanitize_input(sql)
    audit_log("EXECUTE_QUERY", user, sanitized_sql)
    # Check RLS for main table, assume table name is "main" or something
    if not check_rls("main", user):
        print("Access denied by RLS")
        return Table(Schema(), 0)
    if sanitized_sql.upper().startswith("LOAD EXTENSION"):
        var ext_start = sanitized_sql.find("'")
        var ext_end = sanitized_sql.rfind("'")
        if ext_start != -1 and ext_end != -1:
            var ext_name = sanitized_sql[ext_start+1:ext_end]
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
            elif ext_name == "security":
                # from extensions.security import init
                # init()
                pass
            else:
                print("Unknown extension:", ext_name)
        return Table(Schema(), 0)  # Empty table for command
    var result = parse_and_execute_sql(table, sanitized_sql, tables)
    return result^

# Window Functions
fn row_number(table: Table, partition_cols: List[String], order_cols: List[String]) -> Table:
    # Add row_number column
    var schema = table.schema
    schema.add_field("row_number", "int64")
    var result = Table(schema, table.num_rows())
    # Copy data
    for i in range(table.num_rows()):
        for j in range(table.schema.fields.size):
            result.columns[j][i] = table.columns[j][i]
    # Assign row numbers (placeholder: sequential)
    for i in range(table.num_rows()):
        result.columns[table.schema.fields.size][i] = i + 1
    return result

fn rank(table: Table, partition_cols: List[String], order_cols: List[String]) -> Table:
    # Similar to row_number, but handle ties
    return row_number(table, partition_cols, order_cols)  # Placeholder

# Subquery execution
fn execute_subquery(sub_sql: String, main_table: Table, tables: Dict[String, Table]) raises -> Table:
    return parse_and_execute_sql(main_table, sub_sql, tables)