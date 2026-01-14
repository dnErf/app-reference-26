"""
Schema Evolution Manager
========================

Handles schema evolution, version tracking, and backward-compatible changes
for the Godi lakehouse database.
"""

from collections import List, Dict
from python import Python, PythonObject
from blob_storage import BlobStorage
from schema_manager import SchemaManager, DatabaseSchema, TableSchema, Column, Index
from merkle_timeline import MerkleTimeline

# Schema change types
alias ADD_COLUMN = 1
alias DROP_COLUMN = 2
alias MODIFY_COLUMN = 3
alias ADD_INDEX = 4
alias DROP_INDEX = 5

struct SchemaChange(Movable, Copyable):
    """Represents a single schema change."""
    var change_type: Int
    var table_name: String
    var timestamp: Int64
    var details: Dict[String, String]  # Change-specific details

    fn __init__(out self, change_type: Int, table_name: String, timestamp: Int64):
        self.change_type = change_type
        self.table_name = table_name
        self.timestamp = timestamp
        self.details = Dict[String, String]()

    fn __copyinit__(out self, other: Self):
        self.change_type = other.change_type
        self.table_name = other.table_name
        self.timestamp = other.timestamp
        self.details = other.details.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.change_type = existing.change_type
        self.table_name = existing.table_name^
        self.timestamp = existing.timestamp
        self.details = existing.details^

    fn set_detail(mut self, key: String, value: String):
        """Set a change detail."""
        self.details[key] = value

    fn get_detail(self, key: String) -> String:
        """Get a change detail."""
        return self.details.get(key, "")

struct SchemaVersion(Movable, Copyable):
    """Represents a schema version with its changes."""
    var version: Int
    var timestamp: Int64
    var changes: List[SchemaChange]
    var previous_version: Int

    fn __init__(out self, version: Int, timestamp: Int64, previous_version: Int = -1):
        self.version = version
        self.timestamp = timestamp
        self.changes = List[SchemaChange]()
        self.previous_version = previous_version

    fn __copyinit__(out self, other: Self):
        self.version = other.version
        self.timestamp = other.timestamp
        self.changes = other.changes.copy()
        self.previous_version = other.previous_version

    fn __moveinit__(out self, deinit existing: Self):
        self.version = existing.version
        self.timestamp = existing.timestamp
        self.changes = existing.changes^
        self.previous_version = existing.previous_version

    fn add_change(mut self, change: SchemaChange):
        """Add a schema change to this version."""
        self.changes.append(change.copy())

