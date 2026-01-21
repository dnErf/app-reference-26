import pyarrow as pa
import pyarrow.parquet as pq
import pyarrow.compute as pc
from bplus_tree import BPlusTree
from merkle_tree import MerkleTree
from bplus_tree_mojo_wrapper import MojoBPlusTree


def example_mojo_bplus_tree():
    """Example: B+ Tree with Mojo-style optimization"""
    print("=" * 50)
    print("Mojo B+ Tree Example")
    print("=" * 50)
    
    # Create Mojo B+ tree
    tree = MojoBPlusTree(max_keys=3)
    
    # Insert data
    data = [
        (50, "apple"),
        (30, "cat"),
        (70, "dog"),
        (10, "elephant"),
        (40, "fox"),
        (60, "giraffe"),
        (80, "horse"),
        (5, "igloo"),
        (15, "jazz"),
        (35, "kite"),
    ]
    
    print(f"\nInserting {len(data)} key-value pairs...")
    for key, value in data:
        tree.insert(key, value)
        print(f"  Inserted: {key} -> {value}")
    
    # Search operations
    print(f"\n--- Search Operations ---")
    test_keys = [50, 30, 100, 5]
    for key in test_keys:
        result = tree.search(key)
        if result:
            print(f"Found: {key} -> {result}")
        else:
            print(f"Not found: {key}")
    
    # Range query
    print(f"\n--- Range Query ---")
    ranges = [(10, 40), (30, 70), (1, 100)]
    for start, end in ranges:
        results = tree.range_query(start, end)
        print(f"Range [{start}, {end}]:")
        for key, value in results:
            print(f"  {key} -> {value}")
    
    # Bulk insert
    print(f"\n--- Bulk Insert ---")
    bulk_data = [(100, "json"), (110, "kotlin"), (120, "lua")]
    tree.bulk_insert(bulk_data)
    print(f"Bulk inserted {len(bulk_data)} items")
    
    # Delete operation
    print(f"\n--- Delete Operation ---")
    deleted = tree.delete(50)
    print(f"Deleted key 50: {deleted}")
    
    # Get all keys
    print(f"\n--- All Keys ---")
    all_keys = tree.get_all_keys()
    print(f"All keys: {all_keys}")
    
    # Performance stats
    print(f"\n--- Performance Statistics ---")
    stats = tree.get_stats()
    print(f"Backend: {stats.get('backend', 'Python')}")
    print(f"Max keys: {stats.get('max_keys', 3)}")
    print(f"Operations: {stats['operations']}")
    print(f"Hit rate: {stats['hit_rate']:.2%}")
    
    print(f"\n{tree.display()}")
    print()


def example_merkle_tree():
    """Example: Merkle Tree Implementation"""
    print("=" * 50)
    print("Merkle Tree Example")
    print("=" * 50)
    
    # Create Merkle tree with data blocks
    data_blocks = [
        "block_0: transaction A",
        "block_1: transaction B",
        "block_2: transaction C",
        "block_3: transaction D",
        "block_4: transaction E",
    ]
    
    print(f"\nBuilding Merkle tree with {len(data_blocks)} data blocks...")
    tree = MerkleTree(data_blocks, hash_func="sha256")
    
    print(tree.display())
    
    # Get root hash
    print(f"\n--- Root Hash ---")
    print(f"Root Hash: {tree.get_root_hash()}")
    
    # Get proofs and verify leaves
    print(f"\n--- Merkle Proofs and Verification ---")
    for i in range(len(data_blocks)):
        proof = tree.get_proof(i)
        original_data = data_blocks[i]
        is_valid = tree.verify_leaf(i, original_data, proof)
        
        print(f"Leaf [{i}] '{original_data}':")
        print(f"  Proof length: {len(proof)}")
        print(f"  Valid: {is_valid}")
    
    # Verify with corrupted data
    print(f"\n--- Tampering Detection ---")
    corrupted_data = "corrupted data"
    proof = tree.get_proof(0)
    is_valid = tree.verify_leaf(0, corrupted_data, proof)
    print(f"Verify leaf [0] with corrupted data: {is_valid}")
    
    # Tree visualization
    print(f"\n--- Tree Structure ---")
    print(tree.visualize_tree())
    
    print()


def example_bplus_tree():
    """Example: B+ Tree Implementation"""
    print("=" * 50)
    print("B+ Tree Example")
    print("=" * 50)
    
    # Create B+ tree with max_keys=3
    tree = BPlusTree(max_keys=3)
    
    # Insert data
    data = [
        (50, "apple"),
        (30, "cat"),
        (70, "dog"),
        (10, "elephant"),
        (40, "fox"),
        (60, "giraffe"),
        (80, "horse"),
        (5, "igloo"),
        (15, "jazz"),
        (35, "kite"),
    ]
    
    print(f"\nInserting {len(data)} key-value pairs...")
    for key, value in data:
        tree.insert(key, value)
        print(f"  Inserted: {key} -> {value}")
    
    print(f"\nTree structure:")
    print(tree.display())
    
    # Search operations
    print(f"\n--- Search Operations ---")
    test_keys = [50, 30, 100, 5]
    for key in test_keys:
        result = tree.search(key)
        if result:
            print(f"Found: {key} -> {result}")
        else:
            print(f"Not found: {key}")
    
    # Range query
    print(f"\n--- Range Queries ---")
    ranges = [(10, 40), (30, 70), (1, 100)]
    for start, end in ranges:
        results = tree.range_query(start, end)
        print(f"Range [{start}, {end}]:")
        for key, value in results:
            print(f"  {key} -> {value}")
    
    # Update value
    print(f"\n--- Update Value ---")
    tree.insert(50, "APPLE (updated)")
    updated_value = tree.search(50)
    print(f"Updated value: 50 -> {updated_value}")
    
    # Get all sorted keys
    print(f"\n--- All Keys (Sorted) ---")
    all_keys = tree.get_all_keys()
    print(f"Keys: {all_keys}")
    
    print()


