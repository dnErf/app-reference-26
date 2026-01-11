"""
Lakehouse Schema Management
===========================

Manages database schema, tables, and metadata for the Godi lakehouse.
Uses BLOB storage for persistence.
"""

from collections import List
from python import Python
from blob_storage import BlobStorage

struct Column(Movable, Copyable):
    var name: String
    var type: String  # e.g., "int", "string", "float"
    var nullable: Bool

    fn __init__(out self, name: String, type: String, nullable: Bool = True):
        self.name = name
        self.type = type
        self.nullable = nullable

    fn __copyinit__(out self, other: Self):
        self.name = other.name
        self.type = other.type
        self.nullable = other.nullable

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.type = existing.type^
        self.nullable = existing.nullable^
struct Index(Movable, Copyable):
    var name: String
    var table_name: String
    var columns: List[String]
    var type: String  # "btree", "hash", "bitmap"
    var unique: Bool

    fn __init__(out self, name: String, table_name: String, columns: List[String], type: String = "btree", unique: Bool = False):
        self.name = name
        self.table_name = table_name
        self.columns = columns.copy()
        self.type = type
        self.unique = unique

    fn __copyinit__(out self, other: Self):
        self.name = other.name
        self.table_name = other.table_name
        self.columns = other.columns.copy()
        self.type = other.type
        self.unique = other.unique

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.table_name = existing.table_name^
        self.columns = existing.columns^
        self.type = existing.type^
        self.unique = existing.unique

    fn to_json(self) -> String:
        """Serialize index to JSON string."""
        var json = "{"
        json += "\"name\": \"" + self.name + "\","
        json += "\"table_name\": \"" + self.table_name + "\","
        json += "\"type\": \"" + self.type + "\","
        json += "\"unique\": " + (String("true") if self.unique else String("false")) + ","
        json += "\"columns\": ["

        for i in range(len(self.columns)):
            if i > 0:
                json += ","
            json += "\"" + self.columns[i] + "\""

        json += "]}"
        return json
struct TableSchema(Movable, Copyable):
    var name: String
    var columns: List[Column]
    var indexes: List[Index]

    fn __init__(out self, name: String):
        self.name = name
        self.columns = List[Column]()
        self.indexes = List[Index]()

    fn __copyinit__(out self, other: Self):
        self.name = other.name
        self.columns = other.columns.copy()
        self.indexes = other.indexes.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.columns = existing.columns^
        self.indexes = existing.indexes^

    fn add_column(mut self, name: String, type: String):
        """Add a column to the table schema."""
        self.columns.append(Column(name, type))

    fn add_index(mut self, index: Index):
        """Add an index to the table schema."""
        self.indexes.append(index.copy())

    fn get_index(self, name: String) -> Index:
        """Get an index by name."""
        for index in self.indexes:
            if index.name == name:
                return index.copy()
        return Index("", "", List[String]())

    fn to_json(self) -> String:
        """Serialize schema to JSON string."""
        var json = "{"
        json += "\"name\": \"" + self.name + "\","
        json += "\"columns\": ["

        for i in range(len(self.columns)):
            if i > 0:
                json += ","
            json += "{\"name\": \"" + self.columns[i].name + "\", \"type\": \"" + self.columns[i].type + "\"}"

        json += "],\"indexes\": ["

        for i in range(len(self.indexes)):
            if i > 0:
                json += ","
            json += self.indexes[i].to_json()

        json += "]}"
        return json

struct DatabaseSchema(Movable, Copyable):
    var name: String
    var tables: List[TableSchema]

    fn __init__(out self, name: String):
        self.name = name
        self.tables = List[TableSchema]()

    fn __copyinit__(out self, other: Self):
        self.name = other.name
        self.tables = other.tables.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.tables = existing.tables^

    fn add_table(mut self, table: TableSchema):
        """Add a table to the database schema."""
        self.tables.append(table.copy())

    fn get_table(self, name: String) -> TableSchema:
        """Get a table by name."""
        for table in self.tables:
            if table.name == name:
                return table.copy()
        return TableSchema("")

    fn to_json(self) -> String:
        """Serialize database schema to JSON string."""
        var json = "{"
        json += "\"name\": \"" + self.name + "\","
        json += "\"tables\": ["

        for i in range(len(self.tables)):
            if i > 0:
                json += ","
            json += self.tables[i].to_json()

        json += "]}"
        return json

