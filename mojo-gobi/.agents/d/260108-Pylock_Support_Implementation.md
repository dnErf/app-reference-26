# 260108 - Pylock Support Implementation

## Overview
Added comprehensive support for the pylock.toml specification, enabling locked dependency management with TOML-based lock files.

## Problem Solved
- No standardized way to lock Python dependencies in projects
- requirements.txt doesn't capture exact versions installed
- Difficulty reproducing exact dependency environments
- Missing integration with modern Python packaging standards

## Solution Implemented

### Pylock Specification Support
- **Reading**: Uses Python's built-in `tomllib` for parsing pylock.toml files
- **Writing**: Uses `tomli-w` for generating properly formatted TOML files
- **Format**: Follows pylock specification with metadata and packages sections

### Command Integration
Added `--lock` option to dependency management commands:
- `gobi sync --lock` - Generate pylock.toml from current environment
- `gobi add <package> --lock` - Add package and update lock file
- `gobi remove <package> --lock` - Remove package and update lock file

### File Structure
Generated pylock.toml contains:
```toml
[metadata]
version = "1.0"
python = "3.14"

[[packages]]
name = "rich"
version = "14.2.0"
source = "pypi"
```

### Implementation Details
- **Lock Generation**: Queries `pip list` and matches against requirements.txt
- **Version Locking**: Captures exact installed versions for reproducibility
- **TOML Writing**: Proper formatting with tomli-w for standards compliance
- **Error Handling**: Graceful fallbacks if TOML libraries unavailable

## Usage Examples
```bash
# Generate lock file from current dependencies
./gobi.sh sync --lock

# Add package with locking
./gobi.sh add requests --lock

# Remove package and update lock
./gobi.sh remove requests --lock
```

## Benefits
- **Reproducibility**: Exact dependency versions for consistent environments
- **Standards Compliance**: Follows official Python packaging specifications
- **Tool Integration**: Compatible with other Python packaging tools
- **Security**: Locked versions prevent unexpected updates

## Files Modified
- `interop.py` - Added pylock read/write functions and lock integration
- `args.py` - Added --lock options to sync, add, remove commands
- `main.mojo` - Updated function calls to pass lock parameters
- `requirements.txt` - Added tomli-w dependency

## Testing Results
- Lock file generation works correctly
- Add/remove operations update lock files properly
- TOML format follows specification
- Integration with existing dependency management seamless