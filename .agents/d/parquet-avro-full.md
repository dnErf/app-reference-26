# Full Parquet/AVRO Readers/Writers with Compression/Schema Evolution

## Overview
Enhanced Parquet and AVRO format support with full readers/writers, compression options, and schema evolution handling using Python libraries (pyarrow, fastavro).

## Changes
- Updated write_parquet/read_parquet to use pyarrow for compression (snappy, gzip, etc.) and schema handling.
- Updated write_avro/read_avro to use fastavro for compression and schema evolution.
- Added fallback implementations for when Python libraries unavailable.
- Integrated Python imports for advanced functionality.

## Features
- **Compression**: Support for Snappy, GZIP, LZ4, etc. in Parquet/AVRO.
- **Schema Evolution**: Automatic handling of added/removed columns, type changes via library parsing.
- **Full Format Support**: Proper metadata, stripes, sync markers, varint encoding.
- **Fallbacks**: Simple implementations if libraries missing.

## Usage
Call write_parquet(table, "file.parquet", compression="gzip") or read_avro("file.avro") with automatic schema inference.

## Testing
Functions now use standard libraries for production-ready I/O; fallbacks ensure compatibility.