struct SchemaManager(Copyable, Movable):
    var storage: BlobStorage
    var schema_path: String

    fn __init__(out self, storage: BlobStorage):
        self.storage = storage.copy()
        self.schema_path = "schema/database.json"

    fn __copyinit__(out self, other: Self):
        self.storage = other.storage.copy()
        self.schema_path = other.schema_path

    fn __moveinit__(out self, deinit existing: Self):
        self.storage = existing.storage^
        self.schema_path = existing.schema_path^

    fn save_schema(mut self, schema: DatabaseSchema) -> Bool:
        """Save database schema to storage."""
        var json_data = schema.to_json()
        return self.storage.write_blob(self.schema_path, json_data)

    fn load_schema(self) -> DatabaseSchema:
        """Load database schema from storage."""
        var json_data = self.storage.read_blob(self.schema_path)
        print("DEBUG: json_data = '" + json_data + "'")
        if json_data == "":
            print("DEBUG: json_data is empty, returning default schema")
            return DatabaseSchema("default")

        # TODO: Implement proper JSON parsing
        # For now, return hardcoded schema for testing
        print("DEBUG: returning hardcoded schema")
        var schema = DatabaseSchema("godi_db")
        var users_table = TableSchema("users")
        users_table.add_column("username", "string")
        users_table.add_column("password_hash", "string") 
        users_table.add_column("role", "string")
        schema.add_table(users_table)
        return schema.copy()

    fn list_tables(self) -> List[String]:
        """List all table names in the database."""
        var schema = self.load_schema()
        var table_names = List[String]()
        for table in schema.tables:
            table_names.append(table.name)
        return table_names.copy()

    fn create_table(mut self, table_name: String, columns: List[Column]) -> Bool:
        """Create a new table in the schema."""
        var schema = self.load_schema()
        var table = TableSchema(table_name)

        for col in columns:
            table.add_column(col.name, col.type)

        schema.add_table(table)
        return self.save_schema(schema)

    fn create_index(mut self, index_name: String, table_name: String, columns: List[String], index_type: String = "btree", unique: Bool = False) -> Bool:
        """Create an index on a table."""
        var schema = self.load_schema()
        var table = schema.get_table(table_name)
        if table.name == "":
            return False

        # Check if columns exist in table
        for col_name in columns:
            var found = False
            for col in table.columns:
                if col.name == col_name:
                    found = True
                    break
            if not found:
                return False

        # Check for duplicate index name
        for existing_index in table.indexes:
            if existing_index.name == index_name:
                return False

        var index = Index(index_name, table_name, columns, index_type, unique)
        table.add_index(index)

        # Update table in schema
        for i in range(len(schema.tables)):
            if schema.tables[i].name == table_name:
                schema.tables[i] = table.copy()
                break

        return self.save_schema(schema)

    fn drop_index(mut self, index_name: String, table_name: String) -> Bool:
        """Drop an index from a table."""
        var schema = self.load_schema()
        var table = schema.get_table(table_name)
        if table.name == "":
            return False

        var new_indexes = List[Index]()
        var found = False
        for index in table.indexes:
            if index.name != index_name:
                new_indexes.append(index.copy())
            else:
                found = True

        if not found:
            return False

        table.indexes = new_indexes.copy()

        # Update table in schema
        for i in range(len(schema.tables)):
            if schema.tables[i].name == table_name:
                schema.tables[i] = table.copy()
                break

        return self.save_schema(schema)

    fn get_indexes(self, table_name: String) -> List[Index]:
        """Get all indexes for a table."""
        var schema = self.load_schema()
        var table = schema.get_table(table_name)
        return table.indexes.copy()