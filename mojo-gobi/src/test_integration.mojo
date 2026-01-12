"""
Full PL-GRIZZLY Integration Testing
====================================

Comprehensive end-to-end testing of the complete PL-GRIZZLY system:
- Language parsing and evaluation (ASTEvaluator)
- Data persistence and retrieval (ORCStorage)
- Schema management and indexing
- Complete workflows from PL-GRIZZLY queries to data operations
"""

from blob_storage import BlobStorage
from schema_manager import SchemaManager, DatabaseSchema, TableSchema
from pl_grizzly_interpreter import PLGrizzlyInterpreter
from pl_grizzly_values import PLValue

fn test_pl_grizzly_data_workflow() raises:
    """Test complete PL-GRIZZLY workflow: CREATE TABLE → INSERT → SELECT → UPDATE → DELETE."""
    print("DEBUG: Starting test_pl_grizzly_data_workflow")

    # Setup
    print("DEBUG: Creating BlobStorage")
    var storage = BlobStorage("integration_test_db")
    print("DEBUG: Creating SchemaManager")
    var schema_manager = SchemaManager(storage)
    print("DEBUG: Creating PLGrizzlyInterpreter")
    var interpreter = PLGrizzlyInterpreter(schema_manager)

    # Create environment copy to avoid aliasing
    print("DEBUG: Getting global environment")
    var env = interpreter.global_env

    # Step 1: Create table schema
    print("Step 1: Creating table schema...")
    var create_result = interpreter.evaluate("CREATE TABLE employees (id INT, name STRING, department STRING, salary FLOAT)", env)
    print("CREATE TABLE result:", create_result.__str__())

    # Step 2: Insert data using PL-GRIZZLY INSERT
    print("Step 2: Inserting data...")
    var insert_result1 = interpreter.evaluate("INSERT INTO employees VALUES (1, \"Alice\", \"Engineering\", 75000.0)", env)
    print("INSERT 1 result:", insert_result1.__str__())

    var insert2_result = interpreter.evaluate("INSERT INTO employees VALUES (2, \"Bob\", \"Sales\", 65000.0)", env)
    print("INSERT 2 result:", insert2_result.__str__())

    var insert3_result = interpreter.evaluate("INSERT INTO employees VALUES (3, \"Charlie\", \"Engineering\", 80000.0)", env)
    print("INSERT 3 result:", insert3_result.__str__())

    # Step 3: Query data using PL-GRIZZLY SELECT
    print("Step 3: Querying data...")
    var select_result = interpreter.evaluate("SELECT * FROM employees", env)
    print("SELECT result:", select_result.__str__())

    # Step 4: Query with WHERE condition
    print("Step 4: Querying with conditions...")
    var select_where_result = interpreter.evaluate("SELECT name, department FROM employees WHERE salary > 70000", env)
    print("SELECT WHERE result:", select_where_result.__str__())

    # Step 5: Update data
    print("Step 5: Updating data...")
    var update_result = interpreter.evaluate("""
UPDATE employees SET salary = 85000.0 WHERE name = "Alice"
""", env)
    print("UPDATE result:", update_result.__str__())

    # Step 6: Verify update
    print("Step 6: Verifying update...")
    var verify_update = interpreter.evaluate("SELECT name, salary FROM employees WHERE name = \"Alice\"", env)
    print("Verify UPDATE result:", verify_update.__str__())

    # Step 7: Delete data
    print("Step 7: Deleting data...")
    var delete_result = interpreter.evaluate("""
DELETE FROM employees WHERE department = "Sales"
""", env)
    print("DELETE result:", delete_result.__str__())

    # Step 8: Final verification
    print("Step 8: Final data verification...")
    var final_select = interpreter.evaluate("SELECT * FROM employees", env)
    print("Final SELECT result:", final_select.__str__())

    print("🎉 Complete PL-GRIZZLY data workflow test finished!")

