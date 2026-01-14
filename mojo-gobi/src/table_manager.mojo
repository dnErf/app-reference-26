# Table Manager - Unified Interface for Lakehouse Tables
# Provides a unified interface for all table operations across different table types

from collections import List, Dict
from lakehouse_engine import LakehouseEngine, Record, COW, MOR, HYBRID
from schema_manager import Column

struct TableManager(Movable):
    """Unified table management interface for the lakehouse."""
    var engine: LakehouseEngine

    fn __init__(out self, storage_path: String = ".gobi") raises:
        """Initialize the table manager with a lakehouse engine."""
        self.engine = LakehouseEngine(storage_path)

    fn create_table(mut self, name: String, schema: List[Column], table_type: Int = HYBRID) raises -> Bool:
        """Create a new table with the specified schema and type."""
        return self.engine.create_table(name, schema, table_type)

    fn insert(mut self, table_name: String, records: List[Record]) raises -> String:
        """Insert records into a table."""
        return self.engine.insert(table_name, records)

    fn upsert(mut self, table_name: String, records: List[Record], key_columns: List[String]) raises -> String:
        """Upsert records into a table with key-based conflict resolution."""
        return self.engine.upsert(table_name, records, key_columns)

    fn query(self, table_name: String, sql: String) raises -> String:
        """Execute a query against a table."""
        return self.engine.query(table_name, sql)

    fn query_since(self, table_name: String, timestamp: Int64, sql: String) raises -> String:
        """Execute a time travel query since the specified timestamp."""
        return self.engine.query_since(table_name, timestamp, sql)

    fn get_changes_since(mut self, table_name: String, since: Int64) raises -> String:
        """Get incremental changes since the specified timestamp."""
        return self.engine.get_changes_since(table_name, since)

    fn list_tables(self) -> List[String]:
        """List all available tables."""
        var tables = List[String]()
        for table_name in self.engine.tables:
            tables.append(table_name)
        return tables.copy()

    fn get_table_type(self, table_name: String) -> Int:
        """Get the type of a table."""
        return self.engine.tables.get(table_name, -1)

    fn get_stats(mut self) raises -> String:
        """Get lakehouse statistics."""
        return self.engine.get_stats()

    fn compact_timeline(mut self):
        """Perform timeline compaction for optimization."""
        self.engine.compact_timeline()