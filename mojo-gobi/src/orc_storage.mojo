"""
PyArrow ORC Data Storage
========================

Handles columnar data storage using PyArrow ORC format.
Provides efficient storage and retrieval of table data.
"""

from python import Python, PythonObject
from collections import List
from blob_storage import BlobStorage
from merkle_tree import MerkleBPlusTree, SHA256Hash
from index_storage import IndexStorage
from schema_manager import SchemaManager, Index

struct ORCStorage:
    var storage: BlobStorage
    var merkle_tree: MerkleBPlusTree
    var compression: String
    var use_dictionary_encoding: Bool
    var row_index_stride: Int
    var compression_block_size: Int
    var bloom_filter_columns: List[String]
    var index_storage: IndexStorage
    var schema_manager: SchemaManager

    fn __init__(out self, storage: BlobStorage, compression: String = "none", use_dictionary_encoding: Bool = True, row_index_stride: Int = 10000, compression_block_size: Int = 65536, bloom_filter_columns: List[String] = List[String]()):
        self.storage = storage.copy()
        self.merkle_tree = MerkleBPlusTree()
        self.compression = compression
        self.use_dictionary_encoding = use_dictionary_encoding
        self.row_index_stride = row_index_stride
        self.compression_block_size = compression_block_size
        self.bloom_filter_columns = bloom_filter_columns.copy()
        self.index_storage = IndexStorage(storage.copy())
        self.schema_manager = SchemaManager(storage.copy())

    fn __copyinit__(out self, other: Self):
        self.storage = other.storage.copy()
        self.merkle_tree = other.merkle_tree.copy()
        self.compression = other.compression
        self.use_dictionary_encoding = other.use_dictionary_encoding
        self.row_index_stride = other.row_index_stride
        self.compression_block_size = other.compression_block_size
        self.bloom_filter_columns = other.bloom_filter_columns.copy()
        self.index_storage = other.index_storage.copy()
        self.schema_manager = other.schema_manager.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.storage = existing.storage^
        self.merkle_tree = existing.merkle_tree^
        self.compression = existing.compression^
        self.use_dictionary_encoding = existing.use_dictionary_encoding
        self.row_index_stride = existing.row_index_stride
        self.compression_block_size = existing.compression_block_size
        self.bloom_filter_columns = existing.bloom_filter_columns^
        self.index_storage = existing.index_storage^
        self.schema_manager = existing.schema_manager^

    fn write_table(mut self, table_name: String, data: List[List[String]]) -> Bool:
        """Write table data with integrity verification using PyArrow ORC format."""
        try:
            print("Writing table:", table_name, "with", len(data), "rows")

            # Read existing data first
            var existing_data = self.read_table(table_name)
            var all_data = List[List[String]]()

            # Add existing data
            for row in existing_data:
                all_data.append(row.copy())

            # Add new data
            for row in data:
                all_data.append(row.copy())

            print("Total data rows:", len(all_data))

            if len(all_data) == 0:
                return True

            # Import PyArrow
            var pyarrow = Python.import_module("pyarrow")
            var pyarrow_orc = Python.import_module("pyarrow.orc")
            _ = Python.import_module("io")
            _ = Python.import_module("builtins")

            var num_columns = len(all_data[0])

            print("Number of columns:", num_columns)

            print("Creating PyArrow table...")

            # Create PyArrow arrays for each column
            var arrays = Python.list()
            var column_names = Python.list()
            
            for col_idx in range(num_columns):
                var col_name = "col_" + String(col_idx)
                column_names.append(col_name)
                var col_data = Python.list()
                for row_idx in range(len(all_data)):
                    var row = all_data[row_idx].copy()
                    col_data.append(String(row[col_idx] if len(row) > col_idx else ""))
                arrays.append(pyarrow.array(col_data))
            
            # Add integrity hash column
            column_names.append("__integrity_hash__")
            var hash_data = Python.list()
            for row_idx in range(len(all_data)):
                var row = all_data[row_idx].copy()
                var row_data = table_name + ":"
                for i in range(len(row)):
                    if i > 0:
                        row_data += "|"
                    row_data += row[i]
                var row_hash = SHA256Hash.compute(row_data)
                hash_data.append(row_hash)
                # Store in Merkle tree for indexing
                _ = self.merkle_tree.insert(row_idx, row_data)
            arrays.append(pyarrow.array(hash_data))

            # Create PyArrow table directly
            var arrow_table = pyarrow.table(arrays, names=column_names)
            print("PyArrow table created, num columns:", arrow_table.num_columns, "num rows:", arrow_table.num_rows)

            print("Writing ORC...")

            try:
                # Convert List[String] to Python list for bloom filters
                var bloom_filters_py = Python.list()
                for col in self.bloom_filter_columns:
                    bloom_filters_py.append(col)
                
                # Write ORC data to a temporary file with compression
                var temp_filename = table_name + ".orc"
                print("Writing to temp file:", temp_filename, "with compression:", self.compression)
                pyarrow_orc.write_table(
                    arrow_table, 
                    temp_filename,
                    compression=self.compression
                )
                print("PyArrow ORC write to file completed with compression")
                
                # Read the file back as bytes
                var builtins = Python.import_module("builtins")
                var orc_file = builtins.open(temp_filename, "rb")
                var orc_bytes = orc_file.read()
                orc_file.close()
                print("Read ORC file back, size:", len(orc_bytes))
                
                # Remove temp file
                var os = Python.import_module("os")
                os.remove(temp_filename)
                print("Removed temp file")
                
                print("ORC data size:", len(orc_bytes))

                # Encode binary data as base64 for storage
                var base64 = Python.import_module("base64")
                var encoded_data = base64.b64encode(orc_bytes)
                var encoded_str = String(encoded_data.decode("ascii"))
                
                # Store the encoded ORC data
                print("Attempting to store encoded ORC data...")
                var data_success = self.storage.write_blob("tables/" + table_name + ".orc", encoded_str)
                print("Encoded write result:", data_success)

                # Store Merkle tree state for this table
                var tree_state = self.merkle_tree.get_root_hash()
                var tree_success = self.storage.write_blob("integrity/" + table_name + ".merkle", tree_state)

                print("Write success:", data_success and tree_success)
                return data_success and tree_success
            except:
                print("Failed to write ORC table - unknown error")
                return False
        except:
            print("Error in write_table for", table_name)
            return False

    fn save_table(mut self, table_name: String, data: List[List[String]]) -> Bool:
        """Save table data (overwrite) with integrity verification using PyArrow ORC format."""
        try:
            print("Saving table:", table_name, "with", len(data), "rows")

            if len(data) == 0:
                # Delete the table files
                _ = self.storage.delete_blob("tables/" + table_name + ".orc")
                _ = self.storage.delete_blob("integrity/" + table_name + ".merkle")
                return True

            # Import PyArrow
            var pyarrow = Python.import_module("pyarrow")
            var pyarrow_orc = Python.import_module("pyarrow.orc")
            _ = Python.import_module("io")
            _ = Python.import_module("builtins")

            var num_columns = len(data[0])

            print("Number of columns:", num_columns)

            print("Creating PyArrow table...")

            # Create PyArrow arrays for each column
            var arrays = Python.list()
            var column_names = Python.list()
            
            for col_idx in range(num_columns):
                var col_name = "col_" + String(col_idx)
                column_names.append(col_name)
                var col_data = Python.list()
                for row_idx in range(len(data)):
                    var row = data[row_idx].copy()
                    col_data.append(String(row[col_idx] if len(row) > col_idx else ""))
                arrays.append(pyarrow.array(col_data))
            
            # Add integrity hash column
            column_names.append("__integrity_hash__")
            var hash_data = Python.list()
            for row_idx in range(len(data)):
                var row_hash = ""
                for col_idx in range(num_columns):
                    row_hash += data[row_idx][col_idx] + "|"
                var hash_obj = self.merkle_tree.hash_string(row_hash)
                hash_data.append(hash_obj)
            
            arrays.append(pyarrow.array(hash_data))
            
            # Create PyArrow table
            var table = pyarrow.Table.from_arrays(arrays, names=column_names)
            
            print("Converting to ORC...")
            
            # Convert to ORC format
            var orc_buffer = pyarrow_orc.ORCWriter(table, compression=self.compression)
            var orc_bytes = orc_buffer.getvalue()
            
            print("Encoding ORC data...")
            
            # Encode as base64 for storage
            var base64 = Python.import_module("base64")
            var encoded_data = base64.b64encode(orc_bytes)
            var encoded_str = String(encoded_data.decode("ascii"))
            
            # Store the encoded ORC data
            print("Attempting to store encoded ORC data...")
            var data_success = self.storage.write_blob("tables/" + table_name + ".orc", encoded_str)
            print("Encoded write result:", data_success)

            # Store Merkle tree state for this table
            var tree_state = self.merkle_tree.get_root_hash()
            var tree_success = self.storage.write_blob("integrity/" + table_name + ".merkle", tree_state)

            print("Save success:", data_success and tree_success)
            return data_success and tree_success
        except:
            print("Error in save_table for", table_name)
            return False

    fn read_table(self, table_name: String) -> List[List[String]]:
        """Read table data with integrity verification from PyArrow ORC format."""
        var results = List[List[String]]()

        try:
            var encoded_data = self.storage.read_blob("tables/" + table_name + ".orc")
            if encoded_data == "":
                return results.copy()

            # Decode base64 data back to bytes
            var base64 = Python.import_module("base64")
            var orc_data = base64.b64decode(encoded_data)

            # Load stored Merkle tree state for verification
            var stored_tree_hash = self.storage.read_blob("integrity/" + table_name + ".merkle")
            var expected_integrity = stored_tree_hash != ""

            # Import PyArrow
            _ = Python.import_module("pyarrow")
            var pyarrow_orc = Python.import_module("pyarrow.orc")
            _ = Python.import_module("io")
            var builtins = Python.import_module("builtins")

            # Write ORC data to temp file and read it back
            var temp_filename = table_name + "_read_temp.orc"
            var temp_file = builtins.open(temp_filename, "wb")
            temp_file.write(orc_data)
            temp_file.close()
            
            var arrow_table: PythonObject
            try:
                arrow_table = pyarrow_orc.read_table(temp_filename)
                
                # Remove temp file
                var os = Python.import_module("os")
                os.remove(temp_filename)
            except:
                # Cleanup and return empty
                var os = Python.import_module("os")
                os.remove(temp_filename)
                return results.copy()

            # Convert PyArrow table to Python lists for processing
            var num_rows = arrow_table.num_rows
            var column_names = arrow_table.column_names
            var integrity_violations = 0

            for row_idx in range(num_rows):
                var row = List[String]()
                var stored_hash = ""

                # Extract column data (skip the hash column)
                for col_name in column_names:
                    var col_str = String(col_name)
                    if col_str == "__integrity_hash__":
                        stored_hash = String(arrow_table.column(col_name)[row_idx].as_py())
                    else:
                        var cell_value = String(arrow_table.column(col_name)[row_idx].as_py())
                        row.append(cell_value)

                # Verify integrity if we have stored hash
                if stored_hash != "":
                    var row_data = table_name + ":"
                    for j in range(len(row)):
                        if j > 0:
                            row_data += "|"
                        row_data += row[j]

                    var computed_hash = SHA256Hash.compute(row_data)
                    if computed_hash != stored_hash:
                        integrity_violations += 1
                        print("Integrity violation in", table_name, "row", row_idx)

                results.append(row.copy())

            if expected_integrity and integrity_violations == 0:
                print("Integrity verified for", table_name, "-", len(results), "rows OK")
            elif integrity_violations > 0:
                print("WARNING: Found", integrity_violations, "integrity violations in", table_name)

        except:
            print("Error reading ORC table:", table_name)
            pass

        return results.copy()

    fn save_table(mut self, table_name: String, data: List[List[String]]) -> Bool:
        """Save table data by overwriting existing data."""
        # For now, since write_table appends, we need to clear first. But since it's ORC, perhaps delete and write new.
        # For simplicity, assume we delete the blob first.
        _ = self.storage.delete_blob("tables/" + table_name + ".orc")
        _ = self.storage.delete_blob("integrity/" + table_name + ".merkle")
        
        # Reset Merkle tree
        self.merkle_tree = MerkleBPlusTree()
        
        # Write new data
        return self.write_table(table_name, data)

    fn create_index(mut self, index_name: String, table_name: String, columns: List[String], index_type: String = "btree", unique: Bool = False) -> Bool:
        """Create an index on a table."""
        # First, create index in schema
        if not self.schema_manager.create_index(index_name, table_name, columns, index_type, unique):
            return False

        # Load table data
        var table_data = self.read_table(table_name)
        if len(table_data) == 0:
            return True  # Empty table, index created successfully

        # Get column positions
        var schema = self.schema_manager.load_schema()
        var table = schema.get_table(table_name)
        var column_positions = Dict[String, Int]()
        for i in range(len(table.columns)):
            column_positions[table.columns[i].name] = i

        # Create index object
        var index = Index(index_name, table_name, columns, index_type, unique)

        # Build and save index
        return self.index_storage.create_index(index, table_data, column_positions)

    fn drop_index(mut self, index_name: String, table_name: String) -> Bool:
        """Drop an index from a table."""
        # Drop from schema
        if not self.schema_manager.drop_index(index_name, table_name):
            return False

        # Drop from storage
        return self.index_storage.drop_index(index_name)

    fn get_indexes(self, table_name: String) -> List[Index]:
        """Get all indexes for a table."""
        return self.schema_manager.get_indexes(table_name)

    fn search_with_index(self, table_name: String, index_name: String, key: String, start_key: String = "", end_key: String = "") -> List[List[String]]:
        """Search table using an index."""
        var indexes = self.get_indexes(table_name)
        var index_type = ""
        for index in indexes:
            if index.name == index_name:
                index_type = index.type
                break

        if index_type == "":
            return List[List[String]]()  # Index not found

        # Search index for row IDs
        var row_ids = self.index_storage.search_index(index_name, index_type, key, start_key, end_key)

        # Load full table data
        var table_data = self.read_table(table_name)
        var results = List[List[String]]()

        # Filter rows by matching row IDs
        for row_id in row_ids:
            if row_id < len(table_data):
                results.append(table_data[row_id].copy())

        return results

