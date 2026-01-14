"""
Performance Monitoring Test

Tests the performance monitoring capabilities of QueryOptimizer and LakehouseEngine.
"""

from query_optimizer import QueryOptimizer
from lakehouse_engine import LakehouseEngine
from schema_manager import SchemaManager, Column
from collections import List

fn test_performance_monitoring() raises:
    """Test performance monitoring functionality."""
    print("=== Performance Monitoring Test ===\n")

    # Test QueryOptimizer profiling
    print("Testing QueryOptimizer profiling...")
    var optimizer = QueryOptimizer()

    # Enable profiling
    optimizer.enable_profiling()

    # Simulate some cache operations
    var cache_result1 = optimizer.check_cache("test_key_1", 1000)
    var cache_result2 = optimizer.check_cache("test_key_1", 1000)  # Should be cache miss then hit

    # Store something in cache
    optimizer.store_in_cache("test_key_1", "test_result", 1000)

    # Check cache again (should be hit)
    var cache_result3 = optimizer.check_cache("test_key_1", 1000)

    print("✓ Cache operations completed")

    # Generate performance report
    var report = optimizer.generate_performance_report()
    print("QueryOptimizer Performance Report:")
    print(report)
    print()

    # Test LakehouseEngine profiling
    print("Testing LakehouseEngine profiling...")
    var engine = LakehouseEngine("./test_performance_data")

    # Enable profiling
    engine.enable_profiling()

    # Create a test table
    var columns = List[Column]()
    columns.append(Column("id", "INTEGER"))
    columns.append(Column("name", "STRING"))

    var table_created = engine.create_table("test_table", columns)
    print("✓ Test table created:", table_created)

    # Generate LakehouseEngine performance report
    var engine_report = engine.generate_performance_report()
    print("LakehouseEngine Performance Report:")
    print(engine_report)

    print("✓ Performance monitoring test completed successfully!")

fn main() raises:
    test_performance_monitoring()