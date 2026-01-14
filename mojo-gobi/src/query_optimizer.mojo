"""
PL-GRIZZLY Query Optimizer Module

Query optimization and execution planning for PL-GRIZZLY SELECT statements.
"""

from collections import List, Dict, Optional
from pl_grizzly_parser import PLGrizzlyParser, PLGrizzlyLexer
from schema_manager import SchemaManager, Index
from pl_grizzly_values import PLValue
from profiling_manager import ProfilingManager
from python import Python, PythonObject

# Query result cache entry
struct CacheEntry(Movable, Copyable):
    var result: String
    var timestamp: Int64
    var access_count: Int

    fn __init__(out self, result: String, timestamp: Int64):
        self.result = result
        self.timestamp = timestamp
        self.access_count = 1

    fn is_expired(self, current_time: Int64, max_age_seconds: Int64) -> Bool:
        return (current_time - self.timestamp) > max_age_seconds

# Query execution plan structures
struct QueryPlan(Movable):
    var operation: String  # "scan", "join", "filter", "project", "parallel_scan", "timeline_scan"
    var table_name: String
    var conditions: Optional[List[String]]
    var cost: Float64
    var parallel_degree: Int  # Number of parallel threads for parallel operations
    var timeline_timestamp: Optional[Int64]  # For time-travel queries
    var cache_key: Optional[String]  # For result caching

    fn __init__(out self, operation: String, table_name: String, conditions: Optional[List[String]], cost: Float64, parallel_degree: Int):
        self.operation = operation
        self.table_name = table_name
        self.conditions = conditions
        self.cost = cost
        self.parallel_degree = parallel_degree
        self.timeline_timestamp = None
        self.cache_key = None

    fn copy(self) -> QueryPlan:
        var new_conditions: Optional[List[String]] = None
        if self.conditions:
            new_conditions = self.conditions.value().copy()
        var plan = QueryPlan(self.operation, self.table_name, new_conditions, self.cost, self.parallel_degree)
        plan.timeline_timestamp = self.timeline_timestamp
        plan.cache_key = self.cache_key
        return plan^

