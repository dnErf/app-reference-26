"""
Test concurrency control with timestamp-based write isolation.
"""

from timestamp_manager import TimestampManager
from transaction_context import TransactionContext, DataStore
from conflict_resolver import ConflictResolver
from snapshot_manager import SnapshotManager

fn test_timestamp_manager() raises:
    """Test timestamp generation."""
    print("Testing TimestampManager...")
    
    var ts_manager = TimestampManager()
    var ts1 = ts_manager.start_transaction()
    var ts2 = ts_manager.start_transaction()
    
    print("TS1:", ts1, "TS2:", ts2)
    assert ts1 < ts2, "Timestamps should be monotonically increasing"

fn test_transaction_context() raises:
    """Test transaction context with write isolation."""
    print("Testing TransactionContext...")
    
    var ts_manager = TimestampManager()
    var data_store = DataStore()
    
    # Simulate data
    data_store.write("key1", "value1", 1000)
    
    # Transaction 1: Read and write
    var tx1 = TransactionContext()
    tx1.begin(ts_manager)
    var val = tx1.read("key1", data_store)
    assert val == "value1", "Should read existing value"
    tx1.write("key2", "value2")
    
    # Transaction 2: Try to modify same key
    var tx2 = TransactionContext()
    tx2.begin(ts_manager)
    tx2.read("key1", data_store)
    tx2.write("key1", "value1_modified")
    
    # Both should commit (no conflict yet)
    var success1 = tx1.commit(data_store, ts_manager)
    var success2 = tx2.commit(data_store, ts_manager)
    
    print("TX1 commit:", success1, "TX2 commit:", success2)
    assert success1, "TX1 should commit"
    assert not success2, "TX2 should abort due to dirty write"

fn test_snapshot_manager() raises:
    """Test snapshot creation and rollback."""
    print("Testing SnapshotManager...")
    
    var data_store = DataStore()
    var snapshot_mgr = SnapshotManager()
    var ts_manager = TimestampManager()
    
    # Add some data
    data_store.write("key1", "value1", ts_manager.commit_timestamp())
    data_store.write("key2", "value2", ts_manager.commit_timestamp())
    
    # Create snapshot
    var snapshot_id = "test_snapshot"
    var ts = ts_manager.current_timestamp()
    snapshot_mgr.create_snapshot(snapshot_id, data_store, ts)
    
    # Modify data
    data_store.write("key3", "value3", ts_manager.commit_timestamp())
    
    # Verify snapshot has old state
    var snapshot_data = snapshot_mgr.snapshots[snapshot_id]
    assert len(snapshot_data) == 2, "Snapshot should have 2 keys"
    assert snapshot_data["key1"] == "value1", "Snapshot should preserve old values"
    
    # Rollback
    var rollback_success = snapshot_mgr.rollback_to(snapshot_id, data_store)
    assert rollback_success, "Rollback should succeed"
    assert data_store.read("key1") == "value1", "Should restore old value"
    assert data_store.read("key3") == "", "Should remove new data"

fn main() raises:
    """Run all concurrency control tests."""
    print("Running Concurrency Control Tests")
    print("=" * 40)
    
    test_timestamp_manager()
    print("✓ TimestampManager test passed")
    
    test_transaction_context()
    print("✓ TransactionContext test passed")
    
    test_snapshot_manager()
    print("✓ SnapshotManager test passed")
    
    print("\n✓ All concurrency control tests passed!")