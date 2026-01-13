"""
PyArrow File Writer Extension for PL-GRIZZLY

This extension provides support for writing PyArrow-supported file formats for COPY export operations.
Supported formats: ORC, Parquet, Feather, and JSON files.
"""

from collections import List, Dict
from pl_grizzly_values import PLValue
from python import Python, PythonObject


struct PyArrowFileWriter:
    """
    PyArrow file writer extension for handling file export operations in COPY statements.
    Supports ORC, Parquet, Feather, and JSON formats.
    """

    fn __init__(out self):
        """Initialize the PyArrow file writer extension."""
        pass

    fn is_supported_file(self, file_path: String) -> Bool:
        """
        Check if a file path corresponds to a supported PyArrow format for writing.

        Args:
            file_path: The file path to check

        Returns:
            True if the file format is supported for writing
        """
        var lower_path = file_path.lower()
        return (lower_path.endswith(".orc") or
                lower_path.endswith(".parquet") or
                lower_path.endswith(".feather") or
                lower_path.endswith(".json"))

    fn get_file_format(self, file_path: String) -> String:
        """
        Get the file format from the file extension.

        Args:
            file_path: The file path

        Returns:
            The file format as a string ("orc", "parquet", "feather", "json")
        """
        var lower_path = file_path.lower()
        if lower_path.endswith(".orc"):
            return "orc"
        elif lower_path.endswith(".parquet"):
            return "parquet"
        elif lower_path.endswith(".feather"):
            return "feather"
        elif lower_path.endswith(".json"):
            return "json"
        else:
            return "unknown"

    fn write_file_data(self, file_path: String, table_data: List[List[String]], column_names: List[String]) raises -> Bool:
        """
        Write data to a supported file format using PyArrow.

        Args:
            file_path: Path to the file to write
            table_data: List of rows, where each row is a list of string values
            column_names: List of column names

        Returns:
            True if the write operation was successful
        """
        try:
            # Import required modules
            var pa = Python.import_module("pyarrow")
            var pd = Python.import_module("pandas")

            # Convert table_data to pandas DataFrame
            # Create a dictionary of lists for pandas
            var py_data = Python.dict()
            
            for i in range(len(column_names)):
                var col_name = column_names[i]
                var col_data = Python.list()
                
                for row in table_data:
                    if i < len(row):
                        col_data.append(row[i])
                    else:
                        col_data.append("")  # Empty string for missing values
                
                py_data[col_name] = col_data

            # Create pandas DataFrame
            var df = pd.DataFrame(py_data)

            var format_type = self.get_file_format(file_path)

            # Write the file based on format
            if format_type == "orc":
                var orc = Python.import_module("pyarrow.orc")
                # Convert DataFrame to PyArrow table
                var table = pa.Table.from_pandas(df)
                orc.write_table(table, file_path)
            elif format_type == "parquet":
                var pq = Python.import_module("pyarrow.parquet")
                # Convert DataFrame to PyArrow table
                var table = pa.Table.from_pandas(df)
                pq.write_table(table, file_path)
            elif format_type == "feather":
                # Convert DataFrame to PyArrow table
                var table = pa.Table.from_pandas(df)
                pa.feather.write_feather(table, file_path)
            elif format_type == "json":
                # Write directly as JSON from pandas
                df.to_json(file_path, orient="records", indent=2)
            else:
                raise Error("Unsupported file format: " + format_type)

            return True

        except e:
            raise Error("Failed to write file '" + file_path + "': " + String(e))