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
    var root: PythonObject  # B-tree implementation using Python's btree or similar
    var order: Int

    fn __init__(out self, order: Int = 100) raises:
        self.order = order
        # Initialize Python B-tree (using sortedcontainers or similar)
        try:
            var sortedcontainers = Python.import_module("sortedcontainers")
            self.root = sortedcontainers.SortedDict()
        except:
            # Fallback to simple dict if sortedcontainers not available
            self.root = Python.dict()

    fn __copyinit__(out self, other: Self):
        self.root = other.root
        self.order = other.order

    fn __moveinit__(out self, deinit existing: Self):
        self.root = existing.root^
        self.order = existing.order

    fn insert(mut self, key: String, row_id: Int):
        """Insert a key-row_id pair into the B-tree."""
        try:
            var key_list = self.root.get(key, Python.list())
            if Python.type(key_list) != Python.type(Python.list()):
                key_list = Python.list()
            key_list.append(row_id)
            self.root[key] = key_list
        except:
            pass

    fn search(self, key: String) -> List[Int]:
        """Search for row IDs by key."""
        var results = List[Int]()
        try:
            var key_list = self.root.get(key, Python.list())
            if Python.type(key_list) == Python.type(Python.list()):
                for item in key_list:
                    results.append(Int(item))
        except:
            pass
        return results

    fn range_search(self, start_key: String, end_key: String) -> List[Int]:
        """Search for row IDs in a key range."""
        var results = List[Int]()
        try:
            # Get all keys in range
            var keys = Python.list(self.root.keys())
            for key in keys:
                var key_str = String(key)
                if key_str >= start_key and key_str <= end_key:
                    var key_list = self.root[key]
                    if Python.isinstance(key_list, Python.list):
                        for item in key_list:
                            results.append(Int(item))
        except:
            pass
        return results

struct HashIndex(Movable, Copyable):
    var buckets: PythonObject  # Hash table using Python dict
    var bucket_count: Int

    fn __init__(out self, bucket_count: Int = 1000) raises:
        self.bucket_count = bucket_count
        self.buckets = Python.dict()

    fn __copyinit__(out self, other: Self):
        self.buckets = other.buckets
        self.bucket_count = other.bucket_count

    fn __moveinit__(out self, deinit existing: Self):
        self.buckets = existing.buckets^
        self.bucket_count = existing.bucket_count

    fn _hash(self, key: String) -> Int:
        """Simple hash function for string keys."""
        var hash_val = 0
        for c in key:
            hash_val = (hash_val * 31 + ord(c)) % self.bucket_count
        return hash_val

    fn insert(mut self, key: String, row_id: Int):
        """Insert a key-row_id pair into the hash index."""
        try:
            var bucket_key = String(self._hash(key))
            var bucket = self.buckets.get(bucket_key, Python.list())
            try:
                _ = bucket[0]  # Try to access first element to check if it's a list
            except:
                bucket = Python.list()
            bucket.append([key, row_id])
            self.buckets[bucket_key] = bucket
        except:
            pass

    fn search(self, key: String) -> List[Int]:
        """Search for row IDs by key."""
        var results = List[Int]()
        try:
            var bucket_key = String(self._hash(key))
            var bucket = self.buckets.get(bucket_key, Python.list())
            try:
                _ = bucket[0]  # Check if it's a list
                for item in bucket:
                    try:
                        if len(item) == 2:
                            var item_key = String(item[0])
                            if item_key == key:
                                results.append(Int(item[1]))
                    except:
                        pass
            except:
                pass
        except:
            pass
        return results

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
        return results

struct IndexStorage(Copyable, Movable):
    var storage: BlobStorage
    var indexes: Dict[String, PythonObject]  # Map index_name -> index_object

    fn __init__(out self, storage: BlobStorage):
        self.storage = storage.copy()
        self.indexes = Dict[String, PythonObject]()

    fn __copyinit__(out self, other: Self):
        self.storage = other.storage.copy()
        self.indexes = other.indexes.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.storage = existing.storage^
        self.indexes = existing.indexes^

    fn create_index(mut self, index: Index, table_data: List[List[String]], column_positions: Dict[String, Int]) -> Bool:
        """Create and build an index on table data."""
        try:
            var index_name = index.name
            var index_type = index.type

            if index_type == "btree":
                var btree_index = BTreeIndex()
                self._build_btree_index(btree_index, index, table_data, column_positions)
                self.indexes[index_name] = btree_index.root
            elif index_type == "hash":
                var hash_index = HashIndex()
                self._build_hash_index(hash_index, index, table_data, column_positions)
                self.indexes[index_name] = hash_index.buckets
            elif index_type == "bitmap":
                var bitmap_index = BitmapIndex()
                self._build_bitmap_index(bitmap_index, index, table_data, column_positions)
                self.indexes[index_name] = bitmap_index.bitmaps
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

    fn drop_index(mut self, index_name: String) -> Bool:
        """Drop an index."""
        _ = self.indexes.pop(index_name, Python.none())
        return self._delete_index_file(index_name)

    fn search_index(self, index_name: String, index_type: String, key: String, start_key: String = "", end_key: String = "") -> List[Int]:
        """Search an index for matching row IDs."""
        var results = List[Int]()

        # Check if index exists
        var index_exists = False
        for k in self.indexes.keys():
            if k[] == index_name:
                index_exists = True
                break

        if not index_exists:
            # Try to load from storage
            if not self._load_index(index_name, index_type):
                return results

        try:
            if index_type == "btree":
                var btree_root = self.indexes[index_name]
                var btree_index = BTreeIndex()
                btree_index.root = btree_root

                if start_key != "" and end_key != "":
                    results = btree_index.range_search(start_key, end_key)
                else:
                    results = btree_index.search(key)

            elif index_type == "hash":
                var hash_buckets = self.indexes[index_name]
                var hash_index = HashIndex()
                hash_index.buckets = hash_buckets
                results = hash_index.search(key)

            elif index_type == "bitmap":
                var bitmaps = self.indexes[index_name]
                var bitmap_index = BitmapIndex()
                bitmap_index.bitmaps = bitmaps
                results = bitmap_index.search(key)

        except:
            pass

        return results

    fn _save_index(self, index_name: String, index_type: String) -> Bool:
        """Save index to storage."""
        try:
            var index_data = self.indexes[index_name]
            # Serialize Python object to JSON string
            var json_module = Python.import_module("json")
            var json_str = json_module.dumps(index_data)
            return self.storage.write_blob("indexes/" + index_name + ".json", String(json_str))
        except:
            return False

    fn _load_index(mut self, index_name: String, index_type: String) -> Bool:
        """Load index from storage."""
        try:
            var json_str = self.storage.read_blob("indexes/" + index_name + ".json")
            if json_str == "":
                return False

            var json_module = Python.import_module("json")
            var index_data = json_module.loads(json_str)
            self.indexes[index_name] = index_data
            return True
        except:
            return False

    fn _delete_index_file(self, index_name: String) -> Bool:
        """Delete index file from storage."""
        return self.storage.delete_blob("indexes/" + index_name + ".json")