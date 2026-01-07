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
from extensions.rest_api import init as init_rest_api
from network import add_replica
from extensions.ml import init as init_ml
from extensions.scm import init as init_scm
from extensions.packaging import init as init_packaging, package_init, add_python_dep, add_mojo_file, package_build, package_install

struct Trigger:
    var name: String
    var table: String
    var event: String  # INSERT, UPDATE, DELETE
    var action: String  # SQL to execute

var triggers = List[Trigger]()
var cron_jobs = List[String]()  # Simple list of cron commands
var scm_repo = ""  # Current SCM repo path

# Security functions inline
fn generate_token(user_id: String) -> String:
    try:
        var py_jwt = Python.import_module("jwt")
        var py_datetime = Python.import_module("datetime")
        var payload = {"user_id": user_id, "exp": py_datetime.datetime.utcnow() + py_datetime.timedelta(hours=1)}
        var token = py_jwt.encode(payload, "secret", algorithm="HS256")
        return token
    except:
        return "token_" + user_id  # Fallback

fn validate_token(token: String) -> String:
    try:
        var py_jwt = Python.import_module("jwt")
        var decoded = py_jwt.decode(token, "secret", algorithms=["HS256"])
        return decoded["user_id"]
    except:
        return ""  # Invalid

# Observability functions inline
var query_count = 0
var total_latency = 0.0
var error_count = 0

fn record_query(latency: Float64, success: Bool):
    query_count += 1
    total_latency += latency
    if not success:
        error_count += 1

fn get_metrics() -> String:
    var avg_latency = total_latency / query_count if query_count > 0 else 0.0
    return "Queries: " + str(query_count) + ", Avg Latency: " + str(avg_latency) + "s, Errors: " + str(error_count)

fn health_check() -> String:
    return "OK"  # Simple

fn show_dashboard():
    print("=== Mojo Grizzly Dashboard ===")
    print(get_metrics())
    print("Health:", health_check())
from extensions.security import validate_token, generate_token, init as init_security
from extensions.security import validate_token, generate_token, init as init_security

# Global database state
var global_table = Table(Schema(), 0)
var tables = Dict[String, Table]()
var command_history = List[String]()
var current_user = "admin"  # Default, should be set via auth

