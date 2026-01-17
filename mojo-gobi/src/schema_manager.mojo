"""
Lakehouse Schema Management
===========================

Manages database schema, tables, and metadata for the Godi lakehouse.
Uses BLOB storage for persistence.
"""

from collections import List
from python import Python, PythonObject
from blob_storage import BlobStorage

struct Column(Movable, Copyable):
    var name: String
    var type: String  # e.g., "int", "string", "float", "blob"
    var nullable: Bool
    var blob_bucket: String  # S3 bucket for BLOB columns (optional)
    var blob_compression: String  # Compression for BLOB columns (optional)

    fn __init__(out self, name: String, type: String, nullable: Bool = True):
        self.name = name
        self.type = type
        self.nullable = nullable
        self.blob_bucket = ""
        self.blob_compression = "none"

    fn __init__(out self, name: String, type: String, blob_bucket: String, blob_compression: String = "none", nullable: Bool = True):
        """Constructor for BLOB columns."""
        self.name = name
        self.type = type
        self.nullable = nullable
        self.blob_bucket = blob_bucket
        self.blob_compression = blob_compression

    fn __copyinit__(out self, other: Self):
        self.name = other.name
        self.type = other.type
        self.nullable = other.nullable
        self.blob_bucket = other.blob_bucket
        self.blob_compression = other.blob_compression

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.type = existing.type^
        self.nullable = existing.nullable
        self.blob_bucket = existing.blob_bucket^
        self.blob_compression = existing.blob_compression^

    fn is_blob(self) -> Bool:
        """Check if this is a BLOB column."""
        return self.type == "blob"
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
    var struct_definitions: Dict[String, Dict[String, String]]  # struct_name -> {field_name -> field_type}
    var attached_databases: Dict[String, String]  # alias -> path
    var attached_sql_files: Dict[String, String]  # alias -> sql_content
    var installed_extensions: List[String]  # list of installed extensions

    fn __init__(out self, name: String):
        self.name = name
        self.tables = List[TableSchema]()
        self.secrets = Dict[String, Dict[String, String]]()
        self.struct_definitions = Dict[String, Dict[String, String]]()
        self.attached_databases = Dict[String, String]()
        self.attached_sql_files = Dict[String, String]()
        self.installed_extensions = List[String]()
        # Install httpfs by default
        self.installed_extensions.append("httpfs")

    fn __copyinit__(out self, other: Self):
        self.name = other.name
        self.tables = other.tables.copy()
        self.secrets = other.secrets.copy()
        self.struct_definitions = other.struct_definitions.copy()
        self.attached_databases = other.attached_databases.copy()
        self.attached_sql_files = other.attached_sql_files.copy()
        self.installed_extensions = other.installed_extensions.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.tables = existing.tables^
        self.secrets = existing.secrets^
        self.struct_definitions = existing.struct_definitions^
        self.attached_databases = existing.attached_databases^
        self.attached_sql_files = existing.attached_sql_files^
        self.installed_extensions = existing.installed_extensions^

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
            
            # Save installed extensions
            var extensions_list = Python.list()
            for extension in schema.installed_extensions:
                extensions_list.append(extension)
            py_dict["installed_extensions"] = extensions_list
            
            # Save struct definitions
            var structs_dict = Python.dict()
            for struct_name in schema.struct_definitions:
                var fields = schema.struct_definitions[struct_name].copy()
                var fields_py_dict = Python.dict()
                var field_keys = List[String]()
                for field_key in fields.keys():
                    field_keys.append(field_key)
                for field_key in field_keys:
                    var field_type = fields[field_key]
                    fields_py_dict[field_key] = field_type
                structs_dict[struct_name] = fields_py_dict
            py_dict["struct_definitions"] = structs_dict
            
            var pickle_module = Python.import_module("pickle")
            var base64_module = Python.import_module("base64")
            var pickled_data = pickle_module.dumps(py_dict)
            var encoded_data = base64_module.b64encode(pickled_data)
            var encoded_str = encoded_data.decode("ascii")
            return self.storage.write_blob(self.schema_path, String(encoded_str))
        except:
            return False

    fn load_schema(self) -> DatabaseSchema:
        """Load database schema from storage."""
        var data = self.storage.read_blob(self.schema_path)
        if data == "":
            return DatabaseSchema("default")

        try:
            var pickle_module = Python.import_module("pickle")
            var base64_module = Python.import_module("base64")
            var encoded_bytes = PythonObject(data).encode("ascii")
            var decoded_data = base64_module.b64decode(encoded_bytes)
            var parsed = pickle_module.loads(decoded_data)
            
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
            
            # Load struct definitions
            if "struct_definitions" in parsed:
                var structs_data = parsed["struct_definitions"]
                for struct_name in structs_data:
                    var fields_dict = structs_data[struct_name]
                    var fields = Dict[String, String]()
                    for field_name in fields_dict:
                        var field_type = String(fields_dict[field_name])
                        fields[String(field_name)] = field_type
                    schema.struct_definitions[String(struct_name)] = fields^
            
            # Load installed extensions
            if "installed_extensions" in parsed:
                var extensions_list = parsed["installed_extensions"]
                schema.installed_extensions.clear()
                for extension in extensions_list:
                    schema.installed_extensions.append(String(extension))
            else:
                # For backward compatibility, ensure httpfs is installed by default
                if not schema.installed_extensions.__contains__("httpfs"):
                    schema.installed_extensions.append("httpfs")
            
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

    fn store_struct_definition(mut self, name: String, fields: Dict[String, String]) -> Bool:
        """Store a struct definition in the database schema."""
        var schema = self.load_schema()
        schema.struct_definitions[name] = fields.copy()
        return self.save_schema(schema)

    fn get_struct_definition(mut self, name: String) raises -> Dict[String, String]:
        """Retrieve a struct definition from the database schema."""
        var schema = self.load_schema()
        if name in schema.struct_definitions:
            return schema.struct_definitions[name].copy()
        return Dict[String, String]()

    fn list_struct_definitions(mut self) -> List[String]:
        """List all struct definition names in the database."""
        var schema = self.load_schema()
        var struct_names = List[String]()
        for struct_name in schema.struct_definitions:
            struct_names.append(struct_name)
        return struct_names^

    fn delete_struct_definition(mut self, name: String) raises -> Bool:
        """Delete a struct definition from the database schema."""
        var schema = self.load_schema()
        if name in schema.struct_definitions:
            _ = schema.struct_definitions.pop(name)
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

    fn install_extension(mut self, extension_name: String) raises -> Bool:
        """Install an extension."""
        var schema = self.load_schema()
        # Check if already installed
        for installed in schema.installed_extensions:
            if installed == extension_name:
                return True  # Already installed
        schema.installed_extensions.append(extension_name)
        return self.save_schema(schema)

    fn is_extension_installed(self, extension_name: String) -> Bool:
        """Check if an extension is installed."""
        var schema = self.load_schema()
        for installed in schema.installed_extensions:
            if installed == extension_name:
                return True
        return False

    fn list_installed_extensions(self) -> List[String]:
        """List all installed extensions."""
        var schema = self.load_schema()
        return schema.installed_extensions.copy()

    fn get_attached_sql_content(self, `alias`: String) raises -> String:
        """Get the path of an attached SQL file by alias."""
        var schema = self.load_schema()
        if `alias` in schema.attached_sql_files:
            return schema.attached_sql_files[`alias`]
        return ""