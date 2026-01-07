# Grizzly CLI - Simple Database Command Line Tool
# Usage: mojo run cli.mojo <command> [args...]

from python import Python
from arrow import Schema, Table
from query import execute_query
from formats import read_jsonl

struct GrizzlyDB:
    var tables: Dict[String, Table]
    var current_db: String

    fn __init__(inout self):
        self.tables = Dict[String, Table]()
        self.current_db = "default"

    fn create_database(mut self, name: String):
        self.current_db = name
        self.tables = Dict[String, Table]()  # Reset tables for new DB
        print("Database '" + name + "' created successfully")

    fn run_sql_file(mut self, filename: String) raises:
        var py_os = Python.import_module("os")
        if not py_os.path.exists(filename):
            print("Error: File '" + filename + "' not found")
            return

        var py_open = Python.import_module("builtins").open
        var file = py_open(filename, "r")
        var content = file.read()
        file.close()
        var statements = content.split(";")

        for stmt in statements:
            var trimmed = stmt.strip()
            if trimmed != "":
                self.execute_sql(trimmed)

    fn execute_sql(mut self, sql: String) raises:
        print("Executing: " + sql)

        if sql.upper().startswith("CREATE DATABASE"):
            var db_name = sql[16:].strip()
            self.create_database(db_name)

        elif sql.upper().startswith("USE"):
            var db_name = sql[4:].strip()
            self.current_db = db_name
            print("Switched to database '" + db_name + "'")

        elif sql.upper().startswith("CREATE TABLE"):
            # Basic CREATE TABLE parsing
            var parts = sql.split(" ")
            if len(parts) >= 3:
                var table_name = parts[2]
                # Simple table creation - just store the name for now
                print("Table '" + table_name + "' created (basic implementation)")
            else:
                print("Invalid CREATE TABLE syntax")

        elif sql.upper().startswith("INSERT"):
            print("INSERT operations not yet implemented")

        elif sql.upper().startswith("SELECT"):
            print("SELECT operations not yet implemented")

        else:
            print("Unsupported SQL command: " + sql)

fn print_usage():
    print("Grizzly Database CLI")
    print("")
    print("Usage:")
    print("  mojo run cli.mojo <command> <subcommand> [args...]")
    print("")
    print("Commands:")
    print("  database create <name>    Create a new database")
    print("  sql run <file.sql>        Execute SQL commands from file")
    print("  sql exec '<query>'        Execute a single SQL query")
    print("")
    print("Examples:")
    print("  mojo run cli.mojo database create mydb")
    print("  mojo run cli.mojo sql run queries.sql")
    print("  mojo run cli.mojo sql exec 'SELECT * FROM users'")

fn main() raises:
    var py_sys = Python.import_module("sys")
    var argv = py_sys.argv

    var db = GrizzlyDB()

    if len(argv) < 3:
        print_usage()
        return

    var command = str(argv[1])
    var subcommand = str(argv[2])

    if command == "database" and subcommand == "create":
        if len(argv) < 4:
            print("Error: Database name required")
            return
        var db_name = str(argv[3])
        db.create_database(db_name)

    elif command == "sql" and subcommand == "run":
        if len(argv) < 4:
            print("Error: SQL file required")
            return
        var filename = str(argv[3])
        db.run_sql_file(filename)

    elif command == "sql" and subcommand == "exec":
        if len(argv) < 4:
            print("Error: SQL query required")
            return
        var query = str(argv[3])
        db.execute_sql(query)

    else:
        print("Unknown command:", command, subcommand)
        print_usage()