struct SchemaEvolutionManager(Movable):
    """Manages schema evolution with version tracking and compatibility."""
    var schema_manager: SchemaManager
    var timeline: MerkleTimeline
    var current_version: Int
    var schema_versions: Dict[Int, SchemaVersion]
    var schema_versions_path: String

    fn __init__(out self, var schema_manager: SchemaManager, var timeline: MerkleTimeline) raises:
        self.schema_manager = schema_manager^
        self.timeline = timeline^
        self.current_version = 0
        self.schema_versions = Dict[Int, SchemaVersion]()
        self.schema_versions_path = "schema/versions.pkl"

        # Load existing schema versions
        self._load_schema_versions()

    fn _load_schema_versions(mut self) raises:
        """Load schema versions from storage."""
        try:
            var data = self.schema_manager.storage.read_blob(self.schema_versions_path)
            if len(data) > 0:
                var pickle_module = Python.import_module("pickle")
                var py_data = pickle_module.loads(data)

                self.current_version = Int(py_data["current_version"])

                var versions_dict = py_data["versions"]
                for version_key in versions_dict:
                    var version_data = versions_dict[version_key]
                    var version = SchemaVersion(
                        Int(version_data["version"]),
                        Int64(version_data["timestamp"]),
                        Int(version_data["previous_version"])
                    )

                    var changes_list = version_data["changes"]
                    for change_data in changes_list:
                        var change = SchemaChange(
                            Int(change_data["change_type"]),
                            String(change_data["table_name"]),
                            Int64(change_data["timestamp"])
                        )

                        var details_dict = change_data["details"]
                        for detail_key in details_dict:
                            change.set_detail(String(detail_key), String(details_dict[detail_key]))

                        version.add_change(change)

                    self.schema_versions[version.version] = version.copy()
        except:
            # No existing versions, start fresh
            pass

    fn _save_schema_versions(mut self) raises:
        """Save schema versions to storage."""
        var py_dict = Python.dict()
        py_dict["current_version"] = self.current_version

        var versions_dict = Python.dict()
        var version_keys = List[Int]()
        for key in self.schema_versions.keys():
            version_keys.append(key)
        
        for version_num in version_keys:
            var version = self.schema_versions[version_num].copy()
            var version_dict = Python.dict()
            version_dict["version"] = version.version
            version_dict["timestamp"] = version.timestamp
            version_dict["previous_version"] = version.previous_version

            var changes_list = Python.list()
            for change in version.changes:
                var change_dict = Python.dict()
                change_dict["change_type"] = change.change_type
                change_dict["table_name"] = change.table_name
                change_dict["timestamp"] = change.timestamp

                var details_dict = Python.dict()
                for detail_key in change.details:
                    details_dict[detail_key] = change.details[detail_key]
                change_dict["details"] = details_dict

                changes_list.append(change_dict)

            version_dict["changes"] = changes_list
            versions_dict[String(version.version)] = version_dict

        py_dict["versions"] = versions_dict

        var pickle_module = Python.import_module("pickle")
        var data = pickle_module.dumps(py_dict)
        self.schema_manager.storage.write_blob(self.schema_versions_path, String(data))

    fn add_column(mut self, table_name: String, column_name: String, column_type: String, nullable: Bool = True) raises -> Bool:
        """Add a column to a table schema."""
        # Get current schema
        var current_schema = self.schema_manager.load_schema()
        if current_schema.name == "":
            return False

        # Find the table
        var table_index = -1
        for i in range(len(current_schema.tables)):
            if current_schema.tables[i].name == table_name:
                table_index = i
                break

        if table_index == -1:
            return False  # Table not found

        # Check if column already exists
        for col in current_schema.tables[table_index].columns:
            if col.name == column_name:
                return False  # Column already exists

        # Add the column
        current_schema.tables[table_index].add_column(column_name, column_type)

        # Create schema change record
        var timestamp = self._get_current_timestamp()
        var change = SchemaChange(ADD_COLUMN, table_name, timestamp)
        change.set_detail("column_name", column_name)
        change.set_detail("column_type", column_type)
        change.set_detail("nullable", String(nullable))

        # Create new schema version
        var new_version = SchemaVersion(self.current_version + 1, timestamp, self.current_version)
        new_version.add_change(change)

        # Save the updated schema
        var success = self.schema_manager.save_schema(current_schema)
        if success:
            self.schema_versions[new_version.version] = new_version.copy()
            self.current_version = new_version.version
            self._save_schema_versions()
            return True

        return False

    fn drop_column(mut self, table_name: String, column_name: String) raises -> Bool:
        """Drop a column from a table schema."""
        # Get current schema
        var current_schema = self.schema_manager.load_schema()
        if not current_schema:
            return False

        # Find the table
        var table_index = -1
        for i in range(len(current_schema.tables)):
            if current_schema.tables[i].name == table_name:
                table_index = i
                break

        if table_index == -1:
            return False  # Table not found

        # Find and remove the column
        var column_index = -1
        for i in range(len(current_schema.tables[table_index].columns)):
            if current_schema.tables[table_index].columns[i].name == column_name:
                column_index = i
                break

        if column_index == -1:
            return False  # Column not found

        # Remove the column
        var column_type = current_schema.tables[table_index].columns[column_index].type
        current_schema.tables[table_index].columns.remove(column_index)

        # Create schema change record
        var timestamp = self._get_current_timestamp()
        var change = SchemaChange(DROP_COLUMN, table_name, timestamp)
        change.set_detail("column_name", column_name)
        change.set_detail("column_type", column_type)

        # Create new schema version
        var new_version = SchemaVersion(self.current_version + 1, timestamp, self.current_version)
        new_version.add_change(change)

        # Save the updated schema
        var success = self.schema_manager.save_schema(current_schema)
        if success:
            self.schema_versions[new_version.version] = new_version.copy()
            self.current_version = new_version.version
            self._save_schema_versions()
            return True

        return False

    fn _get_version_changes(self, version: Int) -> List[SchemaChange]:
        """Get changes for a specific version."""
        var changes = List[SchemaChange]()
        if version in self.schema_versions:
            try:
                # Access changes without copying the entire SchemaVersion
                var version_key = String(version)
                var version_changes = self._get_version_changes(version)
                for change in version_changes:
                    changes.append(change.copy())
            except:
                pass
        return changes^

    fn get_schema_at_version(mut self, version: Int) raises -> DatabaseSchema:
        """Get the database schema at a specific version."""
        if version == self.current_version:
            return self.schema_manager.load_schema()

        if version not in self.schema_versions:
            return DatabaseSchema("")  # Version not found

        # Start with an empty schema and apply changes up to the requested version
        var schema = DatabaseSchema("godi_db")

        # Apply changes in order
        for v in range(1, version + 1):
            var version_changes = self._get_version_changes(v)
            for change in version_changes:
                self._apply_change_to_schema(schema, change)

        return schema^

    fn get_changes_between_versions(self, old_version: Int, new_version: Int) -> List[SchemaChange]:
        """Get all schema changes between two versions."""
        var changes = List[SchemaChange]()
        for v in range(old_version + 1, new_version + 1):
            if v in self.schema_versions:
                try:
                    var version_changes = self.schema_versions[v]
                    for change in version_changes.changes:
                        changes.append(change)
                except:
                    pass  # Skip if version not found
        return changes.copy()

    fn _apply_change_to_schema(mut self, mut schema: DatabaseSchema, change: SchemaChange):
        """Apply a schema change to a schema."""
        if change.change_type == ADD_COLUMN:
            var table_name = change.table_name
            var column_name = change.get_detail("column_name")
            var column_type = change.get_detail("column_type")

            # Find or create table
            var table_index = -1
            for i in range(len(schema.tables)):
                if schema.tables[i].name == table_name:
                    table_index = i
                    break

            if table_index == -1:
                # Create new table
                var new_table = TableSchema(table_name)
                schema.add_table(new_table)
                table_index = len(schema.tables) - 1

            # Add column
            schema.tables[table_index].add_column(column_name, column_type)

        elif change.change_type == DROP_COLUMN:
            var table_name = change.table_name
            var column_name = change.get_detail("column_name")

            # Find table
            for i in range(len(schema.tables)):
                if schema.tables[i].name == table_name:
                    # Find and remove column
                    var new_columns = List[Column]()
                    for j in range(len(schema.tables[i].columns)):
                        if schema.tables[i].columns[j].name != column_name:
                            new_columns.append(schema.tables[i].columns[j].copy())
                    schema.tables[i].columns = new_columns^
                    break

    fn get_schema_history(self) -> List[SchemaVersion]:
        """Get the complete schema history."""
        var history = List[SchemaVersion]()
        for version_num in self.schema_versions:
            history.append(self.schema_versions[version_num].copy())
        return history

    fn is_backward_compatible(self, old_version: Int, new_version: Int) -> Bool:
        """Check if changes between versions are backward compatible."""
        if old_version >= new_version:
            return True

        # Check changes between versions
        for v in range(old_version + 1, new_version + 1):
            if v in self.schema_versions:
                var version_changes = self.schema_versions[v]
                for change in version_changes.changes:
                    # DROP_COLUMN is not backward compatible
                    if change.change_type == DROP_COLUMN:
                        return False
                    # MODIFY_COLUMN might not be backward compatible depending on the change
                    if change.change_type == MODIFY_COLUMN:
                        var old_type = change.get_detail("old_type")
                        var new_type = change.get_detail("new_type")
                        if not self._is_type_compatible(old_type, new_type):
                            return False

        return True

    fn _is_type_compatible(self, old_type: String, new_type: String) -> Bool:
        """Check if a type change is backward compatible."""
        # Simple type compatibility rules
        if old_type == new_type:
            return True

        # int can be widened to float
        if old_type == "int" and new_type == "float":
            return True

        # string can accommodate more data
        if old_type == "string":
            return True

        # Most other type changes are not backward compatible
        return False

    fn get_breaking_changes(self, old_version: Int, new_version: Int) -> List[SchemaChange]:
        """Get all breaking changes between versions."""
        var breaking_changes = List[SchemaChange]()

        for v in range(old_version + 1, new_version + 1):
            if v in self.schema_versions:
                var version_changes = self.schema_versions[v]
                for change in version_changes.changes:
                    if not self._is_change_backward_compatible(change):
                        breaking_changes.append(change.copy())

        return breaking_changes

    fn _is_change_backward_compatible(self, change: SchemaChange) -> Bool:
        """Check if a specific change is backward compatible."""
        if change.change_type == DROP_COLUMN:
            return False
        elif change.change_type == MODIFY_COLUMN:
            var old_type = change.get_detail("old_type")
            var new_type = change.get_detail("new_type")
            return self._is_type_compatible(old_type, new_type)
        # ADD_COLUMN and ADD_INDEX are backward compatible
        return True

    fn get_schema_differences(self, version1: Int, version2: Int) -> Dict[String, List[String]]:
        """Get differences between two schema versions."""
        var differences = Dict[String, List[String]]()

        var schema1 = self.get_schema_at_version(version1)
        var schema2 = self.get_schema_at_version(version2)

        # Compare tables
        var added_tables = List[String]()
        var removed_tables = List[String]()
        var modified_tables = List[String]()

        # Find added tables
        for table2 in schema2.tables:
            var found = False
            for table1 in schema1.tables:
                if table1.name == table2.name:
                    found = True
                    break
            if not found:
                added_tables.append(table2.name)

        # Find removed tables
        for table1 in schema1.tables:
            var found = False
            for table2 in schema2.tables:
                if table2.name == table1.name:
                    found = True
                    break
            if not found:
                removed_tables.append(table1.name)

        # Find modified tables
        for table1 in schema1.tables:
            for table2 in schema2.tables:
                if table1.name == table2.name:
                    if not self._tables_equal(table1, table2):
                        modified_tables.append(table1.name)
                    break

        differences["added_tables"] = added_tables
        differences["removed_tables"] = removed_tables
        differences["modified_tables"] = modified_tables

        return differences

    fn _tables_equal(self, table1: TableSchema, table2: TableSchema) -> Bool:
        """Check if two table schemas are equal."""
        if table1.name != table2.name or len(table1.columns) != len(table2.columns):
            return False

        for i in range(len(table1.columns)):
            if table1.columns[i].name != table2.columns[i].name or table1.columns[i].type != table2.columns[i].type:
                return False

        return True

    fn _get_current_timestamp(self) raises -> Int64:
        """Get current timestamp."""
        var time_module = Python.import_module("time")
        return Int64(time_module.time() * 1000000)  # microseconds

    fn migrate_data_for_schema_change(self, table_name: String, change: SchemaChange) raises -> Bool:
        """Migrate existing data for a schema change."""
        # This is a placeholder for data migration logic
        # In a full implementation, this would handle data transformation
        # for schema changes like column type modifications

        if change.change_type == ADD_COLUMN:
            # For added columns, we might need to backfill with default values
            # This would require reading existing data and updating it
            return True  # Placeholder - assume success

        elif change.change_type == DROP_COLUMN:
            # For dropped columns, we might need to remove data or archive it
            return True  # Placeholder - assume success

        return False