from collections import Dict, List
from python import Python, PythonObject

# Gobi file format constants
alias GOBI_MAGIC = "GODI"
alias GOBI_VERSION = 1
alias GOBI_HEADER_SIZE = 16  # magic(4) + version(4) + index_offset(8)

# Entry types
alias ENTRY_SCHEMA = 1
alias ENTRY_TABLE = 2
alias ENTRY_INTEGRITY = 3
alias ENTRY_METADATA = 4

struct GobiEntry(Copyable, Movable):
    var entry_type: Int
    var name: String
    var offset: Int64
    var size: Int64
    var checksum: String  # SHA-256

    fn __init__(out self, entry_type: Int, name: String, offset: Int64 = 0, size: Int64 = 0, checksum: String = ""):
        self.entry_type = entry_type
        self.name = name
        self.offset = offset
        self.size = size
        self.checksum = checksum

struct GobiIndex:
    var entries: List[GobiEntry]

    fn __init__(out self):
        self.entries = List[GobiEntry]()

    fn add_entry(mut self, entry: GobiEntry):
        self.entries.append(entry.copy())

    fn find_entry(self, name: String) -> GobiEntry:
        for i in range(len(self.entries)):
            if self.entries[i].name == name:
                return self.entries[i].copy()
        return GobiEntry(0, "", 0, 0, "")

