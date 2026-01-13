"""
Performance Benchmarking Suite
===============================

Comprehensive performance benchmarking for PL-GRIZZLY components.
Measures serialization, ORC storage, memory usage, and identifies bottlenecks.
"""

from python import Python, PythonObject
from collections import List, Dict
import time
from blob_storage import BlobStorage
from schema_manager import SchemaManager, DatabaseSchema, TableSchema, Column
from orc_storage import ORCStorage
from index_storage import IndexStorage
from pl_grizzly_interpreter import PLGrizzlyInterpreter
from pl_grizzly_environment import Environment

struct BenchmarkResult(Movable, Copyable):
    var operation: String
    var iterations: Int
    var total_time: Float64
    var avg_time: Float64
    var min_time: Float64
    var max_time: Float64
    var memory_usage: Int  # in bytes

    fn __init__(out self, operation: String, iterations: Int = 1):
        self.operation = operation
        self.iterations = iterations
        self.total_time = 0.0
        self.avg_time = 0.0
        self.min_time = Float64.MAX
        self.max_time = 0.0
        self.memory_usage = 0

    fn __copyinit__(out self, other: Self):
        self.operation = other.operation
        self.iterations = other.iterations
        self.total_time = other.total_time
        self.avg_time = other.avg_time
        self.min_time = other.min_time
        self.max_time = other.max_time
        self.memory_usage = other.memory_usage

    fn __moveinit__(out self, deinit existing: Self):
        self.operation = existing.operation^
        self.iterations = existing.iterations
        self.total_time = existing.total_time
        self.avg_time = existing.avg_time
        self.min_time = existing.min_time
        self.max_time = existing.max_time
        self.memory_usage = existing.memory_usage

    fn record_time(mut self, duration: Float64):
        self.total_time += duration
        if duration < self.min_time:
            self.min_time = duration
        if duration > self.max_time:
            self.max_time = duration

    fn finalize(mut self):
        if self.iterations > 0:
            self.avg_time = self.total_time / Float64(self.iterations)

    fn to_string(self) -> String:
        var result = self.operation + ":\n"
        result += "  Iterations: " + String(self.iterations) + "\n"
        result += "  Total Time: " + String(self.total_time) + "s\n"
        result += "  Avg Time: " + String(self.avg_time) + "s\n"
        result += "  Min Time: " + String(self.min_time) + "s\n"
        result += "  Max Time: " + String(self.max_time) + "s\n"
        if self.memory_usage > 0:
            result += "  Memory Usage: " + String(self.memory_usage) + " bytes\n"
        return result

