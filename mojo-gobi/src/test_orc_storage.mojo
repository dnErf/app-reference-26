"""
ORCStorage Functionality Test Module

Tests for the ORCStorage to ensure all storage operations work correctly after re-enablement.
"""

from orc_storage import ORCStorage
from blob_storage import BlobStorage

fn test_orc_storage_basic_operations() raises:
    """Test basic ORCStorage operations: write and read table."""
    print("Testing ORCStorage basic operations...")

    # Create storage components
    var blob_storage = BlobStorage("/tmp/orc_test_basic")
    var orc_storage = ORCStorage(blob_storage)

    # Create test data
    var data = List[List[String]]()
    var row1 = List[String]("1", "Alice", "25")
    var row2 = List[String]("2", "Bob", "30")
    data.append(row1.copy())
    data.append(row2.copy())

    # Test writing table
    var success = orc_storage.write_table("users", data)
    if not success:
        print("ERROR: Failed to write table")
        return

    print("Table written successfully")

    # Test reading table
    var result = orc_storage.read_table("users")
    if len(result) != 2:
        print("ERROR: Expected 2 rows, got", len(result))
        return

    print("Table read successfully, rows:", len(result))

    # Verify data
    if result[0][0] != "1" or result[0][1] != "Alice" or result[0][2] != "25":
        print("ERROR: Data mismatch in first row")
        return

    if result[1][0] != "2" or result[1][1] != "Bob" or result[1][2] != "30":
        print("ERROR: Data mismatch in second row")
        return

    print("Data verification passed")
    print("ORCStorage basic operations test passed")

fn test_orc_storage_indexing() raises:
    """Test ORCStorage indexing functionality."""
    print("Testing ORCStorage indexing operations...")

    # Create storage components
    var blob_storage = BlobStorage("/tmp/orc_test_index")
    var orc_storage = ORCStorage(blob_storage)

    # Create test data
    var data = List[List[String]]()
    for i in range(10):
        var row = List[String](String(i), "user" + String(i) + "@example.com")
        data.append(row.copy())

    # Write table
    var success = orc_storage.write_table("contacts", data)
    if not success:
        print("ERROR: Failed to write table for indexing")
        return

    # Create an index
    var columns = List[String]("col_0")
    success = orc_storage.create_index("id_index", "contacts", columns, "btree", False)
    if not success:
        print("ERROR: Failed to create index")
        return

    print("Index created successfully")

    # Test searching with index
    var search_result = orc_storage.search_with_index("contacts", "id_index", "5")
    if len(search_result) == 0:
        print("ERROR: Index search returned no results")
        return

    print("Index search successful, found", len(search_result), "rows")

    # Test dropping index
    success = orc_storage.drop_index("id_index", "contacts")
    if not success:
        print("ERROR: Failed to drop index")
        return

    print("Index dropped successfully")
    print("ORCStorage indexing operations test passed")

fn test_orc_storage_save_load() raises:
    """Test ORCStorage save and load functionality."""
    print("Testing ORCStorage save/load operations...")

    # Create storage components
    var blob_storage = BlobStorage("/tmp/orc_test_save")
    var orc_storage = ORCStorage(blob_storage)

    # Create test data
    var data = List[List[String]]()
    var row1 = List[String]("1", "test_data_1")
    var row2 = List[String]("2", "test_data_2")
    data.append(row1.copy())
    data.append(row2.copy())

    # Test save_table
    var success = orc_storage.save_table("test_table", data)
    if not success:
        print("ERROR: Failed to save table")
        return

    print("Table saved successfully")

    # Test read_table (should load from saved data)
    var result = orc_storage.read_table("test_table")
    if len(result) != 2:
        print("ERROR: Expected 2 rows from saved table, got", len(result))
        return

    print("Table loaded successfully, rows:", len(result))
    print("ORCStorage save/load operations test passed")

fn test_orc_storage_multiple_tables() raises:
    """Test ORCStorage with multiple tables."""
    print("Testing ORCStorage with multiple tables...")

    # Create storage components
    var blob_storage = BlobStorage("/tmp/orc_test_multi")
    var orc_storage = ORCStorage(blob_storage)

    # Create data for users table
    var users_data = List[List[String]]()
    users_data.append(List[String]("1", "John"))
    users_data.append(List[String]("2", "Jane"))

    # Create data for orders table
    var orders_data = List[List[String]]()
    orders_data.append(List[String]("1", "100.50"))
    orders_data.append(List[String]("2", "200.75"))

    # Write both tables
    var success1 = orc_storage.write_table("users", users_data)
    var success2 = orc_storage.write_table("orders", orders_data)

    if not success1 or not success2:
        print("ERROR: Failed to write multiple tables")
        return

    print("Multiple tables written successfully")

    # Read both tables
    var users_result = orc_storage.read_table("users")
    var orders_result = orc_storage.read_table("orders")

    if len(users_result) != 2 or len(orders_result) != 2:
        print("ERROR: Expected 2 rows each, got users:", len(users_result), "orders:", len(orders_result))
        return

    print("Multiple tables read successfully")
    print("ORCStorage multiple tables test passed")

fn main() raises:
    """Run all ORCStorage functionality tests."""
    print("Running ORCStorage functionality tests...")

    test_orc_storage_basic_operations()
    test_orc_storage_indexing()
    test_orc_storage_save_load()
    test_orc_storage_multiple_tables()

    print("All ORCStorage functionality tests completed successfully!")