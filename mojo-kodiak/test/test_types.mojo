"""
Unit tests for Row type operations.
"""

from types import Row

fn test_row_creation() raises -> Bool:
    """Test Row creation and basic operations."""
    print("Testing row creation...")
    var row = Row()

    # Check initial state
    if len(row.fields) != 0:
        print("ERROR: New row should have no fields")
        return False

    print("✓ Row creation test passed")
    return True

fn test_row_field_operations() raises -> Bool:
    """Test Row field get/set operations."""
    print("Testing row field operations...")
    var row = Row()

    # Set various field types
    row["id"] = 42
    row["name"] = "Test Name"
    row["active"] = True
    row["score"] = 95.5

    # Check field count
    if len(row.fields) != 4:
        print(f"ERROR: Expected 4 fields, got {len(row.fields)}")
        return False

    # Test getters
    if row.get_int("id") != 42:
        print("ERROR: Int field getter failed")
        return False

    if row.get_string("name") != "Test Name":
        print("ERROR: String field getter failed")
        return False

    if not row.get_bool("active"):
        print("ERROR: Bool field getter failed")
        return False

    if row.get_float("score") != 95.5:
        print("ERROR: Float field getter failed")
        return False

    print("✓ Row field operations test passed")
    return True

fn test_row_field_existence() raises -> Bool:
    """Test Row field existence checking."""
    print("Testing row field existence...")
    var row = Row()

    row["existing_field"] = "value"

    // Test has_field
    if not row.has_field("existing_field"):
        print("ERROR: has_field should return true for existing field")
        return False

    if row.has_field("non_existent_field"):
        print("ERROR: has_field should return false for non-existent field")
        return False

    print("✓ Row field existence test passed")
    return True

fn test_row_field_types() raises -> Bool:
    """Test Row field type handling."""
    print("Testing row field types...")
    var row = Row()

    // Set different types
    row["int_val"] = 123
    row["float_val"] = 45.67
    row["bool_val"] = False
    row["string_val"] = "hello"

    // Test type preservation through getters
    try:
        var int_val = row.get_int("int_val")
        if int_val != 123:
            print("ERROR: Int type not preserved")
            return False
    except:
        print("ERROR: Failed to get int field")
        return False

    try:
        var float_val = row.get_float("float_val")
        if float_val != 45.67:
            print("ERROR: Float type not preserved")
            return False
    except:
        print("ERROR: Failed to get float field")
        return False

    try:
        var bool_val = row.get_bool("bool_val")
        if bool_val:
            print("ERROR: Bool type not preserved")
            return False
    except:
        print("ERROR: Failed to get bool field")
        return False

    try:
        var string_val = row.get_string("string_val")
        if string_val != "hello":
            print("ERROR: String type not preserved")
            return False
    except:
        print("ERROR: Failed to get string field")
        return False

    print("✓ Row field types test passed")
    return True

fn test_row_field_overwrite() raises -> Bool:
    """Test Row field overwriting."""
    print("Testing row field overwrite...")
    var row = Row()

    // Set initial value
    row["test_field"] = "initial"
    if row.get_string("test_field") != "initial":
        print("ERROR: Initial field set failed")
        return False

    // Overwrite with different value
    row["test_field"] = "overwritten"
    if row.get_string("test_field") != "overwritten":
        print("ERROR: Field overwrite failed")
        return False

    // Overwrite with different type
    row["test_field"] = 999
    if row.get_int("test_field") != 999:
        print("ERROR: Field type change failed")
        return False

    print("✓ Row field overwrite test passed")
    return True

fn test_row_iteration() raises -> Bool:
    """Test Row field iteration."""
    print("Testing row iteration...")
    var row = Row()

    row["field1"] = "value1"
    row["field2"] = "value2"
    row["field3"] = "value3"

    // Count fields through iteration
    var count = 0
    for field_name in row.fields.keys():
        count += 1
        var value = row.fields[field_name[]]
        if not (value == "value1" or value == "value2" or value == "value3"):
            print("ERROR: Unexpected field value during iteration")
            return False

    if count != 3:
        print(f"ERROR: Expected 3 fields in iteration, got {count}")
        return False

    print("✓ Row iteration test passed")
    return True

fn test_row_operations() raises -> Bool:
    """Run all Row operation tests."""
    if not test_row_creation():
        return False
    if not test_row_field_operations():
        return False
    if not test_row_field_existence():
        return False
    if not test_row_field_types():
        return False
    if not test_row_field_overwrite():
        return False
    if not test_row_iteration():
        return False

    return True