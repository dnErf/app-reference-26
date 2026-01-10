"""
Mojo Kodiak DB - REPL

Interactive Read-Eval-Print Loop for database queries.
"""

from python import Python, PythonObject
from database import Database
from ext_query_parser import parse_query
from types import Row

fn start_repl(mut db: Database) raises:
    """
    Start the interactive REPL.
    """
    print("Welcome to Mojo Kodiak DB REPL")
    print("Type SQL queries or commands (.help, .exit)")
    
    var sys = Python.import_module("sys")
    while True:
        try:
            var prompt = "mojo-db> "
            sys.stdout.write(prompt)
            sys.stdout.flush()
            var line = sys.stdin.readline().strip()
            
            if line == "":
                continue
            elif line == ".exit":
                print("Goodbye!")
                break
            elif line == ".help":
                print("Commands:")
                print("  SELECT * FROM table WHERE column = value")
                print("  SELECT * FROM table LIMIT 10 OFFSET 20")
                print("  INSERT INTO table VALUES (val1, val2, val3)")
                print("  SET var = value")
                print("  CREATE TYPE name AS STRUCT(...)")
                print("  CREATE FUNCTION name(...) RETURNS type { ... }")
                print("  CREATE FUNCTION name(...) RETURNS type AS SYNC { ... }")
                print("  CREATE FUNCTION name(...) RETURNS type AS ASYNC { ... }")
                print("  CREATE SECRET name TYPE type VALUE 'value'")
                print("  DROP SECRET name TYPE type")
                print("  SHOW SECRETS")
                print("  SHOW TYPES")
                print("  SHOW EXTENSIONS")
                print("  SELECT * FROM table USING SECRET name TYPE type")
                print("  ATTACH 'path' AS alias")
                print("  DETACH alias")
                print("  LOAD extension")
                print("  INSTALL extension")
                print("  BACKUP 'path'")
                print("  RESTORE 'path'")
                print("  OPTIMIZE MEMORY")
                print("  CREATE TRIGGER name BEFORE|AFTER INSERT|UPDATE|DELETE ON table FOR EACH ROW EXECUTE FUNCTION func")
                print("  CREATE CRON JOB name SCHEDULE 'expr' EXECUTE FUNCTION func")
                print("  DROP CRON JOB name")
                print("  .help - Show this help")
                print("  .exit - Exit REPL")
                print("  .tables - List tables")
                print("  .health - Show database health")
                print("  .cache - Show query cache statistics")
                print("  .connections - Show connection pool statistics")
                print("  .memory - Show memory usage statistics")
                print("  .parallel - Show parallel execution status")
            elif line == ".tables":
                for table_name in db.tables.keys():
                    print("Table: " + String(table_name))
            elif line == ".health":
                print(db.get_health())
            elif line == ".cache":
                print(db.get_cache_stats())
            elif line == ".connections":
                print(db.get_connection_stats())
            elif line == ".memory":
                print(db.get_memory_stats())
            elif line == ".parallel":
                print(db.get_parallel_stats())
            else:
                # Parse and execute query
                var query = parse_query(String(line))
                var results = db.execute_query(query)
                if query.query_type == "SELECT":
                    print("Results:")
                    for row in results:
                        for key in row.data:
                            var k = String(key)
                            var val = row[k]
                            print(k + ": " + val)
                        print("---")
                else:
                    print("Query executed successfully.")
        except e:
            print("Error: " + String(e))

fn scm_init() raises:
    """
    Initialize SCM project structure by creating folders.
    """
    try:
        var os = Python.import_module("os")
        var folders = ["models", "seeds", "tests", "macros", "packages"]
        for folder in folders:
            try:
                os.makedirs(folder, exist_ok=True)
                print("Created folder: " + folder)
            except e:
                print("Error creating folder '" + folder + "': " + String(e))
        print("SCM project initialized successfully")
    except e:
        print("Error initializing SCM: " + String(e))

fn scm_pack() raises:
    """
    Pack the project folders into a .kdk database file using multi-store format.
    Automatically determines project name from current directory.
    """
    var os = Python.import_module("os")
    var pyarrow = Python.import_module("pyarrow")
    
    # Get project name from current directory
    var current_dir = os.getcwd()
    var project_name_obj = os.path.basename(current_dir)
    var project_name = String(project_name_obj)
    var db_file = project_name + ".kdk"
    
    print("Packing project '" + project_name + "' to: " + db_file)
    
    var data = Python.list()
    var folders = ["models", "seeds", "tests", "macros", "packages"]
    
    for folder in folders:
        if os.path.exists(folder):
            # Walk the directory tree
            var walk_iter = os.walk(folder)
            for walk_tuple in walk_iter:
                var root = walk_tuple[0]
                var dirs = walk_tuple[1] 
                var files = walk_tuple[2]
                for file in files:
                    var path = os.path.join(root, file)
                    try:
                        with open(String(path), 'r') as f:
                            var content = f.read()
                            var row = Python.dict()
                            row["path"] = path
                            row["content"] = content
                            row["store_type"] = "text"  # Multi-store support
                            data.append(row)
                    except e:
                        print("Error reading file '" + path + "': " + String(e))
    
    if len(data) == 0:
        print("No files found to pack")
        return
    
    # Create multi-store database file (.kdk)
    var table = pyarrow.Table.from_pylist(data)
    
    # Use Feather format for multi-store compatibility (supports all PyArrow formats)
    pyarrow.feather.write_feather(table, db_file)
    
    print("Project packed to multi-store database: " + db_file)
    print("Database supports SCM and lakehouse functionality")

