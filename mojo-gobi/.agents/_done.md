Add SQLMesh-inspired transformation staging capabilities
Add SQLMesh-inspired transformation staging with data pipeline workflows
Fix DataFrame column creation and integrity verification in ORC storage
Create CLI application using Rich library with repl, init, pack, and unpack commands
Implement core Merkle B+ Tree data structure with SHA-256 hashing and universal compaction strategy
Design BLOB storage abstraction compatible with Azure ADLS Gen 2 patterns
Implement lakehouse schema management for tables and metadata
Develop pack/unpack functionality for .gobi file format
Implement embedded database operations with CRUD functionality
Implement data integrity verification using SHA-256 Merkle tree hashing with compaction support
Restore complex data structures in transformation staging (Dict for models/environments, List for dependencies)
Implement proper serialization/deserialization with JSON for persistence
Add blob storage integration for saving transformation metadata
Optimize compaction strategy for performance and space efficiency
Integrate PyArrow ORC format for columnar data storage with integrity verification
Implement PyArrow ORC columnar storage with compression and encoding optimizations
Implement dependency resolution and topological sorting for pipeline execution
Add incremental materialization support with timestamps and change detection
Extend REPL with advanced transformation commands (list models, show dependencies, view execution history)
Implement environment inheritance and configuration management
Implement PL-GRIZZLY interpreter core with expression evaluation and variable resolution
Add PL-GRIZZLY semantic analysis for type checking and error reporting
Implement PL-GRIZZLY function execution and call stack management
Create PL-GRIZZLY environment system for variable scoping and persistence
Implement pipeline execution engine with dependency resolution and topological sorting
Integrate incremental execution with change detection for pipeline performance
Add data quality checks and validation rules for transformation outputs
Design and implement PL-GRIZZLY lexer for parsing enhanced SQL dialect
Design PL-GRIZZLY AST node structures
Implement basic expression parsing (literals, identifiers, variables)
Implement operator precedence and binary expressions
Implement function call and pipe operations
Implement SELECT statement parsing
Implement CREATE FUNCTION statement parsing
Test parsing of complex PL-GRIZZLY expressions
Add transformation validation and SQL parsing capabilities
Integrate PyArrow filesystem interface in blob storage for cross-platform compatibility
Remove pandas dependency from ORC storage and use direct PyArrow APIs
Change ORC storage default compression to none and implement ZSTD ORC compression for pack/unpack