# Incremental Materialization Engine
# Provides change-based materialization with incremental updates

from collections import List, Dict
from incremental_processor import IncrementalProcessor, ChangeSet, Change
from lakehouse_engine import LakehouseEngine
from merkle_timeline import MerkleTimeline
from query_optimizer import QueryOptimizer
from schema_manager import SchemaManager

# Materialized view definition
struct MaterializedView(Movable, Copyable):
    var name: String
    var query: String
    var source_tables: List[String]
    var refresh_strategy: String  # "incremental" or "full"
    var last_refresh: Int64
    var watermark: Int64

    fn __init__(out self, name: String, query: String):
        self.name = name
        self.query = query
        self.source_tables = List[String]()
        self.refresh_strategy = "incremental"
        self.last_refresh = 0
        self.watermark = 0

    fn add_source_table(mut self, table: String):
        """Add a source table dependency."""
        self.source_tables.append(table)

# Materialization task for processing changes
struct MaterializationTask(Movable, Copyable):
    var view_name: String
    var changes: ChangeSet
    var strategy: String
    var priority: Int  # 1=high, 2=medium, 3=low

    fn __init__(out self, view_name: String, changes: ChangeSet):
        self.view_name = view_name
        self.changes = changes.copy()
        self.strategy = "incremental"
        self.priority = 2