fn scm_unpack() raises:
    """
    Unpack .kdk database file to project folders.
    Automatically determines project name from current directory.
    """
    var os = Python.import_module("os")
    var pyarrow = Python.import_module("pyarrow")
    
    # Get project name from current directory
    var current_dir = os.getcwd()
    var project_name_obj = os.path.basename(current_dir)
    var project_name = String(project_name_obj)
    var db_file = project_name + ".kdk"
    
    if not os.path.exists(db_file):
        print("Database file not found: " + db_file)
        return
    
    print("Unpacking from multi-store database: " + db_file)
    
    # Read multi-store database file (.kdk) using Feather format
    var table = pyarrow.feather.read_table(db_file)
    var rows = table.to_pylist()
    
    for row in rows:
        var path = String(row["path"])
        var content = String(row["content"])
        var dir_path = os.path.dirname(path)
        
        try:
            os.makedirs(dir_path, exist_ok=True)
            with open(path, 'w') as f:
                f.write(content)
            print("Unpacked: " + path)
        except e:
            print("Error writing file '" + path + "': " + String(e))
    
    print("Project unpacked from multi-store database")
    
    print("Project unpacked from ORC file: " + db_file)

fn scm_add(files: String) raises:
    """
    Add files to SCM staging.
    """
    print("Adding files to staging: " + files)
    # For now, just acknowledge - all files are included in pack
    print("Files staged (will be included in next commit)")

fn scm_commit(message: String) raises:
    """
    Commit changes with message.
    """
    scm_pack()
    print("Committed with message: " + message)

fn scm_status() raises:
    """
    Show SCM status compared to repository.
    """
    var os = Python.import_module("os")
    
    # Get project name from current directory
    var current_dir = os.getcwd()
    var project_name_obj = os.path.basename(current_dir)
    var project_name = String(project_name_obj)
    var repo_file = project_name + ".kdk"
    
    if not os.path.exists(repo_file):
        print("No repository found. Run 'kodiak scm pack' to create initial repository")
        return
    
    var current_files = get_current_files()
    var repo_files = get_repo_files(repo_file)
    
    var modified = Python.list()
    var added = Python.list()
    var deleted = Python.list()
    
    for path in current_files.keys():
        if path in repo_files:
            if current_files[path] != repo_files[path]:
                modified.append(path)
        else:
            added.append(path)
    
    for path in repo_files.keys():
        if path not in current_files:
            deleted.append(path)
    
    print("SCM Status:")
    print("Modified files: " + String(len(modified)))
    for f in modified:
        print("  M " + String(f))
    
    print("Added files: " + String(len(added)))
    for f in added:
        print("  A " + String(f))
    
    print("Deleted files: " + String(len(deleted)))
    for f in deleted:
        print("  D " + String(f))

fn scm_diff() raises:
    """
    Show differences between current and repository.
    """
    print("Diff functionality:")
    # Basic diff - show modified files
    scm_status()

fn scm_install(package_file: String) raises:
    """
    Install package from ORC file to packages/ directory.
    """
    var os = Python.import_module("os")
    
    if not os.path.exists(package_file):
        print("Package file not found: " + package_file)
        return
    
    # Extract package name from file name
    var package_name = os.path.splitext(os.path.basename(package_file))[0]
    var package_dir = os.path.join("packages", package_name)
    
    try:
        os.makedirs(package_dir, exist_ok=True)
        
        var pyarrow = Python.import_module("pyarrow")
        var table = pyarrow.orc.read_table(package_file)
        var rows = table.to_pylist()
        
        for row in rows:
            var path = String(row["path"])
            var content = String(row["content"])
            
            # Adjust path to be relative to package directory
            var rel_path = path  # Assume paths are relative in package
            var full_path = os.path.join(package_dir, rel_path)
            var dir_path = os.path.dirname(full_path)
            
            os.makedirs(dir_path, exist_ok=True)
            with open(String(full_path), 'w') as f:
                f.write(content)
        
        print("Package '" + package_name + "' installed successfully")
    except e:
        print("Error installing package: " + String(e))

fn scm_uninstall(package_name: String) raises:
    """
    Uninstall package by removing from packages/ directory.
    """
    var os = Python.import_module("os")
    var shutil = Python.import_module("shutil")
    
    var package_dir = os.path.join("packages", package_name)
    
    if not os.path.exists(package_dir):
        print("Package '" + package_name + "' not found")
        return
    
    try:
        shutil.rmtree(package_dir)
        print("Package '" + package_name + "' uninstalled successfully")
    except e:
        print("Error uninstalling package: " + String(e))

fn get_current_files() raises -> PythonObject:
    """
    Get current files in the project.
    """
    var os = Python.import_module("os")
    var files = Python.dict()
    var folders = ["models", "seeds", "tests", "macros", "packages"]
    
    for folder in folders:
        if os.path.exists(folder):
            var walk_result = os.walk(folder)
            for item in walk_result:
                var root = item[0]
                var dirs = item[1] 
                var files_list = item[2]
                for file in files_list:
                    var path = os.path.join(root, file)
                    try:
                        var content = String()
                        with open(String(path), 'r') as f:
                            content = f.read()
                        files[path] = content
                    except:
                        pass
    return files

fn get_repo_files(repo_file: String) raises -> PythonObject:
    """
    Get files from repository .kdk database file.
    """
    var pyarrow = Python.import_module("pyarrow")
    var files = Python.dict()
    
    try:
        # Read multi-store database file using Feather format
        var table = pyarrow.feather.read_table(repo_file)
        var rows = table.to_pylist()
        
        for row in rows:
            files[row["path"]] = row["content"]
    except:
        pass
    
    return files

fn main() raises:
    var db = Database()
    start_repl(db)