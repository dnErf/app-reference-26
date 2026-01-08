# 260108 - Template Structure Update

## Overview
Updated the AI project template to reorganize the directory structure for better separation of concerns. Moved project tooling (scripts, plugins) into the `.gobi/` folder while keeping AI-specific files at the root level.

## Problem Solved
- Scripts and plugins were cluttering the project root
- No clear separation between AI agent files and project tooling
- Manifest validation needed to reflect the new structure

## Solution Implemented

### Directory Structure Changes
**Before:**
```
project/
├── scripts/
├── plugins/
├── .ai/
│   ├── agents/
│   └── models/
└── .gobi/
```

**After:**
```
project/
├── .ai/
│   ├── agents/
│   └── models/
└── .gobi/
    ├── scripts/
    └── plugins/
```

### Files Updated
- `template.json`: Updated directories list and file paths
- `.manifest.ai`: Updated expected folders for validation

### Key Changes
1. **Directories**: Moved `scripts` and `plugins` into `.gobi/`
2. **Files**: Updated paths for `ai_agent.py` and `example.py`
3. **Manifest**: Updated folder validation list
4. **Bounds**: Updated AI agent bounds to `.gobi/scripts/, .ai/`

## Benefits
- Cleaner project root with AI files prominently displayed
- Tooling organized under `.gobi/` alongside environment
- Better separation between AI logic and project infrastructure
- Consistent with existing `.gobi/env/` structure

## Validation
- Template creates correct directory structure
- Manifest validation checks new folder locations
- AI agent bounds updated to reflect new paths
- Backward compatibility maintained for existing projects