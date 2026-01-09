"""
Mojo Benchmarking and Profiling Example

This file demonstrates performance benchmarking and profiling techniques in Mojo:
- Timing function execution
- Performance comparisons
- Profiling code sections
- Statistical analysis of benchmarks
- Best practices for benchmarking
"""

from python import Python

# 1. Basic timing utilities
fn get_current_time() -> Float64:
    """Get current time in seconds (using Python interop)."""
    try:
        Python.add_to_path(".")
        var time_code = "import time; result = time.time()"
        var result = Python.evaluate(time_code)
        return Float64(result)
    except:
        return 0.0

struct BenchmarkTimer:
    """A simple benchmarking timer."""
    var start_time: Float64

    fn __init__(out self):
        self.start_time = get_current_time()

    fn reset(mut self):
        """Reset the timer."""
        self.start_time = get_current_time()

    fn elapsed(self) -> Float64:
        """Get elapsed time since start/reset."""
        return get_current_time() - self.start_time

# 2. Benchmarking functions
fn benchmark_function(func_name: String, iterations: Int):
    """Benchmark a function by running it multiple times."""
    print("Benchmarking:", func_name)
    print("Iterations:", iterations)

    var timer = BenchmarkTimer()
    var total_time = 0.0
    var min_time = Float64.MAX
    var max_time = 0.0

    for i in range(iterations):
        var start = get_current_time()

        # Call the function to benchmark (placeholder)
        var _result = perform_computation(i)

        var end = get_current_time()
        var iteration_time = end - start

        total_time += iteration_time
        if iteration_time < min_time:
            min_time = iteration_time
        if iteration_time > max_time:
            max_time = iteration_time

    var avg_time = total_time / Float64(iterations)

    print("Total time:", total_time, "seconds")
    print("Average time per iteration:", avg_time, "seconds")
    print("Min time:", min_time, "seconds")
    print("Max time:", max_time, "seconds")
    print("Iterations per second:", Float64(iterations) / total_time)
    print()

fn perform_computation(n: Int) -> Int:
    """A sample computation to benchmark."""
    var result = 0
    for i in range(n % 1000 + 1):  # Variable workload
        result += i * i
    return result

# 3. Algorithm comparison
fn compare_algorithms():
    """Compare performance of different algorithms."""
    print("=== Algorithm Performance Comparison ===")

    var sizes = List[Int]()
    sizes.append(100)
    sizes.append(500)
    sizes.append(1000)

    for size in sizes:
        print("Input size:", size)

        # Algorithm 1: Simple loop
        var timer1 = BenchmarkTimer()
        var result1 = algorithm1(size)
        var time1 = timer1.elapsed()

        # Algorithm 2: Optimized version
        var timer2 = BenchmarkTimer()
        var result2 = algorithm2(size)
        var time2 = timer2.elapsed()

        print("  Algorithm 1 result:", result1, "time:", time1, "seconds")
        print("  Algorithm 2 result:", result2, "time:", time2, "seconds")

        if time1 > 0.0:
            var speedup = time1 / time2
            print("  Speedup:", speedup, "x")
        print()

fn algorithm1(n: Int) -> Int:
    """Simple algorithm (less efficient)."""
    var result = 0
    for i in range(n):
        for j in range(i):
            result += 1
    return result

fn algorithm2(n: Int) -> Int:
    """Optimized algorithm (more efficient)."""
    # Mathematical formula: sum from i=0 to n-1 of i = n*(n-1)/2
    return Int(Float64(n) * Float64(n - 1) / 2.0)

# 4. Memory usage profiling (conceptual)
fn memory_profiling():
    """Demonstrate memory usage profiling concepts."""
    print("=== Memory Usage Profiling ===")

    print("Memory Profiling Techniques:")
    print("- Track allocations during execution")
    print("- Monitor peak memory usage")
    print("- Identify memory leaks")
    print("- Measure memory access patterns")
    print()

    print("Profiling Data Structures:")
    print("- Allocation count and size")
    print("- Deallocation patterns")
    print("- Memory fragmentation")
    print("- Cache hit/miss ratios")
    print()

