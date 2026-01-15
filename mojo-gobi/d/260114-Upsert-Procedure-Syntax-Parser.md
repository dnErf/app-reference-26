# Upsert Procedure Syntax Parser - 260114

## Overview
Completed implementation of parser support for `upsert procedure` syntax with model-like declarations, establishing the foundation for SQLMesh-inspired stored procedures in PL-GRIZZLY.

## Implementation Details

### Parser Method: `upsert_procedure_statement()`
Located in `pl_grizzly_parser.mojo`, this method handles the complete parsing of upsert procedure statements.

### Supported Syntax
```
upsert procedure as procedure_name <{metadata}> (parameters) returns return_type { body }
```

### Syntax Components

#### 1. Procedure Declaration
- `upsert procedure as procedure_name`
- Creates `AST_UPSERT_PROCEDURE` node with `name` attribute

#### 2. Metadata Block
- `<{key1: 'value1', key2: 'value2'}>`
- Parsed as `METADATA` child node
- Supports model-like properties: `kind`, `sched`, etc.
- Example: `<{kind: 'incremental', sched: '@daily'}>`

#### 3. Parameter List
- `(param1: type1, param2: type2, ...)`
- Each parameter becomes a `PARAMETER` child node
- Type annotations are optional
- Stored as `type` attribute on parameter nodes

#### 4. Return Type
- `returns void|type`
- Stored as `return_type` attribute on procedure node

#### 5. Procedure Body
- `{ statements }`
- Parsed as `BLOCK` child node containing statement nodes
- Supports multiple statements within the block

### AST Structure
```
AST_UPSERT_PROCEDURE
├── attributes: {name: "proc_name", return_type: "int"}
├── METADATA (child)
│   └── attributes: {kind: "incremental", sched: "@daily"}
├── PARAMETER (child)
│   └── attributes: {type: "int"}
├── PARAMETER (child)
│   └── attributes: {type: "int"}
└── BLOCK (child)
    └── statement nodes...
```

### Test Coverage
Created comprehensive test suite in `test_upsert_procedure_parser.mojo`:

1. **Basic Procedure Test**
   ```sql
   upsert procedure as test_proc <{kind: 'default'}> () returns void { print('hello'); }
   ```

2. **Parameterized Procedure Test**
   ```sql
   upsert procedure as calc_proc <{kind: 'incremental', sched: '@daily'}> (a: int, b: int) returns int { return a + b; }
   ```

### Error Handling
- Descriptive error messages for malformed syntax
- Validation of required keywords (`as`, `returns`)
- Proper brace/bracket matching
- Token consumption validation

### Integration
- Seamlessly integrated with existing PL-GRIZZLY parser
- Uses existing token types and AST infrastructure
- Maintains backward compatibility
- Compiles successfully with main codebase

## Files Modified
- `pl_grizzly_parser.mojo` - Added `upsert_procedure_statement()` method
- `test_upsert_procedure_parser.mojo` - Created comprehensive test suite

## Next Steps
1. **Function Declaration Extensions** - Add `<ReceiverType>`, `raises Exception`, `as async|sync`
2. **Procedure Execution Engine** - Implement runtime execution environment
3. **Procedure Management** - Add LIST/DROP PROCEDURES commands

## Impact
This implementation provides the parsing foundation for SQLMesh-inspired stored procedures, enabling data transformation automation capabilities in PL-GRIZZLY.