fn execute_sql(sql: String):
    command_history.append(sql)
    if sql.upper().startswith("AUTH"):
        # AUTH token
        let token = sql[5:].strip()
        let user = validate_token(token)
        if user != "":
            current_user = user
            print("Authenticated as", user)
        else:
            print("Invalid token")
        return
    elif sql.upper().startswith("LOGIN"):
        # LOGIN user
        let user = sql[6:].strip()
        let token = generate_token(user)
        print("Token:", token)
        return
    elif sql.upper().startswith("SHOW METRICS"):
        print(get_metrics())
        return
    elif sql.upper().startswith("HEALTH CHECK"):
        print("Health:", health_check())
        return
    elif sql.upper().startswith("TIME TRAVEL TO"):
        # TIME TRAVEL TO timestamp
        let timestamp = sql[15:].strip()
        # Set global time travel point
        print("Time traveled to", timestamp)
        # In real, set context for queries
    elif sql.upper().startswith("QUERY AS OF"):
        # QUERY AS OF timestamp SQL
        let as_of_pos = sql.upper().find(" AS OF ")
        let timestamp = sql[as_of_pos+7:].strip()
        let query = sql[:as_of_pos].strip()
        # Execute query with time travel
        from extensions.lakehouse import query_as_of_lake
        let result = query_as_of_lake("default_lake", timestamp)  # Assume default lake
        print("Time travel query result:")
        for i in range(result.num_rows()):
            print("Row", i, ":", result.columns[0][i])
    elif sql.upper().startswith("BLOB AS OF"):
        # BLOB AS OF timestamp blob_id
        let parts = sql.split(" ")
        if len(parts) >= 4:
            let timestamp = parts[2]
            let blob_id = parts[3]
            from extensions.lakehouse import retrieve_blob_version
            let blob = retrieve_blob_version("default_lake", blob_id, timestamp)
            print("Blob", blob_id, "as of", timestamp, "size:", len(blob.data))
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
            elif ext_name == "rest_api":
                init_rest_api()
            elif ext_name == "ml":
                init_ml()
            elif ext_name == "security":
                init_security()
            elif ext_name == "observability":
                pass  # Placeholder
            elif ext_name == "analytics":
                pass  # Placeholder
            elif ext_name == "ecosystem":
                pass  # Placeholder
            elif ext_name == "scm":
                init_scm()
            elif ext_name == "packaging":
                init_packaging()
            else:
                print("Unknown extension:", ext_name)
    elif sql.upper().startswith("CREATE TRIGGER"):
        # CREATE TRIGGER name ON table FOR event EXECUTE action
        let parts = sql.split(" ")
        if len(parts) >= 7:
            let name = parts[2]
            let table = parts[4]
            let event = parts[6]
            let action_start = sql.find("EXECUTE ")
            if action_start != -1:
                let action = sql[action_start+8:].strip()
                triggers.append(Trigger(name, table, event, action))
                print("Trigger", name, "created on", table, "for", event)
            else:
                print("Invalid CREATE TRIGGER syntax")
        else:
            print("Invalid CREATE TRIGGER syntax")
    elif sql.upper().startswith("DROP TRIGGER"):
        # DROP TRIGGER name
        let name = sql[13:].strip()
        for i in range(len(triggers)):
            if triggers[i].name == name:
                triggers.__delitem__(i)
                print("Trigger", name, "dropped")
                break
        else:
            print("Trigger", name, "not found")
    elif sql.upper().startswith("CRON ADD"):
        # CRON ADD 'schedule' 'command'
        let parts = sql.split("'")
        if len(parts) >= 4:
            let schedule = parts[1]
            let command = parts[3]
            cron_jobs.append(schedule + " " + command)
            print("Cron job added:", schedule, command)
        else:
            print("Invalid CRON ADD syntax")
    elif sql.upper().startswith("GIT INIT"):
        # GIT INIT [path]
        let path = sql[9:].strip()
        if path == "":
            path = "."
        scm_repo = path
        print("SCM repo initialized at", path)
    elif sql.upper().startswith("GIT COMMIT"):
        # GIT COMMIT 'message'
        let message_start = sql.find("'")
        let message_end = sql.rfind("'")
        if message_start != -1 and message_end != -1:
            let message = sql[message_start+1:message_end]
            print("Committed with message:", message)
        else:
            print("Invalid GIT COMMIT syntax")
    elif sql.upper().startswith("BLOCKCHAIN MINT NFT"):
        # BLOCKCHAIN MINT NFT 'metadata'
        let metadata_start = sql.find("'")
        let metadata_end = sql.rfind("'")
        if metadata_start != -1 and metadata_end != -1:
            let metadata = sql[metadata_start+1:metadata_end]
            from extensions.blockchain import mint_nft
            let nft_id = mint_nft(metadata)
            print("NFT minted with ID:", nft_id)
        else:
            print("Invalid BLOCKCHAIN MINT NFT syntax")
    elif sql.upper().startswith("BLOCKCHAIN DEPLOY CONTRACT"):
        # BLOCKCHAIN DEPLOY CONTRACT 'code'
        let code_start = sql.find("'")
        let code_end = sql.rfind("'")
        if code_start != -1 and code_end != -1:
            let code = sql[code_start+1:code_end]
            from extensions.blockchain import deploy_contract
            let contract_id = deploy_contract(code)
            print("Smart contract deployed with ID:", contract_id)
        else:
            print("Invalid BLOCKCHAIN DEPLOY CONTRACT syntax")    elif sql.upper().startswith("PACKAGE INIT"):
        # PACKAGE INIT 'name' 'version'
        let parts = sql.split("'")
        if len(parts) >= 4:
            let name = parts[1]
            let version = parts[3]
            package_init(name, version)
        else:
            print("Invalid PACKAGE INIT syntax")
    elif sql.upper().startswith("PACKAGE ADD DEP"):
        # PACKAGE ADD DEP 'dep'
        let dep_start = sql.find("'")
        let dep_end = sql.rfind("'")
        if dep_start != -1 and dep_end != -1:
            let dep = sql[dep_start+1:dep_end]
            add_python_dep(dep)
        else:
            print("Invalid PACKAGE ADD DEP syntax")
    elif sql.upper().startswith("PACKAGE ADD FILE"):
        # PACKAGE ADD FILE 'file'
        let file_start = sql.find("'")
        let file_end = sql.rfind("'")
        if file_start != -1 and file_end != -1:
            let file = sql[file_start+1:file_end]
            add_mojo_file(file)
        else:
            print("Invalid PACKAGE ADD FILE syntax")
    elif sql.upper().startswith("PACKAGE BUILD"):
        package_build()
    elif sql.upper().startswith("PACKAGE INSTALL"):
        package_install()    elif sql.upper().startswith("RUN CRON"):
        # RUN CRON - execute all cron jobs in background
        @parameter
        fn run_job(job: String):
            let parts = job.split(" ")
            if len(parts) >= 2:
                let schedule = parts[0]
                let command = " ".join(parts[1:])
                # Simple: just execute the command
                let result = execute_query(global_table, command, tables, current_user)
                print("Cron job executed:", command)
        for job in cron_jobs:
            var t = Thread(run_job, job)
            t.start()
        print("Cron jobs started")
    elif sql.upper().startswith("ATTACH"):
        # ATTACH 'path' AS alias
        let path_start = sql.find("'")
        let path_end = sql.find("'", path_start+1)
        let as_pos = sql.upper().find(" AS ")
        if path_start != -1 and path_end != -1 and as_pos != -1:
            let path = sql[path_start+1:path_end]
            let alias = sql[as_pos+4:].strip()
            if alias in tables:
                print("Alias", alias, "already exists")
            else:
                if path.endswith(".grz"):
                    # Load .grz file
                    try:
                        if ColumnStoreConfig.is_default:
                            tables[alias] = read_parquet(path)
                        elif RowStoreConfig.is_default:
                            tables[alias] = read_avro(path)
                        else:
                            tables[alias] = read_parquet(path)  # default
                        print("Attached", path, "as", alias)
                    except:
                        print("Failed to load", path)
                elif path.endswith(".sql"):
                    # Execute .sql file as virtual table
                    try:
                        let sql_content = os.read(path)
                        let result = execute_query(global_table, sql_content, tables, current_user)
                        tables[alias] = result
                        print("Executed", path, "and attached result as", alias)
                    except:
                        print("Failed to execute", path)
                else:
                    print("Unsupported file type for ATTACH:", path)
        else:
            print("Invalid ATTACH syntax")
    elif sql.upper().startswith("DETACH"):
        # DETACH alias
        let alias = sql[7:].strip()
        if alias in tables:
            tables.pop(alias)
            print("Detached", alias)
        else:
            print("Alias", alias, "not found")    elif sql.startswith("LOAD JSONL"):
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
                from formats import detect_format
                let fmt = detect_format(filename)
                if fmt == "parquet":
                    global_table = read_parquet(filename)
                    print("Auto-loaded Parquet")
                elif fmt == "avro":
                    global_table = read_avro(filename)
                    print("Auto-loaded AVRO")
                elif fmt == "orc":
                    global_table = read_orc(filename)
                    print("Auto-loaded ORC")
                elif fmt == "jsonl":
                    global_table = read_jsonl(filename)
                    print("Auto-loaded JSONL")
                elif fmt == "csv":
                    global_table = read_csv(filename)
                    print("Auto-loaded CSV")
                else:
                    print("Unknown format for", filename)
    elif sql.startswith("SELECT"):
        let result = execute_query(global_table, sql, tables, current_user)
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
                # Execute triggers
                for t in triggers:
                    if t.table == table_name and t.event.upper() == "INSERT":
                        let result = execute_query(global_table, t.action, tables, current_user)
                        print("Trigger", t.name, "executed")
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
    elif sql.startswith("ADD REPLICA"):
        let parts = sql.split(" ")
        if len(parts) >= 3:
            let addr = parts[2]
            let addr_parts = addr.split(":")
            if len(addr_parts) == 2:
                let host = addr_parts[0]
                let port = atol(addr_parts[1])
                add_replica(host, port)
                print("Added replica", addr)
            else:
                print("Invalid address format")
        else:
            print("Invalid ADD REPLICA syntax")
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
    elif name == "rest_api":
        init_rest_api()
    elif name == "ml":
        init_ml()
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
        suggestions.append("SELECT AVG(column) FROM")
        suggestions.append("SELECT SUM(column) FROM")
    elif input.startswith("LOAD EXTENSION"):
        suggestions.append("LOAD EXTENSION column_store")
        suggestions.append("LOAD EXTENSION row_store")
        suggestions.append("LOAD EXTENSION graph")
        suggestions.append("LOAD EXTENSION blockchain")
        suggestions.append("LOAD EXTENSION lakehouse")
        suggestions.append("LOAD EXTENSION rest_api")
        suggestions.append("LOAD EXTENSION ml")
    elif input.startswith("CREATE"):
        suggestions.append("CREATE TABLE test (id INT, name STRING)")
        suggestions.append("CREATE FUNCTION myfunc AS SELECT * FROM table")
    elif input.startswith("ADD"):
        suggestions.append("ADD NODE 1 '{\"prop\": \"value\"}'")
        suggestions.append("ADD EDGE 1 2 'label' '{\"prop\": \"value\"}'")
    elif input.startswith("INSERT"):
        suggestions.append("INSERT INTO LAKE test VALUES (1, 'name')")
        suggestions.append("INSERT INTO test VALUES (1, 'name')")
    elif input.startswith("OPTIMIZE"):
        suggestions.append("OPTIMIZE test")
    elif input.startswith("ATTACH"):
        suggestions.append("ATTACH 'file.db' AS db")
    elif input.startswith("DETACH"):
        suggestions.append("DETACH db")
    elif input.startswith("SHOW"):
        suggestions.append("SHOW TABLES")
        suggestions.append("SHOW EXTENSIONS")
    # More completions added
    return suggestions

