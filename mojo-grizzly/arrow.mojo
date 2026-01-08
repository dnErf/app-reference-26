# Pure Mojo Arrow Implementation
# Zero-dependency columnar database core
# Based on Apache Arrow Columnar Format v1.5

from memory import memset_zero
from python import Python, PythonObject

# Variant for mixed types - simplified to avoid Python dependency
struct StringVariant(Copyable, Movable, Writable):
    var value: String
    
    fn __init__(out self, value: String = ""):
        self.value = value
    
    fn __str__(self) -> String:
        return self.value
    
    fn write_to[W: Writer](self, mut writer: W):
        writer.write(self.value)

# Alias for compatibility
alias Variant = StringVariant

# Result type for error handling
# enum Result[T: AnyType, E: AnyType]:
#     case ok(T)
#     case err(E)

# # Alias for common types
# alias ResultInt = Result[Int, String]
# alias ResultTable = Result[Table, String]

struct VariantArray(Copyable, Movable):
    var data: List[Variant]

    fn __init__(out self, size: Int):
        self.data = List[Variant]()
        for _ in range(size):
            self.data.append(Variant())

    fn __getitem__(self, index: Int) -> Variant:
        return self.data[index].copy()

    fn __setitem__(mut self, index: Int, value: Variant):
        self.data[index] = value.copy()

    fn append(mut self, value: Variant):
        self.data.append(value.copy())

struct RefCounted[T: Copyable]:
    var data: T
    var ref_count: Int

    fn __init__(out self, data: T):
        self.data = data^
        self.ref_count = 1

    fn retain(mut self):
        self.ref_count += 1

    fn release(mut self) -> Bool:
        self.ref_count -= 1
        return self.ref_count == 0

struct TablePool:
    var pool: List[Table]
    var max_size: Int

    fn __init__(out self, max_size: Int = 10):
        self.pool = List[Table]()
        self.max_size = max_size

    fn acquire(mut self, schema: Schema, num_rows: Int) -> Table:
        for i in range(len(self.pool)):
            if self.pool[i].schema.fields == schema.fields and self.pool[i].num_rows() == num_rows:
                var tbl = self.pool[i]
                self.pool.remove(i)
                return tbl^
        return Table(schema, num_rows)

    fn release(mut self, tbl: Table):
        if len(self.pool) < self.max_size:
            self.pool.append(tbl^)

fn process_large_table_in_chunks(table: Table, chunk_size: Int, func: fn(Table) -> Table) -> Table:
    # Process large table in chunks to handle memory efficiently
    var result = Table(table.schema, 0)
    var num_chunks = (table.num_rows() + chunk_size - 1) // chunk_size
    for i in range(num_chunks):
        var start = i * chunk_size
        var end = min(start + chunk_size, table.num_rows())
        # Create chunk table
        var chunk = Table(table.schema, end - start)
        for row in range(start, end):
            chunk.append_row(table.get_row_values(row))
        # Process chunk
        var processed = func(chunk)
        # Append to result
        for row in range(processed.num_rows()):
            result.append_row(processed.get_row_values(row))
    return result^

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

    fn __init__(out self, size: Int):
        self.data = List[Int64]()
        self.data.resize(size, 0)
        self.validity = List[Bool]()
        self.validity.resize(size, True)

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

    fn length(self) -> Int:
        return len(self.data)

# Float64 Primitive Array
struct Float64Array(Copyable, Movable):
    var data: List[Float64]
    var validity: List[Bool]

    fn __init__(out self):
        self.data = List[Float64]()
        self.validity = List[Bool]()

    fn __init__(out self, size: Int):
        self.data = List[Float64]()
        self.data.resize(size, 0.0)
        self.validity = List[Bool]()
        self.validity.resize(size, True)

    fn __copyinit__(out self, existing: Float64Array):
        self.data = existing.data.copy()
        self.validity = existing.validity.copy()

    fn __moveinit__(out self, deinit existing: Float64Array):
        self.data = existing.data^
        self.validity = existing.validity^

    fn append(mut self, value: Float64):
        self.data.append(value)
        self.validity.append(True)

    fn is_valid(self, index: Int) -> Bool:
        return self.validity[index]

    fn __getitem__(self, index: Int) -> Float64:
        return self.data[index]

    fn __setitem__(mut self, index: Int, value: Float64):
        self.data[index] = value

    fn length(self) -> Int:
        return len(self.data)

# String Primitive Array
struct StringArray(Copyable, Movable):
    var data: List[String]
    var validity: List[Bool]

    fn __init__(out self):
        self.data = List[String]()
        self.validity = List[Bool]()

    fn __init__(out self, size: Int):
        self.data = List[String]()
        self.data.resize(size, "")
        self.validity = List[Bool]()
        self.validity.resize(size, True)

    fn __copyinit__(out self, existing: StringArray):
        self.data = existing.data.copy()
        self.validity = existing.validity.copy()

    fn __moveinit__(out self, deinit existing: StringArray):
        self.data = existing.data^
        self.validity = existing.validity^

    fn append(mut self, value: String):
        self.data.append(value)
        self.validity.append(True)

    fn is_valid(self, index: Int) -> Bool:
        return self.validity[index]

    fn __getitem__(self, index: Int) -> String:
        return self.data[index]

    fn __setitem__(mut self, index: Int, value: String):
        self.data[index] = value

    fn length(self) -> Int:
        return len(self.data)

