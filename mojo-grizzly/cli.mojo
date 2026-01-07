# CLI for Mojo Arrow Database
# Run SQL from .sql files

import sys
import os

from arrow import DataType, Schema, Table
from query import execute_query
from formats import read_jsonl, write_parquet, write_avro, read_avro, read_parquet
from pl import create_function
from ipc import serialize_table, deserialize_table
from extensions.column_store import ColumnStoreConfig, init as init_column_store
from extensions.row_store import RowStoreConfig, init as init_row_store
from extensions.graph import add_node, add_edge, init as init_graph
from extensions.blockchain import append_block, get_head, save_chain, init as init_blockchain
from extensions.lakehouse import create_lake_table, insert_into_lake, optimize_lake, init as init_lakehouse

# Global database state
var global_table = Table(Schema(), 0)
var tables = Dict[String, Table]()
var command_history = List[String]()

fn execute_sql(sql: String):
    command_history.append(sql)
    if sql.startswith("CREATE FUNCTION"):
        create_function(sql)
        print("Function created")
    elif sql.upper().startswith("LOAD EXTENSION"):
        let ext_start = sql.find("'")
        let ext_end = sql.rfind("'")
        if ext_start != -1 and ext_end != -1:
            let ext_name = sql[ext_start+1:ext_end]
            if ext_name == "column_store":
                init_column_store()
            elif ext_name == "row_store":
                init_row_store()
            elif ext_name == "graph":
                init_graph()
            elif ext_name == "blockchain":
                init_blockchain()
            elif ext_name == "lakehouse":
                init_lakehouse()
            else:
                print("Unknown extension:", ext_name)
    elif sql.startswith("LOAD JSONL"):
        # LOAD JSONL 'content'
        let content_start = sql.find("'")
        let content_end = sql.rfind("'")
        if content_start != -1 and content_end != -1:
            let content = sql[content_start+1:content_end]
            global_table = read_jsonl(content)
            print("Loaded table from JSONL")
    elif sql.startswith("SAVE"):
        # SAVE 'file' - save to file
        let start = sql.find("'")
        let end = sql.rfind("'")
        if start != -1 and end != -1:
            let filename = sql[start+1:end]
            if ColumnStoreConfig.is_default:
                # Save as Parquet .grz
                let grz_file = filename + ".grz"
                write_parquet(global_table, grz_file)
                print("Table saved as Parquet to", grz_file)
            elif RowStoreConfig.is_default:
                # Save as AVRO .grz
                let grz_file = filename + ".grz"
                let data = write_avro(global_table)
                # Write data to file
                let file = open(grz_file, "w")
                file.write(data)
                file.close()
                print("Table saved as AVRO to", grz_file)
            else:
                # Serialize to buffer (memory)
                let ser_buf = serialize_table(global_table)
                print("Table serialized to buffer of size", ser_buf.size)
    elif sql.startswith("LOAD") and not sql.startswith("LOAD JSONL") and not sql.startswith("LOAD EXTENSION"):
        # LOAD 'file' - load from file
        let start = sql.find("'")
        let end = sql.rfind("'")
        if start != -1 and end != -1:
            let filename = sql[start+1:end]
            if ColumnStoreConfig.is_default:
                # Load from Parquet .grz
                let grz_file = filename + ".grz"
                global_table = read_parquet(grz_file)
                print("Table loaded from Parquet", grz_file)
            elif RowStoreConfig.is_default:
                # Load from AVRO .grz
                let grz_file = filename + ".grz"
                global_table = read_avro(grz_file)
                print("Table loaded from AVRO", grz_file)
            else:
                # Auto-detect format
                if filename.endswith(".jsonl"):
                    global_table = read_jsonl(filename)
                    print("Auto-loaded JSONL")
                elif filename.endswith(".parquet"):
                    global_table = read_parquet(filename)
                    print("Auto-loaded Parquet")
                else:
                    print("Unknown format")
    elif sql.startswith("SELECT"):
        let result = execute_query(global_table, sql)
        print("Query result:")
        for i in range(result.columns[0].length):
            print("Row", i, ": id =", result.columns[0][i], ", value =", result.columns[1][i])
    elif sql.startswith("LOAD EXTENSION"):
        # LOAD EXTENSION 'name'
        let start = sql.find("'")
        let end = sql.rfind("'")
        if start != -1 and end != -1:
            let name = sql[start+1:end]
            load_extension(name)
    elif sql.startswith("UNLOAD EXTENSION"):
        # UNLOAD EXTENSION 'name'
        let start = sql.find("'")
        let end = sql.rfind("'")
        if start != -1 and end != -1:
            let name = sql[start+1:end]
            unload_extension(name)
    elif sql.startswith("CREATE TABLE"):
        # CREATE TABLE name (cols) STORAGE type
        let parts = sql.split(" ")
        if len(parts) >= 4:
            let table_name = parts[2]
            let cols_start = sql.find("(")
            let cols_end = sql.find(")")
            if cols_start != -1 and cols_end != -1:
                let cols_str = sql[cols_start+1:cols_end]
                let cols = cols_str.split(",")
                var schema_fields = List[DataType]()
                var field_names = List[String]()
                for col in cols:
                    let col_parts = col[].strip().split(" ")
                    if len(col_parts) == 2:
                        let name = col_parts[0]
                        let type_str = col_parts[1].upper()
                        var dtype: DataType
                        if type_str == "INT":
                            dtype = DataType.int32()
                        elif type_str == "STRING":
                            dtype = DataType.string()
                        else:
                            dtype = DataType.string()  # default
                        field_names.append(name)
                        schema_fields.append(dtype)
                let schema = Schema(field_names, schema_fields)
                tables[table_name] = Table(schema, 0)
                global_table = tables[table_name]
                print("Table", table_name, "created with schema")
        else:
            print("Invalid CREATE TABLE syntax")
    elif sql.startswith("ADD NODE"):
        # ADD NODE id 'properties'
        let parts = sql.split(" ")
        if len(parts) >= 4:
            let node_id = atol(parts[2])
            let props_start = sql.find("'")
            let props_end = sql.rfind("'")
            if props_start != -1 and props_end != -1:
                let properties = sql[props_start+1:props_end]
                add_node(node_id, properties)
                print("Node", node_id, "added")
        else:
            print("Invalid ADD NODE syntax")
    elif sql.startswith("ADD EDGE"):
        # ADD EDGE from to 'label' 'properties'
        let parts = sql.split(" ")
        if len(parts) >= 6:
            let from_id = atol(parts[2])
            let to_id = atol(parts[3])
            let label_start = sql.find("'")
            let label_end = sql.find("'", label_start+1)
            let props_start = sql.find("'", label_end+1)
            let props_end = sql.rfind("'")
            if label_start != -1 and label_end != -1 and props_start != -1 and props_end != -1:
                let label = sql[label_start+1:label_end]
                let properties = sql[props_start+1:props_end]
                add_edge(from_id, to_id, label, properties)
                print("Edge from", from_id, "to", to_id, "added")
        else:
            print("Invalid ADD EDGE syntax")
    elif sql.startswith("APPEND BLOCK"):
        # APPEND BLOCK - append current table as block
        append_block(global_table)
    elif sql.startswith("GET HEAD"):
        # GET HEAD - get latest block
        let head = get_head()
        print("Head block hash:", head.hash)
    elif sql.startswith("SAVE CHAIN"):
        # SAVE CHAIN 'file'
        let start = sql.find("'")
        let end = sql.rfind("'")
        if start != -1 and end != -1:
            let filename = sql[start+1:end]
            save_chain(filename)
    elif sql.startswith("CREATE LAKE TABLE"):
        # CREATE LAKE TABLE name (cols)
        # Stub: parse schema
        create_lake_table("test", Schema())
    elif sql.startswith("INSERT INTO LAKE"):
        # INSERT INTO LAKE table VALUES (vals)
        let parts = sql.split(" ")
        if len(parts) >= 5:
            let table_name = parts[3]
            let vals_start = sql.find("(")
            let vals_end = sql.find(")")
            if vals_start != -1 and vals_end != -1:
                let vals_str = sql[vals_start+1:vals_end]
                let vals = vals_str.split(",")
                var values = List[String]()
                for v in vals:
                    values.append(v[].strip().strip("'\""))
                insert_into_lake(table_name, values)
                print("Inserted into lake table", table_name)
        else:
            print("Invalid INSERT INTO LAKE syntax")
    elif sql.startswith("SELECT") and "AS OF" in sql:
        # SELECT ... AS OF timestamp
        let parts = sql.split("AS OF")
        let timestamp = parts[1].strip().strip("'\"")
        # Stub: query lakehouse
        print("Time travel query executed for", timestamp)
    elif sql.startswith("OPTIMIZE"):
        # OPTIMIZE table
        let parts = sql.split(" ")
        if len(parts) >= 2:
            let table_name = parts[1]
            optimize_lake(table_name)
            print("Optimized lake table", table_name)
        else:
            print("Invalid OPTIMIZE syntax")
    else:
        print("Unsupported SQL:", sql)

