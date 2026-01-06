# Benchmarks for Mojo Arrow Database
# Performance testing against large datasets

import time
import SIMD

from arrow import DataType, Schema, Table, Int64Array
from query import execute_query

fn generate_large_table(num_rows: Int) -> Table:
    var schema = Schema()
    schema.add_field("id", DataType.int64)
    schema.add_field("value", DataType.int64)
    var table = Table(schema, num_rows)
    for i in range(num_rows):
        table.columns[0][i] = i
        table.columns[1][i] = i * 2
    return table

fn benchmark_query(table: Table, sql: String, runs: Int) -> Float64:
    var total_time = 0.0
    for _ in range(runs):
        let start = time.now()
        let result = execute_query(table, sql)
        let end = time.now()
        total_time += end - start
    return total_time / runs

fn simd_sum(arr: Int64Array) -> Int64:
    var sum = 0
    let vec_size = 4  # SIMD width for int64
    for i in range(0, arr.length, vec_size):
        let end = min(i + vec_size, arr.length)
        var vec = SIMD[DType.int64, 4](0)
        for j in range(i, end):
            vec[j - i] = arr[j]
        sum += vec.reduce_add()
    return sum

fn benchmark_sum(table: Table, runs: Int) -> Float64:
    var total_time = 0.0
    for _ in range(runs):
        let start = time.now()
        let s = simd_sum(table.columns[1])
        let end = time.now()
        total_time += end - start
    return total_time / runs

fn main():
    print("Running benchmarks...")

    let num_rows = 10000  # Adjust for performance
    let table = generate_large_table(num_rows)
    print("Generated table with", num_rows, "rows")

    let sql = "SELECT * FROM table WHERE value > 5000"
    let avg_time = benchmark_query(table, sql, 10)
    print("Average query time for", sql, ":", avg_time, "seconds")

    let sum_time = benchmark_sum(table, 10)
    print("Average SIMD sum time:", sum_time, "seconds, sum:", simd_sum(table.columns[1]))

    # Compare to simple scan
    let start = time.now()
    var count = 0
    for i in range(table.columns[1].length):
        if table.columns[1][i] > 5000:
            count += 1
    let end = time.now()
    print("Simple scan time:", end - start, "seconds, results:", count)

    print("Benchmarks complete.")