fn pack_database_zstd(folder: String, rich_console: PythonObject) raises:
    """Pack database folder into a .gobi file using ZSTD ORC compression."""
    rich_console.print("[green]Packing database from: " + folder + " using ZSTD ORC compression[/green]")

    # Check if folder exists
    var os = Python.import_module("os")
    if not os.path.exists(folder):
        rich_console.print("[red]Error: Database folder '" + folder + "' does not exist[/red]")
        return

    # Create .gobi filename
    var gobi_file = folder + ".gobi"
    rich_console.print("[dim]Creating ORC archive: " + gobi_file + "[/dim]")

    try:
        # Import PyArrow for ORC compression
        var pyarrow = Python.import_module("pyarrow")
        var pyarrow_orc = Python.import_module("pyarrow.orc")
        var builtins = Python.import_module("builtins")

        # Collect all files and their contents
        var file_paths = Python.list()
        var file_contents = Python.list()
        var file_sizes = Python.list()

        # Walk through all files in the folder
        var walk_iter = os.walk(folder)
        for walk_item in walk_iter:
            var root = walk_item[0]
            var _ = walk_item[1]  # dirs not used
            var files = walk_item[2]

            for file in files:
                var full_path = os.path.join(root, file)
                var arcname = os.path.relpath(full_path, folder)
                
                # Read file content
                try:
                    var file_obj = builtins.open(full_path, "rb")
                    var content = file_obj.read()
                    file_obj.close()
                    
                    file_paths.append(arcname)
                    file_contents.append(content)
                    file_sizes.append(len(content))
                    
                    rich_console.print("[dim]  Added: " + String(arcname) + " (" + String(len(content)) + " bytes)[/dim]")
                except:
                    rich_console.print("[yellow]  Skipped: " + String(arcname) + " (could not read)[/yellow]")

        # Create PyArrow table with file data
        var table = pyarrow.table([
            pyarrow.array(file_paths, type=pyarrow.string()),
            pyarrow.array(file_contents, type=pyarrow.binary()),
            pyarrow.array(file_sizes, type=pyarrow.int64())
        ], names=["path", "content", "size"])

        # Write as ORC with ZSTD compression
        pyarrow_orc.write_table(table, gobi_file, compression="ZSTD")
        
        rich_console.print("[green]Database packed successfully: " + gobi_file + "[/green]")

    except:
        rich_console.print("[red]Error: Failed to pack database[/red]")