fn load_extension(name: String):
    # Basic loader that calls extension init routines where available
    if name == "column_store":
        init_column_store()
    elif name == "row_store":
        init_row_store()
    elif name == "graph":
        init_graph()
    elif name == "blockchain":
        init_blockchain()
    elif name == "lakehouse":
        init_lakehouse()
    else:
        print("Unknown extension:", name)

fn unload_extension(name: String):
    # Basic unload: toggle configs off where applicable
    if name == "column_store":
        ColumnStoreConfig.is_default = False
        print("Column store unloaded")
    elif name == "row_store":
        RowStoreConfig.is_default = False
        print("Row store unloaded")
    else:
        print("Extension unloaded:", name)

fn main():
    if len(sys.argv) == 1:
        repl()
    elif len(sys.argv) == 2:
        let file_path = sys.argv[1]
        let content = os.read(file_path)
        let sqls = content.split(";")
        for sql in sqls:
            let trimmed = sql.strip()
            if trimmed != "":
                execute_sql(trimmed)
    else:
        print("Usage: mojo cli.mojo [sql_file]")

fn tab_complete(input: String) -> List[String]:
    var suggestions = List[String]()
    if input.startswith("SELECT"):
        suggestions.append("SELECT * FROM")
        suggestions.append("SELECT COUNT(*) FROM")
    elif input.startswith("LOAD EXTENSION"):
        suggestions.append("LOAD EXTENSION column_store")
        suggestions.append("LOAD EXTENSION row_store")
        suggestions.append("LOAD EXTENSION graph")
        suggestions.append("LOAD EXTENSION blockchain")
        suggestions.append("LOAD EXTENSION lakehouse")
    elif input.startswith("CREATE"):
        suggestions.append("CREATE TABLE test (id INT, name STRING)")
        suggestions.append("CREATE FUNCTION")
    elif input.startswith("ADD"):
        suggestions.append("ADD NODE 1 '{\"prop\": \"value\"}'")
        suggestions.append("ADD EDGE 1 2 'label' '{\"prop\": \"value\"}'")
    elif input.startswith("INSERT"):
        suggestions.append("INSERT INTO LAKE test VALUES (1, 'name')")
    elif input.startswith("OPTIMIZE"):
        suggestions.append("OPTIMIZE test")
    # More completions added
    return suggestions

fn repl():
    print("Grizzly DB REPL. Type 'exit' to quit.")
    while True:
        print("grizzly> ", end="")
        let input = input()  # Assume input function
        if input == "exit":
            break
        if input == "":
            continue
        # Handle tab for completion
        if "\t" in input:
            let prefix = input.split("\t")[0]
            let suggestions = tab_complete(prefix)
            print("Suggestions:")
            for s in suggestions:
                print("  ", s)
            continue
        execute_sql(input)