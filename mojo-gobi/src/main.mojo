"""
Godi - Embedded Lakehouse Database
===================================

An embedded lakehouse database inspired by Apache Hudi and SQLMesh,
built with Mojo for high performance and memory safety.

Features:
- Merkle B+ Tree with SHA-256 integrity verification
- Universal compaction strategy
- PyArrow ORC columnar storage
- BLOB storage abstraction
- Rich CLI interface
- Pack/unpack .gobi format
"""

from python import Python, PythonObject
from collections import List
from sys import argv
from blob_storage import BlobStorage
from merkle_tree import MerkleBPlusTree
from schema_manager import SchemaManager, DatabaseSchema, TableSchema, Column
from orc_storage import ORCStorage, test_pyarrow_orc
from transformation_staging import TransformationStaging
from pl_grizzly_lexer import PLGrizzlyLexer, Token

# Import required Python modules
fn initialize_python_modules() raises:
    """Initialize Python modules for interop."""
    Python.add_to_path(".")
    # Rich will be imported as needed

# Main entry point
fn main() raises:
    """Main entry point for Godi CLI."""
    initialize_python_modules()

    var rich_console = Python.import_module("rich.console").Console()
    rich_console.print("[bold blue]Godi - Embedded Lakehouse Database[/bold blue]")
    rich_console.print("=" * 50)

    # Parse command line arguments
    var args = argv()

    if len(args) < 2:
        print_usage(rich_console)
        return

    var command = String(args[1])

    if command == "init":
        if len(args) < 3:
            rich_console.print("[red]Error: init requires a folder path[/red]")
            return
        initialize_database(String(args[2]), rich_console)
    elif command == "repl":
        start_repl(rich_console)
    elif command == "pack":
        if len(args) < 3:
            rich_console.print("[red]Error: pack requires a folder path[/red]")
            return
        pack_database(String(args[2]), rich_console)
    elif command == "unpack":
        if len(args) < 3:
            rich_console.print("[red]Error: unpack requires a .gobi file path[/red]")
            return
        unpack_database(String(args[2]), rich_console)
    else:
        rich_console.print("[red]Unknown command: " + command + "[/red]")
        print_usage(rich_console)

fn print_usage(rich_console: PythonObject) raises:
    """Print CLI usage information."""
    rich_console.print("[yellow]Usage:[/yellow]")
    rich_console.print("  gobi init <folder>    - Initialize database in folder")
    rich_console.print("  gobi repl             - Start interactive REPL")
    rich_console.print("  gobi pack <folder>    - Pack folder into .gobi file")
    rich_console.print("  gobi unpack <file>    - Unpack .gobi file to folder")

fn initialize_database(folder: String, rich_console: PythonObject) raises:
    """Initialize a new Godi database in the specified folder."""
    rich_console.print("[green]Initializing Godi database in: " + folder + "[/green]")

    var storage = BlobStorage(folder)
    var schema_manager = SchemaManager(storage)

    # Create default schema
    var schema = DatabaseSchema("godi_db")
    var success = schema_manager.save_schema(schema)

    if success:
        rich_console.print("[green]Database initialized successfully![/green]")
    else:
        rich_console.print("[red]Failed to initialize database[/red]")

