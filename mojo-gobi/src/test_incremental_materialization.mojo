# Test Incremental Materialization
# Demonstrates change-based materialization with incremental updates

from lakehouse_engine import LakehouseEngine, Record, Column
from incremental_processor import IncrementalProcessor, Change, ChangeSet
from merkle_timeline import MerkleTimeline

fn test_incremental_materialization() raises:
    """Test the incremental materialization pipeline."""
    print("🧪 Testing Incremental Materialization Pipeline")
    print("=" * 50)

    # Initialize lakehouse engine
    var engine = LakehouseEngine("./test_materialization_db")

    # Create a test table
    print("📋 Creating test table...")
    var columns = List[Column]()
    columns.append(Column("id", "INTEGER", True))
    columns.append(Column("name", "STRING", False))
    columns.append(Column("value", "FLOAT", False))

    var success = engine.create_table("test_table", columns)
    if not success:
        print("❌ Failed to create table")
        return

    # Insert some initial data
    print("📝 Inserting initial data...")
    var records = List[Record]()
    var record1 = Record()
    record1.set_value("id", "1")
    record1.set_value("name", "Alice")
    record1.set_value("value", "100.0")
    records.append(record1.copy())

    var record2 = Record()
    record2.set_value("id", "2")
    record2.set_value("name", "Bob")
    record2.set_value("value", "200.0")
    records.append(record2.copy())

    var key_columns = List[String]()
    key_columns.append("id")
    engine.upsert("test_table", records, key_columns)

    # Create a materialized view
    print("🎯 Creating materialized view...")
    var view_query = "SELECT name, value FROM test_table WHERE value > 150"
    engine.create_materialized_view("high_value_view", view_query, "incremental")

    # Simulate some changes
    print("🔄 Simulating data changes...")
    var changes = List[Record]()
    var change_record = Record()
    change_record.set_value("id", "3")
    change_record.set_value("name", "Charlie")
    change_record.set_value("value", "300.0")
    changes.append(change_record.copy())

    engine.upsert("test_table", changes, key_columns)

    # Process incremental changes
    print("⚡ Processing incremental changes...")
    engine.process_table_changes("test_table")

    # Check materialization stats
    print("📊 Materialization Statistics:")
    var stats = engine.get_materialization_stats()
    print(stats)

    # Check view stats
    print("📊 View Statistics:")
    var view_stats = engine.get_materialized_view_stats("high_value_view")
    print(view_stats)

    print("✅ Incremental materialization test completed!")

fn test_incremental_query_optimization() raises:
    """Test incremental query optimization features."""
    print("🧪 Testing Incremental Query Optimization")
    print("=" * 50)

    # Initialize components
    var engine = LakehouseEngine("./test_query_opt_db")
    var optimizer = engine.optimizer

    # Test incremental query optimization
    var query = "SELECT id, name FROM test_table WHERE value > 100"
    var watermark = 1700000000000

    print("🔍 Optimizing query for incremental processing...")
    var plan = optimizer.optimize_incremental_query(query, watermark, engine.schema_manager)

    print("📋 Query Plan:")
    print("  Operation:", plan.operation)
    print("  Table:", plan.table_name)
    print("  Cost:", String(plan.cost))
    print("  Cache Key:", plan.cache_key.value() if plan.cache_key else "None")

    # Test change-based query planning
    var changes = List[String]()
    changes.append("INSERT id=4, name=Diana, value=400")
    changes.append("UPDATE id=2, value=250")

    print("🔄 Creating change processing plan...")
    var change_plan = optimizer.get_incremental_query_plan(query, changes, watermark)

    print("📋 Change Processing Plan:")
    print("  Operation:", change_plan.operation)
    print("  Cost:", String(change_plan.cost))
    print("  Watermark:", String(change_plan.timeline_timestamp.value()))

    print("✅ Incremental query optimization test completed!")

fn main() raises:
    """Main test function."""
    print("🚀 Starting Incremental Materialization Tests")
    print("=" * 60)

    test_incremental_materialization()
    print()
    test_incremental_query_optimization()

    print("🎉 All incremental materialization tests completed!")