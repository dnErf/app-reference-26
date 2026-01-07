# Error Handling with Result Types

## Overview
Implemented Result enum for explicit error handling, replacing raises with Result returns for better error propagation and debugging.

## Changes
- Added Result[T, E] enum and aliases (ResultTable, ResultInt) in arrow.mojo.
- Updated read_parquet and read_avro in formats.mojo to return ResultTable instead of raising.
- Wrapped operations in try-except blocks, returning Result.ok on success and Result.err on failure.

## Features
- **Explicit Errors**: Functions return Result, forcing callers to handle success/failure.
- **Type Safety**: Result[T, E] ensures correct types for ok and err cases.
- **Fallback Handling**: Multiple layers of error handling with informative error messages.

## Usage
Callers check if result.is_ok() then access result.ok_value(), else handle result.err_value().

## Testing
Format readers now handle errors gracefully without exceptions.