"""
PL-GRIZZLY Query Optimizer Module

Query optimization and execution planning for PL-GRIZZLY SELECT statements.
"""

from collections import List, Dict
from pl_grizzly_parser import PLGrizzlyParser, PLGrizzlyLexer
from schema_manager import SchemaManager, Index
from pl_grizzly_values import PLValue

# Query execution plan structures
struct QueryPlan(Movable):
    var operation: String  # "scan", "join", "filter", "project", "parallel_scan"
    var table_name: String
    var conditions: Optional[List[String]]
    var cost: Float64
    var parallel_degree: Int  # Number of parallel threads for parallel operations

    fn __init__(out self, operation: String, table_name: String, conditions: Optional[List[String]], cost: Float64, parallel_degree: Int):
        self.operation = operation
        self.table_name = table_name
        self.conditions = conditions
        self.cost = cost
        self.parallel_degree = parallel_degree

    fn copy(self) -> QueryPlan:
        var new_conditions: Optional[List[String]] = None
        if self.conditions:
            new_conditions = self.conditions.value().copy()
        return QueryPlan(self.operation, self.table_name, new_conditions, self.cost, self.parallel_degree)

# Query optimizer
struct QueryOptimizer(Movable):
    # Remove owned materialized_views to avoid compilation loops
    # materialized_views will be passed as parameters to methods

    fn __init__(out self):
        # Empty constructor - no complex object storage
        pass

    fn optimize_select(mut self, select_stmt: String, schema_manager: SchemaManager, materialized_views: Dict[String, String]) raises -> QueryPlan:
        """Create an optimized query execution plan for a SELECT statement."""
        # Check if query can be rewritten to use a materialized view
        var rewritten_query = self.try_rewrite_with_materialized_view(select_stmt, materialized_views)
        var query_to_optimize = select_stmt
        if rewritten_query != select_stmt:
            # Use rewritten query
            query_to_optimize = rewritten_query

        # Parse the SELECT statement
        var lexer = PLGrizzlyLexer(query_to_optimize)
        var tokens = lexer.tokenize()
        var parser = PLGrizzlyParser(tokens)
        var ast = parser.parse()

        # Extract table name and WHERE conditions
        var table_name = self.extract_table_name(query_to_optimize)
        var where_conditions = self.extract_where_conditions(query_to_optimize)

        # Check for available indexes
        var indexes = schema_manager.get_indexes(table_name)

        # Determine best access method
        var best_plan = self.choose_access_method(table_name, where_conditions, indexes)

        # Check if parallel execution would be beneficial
        if self.should_use_parallel(table_name, where_conditions, schema_manager):
            best_plan.parallel_degree = 4  # Use 4 threads for parallel execution
            best_plan.operation = "parallel_scan"

        return best_plan.copy()

    fn try_rewrite_with_materialized_view(self, select_stmt: String, materialized_views: Dict[String, String]) raises -> String:
        """Try to rewrite the query to use a materialized view if beneficial."""
        # Normalize the query for comparison
        var normalized_query = self.normalize_query(select_stmt)

        # Check each materialized view
        for view_name in materialized_views.keys():
            try:
                var view_query = materialized_views[view_name]
                var normalized_view = self.normalize_query(view_query)

                # Simple exact match for now - could be enhanced with more sophisticated matching
                if normalized_query == normalized_view:
                    # Rewrite to use the materialized view
                    return "SELECT * FROM " + view_name
            except:
                continue

        return select_stmt  # No rewrite possible

    fn normalize_query(self, query: String) -> String:
        """Normalize a query for comparison purposes."""
        # Remove extra whitespace and convert to lowercase for comparison
        var normalized = query.replace("  ", " ").strip().lower()
        return normalized

    fn should_use_parallel(self, table_name: String, conditions: List[String], schema_manager: SchemaManager) -> Bool:
        """Determine if parallel execution would be beneficial for this query."""
        # Parallel execution is beneficial for:
        # 1. Tables that exist
        # 2. Simple conditions that can be parallelized

        var schema = schema_manager.load_schema()
        var table = schema.get_table(table_name)
        if table.name == "":
            return False
        # For now, use a simple heuristic: parallelize if table exists and has simple conditions
        return len(conditions) <= 2  # Simple queries with few conditions

    fn extract_table_name(self, select_stmt: String) -> String:
        """Extract table name from SELECT statement."""
        var from_pos = select_stmt.find(" FROM ")
        if from_pos == -1:
            return ""

        var after_from = select_stmt[from_pos + 6:]
        var space_pos = after_from.find(" ")
        if space_pos == -1:
            return String(after_from.strip())
        else:
            return String(after_from[:space_pos].strip())

    fn extract_where_conditions(self, select_stmt: String) -> List[String]:
        """Extract WHERE conditions from SELECT statement."""
        var conditions = List[String]()
        var where_pos = select_stmt.find(" WHERE ")
        if where_pos == -1:
            return conditions.copy()

        var where_clause = select_stmt[where_pos + 7:]
        where_clause = where_clause[:-1]  # Remove closing )

        # Simple condition parsing - split by AND
        var and_conditions = where_clause.split(" AND ")
        for cond in and_conditions:
            conditions.append(String(cond.strip()))

        return conditions.copy().copy()

    fn choose_access_method(self, table_name: String, conditions: List[String], indexes: List[Index]) -> QueryPlan:
        """Choose the best access method based on available indexes."""
        # Check if any conditions can use indexes
        for condition in conditions:
            for index in indexes:
                if self.can_use_index(condition, index):
                    # Create index scan plan
                    var index_conditions = List[String]()
                    index_conditions.append(condition)
                    var plan = QueryPlan(operation="", table_name="", conditions=None, cost=0.0, parallel_degree=1)
                    plan.operation = "index_scan"
                    plan.table_name = table_name
                    plan.conditions = index_conditions.copy()
                    plan.cost = 10.0
                    plan.parallel_degree = 1
                    return plan.copy()

        # Default to table scan
        var plan = QueryPlan(operation="", table_name="", conditions=None, cost=0.0, parallel_degree=1)
        plan.operation = "table_scan"
        plan.table_name = table_name
        plan.conditions = conditions.copy()
        plan.cost = 100.0
        plan.parallel_degree = 1
        return plan.copy()

    fn can_use_index(self, condition: String, index: Index) -> Bool:
        """Check if a condition can use the given index."""
        # Simple check: look for column = value patterns
        for col in index.columns:
            var pattern = col + " = "
            if condition.find(pattern) != -1:
                return True
            var pattern2 = col + "="
            if condition.find(pattern2) != -1:
                return True
        return False