# 5. Profiling code sections
fn profile_code_sections():
    """Profile different sections of code."""
    print("=== Code Section Profiling ===")

    var total_timer = BenchmarkTimer()

    # Section 1: Data preparation
    var section_timer = BenchmarkTimer()
    var data = prepare_data(1000)
    var prep_time = section_timer.elapsed()
    print("Data preparation:", prep_time, "seconds")

    # Section 2: Computation
    section_timer.reset()
    var result = process_data(data)
    var comp_time = section_timer.elapsed()
    print("Computation:", comp_time, "seconds")

    # Section 3: Result formatting
    section_timer.reset()
    var output = format_result(result)
    var format_time = section_timer.elapsed()
    print("Result formatting:", format_time, "seconds")

    var total_time = total_timer.elapsed()
    print("Total time:", total_time, "seconds")

    # Calculate percentages
    var prep_pct = (prep_time / total_time) * 100.0
    var comp_pct = (comp_time / total_time) * 100.0
    var format_pct = (format_time / total_time) * 100.0

    print("Preparation:", prep_pct, "%")
    print("Computation:", comp_pct, "%")
    print("Formatting:", format_pct, "%")
    print()

fn prepare_data(size: Int) -> List[Int]:
    """Prepare test data."""
    var data = List[Int]()
    for i in range(size):
        data.append(i * i)
    return data^

fn process_data(data: List[Int]) -> Int:
    """Process the data."""
    var result = 0
    for i in range(len(data)):
        result += data[i]
    return result

fn format_result(result: Int) -> String:
    """Format the result."""
    return "Final result: " + String(result)

# 6. Statistical analysis of benchmarks
fn statistical_analysis():
    """Perform statistical analysis on benchmark results."""
    print("=== Statistical Analysis of Benchmarks ===")

    print("Benchmark Statistics:")
    print("- Mean (average) execution time")
    print("- Standard deviation (variability)")
    print("- Median (middle value)")
    print("- Percentiles (P50, P95, P99)")
    print("- Min/Max values")
    print()

    print("Interpreting Results:")
    print("- Lower mean = better performance")
    print("- Lower standard deviation = more consistent")
    print("- Check for outliers (very slow/fast runs)")
    print("- Consider warm-up effects")
    print()

# 7. Benchmarking best practices
fn benchmarking_best_practices():
    """Demonstrate benchmarking best practices."""
    print("=== Benchmarking Best Practices ===")

    print("1. Warm-up Phase:")
    print("   - Run code several times before measuring")
    print("   - Allow JIT compilation and cache warming")
    print()

    print("2. Multiple Iterations:")
    print("   - Run benchmark many times")
    print("   - Calculate statistics (mean, std dev)")
    print("   - Identify and remove outliers")
    print()

    print("3. Controlled Environment:")
    print("   - Consistent hardware and software")
    print("   - Minimize background processes")
    print("   - Control CPU frequency scaling")
    print()

    print("4. Fair Comparisons:")
    print("   - Compare equivalent functionality")
    print("   - Use same input data")
    print("   - Measure same metrics")
    print()

    print("5. Statistical Rigor:")
    print("   - Use appropriate sample sizes")
    print("   - Check for statistical significance")
    print("   - Report confidence intervals")
    print()

# 8. Profiling tools and techniques
fn profiling_tools():
    """Discuss profiling tools and techniques."""
    print("=== Profiling Tools and Techniques ===")

    print("Built-in Profiling:")
    print("- Execution time measurement")
    print("- Memory usage tracking")
    print("- Function call counting")
    print()

    print("External Tools:")
    print("- CPU profilers (perf, VTune)")
    print("- Memory profilers (Valgrind)")
    print("- Cache simulators")
    print("- Hardware performance counters")
    print()

    print("Profiling Metrics:")
    print("- CPU time (user + system)")
    print("- Memory allocations")
    print("- Cache misses")
    print("- Branch mispredictions")
    print("- Context switches")
    print()

fn main():
    print("=== Mojo Benchmarking and Profiling ===\n")

    # Run benchmarks
    benchmark_function("Sample Computation", 10)
    compare_algorithms()
    profile_code_sections()

    # Conceptual discussions
    memory_profiling()
    statistical_analysis()
    benchmarking_best_practices()
    profiling_tools()

    print("=== Benchmarking and Profiling Examples Completed ===")
    print("Note: Current Mojo version has basic timing capabilities")
    print("Advanced profiling tools may be available in future versions")
    print()
    print("Key Takeaways:")
    print("- Always measure performance objectively")
    print("- Use statistical analysis for reliable results")
    print("- Profile before optimizing")
    print("- Consider the full system performance")
    print("- Validate optimizations with benchmarks")