fn start_repl(rich_console: PythonObject) raises:
    """Start the interactive REPL."""
    rich_console.print("[blue]Starting Godi REPL...[/blue]")
    rich_console.print("[dim]Type 'help' for commands, 'quit' to exit[/dim]")

    # Initialize database connection (use current directory as default)
    var current_db = "."
    var storage = BlobStorage(current_db)
    var schema_manager = SchemaManager(storage)
    var bloom_cols = List[String]()
    bloom_cols.append("id")
    bloom_cols.append("category")
    var orc_storage = ORCStorage(storage, "ZSTD", True, 10000, 65536, bloom_cols)
    var transform_staging = TransformationStaging(current_db)

    # Simple REPL loop (in real implementation, use proper async/event loop)
    var running = True
    while running:
        var prompt = rich_console.input("[bold cyan]godi> [/bold cyan]")
        var cmd = String(prompt).strip()

        if cmd == "quit" or cmd == "exit":
            running = False
            rich_console.print("[yellow]Goodbye![/yellow]")
        elif cmd == "help":
            rich_console.print("[yellow]Available commands:[/yellow]")
            rich_console.print("  help          - Show this help")
            rich_console.print("  quit          - Exit REPL")
            rich_console.print("  status        - Show database status")
            rich_console.print("  test          - Run PyArrow ORC test")
            rich_console.print("  use <db>      - Switch to database")
            rich_console.print("  create table <name> (<col1> <type1>, <col2> <type2>, ...) - Create table")
            rich_console.print("  insert into <table> values (<val1>, <val2>, ...) - Insert data")
            rich_console.print("  select * from <table> - Query table")
            rich_console.print("  create model <name> <sql> - Create transformation model")
            rich_console.print("  create env <name> [parent] [type] - Create environment")
            rich_console.print("  run pipeline <env> - Execute pipeline in environment")
            rich_console.print("  list models   - List all transformation models")
            rich_console.print("  show dependencies <model> - Show dependencies for a model")
            rich_console.print("  view history  - Show execution history for all models")
            rich_console.print("  list envs     - List all environments")
            rich_console.print("  set env config <env> <key> <value> - Set environment configuration")
            rich_console.print("  get env config <env> - Get environment configuration")
            rich_console.print("  validate sql <sql> - Validate SQL syntax")
            rich_console.print("  validate model <name> <sql> - Validate a transformation model")
            rich_console.print("  tokenize <code> - Tokenize PL-GRIZZLY code")
        elif cmd == "status":
            rich_console.print("[green]Database status: Operational[/green]")
            rich_console.print("[dim]Current database: " + current_db + "[/dim]")
        elif cmd == "test":
            rich_console.print("[yellow]Running PyArrow ORC test...[/yellow]")
            test_pyarrow_orc()
            rich_console.print("[green]Test completed[/green]")
        elif cmd.startswith("use "):
            var parts = cmd.split(" ")
            if len(parts) >= 2:
                current_db = String(parts[1])
                storage = BlobStorage(current_db)
                schema_manager = SchemaManager(storage)
                orc_storage = ORCStorage(storage)
                rich_console.print("[green]Switched to database: " + current_db + "[/green]")
            else:
                rich_console.print("[red]Usage: use <database_path>[/red]")
        elif cmd.startswith("create table "):
            # Parse: create table <name> (<cols>)
            var table_def = cmd[13:]  # Remove "create table "
            var paren_pos = table_def.find("(")
            if paren_pos == -1:
                rich_console.print("[red]Invalid table definition. Use: create table <name> (<col1> <type1>, ...)[/red]")
                continue

            var table_name = String(table_def[:paren_pos].strip())
            var cols_def = String(table_def[paren_pos+1:].strip())
            if cols_def.endswith(")"):
                cols_def = String(cols_def[:-1])

            # Parse columns
            var columns = List[Column]()
            var col_defs = cols_def.split(",")
            for col_def in col_defs:
                var col_parts = String(col_def).strip().split(" ")
                if len(col_parts) >= 2:
                    var col_name = String(col_parts[0])
                    var col_type = String(col_parts[1])
                    columns.append(Column(col_name, col_type))

            # Create table
            var success = schema_manager.create_table(table_name, columns)
            if success:
                rich_console.print("[green]Table '" + table_name + "' created successfully[/green]")
            else:
                rich_console.print("[red]Failed to create table '" + table_name + "'[/red]")
        elif cmd.startswith("insert into "):
            # Parse: insert into <table> values (<vals>)
            var insert_def = cmd[12:]  # Remove "insert into "
            var values_pos = insert_def.lower().find(" values ")
            if values_pos == -1:
                rich_console.print("[red]Invalid insert syntax. Use: insert into <table> values (<val1>, <val2>, ...)[/red]")
                continue

            var table_name = String(insert_def[:values_pos].strip())
            var vals_def = String(insert_def[values_pos+8:].strip())  # Remove " values "
            if not (vals_def.startswith("(") and vals_def.endswith(")")):
                rich_console.print("[red]Invalid insert syntax. Values must be in parentheses.[/red]")
                continue

            # Parse values using Python ast.literal_eval for safety
            var values = List[String]()
            try:
                var ast = Python.import_module("ast")
                # Parse the values tuple
                var parsed_vals = ast.literal_eval(vals_def)
                for i in range(len(parsed_vals)):
                    values.append(String(parsed_vals[i]))
            except:
                rich_console.print("[red]Failed to parse values: " + vals_def + "[/red]")
                continue

            # Insert data using ORC storage
            var data = List[List[String]]()
            data.append(values.copy())
            var success = orc_storage.write_table(table_name, data)
            if success:
                rich_console.print("[green]Inserted 1 row into '" + table_name + "'[/green]")
            else:
                rich_console.print("[red]Failed to insert into '" + table_name + "'[/red]")
        elif cmd.startswith("select * from "):
            # Parse: select * from <table>
            var table_name = String(cmd[14:].strip())  # Remove "select * from "

            # Read data using ORC storage
            var results = orc_storage.read_table(table_name)
            if len(results) == 0:
                rich_console.print("[yellow]Table '" + table_name + "' is empty or doesn't exist[/yellow]")
            else:
                rich_console.print("[green]Results from '" + table_name + "':[/green]")
                for row in results:
                    var row_str = "("
                    for i in range(len(row)):
                        if i > 0:
                            row_str += ", "
                        row_str += "'" + row[i] + "'"
                    row_str += ")"
                    rich_console.print("  " + row_str)
        elif cmd.startswith("create model "):
            # Parse: create model <name> <sql>
            var parts = cmd[13:].split(" ", 1)  # Split on first space only
            if len(parts) >= 2:
                var model_name = String(parts[0])
                var sql = String(parts[1])
                var dependencies = List[String]()
                var success = transform_staging.create_model(model_name, sql, dependencies)
                if success:
                    rich_console.print("[green]Model '" + model_name + "' created successfully[/green]")
                else:
                    rich_console.print("[red]Failed to create model '" + model_name + "'[/red]")
            else:
                rich_console.print("[red]Usage: create model <name> <sql>[/red]")
        elif cmd.startswith("create env "):
            # Parse: create env <name> [parent] [type]
            var parts = cmd[11:].strip().split(" ")
            if len(parts) >= 1:
                var env_name = String(parts[0])
                var parent = "" if len(parts) < 2 else String(parts[1])
                var env_type = "dev" if len(parts) < 3 else String(parts[2])
                var success = transform_staging.create_environment(env_name, "", parent, env_type)
                if success:
                    rich_console.print("[green]Environment '" + env_name + "' created successfully[/green]")
                else:
                    rich_console.print("[red]Failed to create environment '" + env_name + "'[/red]")
            else:
                rich_console.print("[red]Usage: create env <name> [parent] [type][/red]")
        elif cmd == "list models":
            # List all transformation models
            var models = transform_staging.list_models()
            if len(models) == 0:
                rich_console.print("[yellow]No transformation models found[/yellow]")
            else:
                rich_console.print("[green]Transformation models:[/green]")
                for model_name in models:
                    rich_console.print("  " + model_name)
        elif cmd.startswith("show dependencies "):
            # Parse: show dependencies <model>
            var model_name = String(cmd[18:].strip())
            var dependencies = transform_staging.get_model_dependencies(model_name)
            if len(dependencies) == 0:
                rich_console.print("[yellow]Model '" + model_name + "' has no dependencies[/yellow]")
            else:
                rich_console.print("[green]Dependencies for '" + model_name + "':[/green]")
                for dep in dependencies:
                    rich_console.print("  " + dep)
        elif cmd == "view history":
            # Show execution history for all models
            var history = transform_staging.get_execution_history()
            if len(history) == 0:
                rich_console.print("[yellow]No execution history found[/yellow]")
            else:
                rich_console.print("[green]Execution history:[/green]")
                for entry in history:
                    rich_console.print("  " + entry)
        elif cmd == "list envs":
            # List all environments
            var envs = transform_staging.list_environments()
            if len(envs) == 0:
                rich_console.print("[yellow]No environments found[/yellow]")
            else:
                rich_console.print("[green]Environments:[/green]")
                for env_name in envs:
                    rich_console.print("  " + env_name)
        elif cmd.startswith("set env config "):
            # Parse: set env config <env> <key> <value>
            var parts = cmd[15:].strip().split(" ")
            if len(parts) >= 3:
                var env_name = String(parts[0])
                var key = String(parts[1])
                var value = String(" ".join(parts[2:]))  # Join remaining parts for value
                var success = transform_staging.set_environment_config(env_name, key, value)
                if success:
                    rich_console.print("[green]Configuration '" + key + "' set for environment '" + env_name + "'[/green]")
                else:
                    rich_console.print("[red]Failed to set configuration for environment '" + env_name + "'[/red]")
            else:
                rich_console.print("[red]Usage: set env config <env> <key> <value>[/red]")
        elif cmd.startswith("get env config "):
            # Parse: get env config <env>
            var env_name = String(cmd[16:].strip())
            var config = transform_staging.get_environment_config(env_name)
            if len(config) == 0:
                rich_console.print("[yellow]No configuration found for environment '" + env_name + "'[/yellow]")
            else:
                rich_console.print("[green]Configuration for '" + env_name + "':[/green]")
                # Collect keys first to avoid aliasing issues
                var keys = List[String]()
                for key in config.keys():
                    keys.append(key)
                for key in keys:
                    var value = config[key]
                    rich_console.print("  " + key + " = " + value)
        elif cmd.startswith("run pipeline "):
            # Parse: run pipeline <env>
            var env_name = String(cmd[13:].strip())
            var execution = transform_staging.execute_pipeline(env_name)
            rich_console.print("[green]Pipeline execution completed[/green]")
            rich_console.print("[dim]Status: " + execution.status + "[/dim]")
            rich_console.print("[dim]Executed models: " + String(len(execution.executed_models)) + "[/dim]")
            if len(execution.errors) > 0:
                rich_console.print("[red]Errors:[/red]")
                for error in execution.errors:
                    rich_console.print("  " + error)
        elif cmd.startswith("validate sql "):
            # Parse: validate sql <sql>
            var sql = String(cmd[13:].strip())
            var result = transform_staging.validate_sql(sql)
            if result.is_valid:
                rich_console.print("[green]SQL is valid[/green]")
            else:
                rich_console.print("[red]SQL validation failed: " + result.error_message + "[/red]")
        elif cmd.startswith("validate model "):
            # Parse: validate model <name> <sql>
            var parts = cmd[15:].strip().split(" ", 1)
            if len(parts) >= 2:
                var model_name = String(parts[0])
                var sql = String(parts[1])
                var result = transform_staging.validate_model(model_name, sql)
                if result.is_valid:
                    rich_console.print("[green]Model '" + model_name + "' is valid[/green]")
                    # Also show extracted dependencies
                    var deps = transform_staging.extract_dependencies_from_sql(sql)
                    if len(deps) > 0:
                        rich_console.print("[dim]Extracted dependencies:[/dim]")
                        for dep in deps:
                            rich_console.print("  " + dep)
                else:
                    rich_console.print("[red]Model validation failed: " + result.error_message + "[/red]")
            else:
                rich_console.print("[red]Usage: validate model <name> <sql>[/red]")
        elif cmd.startswith("tokenize "):
            # Parse: tokenize <code>
            var code = String(cmd[9:].strip())
            var lexer = PLGrizzlyLexer(code)
            try:
                var tokens = lexer.tokenize()
                rich_console.print("[green]Tokens:[/green]")
                for token in tokens:
                    rich_console.print("  " + token.type + ": '" + token.value + "' (line " + String(token.line) + ", col " + String(token.column) + ")")
            except:
                rich_console.print("[red]Tokenization failed[/red]")
        else:
            rich_console.print("[red]Unknown command: " + cmd + "[/red]")

