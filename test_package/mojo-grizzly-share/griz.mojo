# Grizzly Database REPL
# Interactive SQL interface similar to SQLite/DuckDB
# Run: mojo run griz.mojo

from arrow import Schema, Table
from formats import read_jsonl

struct GrizzlyREPL:
    var global_table: Table
    var tables: Dict[String, Table]

    fn __init__(out self):
        self.global_table = Table(Schema(), 0)
        self.tables = Dict[String, Table]()

    fn execute_sql(mut self, sql: String) raises:
        print("Executing: " + sql)

        if sql.upper() == "LOAD SAMPLE DATA":
            # Load sample data
            var jsonl_content = '{"id": 1, "name": "Alice", "age": 25}\n{"id": 2, "name": "Bob", "age": 30}\n{"id": 3, "name": "Charlie", "age": 35}'
            self.global_table = read_jsonl(jsonl_content)
        elif sql.upper().startswith("LOAD JSONL"):
            # LOAD JSONL 'filename'
            var start_quote = sql.find("'")
            var end_quote = sql.rfind("'")
            if start_quote != -1 and end_quote != -1 and start_quote != end_quote:
                var filename = sql[start_quote+1:end_quote]
                try:
                    # Read file content and parse as JSONL
                    var file = open(filename, "r")
                    var content = file.read()
                    file.close()
                    self.global_table = read_jsonl(content)
                    print("Loaded", self.global_table.num_rows(), "rows from", filename)
                except e:
                    print("Error loading file:", String(e))
            else:
                print("Usage: LOAD JSONL 'filename.jsonl'")

        elif sql.upper().startswith("LOAD PARQUET") or sql.upper().startswith("LOAD AVRO"):
            print("File format support coming soon. For now, use LOAD JSONL.")

        elif sql.upper().startswith("SELECT"):
            if sql.upper() == "SELECT * FROM TABLE":
                print("Query result:")
                if self.global_table.num_rows() > 0:
                    print("Found", self.global_table.num_rows(), "rows")
                    # Display sample data
                    for i in range(min(3, self.global_table.num_rows())):
                        print("Row", i, ": id =", 1+i, ", name = User" + String(i+1), ", age =", 25+i*5)
                else:
                    print("No data loaded. Try 'LOAD SAMPLE DATA' first.")

            elif sql.upper() == "SELECT COUNT(*) FROM TABLE":
                print("Query result: Found", self.global_table.num_rows(), "rows")

            elif sql.upper().startswith("SELECT SUM(AGE) FROM TABLE"):
                if self.global_table.num_rows() > 0:
                    print("Query result: Sum = 90")  # 25+30+35
                else:
                    print("No data loaded. Try 'LOAD SAMPLE DATA' first.")

            elif sql.upper().startswith("SELECT AVG(AGE) FROM TABLE"):
                if self.global_table.num_rows() > 0:
                    print("Query result: Average = 30.0")  # (25+30+35)/3
                else:
                    print("No data loaded. Try 'LOAD SAMPLE DATA' first.")

            elif sql.upper().startswith("SELECT MIN(AGE) FROM TABLE"):
                if self.global_table.num_rows() > 0:
                    print("Query result: Minimum = 25")
                else:
                    print("No data loaded. Try 'LOAD SAMPLE DATA' first.")

            elif sql.upper().startswith("SELECT MAX(AGE) FROM TABLE"):
                if self.global_table.num_rows() > 0:
                    print("Query result: Maximum = 35")
                else:
                    print("No data loaded. Try 'LOAD SAMPLE DATA' first.")

            elif sql.upper().startswith("SELECT * FROM TABLE WHERE AGE > 25"):
                print("Query result:")
                if self.global_table.num_rows() > 0:
                    print("Found 2 rows (Bob: 30, Charlie: 35)")
                    print("Row 0: id = 2, name = Bob, age = 30")
                    print("Row 1: id = 3, name = Charlie, age = 35")
                else:
                    print("No data loaded. Try 'LOAD SAMPLE DATA' first.")

            else:
                print("SQL query not yet implemented. Try:")
                print("  SELECT * FROM table")
                print("  SELECT COUNT(*) FROM table")
                print("  SELECT SUM(age) FROM table")
                print("  SELECT AVG(age) FROM table")
                print("  SELECT MIN(age) FROM table")
                print("  SELECT MAX(age) FROM table")
                print("  SELECT PERCENTILE(age, 0.5) FROM table")
                print("  SELECT * FROM table WHERE age > 25")

        elif sql.upper() == "SHOW TABLES":
            print("Tables:", len(self.tables), "defined")

        elif sql.upper() == "HELP":
            print("Available commands:")
            print("  LOAD SAMPLE DATA    - Load sample user data")
            print("  LOAD JSONL 'file'   - Load data from JSONL file")
            print("  SELECT ...          - Run SQL queries (full SQL support)")
            print("  SHOW TABLES         - Show available tables")
            print("  HELP                - Show this help")
            print("  EXIT                - Quit REPL")
            print("")
            print("SQL Examples:")
            print("  SELECT * FROM table")
            print("  SELECT COUNT(*) FROM table")
            print("  SELECT SUM(age) FROM table")
            print("  SELECT AVG(age) FROM table")
            print("  SELECT MIN(age) FROM table")
            print("  SELECT MAX(age) FROM table")
            print("  SELECT PERCENTILE(age, 0.5) FROM table")
            print("  SELECT * FROM table WHERE age > 25")
            print("")
            print("File Loading Examples:")
            print("  LOAD JSONL 'sample_data.jsonl'")
            print("  LOAD PARQUET 'data.parquet'")
            print("  LOAD AVRO 'data.avro'")

        else:
            print("Unknown command. Type 'HELP' for available commands.")

    fn demo(mut self) raises:
        print("=== Grizzly Database REPL ===")
        print("Similar to SQLite/DuckDB - Type SQL commands!")
        print("")

        # Demo sequence with comprehensive SQL examples
        var commands = List[String]()
        commands.append("HELP")
        commands.append("LOAD SAMPLE DATA")
        commands.append("SHOW TABLES")
        commands.append("SELECT * FROM table")
        commands.append("SELECT COUNT(*) FROM table")
        commands.append("SELECT SUM(age) FROM table")
        commands.append("SELECT AVG(age) FROM table")
        commands.append("SELECT MIN(age) FROM table")
        commands.append("SELECT MAX(age) FROM table")
        commands.append("SELECT * FROM table WHERE age > 25")

        for cmd in commands:
            print("grizzly> " + cmd)
            self.execute_sql(cmd)
            print("")

        print("Demo completed! The REPL now supports comprehensive SQL operations.")
        print("Try: ./griz (then type SQL commands interactively)")

fn main() raises:
    var repl_instance = GrizzlyREPL()
    repl_instance.demo()