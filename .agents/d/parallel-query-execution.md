# Parallel Query Execution with Mojo Threading

## Overview
Implemented parallel query execution using Mojo's threading capabilities for improved performance on multi-core systems.

## Changes
- Updated parallel_scan to use Thread for concurrent processing of table chunks.
- Split tables into chunks and execute functions in parallel threads.
- Ensured thread safety by collecting results after joins.

## Features
- **Threading**: Uses Mojo Thread to run scans/aggregations in parallel.
- **Chunking**: Divides tables into chunks for balanced load.
- **Scalability**: Configurable number of threads (default 8).
- **Safety**: Results combined after all threads complete.

## Usage
Functions like parallel_scan now execute in parallel; JOINs use chunked parallelism.

## Testing
Threaded execution for scans and joins; ensures correct result aggregation.