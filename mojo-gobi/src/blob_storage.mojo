"""
BLOB Storage Abstraction
========================

File-based BLOB storage abstraction compatible with Azure ADLS Gen 2 patterns.
Provides hierarchical namespace and efficient file operations.
"""

from python import Python
import os

struct BlobStorage(Movable, Copyable):
    var root_path: String

    fn __init__(out self, root_path: String) raises:
        self.root_path = root_path
        # Ensure root directory exists
        var os_module = Python.import_module("os")
        os_module.makedirs(root_path, exist_ok=True)

    fn __copyinit__(out self, other: Self):
        self.root_path = other.root_path

    fn __moveinit__(out self, deinit existing: Self):
        self.root_path = existing.root_path^

    fn write_blob(self, path: String, data: String) -> Bool:
        """Write data to a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            var os_module = Python.import_module("os")
            var dirname = os_module.path.dirname(full_path)
            os_module.makedirs(dirname, exist_ok=True)

            var file = open(full_path, "w")
            file.write(data)
            file.close()
            return True
        except:
            return False

    fn read_blob(self, path: String) -> String:
        """Read data from a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            var file = open(full_path, "r")
            var data = file.read()
            file.close()
            return data
        except:
            return ""

    fn delete_blob(self, path: String) -> Bool:
        """Delete a blob at the specified path."""
        try:
            var full_path = self.root_path + "/" + path
            var os_module = Python.import_module("os")
            os_module.remove(full_path)
            return True
        except:
            return False

    fn list_blobs(self, prefix: String = "") -> List[String]:
        """List blobs with optional prefix."""
        var results = List[String]()
        try:
            var os_module = Python.import_module("os")
            for root, dirs, files in os_module.walk(self.root_path):
                for file in files:
                    var full_path = os_module.path.join(root, file)
                    var rel_path = full_path[len(self.root_path) + 1:]
                    if prefix == "" or rel_path.startswith(prefix):
                        results.append(rel_path)
        except:
            pass
        return results

    fn blob_exists(self, path: String) -> Bool:
        """Check if a blob exists."""
        var full_path = self.root_path + "/" + path
        var os_module = Python.import_module("os")
        return os_module.path.exists(full_path)