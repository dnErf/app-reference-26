"""
Mojo Kodiak DB - Query Parser

Parses basic SQL-like queries.
"""

from collections import List
from types import Row

struct Query(Copyable, Movable):
    var query_type: String
    var table_name: String
    var columns: List[String]
    var values: List[String]  # For INSERT
    var where_column: String
    var where_op: String
    var where_value: String
    var var_name: String  # For SET
    var var_value: String  # For SET
    var type_name: String  # For CREATE TYPE
    var type_kind: String  # STRUCT or EXCEPTION
    var type_fields: List[String]  # For STRUCT fields
    var exception_message: String  # For EXCEPTION
    var func_name: String  # For CREATE FUNCTION
    var func_receiver: String  # Receiver type
    var func_params: List[String]  # Parameters
    var func_body: String  # Function body
    var func_returns: String  # Return type
    var func_raises: String  # Exception type
    var func_async: Bool  # Async flag
    var secret_name: String  # For CREATE SECRET
    var secret_type: String  # bearer, password, key, certificate, custom
    var secret_value: String  # The secret value
    var using_secret: String  # Secret name to use in query
    var using_secret_type: String  # Type of secret to use
    var attach_path: String  # For ATTACH
    var attach_alias: String  # For ATTACH/DETACH
    var load_extension: String  # For LOAD
    var install_extension: String  # For INSTALL
    var trigger_name: String  # For CREATE TRIGGER
    var trigger_timing: String  # BEFORE/AFTER
    var trigger_event: String  # INSERT/UPDATE/DELETE
    var trigger_table: String
    var trigger_function: String
    var cron_name: String  # For CREATE CRON JOB
    var cron_schedule: String
    var cron_function: String
    var pl_code: String  # For PL expressions
    var backup_path: String  # For BACKUP
    var restore_path: String  # For RESTORE
    var limit: Int  # For LIMIT clause
    var offset: Int  # For OFFSET clause
    var optimize_type: String  # For OPTIMIZE command
    var show_types: Bool  # For SHOW TYPES command
    var select_expressions: List[String]  # For complex SELECT expressions
    var window_functions: List[String]  # For window function definitions
    var model_name: String  # For CREATE MODEL
    var model_sql: String  # The SQL for the model
    var model_materialization: String  # table, view, incremental
    var show_models: Bool  # For SHOW MODELS command
    var run_model_name: String  # For RUN MODEL command
    var generate_docs: Bool  # For GENERATE DOCS command
    var test_name: String  # For CREATE TEST
    var test_model: String  # Model to test
    var test_condition: String  # Test condition SQL
    var run_tests: Bool  # For RUN TESTS command
    var snapshot_name: String  # For CREATE SNAPSHOT
    var snapshot_sql: String  # SQL for snapshot
    var run_snapshot_name: String  # For RUN SNAPSHOT command
    var macro_name: String  # For CREATE MACRO
    var macro_sql: String  # SQL for macro
    var backfill_model: String  # For BACKFILL
    var backfill_from: String  # Start date
    var backfill_to: String  # End date
    var schedule_name: String  # For CREATE SCHEDULE
    var schedule_cron: String  # Cron expression
    var schedule_models: List[String]  # Models to run in order
    var orchestrate: Bool  # For ORCHESTRATE command
    var orchestrate_models: List[String]  # Models to orchestrate
    var run_scheduler: Bool  # For RUN SCHEDULER command
    var blob_bucket: String  # For BLOB bucket operations
    var blob_key: String  # For BLOB object key
    var blob_content_type: String  # Content type for BLOB objects
    var blob_data: List[UInt8]  # BLOB data
    var blob_tags: Dict[String, String]  # BLOB tags
    var blob_prefix: String  # For LIST operations
    var blob_max_keys: Int  # Maximum keys to return in LIST
    var create_bucket: Bool  # For CREATE BUCKET command
    var delete_bucket: Bool  # For DELETE BUCKET command
    var put_blob: Bool  # For PUT BLOB command
    var get_blob: Bool  # For GET BLOB command
    var delete_blob: Bool  # For DELETE BLOB command
    var list_blobs: Bool  # For LIST BLOBS command
    var copy_blob: Bool  # For COPY BLOB command
    var blob_source_bucket: String  # Source bucket for COPY
    var blob_source_key: String  # Source key for COPY
    var blob_dest_bucket: String  # Destination bucket for COPY
    var blob_dest_key: String  # Destination key for COPY

    fn __init__(out self):
        self.query_type = ""
        self.table_name = ""
        self.columns = List[String]()
        self.values = List[String]()
        self.where_column = ""
        self.where_op = ""
        self.where_value = ""
        self.var_name = ""
        self.var_value = ""
        self.type_name = ""
        self.type_kind = ""
        self.type_fields = List[String]()
        self.exception_message = ""
        self.func_name = ""
        self.func_receiver = ""
        self.func_params = List[String]()
        self.func_body = ""
        self.func_returns = ""
        self.func_raises = ""
        self.func_async = True
        self.secret_name = ""
        self.secret_type = ""
        self.secret_value = ""
        self.using_secret = ""
        self.using_secret_type = ""
        self.attach_path = ""
        self.attach_alias = ""
        self.load_extension = ""
        self.install_extension = ""
        self.trigger_name = ""
        self.trigger_timing = ""
        self.trigger_event = ""
        self.trigger_table = ""
        self.trigger_function = ""
        self.cron_name = ""
        self.cron_schedule = ""
        self.cron_function = ""
        self.pl_code = ""
        self.backup_path = ""
        self.restore_path = ""
        self.limit = -1  # -1 means no limit
        self.offset = 0
        self.optimize_type = ""
        self.show_types = False
        self.select_expressions = List[String]()
        self.window_functions = List[String]()
        self.model_name = ""
        self.model_sql = ""
        self.model_materialization = ""
        self.show_models = False
        self.run_model_name = ""
        self.generate_docs = False
        self.test_name = ""
        self.test_model = ""
        self.test_condition = ""
        self.run_tests = False
        self.snapshot_name = ""
        self.snapshot_sql = ""
        self.run_snapshot_name = ""
        self.macro_name = ""
        self.macro_sql = ""
        self.backfill_model = ""
        self.backfill_from = ""
        self.backfill_to = ""
        self.schedule_name = ""
        self.schedule_cron = ""
        self.schedule_models = List[String]()
        self.orchestrate = False
        self.orchestrate_models = List[String]()
        self.run_scheduler = False
        self.blob_bucket = ""
        self.blob_key = ""
        self.blob_content_type = ""
        self.blob_data = List[UInt8]()
        self.blob_tags = Dict[String, String]()
        self.blob_prefix = ""
        self.blob_max_keys = 1000
        self.create_bucket = False
        self.delete_bucket = False
        self.put_blob = False
        self.get_blob = False
        self.delete_blob = False
        self.list_blobs = False
        self.copy_blob = False
        self.blob_source_bucket = ""
        self.blob_source_key = ""
        self.blob_dest_bucket = ""
        self.blob_dest_key = ""

