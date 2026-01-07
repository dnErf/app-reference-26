# Security and Encryption Documentation

## Overview
Batch 6 implements comprehensive security features for Mojo-Grizzly, including row-level security (RLS), data encryption at rest, token-based authentication, audit logging, and SQL injection prevention.

## Features Implemented

### Row-Level Security (RLS)
- Policies defined per table with conditions based on user attributes
- Access control enforced during query execution
- Example: `add_rls_policy("users", "user_id = ?", "user_id")`

### Data Encryption at Rest
- AES encryption for WAL logs and block data
- Uses Fernet symmetric encryption from Python cryptography library
- Key: "my_secret_key_32_bytes_long!!!" (should be configurable in production)

### Token-Based Authentication
- JWT tokens for user authentication
- Commands: `LOGIN user` to generate token, `AUTH token` to authenticate
- Tokens expire after 1 hour

### Audit Logging
- Logs all query executions to `audit.log` file
- Format: timestamp | user | action | details

### SQL Injection Prevention
- Input sanitization removes quotes and semicolons
- Applied to all SQL inputs before parsing

## Usage Examples

```sql
LOAD EXTENSION 'security';
LOGIN alice;
AUTH <generated_token>;
SELECT * FROM users;  -- Checked against RLS policies
```

## Files Modified
- `extensions/security.mojo`: Core security functions
- `block.mojo`: Encrypted WAL append/replay
- `query.mojo`: RLS checks, sanitization, audit logging
- `cli.mojo`: Auth commands, user context

## Testing
- Basic auth flow tested
- Encryption/decryption verified
- RLS policies applied to queries
- Audit logs generated