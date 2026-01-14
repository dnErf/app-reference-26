# COPY PyArrow File Import/Export Implementation

## Overview
Successfully implemented complete COPY statement functionality for PL-GRIZZLY to support importing data from external PyArrow-supported files into existing tables and exporting table data to external files.

## Syntax Support

### Import Syntax (File to Table)
```pl-grizzly
COPY 'file_path' TO table_name
```

### Export Syntax (Table to File)
```pl-grizzly
COPY table_name TO 'file_path'
```

## Supported File Formats
- **ORC** (.orc) - Optimized Row Columnar format
- **Parquet** (.parquet) - Columnar storage format
- **Feather** (.feather) - Fast on-disk format
- **JSON** (.json) - JavaScript Object Notation

## Implementation Details

### Lexer Changes
- Added `COPY` keyword to keywords dictionary
- Added `COPY` token alias for lexical recognition
- Added `TO` keyword and token alias for syntax support

### Parser Changes
- Added `COPY` and `TO` token imports
- Added `AST_COPY` node type definition
- Implemented `copy_statement()` method with dual syntax support:
  - String literal first → Table name second (import)
  - Identifier first → String literal second (export)

### AST Node Structure
COPY AST nodes include the following attributes:
- `source_type`: "file" or "table"
- `source`: The source file path or table name
- `destination_type`: "table" or "file"
- `destination`: The destination table name or file path
- `operation`: "import" or "export"

## AST Evaluator Integration

### PyArrow Writer Extension
Created `extensions/pyarrow_writer.mojo` with `PyArrowFileWriter` struct:
- `is_supported_file()`: Checks file format support for writing
- `write_file_data()`: Writes table data to supported file formats using pandas/pyarrow

### Evaluation Logic
Implemented `eval_copy_node()` in ASTEvaluator:

#### Import Operation (`COPY 'file' TO table`)
1. Validates file format support using PyArrow reader
2. Reads file data using `pyarrow_reader.read_file_data()`
3. Checks if destination table exists, creates it if needed with string columns
4. Saves data to ORC storage using `orc_storage.save_table()`
5. Returns success message with row count

#### Export Operation (`COPY table TO 'file'`)
1. Validates file format support using PyArrow writer
2. Checks if source table exists using schema manager
3. Reads table data from ORC storage using `orc_storage.read_table()`
4. Extracts column names from table schema
5. Writes data to file using `pyarrow_writer.write_file_data()`
6. Returns success message with row count

### Error Handling
- **File Format Errors**: Unsupported file formats with format suggestions
- **Table Not Found**: Missing source tables with table name validation
- **I/O Errors**: File read/write failures with detailed error context
- **Schema Errors**: Table creation failures with schema validation

## Technical Implementation

### Parser Logic
```mojo
fn copy_statement(mut self) raises -> ASTNode:
    """Parse COPY statement for importing/exporting data."""
    var node = ASTNode(AST_COPY, "", self.previous().line, self.previous().column)

    if self.match(STRING):
        // Import: COPY 'file_path' TO table_name
    elif self.match(IDENTIFIER):
        // Export: COPY table_name TO 'file_path'
```

### Evaluator Logic
```mojo
fn eval_copy_node(mut self, node: ASTNode, mut env: Environment, mut orc_storage: ORCStorage) raises -> PLValue:
    var operation = node.get_attribute("operation")
    
    if operation == "import":
        // Read file, create table if needed, save data
    elif operation == "export":
        // Read table, write to file
```

## Build Status
✅ **Compilation**: Successful with complete COPY implementation integrated
✅ **Syntax Recognition**: Parser correctly identifies and parses COPY statements
✅ **AST Generation**: Proper AST nodes generated with semantic attributes
✅ **Evaluation Logic**: Complete import/export execution with error handling

## Testing Status
✅ **Parser Testing**: COPY statements parse correctly into AST nodes
✅ **Evaluator Integration**: Import/export logic implemented and ready for testing
⏳ **Integration Testing**: Ready for end-to-end file operation testing

## Impact
PL-GRIZZLY now supports complete data pipeline workflows with standardized COPY syntax for moving data between files and tables using the PyArrow ecosystem, enabling seamless data import/export operations for ORC, Parquet, Feather, and JSON formats.