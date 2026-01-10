# Mojo Kodiak DB

A high-performance, in-memory database built with Mojo, featuring advanced SQL-like query capabilities, PL-Grizzly expression evaluation, and production-ready monitoring.

## Features

- **High Performance**: Built with Mojo for maximum speed
- **In-Memory Storage**: Fast data access with optional persistence
- **SQL-like Queries**: CREATE, SELECT, INSERT, UPDATE, DELETE operations
- **PL-Grizzly**: Expression-based programming language for advanced queries
- **Production Monitoring**: Health checks, performance metrics, and diagnostics
- **Backup/Restore**: Automated data management
- **Container Ready**: Docker support for easy deployment

## Quick Start

### Using Docker
```bash
docker build -t mojo-kodiak .
docker run -it mojo-kodiak
```

### Command Line Interface

```bash
# Show help
./kodiak

# Start interactive REPL
./kodiak repl

# Show database health
./kodiak health
```

### REPL Commands

```sql
-- Create a table
CREATE TABLE users;

-- Insert data
INSERT INTO users VALUES ('Alice', '30');

-- Query data
SELECT * FROM users;

-- Show health
.health

-- List tables
.tables

-- Exit
.exit
```

## Architecture

- **Database Engine**: Core database with tables, indexes, and query execution
- **PL-Grizzly**: Expression evaluator for complex queries and functions
- **Storage Layer**: WAL (Write-Ahead Logging) and block storage
- **Indexing**: B+ trees and fractal trees for fast lookups
- **Monitoring**: Real-time health checks and performance metrics

## Development

Built with Mojo programming language. Requires Mojo SDK for compilation.

## License

MIT License