fn repl():
    print("Grizzly DB REPL. Type 'exit' to quit.")
    # Enable tab completion with readline
    try:
        var py_readline = Python.import_module("readline")
        # Define completer in Python
        var completer_code = """
def completer(text, state):
    suggestions = []
    if text.startswith("SELECT"):
        suggestions = ["SELECT * FROM", "SELECT COUNT(*) FROM", "SELECT AVG(column) FROM", "SELECT SUM(column) FROM"]
    elif text.startswith("LOAD EXTENSION"):
        suggestions = ["LOAD EXTENSION column_store", "LOAD EXTENSION row_store", "LOAD EXTENSION graph", "LOAD EXTENSION blockchain", "LOAD EXTENSION lakehouse", "LOAD EXTENSION rest_api", "LOAD EXTENSION ml"]
    elif text.startswith("CREATE"):
        suggestions = ["CREATE TABLE test (id INT, name STRING)", "CREATE FUNCTION myfunc AS SELECT * FROM table"]
    elif text.startswith("ADD"):
        suggestions = ["ADD NODE 1 '{\\"prop\\": \\"value\\"}'", "ADD EDGE 1 2 'label' '{\\"prop\\": \\"value\\"}'"]
    elif text.startswith("INSERT"):
        suggestions = ["INSERT INTO LAKE test VALUES (1, 'name')", "INSERT INTO test VALUES (1, 'name')"]
    elif text.startswith("OPTIMIZE"):
        suggestions = ["OPTIMIZE test"]
    elif text.startswith("ATTACH"):
        suggestions = ["ATTACH 'file.db' AS db"]
    elif text.startswith("DETACH"):
        suggestions = ["DETACH db"]
    elif text.startswith("SHOW"):
        suggestions = ["SHOW TABLES", "SHOW EXTENSIONS"]
    if state < len(suggestions):
        return suggestions[state]
    return None
"""
        Python.evaluate(completer_code)
        var py_completer = Python.evaluate("completer")
        py_readline.set_completer(py_completer)
        py_readline.parse_and_bind("tab: complete")
    except:
        print("Readline not available, using basic completion.")
    while True:
        try:
            print("grizzly> ", end="")
            var py_input = Python.import_module("builtins").input
            var input = py_input()
            if input == "exit":
                break
            if input == "":
                continue
            execute_sql(input)
        except KeyboardInterrupt:
            print("\nExiting...")
            break