"""
BLOB Storage Abstraction
========================

File-based BLOB storage abstraction compatible with Azure ADLS Gen 2 patterns.
Provides hierarchical namespace and efficient file operations using PyArrow filesystem interface.
"""

from python import Python, PythonObject
import os

struct BlobStorage(Movable, Copyable):
    var fs: PythonObject
    var root_path: String

    fn __init__(out self, root_path: String) raises:
        self.root_path = root_path
        # Ensure root directory exists
        var os_module = Python.import_module("os")
        os_module.makedirs(root_path, exist_ok=True)
        
        # Initialize PyArrow LocalFileSystem
        var pyarrow_fs = Python.import_module("pyarrow.fs")
        self.fs = pyarrow_fs.LocalFileSystem()

    fn __copyinit__(out self, other: Self):
        self.fs = other.fs
        self.root_path = other.root_path

    fn __moveinit__(out self, deinit existing: Self):
        self.fs = existing.fs^
        self.root_path = existing.root_path^

    fn write_blob(self, path: String, data: String) -> Bool:
        """Write data to a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            var os_module = Python.import_module("os")
            var dirname = os_module.path.dirname(full_path)
            os_module.makedirs(dirname, exist_ok=True)
            
            var stream = self.fs.open_output_stream(full_path)
            var py_data = PythonObject(data)
            stream.write(py_data.encode("utf-8"))
            stream.close()
            return True
        except:
            return False

    fn read_blob(self, path: String) -> String:
        """Read data from a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            var stream = self.fs.open_input_stream(full_path)
            var data = stream.read()
            stream.close()
            return String(data.decode("utf-8"))
        except:
            return ""

    fn write_blob_binary(self, path: String, data: PythonObject) -> Bool:
        """Write binary data to a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            var os_module = Python.import_module("os")
            var dirname = os_module.path.dirname(full_path)
            os_module.makedirs(dirname, exist_ok=True)
            
            var stream = self.fs.open_output_stream(full_path)
            stream.write(data)
            stream.close()
            return True
        except:
            return False

    fn read_blob_binary(self, path: String) -> PythonObject:
        """Read binary data from a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            var stream = self.fs.open_input_stream(full_path)
            var data = stream.read()
            stream.close()
            return data
        except:
            return Python.none()

    fn delete_blob(self, path: String) -> Bool:
        """Delete a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            self.fs.delete_file(full_path)
            return True
        except:
            return False

    fn list_blobs(self, prefix: String = "") -> List[String]:
        """List blobs with optional prefix."""
        var results = List[String]()
        try:
            var pyarrow_fs = Python.import_module("pyarrow.fs")
            var selector = pyarrow_fs.FileSelector(self.root_path, recursive=True)
            var file_infos = self.fs.get_file_info(selector)
            
            for file_info in file_infos:
                if file_info.is_file:
                    var full_path = String(file_info.path)
                    var rel_path = full_path[len(self.root_path) + 1:]
                    if prefix == "" or rel_path.startswith(prefix):
                        results.append(rel_path)
        except:
            pass
        return results.copy()

    fn blob_exists(self, path: String) -> Bool:
        """Check if a blob exists."""
        try:
            var full_path = self.root_path + "/" + path
            var file_info = self.fs.get_file_info(full_path)
            return Bool(file_info.is_file)
        except:
            return False