# Query optimizer
struct QueryOptimizer(Movable):
    var result_cache: Dict[String, CacheEntry]
    var cache_max_size: Int
    var cache_max_age_seconds: Int64
    var profiler: ProfilingManager
    var python_time: PythonObject

    fn __init__(out self) raises:
        self.result_cache = Dict[String, CacheEntry]()
        self.cache_max_size = 100  # Maximum cache entries
        self.cache_max_age_seconds = 3600  # 1 hour cache expiry
        self.profiler = ProfilingManager()
        var python_time_mod = Python.import_module("time")
        self.python_time = python_time_mod

    fn check_cache(mut self, cache_key: String, current_time: Int64) raises -> Optional[String]:
        """Check if query result is cached and not expired."""
        var start_time = Float64(self.python_time.time())

        if cache_key in self.result_cache:
            var entry = self.result_cache[cache_key].copy()
            if not entry.is_expired(current_time, self.cache_max_age_seconds):
                entry.access_count += 1
                var lookup_time = Float64(self.python_time.time()) - start_time
                self.profiler.record_cache_hit(lookup_time)
                return entry.result
            else:
                # Remove expired entry
                _ = self.result_cache.pop(cache_key, CacheEntry("", 0))
                var lookup_time = Float64(self.python_time.time()) - start_time
                self.profiler.record_cache_miss(lookup_time)
        else:
            var lookup_time = Float64(self.python_time.time()) - start_time
            self.profiler.record_cache_miss(lookup_time)

        return None

    fn store_in_cache(mut self, cache_key: String, result: String, current_time: Int64) raises:
        """Store query result in cache with LRU eviction if needed."""
        if len(self.result_cache) >= self.cache_max_size:
            self.evict_lru_cache_entry()

        var entry = CacheEntry(result, current_time)
        self.result_cache[cache_key] = entry.copy()

    fn evict_lru_cache_entry(mut self) raises:
        """Evict the least recently used cache entry."""
        var oldest_key = ""
        var oldest_time = Int64.MAX

        # Collect keys first to avoid aliasing issues
        var keys = List[String]()
        for key in self.result_cache.keys():
            keys.append(key)

        for key in keys:
            var entry = self.result_cache[key].copy()
            if entry.timestamp < oldest_time:
                oldest_time = entry.timestamp
                oldest_key = key

        if oldest_key != "":
            _ = self.result_cache.pop(oldest_key, CacheEntry("", 0))
            self.profiler.record_cache_eviction()

    fn optimize_select(mut self, select_stmt: String, schema_manager: SchemaManager, materialized_views: Dict[String, String]) raises -> QueryPlan:
        """Create an optimized query execution plan for a SELECT statement."""
        var start_time = Float64(self.python_time.time())

        # Check if this is a time-travel query
        var since_timestamp = self.extract_since_timestamp(select_stmt)
        var is_timeline_query = since_timestamp != -1

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
        var best_plan = self.choose_access_method(table_name, where_conditions, indexes, schema_manager)

        # Apply comprehensive cost calculation
        best_plan.cost = self.calculate_cost(best_plan, schema_manager)

        # Handle timeline queries with enhanced optimization
        if is_timeline_query:
            best_plan = self.optimize_timeline_query(best_plan, since_timestamp, schema_manager)

        # Check if parallel execution would be beneficial
        if self.should_use_parallel(table_name, where_conditions, schema_manager):
            best_plan = self.optimize_parallel_execution(best_plan, schema_manager)

        # Generate cache key for result caching
        best_plan.cache_key = self.generate_cache_key(select_stmt, table_name, since_timestamp)

        var optimization_time = Float64(self.python_time.time()) - start_time
        self.profiler.record_function_call("optimize_select")

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

    fn can_use_index(self, condition: String, index: Index) -> Bool:
        """Check if a condition can use the given index."""
        # Simple check: see if condition contains any of the indexed columns
        for column in index.columns:
            if condition.find(column) != -1:
                return True
        return False

    fn choose_access_method(self, table_name: String, conditions: List[String], indexes: List[Index], schema_manager: SchemaManager) raises -> QueryPlan:
        """Choose the best access method based on comprehensive cost-based optimization."""
        var best_plan = QueryPlan("table_scan", table_name, conditions.copy(), 100.0, 1)
        var best_cost = 100.0

        # Evaluate table scan option
        var table_scan_plan = QueryPlan("table_scan", table_name, conditions.copy(), 100.0, 1)
        var table_scan_cost = self.calculate_cost(table_scan_plan, schema_manager)
        if table_scan_cost < best_cost:
            best_plan = table_scan_plan.copy()
            best_cost = table_scan_cost

        # Evaluate index scan options
        for condition in conditions:
            for index in indexes:
                if self.can_use_index(condition, index):
                    var index_plan = QueryPlan("index_scan", table_name, List[String](condition), 10.0, 1)
                    var index_cost = self.calculate_cost(index_plan, schema_manager)
                    if index_cost < best_cost:
                        best_plan = index_plan.copy()
                        best_cost = index_cost

        # Evaluate parallel scan option for large tables
        var table_size = self.estimate_table_size(table_name, schema_manager)
        if table_size > 2.0:  # Large table threshold
            var parallel_plan = QueryPlan("parallel_scan", table_name, conditions.copy(), 80.0, 4)
            var parallel_cost = self.calculate_cost(parallel_plan, schema_manager)
            if parallel_cost < best_cost:
                best_plan = parallel_plan.copy()
                best_cost = parallel_cost

        return best_plan.copy()

    fn calculate_cost(self, plan: QueryPlan, schema_manager: SchemaManager) raises -> Float64:
        """Calculate the total cost of a query plan including I/O, CPU, and timeline factors."""
        var base_cost = plan.cost

        # I/O cost factors
        var io_cost = self.calculate_io_cost(plan, schema_manager)

        # CPU cost factors
        var cpu_cost = self.calculate_cpu_cost(plan)

        # Timeline cost factors (for time-travel queries)
        var timeline_cost = self.calculate_timeline_cost(plan)

        # Network/distribution cost (for parallel queries)
        var network_cost = self.calculate_network_cost(plan)

        # Total cost with weighting
        var total_cost = (io_cost * 0.6) + (cpu_cost * 0.2) + (timeline_cost * 0.15) + (network_cost * 0.05)

        return total_cost

    fn calculate_io_cost(self, plan: QueryPlan, schema_manager: SchemaManager) raises -> Float64:
        """Calculate I/O cost based on data access patterns."""
        var io_cost = 1.0

        # Base I/O cost depends on operation type
        if plan.operation == "index_scan":
            io_cost = 0.3  # Index scans are efficient
        elif plan.operation == "table_scan":
            io_cost = 1.0  # Full table scans are expensive
        elif plan.operation == "timeline_scan":
            io_cost = 1.5  # Historical data access is more expensive
        elif plan.operation == "incremental_scan":
            io_cost = 0.2  # Change-based access is very efficient
        elif plan.operation == "parallel_scan":
            io_cost = 0.8  # Parallel scans distribute I/O

        # Adjust based on table size estimate
        var table_size_factor = self.estimate_table_size(plan.table_name, schema_manager)
        io_cost *= table_size_factor

        # Adjust based on selectivity (how much data we actually need)
        var selectivity = self.estimate_selectivity(plan.conditions)
        io_cost *= selectivity

        return io_cost

    fn calculate_cpu_cost(self, plan: QueryPlan) -> Float64:
        """Calculate CPU cost based on computation requirements."""
        var cpu_cost = 1.0

        # CPU cost depends on operation complexity
        if plan.operation == "parallel_scan":
            cpu_cost = 1.2  # Parallel processing has coordination overhead
        elif plan.operation == "timeline_scan":
            cpu_cost = 1.3  # Timeline queries need timestamp filtering
        elif plan.operation == "incremental_scan":
            cpu_cost = 0.8  # Incremental processing is CPU-efficient

        # Adjust based on conditions complexity
        if plan.conditions:
            var condition_count = len(plan.conditions.value())
            cpu_cost *= (1.0 + Float64(condition_count) * 0.1)

        # Adjust based on parallel degree
        if plan.parallel_degree > 1:
            cpu_cost *= (1.0 + Float64(plan.parallel_degree) * 0.05)

        return cpu_cost

    fn calculate_timeline_cost(self, plan: QueryPlan) raises -> Float64:
        """Calculate additional cost for timeline/time-travel queries."""
        var timeline_cost = 1.0

        if plan.timeline_timestamp:
            var timestamp = plan.timeline_timestamp.value()
            var current_time = Int64(self.python_time.time())

            # Cost increases with how far back in time we're going
            var time_diff_hours = Float64(current_time - timestamp) / 3600.0

            if time_diff_hours < 1.0:
                timeline_cost = 1.1  # Recent data (minimal overhead)
            elif time_diff_hours < 24.0:
                timeline_cost = 1.3  # Last day
            elif time_diff_hours < 168.0:  # 1 week
                timeline_cost = 1.6  # Historical data
            else:
                timeline_cost = 2.0  # Very old data (expensive)

        return timeline_cost

    fn calculate_network_cost(self, plan: QueryPlan) -> Float64:
        """Calculate network/distribution cost for parallel queries."""
        var network_cost = 1.0

        if plan.parallel_degree > 1:
            # Network cost increases with parallelism due to coordination
            network_cost = 1.0 + (Float64(plan.parallel_degree) * 0.1)

            # Additional cost for result aggregation
            network_cost *= 1.1

        return network_cost

    fn estimate_table_size(self, table_name: String, schema_manager: SchemaManager) raises -> Float64:
        """Estimate the relative size of a table for cost calculation."""
        try:
            var schema = schema_manager.load_schema()
            var table = schema.get_table(table_name)

            if table.name == "":
                return 1.0  # Default size if table not found

            # Estimate based on column count and types
            var size_factor = 1.0
            for column in table.columns:
                if column.type == "string" or column.type == "text":
                    size_factor *= 1.5  # Strings take more space
                elif column.type == "int64" or column.type == "float64":
                    size_factor *= 1.0  # Numbers are compact

            return size_factor

        except:
            return 1.0  # Default if estimation fails

    fn estimate_selectivity(self, conditions: Optional[List[String]]) -> Float64:
        """Estimate the selectivity of WHERE conditions (0.0 = no rows, 1.0 = all rows)."""
        if not conditions:
            return 1.0  # No conditions = full table scan

        var selectivity = 1.0
        var condition_list = conditions.value().copy()

        for condition in condition_list:
            var condition_selectivity = self.estimate_condition_selectivity(condition)
            selectivity *= condition_selectivity

        # Cap selectivity to prevent unrealistic estimates
        if selectivity < 0.001:
            selectivity = 0.001

        return selectivity

    fn estimate_condition_selectivity(self, condition: String) -> Float64:
        """Estimate selectivity of a single WHERE condition."""
        var lower_condition = condition.lower()

        # Equality conditions are very selective
        if lower_condition.find("=") != -1 and lower_condition.find("!=") == -1:
            return 0.01  # Assume 1% selectivity for equality

        # Range conditions are moderately selective
        elif lower_condition.find(">") != -1 or lower_condition.find("<") != -1:
            return 0.1  # Assume 10% selectivity for ranges

        # LIKE patterns are less selective
        elif lower_condition.find("like") != -1:
            return 0.5  # Assume 50% selectivity for patterns

        # IN conditions depend on list size
        elif lower_condition.find("in") != -1:
            return 0.05  # Assume 5% selectivity for IN lists

        else:
            return 0.3  # Default selectivity for unknown conditions

    fn optimize_timeline_query(mut self, plan: QueryPlan, since_timestamp: Int64, schema_manager: SchemaManager) raises -> QueryPlan:
        """Optimize a query plan for timeline/time-travel operations."""
        var optimized_plan = plan.copy()
        optimized_plan.operation = "timeline_scan"
        optimized_plan.timeline_timestamp = since_timestamp

        # Apply timeline-specific cost adjustments
        optimized_plan.cost = self.calculate_cost(optimized_plan, schema_manager)

        # Consider using incremental processing for recent timeline queries
        var current_time = Int64(self.python_time.time())
        var time_diff_hours = Float64(current_time - since_timestamp) / 3600.0

        if time_diff_hours < 24.0:  # Within last day
            # Check if we can use change-based incremental processing
            var can_use_incremental = self._can_use_incremental_processing_for_timeline(plan.table_name, schema_manager)
            if can_use_incremental:
                optimized_plan.operation = "incremental_timeline_scan"
                optimized_plan.cost *= 0.4  # Significant cost reduction
                print("✓ Timeline query optimized with incremental processing")

        return optimized_plan.copy()

    fn optimize_parallel_execution(mut self, plan: QueryPlan, schema_manager: SchemaManager) raises -> QueryPlan:
        """Optimize a query plan for parallel execution."""
        var optimized_plan = plan.copy()

        # Determine optimal parallel degree based on table size and query complexity
        var table_size = self.estimate_table_size(plan.table_name, schema_manager)
        var condition_complexity = Float64(len(plan.conditions.value())) if plan.conditions else 0.0

        var optimal_degree = 1
        if table_size > 3.0 and condition_complexity < 3.0:
            optimal_degree = 4  # Large table, simple conditions
        elif table_size > 1.5:
            optimal_degree = 2  # Medium table
        else:
            optimal_degree = 1  # Small table, not worth parallelizing

        if optimal_degree > 1:
            optimized_plan.parallel_degree = optimal_degree
            optimized_plan.operation = "parallel_scan"
            optimized_plan.cost = self.calculate_cost(optimized_plan, schema_manager)

        return optimized_plan.copy()

    fn _can_use_incremental_processing_for_timeline(self, table_name: String, schema_manager: SchemaManager) -> Bool:
        """Check if incremental processing can be used for timeline queries."""
        try:
            var schema = schema_manager.load_schema()
            var table = schema.get_table(table_name)

            # Incremental processing works best with tables that have change tracking
            return table.name != ""  # For now, assume all valid tables support it

        except:
            return False

    fn extract_since_timestamp(self, select_stmt: String) raises -> Int64:
        """Extract SINCE timestamp from SELECT statement. Returns -1 if no SINCE clause found."""
        var since_pos = select_stmt.find(" SINCE ")
        if since_pos == -1:
            return -1

        var after_since = select_stmt[since_pos + 7:]
        var space_pos = after_since.find(" ")
        if space_pos == -1:
            # SINCE at end of query
            return Int64(after_since.strip())
        else:
            # Extract timestamp before next keyword
            var timestamp_str = after_since[:space_pos].strip()
            return Int64(timestamp_str)

    fn generate_cache_key(self, query: String, table_name: String, since_timestamp: Int64) -> String:
        """Generate a cache key for query result caching."""
        var key = table_name + "_" + String(since_timestamp) + "_" + query.replace(" ", "_").replace("(", "").replace(")", "")
        return key

    fn optimize_incremental_query_advanced(mut self, base_query: String, changes: List[String], watermark: Int64, schema_manager: SchemaManager) raises -> QueryPlan:
        """Advanced incremental query optimization with change analysis."""
        print("🔄 Advanced incremental optimization for", String(len(changes)), "changes")

        # Analyze change patterns
        var change_analysis = self.analyze_change_patterns(changes)

        # Create optimized plan based on change analysis
        var plan = QueryPlan("incremental_scan", "unknown", None, 1.0, 1)

        # Extract table name
        var table_name_opt = self._extract_table_from_query(base_query)
        if table_name_opt:
            plan.table_name = table_name_opt.value()

            # Optimize based on change characteristics
            if change_analysis["change_type"] == "point_updates":
                plan.operation = "delta_merge_scan"
                plan.cost = Float64(len(changes)) * 0.05  # Very efficient for point updates
            elif change_analysis["change_type"] == "range_updates":
                plan.operation = "range_incremental_scan"
                plan.cost = Float64(len(changes)) * 0.15  # Moderately efficient
            else:
                plan.operation = "full_incremental_scan"
                plan.cost = Float64(len(changes)) * 0.25  # General incremental

            # Adjust parallelism based on change volume
            if len(changes) > 1000:
                plan.parallel_degree = 4
                plan.cost *= 0.9  # Parallel processing reduces cost

        plan.timeline_timestamp = watermark
        plan.cache_key = "adv_incremental_" + String(watermark) + "_" + base_query.replace(" ", "_")

        print("✓ Advanced incremental plan created with cost:", String(plan.cost))
        return plan.copy()

    fn analyze_change_patterns(self, changes: List[String]) -> Dict[String, String]:
        """Analyze patterns in change data for optimization opportunities."""
        var analysis = Dict[String, String]()

        if len(changes) == 0:
            analysis["change_type"] = "no_changes"
            return analysis.copy()

        # Analyze change types
        var insert_count = 0
        var update_count = 0
        var delete_count = 0
        var range_updates = 0

        for change in changes:
            var lower_change = change.lower()
            if lower_change.find("insert") != -1:
                insert_count += 1
            elif lower_change.find("update") != -1:
                update_count += 1
            elif lower_change.find("delete") != -1:
                delete_count += 1

            # Check for range patterns
            if lower_change.find(">") != -1 or lower_change.find("<") != -1 or lower_change.find("between") != -1:
                range_updates += 1

        # Determine dominant pattern
        var total_changes = len(changes)
        if Float64(update_count) / Float64(total_changes) > 0.8:
            analysis["change_type"] = "point_updates"
        elif range_updates > Int(total_changes / 2):
            analysis["change_type"] = "range_updates"
        else:
            analysis["change_type"] = "mixed_changes"

        analysis["insert_ratio"] = String(Float64(insert_count) / Float64(total_changes))
        analysis["update_ratio"] = String(Float64(update_count) / Float64(total_changes))
        analysis["delete_ratio"] = String(Float64(delete_count) / Float64(total_changes))

        return analysis.copy()

    fn optimize_aggregation_query(mut self, query: String, schema_manager: SchemaManager) raises -> QueryPlan:
        """Optimize aggregation queries with specialized execution strategies."""
        print("📊 Optimizing aggregation query")

        var plan = self.optimize_select(query, schema_manager, Dict[String, String]())

        # Check if this is an aggregation query
        var lower_query = query.lower()
        var is_aggregation = lower_query.find("count(") != -1 or lower_query.find("sum(") != -1 or
                           lower_query.find("avg(") != -1 or lower_query.find("min(") != -1 or
                           lower_query.find("max(") != -1 or lower_query.find("group by") != -1

        if is_aggregation:
            plan.operation = "aggregation_scan"

            # Aggregation queries can benefit from different strategies
            if lower_query.find("group by") != -1:
                plan.cost *= 1.5  # Grouping is expensive
                plan.parallel_degree = 4  # Parallel aggregation helps
            else:
                plan.cost *= 0.8  # Simple aggregations are efficient

            print("✓ Aggregation query optimized")

        return plan.copy()

    fn warm_cache(mut self, queries: List[String], schema_manager: SchemaManager, materialized_views: Dict[String, String]) raises:
        """Pre-populate cache with frequently used queries."""
        print("🔥 Warming query cache with", String(len(queries)), "queries")

        for query in queries:
            try:
                var plan = self.optimize_select(query, schema_manager, materialized_views)
                var cache_key = plan.cache_key

                if cache_key:
                    # Simulate query execution and cache result
                    var mock_result = "CACHED_RESULT_FOR_" + query.replace(" ", "_")
                    var current_time = Int64(self.python_time.time())
                    self.store_in_cache(cache_key.value(), mock_result, current_time)
                    print("✓ Warmed cache for query:", query[:50] + "...")

            except:
                print("⚠️  Failed to warm cache for query:", query[:50] + "...")
                continue

        print("✓ Cache warming completed")

    fn predict_and_cache(mut self, recent_queries: List[String], schema_manager: SchemaManager, materialized_views: Dict[String, String]) raises:
        """Predict and cache likely future queries based on patterns."""
        print("🔮 Predicting and caching future queries")

        var predictions = List[String]()

        # Simple prediction: generate variations of recent queries
        for query in recent_queries:
            # Predict time-based variations
            if query.find("SINCE") == -1:
                var current_time = Int64(self.python_time.time())
                var recent_time = current_time - 3600  # 1 hour ago
                var predicted_query = query + " SINCE " + String(recent_time)
                predictions.append(predicted_query)

            # Predict aggregation variations
            if query.find("COUNT(") == -1 and query.find("SUM(") == -1:
                var predicted_query = query.replace("SELECT ", "SELECT COUNT(*), ")
                predictions.append(predicted_query)

        # Cache predictions
        for predicted_query in predictions:
            try:
                var plan = self.optimize_select(predicted_query, schema_manager, materialized_views)
                if plan.cache_key:
                    var mock_result = "PREDICTED_RESULT_FOR_" + predicted_query.replace(" ", "_")
                    var current_time = Int64(self.python_time.time())
                    self.store_in_cache(plan.cache_key.value(), mock_result, current_time)
            except:
                continue

        print("✓ Predictive caching completed with", String(len(predictions)), "predictions")

    fn get_cache_effectiveness(self) raises -> Dict[String, String]:
        """Calculate cache effectiveness metrics."""
        var metrics = Dict[String, String]()

        var total_entries = len(self.result_cache)
        var total_accesses = 0
        var expired_entries = 0
        var current_time = Int64(self.python_time.time())

        for key in self.result_cache.keys():
            var entry = self.result_cache[key].copy()
            total_accesses += entry.access_count

            if entry.is_expired(current_time, self.cache_max_age_seconds):
                expired_entries += 1

        var hit_rate = 0.0
        if total_accesses > 0:
            # Estimate hit rate (simplified - would need actual miss tracking)
            hit_rate = Float64(total_accesses) / Float64(total_entries + expired_entries) * 100.0

        metrics["total_cache_entries"] = String(total_entries)
        metrics["expired_entries"] = String(expired_entries)
        metrics["total_accesses"] = String(total_accesses)
        metrics["estimated_hit_rate_percent"] = String(hit_rate)
        metrics["cache_utilization_percent"] = String(Float64(total_entries) / Float64(self.cache_max_size) * 100.0)

        return metrics.copy()

    # fn get_profiler(self) -> ProfilingManager:
    #     """Get the profiling manager for performance metrics."""
    #     return self.profiler.copy()

    fn generate_performance_report(self) raises -> String:
        """Generate a comprehensive performance report for the query optimizer."""
        var report = String("=== Query Optimizer Performance Report ===\n\n")

        # Cache statistics
        var cache_stats = self.get_cache_effectiveness()
        var cache_effectiveness = self.get_cache_effectiveness()

        report += "Cache Statistics:\n"
        var cache_keys = List[String]()
        for key in cache_stats.keys():
            cache_keys.append(key)
        for key in cache_keys:
            var value = cache_stats[key]
            report += "  " + key + ": " + value + "\n"

        report += "\nCache Effectiveness:\n"
        var effectiveness_keys = List[String]()
        for key in cache_effectiveness.keys():
            effectiveness_keys.append(key)
        for key in effectiveness_keys:
            var value = cache_effectiveness[key]
            report += "  " + key + ": " + value + "\n"
        report += "\n"

        # Profiler report
        report += self.profiler.generate_performance_report()

        return report

    # Incremental Query Optimization Methods
    fn optimize_incremental_query(mut self, query: String, watermark: Int64, schema_manager: SchemaManager) raises -> QueryPlan:
        """Optimize a query for incremental execution using watermark-based change detection."""
        print("🔄 Optimizing incremental query with watermark:", String(watermark))

        # Parse the query
        var lexer = PLGrizzlyLexer(query)
        var tokens = lexer.tokenize()
        var parser = PLGrizzlyParser(tokens)
        var ast = parser.parse()

        # Create incremental plan
        var plan = QueryPlan("incremental_scan", "unknown", None, 1.0, 1)
        var cache_key_str = "incremental_" + String(watermark) + "_" + query
        plan.cache_key = cache_key_str

        # Analyze query for incremental optimization opportunities
        var table_name = self._extract_table_from_query(query)
        if table_name:
            plan.table_name = table_name.value()

            # Check if we can use change-based incremental processing
            var can_incremental = self._can_use_incremental_processing(query, schema_manager)
            if can_incremental:
                plan.operation = "incremental_scan"
                plan.cost = plan.cost * 0.3  # 70% cost reduction for incremental
                print("✓ Query optimized for incremental processing")
            else:
                plan.operation = "full_scan"
                print("ℹ️  Query requires full scan (cannot be incremental)")
        else:
            print("⚠️  Could not extract table name from query")

        return plan^

    fn _extract_table_from_query(self, query: String) -> Optional[String]:
        """Extract table name from a SELECT query."""
        var lower_query = query.lower()
        var from_pos = lower_query.find("from")

        if from_pos == -1:
            return None

        var from_clause = query[from_pos + 4:].strip()
        var table_name = ""

        # Extract table name until whitespace or end
        for i in range(len(from_clause)):
            var char = from_clause[i]
            if char == " " or char == "\t" or char == "\n" or char == ";" or char == "w":
                break
            table_name += char

        return Optional(table_name)

    fn _can_use_incremental_processing(self, query: String, schema_manager: SchemaManager) -> Bool:
        """Determine if a query can benefit from incremental processing."""
        var lower_query = query.lower()

        # Simple heuristics for incremental processing:
        # 1. Must be a SELECT query
        if not lower_query.startswith("select"):
            return False

        # 2. Should not have complex aggregations (for now)
        if lower_query.find("count(") != -1 or lower_query.find("sum(") != -1 or lower_query.find("avg(") != -1:
            return False

        # 3. Should not have complex joins (for now)
        if lower_query.find("join") != -1:
            return False

        # 4. Should not have subqueries
        if lower_query.find("(") != -1 and lower_query.find("select") != -1:
            # Check if it's a subquery (contains another select)
            var select_count = 0
            var pos = 0
            while pos != -1:
                pos = lower_query.find("select", pos + 1)
                if pos != -1:
                    select_count += 1

            if select_count > 1:
                return False

        # If passes all checks, can potentially use incremental processing
        return True

    fn get_incremental_query_plan(mut self, base_query: String, changes: List[String], watermark: Int64) raises -> QueryPlan:
        """Create an optimized query plan for processing incremental changes."""
        print("🔄 Creating incremental query plan for", String(len(changes)), "changes")

        # Create a plan that focuses on processing only changed data
        var plan = QueryPlan("change_processing", "changes", None, 0.1, 1)
        plan.cache_key = "changes_" + String(watermark)

        # Estimate cost based on number of changes
        plan.cost = Float64(len(changes)) * 0.01  # Very low cost for change processing

        # Add change-specific metadata
        plan.timeline_timestamp = watermark

        print("✓ Created incremental change processing plan")
        return plan^

    fn enable_profiling(mut self):
        """Enable performance profiling."""
        self.profiler.enable_profiling()

    fn disable_profiling(mut self):
        """Disable performance profiling."""
        self.profiler.disable_profiling()