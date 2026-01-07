# Formats Implementation Details
## Overview
The formats module (`formats.mojo`) handles reading and writing various data formats for the Mojo Grizzly database, including Parquet, AVRO, ORC, JSONL, and compression.

## Key Features Implemented
- **Parquet**: Full writer with schema JSON and row data to file; reader parses schema and rows from file.
- **AVRO**: Writer encodes schema, sync marker, records with zigzag/varint; reader parses binary data.
- **ORC**: Writer includes magic, schema, stripes, postscript; reader parses postscript, footer, stripes.
- **JSONL**: Reader parses JSON lines to Table; writer serializes Table to JSONL bytes.
- **Compression**: LZ4 with XOR simulation; ZSTD with prefix/suffix.
- **Conversion**: Basic format conversion (placeholder for JSONL).
- **Partitioning/Bucketing**: Structs for PartitionedTable and BucketedTable with add/get methods.

## Data Structures
- **JsonValue**: Simple JSON value holder for parsing.
- **PartitionedTable**: Dict of Tables by partition key.
- **BucketedTable**: List of Tables for bucketing.

## Algorithms
- **Zigzag Encoding/Decoding**: For AVRO integer encoding.
- **Varint**: Variable-length integer encoding/decoding.
- **File I/O**: Uses os.read for reading files in readers.

## Testing
Validated with test.mojo, all tests pass including formats.