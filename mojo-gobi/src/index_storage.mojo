"""
Database Index Storage
======================

Handles database indexes for efficient data retrieval.
Supports B-tree, hash, and bitmap indexes.
"""

from python import Python, PythonObject
from collections import List, Dict
from blob_storage import BlobStorage
from schema_manager import Index

struct BTreeIndex(Movable, Copyable):
    var data: Dict[String, List[Int]]  # Use Mojo Dict instead of Python object
    var order: Int

    fn __init__(out self, order: Int = 100) raises:
        self.order = order
        self.data = Dict[String, List[Int]]()

    fn __copyinit__(out self, other: Self):
        self.data = other.data.copy()
        self.order = other.order

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.order = existing.order

    fn insert(mut self, key: String, row_id: Int) raises:
        """Insert a key-row_id pair into the B-tree."""
        if not (key in self.data):
            self.data[key] = List[Int]()
        self.data[key].append(row_id)

    fn search(self, key: String) -> List[Int]:
        """Search for row IDs by key."""
        try:
            if key in self.data:
                return self.data[key].copy()
        except:
            pass
        return List[Int]()

    fn range_search(self, start_key: String, end_key: String) -> List[Int]:
        """Search for row IDs in a key range."""
        var results = List[Int]()
        try:
            for key in self.data.keys():
                if key >= start_key and key <= end_key:
                    for row_id in self.data[key]:
                        results.append(row_id)
        except:
            pass
        return results.copy()

struct HashIndex(Movable, Copyable):
    var data: Dict[String, List[Int]]  # Use Mojo Dict instead of Python object
    var bucket_count: Int

    fn __init__(out self, bucket_count: Int = 1000) raises:
        self.bucket_count = bucket_count
        self.data = Dict[String, List[Int]]()

    fn __copyinit__(out self, other: Self):
        self.data = other.data.copy()
        self.bucket_count = other.bucket_count

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.bucket_count = existing.bucket_count

    fn insert(mut self, key: String, row_id: Int) raises:
        """Insert a key-row_id pair into the hash index."""
        if not (key in self.data):
            self.data[key] = List[Int]()
        self.data[key].append(row_id)

    fn search(self, key: String) -> List[Int]:
        """Search for row IDs by key."""
        try:
            if key in self.data:
                return self.data[key].copy()
        except:
            pass
        return List[Int]()

struct BitmapIndex(Movable, Copyable):
    var bitmaps: PythonObject  # Dict of bitmaps for each value
    var max_row_id: Int

    fn __init__(out self, max_row_id: Int = 1000000) raises:
        self.max_row_id = max_row_id
        self.bitmaps = Python.dict()

    fn __copyinit__(out self, other: Self):
        self.bitmaps = other.bitmaps
        self.max_row_id = other.max_row_id

    fn __moveinit__(out self, deinit existing: Self):
        self.bitmaps = existing.bitmaps^
        self.max_row_id = existing.max_row_id

    fn insert(mut self, value: String, row_id: Int):
        """Insert a value-row_id pair into the bitmap index."""
        try:
            var bitmap = self.bitmaps.get(value, Python.list())
            try:
                _ = bitmap[0]  # Try to access first element to check if it's a list
            except:
                bitmap = Python.list()
                
                for i in range(self.max_row_id):
                    bitmap.append(0)

            if row_id < len(bitmap):
                bitmap[row_id] = 1
            else:
                # Extend bitmap if needed
                for i in range(len(bitmap), row_id + 1):
                    bitmap.append(0)
                bitmap[row_id] = 1

            self.bitmaps[value] = bitmap
        except:
            pass

    fn search(self, value: String) -> List[Int]:
        """Search for row IDs by value."""
        var results = List[Int]()
        try:
            var bitmap = self.bitmaps.get(value, Python.list())
            if Python.type(bitmap) == Python.type(Python.list()):
                for i in range(len(bitmap)):
                    if bitmap[i] == 1:
                        results.append(i)
        except:
            pass
        return results.copy()

