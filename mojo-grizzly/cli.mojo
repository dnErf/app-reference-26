# CLI for Mojo Arrow Database
# Run SQL from .sql files

import sys
import os

from arrow import DataType, Schema, Table
from query import execute_query
from formats import read_jsonl
from pl import create_function
from ipc import serialize_table, deserialize_table

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
        # SAVE 'file' - serialize to buffer
        let ser_buf = serialize_table(global_table)
        print("Table serialized to buffer of size", ser_buf.size)
    elif sql.startswith("LOAD") and not sql.startswith("LOAD JSONL"):
        # LOAD 'file' - deserialize from buffer (demo: assume same buffer)
        # For demo, if we have a saved buffer, but since no, skip
        print("LOAD not implemented for files yet")
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