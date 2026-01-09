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
    
    else:
        raise Error("Unsupported query type: " + String(tokens[i]))
    
    return query ^