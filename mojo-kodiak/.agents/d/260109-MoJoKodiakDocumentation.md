# Mojo Kodiak Database

A high-performance, in-memory database written in Mojo, featuring advanced SQL capabilities, PL-Grizzly scripting language, and production-ready features.

## Overview

Mojo Kodiak is a modern database implementation that leverages Mojo's performance capabilities to provide fast data storage and retrieval. It combines traditional SQL functionality with a powerful scripting language called PL-Grizzly, making it suitable for both transactional workloads and complex data processing tasks.

## Key Features

### Core Database Features
- **In-Memory Storage**: High-speed data storage with optional block-based persistence
- **WAL (Write-Ahead Logging)**: Data durability and crash recovery
- **B+ Tree Indexing**: Efficient indexing for fast lookups
- **Fractal Tree Storage**: Advanced storage engine for write optimization
- **Concurrent Access**: Thread-safe operations with locking mechanisms

### SQL Capabilities
- Standard SQL operations (SELECT, INSERT, UPDATE, DELETE)
- JOIN operations
- WHERE clause filtering
- Aggregation functions
- Advanced features: ATTACH/DETACH databases, triggers, CRON jobs

### PL-Grizzly Scripting Language
- **Expression Evaluation**: Arithmetic, logical, and complex expressions
- **Data Types**: Arrays `[1,2,3]`, maps `{key: value}`
- **Receivers**: Method calls on data structures (`arr.length()`, `map.keys()`)
- **Control Flow**: TRY/CATCH, MATCH expressions
- **Async Support**: Asynchronous function execution

### Security & Administration
- **Secrets Management**: Encrypted storage of sensitive data
- **Access Control**: Basic authentication and authorization
- **Extensions**: Pluggable extensions for additional functionality
- **Monitoring**: Performance metrics and health checks

## Architecture

### Storage Layers
1. **In-Memory Store**: Fast access for hot data
2. **Block Store**: Persistent storage with WAL
3. **Index Layer**: B+ trees and fractal trees for optimization

### PL-Grizzly Interpreter
- Recursive descent parser for expressions
- Python interop for complex evaluations
- Variable scoping and function execution

### Extension System
- Loadable extensions (e.g., httpfs for remote storage)
- Plugin architecture for custom functionality

## Installation

### Prerequisites
- Mojo SDK
- Python 3.8+ (for interop features)
- PyArrow (for data format support)

### Build Instructions

```bash
# Clone the repository
git clone <repository-url>
cd mojo-kodiak

# Activate virtual environment
. .venv/bin/activate

# Build the database
mojo build src/repl.mojo -o repl

# Build tests
mojo build src/test_pl.mojo -o test_pl
```

## Usage

### Starting the REPL

```bash
./repl
```

### Basic SQL Operations

```sql
-- Create and populate a table
CREATE TABLE users (id INT, name STRING, age INT);
INSERT INTO users VALUES (1, 'Alice', 30);
INSERT INTO users VALUES (2, 'Bob', 25);

-- Query data
SELECT * FROM users WHERE age > 25;
```

### Advanced Features

```sql
-- Triggers
CREATE TRIGGER audit_trigger ON users AFTER INSERT
EXECUTE PL 'print("New user inserted")';

-- Secrets management
CREATE SECRET my_key TYPE password VALUE 'secret123';
SELECT GET_SECRET('my_key', 'password');

-- Extensions
LOAD EXTENSION httpfs;
```

## PL-Grizzly Language Reference

### Data Types
- **Numbers**: `42`, `3.14`
- **Strings**: `'hello'`, `"world"`
- **Arrays**: `[1, 2, 3]`
- **Maps**: `{name: 'Alice', age: 30}`

### Operators
- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `&&`, `||`, `!`

### Receivers
```pl
var arr = [1, 2, 3]
var len = arr.length()  -- Returns 3

var dict = {a: 1, b: 2}
var keys = dict.keys()  -- Returns ['a', 'b']
```

### Control Flow
```pl
-- TRY/CATCH
TRY {
    risky_operation()
} CATCH (e) {
    print("Error:", e)
}

-- MATCH
MATCH value {
    1 => "one"
    2 => "two"
    _ => "other"
}
```

## Configuration

### Environment Variables
- `MOJO_KODIAK_DATA_DIR`: Data directory (default: `./data`)
- `MOJO_KODIAK_MAX_MEMORY`: Maximum memory usage
- `MOJO_KODIAK_LOG_LEVEL`: Logging verbosity

### Configuration File
Create `config.json`:
```json
{
  "storage": {
    "block_size": 4096,
    "wal_enabled": true
  },
  "security": {
    "master_key": "your-encryption-key"
  }
}
```

## Performance Tuning

### Memory Management
- Adjust block sizes for your workload
- Monitor memory usage with built-in metrics
- Use appropriate indexing strategies

### Query Optimization
- Use indexes on frequently queried columns
- Avoid full table scans with proper WHERE clauses
- Leverage PL-Grizzly for complex computations

### Benchmarking
```bash
# Run performance benchmarks
mojo build src/benchmark.mojo -o benchmark
./benchmark
```

## Troubleshooting

### Common Issues

**Build Errors**
- Ensure Mojo SDK is properly installed
- Check Python interop dependencies
- Verify PyArrow installation

**Runtime Errors**
- Check data directory permissions
- Verify WAL file integrity
- Monitor memory usage

**PL-Grizzly Issues**
- Validate syntax with the REPL
- Check variable scoping
- Use debug mode for complex expressions

### Debug Mode
```bash
# Enable debug logging
export MOJO_KODIAK_LOG_LEVEL=DEBUG
./repl
```

### Recovery
```bash
# Recover from WAL
./repl --recover
```

## Development

### Project Structure
```
src/
├── database.mojo      # Core database implementation
├── query_parser.mojo  # SQL parser
├── repl.mojo         # Interactive REPL
├── types.mojo        # Data type definitions
├── wal.mojo          # Write-ahead logging
├── block_store.mojo  # Block storage
├── b_plus_tree.mojo  # B+ tree indexing
└── fractal_tree.mojo # Fractal tree storage

tests/                 # Test files
docs/                  # Documentation
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Submit a pull request

### Testing
```bash
# Run unit tests
mojo build src/test.mojo -o test
./test

# Run PL-Grizzly tests
./test_pl
```

## Roadmap

### Phase 32: Production Optimization
- Connection pooling
- Advanced monitoring
- Containerization support
- Backup/restore automation

### Future Enhancements
- Distributed deployment
- Advanced analytics
- Machine learning integrations
- Graph database capabilities

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with the Mojo programming language
- Inspired by modern database architectures
- Thanks to the Mojo community for support and feedback