# Test Table Manager
# Test the unified table management interface

from table_manager import TableManager
from lakehouse_engine import Record, HYBRID
from schema_manager import Column

fn main() raises:
    print("Testing Table Manager...")

    # Create table manager
    var manager = TableManager("./test_data")

    # Initialize engine
    if manager.engine.initialize():
        print("✓ Table manager initialized successfully")
    else:
        print("✗ Table manager initialization failed")
        return

    # Create a test table
    var columns = List[Column]()
    columns.append(Column("id", "int"))
    columns.append(Column("name", "string"))
    columns.append(Column("value", "float"))

    if manager.create_table("test_table", columns, HYBRID):
        print("✓ Created table: test_table")
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

    # Insert records using table manager
    var commit_id = manager.insert("test_table", records)
    if commit_id != "":
        print("✓ Records inserted via table manager, commit:", commit_id)
    else:
        print("✗ Failed to insert records via table manager")
        return

    # Test time travel query
    var time_travel_result = manager.query_since("test_table", 1640995200, "SELECT * FROM test_table")
    print("Time travel result:", time_travel_result)

    # Get changes
    var changes = manager.get_changes_since("test_table", 0)
    print("Changes since watermark:", changes)

    # Get table stats
    var stats = manager.get_stats()
    print("Table manager stats:", stats)

    # List tables
    var tables = manager.list_tables()
    print("Available tables:", len(tables))

    # Compact timeline
    manager.compact_timeline()

    print("✓ All Table Manager tests completed successfully!")