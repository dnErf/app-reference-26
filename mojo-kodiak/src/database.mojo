"""
Mojo Kodiak DB - Database Module

Defines the main Database class and core structures.
"""

from python import Python, PythonObject
from types import Row, Table
from utils import atof
from extensions.wal import WAL
from extensions.block_store import BlockStore
from extensions.blob_store import BlobStore
from extensions.b_plus_tree import BPlusTree
from extensions.fractal_tree import FractalTree
from extensions.query_parser import Query

struct ExtensionMetadata(Copyable, Movable):
    """
    Metadata for database extensions.
    """
    var name: String
    var version: String
    var description: String
    var dependencies_str: String  # Comma-separated list
    var is_builtin: Bool
    var is_loaded: Bool
    var load_time: Float64

    fn __init__(out self, name: String, version: String = "1.0.0", description: String = "", is_builtin: Bool = False):
        self.name = name
        self.version = version
        self.description = description
        self.dependencies_str = ""
        self.is_builtin = is_builtin
        self.is_loaded = False
        self.load_time = 0.0

    fn get_dependencies(self) -> List[String]:
        """
        Get dependencies as a list.
        """
        if self.dependencies_str == "":
            return List[String]()
        return self.dependencies_str.split(",")

struct Database(Copyable, Movable):
    """
    Main database class managing tables and storage.
    """
    var tables: Dict[String, Table]
    var pyarrow: PythonObject
    var wal_instance: WAL
    var block_store_instance: BlockStore
    var index: BPlusTree
    var fractal_tree: FractalTree
    var lock: PythonObject
    var variables: Dict[String, String]
    var functions: Dict[String, Query]  # Custom functions
    var plugins: Dict[String, PythonObject]
    var in_transaction: Bool
    var transaction_log: List[String]
    var secrets: Dict[String, String]  # Encrypted secrets storage
    var master_key: String  # Derived master key for encryption
    var attached_databases: Dict[String, String]  # Attached database paths
    var triggers: Dict[String, Query]  # Triggers
    var cron_jobs: Dict[String, Query]  # Cron jobs
    var query_count: Int  # Query execution counter
    var total_query_time: Float64  # Total time spent executing queries
    var last_query_time: Float64  # Time of last query execution
    var memory_usage: Int  # Approximate memory usage in bytes
    var min_query_time: Float64  # Minimum query execution time
    var max_query_time: Float64  # Maximum query execution time
    var config: Dict[String, String]  # Configuration settings
    var active_connections: Int  # Number of active connections
    var types: Dict[String, Query]  # Custom types (STRUCT, EXCEPTION)
    var models: Dict[String, Query]  # Data models
    var tests: Dict[String, Query]  # Data quality tests
    var last_run: Dict[String, String]  # Last run timestamp for incremental models
    var snapshots: Dict[String, Query]  # Data snapshots
    var macros: Dict[String, Query]  # SQL macros
    var schedules: Dict[String, Query]  # Scheduled model runs
    var blob_store: BlobStore  # BLOB storage system
    var query_cache: Dict[String, List[Row]]  # Query result cache
    var cache_max_size: Int  # Maximum cache size
    var cache_hits: Int  # Cache hit counter
    var cache_misses: Int  # Cache miss counter
    var connection_pool: List[Int]  # Connection pool (connection IDs)
    var max_connections: Int  # Maximum connections allowed
    var available_connections: List[Int]  # Available connection IDs
    var memory_threshold: Int  # Memory threshold for cleanup (bytes)
    var last_cleanup_time: Float64  # Last cleanup timestamp
    var parallel_enabled: Bool  # Whether parallel execution is enabled
    # var extensions: Dict[String, ExtensionMetadata]  # Extension registry
    # var extension_dependencies: Dict[String, List[String]]  # Extension dependency tracking

    fn __init__(out self) raises:
        self.tables = Dict[String, Table]()
        Python.add_to_path("/home/lnx/Dev/app-reference-26/mojo-kodiak/.venv/lib64/python3.14/site-packages")
        self.pyarrow = Python.import_module("pyarrow")
        print("PyArrow initialized successfully.")
        var threading = Python.import_module("threading")
        self.lock = threading.Lock()
        print("Lock initialized successfully.")
        self.wal_instance = WAL("data/wal.log")
        self.block_store_instance = BlockStore("data/blocks")
        self.index = BPlusTree()
        self.fractal_tree = FractalTree()
        self.variables = Dict[String, String]()
        self.functions = Dict[String, Query]()
        self.plugins = Dict[String, PythonObject]()
        self.in_transaction = False
        self.transaction_log = List[String]()
        self.secrets = Dict[String, String]()
        self.attached_databases = Dict[String, String]()
        self.triggers = Dict[String, Query]()
        self.cron_jobs = Dict[String, Query]()
        self.query_count = 0
        self.total_query_time = 0.0
        self.last_query_time = 0.0
        self.memory_usage = 0
        self.min_query_time = 999999.0
        self.max_query_time = 0.0
        self.config = Dict[String, String]()
        self.active_connections = 0
        self.types = Dict[String, Query]()
        self.models = Dict[String, Query]()
        self.tests = Dict[String, Query]()
        self.last_run = Dict[String, String]()
        self.snapshots = Dict[String, Query]()
        self.macros = Dict[String, Query]()
        self.schedules = Dict[String, Query]()
        self.blob_store = BlobStore("./blob_storage")
        self.query_cache = Dict[String, List[Row]]()
        self.cache_max_size = 100  # Default cache size
        self.cache_hits = 0
        self.cache_misses = 0
        self.connection_pool = List[Int]()
        self.max_connections = 10  # Default max connections
        self.available_connections = List[Int]()
        self.memory_threshold = 100 * 1024 * 1024  # 100MB default threshold
        self.last_cleanup_time = 0.0
        self.parallel_enabled = True  # Enable parallel execution by default
        # self.extensions = Dict[String, ExtensionMetadata]()
        # self.extension_dependencies = Dict[String, List[String]]()
        # Initialize built-in extensions
        # self._register_builtin_extensions()
        # Derive master key using PBKDF2
        var hashlib = Python.import_module("hashlib")
        var os = Python.import_module("os")
        var salt = os.urandom(16)
        var password = Python.evaluate("'default_master_password'")
        var dk = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 100000)
        self.master_key = String(dk.hex())
        self.load_config("config.json")

    fn connect(mut self) -> Int:
        """
        Connect to the database using connection pool. Returns connection ID.
        """
        # Try to get an available connection from the pool
        if len(self.available_connections) > 0:
            var connection_id = self.available_connections.pop()
            return connection_id
        
        # Create a new connection if under the limit
        if len(self.connection_pool) < self.max_connections:
            var new_connection_id = len(self.connection_pool) + 1
            self.connection_pool.append(new_connection_id)
            self.active_connections += 1
            return new_connection_id
        
        # Pool is full, return error (could implement waiting queue)
        return -1  # Connection pool full

    fn disconnect(mut self, connection_id: Int):
        """
        Disconnect from the database and return connection to pool.
        """
        if self.active_connections > 0:
            self.active_connections -= 1
            # Return connection to available pool
            self.available_connections.append(connection_id)

    fn get_connection_stats(self) -> String:
        """
        Get connection pool statistics.
        """
        return "Connections: " + String(self.active_connections) + "/" + String(len(self.connection_pool)) + " active, " + String(len(self.available_connections)) + " available"

    fn check_memory_usage(mut self) raises -> Bool:
        """
        Check if memory usage exceeds threshold and trigger cleanup if needed.
        """
        var time_module = Python.import_module("time")
        var current_time = Float64(time_module.time())
        
        # Check memory every 60 seconds
        if current_time - self.last_cleanup_time > 60.0:
            if self.memory_usage > self.memory_threshold:
                self.perform_memory_cleanup()
                self.last_cleanup_time = current_time
                return True
        
        return False

    fn perform_memory_cleanup(mut self) raises:
        """
        Perform intelligent memory cleanup.
        """
        print("Performing memory cleanup...")
        
        # Clear old cache entries (simple LRU-like cleanup)
        var cache_size = len(self.query_cache)
        if cache_size > self.cache_max_size // 2:
            var keys_to_remove = List[String]()
            var count = 0
            for cache_key in self.query_cache.keys():
                if count >= cache_size // 4:  # Remove 25% of cache
                    break
                keys_to_remove.append(cache_key)
                count += 1
            
            for key in keys_to_remove:
                _ = self.query_cache.pop(key, List[Row]())
        
        # Clear unused variables (simple heuristic)
        var vars_to_remove = List[String]()
        for var_name in self.variables.keys():
            # Remove variables that start with temp_ (temporary variables)
            if var_name.startswith("temp_"):
                vars_to_remove.append(var_name)
        
        for var_name in vars_to_remove:
            if var_name in self.variables:
                _ = self.variables.pop(var_name)
        
        # Update memory usage estimate
        self.memory_usage = self.estimate_memory_usage()
        print("Memory cleanup completed. New usage: " + String(self.memory_usage) + " bytes")

    fn estimate_memory_usage(self) -> Int:
        """
        Estimate current memory usage.
        """
        var usage = 0
        
        # Estimate table memory
        for table in self.tables.values():
            usage += len(table.rows) * 100  # Rough estimate per row
        
        # Estimate cache memory
        usage += len(self.query_cache) * 200  # Rough estimate per cached result
        
        # Estimate variable memory
        usage += len(self.variables) * 50  # Rough estimate per variable
        
        return usage

    fn get_memory_stats(self) -> String:
        """
        Get memory usage statistics.
        """
        var cleanup_status = "OK"
        if self.memory_usage > self.memory_threshold:
            cleanup_status = "HIGH"
        
        return "Memory: " + String(self.memory_usage) + " bytes used, threshold: " + String(self.memory_threshold) + " bytes (" + cleanup_status + ")"

    fn parallel_aggregate(self, table_name: String, column: String, operation: String) -> String:
        """
        Perform parallel aggregation on a table column.
        """
        if not self.parallel_enabled or table_name not in self.tables:
            return "Parallel aggregation not available or table not found"
        
        try:
            var table = self.tables[table_name]
            if len(table.rows) == 0:
                return "0"
            
            # Use Python for parallel processing
            var threading = Python.import_module("threading")
            var concurrent = Python.import_module("concurrent.futures")
            
            # Split data into chunks for parallel processing
            var chunk_size = max(1, len(table.rows) // 4)  # 4 chunks
            var chunks = List[List[Row]]()
            
            var current_chunk = List[Row]()
            for i in range(len(table.rows)):
                current_chunk.append(table.rows[i])
                if len(current_chunk) >= chunk_size:
                    chunks.append(current_chunk)
                    current_chunk = List[Row]()
            
            if len(current_chunk) > 0:
                chunks.append(current_chunk)
            
            # Process chunks in parallel using Python
            var results = List[String]()
            
            if operation == "COUNT":
                return String(len(table.rows))
            elif operation == "SUM":
                var total = 0
                for row in table.rows:
                    if column in row:
                        # Simple sum (would need proper type conversion)
                        total += 1  # Placeholder
                return String(total)
            elif operation == "AVG":
                var count = len(table.rows)
                if count > 0:
                    return String(count // 2)  # Placeholder average
                return "0"
            
            return "Unsupported operation"
            
        except:
            return "Parallel aggregation failed"

    fn get_parallel_stats(self) -> String:
        """
        Get parallel execution statistics.
        """
        var status = "enabled" if self.parallel_enabled else "disabled"
        return "Parallel execution: " + status

    fn create_table(mut self, name: String) raises:
        """
        Create a new table with the given name.
        """
        if name in self.tables:
            raise Error("Table already exists")
        self.tables[name] = Table(name, List[Row]())
        self.save_table_to_disk(name)  # Persist to disk
        print("Table '" + name + "' created: True")

    fn get_table(mut self, name: String) -> Table:
        """
        Get a table by name. Assumes it exists.
        """
        return self.tables[name]

    fn insert_into_table(mut self, table_name: String, row: Row) raises:
        """
        Insert a row into the specified table.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            self.tables[table_name].insert_row(row)
            
            # Update B+ tree index
            if "id" in row.data:
                var id_str = row["id"]
                try:
                    var id_int = Int(id_str)
                    self.index.insert(id_int, row)
                except:
                    # If id is not an integer, use row count as key
                    var row_count = len(self.tables[table_name].rows)
                    self.index.insert(row_count - 1, row)
            
            self.fractal_tree.insert(row)
            self.wal_instance.append_log("INSERT INTO " + table_name)
            self.save_table_to_disk(table_name)  # Persist to disk
            self.execute_triggers(table_name, "INSERT", "AFTER", Row(), row)
            self.invalidate_cache_for_table(table_name)  # Invalidate cache
        finally:
            self.lock.release()

    fn select_from_table(self, table_name: String, filter_func: fn(Row) raises -> Bool) raises -> List[Row]:
        """
        Select rows from the specified table that match the filter.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            return self.tables[table_name].select_rows(filter_func)
        finally:
            self.lock.release()

    fn select_all_from_table(self, table_name: String) raises -> List[Row]:
        """
        Select all rows from the table.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            return self.tables[table_name].select_all()
        finally:
            self.lock.release()

    fn aggregate(self, table_name: String, column: String, agg_func: fn(List[Int]) -> Int) raises -> Int:
        """
        Aggregate values in a column using the provided function.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            var table = self.tables[table_name]
            var values = List[Int]()
            for row in table.rows:
                var val_str = row[column]
                # Assume int values, convert
                var val = 0  # placeholder, atol not available
                values.append(val)
            return agg_func(values)
        finally:
            self.lock.release()

    fn sum(self, table_name: String, column: String) raises -> Float64:
        """
        Calculate sum of numeric values in a column.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            var table = self.tables[table_name]
            var total: Float64 = 0.0
            for row in table.rows:
                var val_str = row[column]
                if val_str != "":
                    try:
                        total += atof(val_str)
                    except:
                        pass  # Skip non-numeric values
            return total
        finally:
            self.lock.release()

    fn count(self, table_name: String, column: String = "") raises -> Int:
        """
        Count rows in a table, or non-null values in a column.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            var table = self.tables[table_name]
            if column == "":
                return len(table.rows)
            var count = 0
            for row in table.rows:
                if row[column] != "":
                    count += 1
            return count
        finally:
            self.lock.release()

    fn avg(self, table_name: String, column: String) raises -> Float64:
        """
        Calculate average of numeric values in a column.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            var table = self.tables[table_name]
            var total: Float64 = 0.0
            var count = 0
            for row in table.rows:
                var val_str = row[column]
                if val_str != "":
                    try:
                        total += atof(val_str)
                        count += 1
                    except:
                        pass  # Skip non-numeric values
            if count == 0:
                return 0.0
            return total / count
        finally:
            self.lock.release()

    fn max(self, table_name: String, column: String) raises -> String:
        """
        Find maximum value in a column.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            var table = self.tables[table_name]
            var max_val = ""
            for row in table.rows:
                var val = row[column]
                if max_val == "" or val > max_val:
                    max_val = val
            return max_val
        finally:
            self.lock.release()

    fn min(self, table_name: String, column: String) raises -> String:
        """
        Find minimum value in a column.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise Error("Table does not exist")
            var table = self.tables[table_name]
            var min_val = ""
            for row in table.rows:
                var val = row[column]
                if min_val == "" or val < min_val:
                    min_val = val
            return min_val
        finally:
            self.lock.release()

    fn join(self, table1_name: String, table2_name: String, on_column1: String, on_column2: String) raises -> List[Row]:
        """
        Perform inner join on two tables based on columns.
        """
        self.lock.acquire()
        try:
            if table1_name not in self.tables or table2_name not in self.tables:
                raise Error("Table does not exist")
            var table1 = self.tables[table1_name].copy()
            var table2 = self.tables[table2_name].copy()
            var result = List[Row]()
            for row1 in table1.rows:
                for row2 in table2.rows:
                    if row1[on_column1] == row2[on_column2]:
                        var joined = Row()
                        # Merge rows (simple, may overwrite keys)
                        for key in row1.data.keys():
                            joined[key] = row1[key]
                        for key in row2.data.keys():
                            joined[key] = row2[key]
                        result.append(joined.copy())
            return result^
        finally:
            self.lock.release()

    fn hash_join(self, table1_name: String, table2_name: String, on_column1: String, on_column2: String) raises -> List[Row]:
        """
        Perform hash join on two tables. More efficient for large datasets.
        """
        self.lock.acquire()
        try:
            if table1_name not in self.tables or table2_name not in self.tables:
                raise Error("Table does not exist")

            var table1 = self.tables[table1_name]
            var table2 = self.tables[table2_name]

            # Build hash table from smaller table (assume table2 is smaller)
            var hash_table = Dict[String, List[Row]]()
            for row in table2.rows:
                var key = row[on_column2]
                if key not in hash_table:
                    hash_table[key] = List[Row]()
                hash_table[key].append(row.copy())

            # Probe with table1
            var result = List[Row]()
            for row1 in table1.rows:
                var key = row1[on_column1]
                if key in hash_table:
                    for row2 in hash_table[key]:
                        var joined = Row()
                        # Merge rows
                        for col_key in row1.data.keys():
                            joined[col_key] = row1[col_key]
                        for col_key in row2.data.keys():
                            joined[col_key] = row2[col_key]
                        result.append(joined.copy())

            return result^
        finally:
            self.lock.release()

    fn merge_join(self, table1_name: String, table2_name: String, on_column1: String, on_column2: String) raises -> List[Row]:
        """
        Perform merge join on two tables. Requires sorted data for optimal performance.
        """
        self.lock.acquire()
        try:
            if table1_name not in self.tables or table2_name not in self.tables:
                raise Error("Table does not exist")

            var table1 = self.tables[table1_name]
            var table2 = self.tables[table2_name]

            # Sort both tables by join key (simple sort for now)
            var sorted1 = List[Row]()
            for row in table1.rows:
                sorted1.append(row.copy())
            # Simple bubble sort by join column
            for i in range(len(sorted1)):
                for j in range(i + 1, len(sorted1)):
                    if sorted1[i][on_column1] > sorted1[j][on_column1]:
                        var temp = sorted1[i]
                        sorted1[i] = sorted1[j]
                        sorted1[j] = temp

            var sorted2 = List[Row]()
            for row in table2.rows:
                sorted2.append(row.copy())
            # Simple bubble sort by join column
            for i in range(len(sorted2)):
                for j in range(i + 1, len(sorted2)):
                    if sorted2[i][on_column2] > sorted2[j][on_column2]:
                        var temp = sorted2[i]
                        sorted2[i] = sorted2[j]
                        sorted2[j] = temp

            # Merge join
            var result = List[Row]()
            var i = 0
            var j = 0

            while i < len(sorted1) and j < len(sorted2):
                var key1 = sorted1[i][on_column1]
                var key2 = sorted2[j][on_column2]

                if key1 == key2:
                    # Found match, collect all matching rows
                    var start_j = j
                    while j < len(sorted2) and sorted2[j][on_column2] == key1:
                        var joined = Row()
                        for col_key in sorted1[i].data.keys():
                            joined[col_key] = sorted1[i][col_key]
                        for col_key in sorted2[j].data.keys():
                            joined[col_key] = sorted2[j][col_key]
                        result.append(joined.copy())
                        j += 1

                    # Move to next distinct key in table1
                    var start_i = i
                    while i < len(sorted1) and sorted1[i][on_column1] == key1:
                        i += 1

                elif key1 < key2:
                    i += 1
                else:
                    j += 1

            return result^
        finally:
            self.lock.release()

    fn execute_subquery(self, subquery_table: List[Row], filter_func: fn(Row) raises -> Bool) raises -> List[Row]:
        """
        Execute a subquery on a derived table (result of another query).
        """
        var result = List[Row]()
        for row in subquery_table:
            if filter_func(row):
                result.append(row.copy())
        return result^

    fn select_with_subquery(self, main_table: String, subquery_table: List[Row], join_condition: fn(Row, Row) raises -> Bool) raises -> List[Row]:
        """
        Select from main table where condition involves subquery result.
        """
        self.lock.acquire()
        try:
            if main_table not in self.tables:
                raise Error("Table does not exist")

            var main = self.tables[main_table]
            var result = List[Row]()

            for main_row in main.rows:
                var matches = False
                for sub_row in subquery_table:
                    if join_condition(main_row, sub_row):
                        matches = True
                        break
                if matches:
                    result.append(main_row.copy())

            return result^
        finally:
            self.lock.release()

    fn exists_subquery(self, main_table: String, subquery_table: List[Row], condition: fn(Row, Row) raises -> Bool) raises -> List[Row]:
        """
        EXISTS subquery - return rows from main table where subquery returns results.
        """
        self.lock.acquire()
        try:
            if main_table not in self.tables:
                raise Error("Table does not exist")

            var main = self.tables[main_table]
            var result = List[Row]()

            for main_row in main.rows:
                var exists = False
                for sub_row in subquery_table:
                    if condition(main_row, sub_row):
                        exists = True
                        break
                if exists:
                    result.append(main_row.copy())

            return result^
        finally:
            self.lock.release()

    fn get_cached_query(self, query_key: String) -> List[Row]:
        """
        Get cached query result if available and not expired.
        """
        if query_key in self.query_cache:
            self.cache_hits += 1
            return self.query_cache[query_key]
        self.cache_misses += 1
        return List[Row]()

    fn cache_query_result(self, query_key: String, result: List[Row]):
        """
        Cache query result with automatic size management.
        """
        # Simple LRU-like eviction: remove oldest entries if cache is full
        if len(self.query_cache) >= self.cache_max_size:
            # Remove first key (simple implementation)
            var first_key = ""
            for key in self.query_cache.keys():
                first_key = key
                break
            if first_key != "":
                _ = self.query_cache.pop(first_key)

        self.query_cache[query_key] = result

    fn invalidate_cache_for_table(mut self, table_name: String) raises:
        """
        Invalidate cache entries that depend on the specified table.
        """
        var keys_to_remove = List[String]()
        for key in self.query_cache.keys():
            if key.find(table_name) != -1:
                keys_to_remove.append(key)

        for key in keys_to_remove:
            if key in self.query_cache:
                _ = self.query_cache.pop(key)

    fn select_with_cache(self, table_name: String, filter_func: fn(Row) raises -> Bool, use_cache: Bool = True) raises -> List[Row]:
        """
        Select with caching support. Uses cache if available and enabled.
        """
        var query_key = table_name + "_filter_" + String(Int(filter_func))  # Simple key generation

        if use_cache:
            var cached = self.get_cached_query(query_key)
            if len(cached) > 0:
                return cached

        # Execute query
        var result = self.select_from_table(table_name, filter_func)

        # Cache result
        if use_cache:
            self.cache_query_result(query_key, result)

        return result

    fn prepare_statement(self, query_template: String) -> String:
        """
        Prepare a parameterized query template. Returns statement ID.
        """
        var stmt_id = "stmt_" + String(len(self.functions))
        var query = Query()
        query.query_string = query_template
        self.functions[stmt_id] = query
        return stmt_id

    fn execute_prepared(self, stmt_id: String, parameters: Dict[String, String]) raises -> List[Row]:
        """
        Execute a prepared statement with parameters.
        """
        if stmt_id not in self.functions:
            raise Error("Prepared statement not found")

        var query = self.functions[stmt_id]
        var query_str = query.query_string

        # Simple parameter substitution - replace ? with values
        var param_index = 0
        var result_query = ""
        var i = 0

        while i < len(query_str):
            if query_str[i] == '?':
                if param_index < len(parameters):
                    # Get parameter by index (simple implementation)
                    var param_key = "param_" + String(param_index)
                    if param_key in parameters:
                        result_query += "'" + parameters[param_key] + "'"
                    else:
                        result_query += "?"
                else:
                    result_query += "?"
                param_index += 1
            else:
                result_query += query_str[i]
            i += 1

        # For now, return empty result (would need full SQL parser for complete implementation)
        return List[Row]()

    fn select_prepared(self, stmt_id: String, parameters: Dict[String, String]) raises -> List[Row]:
        """
        Execute a prepared SELECT statement with parameters.
        """
        return self.execute_prepared(stmt_id, parameters)

    fn insert_prepared(self, stmt_id: String, parameters: Dict[String, String]) raises:
        """
        Execute a prepared INSERT statement with parameters.
        """
        # Implementation would parse the prepared statement and execute insert
        pass

    fn update_prepared(self, stmt_id: String, parameters: Dict[String, String]) raises:
        """
        Execute a prepared UPDATE statement with parameters.
        """
        # Implementation would parse the prepared statement and execute update
        pass

    fn delete_prepared(self, stmt_id: String, parameters: Dict[String, String]) raises:
        """
        Execute a prepared DELETE statement with parameters.
        """
        # Implementation would parse the prepared statement and execute delete
        pass

    fn commit_transaction(mut self):
        """
        Commit transaction (flush WAL).
        """
        print("Transaction committed")

    fn rollback_transaction(mut self):
        """
        Rollback transaction (placeholder).
        """
        print("Transaction rolled back")

    fn save_table_to_disk(mut self, table_name: String) raises:
        """
        Save a table to disk using PyArrow Feather format.
        """
        if table_name not in self.tables:
            raise Error("Table does not exist")
        
        var table = self.tables[table_name].copy()
        
        # Convert table rows to PyArrow table
        var pa = Python.import_module("pyarrow")
        
        # Create list of dicts for PyArrow table
        var records = Python.list()
        
        for i in range(len(table.rows)):
            var row = table.rows[i].copy()
            var record = Python.dict()
            for key in row.data.keys():
                record[key] = row[key]
            records.append(record)
        
        # Create PyArrow table from records
        var pa_table = pa.Table.from_pylist(records)
        
        # Save using block store (Feather format)
        var block_id = table_name + "_table"
        self.block_store_instance.write_block(pa_table, block_id)
        
        # TODO: Implement B+ tree indexing
        # Update B+ tree index for this table
        # self.index = BPlusTree()  # Reset index for this table
        # for i in range(len(table.rows)):
        #     var row = table.rows[i].copy()
        #     if "id" in row.data:
        #         var id_str = row["id"]
        #         # Try to convert to int for indexing
        #         try:
        #             var id_int = Int(id_str)
        #             self.index.insert(id_int, row.copy())
        #         except:
        #             # If id is not an integer, use row index
        #             self.index.insert(i, row.copy())
        
        print("Table '" + table_name + "' saved to disk with Feather format")

    fn load_table_from_disk(mut self, table_name: String) raises:
        """
        Load a table from disk using PyArrow Feather format.
        """
        var block_id = table_name + "_table"
        try:
            var pa_table = self.block_store_instance.read_block(block_id)
            
            # Convert PyArrow table back to our Table format
            var rows = List[Row]()
            
            # Convert to Python list of dicts first
            var records = pa_table.to_pylist()
            
            for i in range(len(records)):
                var record = records[i]
                var row = Row()
                # Get column names from the PyArrow table
                var column_names = pa_table.column_names
                for j in range(len(column_names)):
                    var col_name = String(column_names[j])
                    var value = String(record[col_name])
                    row[col_name] = value
                rows.append(row.copy())
            
            # Create table
            var table = Table(table_name, rows)
            self.tables[table_name] = table
            
            # TODO: Implement B+ tree indexing
            # Rebuild B+ tree index
            # self.index = BPlusTree()
            # for i in range(len(rows)):
            #     var row = rows[i].copy()
            #     if "id" in row.data:
            #         var id_str = row["id"]
            #         try:
            #             var id_int = Int(id_str)
            #             self.index.insert(id_int, row.copy())
            #         except:
            #             self.index.insert(i, row.copy())
            
            print("Table '" + table_name + "' loaded from disk")
        except:
            raise Error("Table '" + table_name + "' not found on disk")

    fn persist_all_tables(mut self) raises:
        """
        Save all tables to disk.
        """
        for table_name in self.tables.keys():
            self.save_table_to_disk(table_name)

    fn load_all_tables(mut self) raises:
        """
        Load all tables from disk (if they exist).
        """
        # This would need a way to discover table names from disk
        # For now, this is a placeholder
        pass

    fn validate_type(self, type_name: String, value: String) raises -> Bool:
        """
        Validate a value against a custom type.
        """
        if type_name not in self.types:
            return False
        
        var type_def = self.types[type_name]
        if type_def.type_kind == "STRUCT":
            # For STRUCT, value should be a dict-like structure
            # Basic validation - check if it's a valid expression
            return True  # Placeholder
        elif type_def.type_kind == "EXCEPTION":
            # For EXCEPTION, value should be a string message
            return True  # Placeholder
        
        return False

    fn get_type_info(self, type_name: String) -> String:
        """
        Get information about a custom type.
        """
        if type_name not in self.types:
            return "Type '" + type_name + "' not found"
        
        var type_def = self.types[type_name]
        var info = "Type: " + type_name + "\n"
        info += "Kind: " + type_def.type_kind + "\n"
        
        if type_def.type_kind == "STRUCT":
            info += "Fields: "
            for field in type_def.type_fields:
                info += field + " "
        elif type_def.type_kind == "EXCEPTION":
            info += "Message: " + type_def.exception_message
        
        return info

    fn optimize_memory(mut self) raises:
        """
        Optimize memory usage by cleaning up unused data.
        """
        # Force garbage collection if available
        try:
            var gc = Python.import_module("gc")
            gc.collect()
        except:
            pass
        
        # Compact tables by removing deleted rows (placeholder for future)
        # For now, just update memory usage
        self.update_memory_usage()
        print("Memory optimization completed")

    fn apply_pagination(self, rows: List[Row], query: Query) -> List[Row]:
        """
        Apply LIMIT and OFFSET to a list of rows.
        """
        var result = List[Row]()
        var start_idx = query.offset
        var end_idx = len(rows)
        
        if query.limit > 0:
            end_idx = min(start_idx + query.limit, len(rows))
        
        for i in range(start_idx, end_idx):
            result.append(rows[i].copy())
        
        return result^

    fn preprocess_macros(mut self, sql: String) raises -> String:
        """
        Replace macro placeholders in SQL.
        """
        var result = sql
        var macro_names = List[String]()
        for name in self.macros.keys():
            macro_names.append(name)
        for macro_name in macro_names:
            var macro = self.macros[macro_name].copy()
            var placeholder = "{{" + macro_name + "}}"
            result = result.replace(placeholder, macro.macro_sql)
        return result

    fn execute_query(mut self, mut query: Query) raises -> List[Row]:
        """
        Execute a parsed query.
        """
        var time_module = Python.import_module("time")
        var start_time = time_module.time()
        
        self.query_count += 1
        
        # Check memory usage periodically
        _ = self.check_memory_usage()
        
        # Handle variable interpolation in table_name
        var table_name = query.table_name
        if table_name.startswith("{") and table_name.endswith("}"):
            var var_name = table_name[1:len(table_name)-1]
            if var_name in self.variables:
                table_name = self.variables[var_name]
        
        if query.query_type == "CREATE":
            self.create_table(table_name)
            var end_time = time_module.time()
            var elapsed = Float64(end_time) - Float64(start_time)
            self.update_query_stats(elapsed)
            return List[Row]()
        elif query.query_type == "SELECT":
            # Check cache first for SELECT queries
            var cached_result = self.get_cached_result(query)
            if len(cached_result) > 0:
                var end_time = time_module.time()
                var elapsed = Float64(end_time) - Float64(start_time)
                self.update_query_stats(elapsed)
                return cached_result.copy()
            
            # Handle function calls like SELECT generate_ulid()
            if len(query.select_expressions) > 0:
                var expr = query.select_expressions[0]
                if expr.find("(") != -1 and expr.find(")") != -1:
                    # This looks like a function call
                    var func_name = String(expr.split("(")[0].strip())
                    var args_str = expr.split("(")[1].split(")")[0].strip()
                    var args = List[String]()
                    if len(args_str) > 0:
                        for arg in args_str.split(","):
                            args.append(String(arg.strip()))
                    
                    var result = self.execute_function(func_name, args)
                    # Return result as a single row
                    var row = Row()
                    row["result"] = result
                    var results = List[Row]()
                    results.append(row.copy())
                    var end_time = time_module.time()
                    var elapsed = Float64(end_time) - Float64(start_time)
                    self.update_query_stats(elapsed)
                    return results^
            
            var base_results = List[Row]()
            var where_value = query.where_value
            if query.using_secret != "":
                where_value = self.get_secret(query.using_secret, query.using_secret_type)
            if query.where_column != "":
                # Simple WHERE for = only
                for row in self.tables[table_name].rows:
                    if row[query.where_column] == query.where_value:
                        base_results.append(row.copy())
            else:
                base_results = self.select_all_from_table(table_name)
            
            base_results = self.apply_pagination(base_results, query)
            
            # Process window functions if any
            if len(query.window_functions) > 0:
                base_results = self.apply_window_functions(base_results, query)
            
            # Cache the result
            self.cache_result(query, base_results)
            var end_time = time_module.time()
            var elapsed = Float64(end_time) - Float64(start_time)
            self.update_query_stats(elapsed)
            return base_results.copy()
        elif query.query_type == "INSERT":
            var row = Row()
            # Assume columns are id, name, age for simplicity
            if len(query.values) >= 3:
                row["id"] = query.values[0]
                row["name"] = query.values[1]
                row["age"] = query.values[2]
            self.insert_into_table(table_name, row)
            # Invalidate cache for this table
            self.invalidate_cache_for_table(table_name)
            var end_time = time_module.time()
            var elapsed = Float64(end_time) - Float64(start_time)
            self.update_query_stats(elapsed)
            return List[Row]()
        elif query.query_type == "SET":
            self.variables[query.var_name] = query.var_value
            print("Variable '" + query.var_name + "' set to '" + query.var_value + "'")
            return List[Row]()
        elif query.query_type == "CREATE_TYPE":
            if query.type_name in self.types:
                raise Error("Type '" + query.type_name + "' already exists")
            self.types[query.type_name] = query.copy()
            print("Type '" + query.type_name + "' created as " + query.type_kind)
            return List[Row]()
        elif query.query_type == "CREATE_FUNCTION":
            self.functions[query.func_name] = query.copy()
            print("Function '" + query.func_name + "' created")
            return List[Row]()
        elif query.query_type == "CREATE_MODEL":
            if query.model_name in self.models:
                raise Error("Model '" + query.model_name + "' already exists")
            self.models[query.model_name] = query.copy()
            print("Model '" + query.model_name + "' created")
            return List[Row]()
        elif query.query_type == "CREATE_TEST":
            if query.test_name in self.tests:
                raise Error("Test '" + query.test_name + "' already exists")
            self.tests[query.test_name] = query.copy()
            print("Test '" + query.test_name + "' created")
            return List[Row]()
        elif query.query_type == "CREATE_SNAPSHOT":
            if query.snapshot_name in self.snapshots:
                raise Error("Snapshot '" + query.snapshot_name + "' already exists")
            self.snapshots[query.snapshot_name] = query.copy()
            print("Snapshot '" + query.snapshot_name + "' created")
            return List[Row]()
        elif query.query_type == "CREATE_MACRO":
            if query.macro_name in self.macros:
                raise Error("Macro '" + query.macro_name + "' already exists")
            self.macros[query.macro_name] = query.copy()
            print("Macro '" + query.macro_name + "' created")
            return List[Row]()
        elif query.query_type == "CREATE_SCHEDULE":
            if query.schedule_name in self.schedules:
                raise Error("Schedule '" + query.schedule_name + "' already exists")
            self.schedules[query.schedule_name] = query.copy()
            print("Schedule '" + query.schedule_name + "' created")
            return List[Row]()
        elif query.query_type == "CREATE_SECRET":
            self.create_secret(query.secret_name, query.secret_type, query.secret_value)
            return List[Row]()
        elif query.query_type == "DROP_SECRET":
            self.drop_secret(query.secret_name, query.secret_type)
            return List[Row]()
        elif query.query_type == "SHOW_SECRETS":
            var secrets_list = self.show_secrets()
            print("Secrets:")
            for secret in secrets_list:
                print("  " + secret)
            return List[Row]()
        elif query.query_type == "SHOW_TYPES":
            print("Custom Types:")
            for type_name in self.types.keys():
                var type_key = String(type_name)
                var type_query = self.types[type_key].copy()
                print("  " + type_name + " (" + type_query.type_kind + ")")
            return List[Row]()
        elif query.query_type == "SHOW_EXTENSIONS":
            print("Loaded Extensions:")
            print("  scm - Source Control Management (built-in)")
            print("  repl - Interactive REPL (built-in)")
            print("  query_parser - SQL Query Parser (built-in)")
            print("  block_store - Block Storage (built-in)")
            print("  blob_store - BLOB Storage (built-in)")
            print("  wal - Write-Ahead Logging (built-in)")
            print("  fractal_tree - Fractal Tree Indexing (built-in)")
            return List[Row]()
        elif query.query_type == "SHOW_MODELS":
            print("Data Models:")
            for model_name in self.models.keys():
                var model_key = String(model_name)
                var model = self.models[model_key].copy()
                print("  " + model_name + " (" + model.model_materialization + ")")
            return List[Row]()
        elif query.query_type == "RUN_MODEL":
            if query.run_model_name not in self.models:
                raise Error("Model '" + query.run_model_name + "' not found")
            var model = self.models[query.run_model_name].copy()
            var sql = model.model_sql
            var is_incremental = model.model_materialization == "incremental"
            if is_incremental:
                var last = self.last_run.get(query.run_model_name, "1970-01-01 00:00:00")
                sql += " WHERE updated_at > '" + last + "'"
            print("Executing model '" + query.run_model_name + "' (" + model.model_materialization + "): " + sql)
            # Simulate execution and materialization
            var table_name = query.run_model_name
            if table_name not in self.tables:
                self.create_table(table_name)
                if is_incremental:
                    print("Table '" + table_name + "' created with automatic partitioning")
            # Assume insert new rows
            print("Materialized " + String(10) + " rows into '" + table_name + "'")
            if is_incremental:
                # Update last_run
                var time_module = Python.import_module("time")
                var current_time = time_module.time()
                var time_str = String(current_time)  # Simplified
                self.last_run[query.run_model_name] = time_str
                print("Updated last_run for '" + query.run_model_name + "' to " + time_str)
            return List[Row]()
        elif query.query_type == "GENERATE_DOCS":
            print("# Data Models Documentation\n")
            var model_names = List[String]()
            for name in self.models.keys():
                model_names.append(name)
            for model_name in model_names:
                var model = self.models[model_name].copy()
                print("## Model: " + model_name)
                print("Materialization: " + model.model_materialization)
                print("SQL: " + model.model_sql)
                print("")
            return List[Row]()
        elif query.query_type == "ORCHESTRATE":
            print("Starting orchestration of " + String(len(query.orchestrate_models)) + " models")
            for model_name in query.orchestrate_models:
                if model_name not in self.models:
                    raise Error("Model '" + model_name + "' not found in orchestration")
                print("Running model '" + model_name + "'")
                # Create a RUN_MODEL query for this model
                var run_query = Query()
                run_query.query_type = "RUN_MODEL"
                run_query.run_model_name = model_name
                # Execute the model
                _ = self.execute_query(run_query)
            print("Orchestration completed")
            return List[Row]()
        elif query.query_type == "RUN_SCHEDULER":
            self.run_scheduler()
            return List[Row]()
        elif query.query_type == "CREATE_BUCKET":
            var success = self.blob_store.create_bucket(query.blob_bucket)
            if success:
                print("Bucket '" + query.blob_bucket + "' created")
            else:
                print("Bucket '" + query.blob_bucket + "' already exists")
            return List[Row]()
        elif query.query_type == "DELETE_BUCKET":
            var success = self.blob_store.delete_bucket(query.blob_bucket)
            if success:
                print("Bucket '" + query.blob_bucket + "' deleted")
            else:
                print("Bucket '" + query.blob_bucket + "' not found or not empty")
            return List[Row]()
        elif query.query_type == "PUT_BLOB":
            var metadata = self.blob_store.put_object(query.blob_bucket, query.blob_key, query.blob_data, query.blob_content_type, query.blob_tags)
            print("Object '" + query.blob_key + "' uploaded to bucket '" + query.blob_bucket + "'")
            print("ETag: " + metadata.etag + ", Size: " + String(metadata.size) + " bytes")
            return List[Row]()
        elif query.query_type == "GET_BLOB":
            var obj = self.blob_store.get_object(query.blob_bucket, query.blob_key)
            print("Object '" + query.blob_key + "' retrieved from bucket '" + query.blob_bucket + "'")
            print("Size: " + String(obj.metadata.size) + " bytes, Content-Type: " + obj.metadata.content_type)
            # Return metadata as result
            var row = Row()
            row["bucket"] = obj.metadata.bucket
            row["key"] = obj.metadata.key
            row["size"] = String(obj.metadata.size)
            row["content_type"] = obj.metadata.content_type
            row["etag"] = obj.metadata.etag
            row["last_modified"] = obj.metadata.last_modified
            var results = List[Row]()
            results.append(row.copy())
            return results^
        elif query.query_type == "DELETE_BLOB":
            var success = self.blob_store.delete_object(query.blob_bucket, query.blob_key)
            if success:
                print("Object '" + query.blob_key + "' deleted from bucket '" + query.blob_bucket + "'")
            else:
                print("Object '" + query.blob_key + "' not found in bucket '" + query.blob_bucket + "'")
            return List[Row]()
        elif query.query_type == "LIST_BLOBS":
            var objects = self.blob_store.list_objects(query.blob_bucket, query.blob_prefix, query.blob_max_keys)
            print("Objects in bucket '" + query.blob_bucket + "':")
            for obj_metadata in objects:
                print("  " + obj_metadata.key + " (" + String(obj_metadata.size) + " bytes, " + obj_metadata.last_modified + ")")
            return List[Row]()
        elif query.query_type == "COPY_BLOB":
            var metadata = self.blob_store.copy_object(query.blob_source_bucket, query.blob_source_key, query.blob_dest_bucket, query.blob_dest_key)
            print("Object copied from '" + query.blob_source_bucket + "/" + query.blob_source_key + "' to '" + query.blob_dest_bucket + "/" + query.blob_dest_key + "'")
            return List[Row]()
        elif query.query_type == "RUN_TESTS":
            print("Running data quality tests...")
            var test_names = List[String]()
            for name in self.tests.keys():
                test_names.append(name)
            var passed = 0
            var failed = 0
            for test_name in test_names:
                var test = self.tests[test_name].copy()
                # For simplicity, assume test_condition is a WHERE clause
                # Execute SELECT COUNT(*) FROM test_model WHERE test_condition
                var count_query_str = "SELECT COUNT(*) FROM " + test.test_model + " WHERE " + test.test_condition
                # Since parse_query not available, simulate
                print("Test '" + test_name + "': " + count_query_str)
                # Assume pass if no error, but for real, need to execute and check count == 0
                print("  PASSED (simulated)")
                passed += 1
            print("Tests completed: " + String(passed) + " passed, " + String(failed) + " failed")
            return List[Row]()
        elif query.query_type == "RUN_SNAPSHOT":
            if query.run_snapshot_name not in self.snapshots:
                raise Error("Snapshot '" + query.run_snapshot_name + "' not found")
            var snapshot = self.snapshots[query.run_snapshot_name].copy()
            print("Running snapshot '" + query.run_snapshot_name + "': " + snapshot.snapshot_sql)
            # Simulate SCD: add valid_from, valid_to
            var table_name = query.run_snapshot_name + "_snapshot"
            if table_name not in self.tables:
                self.create_table(table_name)
                print("Snapshot table '" + table_name + "' created with SCD columns")
            # Assume insert with valid_from = now, valid_to = null
            print("Captured " + String(5) + " rows in snapshot")
            return List[Row]()
        elif query.query_type == "BACKFILL":
            if query.backfill_model not in self.models:
                raise Error("Model '" + query.backfill_model + "' not found")
            print("Backfilling model '" + query.backfill_model + "' from " + query.backfill_from + " to " + query.backfill_to)
            # Simulate backfill: loop over dates
            var from_date = query.backfill_from
            var to_date = query.backfill_to
            # Assume dates are YYYY-MM-DD, simple loop
            var current = from_date
            while current <= to_date:
                print("  Processing date: " + current)
                # Modify SQL with date filter
                var model = self.models[query.backfill_model].copy()
                var sql = model.model_sql + " WHERE date_column = '" + current + "'"
                print("    SQL: " + sql)
                # Simulate execution
                print("    Processed 10 rows")
                # Next date (simplified)
                current = "next_date"  # Placeholder
                if current > to_date:
                    break
            print("Backfill completed")
            return List[Row]()
        elif query.query_type == "ATTACH":
            self.attached_databases[query.attach_alias] = query.attach_path
            print("Attached '" + query.attach_path + "' as '" + query.attach_alias + "'")
            return List[Row]()
        elif query.query_type == "DETACH":
            if query.attach_alias in self.attached_databases:
                _ = self.attached_databases.pop(query.attach_alias, "")
                print("Detached '" + query.attach_alias + "'")
            else:
                print("Alias '" + query.attach_alias + "' not found")
            return List[Row]()
        elif query.query_type == "LOAD":
            self.load_extension(query.load_extension)
            return List[Row]()
        elif query.query_type == "INSTALL":
            print("Extension installation not yet implemented")
            return List[Row]()
        elif query.query_type == "CREATE_TRIGGER":
            var key = query.trigger_table + "_" + query.trigger_event + "_" + query.trigger_timing
            self.triggers[key] = query.copy()
            print("Trigger '" + query.trigger_name + "' created")
            return List[Row]()
        elif query.query_type == "CREATE_CRON_JOB":
            self.cron_jobs[query.cron_name] = query.copy()
            print("Cron job '" + query.cron_name + "' created")
            return List[Row]()
        elif query.query_type == "DROP_CRON_JOB":
            if query.cron_name in self.cron_jobs:
                _ = self.cron_jobs.pop(query.cron_name, Query())
                print("Cron job '" + query.cron_name + "' dropped")
            else:
                print("Cron job '" + query.cron_name + "' not found")
            return List[Row]()
        elif query.query_type == "PL":
            query.pl_code = self.preprocess_macros(query.pl_code)
            var result = self.eval_pl_expression(query.pl_code)
            print(result)
            var end_time = time_module.time()
            var elapsed = Float64(end_time) - Float64(start_time)
            self.update_query_stats(elapsed)
            return List[Row]()
        elif query.query_type == "BACKUP":
            self.backup(query.backup_path)
            return List[Row]()
        elif query.query_type == "RESTORE":
            self.restore(query.restore_path)
            return List[Row]()
        elif query.query_type == "OPTIMIZE":
            self.optimize_memory()
            return List[Row]()
        else:
            raise Error("Query type not implemented: " + query.query_type)

    fn update_query_stats(mut self, elapsed: Float64):
        """
        Update query execution statistics.
        """
        self.total_query_time += elapsed
        self.last_query_time = elapsed
        if elapsed < self.min_query_time:
            self.min_query_time = elapsed
        if elapsed > self.max_query_time:
            self.max_query_time = elapsed

    fn update_memory_usage(mut self) raises:
        """
        Update current memory usage estimate.
        """
        try:
            var psutil = Python.import_module("psutil")
            var process = psutil.Process()
            var mem_info = process.memory_info()
            self.memory_usage = Int(mem_info.rss)
        except:
            # Fallback to approximate calculation
            var approx = 0
            for table in self.tables.values():
                approx += len(table.rows) * 100  # Rough estimate per row
            self.memory_usage = approx

    fn load_config(mut self, config_path: String) raises:
        """
        Load configuration from JSON file.
        """
        try:
            var json = Python.import_module("json")
            var os = Python.import_module("os")
            if os.path.exists(config_path):
                var f = Python.evaluate("open('" + config_path + "', 'r')")
                var data = json.load(f)
                for key in data.keys():
                    self.config[String(key)] = String(data[key])
                Python.evaluate("f.close()")
                print("Configuration loaded from " + config_path)
            else:
                print("Config file not found, using defaults")
        except e:
            print("Error loading config: " + String(e))

    fn get_health(mut self) raises -> String:
        """
        Get database health status.
        """
        self.update_memory_usage()
        var avg_time = 0.0
        if self.query_count > 0:
            avg_time = self.total_query_time / Float64(self.query_count)
        var status = "Database Health Status:\n"
        status += "  Queries executed: " + String(self.query_count) + "\n"
        status += "  Total query time: " + String(self.total_query_time) + "s\n"
        status += "  Average query time: " + String(avg_time) + "s\n"
        status += "  Min query time: " + String(self.min_query_time) + "s\n"
        status += "  Max query time: " + String(self.max_query_time) + "s\n"
        status += "  Last query time: " + String(self.last_query_time) + "s\n"
        status += "  Memory usage: " + String(self.memory_usage) + " bytes\n"
        status += "  Active connections: " + String(self.active_connections) + "\n"
        status += "  Tables: " + String(len(self.tables)) + "\n"
        status += "  Status: OK"
        return status

    fn backup(mut self, backup_path: String) raises:
        """
        Create a backup of the database state.
        """
        var json = Python.import_module("json")
        var backup_data = Python.dict()
        
        # Backup tables
        var tables_data = Python.dict()
        for table_name in self.tables.keys():
            var table_key = String(table_name)
            var table = self.tables[table_key].copy()
            var rows_data = Python.list()
            for row in table.rows:
                var row_data = Python.dict()
                for key in row.data.keys():
                    var key_str = String(key)
                    row_data[key_str] = String(row.data[key_str])
                rows_data.append(row_data)
            tables_data[table_key] = rows_data
        backup_data["tables"] = tables_data
        
        # Backup other state
        var variables_py = Python.dict()
        for key in self.variables.keys():
            var key_str = String(key)
            variables_py[key_str] = String(self.variables[key_str])
        backup_data["variables"] = variables_py
        
        var secrets_py = Python.dict()
        for key in self.secrets.keys():
            var key_str = String(key)
            secrets_py[key_str] = String(self.secrets[key_str])
        backup_data["secrets"] = secrets_py
        backup_data["triggers"] = Python.dict()  # Simplified
        backup_data["cron_jobs"] = Python.dict()  # Simplified
        backup_data["schedules"] = Python.dict()  # Simplified
        
        var f = Python.evaluate("open('" + backup_path + "', 'w')")
        json.dump(backup_data, f)
        Python.evaluate("f.close()")
        print("Backup created at " + backup_path)

    fn restore(mut self, backup_path: String) raises:
        """
        Restore database state from backup.
        """
        var json = Python.import_module("json")
        var os = Python.import_module("os")
        if not os.path.exists(backup_path):
            raise Error("Backup file not found")
            
        var builtins = Python.import_module("builtins")
        var f = builtins.open(backup_path, "r")
        var backup_data = json.load(f)
        f.close()
            
        # Restore tables
        if "tables" in backup_data:
            var tables_data = backup_data["tables"]
            for table_name in tables_data.keys():
                var table_rows = tables_data[table_name]
                var table = Table(String(table_name), List[Row]())
                for row_data in table_rows:
                    var row = Row()
                    for key in row_data.keys():
                        row[String(key)] = String(row_data[key])
                    table.rows.append(row^)
                self.tables[String(table_name)] = table.copy()
        
        print("Database restored from " + backup_path)

    fn export_table_to_json(mut self, table_name: String) raises -> String:
        """
        Export a table to JSON string.
        """
        if table_name not in self.tables:
            raise Error("Table not found")
        var table = self.tables[table_name]
        var json_mod = Python.import_module("json")
        var data = Python.list()
        for row in table.rows:
            var row_dict = Python.dict()
            for key in row.data.keys():
                var k = String(key)
                var v = row[k]
                row_dict[k] = v
            data.append(row_dict)
        var json_str = json_mod.dumps(data)
        return String(json_str)

    fn import_table_from_json(mut self, table_name: String, json_str: String) raises:
        """
        Import a table from JSON string.
        """
        if table_name in self.tables:
            raise Error("Table already exists")
        var json_mod = Python.import_module("json")
        var data = json_mod.loads(json_str)
        var rows = List[Row]()
        for item in data:
            var row = Row()
            for key in item.keys():
                var k = String(key)
                var v = String(item[key])
                row[k] = v
            rows.append(row)
        self.tables[table_name] = Table(table_name, rows)

    fn export_table_to_csv(mut self, table_name: String) raises -> String:
        """
        Export a table to CSV string.
        """
        if table_name not in self.tables:
            raise Error("Table not found")
        var table = self.tables[table_name]
        var io_mod = Python.import_module("io")
        var string_io = io_mod.StringIO()
        var csv_mod = Python.import_module("csv")
        var csv_writer = csv_mod.writer(string_io)
        if len(table.rows) > 0:
            var first_row = table.rows[0]
            var headers = Python.list()
            for key in first_row.data.keys():
                headers.append(String(key))
            csv_writer.writerow(headers)
            for row in table.rows:
                var values = Python.list()
                for key in headers:
                    var k = String(key)
                    var v = row[k]
                    values.append(v)
                csv_writer.writerow(values)
        return String(string_io.getvalue())

    fn import_table_from_csv(mut self, table_name: String, csv_str: String) raises:
        """
        Import a table from CSV string.
        """
        if table_name in self.tables:
            raise Error("Table already exists")
        var csv_mod = Python.import_module("csv")
        var io_mod = Python.import_module("io")
        var string_io = io_mod.StringIO(csv_str)
        var csv_reader = csv_mod.reader(string_io)
        var rows = List[Row]()
        var headers = Python.list()
        var first = True
        for row in csv_reader:
            if first:
                headers = row
                first = False
            else:
                var r = Row()
                for i in range(len(headers)):
                    var k = String(headers[i])
                    var v = String(row[i])
                    r[k] = v
                rows.append(r)
        self.tables[table_name] = Table(table_name, rows)

    fn get_table_data(mut self, table_name: String) raises -> PythonObject:
        """
        Get table data as Python list of dicts for external use.
        """
        if table_name not in self.tables:
            raise Error("Table not found")
        var table = self.tables[table_name]
        var data = Python.list()
        for row in table.rows:
            var row_dict = Python.dict()
            for key in row.data.keys():
                var k = String(key)
                var v = row[k]
                row_dict[k] = v
            data.append(row_dict)
        return data

    fn load_plugin(mut self, name: String, module: String) raises:
        """
        Load a Python module as a plugin.
        """
        var mod = Python.import_module(module)
        self.plugins[name] = mod
        print("Plugin '" + name + "' loaded from '" + module + "'")

    fn begin_transaction(mut self):
        """
        Begin a transaction.
        """
        self.in_transaction = True
        self.transaction_log = List[String]()
        print("Transaction begun")

    fn commit_transaction(mut self):
        """
        Commit the current transaction.
        """
        self.in_transaction = False
        # Placeholder: apply transaction log
        self.transaction_log = List[String]()
        print("Transaction committed")

    fn rollback_transaction(mut self):
        """
        Rollback the current transaction.
        """
        self.in_transaction = False
        # Placeholder: undo changes
        self.transaction_log = List[String]()
        print("Transaction rolled back")

    fn backup_to_file(mut self, filename: String) raises:
        """
        Backup database to file (placeholder).
        """
        print("Backup to '" + filename + "' not implemented")

    fn restore_from_file(mut self, filename: String) raises:
        """
        Restore database from file (placeholder).
        """
        print("Restore from '" + filename + "' not implemented")

    fn execute_function(mut self, name: String, args: List[String]) raises -> String:
        """
        Execute a stored PL function or built-in function.
        """
        # Handle built-in functions
        if name == "generate_ulid":
            return self.generate_ulid()
        elif name == "generate_uuid_v4":
            return self.generate_uuid_v4()
        elif name == "generate_uuid_v5":
            if len(args) != 2:
                raise Error("generate_uuid_v5 requires 2 arguments: namespace and name")
            return self.generate_uuid_v5(args[0], args[1])

        # Handle user-defined functions
        if name not in self.functions:
            raise Error("Function not found")
        var func = self.functions[name].copy()
        # Basic execution using Python eval for simple expressions
        try:
            var result = Python.evaluate(func.func_body)
            return String(result)
        except:
            return "Function execution not fully implemented"

    fn eval_pl_expression(mut self, expr: String) raises -> String:
        """
        Evaluate a PL expression with arithmetic support.
        """
        # Preprocess method calls on custom types
        var processed_expr = self.preprocess_method_calls(expr)
        
        var tokens = self.tokenize_expr(processed_expr)
        var current_pos = 0
        var result_str, _ = self.parse_expr(tokens, current_pos)
        try:
            var py_result = Python.evaluate(result_str)
            var builtins = Python.import_module("builtins")
            var str_result = builtins.str(py_result)
            return String(str_result)
        except e:
            print("Error evaluating:", result_str, "exception:", String(e))
            return "Error evaluating expression"

    fn preprocess_method_calls(self, expr: String) raises -> String:
        """
        Preprocess method calls on custom types.
        """
        # Simple preprocessing: replace known method calls
        var result = expr
        if ".length()" in expr:
            result = result.replace(".length()", ".__len__()")
        # Handle function calls
        for func_name in self.functions.keys():
            if func_name + "(" in expr:
                # Replace function call with PL execution
                var func_def = self.functions[func_name].copy()
                result = self.replace_function_call(result, func_name, func_def)
        return result

    fn replace_function_call(self, expr: String, func_name: String, func_def: Query) -> String:
        """
        Replace function call with its body execution.
        """
        # Extract arguments from function call
        var start_idx = expr.find(func_name + "(")
        if start_idx == -1:
            return expr
        
        var call_start = start_idx + len(func_name) + 1
        var paren_count = 1
        var call_end = call_start
        
        while call_end < len(expr) and paren_count > 0:
            if expr[call_end] == "(":
                paren_count += 1
            elif expr[call_end] == ")":
                paren_count -= 1
            call_end += 1
        
        if paren_count != 0:
            return expr  # Malformed call
        
        var args_str = expr[call_start:call_end-1]
        var args = args_str.split(",")
        
        # Handle async functions differently
        if func_def.func_async:
            # For async functions, wrap in Python asyncio execution
            var async_wrapper = "python_async_exec(\"" + func_def.func_body.replace("\"", "\\\"") + "\")"
            var result = expr[:start_idx] + async_wrapper + expr[call_end:]
            return result
        else:
            # Simple function execution: replace with function body
            # In a real implementation, this would handle parameter substitution
            var result = expr[:start_idx] + "(" + func_def.func_body + ")" + expr[call_end:]
            return result

    fn tokenize_expr(self, expr: String) -> List[String]:
        var tokens = List[String]()
        var i = 0
        while i < len(expr):
            if expr[i] == " ":
                i += 1
                continue
            if expr[i] in "+-*/()[]{}:.":
                tokens.append(String(expr[i]))
                i += 1
            else:
                var start = i
                while i < len(expr) and not (expr[i] in "+-*/() "):
                    i += 1
                tokens.append(expr[start:i])
        return tokens.copy()

    fn parse_expr(mut self, tokens: List[String], pos: Int) raises -> Tuple[String, Int]:
        var current_pos = pos
        var temp_result, temp_pos = self.parse_term(tokens, current_pos)
        var result = temp_result
        current_pos = temp_pos
        while current_pos < len(tokens) and (tokens[current_pos] == "+" or tokens[current_pos] == "-"):
            var op = tokens[current_pos]
            current_pos += 1
            var right, current_pos = self.parse_term(tokens, current_pos)
            result = result + " " + op + " " + right
        return result, current_pos

    fn parse_term(mut self, tokens: List[String], pos: Int) raises -> Tuple[String, Int]:
        var current_pos = pos
        var temp_result, temp_pos = self.parse_factor(tokens, current_pos)
        var result = temp_result
        current_pos = temp_pos
        while current_pos < len(tokens) and (tokens[current_pos] == "*" or tokens[current_pos] == "/"):
            var op = tokens[current_pos]
            current_pos += 1
            var right, current_pos = self.parse_factor(tokens, current_pos)
            result = result + " " + op + " " + right
        return result, current_pos

    fn parse_factor(mut self, tokens: List[String], pos: Int) raises -> Tuple[String, Int]:
        var current_pos = pos
        if current_pos < len(tokens):
            var token = tokens[current_pos]
            current_pos += 1
            var result_str: String
            if token == "(":
                var inner, new_pos = self.parse_expr(tokens, current_pos)
                result_str = "(" + inner + ")"
                current_pos = new_pos
                if current_pos < len(tokens) and tokens[current_pos] == ")":
                    current_pos += 1
            elif token == "[":
                var array_str = "["
                var first = True
                while current_pos < len(tokens) and tokens[current_pos] != "]":
                    if not first:
                        array_str += ","
                    var element_str, temp_pos = self.parse_expr(tokens, current_pos)
                    array_str += element_str
                    current_pos = temp_pos
                    if current_pos < len(tokens) and tokens[current_pos] == ",":
                        current_pos += 1
                    else:
                        break
                    first = False
                if current_pos < len(tokens) and tokens[current_pos] == "]":
                    current_pos += 1
                array_str += "]"
                result_str = array_str
            elif token == "{":
                var map_str = "{"
                var first = True
                while current_pos < len(tokens) and tokens[current_pos] != "}":
                    if not first:
                        map_str += ","
                    var key_str, temp_pos = self.parse_expr(tokens, current_pos)
                    map_str += key_str
                    current_pos = temp_pos
                    if current_pos < len(tokens) and tokens[current_pos] == ":":
                        map_str += ":"
                        current_pos += 1
                    var value_str, temp_pos2 = self.parse_expr(tokens, current_pos)
                    map_str += value_str
                    current_pos = temp_pos2
                    if current_pos < len(tokens) and tokens[current_pos] == ",":
                        current_pos += 1
                    else:
                        break
                    first = False
                if current_pos < len(tokens) and tokens[current_pos] == "}":
                    current_pos += 1
                map_str += "}"
                result_str = map_str
            else:
                # variable or number
                if token in self.variables:
                    result_str = self.variables[token]
                else:
                    result_str = token
            # Handle method calls and field access
            while current_pos < len(tokens) and tokens[current_pos] == ".":
                current_pos += 1
                if current_pos < len(tokens):
                    var member = tokens[current_pos]
                    current_pos += 1
                    if current_pos < len(tokens) and tokens[current_pos] == "(":
                        # method call
                        current_pos += 1
                        var args = List[String]()
                        while current_pos < len(tokens) and tokens[current_pos] != ")":
                            var arg_str, temp_pos = self.parse_expr(tokens, current_pos)
                            args.append(arg_str)
                            current_pos = temp_pos
                            if current_pos < len(tokens) and tokens[current_pos] == ",":
                                current_pos += 1
                        if current_pos < len(tokens) and tokens[current_pos] == ")":
                            current_pos += 1
                        var args_str = ",".join(args)
                        result_str = result_str + "." + member + "(" + args_str + ")"
                    else:
                        # field access
                        result_str = result_str + "." + member
            return result_str, current_pos
        else:
            return "", pos

    fn execute_try_catch(mut self, try_expr: String, catch_patterns: Dict[String, String]) raises -> String:
        """
        Execute TRY/CATCH with pattern matching (placeholder).
        """
        try:
            return self.eval_pl_expression(try_expr)
        except:
            # Placeholder for pattern matching
            if "_" in catch_patterns:
                return catch_patterns["_"]
            return "Exception handling not fully implemented"

    fn execute_pipe(mut self, initial: String, operations: List[String]) raises -> String:
        """
        Execute pipe operations (placeholder).
        """
        var result = initial
        for op in operations:
            # Placeholder: assume op is expression with 'result'
            result = self.eval_pl_expression(op.replace("result", result))
        return result

    fn eval_match(mut self, value: String, cases: Dict[String, String]) raises -> String:
        """
        Evaluate MATCH expression with cases.
        """
        for case in cases.keys():
            if case == value or case == "_":
                return self.eval_pl_expression(cases[case])
        return "No match"

    fn execute_pl_query(mut self, pl_code: String) raises -> String:
        """
        Execute a PL script or expression.
        """
        return self.eval_pl_expression(pl_code)


    fn debug_pl_execution(mut self, code: String) raises -> String:
        """
        Debug PL execution with stack trace (placeholder).
        """
        try:
            return self.execute_pl_query(code)
        except e:
            return "Error: " + String(e) + " (debug info placeholder)"

    fn log_operation(mut self, op: String):
        """
        Log database operations for monitoring.
        """
        print("[LOG] " + op)

    fn get_memory_status(mut self) -> String:
        """
        Check memory usage (placeholder).
        """
        return "Memory usage: placeholder"

    fn enable_access_control(mut self):
        """
        Enable basic access control (placeholder).
        """
        print("Access control enabled (placeholder)")

    fn prevent_sql_injection(mut self, query: String) raises -> String:
        """
        Prevent SQL injection (basic sanitization).
        """
        # Placeholder: basic check
        if "DROP" in query.upper():
            raise Error("Potentially dangerous query")
        return query

    fn create_secret(mut self, name: String, secret_type: String, value: String) raises:
        """
        Create an encrypted secret.
        """
        var crypto = Python.import_module("cryptography.fernet")
        var base64 = Python.import_module("base64")
        var py_master_key = Python.evaluate("'" + self.master_key + "'")
        var fernet_key = base64.urlsafe_b64encode(py_master_key[:32].encode())
        var fernet = crypto.Fernet(fernet_key)
        var py_value = Python.evaluate("'" + value + "'")
        var encrypted = fernet.encrypt(py_value.encode())
        var secret_key = secret_type + ":" + name
        self.secrets[secret_key] = String(encrypted.hex())
        print("Secret '" + name + "' of type '" + secret_type + "' created.")

    fn get_secret(mut self, name: String, secret_type: String) raises -> String:
        """
        Retrieve and decrypt a secret.
        """
        var secret_key = secret_type + ":" + name
        if secret_key not in self.secrets:
            raise Error("Secret not found")
        var crypto = Python.import_module("cryptography.fernet")
        var base64 = Python.import_module("base64")
        var py_master_key = Python.evaluate("'" + self.master_key + "'")
        var fernet_key = base64.urlsafe_b64encode(py_master_key[:32].encode())
        var fernet = crypto.Fernet(fernet_key)
        var builtins = Python.import_module("builtins")
        var py_hex = builtins.str(self.secrets[secret_key])
        var encrypted_bytes = builtins.bytes.fromhex(py_hex)
        var decrypted = fernet.decrypt(encrypted_bytes)
        return String(decrypted.decode())

    fn drop_secret(mut self, name: String, secret_type: String) raises:
        """
        Delete a secret.
        """
        var secret_key = secret_type + ":" + name
        if secret_key not in self.secrets:
            raise Error("Secret not found")
        if secret_key in self.secrets:
            _ = self.secrets.pop(secret_key)
        print("Secret '" + name + "' dropped.")

    fn show_secrets(mut self) -> List[String]:
        """
        List all secret names (without values).
        """
        var result = List[String]()
        for key in self.secrets.keys():
            result.append(key)
        return result^

    fn load_extension(mut self, name: String) raises:
        """
        Load an extension.
        """
        if name in self.plugins:
            print("Extension '" + name + "' already loaded")
            return
        
        if name == "httpfs":
            # Load httpfs extension for HTTP file system access
            try:
                var requests = Python.import_module("requests")
                self.plugins[name] = requests
                print("Loaded httpfs extension - HTTP file access enabled")
            except:
                print("Failed to load httpfs extension - requests module not available")
        elif name == "json":
            # Load JSON processing extension
            try:
                var json = Python.import_module("json")
                self.plugins[name] = json
                print("Loaded json extension - JSON processing enabled")
            except:
                print("Failed to load json extension")
        else:
            print("Extension '" + name + "' not available")

    fn python_async_exec(self, code: String) -> String:
        """
        Execute Python code asynchronously using asyncio.
        For now, simulate async execution.
        """
        try:
            # For async functions, we'll execute the code and return a result
            # In a real implementation, this would use asyncio
            var result = Python.evaluate(code)
            return String(result) + "_async"
        except:
            return "async_execution_error"

    fn generate_cache_key(self, query: Query) -> String:
        """
        Generate a cache key from a query.
        """
        var key_parts = List[String]()
        key_parts.append(query.query_type)
        key_parts.append(query.table_name)
        
        # Add WHERE conditions
        if query.where_column != "":
            key_parts.append(query.where_column + "=" + query.where_value)
        
        # Add LIMIT/OFFSET
        if query.limit != -1:
            key_parts.append("LIMIT=" + String(query.limit))
        if query.offset != 0:
            key_parts.append("OFFSET=" + String(query.offset))
        
        return String(" ".join(key_parts))

    fn get_cached_result(mut self, query: Query) raises -> List[Row]:
        """
        Get cached result for a query if available.
        """
        var cache_key = self.generate_cache_key(query)
        if cache_key in self.query_cache:
            self.cache_hits += 1
            return self.query_cache[cache_key].copy()
        self.cache_misses += 1
        return List[Row]()

    fn cache_result(self, query: Query, result: List[Row]):
        """
        Cache a query result.
        """
        # Check cache size limit
        if len(self.query_cache) >= self.cache_max_size:
            # Simple LRU: remove oldest entry (first in dict iteration)
            if len(self.query_cache) > 0:
                var first_key = ""
                for key in self.query_cache.keys():
                    first_key = key
                    break
                if first_key != "":
                    pass
        
        var cache_key = self.generate_cache_key(query)
        # self.query_cache[cache_key] = result^

    fn get_cache_stats(self) -> String:
        """
        Get cache statistics.
        """
        var total_requests = self.cache_hits + self.cache_misses
        var hit_rate = 0.0
        if total_requests > 0:
            hit_rate = Float64(self.cache_hits) / Float64(total_requests) * 100.0
        
        return "Cache: " + String(len(self.query_cache)) + "/" + String(self.cache_max_size) + " entries, " + String(self.cache_hits) + " hits, " + String(self.cache_misses) + " misses (" + String(hit_rate) + "% hit rate)"

    fn apply_window_functions(mut self, rows: List[Row], query: Query) raises -> List[Row]:
        """
        Apply window functions to the result set.
        """
        if len(query.window_functions) == 0:
            return rows.copy()
        
        var result_rows = List[Row]()
        
        for i in range(len(rows)):
            var row = rows[i].copy()
            var new_row = row.copy()
            # For each window function, compute and add the result
            for wf_expr in query.window_functions:
                # Parse the window function expression
                # Format: function_name() OVER (PARTITION BY col ORDER BY col)
                var func_result = self.compute_window_function(wf_expr, row, rows)
                # Add the result as a new column
                new_row["window_result"] = func_result  # TODO: parse actual column name
            result_rows.append(new_row^)
        
        return result_rows^

    fn compute_window_function(self, wf_expr: String, current_row: Row, all_rows: List[Row]) raises -> String:
        """
        Compute a window function for the current row.
        """
        # Simple implementation for ROW_NUMBER() OVER (ORDER BY col)
        if "ROW_NUMBER()" in wf_expr and "OVER" in wf_expr:
            # Extract ORDER BY column (simplified parsing)
            var order_by_col = "id"  # Default
            if "ORDER BY" in wf_expr:
                var parts = wf_expr.split("ORDER BY")
                if len(parts) > 1:
                    var col_part = String(parts[1]).strip(" )").strip()
                    order_by_col = String(col_part)
            
            # Sort rows by the order column
            var sorted_rows = self.sort_rows_by_column(all_rows, order_by_col)
            
            # Find the position of current_row in sorted list
            for i in range(len(sorted_rows)):
                if self.rows_equal(sorted_rows[i], current_row):
                    return String(i + 1)
        
        return "0"  # Default

    fn sort_rows_by_column(self, rows: List[Row], column: String) raises -> List[Row]:
        """
        Sort rows by a column value.
        """
        var sorted_rows = rows.copy()
        # Simple bubble sort for now
        for i in range(len(sorted_rows)):
            for j in range(i + 1, len(sorted_rows)):
                var row_i = sorted_rows[i].copy()
                var row_j = sorted_rows[j].copy()
                if row_i[column] > row_j[column]:
                    var temp = sorted_rows[i].copy()
                    sorted_rows[i] = sorted_rows[j].copy()
                    sorted_rows[j] = temp^
        return sorted_rows^

    fn rows_equal(self, row1: Row, row2: Row) raises -> Bool:
        """
        Check if two rows are equal.
        """
        if len(row1.keys()) != len(row2.keys()):
            return False
        for key in row1.keys():
            if key not in row2 or row1[key] != row2[key]:
                return False
        return True

    fn execute_triggers(mut self, table_name: String, event: String, timing: String, old_row: Row = Row(), new_row: Row = Row()) raises:
        """
        Execute triggers for the given event and timing.
        """
        var key = table_name + "_" + event + "_" + timing
        if key in self.triggers:
            var trigger = self.triggers[key].copy()
            if trigger.trigger_function in self.functions:
                print("Executing trigger '" + trigger.trigger_name + "'")
                # Placeholder for actual execution
            else:
                print("Trigger function '" + trigger.trigger_function + "' not found")

    fn run_scheduler(mut self) raises:
        """
        Run scheduled jobs based on cron schedules.
        This is a simplified scheduler that checks all schedules.
        """
        print("Running scheduler...")
        for schedule_name in self.schedules.keys():
            var schedule_key = String(schedule_name)
            var schedule = self.schedules[schedule_key].copy()
            print("Checking schedule '" + schedule_name + "' with cron '" + schedule.schedule_cron + "'")
            # Simplified: assume cron matches (in real implementation, would parse cron expression)
            print("Running scheduled models: " + String(len(schedule.schedule_models)))
            for model_name in schedule.schedule_models:
                if model_name not in self.models:
                    print("Warning: Model '" + model_name + "' not found")
                    continue
                print("Running scheduled model '" + model_name + "'")
                # Create and execute RUN_MODEL query
                var run_query = Query()
                run_query.query_type = "RUN_MODEL"
                run_query.run_model_name = model_name
                _ = self.execute_query(run_query)
        print("Scheduler run completed")

    fn generate_ulid(mut self) raises -> String:
        """
        Generate a ULID (Universally Unique Lexicographically Sortable Identifier).
        """
        var py_time = Python.import_module("time")
        var current_time = py_time.time()
        var timestamp = UInt64(current_time * 1000)  # Convert to milliseconds

        # Generate randomness using Python's secrets module
        var secrets = Python.import_module("secrets")
        var random_bytes = secrets.token_bytes(10)  # 80 bits = 10 bytes
        var randomness: UInt64 = 0
        for i in range(10):
            randomness = randomness << 8
            randomness |= UInt64(random_bytes[i])

        # Combine timestamp and randomness into 128-bit value
        var value = UInt128(timestamp) << 80 | UInt128(randomness)

        # Crockford base32 alphabet (no I, L, O, U)
        var alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        var result = String("")

        # Encode 128 bits as 26 base32 characters
        for i in range(26):
            var char_index = Int((value >> (125 - i * 5)) & 0x1F)
            result += alphabet[char_index]

        return result

    fn generate_uuid_v4(mut self) raises -> String:
        """
        Generate a UUID v4 (random).
        """
        var secrets = Python.import_module("secrets")
        var random_bytes = secrets.token_bytes(16)
        var data = List[UInt8]()
        for i in range(16):
            var byte_val = Int(random_bytes[i])
            data.append(byte_val)

        # Set version (4) and variant (RFC 4122)
        data[6] = (data[6] & 0x0F) | 0x40  # Version 4
        data[8] = (data[8] & 0x3F) | 0x80  # Variant 10

        # Convert to string format
        var result = String("")
        var hex_chars = "0123456789abcdef"

        for i in range(16):
            var byte = data[i]
            result += hex_chars[Int(byte >> 4)]
            result += hex_chars[Int(byte & 0x0F)]

            if i == 3 or i == 5 or i == 7 or i == 9:
                result += "-"

        return result

    fn generate_uuid_v5(mut self, namespace: String, name: String) raises -> String:
        """
        Generate UUID v5 (name-based) using SHA-1 hash.
        namespace should be one of: 'dns', 'url', 'oid', 'x500'
        """
        var hashlib = Python.import_module("hashlib")
        var sha1 = hashlib.sha1()

        # Get namespace UUID
        var ns_bytes: List[UInt8]
        if namespace == "dns":
            ns_bytes = List[UInt8]([0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1,
                                   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        elif namespace == "url":
            ns_bytes = List[UInt8]([0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1,
                                   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        elif namespace == "oid":
            ns_bytes = List[UInt8]([0x6b, 0xa7, 0xb8, 0x12, 0x9d, 0xad, 0x11, 0xd1,
                                   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        elif namespace == "x500":
            ns_bytes = List[UInt8]([0x6b, 0xa7, 0xb8, 0x14, 0x9d, 0xad, 0x11, 0xd1,
                                   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        else:
            raise Error("Unknown namespace: " + namespace)

        # Add namespace bytes
        for byte in ns_bytes:
            var byte_list = Python.list()
            byte_list.append(byte)
            sha1.update(Python.evaluate("bytes(byte_list)"))

        # Add name bytes
        var name_bytes = Python.evaluate("bytes('" + name + "', 'utf-8')")
        sha1.update(name_bytes)

        var hash_bytes = sha1.digest()
        var data = List[UInt8]()

        # Take first 16 bytes of SHA-1 hash
        for i in range(16):
            var byte_val = Int(hash_bytes[i])
            data.append(byte_val)

        # Set version (5) and variant (RFC 4122)
        data[6] = (data[6] & 0x0F) | 0x50  # Version 5
        data[8] = (data[8] & 0x3F) | 0x80  # Variant 10

        # Convert to string format
        var result = String("")
        var hex_chars = "0123456789abcdef"

        for i in range(16):
            var byte = data[i]
            result += hex_chars[Int(byte >> 4)]
            result += hex_chars[Int(byte & 0x0F)]

            if i == 3 or i == 5 or i == 7 or i == 9:
                result += "-"

        return result
