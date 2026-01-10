"""
Mojo Kodiak DB - Shared Types

Defines shared data structures.
"""

@fieldwise_init
struct Row(Copyable, Movable):
    """
    Represents a single row of data.
    """
    var data: Dict[String, String]  # Simple key-value for now

    fn __init__(out self):
        self.data = Dict[String, String]()

    fn __getitem__(self, key: String) raises -> String:
        return self.data[key]

    fn __setitem__(mut self, key: String, value: String):
        self.data[key] = value

    fn keys(self) -> List[String]:
        """
        Get all keys in the row.
        """
        var result = List[String]()
        for key in self.data.keys():
            result.append(key)
        return result^

    fn __contains__(self, key: String) -> Bool:
        """
        Check if key exists in the row.
        """
        return key in self.data

@fieldwise_init
struct Table(Copyable, Movable):
    """
    Represents a table with rows.
    """
    var name: String
    var schema: Dict[String, String]  # Column name -> type
    var rows: List[Row]

    fn __init__(out self, name: String, rows: List[Row]):
        self.name = name
        self.schema = Dict[String, String]()
        self.rows = rows.copy()

    fn insert_row(mut self, row: Row):
        """
        Insert a new row into the table.
        """
        self.rows.append(row.copy())

    fn update_row(mut self, index: Int, new_row: Row):
        """
        Update a row at the given index.
        """
        if index >= 0 and index < len(self.rows):
            self.rows[index] = new_row

    fn delete_row(mut self, index: Int):
        """
        Delete a row at the given index.
        Note: This is inefficient for large lists; in production, use a better data structure.
        """
        if index >= 0 and index < len(self.rows):
            # Simple removal by shifting
            var new_rows = List[Row]()
            for i in range(len(self.rows)):
                if i != index:
                    new_rows.append(self.rows[i])
            self.rows = new_rows

    fn select_rows(self, filter_func: fn(Row) raises -> Bool) raises -> List[Row]:
        """
        Select rows that match the filter function.
        """
        var result = List[Row]()
        for row in self.rows:
            if filter_func(row):
                result.append(row.copy())
        return result^

    fn select_all(self) -> List[Row]:
        """
        Select all rows.
        """
        var result = List[Row]()
        for row in self.rows:
            result.append(row.copy())
        return result^