fn test_pl_grizzly_indexing_workflow() raises:
    """Test PL-GRIZZLY indexing workflow with CREATE INDEX and indexed queries."""
    print("Testing PL-GRIZZLY indexing workflow...")

    # Setup
    var storage = BlobStorage("index_test_db")
    var schema_manager = SchemaManager(storage)
    var interpreter = PLGrizzlyInterpreter(schema_manager)
    var env = interpreter.global_env

    # Create table and insert test data
    interpreter.evaluate("""
(CREATE TABLE products (id INT, name STRING, category STRING, price FLOAT))
""", env)

    # Insert test data
    for i in range(5):
        var id_val = i + 1
        var name = "Product" + String(i + 1)
        var category = "Category" + String((i % 3) + 1)
        var price = Float64(10.0 + i * 5.0)

        var insert_cmd = "INSERT INTO products VALUES (" + String(id_val) + ", \"" + name + "\", \"" + category + "\", " + String(price) + ")"
        print("Inserting row", i + 1, "...")
        interpreter.evaluate(insert_cmd, env)
        print("Row", i + 1, "inserted")

    print("Test data inserted")

    # Create index
    print("Creating index on category column...")
    var create_index_result = interpreter.evaluate("""
(CREATE INDEX idx_category ON products (category))
""", env)
    print("CREATE INDEX result:", create_index_result.__str__())
    print("Index creation completed")

    # Query with index
    print("Starting SELECT query...")
    var indexed_query = interpreter.evaluate("""
(SELECT name, price FROM products)
""", env)
    print("SELECT query completed")
    print("Indexed query result:", indexed_query.__str__())

    # Test index search directly
    print("Testing direct index search...")
    var index_search = interpreter.orc_storage.search_with_index("products", "idx_category", "Category1")
    print("Direct index search result count:", len(index_search))

    print("🎉 PL-GRIZZLY indexing workflow test finished!")

fn test_pl_grizzly_mixed_operations() raises:
    """Test mixed PL-GRIZZLY operations combining language features and data operations."""
    print("Testing mixed PL-GRIZZLY operations...")

    # Setup
    var storage = BlobStorage("mixed_test_db")
    var schema_manager = SchemaManager(storage)
    var interpreter = PLGrizzlyInterpreter(schema_manager)
    var env = interpreter.global_env

    # Create table
    interpreter.evaluate("""
(CREATE TABLE calculations (id INT, value FLOAT, computed FLOAT))
""", env)

    # Use PL-GRIZZLY variables and computations
    interpreter.evaluate("(LET base_value 100)", env)
    interpreter.evaluate("(LET multiplier 1.5)", env)

    # Insert computed values
    var computed_value = interpreter.evaluate("(* base_value multiplier)", env)
    print("Computed value:", computed_value.__str__())

    # Insert with computed data
    var insert_computed = interpreter.evaluate("""
(INSERT INTO calculations VALUES (1, 100, (* 100 1.5)))
""", env)
    print("Insert with computation result:", insert_computed.__str__())

    # Query and verify
    var verify_computed = interpreter.evaluate("""
(SELECT * FROM calculations)
""", env)
    print("Verification of computed data:", verify_computed.__str__())

    # Test conditional logic with data
    var conditional_result = interpreter.evaluate("""
(IF (> (SELECT COUNT(*) FROM calculations) 0) "Has Data" "No Data")
""", env)
    print("Conditional with data query:", conditional_result.__str__())

    print("🎉 Mixed PL-GRIZZLY operations test finished!")

fn test_error_handling_and_edge_cases() raises:
    """Test error handling and edge cases in the integrated system."""
    print("Testing error handling and edge cases...")

    # Setup
    var storage = BlobStorage("error_test_db")
    var schema_manager = SchemaManager(storage)
    var interpreter = PLGrizzlyInterpreter(schema_manager)
    var env = interpreter.global_env

    # Test querying non-existent table
    print("Testing non-existent table query...")
    var nonexistent_table = interpreter.evaluate("""
(SELECT * FROM nonexistent_table)
""", env)
    print("Non-existent table result:", nonexistent_table.__str__())

    # Test invalid syntax
    print("Testing invalid syntax...")
    var invalid_syntax = interpreter.evaluate("""
(INVALID SYNTAX HERE)
""", env)
    print("Invalid syntax result:", invalid_syntax.__str__())

    # Test division by zero in evaluation
    print("Testing division by zero...")
    var division_by_zero = interpreter.evaluate("(/ 10 0)", env)
    print("Division by zero result:", division_by_zero.__str__())

    # Test with empty table
    interpreter.evaluate("""
(CREATE TABLE empty_table (id INT, name STRING))
""", env)

    var empty_query = interpreter.evaluate("""
(SELECT * FROM empty_table)
""", env)
    print("Empty table query result:", empty_query.__str__())

    print("🎉 Error handling and edge cases test finished!")

