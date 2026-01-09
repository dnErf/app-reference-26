from database import Database
from types import Row
from python import Python, PythonObject

fn benchmark_inserts(mut db: Database, num: Int) raises -> PythonObject:
    var time_mod = Python.import_module("time")
    var start = time_mod.time()
    for i in range(num):
        var row = Row()
        row["id"] = String(i)
        row["name"] = "User" + String(i)
        row["age"] = String(i % 100)
        db.insert_into_table("bench", row)
    var end = time_mod.time()
    return end - start

fn benchmark_selects(mut db: Database, num: Int) raises -> PythonObject:
    var time_mod = Python.import_module("time")
    var start = time_mod.time()
    for i in range(num):
        var rows = db.select_all_from_table("bench")
    var end = time_mod.time()
    return end - start

fn main() raises:
    print("Starting benchmark...")
    var db = Database()
    db.create_table("bench")
    
    var sizes = List[Int]()
    sizes.append(100)
    sizes.append(1000)
    # sizes.append(10000)  # Uncomment for larger
    
    for size in sizes:
        print("Benchmarking with", size, "rows")
        var insert_time = benchmark_inserts(db, size)
        print("Insert time:", insert_time, "seconds")
        var select_time = benchmark_selects(db, size // 10)  # Fewer selects
        print("Select time:", select_time, "seconds")
    
    print("Benchmark complete.")