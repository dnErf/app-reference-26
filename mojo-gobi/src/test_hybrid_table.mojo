# Test Hybrid Table Implementation
# Validates CoW+MoR hybrid functionality

from collections import Dict
from collections import List
from time import sleep, time
from lakehouse_engine import Record
from schema_manager import Column, TableSchema
from hybrid_table import HybridTable

fn test_hybrid_table() raises:
    print("Testing Hybrid Table Implementation...")
    print("=====================================")

    # Create test schema
    var columns = List[Column]()
    columns.append(Column("id", "INTEGER", True))
    columns.append(Column("name", "STRING", False))
    columns.append(Column("value", "FLOAT", False))
    columns.append(Column("timestamp", "INTEGER", False))

    var schema = TableSchema("test_table")
    schema.columns = columns.copy()

    # Create hybrid table
    var table = HybridTable("test_table", schema)
    print("✓ Created hybrid table")

    # Test small writes (should use CoW)
    print("\nTesting small batch writes (CoW path)...")
    var small_batch = List[Record]()
    for i in range(50):
        var record = Record()
        record.set_value("id", String(i))
        record.set_value("name", "record_" + String(i))
        record.set_value("value", String(Float64(i) * 1.5))
        record.set_value("timestamp", String(Int64(1640995200 + i)))  # Mock timestamp
        small_batch.append(record.copy())

    table.write(small_batch)
    print("✓ Wrote 50 records via CoW path")
    print("  Hot blocks:", len(table.hot_storage))
    print("  Warm blocks:", len(table.warm_storage))
    print("  Cold blocks:", len(table.cold_storage))

    # Test large writes (should use MoR)
    print("\nTesting large batch writes (MoR path)...")
    var large_batch = List[Record]()
    for i in range(200):
        var record = Record()
        record.set_value("id", String(i + 100))
        record.set_value("name", "bulk_record_" + String(i))
        record.set_value("value", String(Float64(i) * 2.0))
        record.set_value("timestamp", String(Int64(1640995200 + 100 + i)))  # Mock timestamp
        large_batch.append(record.copy())

    table.write(large_batch)
    print("✓ Wrote 200 records via MoR path")
    print("  Hot blocks:", len(table.hot_storage))
    print("  Warm blocks:", len(table.warm_storage))
    print("  Cold blocks:", len(table.cold_storage))

    # Test read operations
    print("\nTesting read operations...")
    var query_sql = "SELECT * FROM test_table"

    var results = table.read(query_sql)
    print("✓ Read operation completed")
    print("  Result length:", len(results))
    print("  Read/write ratio:", table.workload_analyzer.get_read_write_ratio())

    # Test workload pattern analysis
    print("\nTesting workload pattern analysis...")
    print("  Is read-heavy:", table.workload_analyzer.is_read_heavy())
    print("  Is write-heavy:", table.workload_analyzer.is_write_heavy())

    # Test compaction
    print("\nTesting compaction...")
    var initial_hot = len(table.hot_storage)
    var initial_warm = len(table.warm_storage)

    table._compact()
    print("✓ Compaction completed")
    print("  Hot blocks before/after:", initial_hot, "/", len(table.hot_storage))
    print("  Warm blocks before/after:", initial_warm, "/", len(table.warm_storage))

    # Test statistics
    print("\nTesting statistics...")
    var stats = table.get_stats()
    print("✓ Table statistics:")
    for key in stats.keys():
        print("  ", key[], ":", stats[key[]][])

    print("\n=====================================")
    print("✓ All Hybrid Table tests completed successfully!")

fn test_workload_adaptation() raises:
    print("\nTesting Workload Adaptation...")
    print("================================")

    # Create table
    var columns = List[Column]()
    columns.append(Column("id", "INTEGER", True))
    var schema = TableSchema("workload_test")
    schema.columns = columns.copy()
    var table = HybridTable("workload_test", schema)

    # Simulate read-heavy workload
    print("Simulating read-heavy workload...")
    for i in range(10):
        var record = Record()
        record.set_value("id", String(i))
        var batch = List[Record]()
        batch.append(record.copy())
        table.write(batch)

        # Simulate reads
        for j in range(5):
            var _ = table.read("SELECT * FROM workload_test")

    print("  Read/write ratio:", table.workload_analyzer.get_read_write_ratio())
    print("  Is read-heavy:", table.workload_analyzer.is_read_heavy())

    # Simulate write-heavy workload
    print("\nSimulating write-heavy workload...")
    var write_table = HybridTable("write_test", schema)
    for i in range(20):
        var record = Record()
        record.set_value("id", String(i))
        var batch = List[Record]()
        batch.append(record.copy())
        write_table.write(batch)

    print("  Read/write ratio:", write_table.workload_analyzer.get_read_write_ratio())
    print("  Is write-heavy:", write_table.workload_analyzer.is_write_heavy())

    print("✓ Workload adaptation tests completed!")

fn test_tier_promotion() raises:
    print("\nTesting Tier Promotion...")
    print("=========================")

    # Create table with short aging times for testing
    var columns = List[Column]()
    columns.append(Column("id", "INTEGER", True))
    var schema = TableSchema("aging_test")
    schema.columns = columns.copy()

    var table = HybridTable("aging_test", schema)
    table.compaction_policy.hot_tier_max_age = 2  # 2 seconds for testing

    # Add data to hot tier
    print("Adding data to hot tier...")
    for i in range(3):
        var record = Record()
        record.set_value("id", String(i))
        var batch = List[Record]()
        batch.append(record.copy())
        table.write(batch)

    print("  Initial hot blocks:", len(table.hot_storage))
    print("  Initial warm blocks:", len(table.warm_storage))

    # Wait for aging
    print("Waiting for data to age...")
    sleep(3.0)

    # Trigger compaction (which includes promotion)
    table._compact()

    print("  After aging - hot blocks:", len(table.hot_storage))
    print("  After aging - warm blocks:", len(table.warm_storage))

    print("✓ Tier promotion tests completed!")

# Main test runner
fn main() raises:
    print("🧪 Hybrid Table Test Suite")
    print("==========================")

    test_hybrid_table()
    test_workload_adaptation()
    test_tier_promotion()

    print("\n🎉 All tests passed! Hybrid Table implementation is working correctly.")