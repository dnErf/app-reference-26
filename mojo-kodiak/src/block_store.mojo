from python import Python, PythonObject
from collections import Dict, List

struct BlockStore(Copyable, Movable):
    var storage_dir: String
    var pyarrow: PythonObject

    fn __init__(out self, dir: String) raises:
        self.storage_dir = dir
        var os = Python.import_module("os")
        os.makedirs(dir, exist_ok=True)
        self.pyarrow = Python.import_module("pyarrow")

    fn write_block(self, table: PythonObject, block_id: String) raises:
        var feather = self.pyarrow.feather
        var path = self.storage_dir + "/" + block_id + ".feather"
        feather.write_feather(table, path)

    fn read_block(self, block_id: String) raises -> PythonObject:
        var feather = self.pyarrow.feather
        var path = self.storage_dir + "/" + block_id + ".feather"
        var table = feather.read_feather(path)
        return table