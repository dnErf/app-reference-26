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

    fn __init__(out self):
        self.query_type = ""
        self.table_name = ""
        self.columns = List[String]()
        self.values = List[String]()
        self.where_column = ""
        self.where_op = ""
        self.where_value = ""

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
        query.query_type = "CREATE"
        i += 1
        if i < len(tokens) and tokens[i].upper() == "TABLE":
            i += 1
            if i < len(tokens):
                query.table_name = String(tokens[i])
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
    
    else:
        raise Error("Unsupported query type: " + String(tokens[i]))
    
    return query ^