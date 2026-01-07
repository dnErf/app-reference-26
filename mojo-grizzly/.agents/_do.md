# Current Tasks - CLI Implementation Focus

## High Priority - Core CLI Commands

### File Loading Commands
- [x] LOAD SAMPLE DATA - Basic sample data loading ✅
- [x] LOAD JSONL - JSONL file loading ✅
- [ ] LOAD PARQUET - Parquet columnar file support
- [ ] LOAD AVRO - Avro file format support
- [ ] LOAD CSV - CSV file loading with options

### SQL Query Commands
- [x] SELECT * FROM table - Basic table display ✅
- [x] SELECT COUNT(*) - Row counting ✅
- [x] SELECT SUM/AVG/MIN/MAX - Aggregate functions ✅
- [x] SELECT with WHERE - Basic filtering ✅
- [ ] Advanced SQL - JOIN, GROUP BY, ORDER BY, LIMIT

### Table Management Commands
- [x] SHOW TABLES - List available tables ✅
- [ ] DESCRIBE TABLE - Show table schema
- [ ] CREATE TABLE - Create new tables
- [ ] DROP TABLE - Remove tables
- [ ] INSERT INTO - Add new rows
- [ ] UPDATE - Modify existing rows
- [ ] DELETE FROM - Remove rows

## Medium Priority - Database Operations

### .griz File Format
- [ ] CREATE DATABASE - Create new .griz files
- [ ] ATTACH DATABASE - Attach database files
- [ ] DETACH DATABASE - Detach database files
- [ ] SHOW DATABASES - List attached databases
- [ ] DATABASE INFO - Show database details

### Database Maintenance
- [ ] VACUUM - Optimize database files
- [ ] PRAGMA integrity_check - Verify file integrity
- [ ] BACKUP/RESTORE - Database backup operations

## Medium Priority - CLI Modes & Interfaces

### Command-Line Interface Modes
- [ ] Batch Mode - Execute SQL from files/stdin
- [ ] Server Mode - REST API server
- [ ] Import/Export Mode - Data migration tools
- [ ] Configuration Mode - Settings management

### Command-Line Options
- [ ] Global Options - --help, --version, --verbose, --quiet
- [ ] REPL Options - --database, --history, --no-banner
- [ ] Batch Options - --command, --file, --output, --format
- [ ] Performance Options - --memory-limit, --threads

## Low Priority - Advanced Features

### Packaging System
- [ ] PACKAGE INIT - Initialize new projects
- [ ] PACKAGE ADD FILE/DEP - Add files and dependencies
- [ ] PACKAGE BUILD - Build executables
- [ ] PACKAGE INSTALL - Install packages
- [ ] Cross-compilation support

### Extensions System
- [ ] LOAD EXTENSION - Load extension modules
- [ ] Extension management commands

### Security & Authentication
- [ ] LOGIN/AUTH commands
- [ ] Token-based authentication

## Implementation Notes

### Current Status
- ✅ Basic REPL with HELP, LOAD SAMPLE DATA, SELECT operations
- ✅ JSONL file loading
- 🔄 Ready for next phase: File format support (PARQUET/AVRO)

### Next Steps Priority
1. **File Format Support**: Implement LOAD PARQUET/AVRO using existing format functions
2. **Table Management**: Add CREATE/INSERT/UPDATE/DELETE operations
3. **Database Files**: Implement .griz file creation and attachment
4. **CLI Modes**: Add batch processing and command-line options

### Testing Requirements
- [ ] Unit tests for each command
- [ ] Integration tests for command sequences
- [ ] File format compatibility tests
- [ ] Performance benchmarks

### Documentation Updates
- [ ] Update HELP command with new features
- [ ] Add examples for new commands
- [ ] Create command reference documentation
