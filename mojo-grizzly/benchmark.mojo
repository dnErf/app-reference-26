# Benchmarks for Mojo Arrow Database
# Performance testing against large datasets

import time

from arrow import Schema, Table, Int64Array
from query import execute_query

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

    print("Comprehensive benchmarks complete.")