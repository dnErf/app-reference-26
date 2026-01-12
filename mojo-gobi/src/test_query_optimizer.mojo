"""
QueryOptimizer Functionality Test Module

Tests for the QueryOptimizer to ensure it works correctly after re-enablement.
"""

from query_optimizer import QueryOptimizer, QueryPlan
from pl_grizzly_parser import PLGrizzlyParser, ASTNode
from pl_grizzly_lexer import PLGrizzlyLexer
from schema_manager import SchemaManager
from blob_storage import BlobStorage

fn test_query_optimizer_basic() raises:
    """Test basic QueryOptimizer functionality."""
    print("Testing QueryOptimizer basic functionality...")

    # Create QueryOptimizer instance
    var optimizer = QueryOptimizer()

    # Create schema manager and materialized views dict
    var blob_storage = BlobStorage("/tmp/test_db")
    var schema_manager = SchemaManager(blob_storage)
    var materialized_views = Dict[String, String]()

    # Test optimize_select method with SQL string
    var sql = "SELECT id, name FROM users WHERE age > 18"
    var query_plan = optimizer.optimize_select(sql, schema_manager, materialized_views)

    print("QueryOptimizer basic test passed - QueryPlan generated successfully")
    print("Operation:", query_plan.operation)
    print("Table:", query_plan.table_name)
    print("Cost:", query_plan.cost)

fn test_materialized_view_rewriting() raises:
    """Test materialized view rewriting functionality."""
    print("Testing materialized view rewriting...")

    var optimizer = QueryOptimizer()

    # Create schema manager and materialized views dict with a relevant view
    var blob_storage = BlobStorage("/tmp/test_db")
    var schema_manager = SchemaManager(blob_storage)
    var materialized_views = Dict[String, String]()
    materialized_views["order_summary"] = "SELECT status, COUNT(*) as count FROM orders GROUP BY status"

    # Test try_rewrite_with_materialized_view method
    var sql = "SELECT COUNT(*) FROM orders WHERE status = 'completed'"
    var rewritten_sql = optimizer.try_rewrite_with_materialized_view(sql, materialized_views)

    print("Original SQL:", sql)
    print("Rewritten SQL:", rewritten_sql)
    print("Materialized view rewriting test passed - method executed without errors")

fn test_query_plan_generation() raises:
    """Test query plan generation."""
    print("Testing query plan generation...")

    var optimizer = QueryOptimizer()

    # Create schema manager and materialized views
    var blob_storage = BlobStorage("/tmp/test_db")
    var schema_manager = SchemaManager(blob_storage)
    var materialized_views = Dict[String, String]()

    # Test optimize_select with complex query
    var sql = "SELECT u.name, COUNT(o.id) FROM users u JOIN orders o ON u.id = o.user_id WHERE u.age > 21 GROUP BY u.name"
    var query_plan = optimizer.optimize_select(sql, schema_manager, materialized_views)

    print("Query plan generation test passed - complex JOIN query optimized successfully")
    print("Operation:", query_plan.operation)
    print("Table:", query_plan.table_name)
    print("Parallel degree:", query_plan.parallel_degree)

fn main() raises:
    """Run all QueryOptimizer tests."""
    print("Running QueryOptimizer functionality tests...")

    test_query_optimizer_basic()
    test_materialized_view_rewriting()
    test_query_plan_generation()

    print("All QueryOptimizer tests completed successfully!")