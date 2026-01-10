"""
Performance benchmarks for database operations.
"""

from database import Database
from types import Row
from time import now

fn benchmark_inserts() raises -> Bool:
    """Benchmark insert performance."""
    print("Benchmarking insert performance...")

    var db = Database()
    db.create_table("bench_insert")

    var start_time = now()
    var num_inserts = 1000

    # Perform inserts
    for i in range(num_inserts):
        var row = Row()
        row["id"] = i
        row["data1"] = f"string_data_{i}"
        row["data2"] = i * 1.5
        row["data3"] = (i % 2) == 0
        db.insert_into_table("bench_insert", row)

    var end_time = now()
    var duration = end_time - start_time
    var inserts_per_second = num_inserts / duration

    print(f"  Inserted {num_inserts} rows in {duration:.3f}s")
    print(f"  Rate: {inserts_per_second:.1f} inserts/second")

    # Verify all inserts worked
    var rows = db.select_all_from_table("bench_insert")
    if len(rows) != num_inserts:
        print(f"ERROR: Expected {num_inserts} rows, got {len(rows)}")
        return False

    print("✓ Insert benchmark passed")
    return True

fn benchmark_queries() raises -> Bool:
    """Benchmark query performance."""
    print("Benchmarking query performance...")

    var db = Database()
    db.create_table("bench_query")

    # Setup test data
    var num_rows = 5000
    for i in range(num_rows):
        var row = Row()
        row["id"] = i
        row["category"] = f"cat_{i % 10}"
        row["value"] = i * 2.5
        db.insert_into_table("bench_query", row)

    var start_time = now()
    var num_queries = 100

    # Perform select all queries
    for i in range(num_queries):
        var rows = db.select_all_from_table("bench_query")
        if len(rows) != num_rows:
            print(f"ERROR: Query {i} returned wrong number of rows")
            return False

    var end_time = now()
    var duration = end_time - start_time
    var queries_per_second = num_queries / duration

    print(f"  Performed {num_queries} SELECT * queries in {duration:.3f}s")
    print(f"  Rate: {queries_per_second:.1f} queries/second")

    print("✓ Query benchmark passed")
    return True

fn benchmark_indexing() raises -> Bool:
    """Benchmark indexing performance."""
    print("Benchmarking indexing performance...")

    var db = Database()
    db.create_table("bench_index")

    var start_time = now()
    var num_inserts = 2000

    # Insert rows with IDs (should trigger indexing)
    for i in range(num_inserts):
        var row = Row()
        row["id"] = i
        row["data"] = f"indexed_data_{i}"
        row["timestamp"] = i * 1000000
        db.insert_into_table("bench_index", row)

    var end_time = now()
    var duration = end_time - start_time
    var inserts_per_second = num_inserts / duration

    print(f"  Inserted {num_inserts} indexed rows in {duration:.3f}s")
    print(f"  Rate: {inserts_per_second:.1f} indexed inserts/second")

    # Verify indexing worked
    var rows = db.select_all_from_table("bench_index")
    if len(rows) != num_inserts:
        print(f"ERROR: Expected {num_inserts} rows, got {len(rows)}")
        return False

    print("✓ Indexing benchmark passed")
    return True

fn benchmark_joins() raises -> Bool:
    """Benchmark join performance."""
    print("Benchmarking join performance...")

    var db = Database()

    # Create tables
    db.create_table("bench_users")
    db.create_table("bench_posts")

    # Insert users
    var num_users = 100
    for i in range(1, num_users + 1):
        var user = Row()
        user["id"] = i
        user["name"] = f"User{i}"
        db.insert_into_table("bench_users", user)

    # Insert posts (multiple posts per user)
    var num_posts = 1000
    for i in range(1, num_posts + 1):
        var post = Row()
        post["id"] = i
        post["user_id"] = ((i - 1) % num_users) + 1
        post["title"] = f"Post {i}"
        post["content"] = f"Content for post {i}"
        db.insert_into_table("bench_posts", post)

    var start_time = now()
    var num_joins = 50

    # Perform joins
    for i in range(num_joins):
        var joined = db.join("bench_users", "bench_posts", "id", "user_id")
        if len(joined) != num_posts:
            print(f"ERROR: Join {i} returned wrong number of rows: {len(joined)}")
            return False

    var end_time = now()
    var duration = end_time - start_time
    var joins_per_second = num_joins / duration

    print(f"  Performed {num_joins} joins in {duration:.3f}s")
    print(f"  Rate: {joins_per_second:.1f} joins/second")
    print(f"  Each join returned {num_posts} rows")

    print("✓ Join benchmark passed")
    return True