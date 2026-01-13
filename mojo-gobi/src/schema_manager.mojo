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
        self.nullable = existing.nullable
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



struct DatabaseSchema(Movable, Copyable):
    var name: String
    var tables: List[TableSchema]
    var secrets: Dict[String, Dict[String, String]]  # secret_name -> {key -> encrypted_value}
    var attached_databases: Dict[String, String]  # alias -> path
    var attached_sql_files: Dict[String, String]  # alias -> sql_content

    fn __init__(out self, name: String):
        self.name = name
        self.tables = List[TableSchema]()
        self.secrets = Dict[String, Dict[String, String]]()
        self.attached_databases = Dict[String, String]()
        self.attached_sql_files = Dict[String, String]()

    fn __copyinit__(out self, other: Self):
        self.name = other.name
        self.tables = other.tables.copy()
        self.secrets = other.secrets.copy()
        self.attached_databases = other.attached_databases.copy()
        self.attached_sql_files = other.attached_sql_files.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.tables = existing.tables^
        self.secrets = existing.secrets^
        self.attached_databases = existing.attached_databases^
        self.attached_sql_files = existing.attached_sql_files^

    fn add_table(mut self, table: TableSchema):
        """Add a table to the database schema."""
        self.tables.append(table.copy())

    fn get_table(self, name: String) -> TableSchema:
        """Get a table by name."""
        for table in self.tables:
            if table.name == name:
                return table.copy()
        return TableSchema("")



