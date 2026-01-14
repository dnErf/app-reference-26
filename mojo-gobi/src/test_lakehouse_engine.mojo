# Test Lakehouse Engine
# Simple test to verify the LakehouseEngine compiles and works

from lakehouse_engine import LakehouseEngine, Record, COW, MOR, HYBRID
from schema_manager import Column

fn main() raises:
    print("Testing Lakehouse Engine...")

    # Create engine
    var engine = LakehouseEngine("./test_data")

    # Initialize
    if engine.initialize():
        print("✓ Engine initialized successfully")
    else:
        print("✗ Engine initialization failed")
        return

    # Create a test table
    var columns = List[Column]()
    columns.append(Column("id", "int"))
    columns.append(Column("name", "string"))
    columns.append(Column("value", "float"))

    if engine.create_table("test_table", columns, HYBRID):
        print("✓ Test table created")
    else:
        print("✗ Failed to create test table")
        return

    # Create some test records
    var records = List[Record]()
    var record1 = Record()
    record1.set_value("id", "1")
    record1.set_value("name", "Alice")
    record1.set_value("value", "100.5")
    records.append(record1.copy())

    var record2 = Record()
    record2.set_value("id", "2")
    record2.set_value("name", "Bob")
    record2.set_value("value", "200.75")
    records.append(record2.copy())

    # Insert records
    var commit_id = engine.insert("test_table", records)
    if commit_id != "":
        print("✓ Records inserted, commit:", commit_id)
    else:
        print("✗ Failed to insert records")
        return

    # Test query
    var query_result = engine.query("test_table", "SELECT * FROM test_table")
    print("Query result:", query_result)

    # Test time travel query
    var time_travel_result = engine.query_as_of("test_table", 1234567890, "SELECT * FROM test_table AS OF 1234567890")
    print("Time travel result:", time_travel_result)

    # Get changes
    var changes = engine.get_changes_since("test_table", 0)
    print("Changes:", changes)

    # Get stats
    var stats = engine.get_stats()
    print("Stats:", stats)

    # Compact timeline
    engine.compact_timeline()

    print("✓ All tests completed successfully!")