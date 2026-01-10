# 2026-01-09: ULID and UUID Generation Functions

## Overview
Implemented ULID (Universally Unique Lexicographically Sortable Identifier) and UUID (Universally Unique Identifier) generation functions as foundational components for the SCM extension. These provide unique identifier generation capabilities essential for version control, object storage, and metadata management.

## Features Implemented

### ULID (Universally Unique Lexicographically Sortable Identifier)
- **128-bit identifier**: 48 bits timestamp + 80 bits randomness
- **Lexicographically sortable**: IDs sort by creation time
- **Crockford base32 encoding**: URL-safe, human-readable format
- **Time-ordered**: Newer ULIDs are always greater than older ones

### UUID (Universally Unique Identifier)
- **RFC 4122 compliant**: Standard UUID format and variants
- **Version 4 (Random)**: Cryptographically secure random UUIDs
- **Version 5 (Name-based)**: Deterministic UUIDs from namespace + name using SHA-1
- **Namespace support**: DNS, URL, OID, X.500 predefined namespaces

### SQL Integration
- **Built-in functions**: `generate_ulid()`, `generate_uuid_v4()`, `generate_uuid_v5()`
- **SQL callable**: Can be used in SELECT statements
- **Function execution**: Integrated with database's function execution system

## Technical Implementation

### ULID Structure
```mojo
struct ULID:
    var timestamp: UInt64  # Unix timestamp in milliseconds
    var randomness: UInt64  # 80 bits of cryptographic randomness
```

### UUID Structure
```mojo
struct UUID:
    var data: List[UInt8]  # 16 bytes of UUID data
```

### Generation Algorithms

**ULID Generation:**
1. Get current Unix timestamp in milliseconds
2. Generate 80 bits of cryptographic randomness
3. Combine into 128-bit value
4. Encode as 26-character Crockford base32 string

**UUID v4 Generation:**
1. Generate 16 bytes of cryptographic randomness
2. Set version bits (4) and variant bits (RFC 4122)
3. Format as standard UUID string

**UUID v5 Generation:**
1. Use predefined namespace UUID
2. Hash namespace + name with SHA-1
3. Take first 16 bytes of hash
4. Set version bits (5) and variant bits
5. Format as standard UUID string

## Usage Examples

### SQL Function Calls
```sql
-- Generate ULID
SELECT generate_ulid();

-- Generate random UUID
SELECT generate_uuid_v4();

-- Generate name-based UUID
SELECT generate_uuid_v5('dns', 'example.com');
SELECT generate_uuid_v5('url', 'https://github.com/user/repo');
```

### Programmatic Usage
```mojo
// ULID generation
var ulid = ULID()
var ulid_string = ulid.__str__()  // "01HXXXXXXXXXXXXXXXXXXXXX"

// UUID generation
var uuid = UUID()
var uuid_string = uuid.__str__()  // "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

// UUID v5 with namespace
var dns_uuid = UUID.namespace_dns()
var name_uuid = UUID.v5(dns_uuid, "example.com")
```

## Benefits

1. **ULID Advantages**:
   - Sortable by creation time
   - URL-safe encoding
   - High collision resistance
   - Time-ordered for efficient indexing

2. **UUID Advantages**:
   - Industry standard
   - Multiple generation methods
   - Deterministic (v5) and random (v4) options
   - Wide ecosystem support

3. **SCM Foundation**:
   - Essential for commit IDs, object references
   - Enables efficient version control operations
   - Supports distributed system requirements

## Integration Points

- **Database Functions**: Accessible through `execute_function()` for stored procedures
- **SQL Queries**: Callable from SELECT statements for dynamic ID generation
- **Future Extensions**: Foundation for SCM, BLOB storage, and package management systems

## Standards Compliance

- **ULID**: Follows ulid/spec at https://github.com/ulid/spec
- **UUID**: RFC 4122 compliant with proper version and variant bits
- **Base32**: Crockford variant for URL safety and readability
- **Namespaces**: Standard DNS, URL, OID, and X.500 namespace UUIDs</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/mojo-kodiak/.agents/d/20260109-ULID-and-UUID-Generation-Functions.md