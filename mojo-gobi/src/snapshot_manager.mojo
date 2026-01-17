"""
PL-GRIZZLY Snapshot Manager Module

Manages manual snapshots for rollback functionality.
"""

from collections import Dict, List
from transaction_context import DataStore

# Snapshot manager for manual commits and rollbacks
struct SnapshotManager(Movable):
    var snapshots: Dict[String, Dict[String, String]]  # snapshot_id -> data_copy
    var snapshot_timestamps: Dict[String, Int64]       # snapshot_id -> creation_ts
    
    fn __init__(out self):
        self.snapshots = Dict[String, Dict[String, String]]()
        self.snapshot_timestamps = Dict[String, Int64]()
    
    fn create_snapshot(mut self, snapshot_id: String, data_store: DataStore, timestamp: Int64):
        """Create a snapshot of current data store state."""
        var data_copy = Dict[String, String]()
        for key in data_store.data.keys():
            data_copy[key] = data_store.data[key]
        
        self.snapshots[snapshot_id] = data_copy
        self.snapshot_timestamps[snapshot_id] = timestamp
        
        print("Created snapshot:", snapshot_id, "at timestamp:", timestamp)
    
    fn rollback_to(mut self, snapshot_id: String, data_store: DataStore) -> Bool:
        """Rollback data store to a snapshot."""
        if snapshot_id not in self.snapshots:
            print("Snapshot not found:", snapshot_id)
            return False
        
        # Restore data
        data_store.data = self.snapshots[snapshot_id].copy()
        
        # Clear last_modified timestamps (they become invalid after rollback)
        data_store.last_modified.clear()
        
        print("Rolled back to snapshot:", snapshot_id)
        return True
    
    fn list_snapshots(self) -> List[String]:
        """List all available snapshots."""
        var snapshot_list = List[String]()
        for key in self.snapshots.keys():
            snapshot_list.append(key)
        return snapshot_list
    
    fn get_snapshot_timestamp(self, snapshot_id: String) -> Int64:
        """Get creation timestamp of a snapshot."""
        return self.snapshot_timestamps.get(snapshot_id, 0)