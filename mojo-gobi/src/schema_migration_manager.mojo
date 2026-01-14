"""
Schema Migration Utilities for PL-Grizzly Lakehouse

This module provides utilities for migrating data when schema changes occur,
ensuring backward compatibility and data integrity during schema evolution.
"""

from collections import Dict, List
from time import time
from json import json
from python import Python
from pathlib import Path
from typing import Any, Optional

from .schema_evolution_manager import SchemaEvolutionManager, SchemaChange, SchemaVersion
from .schema_manager import SchemaManager, ColumnDef
from .orc_storage import ORCStorage
from .merkle_timeline import MerkleTimeline


struct MigrationTask(Movable, Copyable):
    """Represents a data migration task for schema changes."""
    var table_name: String
    var old_schema_version: Int
    var new_schema_version: Int
    var changes: List[SchemaChange]
    var data_files: List[String]
    var status: String  # "pending", "running", "completed", "failed"
    var error_message: String
    var created_at: Int
    var completed_at: Int

    fn __init__(out self,
        table_name: String,
        old_schema_version: Int,
        new_schema_version: Int,
        changes: List[SchemaChange],
        data_files: List[String]
    ):
        self.table_name = table_name
        self.old_schema_version = old_schema_version
        self.new_schema_version = new_schema_version
        self.changes = changes
        self.data_files = data_files
        self.status = "pending"
        self.error_message = ""
        self.created_at = int(time())
        self.completed_at = 0


