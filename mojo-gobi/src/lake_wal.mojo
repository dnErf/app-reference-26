"""
Embedded LakeWAL (Lakehouse Write-Ahead Log)
=============================================

Embedded binary storage for internal and global configuration.
Uses the same ORC layout as ORCStorage but embedded directly in the binary.
Read-only, cannot be unpacked or packed externally.
"""

from python import Python, PythonObject
from collections import List
from blob_storage import BlobStorage
from merkle_tree import MerkleBPlusTree, SHA256Hash
from index_storage import IndexStorage
from schema_manager import SchemaManager, DatabaseSchema, Index, Column

from lake_wal_embedded import get_embedded_orc_data

struct EmbeddedBlobStorage(Movable):
    """Blob storage that reads from embedded binary data instead of files."""
    var embedded_data: List[UInt8]

    fn __init__(out self, embedded_data: List[UInt8]):
        self.embedded_data = embedded_data.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.embedded_data = existing.embedded_data^

    fn read_blob(self, path: String) -> Optional[PythonObject]:
        """Read embedded data as Python bytes object."""
        # For embedded storage, we treat the entire embedded data as one "file"
        # In a real implementation, you might have multiple embedded blobs
        # differentiated by path, but for LakeWAL, we use a single embedded dataset
        try:
            # Convert List[UInt8] to Python bytes
            var py_bytes_list = Python.list()
            for byte_val in self.embedded_data:
                py_bytes_list.append(PythonObject(byte_val))
            
            # Create Python bytes object
            var builtins = Python.import_module("builtins")
            var py_bytes = builtins.bytes(py_bytes_list)
            return py_bytes
        except:
            return None

    fn write_blob(self, path: String, data: String) -> Bool:
        """Embedded storage is read-only."""
        return False

    fn list_blobs(self, prefix: String = "") -> List[String]:
        """List available embedded blobs."""
        var blobs = List[String]()
        blobs.append("lakewal.orc")  # Single embedded blob
        return blobs^

    fn delete_blob(self, path: String) -> Bool:
        """Embedded storage is read-only."""
        return False

struct EmbeddedORCStorage(Movable):
    """ORC storage that reads from embedded binary data."""
    var embedded_storage: EmbeddedBlobStorage
    var merkle_tree: MerkleBPlusTree
    var schema_manager: SchemaManager

    fn __init__(out self, embedded_data: List[UInt8], schema_manager: SchemaManager):
        self.embedded_storage = EmbeddedBlobStorage(embedded_data.copy())
        self.merkle_tree = MerkleBPlusTree()
        self.schema_manager = schema_manager.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.embedded_storage = existing.embedded_storage^
        self.merkle_tree = existing.merkle_tree^
        self.schema_manager = existing.schema_manager^

    fn read_table(self, table_name: String) -> List[List[String]]:
        """Read table data from embedded ORC storage."""
        try:
            # Read embedded ORC data as Python bytes
            var orc_data_opt = self.embedded_storage.read_blob("lakewal.orc")

            if not orc_data_opt:
                return List[List[String]]()
            
            var orc_data = orc_data_opt.value()

            # Parse ORC data using PyArrow
            var pyarrow_orc = Python.import_module("pyarrow.orc")
            var io_module = Python.import_module("io")
            var bytes_io = io_module.BytesIO(orc_data)  # Direct bytes object

            var orc_file = pyarrow_orc.ORCFile(bytes_io)
            var arrow_table = orc_file.read()

            # Convert to List[List[String]]
            var result = List[List[String]]()
            var num_rows = arrow_table.num_rows
            var num_cols = arrow_table.num_columns

            for row_idx in range(num_rows):
                var row = List[String]()
                for col_idx in range(num_cols):
                    var col_name = arrow_table.column_names[col_idx]
                    if col_name == "__integrity_hash__":
                        continue  # Skip integrity column

                    var value = String(arrow_table.column(col_idx)[row_idx])
                    row.append(value)
                result.append(row^)

            return result^

        except e:
            print("Error reading embedded ORC table:", e)
            return List[List[String]]()

    fn get_config_value(self, key: String) -> String:
        """Get a configuration value from the embedded LakeWAL."""
        var config_table = self.read_table("global_config")
        for row in config_table:
            if len(row) >= 2 and row[0] == key:
                return row[1]
        return ""

    fn list_config_keys(self) -> List[String]:
        """List all configuration keys in the embedded LakeWAL."""
        var config_table = self.read_table("global_config")
        var keys = List[String]()
        for row in config_table:
            if len(row) >= 1:
                keys.append(row[0])
        return keys^

