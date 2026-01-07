# CLI Implementation Details
## Overview
The CLI module (`cli.mojo`) provides a command-line interface for interacting with the Mojo Grizzly database. It supports SQL execution, extension loading, and REPL mode.

## Key Features Implemented
- **SQL Execution**: Parses and executes various SQL commands including SELECT, CREATE TABLE, LOAD, SAVE, etc.
- **Extension Management**: Loads and unloads extensions like column_store, row_store, graph, blockchain, lakehouse.
- **REPL Mode**: Interactive shell with tab completion for commands.
- **File I/O**: Supports loading from and saving to various formats (.jsonl, .parquet, .grz for AVRO).

## Global State
- `global_table`: Current active table for queries.
- `tables`: Dictionary of named tables created via CREATE TABLE.
- `command_history`: List of executed commands.

## Command Parsing
Commands are parsed using string splitting and find operations. For example:
- CREATE TABLE: Extracts table name, column definitions, and creates Schema.
- ADD NODE/EDGE: Parses IDs and properties, calls extension functions.
- INSERT INTO LAKE: Parses table name and values, inserts into lakehouse.

## Tab Completion
Provides suggestions based on command prefixes. Handles tab input in REPL by printing suggestions.

## File Operations
- SAVE: Writes to file based on current store config (Parquet for column, AVRO for row).
- LOAD: Reads from file, auto-detects format or uses config.

## Extensions Integration
Calls init functions for extensions and uses their APIs for specific commands (e.g., add_node for graph).

## Testing
Validated with test.mojo, all tests pass including extensions and formats.