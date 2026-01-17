"""
PL-GRIZZLY Transaction Context Module

Manages transaction state with timestamp-based write isolation.
"""

from collections import Dict, List
from timestamp_manager import TimestampManager

# Transaction context for write isolation
struct TransactionContext(Movable):
    var start_ts: Int64
    var read_set: Dict[String, Int64]  # record_id -> last_modified_ts at read time
    var write_set: Dict[String, String]  # record_id -> new_data
    var active: Bool
    
    fn __init__(out self):
        self.start_ts = 0
        self.read_set = Dict[String, Int64]()
        self.write_set = Dict[String, String]()
        self.active = False
    
    fn begin(mut self, ts_manager: TimestampManager):
        """Start a new transaction with a timestamp."""
        self.start_ts = ts_manager.start_transaction()
        self.read_set.clear()
        self.write_set.clear()
        self.active = True
    
    fn read(mut self, record_id: String, data_store: DataStore) -> String:
        """Read a record and track it in read set."""
        var last_modified_ts = data_store.get_last_modified_ts(record_id)
        self.read_set[record_id] = last_modified_ts
        return data_store.read(record_id)
    
    fn write(mut self, record_id: String, data: String):
        """Write a record to the write set."""
        self.write_set[record_id] = data
    
    fn validate(mut self, data_store: DataStore) -> Bool:
        """Validate transaction: check for dirty writes."""
        if not self.active:
            return False
        
        # Check if any record we read has been modified since
        for record_id in self.read_set.keys():
            var current_ts = data_store.get_last_modified_ts(record_id)
            var read_ts = self.read_set[record_id]
            if current_ts != read_ts:
                return False  # Dirty write detected
        return True
    
    fn commit(mut self, data_store: DataStore, ts_manager: TimestampManager) -> Bool:
        """Commit transaction if validation passes."""
        if not self.validate(data_store):
            self.active = False
            return False  # Conflict, abort
        
        var commit_ts = ts_manager.commit_timestamp()
        
        # Write all changes with commit timestamp
        for record_id in self.write_set.keys():
            var data = self.write_set[record_id]
            data_store.write(record_id, data, commit_ts)
        
        self.active = False
        return True
    
    fn abort(mut self):
        """Abort transaction."""
        self.active = False
        self.read_set.clear()
        self.write_set.clear()

# Data store with timestamp tracking for write isolation
struct DataStore(Movable):
    var data: Dict[String, String]
    var last_modified: Dict[String, Int64]

    fn __init__(out self):
        self.data = Dict[String, String]()
        self.last_modified = Dict[String, Int64]()

    fn read(self, record_id: String) -> String:
        return self.data.get(record_id, "")

    fn write(mut self, record_id: String, new_data: String, commit_ts: Int64):
        self.data[record_id] = new_data
        self.last_modified[record_id] = commit_ts

    fn get_last_modified_ts(self, record_id: String) -> Int64:
        return self.last_modified.get(record_id, 0)