struct SchemaManager(Copyable, Movable):
    var storage: BlobStorage
    var schema_path: String

    fn __init__(out self, storage: BlobStorage):
        self.storage = storage.copy()
        self.schema_path = "schema/database.pkl"

    fn __copyinit__(out self, other: Self):
        self.storage = other.storage.copy()
        self.schema_path = other.schema_path

    fn __moveinit__(out self, deinit existing: Self):
        self.storage = existing.storage^
        self.schema_path = existing.schema_path^

    fn save_schema(mut self, schema: DatabaseSchema) -> Bool:
        """Save database schema to storage."""
        try:
            var py_dict = Python.dict()
            py_dict["name"] = schema.name
            
            var tables_list = Python.list()
            for table in schema.tables:
                var table_dict = Python.dict()
                table_dict["name"] = table.name
                
                var columns_list = Python.list()
                for col in table.columns:
                    var col_dict = Python.dict()
                    col_dict["name"] = col.name
                    col_dict["type"] = col.type
                    columns_list.append(col_dict)
                table_dict["columns"] = columns_list
                
                var indexes_list = Python.list()
                for idx in table.indexes:
                    var idx_dict = Python.dict()
                    idx_dict["name"] = idx.name
                    idx_dict["table_name"] = idx.table_name
                    idx_dict["type"] = idx.type
                    idx_dict["unique"] = idx.unique
                    var cols_list = Python.list()
                    for col in idx.columns:
                        cols_list.append(col)
                    idx_dict["columns"] = cols_list
                    indexes_list.append(idx_dict)
                table_dict["indexes"] = indexes_list
                
                tables_list.append(table_dict)
            py_dict["tables"] = tables_list
            
            # Save secrets
            var secrets_dict = Python.dict()
            for secret_name in schema.secrets:
                var secret_data = schema.secrets[secret_name].copy()
                var secret_py_dict = Python.dict()
                var keys = List[String]()
                for key in secret_data:
                    keys.append(key)
                for key in keys:
                    var value = secret_data[key]
                    secret_py_dict[key] = value
                secrets_dict[secret_name] = secret_py_dict
            py_dict["secrets"] = secrets_dict
            
            # Save attached databases
            var attached_list = Python.list()
            for `alias` in schema.attached_databases:
                var item = Python.list()
                item.append(`alias`)
                item.append(schema.attached_databases[`alias`])
                attached_list.append(item)
            py_dict["attached_databases"] = attached_list
            
            # Save attached SQL files
            var sql_dict = Python.dict()
            for `alias` in schema.attached_sql_files.keys():
                sql_dict[`alias`] = schema.attached_sql_files[`alias`]
            py_dict["attached_sql_files"] = sql_dict
            
            var pickle_module = Python.import_module("pickle")
            var pickled_data = pickle_module.dumps(py_dict)
            return self.storage.write_blob(self.schema_path, String(pickled_data))
        except:
            return False

    fn load_schema(self) -> DatabaseSchema:
        """Load database schema from storage."""
        var data = self.storage.read_blob(self.schema_path)
        if data == "":
            return DatabaseSchema("default")

        try:
            var pickle_module = Python.import_module("pickle")
            var parsed = pickle_module.loads(data)
            
            var db_name = String(parsed["name"])
            var schema = DatabaseSchema(db_name)
            
            var tables = parsed["tables"]
            for i in range(len(tables)):
                var table_data = tables[i]
                var table_name = String(table_data["name"])
                var table_schema = TableSchema(table_name)
                
                var columns = table_data["columns"]
                for j in range(len(columns)):
                    var col_data = columns[j]
                    var col_name = String(col_data["name"])
                    var col_type = String(col_data["type"])
                    table_schema.add_column(col_name, col_type)
                
                var indexes = table_data["indexes"]
                for k in range(len(indexes)):
                    var idx_data = indexes[k]
                    var idx_name = String(idx_data["name"])
                    var idx_table_name = String(idx_data["table_name"])
                    var idx_type = String(idx_data["type"])
                    var idx_unique = Bool(idx_data["unique"])
                    var idx_columns = List[String]()
                    var cols = idx_data["columns"]
                    for col in cols:
                        idx_columns.append(String(col))
                    var index = Index(idx_name, idx_table_name, idx_columns, idx_type, idx_unique)
                    table_schema.add_index(index)
                
                schema.add_table(table_schema)
            
            # Load secrets
            if "secrets" in parsed:
                var secrets_data = parsed["secrets"]
                for secret_name in secrets_data:
                    var secret_dict = secrets_data[secret_name]
                    var secret_kv = Dict[String, String]()
                    for key in secret_dict:
                        secret_kv[String(key)] = String(secret_dict[key])
                    schema.secrets[String(secret_name)] = secret_kv^
            
            # Load attached databases
            if "attached_databases" in parsed:
                var attached_list = parsed["attached_databases"]
                for item in attached_list:
                    var `alias` = String(item[0])
                    var path = String(item[1])
                    schema.attached_databases[`alias`] = path
            
            # Load attached SQL files
            if "attached_sql_files" in parsed:
                var sql_dict = parsed["attached_sql_files"]
                var keys = sql_dict.keys()
                for `alias` in keys:
                    var content = String(sql_dict[`alias`])
                    schema.attached_sql_files[String(`alias`)] = content
            
            return schema.copy()
        except:
            return DatabaseSchema("default")

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

    fn store_secret(mut self, name: String, secret_data: Dict[String, String]) -> Bool:
        """Store an encrypted secret in the database schema."""
        var schema = self.load_schema()
        schema.secrets[name] = secret_data.copy()
        return self.save_schema(schema)

    fn get_secret(mut self, name: String) raises -> Dict[String, String]:
        """Retrieve a secret from the database schema."""
        var schema = self.load_schema()
        if name in schema.secrets:
            return schema.secrets[name].copy()
        return Dict[String, String]()

    fn list_secrets(mut self) -> List[String]:
        """List all secret names in the database."""
        var schema = self.load_schema()
        var secret_names = List[String]()
        for secret_name in schema.secrets:
            secret_names.append(secret_name)
        return secret_names^

    fn delete_secret(mut self, name: String) raises -> Bool:
        """Delete a secret from the database schema."""
        var schema = self.load_schema()
        if name in schema.secrets:
            _ = schema.secrets.pop(name)
            return self.save_schema(schema)
        return False

    fn attach_database(mut self, `alias`: String, path: String) -> Bool:
        """Attach a database with the given alias."""
        var schema = self.load_schema()
        schema.attached_databases[`alias`] = path
        return self.save_schema(schema)

    fn detach_database(mut self, `alias`: String) raises -> Bool:
        """Detach a database by alias."""
        var schema = self.load_schema()
        if `alias` in schema.attached_databases:
            _ = schema.attached_databases.pop(`alias`)
            return self.save_schema(schema)
        return False

    fn list_attached_databases(self) -> Dict[String, String]:
        """List all attached databases."""
        var schema = self.load_schema()
        return schema.attached_databases.copy()

    fn get_attached_database_path(self, `alias`: String) raises -> String:
        """Get the path of an attached database by alias."""
        var schema = self.load_schema()
        if `alias` in schema.attached_databases:
            return schema.attached_databases[`alias`]
        return ""

    fn attach_sql_file(mut self, `alias`: String, file_path: String) raises -> Bool:
        """Attach a SQL file with an alias."""
        var schema = self.load_schema()
        schema.attached_sql_files[`alias`] = file_path
        return self.save_schema(schema)

    fn detach_sql_file(mut self, `alias`: String) raises -> Bool:
        """Detach a SQL file by alias."""
        var schema = self.load_schema()
        if `alias` in schema.attached_sql_files:
            _ = schema.attached_sql_files.pop(`alias`)
            return self.save_schema(schema)
        return False

    fn list_attached_sql_files(self) -> Dict[String, String]:
        """List all attached SQL files."""
        var schema = self.load_schema()
        return schema.attached_sql_files.copy()

    fn get_attached_sql_content(self, `alias`: String) raises -> String:
        """Get the path of an attached SQL file by alias."""
        var schema = self.load_schema()
        if `alias` in schema.attached_sql_files:
            return schema.attached_sql_files[`alias`]
        return ""