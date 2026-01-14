# Test Enhanced Query Optimization Features
# Tests the advanced query optimization capabilities

from collections import List, Dict
from query_optimizer import QueryOptimizer, QueryPlan

fn test_cost_calculation() raises:
    """Test the enhanced cost calculation system."""
    print("🧪 Testing Cost Calculation System")
    print("=" * 50)

    var optimizer = QueryOptimizer()

    # Create test plans individually
    var plan1 = QueryPlan("table_scan", "test_table", None, 100.0, 1)
    var plan2 = QueryPlan("index_scan", "test_table", None, 10.0, 1)
    var plan3 = QueryPlan("parallel_scan", "test_table", None, 80.0, 4)

    # Test cost calculation (without schema manager for simplicity)
    # Test plan1
    # Note: calculate_io_cost requires SchemaManager, so we'll skip it for now
    var cpu_cost1 = optimizer.calculate_cpu_cost(plan1)
    var network_cost1 = optimizer.calculate_network_cost(plan1)

    print("  Plan 1 -", plan1.operation, ":")
    print("    CPU Cost:", String(cpu_cost1))
    print("    Network Cost:", String(network_cost1))

    # Test plan2
    var cpu_cost2 = optimizer.calculate_cpu_cost(plan2)
    var network_cost2 = optimizer.calculate_network_cost(plan2)

    print("  Plan 2 -", plan2.operation, ":")
    print("    CPU Cost:", String(cpu_cost2))
    print("    Network Cost:", String(network_cost2))

    # Test plan3
    var cpu_cost3 = optimizer.calculate_cpu_cost(plan3)
    var network_cost3 = optimizer.calculate_network_cost(plan3)

    print("  Plan 3 -", plan3.operation, ":")
    print("    CPU Cost:", String(cpu_cost3))
    print("    Network Cost:", String(network_cost3))

    print("✅ Cost calculation test completed!")

fn test_change_analysis() raises:
    """Test change pattern analysis for incremental optimization."""
    print("🧪 Testing Change Pattern Analysis")
    print("=" * 50)

    var optimizer = QueryOptimizer()

    # Test different change patterns
    var changes = List[String]()
    changes.append("UPDATE users SET name = 'John' WHERE id = 1")
    changes.append("UPDATE users SET name = 'Jane' WHERE id = 2")
    changes.append("INSERT INTO users (name) VALUES ('Bob')")

    var analysis = optimizer.analyze_change_patterns(changes)
    print("📊 Change Analysis Results:")
    for entry in analysis.items():
        print("  " + entry.key + ": " + entry.value)

    print("✅ Change analysis test completed!")

fn test_selectivity_estimation() raises:
    """Test selectivity estimation for WHERE conditions."""
    print("🧪 Testing Selectivity Estimation")
    print("=" * 50)

    var optimizer = QueryOptimizer()

    # Test different condition types
    var test_conditions = List[String]()
    test_conditions.append("id = 1")  # Equality - very selective
    test_conditions.append("value > 100")  # Range - moderately selective
    test_conditions.append("name LIKE '%john%'")  # Pattern - less selective

    for condition in test_conditions:
        var selectivity = optimizer.estimate_condition_selectivity(condition)
        print("  Condition '" + condition + "' selectivity:", String(selectivity))

    print("✅ Selectivity estimation test completed!")

fn test_cache_operations() raises:
    """Test advanced caching operations."""
    print("🧪 Testing Cache Operations")
    print("=" * 50)

    var optimizer = QueryOptimizer()

    # Test cache storage and retrieval
    var test_key = "test_query_cache_key"
    var test_result = "test query result"
    var current_time = 1700000000

    optimizer.store_in_cache(test_key, test_result, current_time)

    var cached_result = optimizer.check_cache(test_key, current_time)
    if cached_result:
        print("✓ Cache hit successful:", cached_result.value())
    else:
        print("❌ Cache miss")

    # Test cache effectiveness metrics
    var effectiveness = optimizer.get_cache_effectiveness()
    print("📊 Cache Effectiveness:")
    for entry in effectiveness.items():
        print("  " + entry.key + ": " + entry.value)

    print("✅ Cache operations test completed!")

fn test_performance_reporting() raises:
    """Test performance reporting capabilities."""
    print("🧪 Testing Performance Reporting")
    print("=" * 50)

    var optimizer = QueryOptimizer()

    # Enable profiling
    optimizer.enable_profiling()

    # Generate some mock activity
    var mock_result = "mock result"
    var mock_time = 1700000000
    optimizer.store_in_cache("mock_key", mock_result, mock_time)

    # Generate report
    var report = optimizer.generate_performance_report()
    print("📋 Performance Report:")
    print(report)

    print("✅ Performance reporting test completed!")

fn main() raises:
    """Run all query optimization tests."""
    print("🚀 Starting Enhanced Query Optimization Tests")
    print("=" * 60)

    test_cost_calculation()
    print()

    test_change_analysis()
    print()

    test_selectivity_estimation()
    print()

    test_cache_operations()
    print()

    test_performance_reporting()
    print()

    print("🎉 All Query Optimization tests completed!")