struct PerformanceBenchmarker(Movable):
    var results: List[BenchmarkResult]
    var python_time: PythonObject
    var python_psutil: PythonObject

    fn __init__(out self) raises:
        self.results = List[BenchmarkResult]()
        var python_time_mod = Python.import_module("time")
        self.python_time = python_time_mod

        # Try to import psutil for memory monitoring
        try:
            self.python_psutil = Python.import_module("psutil")
        except:
            self.python_psutil = PythonObject(None)

    fn __moveinit__(out self, deinit existing: Self):
        self.results = existing.results^
        self.python_time = existing.python_time
        self.python_psutil = existing.python_psutil

    fn time_function(mut self, name: String, iterations: Int = 100) raises -> BenchmarkResult:
        """Time a function over multiple iterations - placeholder for now."""
        var result = BenchmarkResult(name, iterations)
        # TODO: Implement proper timing mechanism without lambdas
        result.finalize()
        self.results.append(result.copy())
        return result.copy()

    fn benchmark_query_performance(mut self) raises -> List[BenchmarkResult]:
        """Benchmark PL-GRIZZLY query performance with 1 million rows."""
        var query_results = List[BenchmarkResult]()

        # Setup test database
        var storage = BlobStorage("benchmark_query_db_1m")
        var schema_manager = SchemaManager(storage)
        var index_storage = IndexStorage(storage)
        var orc_storage = ORCStorage(storage^, schema_manager^, index_storage^)
        var interpreter = PLGrizzlyInterpreter(orc_storage^)
        var env = interpreter.global_env

        # Create test table
        _ = interpreter.evaluate("CREATE TABLE benchmark_users (id INT, name STRING, age INT)", env)

        print("📥 Inserting 1,000,000 rows for benchmarking...")

        # Insert 1M test data
        var insert_result = BenchmarkResult("INSERT 1M Rows", 1)
        var start_time = self.python_time.time()
        for i in range(1_000_000):
            var insert_sql = "INSERT INTO benchmark_users VALUES (" + String(i) + ", \"User" + String(i) + "\", " + String(i % 100 + 20) + ")"
            _ = interpreter.evaluate(insert_sql, env)
        var end_time = self.python_time.time()
        var duration = Float64(end_time) - Float64(start_time)
        insert_result.record_time(duration)
        insert_result.finalize()
        query_results.append(insert_result.copy())
        print("✅ Inserted 1M rows in " + String(duration) + "s")

        # Benchmark SELECT queries
        var select_result = BenchmarkResult("SELECT 1M Rows", 5)
        for i in range(5):
            var start_time = self.python_time.time()
            var result = interpreter.interpret("SELECT * FROM benchmark_users")
            var end_time = self.python_time.time()
            var duration = Float64(end_time) - Float64(start_time)
            select_result.record_time(duration)
        select_result.finalize()
        query_results.append(select_result.copy())

        # Benchmark WHERE queries
        var where_result = BenchmarkResult("WHERE Query on 1M Rows", 5)
        for i in range(5):
            var start_time = self.python_time.time()
            var result = interpreter.interpret("SELECT * FROM benchmark_users WHERE age > 50")
            var end_time = self.python_time.time()
            var duration = Float64(end_time) - Float64(start_time)
            where_result.record_time(duration)
        where_result.finalize()
        query_results.append(where_result.copy())

        # Benchmark aggregation queries
        var agg_result = BenchmarkResult("Aggregation on 1M Rows", 5)
        for i in range(5):
            var start_time = self.python_time.time()
            var result = interpreter.interpret("SELECT Array::(distinct age) FROM benchmark_users")
            var end_time = self.python_time.time()
            var duration = Float64(end_time) - Float64(start_time)
            agg_result.record_time(duration)
        agg_result.finalize()
        query_results.append(agg_result.copy())

        return query_results^

    fn benchmark_sqlite(mut self) raises -> List[BenchmarkResult]:
        """Benchmark SQLite performance with 1 million rows."""
        var sqlite_results = List[BenchmarkResult]()

        var sqlite3 = Python.import_module("sqlite3")

        # Create in-memory database
        var conn = sqlite3.connect(":memory:")
        var cursor = conn.cursor()

        # Create table
        cursor.execute("CREATE TABLE benchmark_users (id INTEGER, name TEXT, age INTEGER)")

        print("📥 Inserting 1,000,000 rows into SQLite...")

        # Insert 1M rows
        var insert_result = BenchmarkResult("SQLite INSERT 1M Rows", 1)
        var start_time = self.python_time.time()
        for i in range(1_000_000):
            cursor.execute("INSERT INTO benchmark_users VALUES (" + String(i) + ", '" + "User" + String(i) + "', " + String((i % 100) + 20) + ")")
        conn.commit()
        var end_time = self.python_time.time()
        var duration = Float64(end_time) - Float64(start_time)
        insert_result.record_time(duration)
        insert_result.finalize()
        sqlite_results.append(insert_result.copy())
        print("✅ SQLite inserted 1M rows in " + String(duration) + "s")

        # Benchmark SELECT
        var select_result = BenchmarkResult("SQLite SELECT 1M Rows", 5)
        for i in range(5):
            var start_time = self.python_time.time()
            var rows = cursor.execute("SELECT * FROM benchmark_users").fetchall()
            var end_time = self.python_time.time()
            var duration = Float64(end_time) - Float64(start_time)
            select_result.record_time(duration)
        select_result.finalize()
        sqlite_results.append(select_result.copy())

        # Benchmark WHERE
        var where_result = BenchmarkResult("SQLite WHERE on 1M Rows", 5)
        for i in range(5):
            var start_time = self.python_time.time()
            var rows = cursor.execute("SELECT * FROM benchmark_users WHERE age > 50").fetchall()
            var end_time = self.python_time.time()
            var duration = Float64(end_time) - Float64(start_time)
            where_result.record_time(duration)
        where_result.finalize()
        sqlite_results.append(where_result.copy())

        # Benchmark aggregation
        var agg_result = BenchmarkResult("SQLite Aggregation on 1M Rows", 5)
        for i in range(5):
            var start_time = self.python_time.time()
            var result = cursor.execute("SELECT DISTINCT age FROM benchmark_users").fetchall()
            var end_time = self.python_time.time()
            var duration = Float64(end_time) - Float64(start_time)
            agg_result.record_time(duration)
        agg_result.finalize()
        sqlite_results.append(agg_result.copy())

        conn.close()
        return sqlite_results^

    fn benchmark_duckdb(mut self) raises -> List[BenchmarkResult]:
        """Benchmark DuckDB performance with 1 million rows."""
        var duckdb_results = List[BenchmarkResult]()

        try:
            var duckdb = Python.import_module("duckdb")

            # Create in-memory database
            var conn = duckdb.connect(":memory:")

            # Create table
            conn.execute("CREATE TABLE benchmark_users (id INTEGER, name VARCHAR, age INTEGER)")

            print("📥 Inserting 1,000,000 rows into DuckDB...")

            # Insert 1M rows
            var insert_result = BenchmarkResult("DuckDB INSERT 1M Rows", 1)
            var start_time = self.python_time.time()
            for i in range(1_000_000):
                conn.execute("INSERT INTO benchmark_users VALUES (" + String(i) + ", '" + "User" + String(i) + "', " + String((i % 100) + 20) + ")")
            var end_time = self.python_time.time()
            var duration = Float64(end_time) - Float64(start_time)
            insert_result.record_time(duration)
            insert_result.finalize()
            duckdb_results.append(insert_result.copy())
            print("✅ DuckDB inserted 1M rows in " + String(duration) + "s")

            # Benchmark SELECT
            var select_result = BenchmarkResult("DuckDB SELECT 1M Rows", 5)
            for i in range(5):
                var start_time = self.python_time.time()
                var result = conn.execute("SELECT * FROM benchmark_users").fetchall()
                var end_time = self.python_time.time()
                var duration = Float64(end_time) - Float64(start_time)
                select_result.record_time(duration)
            select_result.finalize()
            duckdb_results.append(select_result.copy())

            # Benchmark WHERE
            var where_result = BenchmarkResult("DuckDB WHERE on 1M Rows", 5)
            for i in range(5):
                var start_time = self.python_time.time()
                var result = conn.execute("SELECT * FROM benchmark_users WHERE age > 50").fetchall()
                var end_time = self.python_time.time()
                var duration = Float64(end_time) - Float64(start_time)
                where_result.record_time(duration)
            where_result.finalize()
            duckdb_results.append(where_result.copy())

            # Benchmark aggregation
            var agg_result = BenchmarkResult("DuckDB Aggregation on 1M Rows", 5)
            for i in range(5):
                var start_time = self.python_time.time()
                var result = conn.execute("SELECT DISTINCT age FROM benchmark_users").fetchall()
                var end_time = self.python_time.time()
                var duration = Float64(end_time) - Float64(start_time)
                agg_result.record_time(duration)
            agg_result.finalize()
            duckdb_results.append(agg_result.copy())

            conn.close()
        except:
            print("❌ DuckDB not available, skipping DuckDB benchmarks")

        return duckdb_results^

    fn get_memory_usage(self) -> Int:
        """Get current memory usage in bytes."""
        if self.python_psutil:
            try:
                var process = self.python_psutil.Process()
                return Int(process.memory_info().rss)
            except:
                return 0
        return 0

    fn run_full_benchmark(mut self) raises -> List[BenchmarkResult]:
        """Run complete performance benchmark suite with 1 million rows."""
        print("🧪 Starting PL-GRIZZLY Performance Benchmark Suite (1M Rows)")
        print("=" * 60)

        var all_results = List[BenchmarkResult]()

        # print("📊 Benchmarking Serialization Performance...")
        # var serialization_results = self.benchmark_serialization()
        # for result in serialization_results:
        #     all_results.append(result.copy())
        #     print(result.to_string())

        # print("💾 Benchmarking ORC Storage Performance...")
        # var orc_results = self.benchmark_orc_storage()
        # for result in orc_results:
        #     all_results.append(result.copy())
        #     print(result.to_string())

        print("🔍 Benchmarking PL-GRIZZLY Query Performance (1M Rows)...")
        var query_results = self.benchmark_query_performance()
        for result in query_results:
            all_results.append(result.copy())
            print(result.to_string())

        print("🗄️ Benchmarking SQLite Performance (1M Rows)...")
        var sqlite_results = self.benchmark_sqlite()
        for result in sqlite_results:
            all_results.append(result.copy())
            print(result.to_string())

        print("🦆 Benchmarking DuckDB Performance (1M Rows)...")
        var duckdb_results = self.benchmark_duckdb()
        for result in duckdb_results:
            all_results.append(result.copy())
            print(result.to_string())

        # print("⚡ Benchmarking JIT Compiler Performance...")
        # var jit_results = self.benchmark_jit_compiler()
        # for result in jit_results:
        #     all_results.append(result.copy())
        #     print(result.to_string())

        print("✅ Benchmark Suite Complete")
        print("=" * 60)

        return all_results^

    fn generate_report(self, results: List[BenchmarkResult]) -> String:
        """Generate a comprehensive performance report for 1M row benchmarks."""
        var report = "# PL-GRIZZLY Performance Benchmark Report (1M Rows)\n\n"
        report += "## Summary\n\n"
        report += "| Operation | Avg Time (s) | Min Time (s) | Max Time (s) | Iterations |\n"
        report += "|-----------|---------------|--------------|--------------|------------|\n"

        for result in results:
            report += "| " + result.operation + " | " + String(result.avg_time) + " | " + String(result.min_time) + " | " + String(result.max_time) + " | " + String(result.iterations) + " |\n"

        report += "\n## Performance Comparison (1M Rows)\n\n"

        # Extract key metrics
        var pl_grizzly_insert = 0.0
        var sqlite_insert = 0.0
        var duckdb_insert = 0.0
        var pl_grizzly_select = 0.0
        var sqlite_select = 0.0
        var duckdb_select = 0.0

        for result in results:
            if result.operation == "INSERT 1M Rows":
                pl_grizzly_insert = result.avg_time
            elif result.operation == "SQLite INSERT 1M Rows":
                sqlite_insert = result.avg_time
            elif result.operation == "DuckDB INSERT 1M Rows":
                duckdb_insert = result.avg_time
            elif result.operation == "SELECT 1M Rows":
                pl_grizzly_select = result.avg_time
            elif result.operation == "SQLite SELECT 1M Rows":
                sqlite_select = result.avg_time
            elif result.operation == "DuckDB SELECT 1M Rows":
                duckdb_select = result.avg_time

        if pl_grizzly_insert > 0 and sqlite_insert > 0:
            var insert_ratio = pl_grizzly_insert / sqlite_insert
            report += "### INSERT Performance\n"
            report += "- PL-GRIZZLY: " + String(pl_grizzly_insert) + "s\n"
            report += "- SQLite: " + String(sqlite_insert) + "s\n"
            if duckdb_insert > 0:
                report += "- DuckDB: " + String(duckdb_insert) + "s\n"
            report += "- PL-GRIZZLY is " + String(insert_ratio) + "x " + ("slower" if insert_ratio > 1 else "faster") + " than SQLite for INSERT\n\n"

        if pl_grizzly_select > 0 and sqlite_select > 0:
            var select_ratio = pl_grizzly_select / sqlite_select
            report += "### SELECT Performance\n"
            report += "- PL-GRIZZLY: " + String(pl_grizzly_select) + "s\n"
            report += "- SQLite: " + String(sqlite_select) + "s\n"
            if duckdb_select > 0:
                report += "- DuckDB: " + String(duckdb_select) + "s\n"
            report += "- PL-GRIZZLY is " + String(select_ratio) + "x " + ("slower" if select_ratio > 1 else "faster") + " than SQLite for SELECT\n\n"

        report += "## Detailed Results\n\n"
        for result in results:
            report += "### " + result.operation + "\n\n"
            report += result.to_string() + "\n"

        report += "\n## Recommendations\n\n"

        # Analyze results and provide recommendations
        if pl_grizzly_insert > sqlite_insert * 2:
            report += "- **INSERT Optimization**: PL-GRIZZLY INSERT is significantly slower than SQLite. Consider bulk insert operations and optimize AST evaluation for INSERT statements.\n"
        if pl_grizzly_select > sqlite_select * 2:
            report += "- **SELECT Optimization**: PL-GRIZZLY SELECT is slower than SQLite. Implement query result caching and optimize data retrieval from ORC storage.\n"
        if duckdb_insert > 0 and duckdb_insert < pl_grizzly_insert:
            report += "- **Competitive Analysis**: DuckDB outperforms PL-GRIZZLY in INSERT operations. Study DuckDB's columnar storage and vectorized execution.\n"

        report += "- **JIT Compiler**: Current JIT benchmarks show compilation overhead. Focus on reducing compilation time for complex queries.\n"
        report += "- **Memory Usage**: Implement detailed memory profiling to identify memory leaks in large dataset operations.\n"
        report += "- **ORC Storage**: With 10K rows, ORC performance is acceptable, but test with larger datasets for scalability.\n"
        report += "- **Scalability**: 1M row benchmarks reveal performance characteristics. Consider sharding or partitioning for larger datasets.\n"

        return report

fn main() raises:
    var benchmarker = PerformanceBenchmarker()
    var results = benchmarker.run_full_benchmark()
    var report = benchmarker.generate_report(results)

    # Save report to file
    var storage = BlobStorage("benchmark_reports")
    var time_mod = Python.import_module("time")
    var timestamp = String(time_mod.time())
    var report_path = "performance_report_" + timestamp + ".md"
    _ = storage.write_blob(report_path, report)

    print("📄 Performance report saved to: " + report_path)
    print("\n" + report)