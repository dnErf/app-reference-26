# PL Libraries and External Loading Enhancement

## Overview
Expanded PL (Procedural Language) libraries with additional functions and added capability for external PL code loading.

## Changes
- Added string_concat, date_diff, regex_match functions to pl.mojo.
- Implemented load_external_pl to read PL code from files.
- Added execute_pl placeholder for dynamic execution.

## Features
- String manipulation: concat
- Date operations: diff
- Pattern matching: regex
- External loading: Load and potentially execute PL from files
- Extensibility: Easy to add more functions

## Usage
Call functions directly or load external PL scripts for custom logic.

## Testing
Added functions compiled successfully. External loading tested for file read.