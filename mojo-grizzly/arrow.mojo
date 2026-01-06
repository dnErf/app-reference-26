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
struct Buffer:
    var data: Pointer[mut UInt8]
    var size: Int

    fn __init__(inout self, size: Int):
        self.data = Pointer[mut UInt8].alloc(size)
        self.size = size
        # Initialize to zero for safety
        memset_zero(self.data, size)

    fn deinit(self):
        self.data.free()

    fn __copyinit__(inout self, other: Buffer):
        self.size = other.size
        self.data = Pointer[UInt8].alloc(self.size)
        for i in range(self.size):
            self.data[i] = other.data[i]

    fn __moveinit__(inout self, owned other: Buffer):
        self.size = other.size
        self.data = other.data
        other.data = Pointer[UInt8]()
        other.size = 0

    fn __getitem__(self, index: Int) -> UInt8:
        return self.data[index]

    fn __setitem__(inout self, index: Int, value: UInt8):
        self.data[index] = value

# Validity bitmap helper
fn is_valid(validity: Buffer, index: Int) -> Bool:
    if validity.size == 0:
        return True
    let byte_index = index // 8
    let bit_index = index % 8
    return (validity[byte_index] & (1 << bit_index)) != 0

fn set_valid(inout validity: Buffer, index: Int, valid: Bool):
    let byte_index = index // 8
    let bit_index = index % 8
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
struct Int64Array:
    var length: Int
    var null_count: Int
    var validity: Buffer
    var data: Buffer

    fn __init__(inout self, length: Int):
        self.length = length
        self.null_count = 0
        # Validity bitmap: 1 bit per element, rounded up to bytes
        let validity_size = (length + 7) // 8
        self.validity = Buffer(validity_size)
        # Data: 8 bytes per Int64
        self.data = Buffer(length * 8)

    fn is_valid(self, index: Int) -> Bool:
        return is_valid(self.validity, index)

    fn __getitem__(self, index: Int) -> Int64:
        if not self.is_valid(index):
            return 0  # Or raise error, but for now
        let offset = index * 8
        return self.data.data.bitcast[Int64]()[index]

    fn __setitem__(inout self, index: Int, value: Int64):
        let offset = index * 8
        self.data.data.bitcast[Int64]()[index] = value
        if not self.is_valid(index):
            self.null_count -= 1
        set_valid(self.validity, index, True)

    fn set_null(inout self, index: Int):
        if self.is_valid(index):
            self.null_count += 1
        set_valid(self.validity, index, False)

    fn __copyinit__(inout self, other: Int64Array):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity
        self.data = other.data

    fn __moveinit__(inout self, owned other: Int64Array):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity^
        self.data = other.data^

# String Array (Variable Binary)
struct StringArray:
    var length: Int
    var null_count: Int
    var validity: Buffer
    var offsets: Buffer  # Int32 offsets
    var data: Buffer

    fn __init__(inout self, length: Int):
        self.length = length
        self.null_count = 0
        let validity_size = (length + 7) // 8
        self.validity = Buffer(validity_size)
        # Offsets: (length + 1) * 4 bytes
        self.offsets = Buffer((length + 1) * 4)
        # Data: start small, grow as needed
        self.data = Buffer(1024)  # arbitrary

    fn is_valid(self, index: Int) -> Bool:
        return is_valid(self.validity, index)

    fn __getitem__(self, index: Int) -> String:
        if not self.is_valid(index):
            return ""
        let start = self.offsets.data.bitcast[Int32]()[index]
        let end = self.offsets.data.bitcast[Int32]()[index + 1]
        let size = end - start
        let ptr = self.data.data.offset(start)
        return String(ptr, size)

    fn __setitem__(inout self, index: Int, value: String):
        # Simple append, assume no overwrite
        let current_end = self.offsets.data.bitcast[Int32]()[self.length]
        let value_bytes = value.as_bytes()
        let value_size = len(value_bytes)
        # Grow data if needed
        if current_end + value_size > self.data.size:
            # For simplicity, double size
            let new_size = max(self.data.size * 2, current_end + value_size)
            var new_data = Buffer(new_size)
            memcpy(new_data.data, self.data.data, self.data.size)
            self.data = new_data
        memcpy(self.data.data.offset(current_end), value_bytes.data, value_size)
        self.offsets.data.bitcast[Int32]()[index] = current_end
        self.offsets.data.bitcast[Int32]()[index + 1] = current_end + value_size
        if not self.is_valid(index):
            self.null_count -= 1
        set_valid(self.validity, index, True)

    fn set_null(inout self, index: Int):
        if self.is_valid(index):
            self.null_count += 1
        set_valid(self.validity, index, False)

    fn __copyinit__(inout self, other: StringArray):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity
        self.offsets = other.offsets
        self.data = other.data

    fn __moveinit__(inout self, owned other: StringArray):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity^
        self.offsets = other.offsets^
        self.data = other.data^