# Field for Schema
struct Field(Copyable, Movable):
    var name: String
    var data_type: String

    fn __init__(out self, name: String, data_type: String):
        self.name = name
        self.data_type = data_type

    fn __copyinit__(out self, existing: Field):
        self.name = existing.name
        self.data_type = existing.data_type

    fn __moveinit__(out self, deinit existing: Field):
        self.name = existing.name^
        self.data_type = existing.data_type^

# Schema
struct Schema(Copyable, Movable):
    var fields: List[Field]

    fn __init__(out self):
        self.fields = List[Field]()

    fn __copyinit__(out self, existing: Schema):
        self.fields = List[Field]()
        for f in existing.fields:
            self.fields.append(f.copy())

    fn __moveinit__(out self, deinit existing: Schema):
        self.fields = existing.fields^

    fn add_field(mut self, name: String, data_type: String):
        self.fields.append(Field(name, data_type))

    fn clone(self) raises -> Schema:
        var s = Schema()
        for f in self.fields:
            s.fields.append(f.copy())
        return s^

from collections import Dict
from index import HashIndex, BTreeIndex

# ... existing ...

# Table (simplified: all columns Int64 for now)
struct Table(Copyable, Movable):
    var schema: Schema
    var columns: List[Int64Array]
    var mixed_columns: List[VariantArray]  # For mixed types
    var indexes: Dict[String, BTreeIndex]
    var row_versions: List[Int64]  # MVCC: version for each row

    fn __init__(out self, schema: Schema, num_rows: Int):
        self.schema = Schema()
        for f in schema.fields:
            self.schema.fields.append(f.copy())
        self.columns = List[Int64Array]()
        self.mixed_columns = List[VariantArray]()
        for f in schema.fields:
            if f.data_type == "mixed":
                self.mixed_columns.append(VariantArray(num_rows))
            else:
                self.columns.append(Int64Array(num_rows))
        self.indexes = Dict[String, BTreeIndex]()
        self.row_versions = List[Int64](capacity=num_rows)
        for _ in range(num_rows):
            self.row_versions.append(1)  # Initial version

    fn __copyinit__(out self, existing: Table):
        self.schema = Schema()
        for f in existing.schema.fields:
            self.schema.fields.append(f.copy())
        self.columns = List[Int64Array]()
        for col in existing.columns:
            self.columns.append(col.copy())
        self.mixed_columns = List[VariantArray]()
        for col in existing.mixed_columns:
            self.mixed_columns.append(col.copy())
        self.indexes = Dict[String, BTreeIndex]()
        for key in existing.indexes.keys():
            try:
                self.indexes[key] = existing.indexes[key].copy()
            except:
                pass
        self.row_versions = List[Int64]()
        for v in existing.row_versions:
            self.row_versions.append(v)

    fn __moveinit__(out self, deinit existing: Table):
        self.schema = existing.schema^
        self.columns = existing.columns^
        self.mixed_columns = existing.mixed_columns^
        self.indexes = existing.indexes^
        self.row_versions = existing.row_versions^

    fn build_index(mut self, column_name: String):
        var col_index = -1
        var i = 0
        for f in self.schema.fields:
            if f.name == column_name:
                col_index = i
                break
            i += 1
        if col_index == -1:
            return
        var index = BTreeIndex()
        for j in range(len(self.columns[col_index].data)):
            index.insert(self.columns[col_index][j], j)
        self.indexes[column_name] = index^

    fn num_rows(self) -> Int:
        return len(self.columns[0].data) if len(self.columns) > 0 else 0

    # MVCC functions
    fn get_row_version(self, row: Int) -> Int64:
        return self.row_versions[row]

    fn set_row_version(mut self, row: Int, version: Int64):
        self.row_versions[row] = version

    fn increment_version(mut self, row: Int):
        self.row_versions[row] += 1

    fn append_row(mut self, values: List[Int64]):
        for i in range(len(values)):
            self.columns[i].append(values[i])
        self.row_versions.append(1)  # New row starts at version 1

    fn append_mixed_row(mut self, int_values: List[Int64], mixed_values: List[Variant]):
        # Append int64 values
        for i in range(len(int_values)):
            self.columns[i].append(int_values[i])
        
        # Append mixed values
        for i in range(len(mixed_values)):
            self.mixed_columns[i].append(mixed_values[i])
        
        self.row_versions.append(1)  # New row starts at version 1

    fn get_row_values(self, row: Int) -> List[Int64]:
        var values = List[Int64]()
        for col in self.columns:
            values.append(col[row])
        return values

    fn snapshot(self) -> Table:
        var new_schema = Schema()
        for f in self.schema.fields:
            new_schema.add_field(f.name, f.data_type)
        var new_table = Table(new_schema, 0)
        for i in range(len(self.columns)):
            for j in range(len(self.columns[i].data)):
                new_table.columns[i].append(self.columns[i][j])
        for key in self.indexes.keys():
            new_table.indexes[key] = self.indexes[key]^
        return new_table^

    fn slice(self, start: Int, end: Int) -> TableView:
        # Zero-copy slice using view
        return TableView(self, start, end)

struct TableView(Copyable, Movable):
    var schema: Schema
    var columns: List[Int64Array]  # References to original
    var start: Int
    var end: Int

    fn __init__(out self, table: Table, start: Int, end: Int):
        self.schema = Schema()
        for f in table.schema.fields:
            self.schema.fields.append(f.copy())
        self.columns = List[Int64Array]()
        for col in table.columns:
            self.columns.append(col)  # Reference
        self.start = start
        self.end = end

    fn num_rows(self) -> Int:
        return self.end - self.start

    fn get_row(self, index: Int) -> List[Int64]:
        var row = List[Int64]()
        for col in self.columns:
            row.append(col[self.start + index])
        return row