fn test_pyarrow_orc():
    """Test PyArrow ORC functionality."""
    try:
        print("Testing PyArrow ORC...")
        
        var pyarrow = Python.import_module("pyarrow")
        print("PyArrow imported successfully")
        
        # Try importing pyarrow.orc directly
        var pyarrow_orc = Python.import_module("pyarrow.orc")
        print("PyArrow ORC module imported successfully")
        
        # Create simple test data using PyArrow directly
        var test_data = Python.list()
        test_data.append(pyarrow.array(["Alice", "Bob"]))
        test_data.append(pyarrow.array(["25", "30"]))
        
        var table = pyarrow.table(test_data, names=["name", "age"])
        print("PyArrow table created")
        
        # Try writing to file
        print("Attempting ORC write...")
        pyarrow_orc.write_table(table, "test.orc")
        print("ORC write successful")
        
        # Try reading back
        var read_table = pyarrow_orc.read_table("test.orc")
        print("ORC read successful, rows:", read_table.num_rows)
        
        # Clean up
        var os = Python.import_module("os")
        os.remove("test.orc")
        print("Test completed successfully")
        
    except:
        print("ORC test failed")
        try:
            var os = Python.import_module("os")
            if os.path.exists("test.orc"):
                os.remove("test.orc")
        except:
            pass