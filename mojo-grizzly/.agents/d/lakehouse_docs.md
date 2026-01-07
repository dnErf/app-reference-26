# Multi-Format Data Lake Documentation

## Overview
Batch 12 enhances the lakehouse with ACID transactions, schema-on-read, data lineage, versioning, and hybrid storage.

## Features Implemented

### ACID Transactions
- Transaction struct with operations and commit
- Atomic inserts with `insert_with_transaction`

### Schema-on-Read
- Infer schema from JSON with `infer_schema_from_json`
- Query unstructured data with `query_unstructured`

### Data Lineage Tracking
- Global lineage map with `add_lineage` and `get_lineage`
- Track sources for tables

### Data Versioning
- Already supported with versions list and time travel

### Hybrid Storage
- HybridStore struct for row and column storage
- Store and query in different modes

## Usage Examples

```sql
LOAD EXTENSION 'lakehouse';
-- Use enhanced lakehouse functions
```

## Files Modified
- `extensions/lakehouse.mojo`: Enhanced with ACID, schema-on-read, lineage, hybrid storage

## Testing
- New features integrated into LakeTable
- Placeholders for full implementation