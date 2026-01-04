# AGENTS WORKFLOW GUIDELINES

## Principles
- Conscious and concise changes only
- No unrelated refactors
- Use `zig build` for Grizzly projects
- Every sprint ships code, docs, and tests together

## Commit Format
`type: description` where type is: ft, fx, up, ch, ci, docs

## Roles
- **Owner**: Specs (`specs/`), QA checklist (`.agents/_qa.md`), approval
- **Developer**: Planning (`.agents/_plan.md`), implementation, CI/testing

## Workflow
1. **Understand** - Confirm acceptance criteria
2. **Spec** - For medium+ complexity, add/update `specs/*.json`
3. **Plan** - Create/update `.agents/_plan.md`
4. **Implement** - Write code
5. **QA** - Run tests: `zig test src/root.zig` (baseline) + feature-specific tests
6. **Document** - Update `.agents/SPRINT_<theme>.md` and link from README

## Error Handling Protocol
When encountering compilation or runtime errors:

1. **Diagnosis Phase**
   - Run `zig build 2>&1 | head -50` to capture initial errors
   - Identify error location, type, and root cause
   - Note the Zig version and affected module

2. **Documentation Phase**
   - Update `.agents/ERROR_ANALYSIS.md` with:
     - **Error Location**: Exact file and line number
     - **Error Message**: Complete compiler/runtime error text
     - **Root Cause**: Why the error occurs (API change, type mismatch, etc.)
     - **Context Code**: Relevant code snippet (5-10 lines)
     - **Proposed Solutions**: 2-3 numbered options with trade-offs
   - Format errors chronologically with timestamp

3. **Solution Selection**
   - Choose solution based on:
     - Impact on core functionality (prefer non-breaking)
     - Development effort vs. benefit
     - Agent workflow compatibility
     - Long-term maintainability
   - Document decision rationale in ERROR_ANALYSIS.md

4. **Implementation**
   - Apply fix with minimal scope (single error at a time)
   - Add inline comments explaining Zig 0.15 compatibility
   - Update ERROR_ANALYSIS.md with "✅ FIXED" status

5. **Verification**
   - Run `zig build` to confirm error is resolved
   - Check for cascade/secondary errors
   - Verify affected feature works as intended
   - Update ERROR_ANALYSIS.md with verification result

## ERROR_ANALYSIS.md Format
```
# [Feature/Module Name] Error Analysis & Solutions

**Date**: YYYY-MM-DD
**Sprint**: [Current sprint]
**Status**: [In Progress | Resolved | Deferred]

## Error: [Brief Error Title]

### Location
- File: `path/to/file.zig:LINE`
- Module: [relevant module]

### Error Message
```
[Complete compiler/runtime error]
```

### Root Cause
[Explanation of why error occurs, reference Zig version/API changes]

### Current Code
```zig
[5-10 lines of context around error]
```

### Proposed Solutions

#### Option A: [Solution Name] (RECOMMENDED/ALTERNATIVE/DEFERRED)
```zig
[Fixed code example]
```
**Pros**: [Benefits]
**Cons**: [Trade-offs]
**Effort**: [Time estimate]
**Risk**: [Assessment]

#### Option B: [Alternative Solution]
[Similar format as Option A]

### Decision
**Selected**: Option A
**Rationale**: [Why this solution chosen]
**Status**: ✅ FIXED | ⏸️ DEFERRED

### Verification
- ✅ Compiles without errors
- ✅ Affected feature works
- ✅ No new errors introduced
```

## Project Structure
```
.agents/              # All agent reports and planning
  _plan.md           # Current sprint plan
  _qa.md             # QA checklist (if needed)
  _roadmap.md        # Strategic roadmap and future sprints
  specs/             # JSON schemas for features
  SPRINT_*.md        # Sprint documentation
  *_REPORT.md        # Verification/delivery reports
  *.json             # Audit logs, query traces
src/                 # Core source code
examples/            # Demo and example applications
tests/               # Test files and test suites
scripts/             # Utility scripts
```

**Note**: `TRANSFORMATION_ROADMAP.md` and `STRATEGIC_ROADMAP.md` are deprecated. All roadmap planning is now consolidated in `_roadmap.md`.

## AI Checkpointing
**Purpose**: Resume interrupted long-running operations (rate limits, crashes)