struct GobiFileFormat:
    """
    Handles packing and unpacking of .gobi lakehouse database files.
    """

    var index: GobiIndex

    fn __init__(out self):
        self.index = GobiIndex()

    fn pack(mut self, source_folder: String, target_file: String) raises -> Bool:
        """
        Pack a lakehouse folder into a .gobi file.

        Args:
            source_folder: Path to the lakehouse folder to pack
            target_file: Path where the .gobi file will be created

        Returns:
            True if successful, False otherwise
        """
        print("Packing lakehouse from", source_folder, "to", target_file)

        # Initialize Python modules
        var os = Python.import_module("os")
        var builtins = Python.import_module("builtins")

        # Validate source folder exists
        if not os.path.exists(source_folder):
            print("Error: Source folder does not exist:", source_folder)
            return False

        # Collect all files in the lakehouse
        var files = self._collect_files(source_folder, os)
        if len(files) == 0:
            print("Warning: No files found in source folder")
            return False

        # Create the .gobi file
        try:
            var file = builtins.open(target_file, "wb")

            # Write header
            self._write_header(file, builtins)

            # Reserve space for index (will be written at the end)
            var index_offset_pos = file.tell()
            var struct_mod = Python.import_module("struct")
            file.write(struct_mod.pack("<Q", 0))  # Placeholder for index offset (8 bytes)

            # Write file data and build index
            var current_offset = file.tell()
            for i in range(len(files)):
                var entry = self._write_file_entry(file, String(files[i]), source_folder, Int64(current_offset), builtins)
                self.index.add_entry(entry)
                current_offset = file.tell()

            # Write index
            var index_offset = file.tell()
            self._write_index(file, builtins)

            # Update index offset in header
            file.seek(index_offset_pos)
            file.write(struct_mod.pack("<Q", Int64(index_offset)))

            file.close()

            print("Successfully packed", len(files), "files into", target_file)
            return True

        except:
            print("Error during packing operation")
            return False

    fn unpack(mut self, source_file: String, target_folder: String) raises -> Bool:
        """
        Unpack a .gobi file into a lakehouse folder structure.

        Args:
            source_file: Path to the .gobi file to unpack
            target_folder: Path where the lakehouse folder will be created

        Returns:
            True if successful, False otherwise
        """
        print("Unpacking lakehouse from", source_file, "to", target_folder)

        # Initialize Python modules
        var os = Python.import_module("os")
        var builtins = Python.import_module("builtins")

        # Validate source file exists
        if not os.path.exists(source_file):
            print("Error: Source file does not exist:", source_file)
            return False

        try:
            var file = builtins.open(source_file, "rb")

            # Read and validate header
            var index_offset = self._read_header(file, builtins)
            if index_offset == -1:
                file.close()
                return False

            # Seek to index and read it
            file.seek(index_offset)
            if not self._read_index(file, builtins):
                file.close()
                return False

            # Create target folder
            os.makedirs(target_folder, exist_ok=True)

            # Extract files
            var extracted_count = 0
            for i in range(len(self.index.entries)):
                var entry = self.index.entries[i].copy()
                if self._extract_file_entry(file, entry, target_folder, os, builtins):
                    extracted_count += 1

            file.close()

            print("Successfully unpacked", extracted_count, "files to", target_folder)
            return True

        except:
            print("Error during unpacking operation")
            return False

    fn _collect_files(self, folder: String, os: PythonObject) raises -> List[String]:
        """Recursively collect all files in the lakehouse folder."""
        var files = List[String]()

        try:
            var walk_iter = os.walk(folder)
            for walk_item in walk_iter:
                var root = String(walk_item[0])
                var _ = walk_item[1]  # dirs not used
                var filenames = walk_item[2]

                for filename in filenames:
                    var full_path = os.path.join(root, String(filename))
                    files.append(String(full_path))
        except:
            pass  # Ignore errors during file collection

        return files^

    fn _write_header(mut self, file: PythonObject, builtins: PythonObject) raises:
        """Write the .gobi file header."""
        var struct_mod = Python.import_module("struct")
        var magic_str = PythonObject(GOBI_MAGIC)
        file.write(magic_str.encode("utf-8"))
        file.write(struct_mod.pack("<I", GOBI_VERSION))  # Little endian unsigned int
        # Index offset will be written later

    fn _write_file_entry(mut self, file: PythonObject, file_path: String, base_path: String, offset: Int64, builtins: PythonObject) raises -> GobiEntry:
        """Write a file entry to the .gobi file and return the entry metadata."""
        # Read file content
        var content_file = builtins.open(file_path, "rb")
        var content = content_file.read()
        content_file.close()

        # Determine entry type based on path
        var entry_type = self._get_entry_type(file_path, base_path)

        # Calculate relative path for name
        var relative_path = file_path.replace(base_path + "/", "")
        if relative_path.startswith(base_path):
            relative_path = relative_path[len(base_path) + 1:]

        var start_offset = Int64(file.tell())
        file.write(content)
        var end_offset = Int64(file.tell())
        var size = end_offset - start_offset

        # Create entry (checksum calculation would be added here)
        var entry = GobiEntry(entry_type, relative_path, offset, size, "")

        return entry.copy()

    fn _write_index(mut self, file: PythonObject, builtins: PythonObject) raises:
        """Write the index to the .gobi file."""
        var struct_mod = Python.import_module("struct")

        # Write number of entries
        file.write(struct_mod.pack("<I", len(self.index.entries)))

        # Write each entry
        for i in range(len(self.index.entries)):
            var entry = self.index.entries[i].copy()
            file.write(struct_mod.pack("<I", entry.entry_type))
            var name_str = PythonObject(entry.name)
            var name_bytes = name_str.encode("utf-8")
            file.write(struct_mod.pack("<I", len(name_bytes)))
            file.write(name_bytes)
            file.write(struct_mod.pack("<Q", entry.offset))
            file.write(struct_mod.pack("<Q", entry.size))
            # Checksum would be written here

    fn _read_header(mut self, file: PythonObject, builtins: PythonObject) raises -> Int64:
        """Read and validate the .gobi file header. Returns the index offset."""
        var struct_mod = Python.import_module("struct")

        var magic_bytes = file.read(4)
        var magic = String(magic_bytes.decode("utf-8"))
        if magic != GOBI_MAGIC:
            print("Error: Invalid .gobi file format")
            return -1

        var version_bytes = file.read(4)
        var version = Int(struct_mod.unpack("<I", version_bytes)[0])
        if version != GOBI_VERSION:
            print("Error: Unsupported .gobi file version:", version)
            return -1

        # Read index offset
        var index_offset_bytes = file.read(8)
        var index_offset = Int64(struct_mod.unpack("<Q", index_offset_bytes)[0])

        return index_offset

    fn _read_index(mut self, file: PythonObject, builtins: PythonObject) raises -> Bool:
        """Read the index from the .gobi file."""
        var struct_mod = Python.import_module("struct")

        try:
            # Read number of entries
            var num_entries_bytes = file.read(4)
            var num_entries = Int(struct_mod.unpack("<I", num_entries_bytes)[0])

            # Read each entry
            for i in range(num_entries):
                var entry_type_bytes = file.read(4)
                var entry_type = Int(struct_mod.unpack("<I", entry_type_bytes)[0])

                var name_len_bytes = file.read(4)
                var name_len = Int(struct_mod.unpack("<I", name_len_bytes)[0])

                var name_bytes = file.read(name_len)
                var name = String(name_bytes.decode("utf-8"))

                var offset_bytes = file.read(8)
                var offset = Int64(struct_mod.unpack("<Q", offset_bytes)[0])

                var size_bytes = file.read(8)
                var size = Int64(struct_mod.unpack("<Q", size_bytes)[0])

                # Checksum would be read here
                var entry = GobiEntry(entry_type, name, offset, size, "")
                self.index.add_entry(entry)

            return True

        except:
            print("Error reading index from .gobi file")
            return False

    fn _extract_file_entry(mut self, file: PythonObject, entry: GobiEntry, target_folder: String, os: PythonObject, builtins: PythonObject) raises -> Bool:
        """Extract a single file entry from the .gobi file."""
        try:
            # Seek to the file data
            file.seek(entry.offset)

            # Read the content
            var content = file.read(Int(entry.size))

            # Create the full path
            var full_path = os.path.join(target_folder, entry.name)

            # Create directories if needed
            var dir_path = os.path.dirname(full_path)
            if String(dir_path):
                os.makedirs(dir_path, exist_ok=True)

            # Write the file
            var out_file = builtins.open(String(full_path), "wb")
            out_file.write(content)
            out_file.close()

            return True

        except:
            print("Error extracting file:", entry.name)
            return False

    fn _get_entry_type(self, file_path: String, base_path: String) -> Int:
        """Determine the entry type based on file path."""
        if "/schema/" in file_path:
            return ENTRY_SCHEMA
        elif "/tables/" in file_path:
            return ENTRY_TABLE
        elif "/integrity/" in file_path:
            return ENTRY_INTEGRITY
        else:
            return ENTRY_METADATA