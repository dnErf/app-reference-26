# IPC Serialization for Mojo Arrow Database
# Serialize/deserialize Tables to/from buffers

from arrow import Buffer, Table, Schema, DataType, Int64Array
from memory import memcpy

fn serialize_table(table: Table) -> Buffer:
    # Calculate total size
    var total_size = 0
    # Schema: num_fields (4), then for each: name_len(4), name, type(1)
    total_size += 4
    for field in table.schema.fields:
        total_size += 4 + len(field.name) + 1
    # Columns: for each: length(8), null_count(8), validity_size(8), validity_data, data_size(8), data
    for col in table.columns:
        total_size += 8 + 8 + 8 + col.validity.size + 8 + col.data.size

    var buf = Buffer(total_size)
    var pos = 0

    # Write schema
    buf.data.bitcast[Int32]()[pos//4] = len(table.schema.fields)
    pos += 4
    for field in table.schema.fields:
        let name_bytes = field.name.as_bytes()
        buf.data.bitcast[Int32]()[pos//4] = len(name_bytes)
        pos += 4
        memcpy(buf.data.offset(pos), name_bytes.data, len(name_bytes))
        pos += len(name_bytes)
        buf[pos] = field.data_type.value  # Assume enum value 0 for int64
        pos += 1

    # Write columns
    for col in table.columns:
        buf.data.bitcast[Int64]()[pos//8] = col.length
        pos += 8
        buf.data.bitcast[Int64]()[pos//8] = col.null_count
        pos += 8
        buf.data.bitcast[Int64]()[pos//8] = col.validity.size
        pos += 8
        memcpy(buf.data.offset(pos), col.validity.data, col.validity.size)
        pos += col.validity.size
        buf.data.bitcast[Int64]()[pos//8] = col.data.size
        pos += 8
        memcpy(buf.data.offset(pos), col.data.data, col.data.size)
        pos += col.data.size

    return buf

fn deserialize_table(buf: Buffer) -> Table:
    var pos = 0

    # Read schema
    let num_fields = buf.data.bitcast[Int32]()[pos//4]
    pos += 4
    var schema = Schema()
    for _ in range(num_fields):
        let name_len = buf.data.bitcast[Int32]()[pos//4]
        pos += 4
        var name = String(buf.data.offset(pos), name_len)
        pos += name_len
        let type_val = buf[pos]
        pos += 1
        # Assume int64
        schema.add_field(name, DataType.int64)

    # Read columns
    var columns = List[Int64Array]()
    for _ in range(num_fields):
        let length = buf.data.bitcast[Int64]()[pos//8]
        pos += 8
        let null_count = buf.data.bitcast[Int64]()[pos//8]
        pos += 8
        let validity_size = buf.data.bitcast[Int64]()[pos//8]
        pos += 8
        var validity = Buffer(validity_size)
        memcpy(validity.data, buf.data.offset(pos), validity_size)
        pos += validity_size
        let data_size = buf.data.bitcast[Int64]()[pos//8]
        pos += 8
        var data = Buffer(data_size)
        memcpy(data.data, buf.data.offset(pos), data_size)
        pos += data_size
        var col = Int64Array(length)
        col.null_count = null_count
        col.validity = validity
        col.data = data
        columns.append(col)

    var table = Table(schema, 0)
    table.columns = columns
    return table