**Implementation**:
- Checkpoint file: `.ai_checkpoint.json` (git-ignored, ephemeral)
- API: `src/checkpoint.zig` (write/read/clear helpers)
- Used by: `Lakehouse.save` and other long-running procedures
- Inspect: `zig run scripts/ai_resume.zig`
- Clear: `zig run scripts/ai_resume.zig -- --clear`

**Best Practices**:
- Keep granularity small (per-table, per-column)
- Make operations idempotent or detect completed work
- Never store secrets in checkpoints
- Include error details for intelligent retry

## Testing
- **Baseline**: `zig test src/root.zig`
- **Feature demos**: `zig build run-sprint3`, `zig build run-sprint2`
- **Coverage**: Record unusual test commands in `.agents/_qa.md`
- **Test Organization**: All test files are located in the `tests/` folder

---

## Current Status: ✅ SPRINT 13 - CREATE TYPE COMPLETE

**Language**: Pure Zig 0.15.2 (zero dependencies)
**Goal**: Implement comprehensive user-defined type support

### Latest Sprint: Sprint 13 - Create Type ✅ COMPLETE
- [x] Implement CREATE TYPE AS ENUM syntax with validation
- [x] Implement CREATE TYPE AS STRUCT syntax with nested fields
- [x] Add type aliasing functionality (CREATE TYPE alias AS target_type)
- [x] Add SHOW TYPES and DESCRIBE TYPE commands
- [x] Implement DROP TYPE and ALTER TYPE commands
- [x] Custom type serialization in lakehouse format
- [x] Type validation and conversion in queries
- 📄 See `.agents/_plan.md` for complete details
- 📋 See `.agents/_qa.md` for testing results
- 📋 Spec: `.agents/specs/sprint13-create-type.json`

### ✅ Testing (66/66 tests passing)
- All baseline tests passing
- CREATE TYPE ENUM functionality validated
- CREATE TYPE STRUCT functionality validated
- Type aliasing working correctly
- SHOW TYPES and DESCRIBE TYPE commands working
- Custom types in table schemas supported
- Type validation during INSERT operations
- All existing functionality preserved
- Zero compilation errors in core features

---

## 🚀 READY FOR SPRINT 14: PL-Grizzly - SQL Templating & Stored Procedures

**Next Sprint**: Sprint 14 (8-10 weeks)
**Theme**: PL-Grizzly - Comprehensive procedural language for SQL templating and stored procedures
**Goal**: Complete dbt replacement with dynamic model generation and callable functions

### Sprint 14 Objectives
- [x] **Phase 1 COMPLETE**: Implement PL-Grizzly expression language foundation
- [x] Expression evaluation engine with variables and literals
- [x] Template compilation with {variable} syntax
- [x] Conditional logic (if/else expressions)
- [x] Let bindings for variable assignment
- [x] SQL parser integration for CREATE MODEL templating
- [x] **Phase 2 COMPLETE**: Add CREATE FUNCTION syntax for runtime and compile-time functions
- [x] Pattern matching and pipes
- [x] Async-by-default execution model
- [x] Advanced function system with dual execution modes

### Key Features to Implement
- **Dual Functionality**: SQL templating (dbt alternative) + stored procedures
- **Expression Language**: Variables, conditionals, loops, functions
- **Template Syntax**: `{variable}` instead of `{{variable}}`
- **Function System**: CREATE FUNCTION for both runtime and compile-time use
- **Async Execution**: All functions async by default with opt-in sync
- **Pattern Matching**: Advanced data transformation capabilities

```sql
-- Async by default (non-blocking)
CREATE FUNCTION process_data(data JSON) RETURNS JSON {
  let result = expensive_computation(data);
  result
}

CREATE FUNCTION process_data(data JSON) RETURNS JSON AS ASYNC {
  let result = expensive_computation(data);
  result
}

-- Explicit synchronous execution
CREATE FUNCTION sync_process(data JSON) RETURNS JSON AS SYNC {
  let result = expensive_computation(data);
  result
}
```

### Technical Foundation Ready ✅
- ✅ Extended type system (Sprint 13 complete)
- ✅ SQL parser with custom syntax support
- ✅ Lakehouse storage with custom types
- ✅ Query engine extensibility
- ✅ Zero dependencies maintained

