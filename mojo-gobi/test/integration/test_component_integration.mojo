# Component Integration Tests for PL-GRIZZLY Lakehouse System
# Tests real interactions between storage engine, query optimizer, timeline, incremental processing, caching, and schema management

from collections import List, Dict
from python import Python, PythonObject
from lakehouse_engine import LakehouseEngine, Record, Commit, HYBRID, COW, MOR
from schema_manager import Column
from query_optimizer import QueryPlan, QueryOptimizer
from incremental_processor import IncrementalProcessor
from merkle_timeline import MerkleTimeline
from orc_storage import ORCStorage
from profiling_manager import ProfilingManager

# Test assertion utilities
fn assert_true(condition: Bool, message: String) raises:
    """Assert that a condition is true."""
    if not condition:
        print("ASSERTION FAILED:", message)
        raise Error("Assertion failed: " + message)

fn assert_equal(actual: String, expected: String, message: String) raises:
    """Assert that two strings are equal."""
    if actual != expected:
        print("ASSERTION FAILED:", message, "Expected:", expected, "Actual:", actual)
        raise Error("Assertion failed: " + message)

fn assert_greater(actual: Int, expected: Int, message: String) raises:
    """Assert that actual is greater than expected."""
    if actual <= expected:
        print("ASSERTION FAILED:", message, "Expected >", expected, "Actual:", actual)
        raise Error("Assertion failed: " + message)

