# PL-Grizzly Interpreter Design Refactoring

## Overview
Refactored PL-Grizzly interpreter to accept SchemaManager directly instead of BlobStorage, improving dependency clarity and testability.

## Problem
- **Previous Design**: Interpreter took `storage: BlobStorage` parameter and created its own `SchemaManager(storage)`
- **Dependency Confusion**: Interpreter appeared to depend on storage directly, but only used it to create SchemaManager
- **Tight Coupling**: Storage abstraction leaked into interpreter layer unnecessarily

## Solution
- **New Design**: Interpreter now takes `schema_manager: SchemaManager` parameter directly
- **Clear Dependencies**: Interpreter's dependency on SchemaManager is now explicit and clear
- **Better Separation**: Storage concerns are isolated in main.mojo, interpreter focuses on language execution

## Changes Made

### PL-Grizzly Interpreter (`pl_grizzly_interpreter.mojo`)
- **Constructor**: Changed from `__init__(out self, storage: BlobStorage)` to `__init__(out self, schema_manager: SchemaManager)`
- **Initialization**: Now directly assigns `self.schema_manager = schema_manager.copy()` instead of creating new SchemaManager
- **Dependency Clarity**: All schema operations go through the explicitly provided SchemaManager

### Main Application (`main.mojo`)
- **SchemaManager Creation**: Creates `schema_manager = SchemaManager(storage)` explicitly
- **Interpreter Creation**: Passes `PLGrizzlyInterpreter(schema_manager)` instead of `PLGrizzlyInterpreter(storage)`
- **Separation of Concerns**: Storage setup and interpreter initialization are now clearly separated

## Benefits
- **Explicit Dependencies**: Interpreter's reliance on SchemaManager is now clear from the API
- **Better Testability**: Can pass mock SchemaManager instances for testing
- **Reduced Coupling**: Interpreter no longer has implicit knowledge of storage layer
- **Cleaner Architecture**: Each component has a single, clear responsibility

## Usage Pattern
```mojo
// Before
var storage = BlobStorage("path/to/db")
var interpreter = PLGrizzlyInterpreter(storage)

// After
var storage = BlobStorage("path/to/db")
var schema_manager = SchemaManager(storage)
var interpreter = PLGrizzlyInterpreter(schema_manager)
```

## Testing
- Build completes successfully with new design
- All existing functionality preserved
- No breaking changes to public API beyond internal constructor signature