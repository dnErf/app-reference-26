# 241010-Build-Mojo-CLI

## Overview
Developed a pure Mojo-based CLI tool named 'gobi' for managing AI projects, inspired by uv with stricter constraints. The tool provides commands for initializing, validating, building, and managing AI project dependencies.

## Implementation
- **Language**: Mojo with Python interop for CLI parsing and operations.
- **Architecture**: Interactive CLI using Python's input() to read commands, dynamically setting sys.argv for argparse compatibility.
- **Commands**:
  - `version`: Display version.
  - `help`: Show available commands.
  - `init <name> --path <path>`: Create AI project structure.
  - `validate --path <path>`: Validate project structure.
  - `run --path <path>`: Run the project (placeholder).
  - `sync --path <path>`: Sync dependencies (placeholder).
  - `build --path <path>`: Build project into executable using cx_Freeze.
  - `add <package> --version <ver> --path <path>`: Add dependency.
  - `remove <package> --path <path>`: Remove dependency.

## Key Features
- Pure Mojo execution with Python interop for utilities.
- Project structure validation against a JSON template.
- Dependency management via pyproject.toml.
- Executable building for distribution.

## Usage
Run `mojo main.mojo` and enter commands interactively, e.g., `init myproject --path ./`.

## Testing
- Verified init creates correct folder structure and .manifest.ai file.
- Validate confirms project validity.
- Build generates executable in dist/ folder.

## Challenges Resolved
- Mojo lacks direct argv access; solved via interactive input and dynamic sys.argv setting.
- Ensured compatibility with existing Python argparse and Rich UI libraries.