fn pack_database(folder: String, rich_console: PythonObject) raises:
    """Pack database folder into a .gobi file."""
    rich_console.print("[green]Packing database from: " + folder + "[/green]")

    # Check if folder exists
    var os = Python.import_module("os")
    if not os.path.exists(folder):
        rich_console.print("[red]Error: Database folder '" + folder + "' does not exist[/red]")
        return

    # Create .gobi filename
    var gobi_file = folder + ".gobi"
    rich_console.print("[dim]Creating archive: " + gobi_file + "[/dim]")

    try:
        # Use zipfile for compression
        var zipfile = Python.import_module("zipfile")
        var zipf = zipfile.ZipFile(gobi_file, "w", zipfile.ZIP_DEFLATED)

        # Walk through all files in the folder
        var walk_iter = os.walk(folder)
        for walk_item in walk_iter:
            var root = walk_item[0]
            var _ = walk_item[1]  # dirs not used
            var files = walk_item[2]

            for file in files:
                var full_path = os.path.join(root, file)
                var arcname = os.path.relpath(full_path, folder)
                zipf.write(full_path, arcname)
                rich_console.print("[dim]  Added: " + String(arcname) + "[/dim]")

        zipf.close()
        rich_console.print("[green]Database packed successfully: " + gobi_file + "[/green]")

    except:
        rich_console.print("[red]Error: Failed to pack database[/red]")

fn unpack_database(file_path: String, rich_console: PythonObject) raises:
    """Unpack .gobi file to folder structure."""
    rich_console.print("[green]Unpacking database from: " + file_path + "[/green]")

    # Check if file exists
    var os = Python.import_module("os")
    if not os.path.exists(file_path):
        rich_console.print("[red]Error: .gobi file '" + file_path + "' does not exist[/red]")
        return

    # Determine target folder (remove .gobi extension)
    var target_folder: String
    if file_path.endswith(".gobi"):
        target_folder = file_path[:-5]  # Remove .gobi extension
    else:
        target_folder = file_path + "_unpacked"

    rich_console.print("[dim]Extracting to: " + target_folder + "[/dim]")

    try:
        # Use zipfile for extraction
        var zipfile = Python.import_module("zipfile")
        var zipf = zipfile.ZipFile(file_path, "r")

        # Extract all files
        zipf.extractall(target_folder)

        # List extracted files
        var namelist = zipf.namelist()
        for name in namelist:
            rich_console.print("[dim]  Extracted: " + String(name) + "[/dim]")

        zipf.close()
        rich_console.print("[green]Database unpacked successfully to: " + target_folder + "[/green]")

    except:
        rich_console.print("[red]Error: Failed to unpack database[/red]")