fn test_list_operations() raises:
    """Test ARRAY operations including indexing."""
    print("🧪 Testing ARRAY Operations")

    # Setup
    var storage = BlobStorage("list_test_db")
    var schema_manager = SchemaManager(storage)
    var interpreter = PLGrizzlyInterpreter(schema_manager)
    var env = interpreter.global_env

    # Test basic array creation
    print("Testing basic array creation...")
    var list_result = interpreter.evaluate("(ARRAY \"apple\" \"banana\" \"cherry\")", env)
    print("ARRAY result:", list_result.__str__())
    
    # Test new array literal syntax
    print("Testing array literal syntax...")
    var literal_result = interpreter.evaluate("[]", env)
    print("Empty array result:", literal_result.__str__())
    
    var literal_result2 = interpreter.evaluate("[\"hello\", \"world\"]", env)
    print("Array literal result:", literal_result2.__str__())

    # Test array indexing
    print("Testing array indexing...")
    var index_result = interpreter.evaluate("(index (ARRAY \"apple\" \"banana\" \"cherry\") 0)", env)
    print("Index 0 result:", index_result.__str__())

    var index_result2 = interpreter.evaluate("(index [\"apple\", \"banana\", \"cherry\"] 1)", env)
    # Test negative indexing
    print("Testing negative indexing...")
    var neg_index = interpreter.evaluate("(index [\"apple\", \"banana\", \"cherry\"] -1)", env)
    print("Index -1 result:", neg_index.__str__())

    # Test out of bounds
    print("Testing out of bounds...")
    var out_of_bounds = interpreter.evaluate("(index [\"apple\", \"banana\", \"cherry\"] 5)", env)
    print("Out of bounds result:", out_of_bounds.__str__())

    print("🎉 ARRAY operations test finished!")
    
    # Test new advanced array syntax
    print("🧪 Testing Advanced Array Syntax")
    
    # Test struct literals
    print("Testing struct literals...")
    var struct_result = interpreter.evaluate("{name: \"John\", age: 30}", env)
    print("Struct result:", struct_result.__str__())
    
    # Test simple typed array declaration
    print("Testing simple typed array...")
    var simple_typed = interpreter.interpret("Array<Person>")
    print("Simple typed array:", simple_typed.__str__())
    
    # Test typed arrays
    print("Testing typed arrays...")
    var typed_result1 = interpreter.interpret("Array<Person> as [{name: \"Alice\", age: 25}]")
    print("Typed array (as syntax):", typed_result1.__str__())
    
    var typed_result2 = interpreter.interpret("Array<Person>::[{name: \"Bob\", age: 30}]")
    print("Typed array (constructor syntax):", typed_result2.__str__())
    
    print("🎉 Advanced array syntax test finished!")

fn test_array_aggregation() raises:
    """Test Array::(Distinct column) aggregation syntax."""
    print("🧪 Testing Array Aggregation")
    
    # Setup
    var storage = BlobStorage("array_agg_test_db")
    var schema_manager = SchemaManager(storage)
    var interpreter = PLGrizzlyInterpreter(schema_manager)
    var env = interpreter.global_env
    
    # Create test table
    interpreter.evaluate("CREATE TABLE locations (id INT, city STRING, country STRING)", env)
    
    # Insert test data
    interpreter.evaluate("INSERT INTO locations VALUES (1, \"New York\", \"USA\")", env)
    interpreter.evaluate("INSERT INTO locations VALUES (2, \"London\", \"UK\")", env)
    interpreter.evaluate("INSERT INTO locations VALUES (3, \"New York\", \"USA\")", env)
    interpreter.evaluate("INSERT INTO locations VALUES (4, \"Paris\", \"France\")", env)
    interpreter.evaluate("INSERT INTO locations VALUES (5, \"London\", \"UK\")", env)
    
    # Test basic SELECT first
    var basic_result = interpreter.interpret("SELECT city FROM locations")
    print("Basic SELECT result:", basic_result.__str__())
    
    # Test Array::(Distinct city)
    var distinct_result = interpreter.interpret("SELECT Array::(distinct city) FROM locations")
    print("Array::(Distinct city) result:", distinct_result.__str__())
    
    # Test Array::(Distinct country)
    var distinct_country_result = interpreter.interpret("SELECT Array::(distinct country) FROM locations")
    print("Array::(Distinct country) result:", distinct_country_result.__str__())
    
    print("🎉 Array aggregation test finished!")

fn main() raises:
    """Run comprehensive PL-GRIZZLY integration tests."""
    print("=== Full PL-GRIZZLY Integration Testing ===")

    print("🧪 Test 1: Complete Data Workflow")
    test_pl_grizzly_data_workflow()

    print("🧪 Test 2: Error Handling and Edge Cases")
    test_error_handling_and_edge_cases()

    print("🧪 Test 3: ARRAY Operations")
    test_list_operations()

    print("🧪 Test 4: Array Aggregation")
    test_array_aggregation()

    print("🎉 All PL-GRIZZLY integration tests completed!")