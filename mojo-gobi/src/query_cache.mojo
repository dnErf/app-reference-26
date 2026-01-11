"""
Query Result Caching System
===========================

Implements intelligent caching of query results with automatic invalidation
strategies for improved performance.
"""

from python import Python, PythonObject
from collections import Dict, List

struct CacheEntry(Copyable, Movable):
    var query_hash: String
    var result: List[List[String]]
    var timestamp: Float64
    var hits: Int
    var table_names: List[String]  # Tables this query depends on
    var cost: Float64  # Original query cost

    fn __init__(out self, query_hash: String, result: List[List[String]], table_names: List[String], cost: Float64):
        self.query_hash = query_hash
        self.result = result.copy()
        try:
            var time_module = Python.import_module("time")
            self.timestamp = Float64(time_module.time())
        except:
            self.timestamp = 0.0
        self.hits = 0
        self.table_names = table_names.copy()
        self.cost = cost

    fn __copyinit__(out self, other: Self):
        self.query_hash = other.query_hash
        self.result = other.result.copy()
        self.timestamp = other.timestamp
        self.hits = other.hits
        self.table_names = other.table_names.copy()
        self.cost = other.cost

    fn __moveinit__(out self, deinit existing: Self):
        self.query_hash = existing.query_hash^
        self.result = existing.result^
        self.timestamp = existing.timestamp
        self.hits = existing.hits
        self.table_names = existing.table_names^
        self.cost = existing.cost

    fn is_expired(self, max_age: Float64) -> Bool:
        """Check if cache entry has expired."""
        try:
            var time_module = Python.import_module("time")
            var current_time = Float64(time_module.time())
            return (current_time - self.timestamp) > max_age
        except:
            return False
@fieldwise_init
struct DeserializedEntry(Copyable, Movable):
    var query_hash: String
    var timestamp: Float64
    var hits: Int
    var cost: Float64
    var table_names: List[String]
    var result: List[List[String]]
    
    fn __init__(out self):
        self.query_hash = ""
        self.timestamp = 0.0
        self.hits = 0
        self.cost = 0.0
        self.table_names = List[String]()
        self.result = List[List[String]]()
    
    fn is_expired(self, max_age: Float64) raises -> Bool:
        """Check if entry is expired."""
        var time_module = Python.import_module("time")
        var current_time = Float64(time_module.time())
        return current_time - self.timestamp > max_age
    fn hit(mut self):
        """Record a cache hit."""
        self.hits += 1