struct IndexStorage(Copyable, Movable):
    var storage: BlobStorage
    var btree_indexes: Dict[String, BTreeIndex]  # Store BTreeIndex objects directly
    var hash_indexes: Dict[String, HashIndex]
    var bitmap_indexes: Dict[String, BitmapIndex]

    fn __init__(out self, storage: BlobStorage):
        self.storage = storage.copy()
        self.btree_indexes = Dict[String, BTreeIndex]()
        self.hash_indexes = Dict[String, HashIndex]()
        self.bitmap_indexes = Dict[String, BitmapIndex]()

    # Remove __copyinit__ to avoid compilation loops
    # IndexStorage instances should be passed by reference, not copied

    fn __moveinit__(out self, deinit existing: Self):
        self.storage = existing.storage^
        self.btree_indexes = existing.btree_indexes^
        self.hash_indexes = existing.hash_indexes^
        self.bitmap_indexes = existing.bitmap_indexes^

    fn create_index(mut self, index: Index, table_data: List[List[String]], column_positions: Dict[String, Int]) -> Bool:
        """Create and build an index on table data."""
        try:
            var index_name = index.name
            var index_type = index.type

            if index_type == "btree":
                var btree_index = BTreeIndex()
                self._build_btree_index(btree_index, index, table_data, column_positions)
                self.btree_indexes[index_name] = btree_index.copy()
            elif index_type == "hash":
                var hash_index = HashIndex()
                self._build_hash_index(hash_index, index, table_data, column_positions)
                self.hash_indexes[index_name] = hash_index.copy()
            elif index_type == "bitmap":
                var bitmap_index = BitmapIndex()
                self._build_bitmap_index(bitmap_index, index, table_data, column_positions)
                self.bitmap_indexes[index_name] = bitmap_index.copy()
            else:
                return False

            # Save index to storage
            return self._save_index(index_name, index_type)
        except:
            return False

    fn _build_btree_index(mut self, mut btree_index: BTreeIndex, index: Index, table_data: List[List[String]], column_positions: Dict[String, Int]) raises:
        """Build a B-tree index."""
        for row_id in range(len(table_data)):
            var key = self._build_composite_key(index.columns, table_data[row_id], column_positions)
            btree_index.insert(key, row_id)

    fn _build_hash_index(mut self, mut hash_index: HashIndex, index: Index, table_data: List[List[String]], column_positions: Dict[String, Int]) raises:
        """Build a hash index."""
        for row_id in range(len(table_data)):
            var key = self._build_composite_key(index.columns, table_data[row_id], column_positions)
            hash_index.insert(key, row_id)

    fn _build_bitmap_index(mut self, mut bitmap_index: BitmapIndex, index: Index, table_data: List[List[String]], column_positions: Dict[String, Int]) raises:
        """Build a bitmap index."""
        for row_id in range(len(table_data)):
            for col_name in index.columns:
                var col_pos = column_positions[col_name]
                if col_pos < len(table_data[row_id]):
                    var value = table_data[row_id][col_pos]
                    bitmap_index.insert(value, row_id)

    fn _build_composite_key(self, columns: List[String], row: List[String], column_positions: Dict[String, Int]) raises -> String:
        """Build a composite key from multiple columns."""
        var key = ""
        for i in range(len(columns)):
            if i > 0:
                key += "|"
            var col_pos = column_positions[columns[i]]
            if col_pos < len(row):
                key += row[col_pos]
        return key

    fn drop_index(mut self, index_name: String) raises -> Bool:
        """Drop an index."""
        if index_name in self.btree_indexes:
            _ = self.btree_indexes.pop(index_name)
        if index_name in self.hash_indexes:
            _ = self.hash_indexes.pop(index_name)
        if index_name in self.bitmap_indexes:
            _ = self.bitmap_indexes.pop(index_name)
        return self._delete_index_file(index_name)

    fn search_index(mut self, index_name: String, index_type: String, key: String, start_key: String = "", end_key: String = "") -> List[Int]:
        """Search an index for matching row IDs."""
        var results = List[Int]()

        # Check if index exists in memory
        var index_loaded = False
        if index_type == "btree" and index_name in self.btree_indexes:
            index_loaded = True
        elif index_type == "hash" and index_name in self.hash_indexes:
            index_loaded = True
        elif index_type == "bitmap" and index_name in self.bitmap_indexes:
            index_loaded = True

        if not index_loaded:
            # Try to load from storage
            if not self._load_index(index_name, index_type):
                return results.copy()

        try:
            if index_type == "btree":
                var btree_index = self.btree_indexes[index_name].copy()
                if start_key != "" and end_key != "":
                    results = btree_index.range_search(start_key, end_key)
                else:
                    results = btree_index.search(key)

            elif index_type == "hash":
                var hash_index = self.hash_indexes[index_name].copy()
                results = hash_index.search(key)

            elif index_type == "bitmap":
                var bitmap_index = self.bitmap_indexes[index_name].copy()
                results = bitmap_index.search(key)

        except:
            pass

        return results.copy()

    fn _save_index(self, index_name: String, index_type: String) -> Bool:
        """Save index to storage using pickle."""
        try:
            var pickle_module = Python.import_module("pickle")
            var data_dict = Python.dict()

            if index_type == "btree" and index_name in self.btree_indexes:
                var btree_index = self.btree_indexes[index_name].copy()
                # Convert Mojo Dict[String, List[Int]] to Python dict
                var keys = List[String]()
                for key in btree_index.data.keys():
                    keys.append(key)
                for key in keys:
                    var row_ids = btree_index.data[key].copy()
                    var py_list = Python.list()
                    for row_id in row_ids:
                        py_list.append(row_id)
                    data_dict[key] = py_list
            elif index_type == "hash" and index_name in self.hash_indexes:
                var hash_index = self.hash_indexes[index_name].copy()
                # Convert Mojo Dict[String, List[Int]] to Python dict
                var keys = List[String]()
                for key in hash_index.data.keys():
                    keys.append(key)
                for key in keys:
                    var row_ids = hash_index.data[key].copy()
                    var py_list = Python.list()
                    for row_id in row_ids:
                        py_list.append(row_id)
                    data_dict[key] = py_list
            elif index_type == "bitmap" and index_name in self.bitmap_indexes:
                # For bitmap indexes, store the Python object directly
                var bitmap_index = self.bitmap_indexes[index_name].copy()
                data_dict["bitmaps"] = bitmap_index.bitmaps
                data_dict["max_row_id"] = bitmap_index.max_row_id
            else:
                return False

            var pickled_data = pickle_module.dumps(data_dict)
            return self.storage.write_blob("indexes/" + index_name + ".pkl", String(pickled_data))
        except:
            return False

    fn _load_index(mut self, index_name: String, index_type: String) -> Bool:
        """Load index from storage using pickle."""
        try:
            var data = self.storage.read_blob("indexes/" + index_name + ".pkl")
            if data == "":
                return False

            var pickle_module = Python.import_module("pickle")
            var data_dict = pickle_module.loads(data)

            if index_type == "btree":
                var btree_index = BTreeIndex()
                # Parse the pickled data back into Dict[String, List[Int]]
                var keys = Python.list(data_dict.keys())
                for key in keys:
                    var key_str = String(key)
                    var py_list = data_dict[key_str]
                    var row_ids = List[Int]()
                    for item in py_list:
                        row_ids.append(Int(item))
                    btree_index.data[key_str] = row_ids.copy()
                self.btree_indexes[index_name] = btree_index.copy()
            elif index_type == "hash":
                var hash_index = HashIndex()
                var keys = Python.list(data_dict.keys())
                for key in keys:
                    var key_str = String(key)
                    var py_list = data_dict[key_str]
                    var row_ids = List[Int]()
                    for item in py_list:
                        row_ids.append(Int(item))
                    hash_index.data[key_str] = row_ids.copy()
                self.hash_indexes[index_name] = hash_index.copy()
            elif index_type == "bitmap":
                var bitmap_index = BitmapIndex()
                bitmap_index.bitmaps = data_dict["bitmaps"]
                bitmap_index.max_row_id = Int(data_dict["max_row_id"])
                self.bitmap_indexes[index_name] = bitmap_index.copy()

            return True
        except:
            return False


    fn _delete_index_file(self, index_name: String) -> Bool:
        """Delete index file from storage."""
        # Try to delete both pickle and JSON files for backward compatibility
        var pickle_deleted = self.storage.delete_blob("indexes/" + index_name + ".pkl")
        var json_deleted = self.storage.delete_blob("indexes/" + index_name + ".json")
        return pickle_deleted or json_deleted