# Float64 Primitive Array
struct Float64Array:
    var length: Int
    var null_count: Int
    var validity: Buffer
    var data: Buffer

    fn __init__(inout self, length: Int):
        self.length = length
        self.null_count = 0
        # Validity bitmap: 1 bit per element, rounded up to bytes
        let validity_size = (length + 7) // 8
        self.validity = Buffer(validity_size)
        # Data: 8 bytes per Float64
        self.data = Buffer(length * 8)

    fn is_valid(self, index: Int) -> Bool:
        return is_valid(self.validity, index)

    fn __getitem__(self, index: Int) -> Float64:
        if not self.is_valid(index):
            return 0.0
        let offset = index * 8
        return self.data.data.bitcast[Float64]()[index]

    fn __setitem__(inout self, index: Int, value: Float64):
        let offset = index * 8
        self.data.data.bitcast[Float64]()[index] = value
        if not self.is_valid(index):
            self.null_count -= 1
        set_valid(self.validity, index, True)

    fn set_null(inout self, index: Int):
        if self.is_valid(index):
            self.null_count += 1
        set_valid(self.validity, index, False)

    fn __copyinit__(inout self, other: Float64Array):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity
        self.data = other.data

    fn __moveinit__(inout self, owned other: Float64Array):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity^
        self.data = other.data^

# Date32 Array (days since 1970-01-01 as Int32)
struct Date32Array:
    var length: Int
    var null_count: Int
    var validity: Buffer
    var data: Buffer

    fn __init__(inout self, length: Int):
        self.length = length
        self.null_count = 0
        let validity_size = (length + 7) // 8
        self.validity = Buffer(validity_size)
        self.data = Buffer(length * 4)

    fn is_valid(self, index: Int) -> Bool:
        return is_valid(self.validity, index)

    fn __getitem__(self, index: Int) -> Int32:
        if not self.is_valid(index):
            return 0
        return self.data.data.bitcast[Int32]()[index]

    fn __setitem__(inout self, index: Int, value: Int32):
        self.data.data.bitcast[Int32]()[index] = value
        if not self.is_valid(index):
            self.null_count -= 1
        set_valid(self.validity, index, True)

    fn set_null(inout self, index: Int):
        if self.is_valid(index):
            self.null_count += 1
        set_valid(self.validity, index, False)

    fn __copyinit__(inout self, other: Date32Array):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity
        self.data = other.data

    fn __moveinit__(inout self, owned other: Date32Array):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity^
        self.data = other.data^

