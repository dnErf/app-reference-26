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
        self.func_async = False
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
            # Optional AS ASYNC
            if i < len(tokens) and tokens[i].upper() == "AS":
                i += 1
                if i < len(tokens) and tokens[i].upper() == "ASYNC":
                    query.func_async = True
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
    
    elif tokens[i].upper() == "SELECT":
        query.query_type = "SELECT"
        i += 1
        # Parse columns (assume * for now)
        if tokens[i] == "*":
            query.columns.append("*")
            i += 1
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
    
    elif tokens[i].upper() == "FROM":
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
    
    return query ^