**Status**: Sprint 14 Phase 4 Complete ✅ - Integration & Optimization (full SQL engine integration, performance optimization, comprehensive testing, documentation, backward compatibility)
**Next Phase**: Sprint 15 - Advanced Features (pattern matching, advanced functions, error handling)
**Spec**: See `.agents/specs/sprint14-pl-grizzly.json` for detailed specification
**Roadmap**: See `.agents/_roadmap.md` for Sprint 14 technical details

## Performance Results

| Operation | Result | Details |
|-----------|--------|---------|
| **Insert** | 2.3M rows/sec | 100k rows in 43ms |
| **SUM** | 0.27ms | 100k rows |
| **AVG** | 0.25ms | 100k rows |
| **MAX** | 27.96ms | 100k rows |
| **CTAS** | ~50ms | Create table from 10k row query |
| **Model Creation** | <1ms | Model registration overhead |

## Technical Decisions

1. **Model Registry Pattern**: Consistent with views/materialized views
2. **Dependency Analysis**: SQL parsing for automatic lineage extraction
3. **DAG Implementation**: Adjacency list with topological sort
4. **Cycle Detection**: DFS-based algorithm with recursion stack
5. **Audit Integration**: All model operations logged
6. **Zero Dependencies**: Pure Zig stdlib only
7. **Incremental Architecture**: Build upon existing patterns

## Sprint 10 Progress

### Phase 1: CTAS ✅ COMPLETE
- CREATE TABLE AS SELECT syntax
- Schema inference from query results
- Table creation from SELECT queries

### Phase 2: Model Framework ✅ COMPLETE
- CREATE MODEL syntax parsing
- Model registry with metadata
- Dependency tracking
- Database integration

### Phase 3: Dependency DAG ✅ COMPLETE
- Graph data structure implementation
- Topological sort for execution order
- REFRESH MODEL command
- SHOW LINEAGE and SHOW DEPENDENCIES commands
- Cycle detection
- DOT format export for visualization

## Known Limitations

- CTE module has compilation issues (unrelated to core features)
- Dependency graph rebuilding temporarily disabled due to hash map corruption in dependency analyzer
- No JOINs, subqueries, or complex WHERE clauses
- No indexes (all queries are table scans)
- No transactions or ACID guarantees

## Sprint 12 - Persistence SQL Commands ✅ COMPLETE

### Completed Features
- [x] **SAVE DATABASE**: Export current database to .griz file with compression options (lz4, zstd, gzip, snappy, none)
- [x] **LOAD DATABASE**: Import database from .griz file with validation
- [x] **ATTACH DATABASE**: Mount additional databases read-only with aliases
- [x] **DETACH DATABASE**: Remove attached databases by alias
- [x] **SHOW DATABASES**: List all attached databases with their aliases
- [x] **Database Connection Management**: Multi-database support with alias-based access
- [x] **File Validation**: Automatic validation of database files during load/attach operations

### Key Features Implemented
- **SAVE DATABASE**: `SAVE DATABASE TO 'file.griz' WITH COMPRESSION lz4;`
- **LOAD DATABASE**: `LOAD DATABASE FROM 'file.griz';`
- **ATTACH DATABASE**: `ATTACH DATABASE 'file.griz' AS alias;`
- **DETACH DATABASE**: `DETACH DATABASE alias;`
- **SHOW DATABASES**: `SHOW DATABASES;`
- **File Validation**: Automatic format and integrity checking
- **Compression Support**: Multiple algorithms with performance trade-offs
- **Error Handling**: Comprehensive error reporting for file operations

### Sprint Spec
- 📋 See `.agents/specs/sprint12-persistence-sql.json` (to be created)

## Sprint 12 Progress ✅ COMPLETE

### Current Status: All Phases Complete
**Theme**: SQL Interface for Database Persistence
**Goal**: Provide complete SQL interface for database save/load and multi-database workflows

### Phase 1: SAVE DATABASE Command ✅ COMPLETE
- [x] SAVE token recognition in tokenizer
- [x] SAVE DATABASE TO 'file.griz' syntax parsing
- [x] File path validation and error handling
- [x] Integration with lakehouse save functionality
- [x] Compression option parsing (WITH COMPRESSION)
- [x] Compression algorithm validation (lz4, zstd)
- [x] File overwrite protection and confirmation

