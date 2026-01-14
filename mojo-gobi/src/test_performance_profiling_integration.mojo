"""
Test Performance Profiling Integration

Comprehensive testing of advanced profiling features including query plan analysis,
bottleneck identification, optimization recommendations, performance comparison tools,
and historical performance tracking.
"""

from profiling_manager import ProfilingManager, QueryPlanAnalysis, PerformanceSnapshot, PerformanceComparison

fn test_query_plan_analysis() raises -> Bool:
    """Test query plan analysis integration."""
    print("Testing Query Plan Analysis Integration...")

    var profiler = ProfilingManager()
    profiler.enable_profiling()

    # Simulate query execution with plan analysis
    var query = "SELECT * FROM users JOIN orders ON users.id = orders.user_id WHERE users.age > 25"
    var plan_steps = List[String]()
    plan_steps.append("SCAN users table")
    plan_steps.append("FILTER users.age > 25")
    plan_steps.append("SCAN orders table")
    plan_steps.append("HASH JOIN on user_id")
    plan_steps.append("PROJECT columns")

    # Record query execution
    profiler.record_detailed_query_execution(query, 2.5, 0.1, 0.3, 2.1)

    # Analyze query plan
    profiler.analyze_query_plan(query, plan_steps, 150.0, 180.0, 2.5)

    # Get analysis
    var analysis = profiler.get_query_plan_analysis(query)

    print("Query:", analysis.query)
    print("Plan steps:", len(analysis.plan_steps))
    print("Estimated cost:", analysis.estimated_cost)
    print("Actual cost:", analysis.actual_cost)
    print("Bottlenecks found:", len(analysis.bottlenecks))
    print("Optimization suggestions:", len(analysis.optimization_suggestions))

    if len(analysis.plan_steps) != 5:
        print("ERROR: Expected 5 plan steps, got", len(analysis.plan_steps))
        return False
    if analysis.estimated_cost != 150.0:
        print("ERROR: Expected estimated cost 150.0, got", analysis.estimated_cost)
        return False
    if analysis.actual_cost != 180.0:
        print("ERROR: Expected actual cost 180.0, got", analysis.actual_cost)
        return False
    if len(analysis.bottlenecks) == 0:
        print("ERROR: Should identify bottlenecks")
        return False
    if len(analysis.optimization_suggestions) == 0:
        print("ERROR: Should provide optimization suggestions")
        return False

    print("✓ Query plan analysis test passed")
    return True

fn test_performance_snapshot_and_comparison() raises -> Bool:
    """Test performance snapshot and comparison tools."""
    print("\nTesting Performance Snapshot and Comparison...")

    var profiler = ProfilingManager()

    # Create initial baseline data
    profiler.record_query_execution("SELECT * FROM users", 0.5)
    profiler.record_query_execution("SELECT * FROM orders", 0.3)
    profiler.record_cache_hit(0.01)
    profiler.record_cache_hit(0.02)

    # Take first snapshot
    profiler.take_performance_snapshot()

    # Simulate performance changes
    profiler.record_query_execution("SELECT * FROM users", 0.4)  # Faster
    profiler.record_query_execution("SELECT * FROM products", 0.6)  # New query
    profiler.record_cache_hit(0.015)
    profiler.record_cache_miss(0.03)  # Some misses

    # Take second snapshot
    profiler.take_performance_snapshot()

    # Compare performance
    var comparison = profiler.compare_performance()

    print("Query time change:", comparison.query_time_change_percent, "%")
    print("Cache hit rate change:", comparison.cache_hit_rate_change_percent, "%")
    print("Overall performance score:", comparison.overall_performance_score)

    # Should show some improvement due to faster query
    if comparison.overall_performance_score < 0.0 or comparison.overall_performance_score > 100.0:
        print("ERROR: Performance score out of range")
        return False

    print("✓ Performance comparison test passed")
    return True

fn test_bottleneck_identification() raises -> Bool:
    """Test bottleneck identification algorithms."""
    print("\nTesting Bottleneck Identification...")

    var profiler = ProfilingManager()

    # Simulate slow queries (bottleneck)
    for i in range(40):  # 40 slow queries
        profiler.record_query_execution("SELECT * FROM large_table WHERE complex_condition", 1.5)

    # Simulate good cache performance
    for i in range(80):
        profiler.record_cache_hit(0.01)

    # Simulate normal queries
    for i in range(10):
        profiler.record_query_execution("SELECT id FROM users", 0.1)

    # Get bottleneck analysis
    var bottlenecks = profiler.get_bottleneck_analysis()

    print("Bottlenecks identified:", len(bottlenecks))
    for bottleneck in bottlenecks:
        print("-", bottleneck)

    # Should identify slow queries bottleneck
    var has_slow_query_bottleneck = False
    for bottleneck in bottlenecks:
        if "slow queries" in bottleneck:
            has_slow_query_bottleneck = True
            break

    if not has_slow_query_bottleneck:
        print("ERROR: Should identify slow query bottleneck")
        return False

    print("✓ Bottleneck identification test passed")
    return True

