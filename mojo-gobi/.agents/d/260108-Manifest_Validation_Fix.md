# 260108 - Manifest Validation Fix

## Problem
The `.manifest.ai` file existed but the `validate` command was not accessible in command-line mode. Users could only validate projects by entering the interactive shell, making the manifest "not working".

## Root Cause
The `main.mojo` CLI only supported interactive mode. Command-line arguments were not processed, so commands like `gobi validate .` failed to execute.

## Solution
Added command-line mode support to `main.mojo`:

1. **Environment Variable Detection**: Check `GOBI_ARGS` for command-line arguments
2. **Argument Processing**: Parse args and execute commands without entering shell
3. **Wrapper Script**: Created `gobi.sh` to pass arguments via environment variables
4. **Unified Interface**: Both interactive and command-line modes use the same handlers

## Implementation Details
```mojo
// Command-line mode detection
var cmd_args = getenv("GOBI_ARGS")
if cmd_args != "":
    // Parse and execute command
    return
// Interactive mode
```

## Wrapper Script
```bash
#!/bin/bash
export GOBI_ARGS="$*"
exec "$(dirname "$0")/main" "$@"
```

## Testing Results
- `./gobi.sh validate .` now works, reading `.manifest.ai`
- Validates project structure against manifest requirements
- Shows errors for missing folders, warnings for naming issues
- Command-line mode preserves all functionality

## Files Modified
- `main.mojo` - Added command-line mode
- `gobi.sh` - New wrapper script (executable)

## Impact
Manifest-driven validation now works as intended. Agent hooks can be executed via command-line, enabling automated project checks and CI/CD integration.