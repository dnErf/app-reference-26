# Index Storage Serialization Optimization

## Overview
Replaced JSON-based index serialization with Python Pickle for improved performance and efficiency in database index storage and retrieval.

## Changes Made

### IndexStorage Updates
- **`_save_index()`**: Now uses `pickle.dumps()` instead of JSON serialization for all index types (btree, hash, bitmap)
- **`_load_index()`**: Now uses `pickle.loads()` as primary method with JSON fallback for backward compatibility
- **`_load_index_json()`**: New method added for JSON fallback support
- **`_delete_index_file()`**: Updated to handle both `.pkl` and `.json` files for backward compatibility

### Performance Benefits
- **Faster Serialization**: Pickle provides native Python object serialization
- **Smaller Storage Size**: Binary format reduces disk space usage for index files
- **Better Performance**: Eliminates JSON parsing overhead for index operations
- **Type Preservation**: Pickle maintains Python object types more accurately

### Backward Compatibility
- **Fallback Support**: JSON parsing remains available for existing indexes
- **Migration Path**: Existing JSON indexes will be automatically loaded and can be saved as Pickle
- **File Extensions**: New indexes use `.pkl` extension, old indexes use `.json`

### Technical Details
- **Python Interop**: Uses `Python.import_module("pickle")` for serialization
- **Data Conversion**: Mojo index structures converted to Python dictionaries for pickling
- **Index Types Supported**: B-tree, Hash, and Bitmap indexes all use pickle serialization
- **Error Handling**: Graceful fallback to JSON if pickle parsing fails

## Testing
- All ORCStorage functionality tests pass with new pickle-based index serialization
- Index creation, search, and drop operations verified
- Backward compatibility with existing JSON indexes confirmed
- Multiple index types (btree, hash) tested successfully

## Future Considerations
- Consider MessagePack or Protocol Buffers for cross-language compatibility if needed
- Evaluate compression options for very large indexes
- Monitor memory usage patterns with pickle serialization