struct LakeWAL(Movable):
    """Lakehouse Write-Ahead Log for internal and global configuration."""
    var embedded_orc: EmbeddedORCStorage
    var schema_manager: SchemaManager

    fn __init__(out self) raises:
        # Initialize with embedded data
        # Create a minimal blob storage for schema manager (embedded doesn't need persistence)
        var dummy_storage = BlobStorage("/tmp/dummy")  # Won't be used for embedded
        self.schema_manager = SchemaManager(dummy_storage)
        
        # Generate config data at runtime
        var config_data = self._generate_runtime_config_static()
        var embedded_data = self._generate_orc_from_config_static(config_data)
        self.embedded_orc = EmbeddedORCStorage(embedded_data, self.schema_manager)

        # Initialize embedded schema for global config
        self._initialize_embedded_schema()

    fn __moveinit__(out self, deinit existing: Self):
        self.embedded_orc = existing.embedded_orc^
        self.schema_manager = existing.schema_manager^

    fn _initialize_embedded_schema(mut self):
        """Initialize the embedded schema for global configuration."""
        # Create global_config table schema
        var columns = List[Column]()
        columns.append(Column("key", "string"))
        columns.append(Column("value", "string"))
        columns.append(Column("description", "string"))

        _ = self.schema_manager.create_table("global_config", columns)

    @staticmethod
    fn _generate_runtime_config_static() -> List[List[String]]:
        """Generate default LakeWAL configuration data at runtime."""
        var config_data = List[List[String]]()

        # Database and system configuration
        config_data.append(["database.version", "2.1.0", "PL-GRIZZLY database version"])
        config_data.append(["database.name", "PL-GRIZZLY", "Database system name"])
        config_data.append(["database.engine", "Lakehouse", "Storage engine type"])

        # Storage configuration
        config_data.append(["storage.compression.default", "snappy", "Default compression algorithm"])
        config_data.append(["storage.compression.level", "6", "Default compression level"])
        config_data.append(["storage.orc.stripe_size", "67108864", "ORC stripe size in bytes (64MB)"])
        config_data.append(["storage.orc.row_index_stride", "10000", "ORC row index stride"])
        config_data.append(["storage.page_size", "8192", "Default page size in bytes"])

        # Query execution configuration
        config_data.append(["query.max_memory", "1073741824", "Maximum memory per query (1GB)"])
        config_data.append(["query.timeout", "300000", "Query timeout in milliseconds (5 minutes)"])
        config_data.append(["query.max_rows", "1000000", "Maximum rows to return per query"])
        config_data.append(["query.cache.enabled", "true", "Enable query result caching"])
        config_data.append(["query.cache.size", "104857600", "Query cache size in bytes (100MB)"])

        # JIT compilation configuration
        config_data.append(["jit.enabled", "true", "Enable JIT compilation"])
        config_data.append(["jit.optimization_level", "2", "JIT optimization level (0-3)"])
        config_data.append(["jit.cache.enabled", "true", "Enable JIT compilation caching"])

        # Network and HTTP configuration
        config_data.append(["http.timeout", "30000", "HTTP request timeout in milliseconds"])
        config_data.append(["http.max_redirects", "5", "Maximum HTTP redirects"])
        config_data.append(["http.user_agent", "PL-GRIZZLY/2.1.0", "HTTP user agent string"])

        # Security configuration
        config_data.append(["security.encryption.enabled", "true", "Enable data encryption"])
        config_data.append(["security.encryption.algorithm", "AES-256-GCM", "Encryption algorithm"])
        config_data.append(["security.secret.max_age", "86400000", "Secret maximum age in milliseconds (24 hours)"])

        # Performance tuning
        config_data.append(["performance.thread_pool_size", "8", "Thread pool size for parallel operations"])
        config_data.append(["performance.batch_size", "1000", "Default batch size for operations"])
        config_data.append(["performance.prefetch.enabled", "true", "Enable data prefetching"])

        # Logging and monitoring
        config_data.append(["logging.level", "INFO", "Default logging level"])
        config_data.append(["logging.max_file_size", "10485760", "Maximum log file size (10MB)"])
        config_data.append(["monitoring.enabled", "true", "Enable system monitoring"])
        config_data.append(["monitoring.metrics_interval", "60000", "Metrics collection interval (1 minute)"])

        # Feature flags
        config_data.append(["features.advanced_analytics", "true", "Enable advanced analytics features"])
        config_data.append(["features.experimental", "false", "Enable experimental features"])
        config_data.append(["features.deprecated_warnings", "true", "Show warnings for deprecated features"])

        return config_data^

    @staticmethod
    fn _generate_orc_from_config_static(config_data: List[List[String]]) -> List[UInt8]:
        """Generate ORC binary data from configuration key-value pairs."""
        try:
            # Import PyArrow modules
            var pyarrow = Python.import_module("pyarrow")
            var pyarrow_orc = Python.import_module("pyarrow.orc")
            var io_module = Python.import_module("io")
            var builtins = Python.import_module("builtins")

            if len(config_data) == 0:
                # Return minimal ORC data for empty config
                var minimal = List[UInt8]()
                minimal.append(0x4F)  # O
                minimal.append(0x52)  # R
                minimal.append(0x43)  # C
                minimal.append(0x00)  # null terminator
                return minimal^

            # Create PyArrow arrays
            var keys = Python.list()
            var values = Python.list()
            var descriptions = Python.list()

            for row in config_data:
                if len(row) >= 1:
                    keys.append(row[0])  # key
                else:
                    keys.append("")

                if len(row) >= 2:
                    values.append(row[1])  # value
                else:
                    values.append("")

                if len(row) >= 3:
                    descriptions.append(row[2])  # description
                else:
                    descriptions.append("")

            # Create PyArrow arrays
            var key_array = pyarrow.array(keys)
            var value_array = pyarrow.array(values)
            var desc_array = pyarrow.array(descriptions)

            # Create table
            var table = pyarrow.table({
                "key": key_array,
                "value": value_array,
                "description": desc_array
            })

            # Write to ORC format in memory
            var buffer = io_module.BytesIO()
            pyarrow_orc.write_table(table, buffer)

            # Get the binary data
            var orc_bytes = buffer.getvalue()
            buffer.close()

            # Convert to List[UInt8]
            var result = List[UInt8]()
            for i in range(len(orc_bytes)):
                result.append(UInt8(orc_bytes[i]))

            return result^

        except e:
            print("Error generating runtime ORC data:", e)
            var minimal = List[UInt8]()
            minimal.append(0x4F)
            minimal.append(0x52)
            minimal.append(0x43)
            minimal.append(0x00)
            return minimal^

    fn get_config(self, key: String) -> String:
        """Get a global configuration value."""
        return self.embedded_orc.get_config_value(key)

    fn get_config_with_default(self, key: String, default: String) -> String:
        """Get a configuration value with a default fallback."""
        var value = self.get_config(key)
        return value if value != "" else default

    fn list_configs(self) -> List[String]:
        """List all available configuration keys."""
        return self.embedded_orc.list_config_keys()

    fn is_embedded(self) -> Bool:
        """Confirm this is embedded storage."""
        return True

    fn create_config_table(mut self, table_name: String = "lakewal_config") -> Bool:
        """Create a virtual table schema for embedded configuration data that can be queried."""
        try:
            # Create table schema based on configuration structure
            var columns = List[Column]()
            columns.append(Column("key", "string"))
            columns.append(Column("value", "string"))
            columns.append(Column("description", "string"))

            # Create the table schema only (data is accessed directly from embedded storage)
            var create_result = self.schema_manager.create_table(table_name, columns)
            if not create_result:
                print("Failed to create config table schema")
                return False

            print("Created config table schema '" + table_name + "'")
            print("Note: Data is accessed directly from embedded LakeWAL storage")
            return True

        except e:
            print("Error creating config table:", e)
            return False

    fn get_config_table_name(self) -> String:
        """Get the default configuration table name."""
        return "lakewal_config"

    fn query_config_table(self, query: String) -> List[List[String]]:
        """Execute a query against the configuration table."""
        # This would require integration with the full query engine
        # For now, return the raw config data
        return self.embedded_orc.read_table("global_config")

    fn get_storage_info(self) -> String:
        """Get information about the embedded storage."""
        var info = "LakeWAL Runtime Storage\n"
        var config_data = LakeWAL._generate_runtime_config_static()
        info += "Data Size: " + String(len(config_data) * 100) + " bytes (estimated)\n"  # Rough estimate
        info += "Read-Only: Yes\n"
        info += "Config Keys: " + String(len(config_data)) + "\n"
        return info