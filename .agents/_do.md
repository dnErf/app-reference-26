# Current Priority Tasks - REPL Feature Implementation

## ✅ COMPLETED: Phase 1 - Core Infrastructure (Today)

### ✅ Task 1: Refactor REPL to use execute_query
- ✅ Replaced custom execute_sql logic with proper SQL parsing
- ✅ Added error handling for query execution
- ✅ Implemented result display formatting
- ✅ Tested basic SELECT * functionality

### ✅ Task 2: Add Basic SELECT Operations
- ✅ Implemented `SELECT * FROM table` command
- ✅ Added support for `SELECT COUNT(*) FROM table`
- ✅ Added `SELECT SUM(age) FROM table`
- ✅ Added `SELECT * FROM table WHERE age > 25`

### ✅ Task 3: Add More Aggregate Functions
- ✅ Implement `SELECT AVG(column) FROM table`
- ✅ Add `SELECT MIN(column) FROM table`
- ✅ Add `SELECT MAX(column) FROM table`
- ✅ Add `SELECT PERCENTILE(column, 0.5) FROM table`

### ✅ Task 4: Add File Loading Commands
- ✅ Implement `LOAD JSONL 'filename.jsonl'` - Working in REPL
- [ ] Add `LOAD PARQUET 'filename.parquet'` - Not implemented yet
- [ ] Add `LOAD AVRO 'filename.avro'` - Not implemented yet
- [ ] Add `LOAD CSV 'filename.csv'` - Not implemented yet
- [ ] Add `SAVE table_name AS 'filename.format'` - Not implemented yet

### 🔄 FUTURE: Task 5: Add Table Management
- [ ] Implement `CREATE TABLE table_name (col1 type, col2 type)`
- [ ] Add `INSERT INTO table_name VALUES (...)`
- [ ] Add `UPDATE table_name SET col=val WHERE condition`
- [ ] Add `DELETE FROM table_name WHERE condition`

## Testing & Validation
- [ ] Test each new command with sample data
- [ ] Verify error handling works properly
- [ ] Ensure performance is acceptable
- [ ] Update help system with new commands

## Success Criteria
- [ ] REPL can execute basic SELECT queries ✅
- [ ] Aggregate functions work correctly ✅
- [ ] File operations work for loading/saving data
- [ ] Table management (CRUD) operations functional
- [ ] Error messages are helpful and informative
- [ ] Performance is acceptable for demo purposes