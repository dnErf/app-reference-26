# CLI for Mojo Arrow Database
# Run SQL from .sql files

import sys
import os

from arrow import DataType, Schema, Table
from query import execute_query
from formats import read_jsonl, write_parquet
from pl import create_function
from ipc import serialize_table, deserialize_table
from extensions.column_store import ColumnStoreConfig
from extensions.row_store import RowStoreConfig
from extensions.graph import add_node, add_edge
from extensions.blockchain import append_block, get_head, save_chain
from extensions.lakehouse import create_lake_table

# Global database state (simple: one table)
var global_table = Table(Schema(), 0)
var command_history = List[String]()

fn execute_sql(sql: String):
    command_history.append(sql)
    if sql.startswith("CREATE FUNCTION"):
        create_function(sql)
        print("Function created")
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
                # Stub: write data to file
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
    elif sql.startswith("CREATE TABLE"):
        # CREATE TABLE name (cols) STORAGE type
        # Placeholder
        print("CREATE TABLE not fully implemented")
    elif sql.startswith("ADD NODE"):
        # ADD NODE id 'properties'
        # Stub: parse and add
        print("ADD NODE not implemented yet")
    elif sql.startswith("ADD EDGE"):
        # ADD EDGE from to 'label' 'properties'
        # Stub
        print("ADD EDGE not implemented yet")
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
        # Stub
        print("INSERT INTO LAKE not implemented yet")
    elif sql.startswith("SELECT") and "AS OF" in sql:
        # SELECT ... AS OF timestamp
        let parts = sql.split("AS OF")
        let timestamp = parts[1].strip().strip("'\"")
        # Stub: query lakehouse
        print("Time travel query executed for", timestamp)
    elif sql.startswith("OPTIMIZE"):
        # OPTIMIZE table
        # Stub
        print("OPTIMIZE not implemented yet")
    else:
        print("Unsupported SQL:", sql)

fn load_extension(name: String):
    if name == "secret":
        from extensions.secret import init
        init()
    elif name == "blockchain":
        from extensions.blockchain import init
        init()
    elif name == "graph":
        from extensions.graph import init
        init()
    elif name == "rest_api":
        from extensions.rest_api import init
        init()
    elif name == "column_store":
        from extensions.column_store import init
        init()
    elif name == "row_store":
        from extensions.row_store import init
        init()
    else:
        print("Unknown extension:", name)

fn main():
    if len(sys.argv) != 2:
        print("Usage: mojo cli.mojo <sql_file>")
        return

    let file_path = sys.argv[1]
    let content = os.read(file_path)
    let sqls = content.split(";")
    for sql in sqls:
        let trimmed = sql.strip()
        if trimmed != "":
            execute_sql(trimmed)

fn tab_complete(input: String) -> List[String]:
    var suggestions = List[String]()
    if input.startswith("SELECT"):
        suggestions.append("SELECT * FROM")
    elif input.startswith("LOAD EXTENSION"):
        suggestions.append("LOAD EXTENSION column_store")
        suggestions.append("LOAD EXTENSION row_store")
        suggestions.append("LOAD EXTENSION graph")
        suggestions.append("LOAD EXTENSION blockchain")
        suggestions.append("LOAD EXTENSION lakehouse")
    # Stub: more completions
    return suggestions