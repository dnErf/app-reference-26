# Format Interoperability for Mojo Arrow Database
# Readers for JSONL, etc.

from arrow import Schema, Table, Int64Array

# Simple JSON parser (numbers and strings only)
struct JsonValue:
    enum Type:
        number
        string
    var type: Type
    var number: Int64
    var string_val: String

fn parse_json(json: String) -> Dict[String, JsonValue]:
    # Very simple parser: {"key": value, "key2": "string"}
    var dict = Dict[String, JsonValue]()
    let stripped = json.strip().strip("{}")
    let pairs = stripped.split(",")
    for pair in pairs:
        let kv = pair.split(":")
        if len(kv) == 2:
            let key = kv[0].strip().strip('"')
            let val_str = kv[1].strip()
            if val_str.startswith('"'):
                let str_val = val_str.strip('"')
                dict[key] = JsonValue(JsonValue.Type.string, 0, str_val)
            else:
                let num = atol(val_str)
                dict[key] = JsonValue(JsonValue.Type.number, num, "")
    return dict

# Read JSONL from string content
fn read_jsonl(content: String) -> Table:
    var lines = content.split("\n")
    if len(lines) == 0:
        return Table(Schema(), 0)

    # Parse first line for schema
    let first_dict = parse_json(lines[0])
    var schema = Schema()
    for key in first_dict.keys():
        # Assume all numbers for now
        schema.add_field(key[], DataType.int64)

    # Create table
    var table = Table(schema, len(lines))
    for i in range(len(lines)):
        let line = lines[i]
        if line.strip() == "":
            continue
        let dict = parse_json(line)
        for j in range(len(schema.fields)):
            let key = schema.fields[j].name
            if key in dict:
                let val = dict[key]
                if val.type == JsonValue.Type.number:
                    table.columns[j][i] = val.number
    return table