### Phase 2: LOAD DATABASE Command ✅ COMPLETE
- [x] LOAD DATABASE FROM 'file.griz' syntax parsing
- [x] File existence and format validation
- [x] Database loading with lakehouse.load()
- [x] Current database replacement
- [x] Error handling for invalid files

### Phase 3: ATTACH/DETACH DATABASE Commands ✅ COMPLETE
- [x] ATTACH DATABASE 'file.griz' AS alias syntax
- [x] Database registry management for multi-database support
- [x] DETACH DATABASE alias syntax
- [x] Read-only access to attached databases
- [x] Resource cleanup and memory management

### Phase 4: Database Management & Validation ✅ COMPLETE
- [x] SHOW DATABASES command for listing attached databases
- [x] Database metadata display (name, alias)
- [x] File validation during attach/load operations
- [x] Error handling for duplicate aliases and missing databases

### Phase 5: Integration & Testing ✅ COMPLETE
- [x] All commands working together seamlessly
- [x] Comprehensive error handling across all operations
- [x] SELECT * expansion fixed for loaded databases
- [x] Full test coverage and backward compatibility

### Sprint Spec
- 📋 See `.agents/specs/sprint12-persistence-sql.json`
- 📄 See `.agents/SPRINT_12.md` for detailed implementation report

---

## Sprint 11 Summary ✅ COMPLETE

### Completed Features
- ✅ PARTITION BY clause for incremental models
- ✅ Incremental refresh logic with state tracking
- ✅ Automated model refresh scheduler with cron syntax
- ✅ Column-level lineage tracking
- ✅ DAG performance optimization with parallel execution
- ✅ Comprehensive testing (61/61 tests passing)

### Key Achievements
- Complete dbt-like incremental processing
- Automated scheduling with retry logic
- Advanced lineage analysis
- Parallel execution capabilities
- Production-ready error handling

### Technical Metrics
- **Lines Added**: 730 lines across 7 files
- **Test Coverage**: 100% for new features
- **Performance**: Cached DAG operations, parallel execution
- **Zero Dependencies**: Pure Zig implementation

```
src/                 # Core application source code
├── root.zig         # Module exports
├── types.zig        # Data types and Value union
├── schema.zig       # Table schema definitions
├── column.zig       # Columnar storage with aggregations
├── table.zig        # Table operations
├── database.zig     # Multi-table management
├── query.zig        # SQL tokenizer and executor
├── export.zig       # Export formats (JSON/CSV/Binary)
├── model.zig        # Model definitions and registry
├── incremental.zig  # Incremental model logic
├── scheduler.zig    # Automated refresh scheduling
└── ...              # Additional core modules

examples/            # Demo and example applications
├── main_*.zig       # Various demo applications
└── ...              # Example implementations

tests/               # Test files and test suites
├── test_*.zig       # Unit and integration tests
└── ...              # Test data and fixtures
```

## Demo Output

```
Database: my_database
Creating table: users
Inserted 4 rows

Aggregations:
  Average age: 29.50
  Max salary: $85,000.00
  Min salary: $65,000.00
  Total salary: $295,000.00

Exports:
  JSON: 510 bytes
  JSONL: 257 bytes
  CSV: 124 bytes
  Binary: 186 bytes (3.2x compression)
```

## Success Criteria: ALL MET ✅

✅ **Functional**: All core features working
✅ **Fast**: 2.3M rows/sec insertion
✅ **Tested**: 14 tests passing
✅ **Documented**: Complete README
✅ **AI-Friendly**: 4 export formats
✅ **Zero Dependencies**: Pure Zig
✅ **MVP Ready**: Fully functional demo

---

**Status**: Ready for user review and next phase development

## Sprint 11 - Incremental Models (Phase 3: Model Refresh Scheduler) ✅ COMPLETE

### Completed Features
- **Automated Model Refresh**: Background thread-based scheduling system
- **Cron Expression Parsing**: Full cron syntax support (minutes, hours, days, months, weekdays)
- **Retry Logic**: Configurable retry attempts with exponential backoff
- **SQL Commands**: CREATE/DROP/SHOW SCHEDULE syntax
- **Background Execution**: Non-blocking scheduler with proper thread management
- **Audit Integration**: Scheduler events logged to audit system
- **Project Reorganization**: Tests moved to `tests/`, demos to `examples/`
- **CTE Functionality Restored**: WITH clause parsing and execution working