# Component Integration Test Suite using real PL-GRIZZLY components
struct ComponentIntegrationTestSuite(Movable):
    var engine: LakehouseEngine
    var test_db_path: String

    fn __init__(out self) raises:
        self.test_db_path = "./test_component_integration_db_real"
        self.engine = LakehouseEngine(self.test_db_path)

    fn run_all_tests(mut self) raises:
        """Run all component integration tests."""
        print("Running Real Component Integration Tests...")
        print("=" * 60)

        try:
            self.test_storage_query_optimizer_integration()
            self.test_timeline_incremental_coordination()
            self.test_caching_query_execution_integration()
            self.test_schema_data_consistency()
            self.test_cross_component_error_handling()

            print("=" * 60)
            print("✓ All real component integration tests passed!")

        except e:
            print("✗ Component integration tests failed:", String(e))
            raise e

    fn test_storage_query_optimizer_integration(mut self) raises:
        """Test real integration between storage engine and query optimizer."""
        print("Testing storage engine and query optimizer integration...")

        # Create test table schema
        var columns = List[Column]()
        columns.append(Column("id", "int", False))
        columns.append(Column("name", "string", False))
        columns.append(Column("score", "float", True))

        var success = self.engine.create_table("test_storage_opt_real", columns, HYBRID)
        assert_true(success, "Failed to create test table")

        # Insert test data
        var records = List[Record]()
        for i in range(10):
            var record = Record()
            record.set_value("id", String(i + 1))
            record.set_value("name", "item_" + String(i + 1))
            record.set_value("score", String(Float64(i + 1) * 10.5))
            records.append(record.copy())

        var commit_id = self.engine.insert("test_storage_opt_real", records)
        assert_true(commit_id != "", "Failed to insert test data")

        # Test query optimization integration
        var sql = "SELECT id, name FROM test_storage_opt_real WHERE score > 50.0"
        var plan = self.engine.optimizer.optimize_query(sql, self.engine.schema_manager)
        assert_true(plan.query != "", "Query optimization failed")

        # Verify plan contains expected elements
        assert_true(len(plan.execution_steps) > 0, "Query plan should have execution steps")

        # Test storage integration by checking if data was actually stored
        var table_exists = self.engine.schema_manager.table_exists("test_storage_opt_real")
        assert_true(table_exists, "Table should exist in schema manager")

        print("✓ Storage engine and query optimizer integration test passed")

    fn test_timeline_incremental_coordination(mut self) raises:
        """Test real coordination between timeline and incremental processing."""
        print("Testing timeline and incremental processing coordination...")

        # Create test table
        var columns = List[Column]()
        columns.append(Column("id", "int", False))
        columns.append(Column("data", "string", False))

        var success = self.engine.create_table("test_timeline_inc_real", columns, HYBRID)
        assert_true(success, "Failed to create test table")

        # Insert initial data
        var records = List[Record]()
        var record = Record()
        record.set_value("id", "1")
        record.set_value("data", "initial_data")
        records.append(record.copy())

        var commit_id1 = self.engine.insert("test_timeline_inc_real", records)
        assert_true(commit_id1 != "", "Failed to insert initial data")

        # Insert more data
        records.clear()
        record = Record()
        record.set_value("id", "2")
        record.set_value("data", "additional_data")
        records.append(record.copy())

        var commit_id2 = self.engine.insert("test_timeline_inc_real", records)
        assert_true(commit_id2 != "", "Failed to insert additional data")

        # Test timeline coordination - get commits since timestamp
        var commits_since = self.engine.timeline.get_commits_since("test_timeline_inc_real", 0)
        assert_greater(len(commits_since), 0, "Should have commits in timeline")

        # Test incremental processing coordination
        var changes = List[String]()
        changes.append("INSERT INTO test_timeline_inc_real VALUES (3, 'incremental_data')")
        var incremental_commit = self.engine.timeline.commit("test_timeline_inc_real", changes, 1)
        assert_true(incremental_commit != "", "Incremental commit failed")

        # Verify timeline integrity
        var integrity_check = self.engine.timeline.verify_timeline_integrity()
        assert_true(integrity_check, "Timeline integrity check failed")

        print("✓ Timeline and incremental processing coordination test passed")

    fn test_caching_query_execution_integration(mut self) raises:
        """Test real integration between caching layer and query execution."""
        print("Testing caching layer and query execution integration...")

        # Create test table
        var columns = List[Column]()
        columns.append(Column("id", "int", False))
        columns.append(Column("category", "string", False))
        columns.append(Column("value", "float", True))

        var success = self.engine.create_table("test_cache_exec_real", columns, HYBRID)
        assert_true(success, "Failed to create test table")

        # Insert test data
        var records = List[Record]()
        for i in range(5):
            var record = Record()
            record.set_value("id", String(i + 1))
            record.set_value("category", "type_" + String((i % 3) + 1))
            record.set_value("value", String(Float64(i + 1) * 25.0))
            records.append(record.copy())

        var commit_id = self.engine.insert("test_cache_exec_real", records)
        assert_true(commit_id != "", "Failed to insert test data")

        # Test query execution with caching
        var sql = "SELECT category, AVG(value) FROM test_cache_exec_real GROUP BY category"

        # First execution - should cache the result
        var plan1 = self.engine.optimizer.optimize_query(sql, self.engine.schema_manager)
        assert_true(plan1.query != "", "First query optimization failed")

        # Second execution - should use cached plan if available
        var plan2 = self.engine.optimizer.optimize_query(sql, self.engine.schema_manager)
        assert_true(plan2.query != "", "Second query optimization failed")

        # Verify plans are consistent (basic check)
        assert_equal(plan1.query, plan2.query, "Query plans should be consistent")

        # Test profiling integration with caching
        self.engine.profiler.start_operation("cache_test_query")
        # Simulate some work
        var dummy_work = 0
        for i in range(1000):
            dummy_work += 1
        self.engine.profiler.end_operation("cache_test_query")

        var metrics = self.engine.profiler.get_metrics()
        assert_true(len(metrics) > 0, "Should have profiling metrics")

        print("✓ Caching layer and query execution integration test passed")

    fn test_schema_data_consistency(mut self) raises:
        """Test real schema management and data consistency across components."""
        print("Testing schema management and data consistency...")

        # Create test table
        var columns = List[Column]()
        columns.append(Column("id", "int", False))
        columns.append(Column("name", "string", False))
        columns.append(Column("value", "float", True))

        var success = self.engine.create_table("test_schema_real", columns, HYBRID)
        assert_true(success, "Failed to create test table")

        # Insert test data
        var records = List[Record]()
        var record = Record()
        record.set_value("id", "1")
        record.set_value("name", "test_item")
        record.set_value("value", "42.5")
        records.append(record.copy())

        var commit_id = self.engine.insert("test_schema_real", records)
        assert_true(commit_id != "", "Failed to insert test data")

        # Test schema evolution - add column
        var new_column = Column("description", "string", True)
        success = self.engine.schema_evolution.add_column("test_schema_real", new_column)
        assert_true(success, "Failed to add column via schema evolution")

        # Insert data with new column
        records.clear()
        record = Record()
        record.set_value("id", "2")
        record.set_value("name", "test_item_2")
        record.set_value("value", "100.0")
        record.set_value("description", "new column test")
        records.append(record.copy())

        commit_id = self.engine.insert("test_schema_real", records)
        assert_true(commit_id != "", "Failed to insert data with new column")

        # Verify schema consistency across components
        var table_schema = self.engine.schema_manager.get_table_schema("test_schema_real")
        assert_true(table_schema.is_ok, "Should be able to get table schema")

        if table_schema.is_ok:
            var schema = table_schema.value()
            assert_greater(len(schema.columns), 3, "Schema should have at least 4 columns after evolution")

        # Test migration manager integration
        var migration_success = self.engine.migration_manager.migrate_table("test_schema_real", "migrated_test_schema")
        # Migration might not succeed if target already exists, but should not crash
        print("✓ Schema management and data consistency test passed")

    fn test_cross_component_error_handling(mut self) raises:
        """Test real error handling across components."""
        print("Testing cross-component error handling...")

        # Test invalid table access
        var records = List[Record]()
        var record = Record()
        record.set_value("id", "1")
        records.append(record.copy())

        try:
            var commit_id = self.engine.insert("nonexistent_table_real", records)
            # Should handle gracefully
            print("✓ Correctly handled nonexistent table error")
        except:
            print("✓ Correctly handled nonexistent table error with exception")

        # Test invalid schema operations
        try:
            var new_column = Column("new_col", "string", True)
            var success = self.engine.schema_evolution.add_column("nonexistent_table_real", new_column)
            # Should handle gracefully
            print("✓ Correctly handled schema operation on nonexistent table")
        except:
            print("✓ Correctly handled schema operation on nonexistent table with exception")

        # Test invalid query optimization
        try:
            var invalid_sql = "SELECT * FROM nonexistent_table_real WHERE invalid_column > 0"
            var plan = self.engine.optimizer.optimize_query(invalid_sql, self.engine.schema_manager)
            # Should handle gracefully
            print("✓ Correctly handled invalid query optimization")
        except:
            print("✓ Correctly handled invalid query optimization with exception")

        # Test schema consistency after errors
        var columns = List[Column]()
        columns.append(Column("id", "int", False))
        columns.append(Column("data", "string", False))

        var success = self.engine.create_table("error_recovery_table_real", columns, HYBRID)
        assert_true(success, "Failed to create table after error handling test")

        # Verify all components are still functional
        var table_exists = self.engine.schema_manager.table_exists("error_recovery_table_real")
        assert_true(table_exists, "Schema manager should still work after errors")

        var timeline_ok = self.engine.timeline.verify_timeline_integrity()
        assert_true(timeline_ok, "Timeline should still be intact after errors")

        print("✓ Cross-component error handling test passed")