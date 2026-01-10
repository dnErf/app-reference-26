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

struct ORCStorage:
    var storage: BlobStorage
    var merkle_tree: MerkleBPlusTree
    var compression: String
    var use_dictionary_encoding: Bool
    var row_index_stride: Int
    var compression_block_size: Int
    var bloom_filter_columns: List[String]

    fn __init__(out self, storage: BlobStorage, compression: String = "ZSTD", use_dictionary_encoding: Bool = True, row_index_stride: Int = 10000, compression_block_size: Int = 65536, bloom_filter_columns: List[String] = List[String]()):
        self.storage = storage.copy()
        self.merkle_tree = MerkleBPlusTree()
        self.compression = compression
        self.use_dictionary_encoding = use_dictionary_encoding
        self.row_index_stride = row_index_stride
        self.compression_block_size = compression_block_size
        self.bloom_filter_columns = bloom_filter_columns.copy()

    fn __copyinit__(out self, other: Self):
        self.storage = other.storage.copy()
        self.merkle_tree = other.merkle_tree.copy()
        self.compression = other.compression
        self.use_dictionary_encoding = other.use_dictionary_encoding
        self.row_index_stride = other.row_index_stride
        self.compression_block_size = other.compression_block_size
        self.bloom_filter_columns = other.bloom_filter_columns.copy()

    fn __moveinit__(out self, deinit existing: Self):
        self.storage = existing.storage^
        self.merkle_tree = existing.merkle_tree^
        self.compression = existing.compression^
        self.use_dictionary_encoding = existing.use_dictionary_encoding
        self.row_index_stride = existing.row_index_stride
        self.compression_block_size = existing.compression_block_size
        self.bloom_filter_columns = existing.bloom_filter_columns^

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
            var pandas = Python.import_module("pandas")
            _ = Python.import_module("io")
            _ = Python.import_module("builtins")

            var num_columns = len(all_data[0])

            print("Number of columns:", num_columns)

            print("Creating DataFrame...")

            # Create pandas DataFrame with dynamic columns based on data
            var df_data = Python.dict()
            for col_idx in range(num_columns):
                df_data["col_" + String(col_idx)] = Python.list()
            df_data["__integrity_hash__"] = Python.list()
            
            for row_idx in range(len(all_data)):
                var row = all_data[row_idx].copy()
                for col_idx in range(num_columns):
                    df_data["col_" + String(col_idx)].append(String(row[col_idx] if len(row) > col_idx else ""))
                
                var row_data = table_name + ":"
                for i in range(len(row)):
                    if i > 0:
                        row_data += "|"
                    row_data += row[i]
                var row_hash = SHA256Hash.compute(row_data)
                df_data["__integrity_hash__"].append(row_hash)

                # Store in Merkle tree for indexing
                _ = self.merkle_tree.insert(row_idx, row_data)

            var df = pandas.DataFrame(df_data)

            print("Converting to PyArrow table...")

            # Convert to PyArrow table and write as ORC
            var arrow_table = pyarrow.Table.from_pandas(df)
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
            _ = Python.import_module("pandas")
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

            # Convert to pandas DataFrame for easier processing
            var df = arrow_table.to_pandas()

            # Extract data rows
            var integrity_violations = 0
            var num_rows = len(df)

            for row_idx in range(num_rows):
                var row = List[String]()
                var stored_hash = ""

                # Get the integrity hash
                if df.__contains__("__integrity_hash__"):
                    stored_hash = String(df["__integrity_hash__"].iloc[row_idx])

                # Extract column data (skip the hash column)
                var columns = df.columns
                for col_name in columns:
                    var col_str = String(col_name)
                    if col_str != "__integrity_hash__":
                        var cell_value = String(df[col_name].iloc[row_idx])
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

fn test_pyarrow_orc():
    """Test PyArrow ORC functionality."""
    try:
        print("Testing PyArrow ORC...")
        
        var pyarrow = Python.import_module("pyarrow")
        print("PyArrow imported successfully")
        
        # Try importing pyarrow.orc directly
        var pyarrow_orc = Python.import_module("pyarrow.orc")
        print("PyArrow ORC module imported successfully")
        
        var pandas = Python.import_module("pandas")
        print("Pandas imported successfully")
        
        # Create simple test data
        var test_data = Python.dict()
        test_data["name"] = Python.list()
        test_data["name"].append("Alice")
        test_data["age"] = Python.list()  
        test_data["age"].append("25")
        
        var df = pandas.DataFrame(test_data)
        print("DataFrame created")
        
        var table = pyarrow.Table.from_pandas(df)
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