fn parse_query(sql: String) raises -> Query:
    """
    Parse a basic SQL query.
    Supports: SELECT * FROM table WHERE column = value
              INSERT INTO table VALUES (val1, val2)
    """
    var query = Query()
    var tokens = sql.split(" ")
    var i = 0
    
    # Skip leading/trailing whitespace
    while i < len(tokens) and tokens[i] == "":
        i += 1
    
    if i >= len(tokens):
        raise "Empty query"
    
    # Determine query type
    if tokens[i].upper() == "CREATE":
        i += 1
        if tokens[i].upper() == "TABLE":
            query.query_type = "CREATE"
            i += 1
            if i < len(tokens):
                query.table_name = String(tokens[i])
        elif tokens[i].upper() == "TYPE":
            query.query_type = "CREATE_TYPE"
            i += 1
            if i < len(tokens):
                query.type_name = String(tokens[i])
                i += 1
                if i < len(tokens) and tokens[i].upper() == "AS":
                    i += 1
                    if i < len(tokens):
                        if tokens[i].upper() == "STRUCT":
                            query.type_kind = "STRUCT"
                            i += 1
                            if i < len(tokens) and String(tokens[i]) == "(":
                                i += 1
                                while i < len(tokens) and String(tokens[i]) != ")":
                                    if String(tokens[i]) != "," and String(tokens[i]) != "":
                                        query.type_fields.append(String(tokens[i]))
                                    i += 1
                        elif tokens[i].upper() == "EXCEPTION":
                            query.type_kind = "EXCEPTION"
                            i += 1
                            if i < len(tokens) and String(tokens[i]) == "(":
                                i += 1
                                var msg_parts = List[String]()
                                while i < len(tokens) and String(tokens[i]) != ")":
                                    if String(tokens[i]) != "":
                                        msg_parts.append(String(tokens[i]))
                                    i += 1
                                query.exception_message = String(" ".join(msg_parts).strip("'\""))
        elif tokens[i].upper() == "MODEL":
            query.query_type = "CREATE_MODEL"
            i += 1
            if i < len(tokens):
                query.model_name = String(tokens[i])
                i += 1
            # Optional materialization (table, view, incremental)
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                if i < len(tokens):
                    query.model_materialization = String(tokens[i]).lower()
                    i += 1
            # AS SELECT ...
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                var sql_parts = List[String]()
                while i < len(tokens):
                    sql_parts.append(String(tokens[i]))
                    i += 1
                query.model_sql = " ".join(sql_parts)
        elif tokens[i].upper() == "TEST":
            query.query_type = "CREATE_TEST"
            i += 1
            if i < len(tokens):
                query.test_name = String(tokens[i])
                i += 1
            if i < len(tokens) and tokens[i].upper() == "ON":
                i += 1
                if i < len(tokens):
                    query.test_model = String(tokens[i])
                    i += 1
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                var cond_parts = List[String]()
                while i < len(tokens):
                    cond_parts.append(String(tokens[i]))
                    i += 1
                query.test_condition = " ".join(cond_parts)
        elif tokens[i].upper() == "SNAPSHOT":
            query.query_type = "CREATE_SNAPSHOT"
            i += 1
            if i < len(tokens):
                query.snapshot_name = String(tokens[i])
                i += 1
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                var sql_parts = List[String]()
                while i < len(tokens):
                    sql_parts.append(String(tokens[i]))
                    i += 1
                query.snapshot_sql = " ".join(sql_parts)
        elif tokens[i].upper() == "MACRO":
            query.query_type = "CREATE_MACRO"
            i += 1
            if i < len(tokens):
                query.macro_name = String(tokens[i])
                i += 1
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                var sql_parts = List[String]()
                while i < len(tokens):
                    sql_parts.append(String(tokens[i]))
                    i += 1
                query.macro_sql = " ".join(sql_parts)
        elif tokens[i].upper() == "SCHEDULE":
            query.query_type = "CREATE_SCHEDULE"
            i += 1
            if i < len(tokens):
                query.schedule_name = String(tokens[i])
                i += 1
            if i < len(tokens) and tokens[i].upper() == "CRON":
                i += 1
                var cron_parts = List[String]()
                while i < len(tokens) and tokens[i].upper() != "MODELS":
                    cron_parts.append(String(tokens[i]))
                    i += 1
                query.schedule_cron = String(" ".join(cron_parts).strip("'\""))
            if i < len(tokens) and tokens[i].upper() == "MODELS":
                i += 1
                while i < len(tokens):
                    if String(tokens[i]) != "," and String(tokens[i]) != "":
                        query.schedule_models.append(String(tokens[i]))
                    i += 1
        elif tokens[i].upper() == "FUNCTION":
            query.query_type = "CREATE_FUNCTION"
            i += 1
            # Check for receiver [Type]
            if i < len(tokens) and String(tokens[i]).startswith("["):
                var rec = String(tokens[i])
                query.func_receiver = rec[1:len(rec)-1]
                i += 1
            # Function name
            if i < len(tokens):
                query.func_name = String(tokens[i])
                if query.func_name.endswith("()"):
                    query.func_name = query.func_name[:-2]
                i += 1
            # Parameters (arg: Type, ...)
            if i < len(tokens) and String(tokens[i]) == "(":
                i += 1
                while i < len(tokens) and String(tokens[i]) != ")":
                    if String(tokens[i]) != ",":
                        query.func_params.append(String(tokens[i]))
                    i += 1
                i += 1  # skip )
            # RETURNS
            if i < len(tokens) and tokens[i].upper() == "RETURNS":
                i += 1
                if i < len(tokens):
                    query.func_returns = String(tokens[i])
                    i += 1
            # Optional RAISE
            if i < len(tokens) and tokens[i].upper() == "RAISE":
                i += 1
                if i < len(tokens):
                    query.func_raises = String(tokens[i])
                    i += 1
            # Optional AS ASYNC or AS SYNC
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                if i < len(tokens):
                    if tokens[i].upper() == "ASYNC":
                        query.func_async = True
                        i += 1
                    elif tokens[i].upper() == "SYNC":
                        query.func_async = False
                        i += 1
            # Body { ... }
            if i < len(tokens) and String(tokens[i]) == "{":
                i += 1
                var body_parts = List[String]()
                while i < len(tokens) and String(tokens[i]) != "}":
                    body_parts.append(String(tokens[i]))
                    i += 1
                query.func_body = " ".join(body_parts)
        elif tokens[i].upper() == "SECRET":
            query.query_type = "CREATE_SECRET"
            i += 1
            if i < len(tokens):
                query.secret_name = String(tokens[i])
                i += 1
                if i < len(tokens) and tokens[i].upper() == "TYPE":
                    i += 1
                    if i < len(tokens):
                        query.secret_type = String(tokens[i])
                        i += 1
                        if i < len(tokens) and tokens[i].upper() == "VALUE":
                            i += 1
                            var value_parts = List[String]()
                            while i < len(tokens):
                                value_parts.append(String(tokens[i]))
                                i += 1
                            query.secret_value = String(" ".join(value_parts).strip("'\""))
        elif tokens[i].upper() == "TRIGGER":
            query.query_type = "CREATE_TRIGGER"
            i += 1
            if i < len(tokens):
                query.trigger_name = String(tokens[i])
                i += 1
                if i < len(tokens) and (tokens[i].upper() == "BEFORE" or tokens[i].upper() == "AFTER"):
                    query.trigger_timing = String(tokens[i])
                    i += 1
                if i < len(tokens) and (tokens[i].upper() == "INSERT" or tokens[i].upper() == "UPDATE" or tokens[i].upper() == "DELETE"):
                    query.trigger_event = String(tokens[i])
                    i += 1
                if i < len(tokens) and tokens[i].upper() == "ON":
                    i += 1
                    if i < len(tokens):
                        query.trigger_table = String(tokens[i])
                        i += 1
                # Skip to EXECUTE FUNCTION
                while i < len(tokens) and not (tokens[i].upper() == "EXECUTE" and i + 1 < len(tokens) and tokens[i+1].upper() == "FUNCTION"):
                    i += 1
                if i + 1 < len(tokens):
                    i += 2
                    if i < len(tokens):
                        query.trigger_function = String(tokens[i])
        elif tokens[i].upper() == "CRON":
            i += 1
            if tokens[i].upper() == "JOB":
                query.query_type = "CREATE_CRON_JOB"
                i += 1
                if i < len(tokens):
                    query.cron_name = String(tokens[i])
                    i += 1
                if i < len(tokens) and tokens[i].upper() == "SCHEDULE":
                    i += 1
                    var sched_parts = List[String]()
                    while i < len(tokens) and tokens[i].upper() != "EXECUTE":
                        sched_parts.append(String(tokens[i]))
                        i += 1
                    query.cron_schedule = String(" ".join(sched_parts).strip("'\""))
                if i < len(tokens) and tokens[i].upper() == "EXECUTE":
                    i += 1
                    if i < len(tokens) and tokens[i].upper() == "FUNCTION":
                        i += 1
                        if i < len(tokens):
                            query.cron_function = String(tokens[i])
    
    elif tokens[i].upper() == "ATTACH":
        query.query_type = "ATTACH"
        i += 1
        if i < len(tokens):
            var path_parts = List[String]()
            while i < len(tokens) and tokens[i].upper() != "AS":
                path_parts.append(String(tokens[i]))
                i += 1
            query.attach_path = String(" ".join(path_parts).strip("'\""))
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                if i < len(tokens):
                    query.attach_alias = String(tokens[i])
    
    elif tokens[i].upper() == "DETACH":
        query.query_type = "DETACH"
        i += 1
        if i < len(tokens):
            query.attach_alias = String(tokens[i])
    
    elif tokens[i].upper() == "LOAD":
        query.query_type = "LOAD"
        i += 1
        if i < len(tokens):
            query.load_extension = String(tokens[i])
    
    elif tokens[i].upper() == "INSTALL":
        query.query_type = "INSTALL"
        i += 1
        if i < len(tokens):
            query.install_extension = String(tokens[i])
    
    elif tokens[i].upper() == "BACKUP":
        query.query_type = "BACKUP"
        i += 1
        if i < len(tokens):
            query.backup_path = String(tokens[i])
    
    elif tokens[i].upper() == "RESTORE":
        query.query_type = "RESTORE"
        i += 1
        if i < len(tokens):
            query.restore_path = String(tokens[i])
    
    elif tokens[i].upper() == "OPTIMIZE":
        query.query_type = "OPTIMIZE"
        i += 1
        if i < len(tokens):
            query.optimize_type = String(tokens[i])
    
    elif tokens[i].upper() == "SELECT":
        query.query_type = "SELECT"
        i += 1
        # Parse select expressions until FROM
        var expr_start = i
        while i < len(tokens) and tokens[i].upper() != "FROM":
            i += 1
        if expr_start < i:
            var expr_tokens = tokens[expr_start:i]
            var expr_str = " ".join(expr_tokens)
            query.select_expressions.append(expr_str)
            # Check for window functions
            if "OVER" in expr_str.upper():
                query.window_functions.append(expr_str)
        # FROM
        if i < len(tokens) and tokens[i].upper() == "FROM":
            i += 1
            if i < len(tokens):
                query.table_name = String(tokens[i])
                i += 1
        # WHERE
        if i < len(tokens) and tokens[i].upper() == "WHERE":
            i += 1
            if i + 2 < len(tokens):
                query.where_column = String(tokens[i])
                query.where_op = String(tokens[i + 1])
                var temp = String(tokens[i + 2])
                var stripped = temp.strip("'\"")
                query.where_value = String(stripped)
        # USING SECRET
        if i < len(tokens) and tokens[i].upper() == "USING":
            i += 1
            if i < len(tokens) and tokens[i].upper() == "SECRET":
                i += 1
                if i < len(tokens):
                    query.using_secret = String(tokens[i])
                    i += 1
                    if i < len(tokens) and tokens[i].upper() == "TYPE":
                        i += 1
                        if i < len(tokens):
                            query.using_secret_type = String(tokens[i])
        # LIMIT
        if i < len(tokens) and tokens[i].upper() == "LIMIT":
            i += 1
            if i < len(tokens):
                query.limit = atol(String(tokens[i]))
                i += 1
        # OFFSET
        if i < len(tokens) and tokens[i].upper() == "OFFSET":
            i += 1
            if i < len(tokens):
                query.offset = atol(String(tokens[i]))
                i += 1
        query.query_type = "SELECT"
        i += 1
        if i < len(tokens):
            query.table_name = String(tokens[i])
            i += 1
        # SELECT
        if i < len(tokens) and tokens[i].upper() == "SELECT":
            i += 1
            if tokens[i] == "*":
                query.columns.append("*")
                i += 1
        # WHERE
        if i < len(tokens) and tokens[i].upper() == "WHERE":
            i += 1
            if i + 2 < len(tokens):
                query.where_column = String(tokens[i])
                query.where_op = String(tokens[i + 1])
                var temp = String(tokens[i + 2])
                var stripped = temp.strip("'\"")
                query.where_value = String(stripped)
    
    elif tokens[i].upper() == "INSERT":
        query.query_type = "INSERT"
        i += 1
        if i < len(tokens) and tokens[i].upper() == "INTO":
            i += 1
            if i < len(tokens):
                query.table_name = String(tokens[i])
                i += 1
        # VALUES
        if i < len(tokens) and tokens[i].upper() == "VALUES":
            i += 1
            if i < len(tokens):
                var vals_str = tokens[i].strip("()")
                var vals = vals_str.split(",")
                for val in vals:
                    var s = String(val)
                    var stripped = s.strip("'\"")
                    query.values.append(String(stripped))
    
    elif tokens[i].upper() == "SET":
        query.query_type = "SET"
        i += 1
        if i < len(tokens):
            query.var_name = String(tokens[i])
            i += 1
            if i < len(tokens) and tokens[i] == "=":
                i += 1
                var value_parts = List[String]()
                while i < len(tokens):
                    value_parts.append(String(tokens[i]))
                    i += 1
                query.var_value = String(" ".join(value_parts).strip())
    
    elif tokens[i].upper() == "DROP":
        i += 1
        if i < len(tokens) and tokens[i].upper() == "SECRET":
            query.query_type = "DROP_SECRET"
            i += 1
            if i < len(tokens):
                query.secret_name = String(tokens[i])
                i += 1
                if i < len(tokens) and tokens[i].upper() == "TYPE":
                    i += 1
                    if i < len(tokens):
                        query.secret_type = String(tokens[i])
        elif tokens[i].upper() == "CRON":
            i += 1
            if tokens[i].upper() == "JOB":
                query.query_type = "DROP_CRON_JOB"
                i += 1
                if i < len(tokens):
                    query.cron_name = String(tokens[i])
    
    elif tokens[i].upper() == "SHOW":
        i += 1
        if i < len(tokens) and tokens[i].upper() == "SECRETS":
            query.query_type = "SHOW_SECRETS"
        elif i < len(tokens) and tokens[i].upper() == "TYPES":
            query.query_type = "SHOW_TYPES"
        elif i < len(tokens) and tokens[i].upper() == "EXTENSIONS":
            query.query_type = "SHOW_EXTENSIONS"
        elif i < len(tokens) and tokens[i].upper() == "MODELS":
            query.query_type = "SHOW_MODELS"
            query.show_models = True
    elif tokens[i].upper() == "RUN":
        i += 1
        if i < len(tokens) and tokens[i].upper() == "MODEL":
            query.query_type = "RUN_MODEL"
            i += 1
            if i < len(tokens):
                query.run_model_name = String(tokens[i])
    elif tokens[i].upper() == "GENERATE":
        i += 1
        if i < len(tokens) and tokens[i].upper() == "DOCS":
            query.query_type = "GENERATE_DOCS"
            query.generate_docs = True
    elif tokens[i].upper() == "BACKFILL":
        query.query_type = "BACKFILL"
        i += 1
        if i < len(tokens) and tokens[i].upper() == "MODEL":
            i += 1
            if i < len(tokens):
                query.backfill_model = String(tokens[i])
                i += 1
            if i < len(tokens) and tokens[i].upper() == "FROM":
                i += 1
                if i < len(tokens):
                    query.backfill_from = String(tokens[i])
                    i += 1
            if i < len(tokens) and tokens[i].upper() == "TO":
                i += 1
                if i < len(tokens):
                    query.backfill_to = String(tokens[i])
    elif tokens[i].upper() == "ORCHESTRATE":
        query.query_type = "ORCHESTRATE"
        query.orchestrate = True
        i += 1
        while i < len(tokens):
            if String(tokens[i]) != "," and String(tokens[i]) != "":
                query.orchestrate_models.append(String(tokens[i]))
            i += 1
    elif tokens[i].upper() == "RUN" and i + 1 < len(tokens) and tokens[i + 1].upper() == "SCHEDULER":
        query.query_type = "RUN_SCHEDULER"
        query.run_scheduler = True
        i += 2
    elif tokens[i].upper() == "CREATE" and i + 1 < len(tokens) and tokens[i + 1].upper() == "BUCKET":
        query.query_type = "CREATE_BUCKET"
        query.create_bucket = True
        i += 2
        if i < len(tokens):
            query.blob_bucket = String(tokens[i])
    elif tokens[i].upper() == "DELETE" and i + 1 < len(tokens) and tokens[i + 1].upper() == "BUCKET":
        query.query_type = "DELETE_BUCKET"
        query.delete_bucket = True
        i += 2
        if i < len(tokens):
            query.blob_bucket = String(tokens[i])
    elif tokens[i].upper() == "PUT" and i + 1 < len(tokens) and tokens[i + 1].upper() == "BLOB":
        query.query_type = "PUT_BLOB"
        query.put_blob = True
        i += 2
        if i < len(tokens):
            query.blob_bucket = String(tokens[i])
            i += 1
        if i < len(tokens):
            query.blob_key = String(tokens[i])
            i += 1
        # Parse optional CONTENT_TYPE
        if i < len(tokens) and tokens[i].upper() == "CONTENT_TYPE":
            i += 1
            if i < len(tokens):
                query.blob_content_type = String(tokens[i])
                i += 1
        # Parse optional data (simplified - would need proper data parsing)
        if i < len(tokens):
            var data_str = String(tokens[i])
            # Convert string to bytes (simplified)
            for i in range(len(data_str)):
                query.blob_data.append(ord(data_str[i]))
    elif tokens[i].upper() == "GET" and i + 1 < len(tokens) and tokens[i + 1].upper() == "BLOB":
        query.query_type = "GET_BLOB"
        query.get_blob = True
        i += 2
        if i < len(tokens):
            query.blob_bucket = String(tokens[i])
            i += 1
        if i < len(tokens):
            query.blob_key = String(tokens[i])
    elif tokens[i].upper() == "DELETE" and i + 1 < len(tokens) and tokens[i + 1].upper() == "BLOB":
        query.query_type = "DELETE_BLOB"
        query.delete_blob = True
        i += 2
        if i < len(tokens):
            query.blob_bucket = String(tokens[i])
            i += 1
        if i < len(tokens):
            query.blob_key = String(tokens[i])
    elif tokens[i].upper() == "LIST" and i + 1 < len(tokens) and tokens[i + 1].upper() == "BLOBS":
        query.query_type = "LIST_BLOBS"
        query.list_blobs = True
        i += 2
        if i < len(tokens):
            query.blob_bucket = String(tokens[i])
            i += 1
        # Parse optional PREFIX
        if i < len(tokens) and tokens[i].upper() == "PREFIX":
            i += 1
            if i < len(tokens):
                query.blob_prefix = String(tokens[i])
                i += 1
        # Parse optional MAX_KEYS
        if i < len(tokens) and tokens[i].upper() == "MAX_KEYS":
            i += 1
            if i < len(tokens):
                query.blob_max_keys = Int(String(tokens[i]))
    elif tokens[i].upper() == "COPY" and i + 1 < len(tokens) and tokens[i + 1].upper() == "BLOB":
        query.query_type = "COPY_BLOB"
        query.copy_blob = True
        i += 2
        if i < len(tokens):
            query.blob_source_bucket = String(tokens[i])
            i += 1
        if i < len(tokens):
            query.blob_source_key = String(tokens[i])
            i += 1
        if i < len(tokens) and tokens[i].upper() == "TO":
            i += 1
            if i < len(tokens):
                query.blob_dest_bucket = String(tokens[i])
                i += 1
            if i < len(tokens):
                query.blob_dest_key = String(tokens[i])
    elif tokens[i].upper() == "RUN":
        i += 1
        if i < len(tokens) and tokens[i].upper() == "TESTS":
            query.query_type = "RUN_TESTS"
            query.run_tests = True
        elif i < len(tokens) and tokens[i].upper() == "SNAPSHOT":
            query.query_type = "RUN_SNAPSHOT"
            i += 1
            if i < len(tokens):
                query.run_snapshot_name = String(tokens[i])
    
    if query.query_type == "":
        query.query_type = "PL"
        query.pl_code = sql
    
    return query ^