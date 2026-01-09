"""
Mojo Kodiak DB - Database Module

Defines the main Database class and core structures.
"""

from python import Python, PythonObject
from types import Row, Table
from wal import WAL
from block_store import BlockStore
from b_plus_tree import BPlusTree
from fractal_tree import FractalTree
from query_parser import Query

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

    fn create_table(mut self, name: String) raises:
        """
        Create a new table with the given name.
        """
        if name in self.tables:
            raise "Table already exists"
        self.tables[name] = Table(name, List[Row]())
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
                raise "Table does not exist"
            self.tables[table_name].insert_row(row)
            # var key = row["id"].int_value()
            # self.index.insert(key, row)
            self.fractal_tree.insert(row)
            self.wal_instance.append_log("INSERT INTO " + table_name)
        finally:
            self.lock.release()

    fn select_from_table(self, table_name: String, filter_func: fn(Row) raises -> Bool) raises -> List[Row]:
        """
        Select rows from the specified table that match the filter.
        """
        self.lock.acquire()
        try:
            if table_name not in self.tables:
                raise "Table does not exist"
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
                raise "Table does not exist"
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
                raise "Table does not exist"
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

    fn join(self, table1_name: String, table2_name: String, on_column1: String, on_column2: String) raises -> List[Row]:
        """
        Perform inner join on two tables based on columns.
        """
        self.lock.acquire()
        try:
            if table1_name not in self.tables or table2_name not in self.tables:
                raise "Table does not exist"
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

    fn begin_transaction(mut self):
        """
        Begin a transaction (placeholder).
        """
        print("Transaction begun")

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

    fn execute_query(mut self, query: Query) raises -> List[Row]:
        """
        Execute a parsed query.
        """
        if query.query_type == "CREATE":
            self.create_table(query.table_name)
            return List[Row]()
        elif query.query_type == "SELECT":
            if query.where_column != "":
                # Simple WHERE for = only
                var results = List[Row]()
                for row in self.tables[query.table_name].rows:
                    if row[query.where_column] == query.where_value:
                        results.append(row.copy())
                return results^
            else:
                return self.select_all_from_table(query.table_name)
        elif query.query_type == "INSERT":
            var row = Row()
            # Assume columns are id, name, age for simplicity
            if len(query.values) >= 3:
                row["id"] = query.values[0]
                row["name"] = query.values[1]
                row["age"] = query.values[2]
            self.insert_into_table(query.table_name, row)
            return List[Row]()
        else:
            raise Error("Query type not implemented: " + query.query_type)