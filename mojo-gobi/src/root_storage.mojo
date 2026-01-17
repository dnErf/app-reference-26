"""
Root Storage System

Manages persistent storage of various entities (procedures, triggers, schedules, etc.) using LakehouseEngine.
Provides generic CRUD operations for entity storage.
"""

from python import Python, PythonObject
from collections import List
from lakehouse_engine import LakehouseEngine, Record
from schema_manager import Column
from job_scheduler import JobScheduler
from profiling_manager import ProfilingManager
from incremental_processor import IncrementalProcessor
from merkle_timeline import MerkleTimeline
from procedure_execution_engine import ProcedureExecutionEngine

struct RootStorage(Movable, Copyable):
    """Generic storage system for entities using LakehouseEngine."""

    var engine: LakehouseEngine
    var entities_table: String
    var procedure_engine: ProcedureExecutionEngine
    var job_scheduler: JobScheduler
    var profiler: ProfilingManager
    var processor: IncrementalProcessor
    var timeline: MerkleTimeline
    var tables: Dict[String, Int]

    # db_path: String = ".entities" 
    fn __init__(out self, var engine: LakehouseEngine) raises:
        """Initialize root storage with a dedicated database."""
        self.engine = engine^
        self.entities_table = "@gobi_entities"

        self.procedure_engine = ProcedureExecutionEngine(self)
        self.job_scheduler = JobScheduler(self)
        self.profiler = ProfilingManager()
        self.processor = IncrementalProcessor()
        self.timeline = MerkleTimeline()
        self.tables = Dict[String, Int]()
        
        # Initialize the entities table if it doesn't exist
        self._ensure_entities_table()

        # Initialize blob storage
        self._initialize_blob_store()

    fn _initialize_blob_store(mut self) raises:
        """Initialize blob storage for the lakehouse engine."""
        try:
            self.engine.initialize_blob_store(".gobi")
            print("✓ Blob storage initialized in root storage")
        except e:
            print("Warning: Failed to initialize blob storage:", String(e))

    fn _ensure_entities_table(mut self) raises:
        """Ensure the entities table exists with correct schema."""
        # Try to create the table - if it already exists, this will be a no-op or handled gracefully
        var columns = List[Column]()
        columns.append(Column("entity_type", "string"))  # 'procedure', 'trigger', 'schedule', etc.
        columns.append(Column("entity_name", "string"))  # Name of the entity
        columns.append(Column("data", "string"))         # JSON data for the entity
        columns.append(Column("created_at", "timestamp"))
        columns.append(Column("updated_at", "timestamp"))

        # Try to create table - ignore if it already exists
        try:
            var success = self.engine.create_table(self.entities_table, columns)
            if not success:
                print("Warning: Could not create entities table, it may already exist")
        except:
            print("Warning: Could not create entities table, it may already exist")

    # Generic entity operations
    fn store_entity(mut self, entity_type: String, name: String, data: Record) raises -> Bool:
        """Store an entity in the storage system."""
        # Check if entity already exists
        if self.entity_exists(entity_type, name):
            # Update existing entity
            return self.update_entity(entity_type, name, data)
        else:
            # Insert new entity
            return self._insert_entity(entity_type, name, data)

    fn _insert_entity(mut self, entity_type: String, name: String, data: Record) raises -> Bool:
        """Insert a new entity."""
        # Create record for insertion
        var record = Record()
        record.set_value("entity_type", entity_type)
        record.set_value("entity_name", name)

        # Serialize data to JSON-like string
        var data_str = self._serialize_record(data)
        record.set_value("data", data_str)

        # Set timestamps
        var now = self._get_current_timestamp()
        record.set_value("created_at", now)
        record.set_value("updated_at", now)

        # Insert the record
        var records = List[Record]()
        records.append(record ^)
        var commit_id = self.engine.insert(self.entities_table, records)
        return commit_id != ""

    fn update_entity(mut self, entity_type: String, name: String, data: Record) raises -> Bool:
        """Update an existing entity."""
        # For now, delete and re-insert (in a real implementation, we'd do an update)
        var delete_success = self.delete_entity(entity_type, name)
        if not delete_success:
            return False

        return self._insert_entity(entity_type, name, data)

    fn entity_exists(self, entity_type: String, name: String) raises -> Bool:
        """Check if an entity exists."""
        var all_data = self.engine.storage.read_table(self.entities_table)

        for row in all_data:
            if len(row) >= 2 and row[0] == entity_type and row[1] == name:
                return True

        return False

    fn get_entity(self, entity_type: String, name: String) raises -> Optional[Record]:
        """Get an entity by type and name."""
        var all_data = self.engine.storage.read_table(self.entities_table)

        for row in all_data:
            if len(row) >= 3 and row[0] == entity_type and row[1] == name:
                var record = Record()
                record.set_value("entity_type", row[0])
                record.set_value("entity_name", row[1])
                record.set_value("data", row[2])
                record.set_value("created_at", row[3] if len(row) > 3 else "")
                record.set_value("updated_at", row[4] if len(row) > 4 else "")
                return record ^

        return None

    fn list_entities(self, entity_type: String) raises -> List[Record]:
        """List all entities of a specific type."""
        var all_data = self.engine.storage.read_table(self.entities_table)
        var entities = List[Record]()

        for row in all_data:
            if len(row) >= 3 and row[0] == entity_type:
                var record = Record()
                record.set_value("entity_type", row[0])
                record.set_value("entity_name", row[1])
                record.set_value("data", row[2])
                record.set_value("created_at", row[3] if len(row) > 3 else "")
                record.set_value("updated_at", row[4] if len(row) > 4 else "")
                entities.append(record ^)

        return entities ^

    fn delete_entity(mut self, entity_type: String, name: String) raises -> Bool:
        """Delete an entity by type and name."""
        # Get all entities except the one to delete
        var all_entities = self._list_all_entities()
        var remaining_entities = List[Record]()

        for entity in all_entities:
            var ent_type = entity.get_value("entity_type")
            var ent_name = entity.get_value("entity_name")
            if not (ent_type == entity_type and ent_name == name):
                remaining_entities.append(entity.copy())

        # Clear the table by recreating it (simplified approach)
        # In a real implementation, we'd have proper delete operations
        # For now, we'll recreate the table with remaining entities

        # Create new table data without the deleted entity
        var new_data = List[List[String]]()
        for entity in remaining_entities:
            var row = List[String]()
            row.append(entity.get_value("entity_type"))
            row.append(entity.get_value("entity_name"))
            row.append(entity.get_value("data"))
            row.append(entity.get_value("created_at"))
            row.append(entity.get_value("updated_at"))
            new_data.append(row ^)

        # Write the new data back to storage
        return self.engine.storage.write_table(self.entities_table, new_data)

    fn _list_all_entities(self) raises -> List[Record]:
        """List all entities regardless of type."""
        var all_data = self.engine.storage.read_table(self.entities_table)
        var entities = List[Record]()

        for row in all_data:
            if len(row) >= 3:
                var record = Record()
                record.set_value("entity_type", row[0])
                record.set_value("entity_name", row[1])
                record.set_value("data", row[2])
                record.set_value("created_at", row[3] if len(row) > 3 else "")
                record.set_value("updated_at", row[4] if len(row) > 4 else "")
                entities.append(record ^)

        return entities ^

    # Procedure-specific convenience methods (for backward compatibility)
    fn store_procedure(mut self, name: String, kind: String, metadata: String, body: String) raises -> Bool:
        """Store a procedure (convenience method)."""
        var data = Record()
        data.set_value("kind", kind)
        data.set_value("metadata", metadata)
        data.set_value("body", body)
        return self.store_entity("procedure", name, data)

    fn list_procedures(self) raises -> List[Record]:
        """List all procedures (convenience method)."""
        var entities = self.list_entities("procedure")
        var procedures = List[Record]()

        for entity in entities:
            var data_str = entity.get_value("data")
            # Parse the data string back to individual fields
            # This is a simplified parsing - in real implementation, use proper JSON parsing
            var record = Record()
            record.set_value("procedure_name", entity.get_value("entity_name"))

            # Extract fields from data string
            if data_str.find('"kind"') != -1:
                var kind_start = data_str.find('"kind"') + 8
                var kind_end = data_str.find('"', kind_start)
                if kind_end != -1:
                    record.set_value("kind", data_str[kind_start:kind_end])

            if data_str.find('"metadata"') != -1:
                var meta_start = data_str.find('"metadata"') + 12
                var meta_end = data_str.find('}', meta_start)
                if meta_end != -1:
                    var meta_content = data_str[meta_start:meta_end].strip()
                    if meta_content.endswith('"'):
                        meta_content = meta_content[:-1]
                    if meta_content.startswith('"'):
                        meta_content = meta_content[1:]
                    record.set_value("metadata", String(meta_content))

            if data_str.find('"body"') != -1:
                var body_start = data_str.find('"body"') + 8
                var body_end = data_str.find('"', body_start)
                if body_end != -1:
                    record.set_value("body", data_str[body_start:body_end])

            record.set_value("created_at", entity.get_value("created_at"))
            record.set_value("updated_at", entity.get_value("updated_at"))

            procedures.append(record ^)

        return procedures ^

    fn procedure_exists(self, name: String) raises -> Bool:
        """Check if a procedure exists (convenience method)."""
        return self.entity_exists("procedure", name)

    fn delete_procedure(mut self, name: String) raises -> Bool:
        """Delete a procedure (convenience method)."""
        return self.delete_entity("procedure", name)

    # Trigger-specific convenience methods
    fn store_trigger(mut self, name: String, timing: String, event: String, target: String, body: String) raises -> Bool:
        """Store a trigger (convenience method)."""
        var data = Record()
        data.set_value("timing", timing)
        data.set_value("event", event)
        data.set_value("target", target)
        data.set_value("body", body)
        data.set_value("enabled", "true")  # Triggers are enabled by default
        return self.store_entity("trigger", name, data)

    fn list_triggers(self) raises -> List[Record]:
        """List all triggers (convenience method)."""
        var entities = self.list_entities("trigger")
        var triggers = List[Record]()

        for entity in entities:
            var data_str = entity.get_value("data")
            var record = Record()
            record.set_value("trigger_name", entity.get_value("entity_name"))

            # Extract fields from data string (simplified parsing)
            if data_str.find('"timing"') != -1:
                var timing_start = data_str.find('"timing"') + 10
                var timing_end = data_str.find('"', timing_start)
                if timing_end != -1:
                    record.set_value("timing", data_str[timing_start:timing_end])

            if data_str.find('"event"') != -1:
                var event_start = data_str.find('"event"') + 9
                var event_end = data_str.find('"', event_start)
                if event_end != -1:
                    record.set_value("event", data_str[event_start:event_end])

            if data_str.find('"target"') != -1:
                var target_start = data_str.find('"target"') + 10
                var target_end = data_str.find('"', target_start)
                if target_end != -1:
                    record.set_value("target", data_str[target_start:target_end])

            if data_str.find('"body"') != -1:
                var body_start = data_str.find('"body"') + 8
                var body_end = data_str.find('"', body_start)
                if body_end != -1:
                    record.set_value("body", data_str[body_start:body_end])

            record.set_value("created_at", entity.get_value("created_at"))
            record.set_value("updated_at", entity.get_value("updated_at"))

            triggers.append(record ^)

        return triggers ^

    fn find_triggers(self, target: String, event: String, timing: String) raises -> List[Record]:
        """Find triggers matching the given target, event, and timing."""
        var entities = self.list_entities("trigger")
        var matching_triggers = List[Record]()

        for entity in entities:
            var data_str = entity.get_value("data")
            var record = Record()
            record.set_value("trigger_name", entity.get_value("entity_name"))

            # Extract fields
            var trigger_timing = ""
            var trigger_event = ""
            var trigger_target = ""

            if data_str.find('"timing"') != -1:
                var timing_start = data_str.find('"timing"') + 10
                var timing_end = data_str.find('"', timing_start)
                if timing_end != -1:
                    trigger_timing = data_str[timing_start:timing_end]

            if data_str.find('"event"') != -1:
                var event_start = data_str.find('"event"') + 9
                var event_end = data_str.find('"', event_start)
                if event_end != -1:
                    trigger_event = data_str[event_start:event_end]

            if data_str.find('"target"') != -1:
                var target_start = data_str.find('"target"') + 10
                var target_end = data_str.find('"', target_start)
                if target_end != -1:
                    trigger_target = data_str[target_start:target_end]

            # Check if this trigger matches
            if trigger_target == target and trigger_event == event and trigger_timing == timing:
                # Check if trigger is enabled
                var is_enabled = True  # Default to enabled for backward compatibility
                if data_str.find('"enabled"') != -1:
                    var enabled_start = data_str.find('"enabled"') + 11
                    var enabled_end = data_str.find('"', enabled_start)
                    if enabled_end != -1:
                        var enabled_str = data_str[enabled_start:enabled_end]
                        is_enabled = enabled_str == "true"

                if is_enabled:
                    record.set_value("timing", trigger_timing)
                    record.set_value("event", trigger_event)
                    record.set_value("target", trigger_target)

                    if data_str.find('"body"') != -1:
                        var body_start = data_str.find('"body"') + 8
                        var body_end = data_str.find('"', body_start)
                        if body_end != -1:
                            record.set_value("body", data_str[body_start:body_end])

                    matching_triggers.append(record ^)

        return matching_triggers ^

    fn trigger_exists(self, name: String) raises -> Bool:
        """Check if a trigger exists (convenience method)."""
        return self.entity_exists("trigger", name)

    fn delete_trigger(mut self, name: String) raises -> Bool:
        """Delete a trigger (convenience method)."""
        return self.delete_entity("trigger", name)

    fn enable_trigger(mut self, name: String) raises -> Bool:
        """Enable a trigger."""
        return self.update_trigger_enabled(name, True)

    fn disable_trigger(mut self, name: String) raises -> Bool:
        """Disable a trigger."""
        return self.update_trigger_enabled(name, False)

    fn update_trigger_enabled(mut self, name: String, enabled: Bool) raises -> Bool:
        """Update trigger enabled status."""
        if not self.trigger_exists(name):
            return False

        # Get current trigger data
        var entities = self.list_entities("trigger")
        for entity in entities:
            if entity.get_value("entity_name") == name:
                var data_str = entity.get_value("data")

                # Parse current data and create new record
                var record = Record()
                
                # Extract timing
                if data_str.find('"timing"') != -1:
                    var start = data_str.find('"timing"') + 10
                    var end = data_str.find('"', start)
                    if end != -1:
                        record.set_value("timing", data_str[start:end])

                # Extract event
                if data_str.find('"event"') != -1:
                    var start = data_str.find('"event"') + 9
                    var end = data_str.find('"', start)
                    if end != -1:
                        record.set_value("event", data_str[start:end])

                # Extract target
                if data_str.find('"target"') != -1:
                    var start = data_str.find('"target"') + 10
                    var end = data_str.find('"', start)
                    if end != -1:
                        record.set_value("target", data_str[start:end])

                # Extract body
                if data_str.find('"body"') != -1:
                    var start = data_str.find('"body"') + 8
                    var end = data_str.find('"', start)
                    if end != -1:
                        record.set_value("body", data_str[start:end])

                # Set enabled
                record.set_value("enabled", "true" if enabled else "false")

                # Delete and re-insert
                var delete_success = self.delete_entity("trigger", name)
                if not delete_success:
                    return False

                return self._insert_entity("trigger", name, record)

        return False

    # Schedule-specific convenience methods
    fn store_schedule(mut self, name: String, sched: String, exe: String, call: String) raises -> Bool:
        """Store a schedule (convenience method)."""
        var data = Record()
        data.set_value("sched", sched)
        data.set_value("exe", exe)
        data.set_value("call", call)
        data.set_value("enabled", "true")  # Schedules are enabled by default
        return self.store_entity("schedule", name, data)

    fn _serialize_record(self, record: Record) -> String:
        """Serialize a Record to JSON-like string."""
        # Generic JSON serialization for any Record fields
        var json = "{"
        var parts = List[String]()
        
        # Get all field names (this is a simplified approach)
        # In a real implementation, we'd iterate over all fields
        var timing = record.get_value("timing")
        var event = record.get_value("event") 
        var target = record.get_value("target")
        var body = record.get_value("body")
        var enabled = record.get_value("enabled")
        var kind = record.get_value("kind")
        var metadata = record.get_value("metadata")

        if timing != "":
            parts.append('"timing": "' + timing + '"')
        if event != "":
            parts.append('"event": "' + event + '"')
        if target != "":
            parts.append('"target": "' + target + '"')
        if body != "":
            parts.append('"body": "' + body + '"')
        if enabled != "":
            parts.append('"enabled": "' + enabled + '"')
        if kind != "":
            parts.append('"kind": "' + kind + '"')
        if metadata != "":
            parts.append('"metadata": ' + metadata)

        json += ", ".join(parts)
        json += "}"
        return json

    fn _get_current_timestamp(self) -> String:
        """Get current timestamp as string."""
        # Simplified timestamp - in real implementation, use proper datetime
        return "2024-01-01T00:00:00Z"  # Placeholder

    fn generate_performance_report(self) raises -> String:
        """Generate a comprehensive performance report for the lakehouse engine."""
        var report = String("=== Lakehouse Engine Performance Report ===\n\n")
        report += self.profiler.generate_performance_report()
        return report

    fn get_changes_since(mut self, table_name: String, since: Int64) raises -> String:
        """Get incremental changes since a watermark."""
        var changeset = self.processor.get_changes_since(table_name, since)
        var result = "Changes since " + String(since) + " for " + table_name + ":\n"
        result += "  Total changes: " + String(changeset.count_changes()) + "\n"
        result += "  Watermark: " + String(changeset.watermark) + "\n"
        return result

    fn query_since(mut self, table_name: String, timestamp: Int64, sql: String) raises -> String:
        """Execute a time-travel query against the lakehouse with schema evolution support."""
        print("Time-travel query since", String(timestamp) + ":", sql)

        # Get commits and schema version at the specified timestamp
        var result = self.timeline.query_as_of_with_schema(table_name, timestamp)
        var commits = result[0].copy()
        var schema_version = result[1]

        print("Found", len(commits), "commits since timestamp", String(timestamp))
        print("Using schema version:", String(schema_version))

        # Get the appropriate schema for this timestamp
        # var historical_schema = self.schema_evolution.get_schema_at_version(schema_version)
        print("Historical schema lookup disabled (schema_evolution commented out)")

        # In full implementation, this would:
        # 1. Parse SQL with SINCE clause
        # 2. Use historical schema for column mapping
        # 3. Filter data based on timeline state
        # 4. Execute query against historical data with proper schema

        return "Time-travel query executed: " + sql + " (since " + String(timestamp) + ", schema v" + String(schema_version) + ")"

    fn get_stats(mut self) raises -> String:
        """Get lakehouse engine statistics."""
        var stats = "Lakehouse Engine Statistics:\n"
        stats += "  Tables: " + String(len(self.tables)) + "\n"
        stats += self.timeline.get_stats()
        stats += self.processor.get_stats()
        return stats