fn test_optimization_recommendations() raises -> Bool:
    """Test optimization recommendations engine."""
    print("\nTesting Optimization Recommendations...")

    var profiler = ProfilingManager()

    # Create conditions that trigger recommendations
    # High percentage of slow queries
    for i in range(40):
        profiler.record_query_execution("SELECT * FROM large_table", 1.5)

    # Poor cache performance
    for i in range(20):
        profiler.record_cache_miss(0.05)

    # Get recommendations
    var recommendations = profiler.get_optimization_recommendations()

    print("Optimization recommendations:", len(recommendations))
    for rec in recommendations:
        print("-", rec)

    # Should have recommendations for slow queries and cache
    if len(recommendations) == 0:
        print("ERROR: Should provide optimization recommendations")
        return False

    var has_query_recommendation = False
    var has_cache_recommendation = False

    for rec in recommendations:
        var rec_lower = rec.lower()
        if "query" in rec_lower:
            has_query_recommendation = True
        if "cache" in rec_lower:
            has_cache_recommendation = True

    if not has_query_recommendation:
        print("ERROR: Should recommend query optimizations")
        return False
    if not has_cache_recommendation:
        print("ERROR: Should recommend cache improvements")
        return False

    print("✓ Optimization recommendations test passed")
    return True

fn test_historical_performance_tracking() raises -> Bool:
    """Test historical performance tracking."""
    print("\nTesting Historical Performance Tracking...")

    var profiler = ProfilingManager()

    # Take multiple snapshots over time
    profiler.record_query_execution("SELECT * FROM users", 0.5)
    profiler.take_performance_snapshot()

    profiler.record_query_execution("SELECT * FROM orders", 0.3)
    profiler.take_performance_snapshot()

    profiler.record_query_execution("SELECT * FROM products", 0.4)
    profiler.take_performance_snapshot()

    # Get performance history
    var history = profiler.get_performance_history()

    print("Performance snapshots in history:", len(history))

    # Should have 3 snapshots
    if len(history) != 3:
        print("ERROR: Should have 3 performance snapshots, got", len(history))
        return False

    # Check that snapshots are in chronological order
    for i in range(1, len(history)):
        if history[i].timestamp < history[i-1].timestamp:
            print("ERROR: Snapshots should be in chronological order")
            return False

    print("✓ Historical performance tracking test passed")
    return True

fn test_enhanced_performance_report() raises -> Bool:
    """Test enhanced performance report with new features."""
    print("\nTesting Enhanced Performance Report...")

    var profiler = ProfilingManager()

    # Add some test data
    profiler.record_detailed_query_execution("SELECT * FROM users", 0.5, 0.05, 0.1, 0.35)
    profiler.record_cache_hit(0.01)
    profiler.record_cache_hit(0.02)

    # Add query plan analysis
    var plan_steps = List[String]()
    plan_steps.append("SCAN users")
    plan_steps.append("PROJECT columns")
    profiler.analyze_query_plan("SELECT * FROM users", plan_steps, 50.0, 45.0, 0.5)

    # Take snapshot
    profiler.take_performance_snapshot()

    # Generate report
    var report = profiler.generate_performance_report()

    print("Performance report generated successfully")
    print("Report length:", len(report))

    # Check that report contains new sections
    if "Query Plan Analysis" not in report:
        print("ERROR: Report should contain query plan analysis")
        return False
    if "Performance Comparison" not in report:
        print("ERROR: Report should contain performance comparison")
        return False
    if "System Bottlenecks" not in report:
        print("ERROR: Report should contain bottleneck analysis")
        return False
    if "Optimization Recommendations" not in report:
        print("ERROR: Report should contain optimization recommendations")
        return False
    if "Historical Performance" not in report:
        print("ERROR: Report should contain historical performance")
        return False

    print("✓ Enhanced performance report test passed")
    return True

fn main() raises:
    """Run all performance profiling integration tests."""
    print("=== Performance Profiling Integration Tests ===\n")

    var all_passed = True

    if not test_query_plan_analysis():
        all_passed = False
    if not test_performance_snapshot_and_comparison():
        all_passed = False
    if not test_bottleneck_identification():
        all_passed = False
    if not test_optimization_recommendations():
        all_passed = False
    if not test_historical_performance_tracking():
        all_passed = False
    if not test_enhanced_performance_report():
        all_passed = False

    if all_passed:
        print("\n=== All Performance Profiling Integration Tests Passed! ===")
    else:
        print("\n=== Some Tests Failed ===")