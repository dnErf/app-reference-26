from python import Python, PythonObject
from collections import Dict, List

struct BlockStore(Copyable, Movable):
    var storage_dir: String
    var pyarrow: PythonObject
    var feather: PythonObject
    var orc: PythonObject

    fn __init__(out self, dir: String) raises:
        self.storage_dir = dir
        var os = Python.import_module("os")
        os.makedirs(dir, exist_ok=True)
        self.pyarrow = Python.import_module("pyarrow")
        self.feather = Python.import_module("pyarrow.feather")
        self.orc = Python.import_module("pyarrow.orc")

    fn write_block(self, table: PythonObject, block_id: String, format: String = "feather") raises:
        """
        Write a block using the specified format (feather or orc).
        Defaults to feather for backward compatibility.
        """
        if format == "orc":
            var path = self.storage_dir + "/" + block_id + ".orc"
            self.orc.write_table(table, path)
        else:
            var path = self.storage_dir + "/" + block_id + ".feather"
            self.feather.write_feather(table, path)

    fn read_block(self, block_id: String) raises -> PythonObject:
        """
        Read a block, auto-detecting format from file extension.
        """
        var feather_path = self.storage_dir + "/" + block_id + ".feather"
        var orc_path = self.storage_dir + "/" + block_id + ".orc"

        var os = Python.import_module("os")
        if os.path.exists(orc_path):
            var table = self.orc.read_table(orc_path)
            return table
        elif os.path.exists(feather_path):
            var table = self.feather.read_feather(feather_path)
            return table
        else:
            raise Error("Block file not found: " + block_id)

    fn write_block_feather(self, table: PythonObject, block_id: String) raises:
        """Write a block using Feather format."""
        var path = self.storage_dir + "/" + block_id + ".feather"
        self.feather.write_feather(table, path)

    fn write_block_orc(self, table: PythonObject, block_id: String) raises:
        """Write a block using ORC format."""
        var path = self.storage_dir + "/" + block_id + ".orc"
        self.orc.write_table(table, path)

    fn read_block_feather(self, block_id: String) raises -> PythonObject:
        """Read a block from Feather format."""
        var path = self.storage_dir + "/" + block_id + ".feather"
        var table = self.feather.read_feather(path)
        return table

    fn read_block_orc(self, block_id: String) raises -> PythonObject:
        """Read a block from ORC format."""
        var path = self.storage_dir + "/" + block_id + ".orc"
        var table = self.orc.read_table(path)
        return table