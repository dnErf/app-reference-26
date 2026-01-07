# Memory Management Optimizations (Zero-Copy)

## Overview
Implemented zero-copy techniques to reduce memory overhead and improve performance, particularly for large datasets.

## Changes
- Added TableView struct for zero-copy table slicing, holding references to original columns with start/end indices.
- Updated Table.slice() to return TableView instead of copying data.
- Serialization in ipc.mojo already uses memcpy for direct memory copies.

## Features
- **Zero-Copy Slicing**: TableView allows access to subsets without duplicating data.
- **Reference-Based Views**: Views share underlying arrays, reducing memory usage.
- **Efficient Access**: get_row and num_rows methods for view operations.

## Usage
Use table.slice(start, end) to get a TableView for zero-copy operations on subsets.

## Testing
Slicing now avoids data copying; views provide read-only access to original data.