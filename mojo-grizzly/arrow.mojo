# Pure Mojo Arrow Implementation
# Zero-dependency columnar database core
# Based on Apache Arrow Columnar Format v1.5

from memory import memset_zero

# Data Types
# enum DataType:
#     int64
#     float64
#     string

# Core Buffer struct for contiguous memory
struct Buffer(Copyable, Movable):
    var data: List[UInt8]
    var size: Int

    fn __init__(out self, size: Int):
        self.data = List[UInt8]()
        self.data.resize(size, 0)
        self.size = size

    fn __copyinit__(out self, existing: Buffer):
        self.data = List[UInt8]()
        for b in existing.data:
            self.data.append(b)
        self.size = existing.size

    fn __moveinit__(out self, deinit existing: Buffer):
        self.data = existing.data^
        self.size = existing.size

    fn __getitem__(self, index: Int) -> UInt8:
        return self.data[index]

    fn __setitem__(mut self, index: Int, value: UInt8):
        self.data[index] = value

# Validity bitmap helper
fn is_valid(validity: Buffer, index: Int) -> Bool:
    if validity.size == 0:
        return True
    var byte_index = index // 8
    var bit_index = index % 8
    return (validity[byte_index] & (1 << bit_index)) != 0

fn set_valid(inout validity: Buffer, index: Int, valid: Bool):
    var byte_index = index // 8
    var bit_index = index % 8
    if valid:
        validity[byte_index] |= (1 << bit_index)
    else:
        validity[byte_index] &= ~(1 << bit_index)

# Primitive Array base
# trait Array:
#     var length: Int
#     var null_count: Int
#     var validity: Buffer

#     fn is_valid(self, index: Int) -> Bool:
#         return is_valid(self.validity, index)

# Int64 Primitive Array
struct Int64Array(Copyable, Movable):
    var data: List[Int64]
    var validity: List[Bool]

    fn __init__(out self):
        self.data = List[Int64]()
        self.validity = List[Bool]()

    fn __copyinit__(out self, existing: Int64Array):
        self.data = existing.data.copy()
        self.validity = existing.validity.copy()

    fn __moveinit__(out self, deinit existing: Int64Array):
        self.data = existing.data^
        self.validity = existing.validity^

    fn append(mut self, value: Int64):
        self.data.append(value)
        self.validity.append(True)

    fn is_valid(self, index: Int) -> Bool:
        return self.validity[index]

    fn __getitem__(self, index: Int) -> Int64:
        return self.data[index]

    fn __setitem__(mut self, index: Int, value: Int64):
        self.data[index] = value

# Schema
struct Schema(Copyable, Movable):
    var field_names: List[String]
    var field_types: Dict[String, String]

    fn __init__(out self):
        self.field_names = List[String]()
        self.field_types = Dict[String, String]()

    fn __copyinit__(out self, existing: Schema):
        self.field_names = List[String]()
        for n in existing.field_names:
            self.field_names.append(n)
        self.field_types = existing.field_types.copy()

    fn __moveinit__(out self, deinit existing: Schema):
        self.field_names = existing.field_names^
        self.field_types = existing.field_types^

    fn add_field(mut self, name: String, data_type: String):
        self.field_names.append(name)
        self.field_types[name] = data_type

    fn clone(self) raises -> Schema:
        var s = Schema()
        for n in self.field_names:
            s.field_names.append(n)
        for k in self.field_types.keys():
            s.field_types[k] = self.field_types[k]
        return s^

from collections import Dict
from index import HashIndex

# ... existing ...

# Table (simplified: all columns Int64 for now)
struct Table(Copyable, Movable):
    var schema: Schema
    var columns: List[Int64Array]
    var indexes: Dict[String, HashIndex]

    fn __init__(out self, schema: Schema, num_rows: Int):
        self.schema = Schema()
        self.schema.field_names = schema.field_names.copy()
        self.schema.field_types = schema.field_types.copy()
        self.columns = List[Int64Array]()
        for _ in schema.field_names:
            self.columns.append(Int64Array())
        self.indexes = Dict[String, HashIndex]()

    fn __copyinit__(out self, existing: Table):
        self.schema = Schema()
        self.schema.field_names = existing.schema.field_names.copy()
        self.schema.field_types = existing.schema.field_types.copy()
        self.columns = List[Int64Array]()
        self.indexes = Dict[String, HashIndex]()

    fn __moveinit__(out self, deinit existing: Table):
        self.schema = existing.schema^
        self.columns = existing.columns^
        self.indexes = existing.indexes^

    fn build_index(mut self, column_name: String):
        var col_index = -1
        var i = 0
        for name in self.schema.field_names:
            if name == column_name:
                col_index = i
                break
            i += 1
        if col_index == -1:
            return
        var index = HashIndex()
        for j in range(len(self.columns[col_index].data)):
            index.insert(self.columns[col_index][j], j)
        self.indexes[column_name] = index^

    fn num_rows(self) -> Int:
        return len(self.columns[0].data) if len(self.columns) > 0 else 0

    fn snapshot(self) -> Table:
        var new_schema = Schema()
        for name in self.schema.field_names:
            new_schema.add_field(name, self.schema.field_types[name])
        var new_table = Table(new_schema, 0)
        for i in range(len(self.columns)):
            for j in range(len(self.columns[i].data)):
                new_table.columns[i].append(self.columns[i][j])
        for key in self.indexes.keys():
            new_table.indexes[key] = self.indexes[key]^
        return new_table^