struct SchemaMigrationManager(Movable):
    """Manages data migration tasks for schema evolution."""

    var schema_evolution: SchemaEvolutionManager
    var schema_manager: SchemaManager
    var storage: ORCStorage
    var timeline: MerkleTimeline
    var migration_tasks: List[MigrationTask]
    var migration_dir: String

    fn __init__(out self,
        var schema_evolution: SchemaEvolutionManager,
        var schema_manager: SchemaManager,
        var storage: ORCStorage,
        var timeline: MerkleTimeline,
        migration_dir: String = "migrations"
    ) raises:
        self.schema_evolution = schema_evolution ^
        self.schema_manager = schema_manager ^
        self.storage = storage ^
        self.timeline = timeline ^
        self.migration_tasks = List[MigrationTask]()
        self.migration_dir = migration_dir

        # Create migration directory if it doesn't exist
        var os = Python.import_module("os")
        if not os.path.exists(migration_dir):
            os.makedirs(migration_dir)

    fn create_migration_task(
        mut self,
        table_name: String,
        old_version: Int,
        new_version: Int
    ) raises -> MigrationTask:
        """Create a migration task for schema changes between versions."""
        var changes = self.schema_evolution.get_changes_between_versions(old_version, new_version)
        var data_files = self._get_data_files_for_table(table_name, old_version)

        var task = MigrationTask(table_name, old_version, new_version, changes, data_files)
        self.migration_tasks.append(task)

        print("Created migration task for table", table_name, "from v" + String(old_version) + " to v" + String(new_version))
        return task

    fn execute_migration(mut self, task_index: Int) raises -> Bool:
        """Execute a migration task."""
        if task_index >= len(self.migration_tasks):
            print("Invalid migration task index")
            return False

        var task = self.migration_tasks[task_index]
        task.status = "running"

        try:
            # Check if migration is needed
            if not self._requires_data_migration(task.changes):
                print("No data migration required for task", task_index)
                task.status = "completed"
                task.completed_at = int(time())
                return True

            # Execute migration
            var success = self._migrate_table_data(task)
            if success:
                task.status = "completed"
                task.completed_at = int(time())
                print("Migration completed successfully for task", task_index)
            else:
                task.status = "failed"
                task.error_message = "Migration failed"
                print("Migration failed for task", task_index)

            return success

        except e:
            task.status = "failed"
            task.error_message = String(e)
            print("Migration error:", String(e))
            return False

    fn _requires_data_migration(self, changes: List[SchemaChange]) -> Bool:
        """Check if the schema changes require data migration."""
        for change in changes:
            if change.change_type == "drop_column":
                return True  # Dropping columns requires data transformation
            elif change.change_type == "add_column" and not change.nullable:
                return True  # Adding non-nullable columns requires default values
            elif change.change_type == "modify_column":
                return True  # Column type changes require data transformation
        return False

    fn _migrate_table_data(mut self, task: MigrationTask) raises -> Bool:
        """Migrate table data for schema changes."""
        var old_schema = self.schema_evolution.get_schema_at_version(task.table_name, task.old_schema_version)
        var new_schema = self.schema_evolution.get_schema_at_version(task.table_name, task.new_schema_version)

        if not old_schema or not new_schema:
            print("Could not retrieve schemas for migration")
            return False

        # Process each data file
        for file_path in task.data_files:
            var success = self._migrate_data_file(file_path, old_schema.value(), new_schema.value(), task.changes)
            if not success:
                return False

        return True

    fn _migrate_data_file(
        self,
        file_path: String,
        old_schema: Dict[String, ColumnDef],
        new_schema: Dict[String, ColumnDef],
        changes: List[SchemaChange]
    ) raises -> Bool:
        """Migrate a single data file."""
        # Read existing data
        var data = self.storage.read_table_data(file_path)
        if not data:
            return True  # Empty file, nothing to migrate

        # Transform data according to schema changes
        var transformed_data = self._transform_data(data.value(), old_schema, new_schema, changes)

        # Write transformed data to new file
        var new_file_path = file_path + ".migrated"
        var success = self.storage.write_table_data(new_file_path, transformed_data)

        if success:
            # Replace original file with migrated file
            # In a real implementation, you'd want atomic file replacement
            print("Migrated data file:", file_path, "->", new_file_path)

        return success

    fn _transform_data(
        self,
        data: List[Dict[String, Any]],
        old_schema: Dict[String, ColumnDef],
        new_schema: Dict[String, ColumnDef],
        changes: List[SchemaChange]
    ) -> List[Dict[String, Any]]:
        """Transform data rows according to schema changes."""
        var transformed_data = List[Dict[String, Any]]()

        for row in data:
            var new_row = Dict[String, Any]()

            # Copy existing columns, applying transformations
            for col_name in new_schema.keys():
                if col_name in row:
                    # Column exists in both schemas
                    new_row[col_name] = row[col_name]
                elif self._is_added_column(col_name, changes):
                    # New column added
                    var change = self._get_column_change(col_name, changes)
                    if change and change.default_value:
                        new_row[col_name] = change.default_value.value()
                    else:
                        new_row[col_name] = None  # or appropriate default
                # Dropped columns are simply not copied

            transformed_data.append(new_row)

        return transformed_data

    fn _is_added_column(self, column_name: String, changes: List[SchemaChange]) -> Bool:
        """Check if a column was added in the changes."""
        for change in changes:
            if change.change_type == "add_column" and change.column_name == column_name:
                return True
        return False

    fn _get_column_change(self, column_name: String, changes: List[SchemaChange]) -> Optional[SchemaChange]:
        """Get the change for a specific column."""
        for change in changes:
            if change.column_name == column_name:
                return change
        return None

    fn _get_data_files_for_table(self, table_name: String, version: Int) -> List[String]:
        """Get data files for a table at a specific schema version."""
        # This would query the timeline to find data files for the table at the given version
        # For now, return a placeholder
        var files = List[String]()
        files.append(table_name + "_data.orc")
        return files.copy()

    fn get_migration_status(self) -> List[String]:
        """Get status of all migration tasks."""
        var status_list = List[String]()
        for i in range(len(self.migration_tasks)):
            var task = self.migration_tasks[i]
            var status = "Task " + String(i) + ": " + task.table_name + " (" + task.status + ")"
            if task.status == "failed":
                status += " - Error: " + task.error_message
            status_list.append(status)
        return status_list.copy()

    fn rollback_migration(mut self, task_index: Int) raises -> Bool:
        """Rollback a completed migration."""
        if task_index >= len(self.migration_tasks):
            print("Invalid migration task index")
            return False

        var task = self.migration_tasks[task_index]
        if task.status != "completed":
            print("Cannot rollback incomplete migration")
            return False

        # Implementation would restore original files from backup
        print("Migration rollback not yet implemented")
        return False