def example_1_basic_arrays():
    """Example 1: Creating and working with PyArrow arrays"""
    print("=" * 50)
    print("Example 1: Basic Arrays")
    print("=" * 50)
    
    # Create arrays
    names = pa.array(["Alice", "Bob", "Charlie", "Diana", "Eve"])
    ages = pa.array([25, 30, 35, 28, 32], type=pa.int32())
    salaries = pa.array([50000.0, 60000.0, 70000.0, 55000.0, 65000.0])
    
    print(f"Names: {names}")
    print(f"Ages: {ages}")
    print(f"Salaries: {salaries}")
    print()


def example_2_schema_and_table():
    """Example 2: Creating schemas and tables"""
    print("=" * 50)
    print("Example 2: Schema and Table")
    print("=" * 50)
    
    # Define schema
    schema = pa.schema([
        pa.field("name", pa.string()),
        pa.field("age", pa.int32()),
        pa.field("salary", pa.float64()),
    ])
    
    # Create table with data
    data = {
        "name": ["Alice", "Bob", "Charlie", "Diana", "Eve"],
        "age": [25, 30, 35, 28, 32],
        "salary": [50000.0, 60000.0, 70000.0, 55000.0, 65000.0],
    }
    
    table = pa.table(data, schema=schema)
    print(f"Table:\n{table}")
    print(f"Schema: {table.schema}")
    print(f"Num rows: {table.num_rows}, Num columns: {table.num_columns}")
    print()


def example_3_parquet_io():
    """Example 3: Reading and writing Parquet files"""
    print("=" * 50)
    print("Example 3: Parquet I/O")
    print("=" * 50)
    
    # Create sample data
    schema = pa.schema([
        pa.field("name", pa.string()),
        pa.field("age", pa.int32()),
        pa.field("salary", pa.float64()),
    ])
    
    data = {
        "name": ["Alice", "Bob", "Charlie", "Diana", "Eve"],
        "age": [25, 30, 35, 28, 32],
        "salary": [50000.0, 60000.0, 70000.0, 55000.0, 65000.0],
    }
    
    table = pa.table(data, schema=schema)
    
    # Write to Parquet
    filename = "employees.parquet"
    pq.write_table(table, filename)
    print(f"Written {table.num_rows} rows to {filename}")
    
    # Read back from Parquet
    read_table = pq.read_table(filename)
    print(f"Read back {read_table.num_rows} rows from {filename}")
    print(f"Data:\n{read_table}")
    print()


def example_4_compute_functions():
    """Example 4: Using compute functions for data transformation"""
    print("=" * 50)
    print("Example 4: Compute Functions")
    print("=" * 50)
    
    schema = pa.schema([
        pa.field("name", pa.string()),
        pa.field("age", pa.int32()),
        pa.field("salary", pa.float64()),
    ])
    
    data = {
        "name": ["Alice", "Bob", "Charlie", "Diana", "Eve"],
        "age": [25, 30, 35, 28, 32],
        "salary": [50000.0, 60000.0, 70000.0, 55000.0, 65000.0],
    }
    
    table = pa.table(data, schema=schema)
    
    # Compute operations
    ages = table["age"]
    names = table["name"]
    
    # Filter: ages >= 30
    mask = pc.greater_equal(ages, 30)
    filtered_table = table.filter(mask)
    print("Employees with age >= 30:")
    print(filtered_table)
    print()
    
    # Aggregate: mean salary
    mean_salary = pc.mean(table["salary"])
    print(f"Mean salary: {mean_salary.as_py()}")
    
    # Sort by age
    indices = pc.sort_indices(table, sort_keys=[("age", "ascending")])
    sorted_table = pc.take(table, indices)
    print("\nSorted by age:")
    print(sorted_table)
    print()


def example_5_record_batch():
    """Example 5: Working with RecordBatches"""
    print("=" * 50)
    print("Example 5: RecordBatch")
    print("=" * 50)
    
    schema = pa.schema([
        pa.field("id", pa.int32()),
        pa.field("value", pa.float64()),
    ])
    
    # Create record batch (columnar data)
    batch = pa.record_batch([
        pa.array([1, 2, 3, 4, 5]),
        pa.array([10.5, 20.3, 30.1, 40.7, 50.2])
    ], schema=schema)
    
    print(f"RecordBatch:\n{batch}")
    print(f"Num rows: {batch.num_rows}, Num columns: {batch.num_columns}")
    print()


def main():
    print("\n" + "=" * 50)
    print("Mojo-Python Integration Examples")
    print("=" * 50 + "\n")
    
    example_mojo_bplus_tree()
    example_merkle_tree()
    example_bplus_tree()
    example_1_basic_arrays()
    example_2_schema_and_table()
    example_3_parquet_io()
    example_4_compute_functions()
    example_5_record_batch()
    
    print("=" * 50)
    print("All examples completed!")
    print("=" * 50)


if __name__ == "__main__":
    main()
