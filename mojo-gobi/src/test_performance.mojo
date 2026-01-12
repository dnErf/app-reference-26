"""
Performance Benchmark Test Runner
==================================

Runs comprehensive performance benchmarks for PL-GRIZZLY components.
"""

from performance_benchmarker import PerformanceBenchmarker

fn main() raises:
    """Run performance benchmarks."""
    print("🚀 PL-GRIZZLY Performance Benchmark Suite")
    print("==========================================")

    var benchmarker = PerformanceBenchmarker()
    var results = benchmarker.run_full_benchmark()

    print("\n📊 Generating Performance Report...")
    var report = benchmarker.generate_report(results)

    print("\n" + report)

    print("\n✅ Performance benchmarking complete!")