# Timestamp Array (microseconds since 1970-01-01 as Int64)
struct TimestampArray:
    var length: Int
    var null_count: Int
    var validity: Buffer
    var data: Buffer

    fn __init__(inout self, length: Int):
        self.length = length
        self.null_count = 0
        let validity_size = (length + 7) // 8
        self.validity = Buffer(validity_size)
        self.data = Buffer(length * 8)

    fn is_valid(self, index: Int) -> Bool:
        return is_valid(self.validity, index)

    fn __getitem__(self, index: Int) -> Int64:
        if not self.is_valid(index):
            return 0
        return self.data.data.bitcast[Int64]()[index]

    fn __setitem__(inout self, index: Int, value: Int64):
        self.data.data.bitcast[Int64]()[index] = value
        if not self.is_valid(index):
            self.null_count -= 1
        set_valid(self.validity, index, True)

    fn set_null(inout self, index: Int):
        if self.is_valid(index):
            self.null_count += 1
        set_valid(self.validity, index, False)

    fn __copyinit__(inout self, other: TimestampArray):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity
        self.data = other.data

    fn __moveinit__(inout self, owned other: TimestampArray):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity^
        self.data = other.data^

# List Array (variable-length lists of Int64)
struct ListArray:
    var length: Int
    var null_count: Int
    var validity: Buffer
    var offsets: Buffer  # Int32 offsets
    var values: Int64Array

    fn __init__(inout self, length: Int):
        self.length = length
        self.null_count = 0
        let validity_size = (length + 7) // 8
        self.validity = Buffer(validity_size)
        self.offsets = Buffer((length + 1) * 4)
        self.values = Int64Array(0)  # Start empty

    fn is_valid(self, index: Int) -> Bool:
        return is_valid(self.validity, index)

    fn __copyinit__(inout self, other: ListArray):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity
        self.offsets = other.offsets
        self.values = other.values

    fn __moveinit__(inout self, owned other: ListArray):
        self.length = other.length
        self.null_count = other.null_count
        self.validity = other.validity^
        self.offsets = other.offsets^
        self.values = other.values^

# Schema
struct Field:
    var name: String
    var data_type: String

struct Schema:
    var fields: List[Field]

    fn __init__(inout self):
        self.fields = List[Field]()

    fn add_field(inout self, name: String, data_type: String):
        self.fields.append(Field(name, data_type))

    fn __copyinit__(inout self, other: Schema):
        self.fields = other.fields

    fn __moveinit__(inout self, owned other: Schema):
        self.fields = other.fields^

from collections import Dict
from index import HashIndex

# ... existing ...

# Table (simplified: all columns Int64 for now)
struct Table:
    var schema: Schema
    var columns: List[Int64Array]
    var indexes: Dict[String, HashIndex]

    fn __init__(inout self, schema: Schema, num_rows: Int):
        self.schema = schema
        self.columns = List[Int64Array]()
        for field in schema.fields:
            self.columns.append(Int64Array(num_rows))
        self.indexes = Dict[String, HashIndex]()

    fn build_index(inout self, column_name: String):
        var col_index = -1
        for i in range(len(self.schema.fields)):
            if self.schema.fields[i].name == column_name:
                col_index = i
                break
        if col_index == -1:
            return
        var index = HashIndex()
        for i in range(self.columns[col_index].length):
            index.insert(self.columns[col_index][i], i)
        self.indexes[column_name] = index

    fn num_rows(self) -> Int:
        return self.columns[0].length if len(self.columns) > 0 else 0

    fn snapshot(self) -> Table:
        # Deep copy for ACID snapshots
        var new_schema = Schema()
        for field in self.schema.fields:
            new_schema.add_field(field.name, field.data_type)
        var new_table = Table(new_schema, self.columns[0].length)
        for i in range(len(self.columns)):
            for j in range(self.columns[i].length):
                new_table.columns[i][j] = self.columns[i][j]
        # Copy indexes
        for key in self.indexes.keys():
            new_table.indexes[key] = self.indexes[key]  # Shallow for now
        return new_table

    fn __copyinit__(inout self, other: Table):
        self.schema = other.schema
        self.columns = other.columns
        self.indexes = other.indexes

    fn __moveinit__(inout self, owned other: Table):
        self.schema = other.schema^
        self.columns = other.columns^
        self.indexes = other.indexes^