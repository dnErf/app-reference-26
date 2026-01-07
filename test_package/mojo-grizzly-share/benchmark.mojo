# Benchmarks for Mojo Arrow Database
# Performance testing against large datasets

import time

from arrow import Schema, Table, Int64Array
from query import execute_query
from formats import write_parquet, read_parquet, write_avro, read_avro
from index import BTreeIndex

fn generate_large_table(num_rows: Int) -> Table:
    var schema = Schema()
    schema.add_field("id", "int64")
    schema.add_field("value", "int64")
    var table = Table(schema, num_rows)
    for i in range(num_rows):
        table.columns[0][i] = i
        table.columns[1][i] = i * 2
    return table^

fn benchmark_query(table: Table, sql: String, runs: Int) raises -> Float64:
    var total_time = 0.0
    for _ in range(runs):
        let start = time.now()
        let result = execute_query(table, sql)
        let end = time.now()
        total_time += end - start
    return total_time / runs

fn simple_sum(arr: Int64Array) -> Int64:
    var sum = 0
    for i in 0 ..< arr.length:
        sum += arr[i]
    return sum

fn benchmark_sum(table: Table, runs: Int) raises -> Float64:
    var total_time = 0.0
    for _ in range(runs):
        let start = time.now()
        let s = simple_sum(table.columns[1])
        let end = time.now()
        total_time += end - start
    return total_time / runs

fn benchmark_format_io(table: Table, runs: Int) raises -> (Float64, Float64):
    var write_times = 0.0
    var read_times = 0.0
    for _ in range(runs):
        let start = time.now()
        write_parquet(table, "temp.parquet")
        let end = time.now()
        write_times += end - start
        
        let start_read = time.now()
        let result = read_parquet("temp.parquet")
        let end_read = time.now()
        read_times += end_read - start_read
    return write_times / runs, read_times / runs

fn benchmark_indexing(table: Table, runs: Int) raises -> Float64:
    var total_time = 0.0
    for _ in range(runs):
        let start = time.now()
        var index = BTreeIndex()
        for i in range(table.num_rows()):
            index.insert(table.columns[0][i], i)
        let lookup_time = time.now()
        let _ = index.lookup(50000)
        let end = time.now()
        total_time += end - start
    return total_time / runs

fn main() raises:
    print("Running comprehensive benchmarks...")
    
    let num_rows = 100000  # Larger dataset for better benchmarking
    let table = generate_large_table(num_rows)
    print("Generated table with", num_rows, "rows")

    # Basic query benchmarks
    let sql = "SELECT * FROM table WHERE value > 50000"
    let avg_time = benchmark_query(table, sql, 10)
    print("Average query time for", sql, ":", avg_time, "seconds")

    let sum_time = benchmark_sum(table, 10)
    print("Average SIMD sum time:", sum_time, "seconds, sum:", simple_sum(table.columns[1]))

    # Format I/O benchmarks
    let write_time, read_time = benchmark_format_io(table, 5)
    print("Average Parquet write time:", write_time, "seconds")
    print("Average Parquet read time:", read_time, "seconds")

    # Indexing benchmarks
    let index_time = benchmark_indexing(table, 5)
    print("Average B-tree indexing time:", index_time, "seconds")

    # Join benchmark
    let sql_join = "SELECT * FROM table t1 JOIN table t2 ON t1.id = t2.id"
    let join_time = benchmark_query(table, sql_join, 5)
    print("Average join time:", join_time, "seconds")

    # Aggregate benchmark
    let sql_agg = "SELECT SUM(value) FROM table"
    let agg_time = benchmark_query(table, sql_agg, 10)
    print("Average aggregate time:", agg_time, "seconds")

    # TPC-H like Q1: Pricing Summary Report
    let sql_q1 = "SELECT SUM(value), AVG(value) FROM table WHERE value > 10000"
    let q1_time = benchmark_query(table, sql_q1, 10)
    print("TPC-H Q1-like time:", q1_time, "seconds")

    # Q6: Forecast Revenue Change
    let sql_q6 = "SELECT SUM(value * 1.1) FROM table WHERE value BETWEEN 20000 AND 80000"
    let q6_time = benchmark_query(table, sql_q6, 10)
    print("TPC-H Q6-like time:", q6_time, "seconds")

    # Throughput benchmark: queries per second
    let start_throughput = time.now()
    var queries_run = 0
    let duration = 5.0  # 5 seconds
    while time.now() - start_throughput < duration:
        let _ = execute_query(table, sql)
        queries_run += 1
    let throughput = Float64(queries_run) / duration
    print("Throughput:", throughput, "queries/second")

    # Memory usage simulation (rough estimate)
    let mem_usage = Float64(num_rows * 16)  # Assume 16 bytes per row
    print("Estimated memory usage:", mem_usage / 1024 / 1024, "MB")

    # Compare to simple scan
    let start = time.now()
    var count = 0
    for i in 0 ..< table.columns[1].length:
        if table.columns[1][i] > 50000:
            count += 1
    let end = time.now()
    print("Simple scan time:", end - start, "seconds, results:", count)

    # Generate report
    print("\n=== Benchmark Report ===")
    print("Dataset size:", num_rows, "rows")
    print("Query performance:", avg_time, "s avg")
    print("Sum performance:", sum_time, "s avg")
    print("Join performance:", join_time, "s avg")
    print("Aggregate performance:", agg_time, "s avg")
    print("TPC-H Q1-like:", q1_time, "s avg")
    print("TPC-H Q6-like:", q6_time, "s avg")
    print("Throughput:", throughput, "qps")
    print("Estimated memory:", mem_usage / 1024 / 1024, "MB")
    print("Parquet write:", write_time, "s avg")
    print("Parquet read:", read_time, "s avg")
    print("B-tree indexing:", index_time, "s avg")

    print("Comprehensive benchmarks complete.")