struct QueryCache:
    var cache: Dict[String, String]  # Store serialized CacheEntry
    var max_size: Int
    var max_age: Float64  # Maximum age in seconds
    var hit_count: Int
    var miss_count: Int

    fn __init__(out self, max_size: Int = 1000, max_age: Float64 = 3600.0):  # 1 hour default
        self.cache = Dict[String, String]()
        self.max_size = max_size
        self.max_age = max_age
        self.hit_count = 0
        self.miss_count = 0

    fn _serialize_entry_components(self, query_hash: String, timestamp: Float64, hits: Int, cost: Float64, table_names: List[String], result: List[List[String]]) -> String:
        """Serialize CacheEntry components to string."""
        var data = query_hash + "|" + String(timestamp) + "|" + String(hits) + "|" + String(cost) + "|"
        # Serialize table_names
        for i in range(len(table_names)):
            if i > 0:
                data += ","
            data += table_names[i]
        data += "|"
        # Serialize result data
        for i in range(len(result)):
            if i > 0:
                data += ";"
            for j in range(len(result[i])):
                if j > 0:
                    data += ","
                data += result[i][j]
        return data

    fn _deserialize_entry(self, data: String) raises -> DeserializedEntry:
        """Deserialize a string to CacheEntry components."""
        var parts = data.split("|")
        var query_hash = String(parts[0])
        var timestamp = Float64(String(parts[1]))
        var hits = Int(String(parts[2]))
        var cost = Float64(String(parts[3]))
        var table_names_str = String(parts[4])
        var result_str = String(parts[5])
        
        # Deserialize table_names
        var table_names = List[String]()
        if len(table_names_str) > 0:
            for table_slice in table_names_str.split(","):
                table_names.append(String(table_slice))
        
        # Deserialize result
        var result = List[List[String]]()
        if len(result_str) > 0:
            for row_str_slice in result_str.split(";"):
                var row_str = String(row_str_slice)
                var row = List[String]()
                for cell_slice in row_str.split(","):
                    row.append(String(cell_slice))
                result.append(row.copy())
        
        var entry = DeserializedEntry()
        entry.query_hash = query_hash
        entry.timestamp = timestamp
        entry.hits = hits
        entry.cost = cost
        entry.table_names = table_names.copy()
        entry.result = result.copy()
        return entry.copy()

    fn __copyinit__(out self, other: Self):
        self.cache = other.cache.copy()
        self.max_size = other.max_size
        self.max_age = other.max_age
        self.hit_count = other.hit_count
        self.miss_count = other.miss_count

    fn __moveinit__(out self, deinit existing: Self):
        self.cache = existing.cache^
        self.max_size = existing.max_size
        self.max_age = existing.max_age
        self.hit_count = existing.hit_count
        self.miss_count = existing.miss_count

    fn get_cache_key(self, query: String, params: Dict[String, String] = Dict[String, String]()) raises -> String:
        """Generate a cache key from query and parameters."""
        var key = query
        if len(params) > 0:
            key += "|"
            for param_key in params.keys():
                try:
                    var param_value = params[param_key]
                    key += param_key + "=" + param_value + ";"
                except:
                    pass
        return self._hash_string(key)

    fn _hash_string(self, input: String) -> String:
        """Generate a simple hash of input string."""
        var hash_val: UInt64 = 0
        for cp in input.codepoints():
            hash_val = (hash_val * 31 + UInt64(Int(cp))) % 1000000007
        return String(hash_val)

    fn get(mut self, key: String) raises -> List[List[String]]:
        """Get cached result if available and valid."""
        try:
            var serialized = self.cache[key]
            var entry = self._deserialize_entry(serialized)
            
            # Check if expired
            if entry.is_expired(self.max_age):
                _ = self.cache.pop(key)
                self.miss_count += 1
                return List[List[String]]()

            # Update hits and reserialize
            var new_hits = entry.hits + 1
            var updated_serialized = self._serialize_entry_components(entry.query_hash, entry.timestamp, new_hits, entry.cost, entry.table_names, entry.result)
            self.cache[key] = updated_serialized
            self.hit_count += 1
            return entry.result.copy()
        except:
            self.miss_count += 1
            return List[List[String]]()

    fn put(mut self, key: String, result: List[List[String]], table_names: List[String], cost: Float64) raises:
        """Store result in cache."""
        # Evict entries if cache is full (LRU-like by removing oldest)
        if len(self.cache) >= self.max_size:
            self._evict_oldest()

        var time_module = Python.import_module("time")
        var timestamp = Float64(time_module.time())
        var serialized = self._serialize_entry_components(key, timestamp, 0, cost, table_names, result)
        self.cache[key] = serialized

    fn _evict_oldest(mut self) raises:
        """Evict the oldest cache entry."""
        try:
            var time_module = Python.import_module("time")
            var oldest_key = ""
            var oldest_time = Float64(time_module.time())

            # Collect all keys first
            var all_keys = List[String]()
            for key in self.cache.keys():
                all_keys.append(key)

            for key in all_keys:
                try:
                    var serialized = self.cache[key]
                    var entry = self._deserialize_entry(serialized)
                    if entry.timestamp < oldest_time:
                        oldest_time = entry.timestamp
                        oldest_key = key
                except:
                    pass

            if oldest_key != "":
                _ = self.cache.pop(oldest_key)
        except:
            pass

    fn invalidate_table(mut self, table_name: String) raises:
        """Invalidate all cache entries that depend on a specific table."""
        var keys_to_remove = List[String]()

        # Collect all keys first
        var all_keys = List[String]()
        for key in self.cache.keys():
            all_keys.append(key)

        for key in all_keys:
            try:
                var serialized = self.cache[key]
                var entry = self._deserialize_entry(serialized)
                for table in entry.table_names:
                    if table == table_name:
                        keys_to_remove.append(key)
                        break
            except:
                pass

        for key in keys_to_remove:
            try:
                _ = self.cache.pop(key)
            except:
                pass

    fn invalidate_all(mut self):
        """Invalidate entire cache."""
        self.cache = Dict[String, String]()

    fn clear(mut self):
        """Clear the entire cache and reset statistics."""
        self.cache = Dict[String, String]()
        self.hit_count = 0
        self.miss_count = 0

    fn get_stats(self) -> Dict[String, Int]:
        """Get cache statistics."""
        var stats = Dict[String, Int]()
        stats["size"] = len(self.cache)
        stats["hits"] = self.hit_count
        stats["misses"] = self.miss_count
        stats["hit_rate"] = self.hit_count * 100 // max(1, self.hit_count + self.miss_count)
        return stats^

    fn cleanup_expired(mut self) raises:
        """Remove all expired entries."""
        var keys_to_remove = List[String]()

        # Collect all keys first
        var all_keys = List[String]()
        for key in self.cache.keys():
            all_keys.append(key)

        for key in all_keys:
            try:
                var serialized = self.cache[key]
                var entry = self._deserialize_entry(serialized)
                if entry.is_expired(self.max_age):
                    keys_to_remove.append(key)
            except:
                pass

        for key in keys_to_remove:
            try:
                _ = self.cache.pop(key)
            except:
                pass