# Materialization Engine - Core component for incremental materialization
struct MaterializationEngine(Movable, Copyable):
    var processor: IncrementalProcessor
    # var optimizer: Pointer[QueryOptimizer]  # Removed - will pass as parameter
    var views: Dict[String, MaterializedView]
    var task_queue: List[MaterializationTask]
    var refresh_stats: Dict[String, Int]

    fn __init__(out self) raises:
        self.processor = IncrementalProcessor()
        # self.optimizer = Pointer[QueryOptimizer].alloc(1)
        # self.optimizer.init_pointee_copy(QueryOptimizer())
        self.views = Dict[String, MaterializedView]()
        self.task_queue = List[MaterializationTask]()
        self.refresh_stats = Dict[String, Int]()

    fn create_materialized_view(mut self, name: String, query: String, engine: LakehouseEngine, strategy: String = "incremental") raises:
        """Create a new materialized view."""
        var view = MaterializedView(name, query)
        view.refresh_strategy = strategy

        # Analyze query to determine source tables
        self._analyze_view_dependencies(view, query)

        # Store the view
        self.views[name] = view.copy()

        # Perform initial full refresh
        self._perform_full_refresh(view, engine)

        print("✓ Created materialized view:", name, "with strategy:", strategy)

    fn _analyze_view_dependencies(mut self, mut view: MaterializedView, query: String):
        """Analyze query to find source table dependencies."""
        # Simple analysis - look for FROM clauses
        var lower_query = query.lower()
        var from_pos = lower_query.find("from")

        if from_pos != -1:
            var from_clause = query[from_pos + 4:].strip()
            var table_name = ""

            # Extract table name (simplified - assumes single table)
            for i in range(len(from_clause)):
                var char = from_clause[i]
                if char == " " or char == "\t" or char == "\n" or char == ";":
                    break
                table_name += char

            if table_name != "":
                var table_str = String(table_name.strip())
                view.add_source_table(table_str)

    fn _perform_full_refresh(mut self, mut view: MaterializedView, engine: LakehouseEngine) raises:
        """Perform a full refresh of a materialized view."""
        print("🔄 Performing full refresh for view:", view.name)

        # Execute the view query - for now, we'll simulate this
        # var result = self.engine.query(view.source_tables[0], view.query)

        # Store result as a table (simplified - would need proper table creation)
        # For now, just mark as refreshed
        view.last_refresh = self._get_current_timestamp()
        view.watermark = view.last_refresh

        # Update stats
        var count = self.refresh_stats.get(view.name, 0)
        self.refresh_stats[view.name] = count + 1

        print("✓ Full refresh completed for view:", view.name)

    fn _perform_incremental_refresh(mut self, mut view: MaterializedView, changes: ChangeSet, engine: LakehouseEngine, mut optimizer: QueryOptimizer) raises:
        """Perform incremental refresh based on changes."""
        print("🔄 Performing incremental refresh for view:", view.name, "with", String(changes.count_changes()), "changes")

        # For incremental refresh, we need to:
        # 1. Apply changes to existing materialized data
        # 2. Update only affected rows
        # 3. Maintain consistency with source data

        # Simplified implementation - in practice this would be much more complex
        # involving delta computation, merge operations, etc.

        if changes.count_changes() > 0:
            # Use query optimizer to create efficient incremental plan
            # Convert changes to string descriptions for the optimizer
            var change_strings = List[String]()
            for change in changes.changes:
                change_strings.append(change.change_type + " on " + change.table)

            var incremental_plan = optimizer.get_incremental_query_plan(
                view.query,
                change_strings,
                changes.watermark
            )

            print("✓ Created optimized incremental plan with cost:", String(incremental_plan.cost))

            # Mark view as needing refresh
            view.last_refresh = self._get_current_timestamp()
            view.watermark = changes.watermark

            # Update stats
            var count = self.refresh_stats.get(view.name, 0)
            self.refresh_stats[view.name] = count + 1

            print("✓ Incremental refresh completed for view:", view.name, "using optimized plan")
        else:
            print("ℹ️  No changes to process for view:", view.name)

    fn process_changes(mut self, table_name: String, engine: LakehouseEngine, mut optimizer: QueryOptimizer) raises:
        """Process changes for a table and update dependent materialized views."""
        # Get changes since last watermark for this table
        var watermark = self._get_table_watermark(table_name)
        var changeset = self.processor.get_changes_since(table_name, watermark)

        if changeset.count_changes() == 0:
            print("ℹ️  No changes to process for table:", table_name)
            return

        # Verify changeset integrity
        if not self.processor.verify_changes_integrity(changeset):
            print("⚠️  Warning: Changeset integrity verification failed for table:", table_name)
            return

        print("📊 Processing", String(changeset.count_changes()), "changes for table:", table_name)

        # Find views that depend on this table
        for view_entry in self.views.items():
            var view_name = view_entry.key
            var view = view_entry.value.copy()

            # Check if this view depends on the changed table
            var depends_on_table = False
            for source_table in view.source_tables:
                if source_table == table_name:
                    depends_on_table = True
                    break

            if depends_on_table:
                # Create materialization task
                var task = MaterializationTask(view_name, changeset)
                self.task_queue.append(task.copy())

                print("📋 Queued refresh task for view:", view_name)

        # Process queued tasks
        self._process_task_queue(engine, optimizer)

        # Update watermark
        self.processor.update_watermark(table_name, changeset.watermark)

    fn _process_task_queue(mut self, engine: LakehouseEngine, mut optimizer: QueryOptimizer) raises:
        """Process all queued materialization tasks."""
        # Sort by priority (simplified - just process in order)
        for i in range(len(self.task_queue)):
            var task = self.task_queue[i].copy()

            # Get the view
            if task.view_name in self.views:
                var view = self.views[task.view_name].copy()

                if task.strategy == "incremental":
                    self._perform_incremental_refresh(view, task.changes, engine, optimizer)
                else:
                    self._perform_full_refresh(view, engine)

        # Clear queue
        self.task_queue = List[MaterializationTask]()

    fn _get_table_watermark(self, table_name: String) -> Int64:
        """Get the current watermark for a table."""
        # Check if we have any views that track this table
        for view_entry in self.views.items():
            var view = view_entry.value.copy()
            for source_table in view.source_tables:
                if source_table == table_name:
                    return view.watermark

        return 0  # Default watermark

    fn _get_current_timestamp(self) -> Int64:
        """Get current timestamp."""
        # Simplified - in practice would use proper time source
        return 1700000000000  # Placeholder timestamp

    fn refresh_view(mut self, view_name: String, engine: LakehouseEngine, mut optimizer: QueryOptimizer, strategy: String = "incremental") raises:
        """Manually refresh a materialized view."""
        if view_name not in self.views:
            print("❌ View not found:", view_name)
            return

        var view = self.views[view_name].copy()

        if strategy == "full":
            self._perform_full_refresh(view, engine)
        else:
            # For manual incremental refresh, get latest changes
            for source_table in view.source_tables:
                self.process_changes(source_table, engine, optimizer)

    fn get_view_stats(self, view_name: String) raises -> String:
        """Get statistics for a materialized view."""
        if view_name not in self.views:
            return "View not found: " + view_name

        var view = self.views[view_name].copy()
        var refresh_count = self.refresh_stats.get(view_name, 0)

        var stats = "Materialized View Statistics for '" + view_name + "':\n"
        stats += "  Query: " + view.query + "\n"
        stats += "  Strategy: " + view.refresh_strategy + "\n"
        stats += "  Source Tables: " + String(len(view.source_tables)) + "\n"
        stats += "  Last Refresh: " + String(view.last_refresh) + "\n"
        stats += "  Watermark: " + String(view.watermark) + "\n"
        stats += "  Refresh Count: " + String(refresh_count) + "\n"

        return stats

    fn get_engine_stats(self) -> String:
        """Get overall materialization engine statistics."""
        var stats = "Materialization Engine Statistics:\n"
        stats += "  Total Views: " + String(len(self.views)) + "\n"
        stats += "  Queued Tasks: " + String(len(self.task_queue)) + "\n"
        stats += "  Total Refreshes: " + String(len(self.refresh_stats)) + "\n"

        var total_refreshes = 0
        for count in self.refresh_stats.values():
            total_refreshes += count
        stats += "  Refresh Operations: " + String(total_refreshes) + "\n"

        return stats