### Technical Implementation
- **Scheduler Architecture**: Thread-based background execution with proper cleanup
- **Cron Parser**: Custom cron expression parser with validation
- **Database Integration**: Scheduler embedded in Database struct
- **Memory Management**: Proper allocator handling and resource cleanup
- **Error Handling**: Comprehensive error handling for scheduling failures
- **Testing**: All 61 tests passing, scheduler demo functional

### Success Criteria: ALL MET ✅
✅ **Functional**: Automated scheduling with cron syntax and retry logic  
✅ **Tested**: 61/61 tests passing, scheduler demo works
✅ **Documented**: README updated, AGENTS.md current
✅ **Zero Dependencies**: Pure Zig implementation
✅ **Thread-Safe**: Background execution without blocking
✅ **SQL Integration**: CREATE/DROP/SHOW SCHEDULE commands working

## Sprint 11 - Column-Level Lineage (Phase 4) ✅ COMPLETE

### Completed Features
- **Column-Level Lineage Tracking**: Extended SHOW LINEAGE to support column dependencies
- **SQL Syntax Extension**: Added `SHOW LINEAGE FOR COLUMN table.column` syntax
- **Token Parser Enhancement**: Added dot (.) token type for table.column parsing
- **Column Dependency Analysis**: Basic SQL parsing to extract column-to-column mappings
- **Model Integration**: Column lineage works with existing model definitions
- **Case-Insensitive Matching**: Proper handling of column name comparisons

### Technical Implementation
- **Query Engine Extension**: Added `getColumnLineage()` and `analyzeColumnDependencies()` methods
- **SQL Parsing Logic**: Basic SELECT clause parsing to identify column expressions and aliases
- **Memory Management**: Proper allocation/deallocation of lineage result strings
- **Error Handling**: Comprehensive error handling for malformed queries and missing columns
- **Tokenizer Enhancement**: Added dot token support for qualified column names

### Success Criteria: ALL MET ✅
✅ **Functional**: `SHOW LINEAGE FOR COLUMN table.column` syntax working
✅ **Tested**: Column lineage demo shows correct dependencies (COUNT, AVG, age)
✅ **Documented**: Implementation details captured in AGENTS.md
✅ **SQL Integration**: Works with existing CREATE MODEL and query infrastructure
✅ **Memory Safe**: Proper resource cleanup and allocation handling
✅ **Extensible**: Foundation for more sophisticated column dependency analysis

## Sprint 11 - DAG Performance Optimization (Phase 5) ✅ COMPLETE

### Completed Features
- **DAG Caching System**: Hash map-based caching for dependency lookups and topological sorts
- **Parallel Execution Groups**: Identification of models that can run concurrently within dependency groups
- **Thread-Based Parallel Refresh**: Multi-threaded model execution using std.Thread
- **Performance Metrics**: RefreshMetrics struct for tracking execution statistics
- **Cache Invalidation**: Automatic cache clearing on graph changes

### Technical Implementation
- **DependencyGraph Enhancement**: Added dependency_cache and topological_sort_cache fields
- **Parallel Execution Logic**: getParallelExecutionGroups() method for concurrent model identification
- **Thread Management**: refreshModelThread() function with proper error handling and cleanup
- **Metrics Collection**: RefreshMetrics struct integrated into refreshModelWithMetrics()
- **Memory Management**: Proper allocator handling for cached data and thread resources

### Success Criteria: ALL MET ✅
✅ **Functional**: Parallel execution within dependency groups working
✅ **Tested**: All 61 tests passing, caching improves repeated operations
✅ **Documented**: Implementation details in SPRINT_11_COMPLETION.md and _qa.md
✅ **Thread-Safe**: Proper resource management and error handling
✅ **Performance**: Cached DAG operations and multi-core utilization
✅ **Zero Breaking Changes**: All existing functionality preserved

### Sprint 11 Complete ✅
All phases (1-5) of Sprint 11 have been successfully implemented with full functionality, testing, and documentation. The system now supports incremental models with automated scheduling, column-level lineage tracking, and optimized DAG performance with parallel execution capabilities.
