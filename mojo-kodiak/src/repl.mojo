"""
Mojo Kodiak DB - REPL

Interactive Read-Eval-Print Loop for database queries.
"""

from python import Python, PythonObject
from database import Database
from query_parser import parse_query
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
                print("  INSERT INTO table VALUES (val1, val2, val3)")
                print("  SET var = value")
                print("  CREATE TYPE name AS STRUCT(...)")
                print("  CREATE FUNCTION name(...) RETURNS type { ... }")
                print("  .help - Show this help")
                print("  .exit - Exit REPL")
                print("  .tables - List tables")
            elif line == ".tables":
                for table_name in db.tables.keys():
                    print("Table: " + String(table_name))
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

fn main() raises:
    var db = Database()
    start_repl(db)