# Mojo Kodiak DB Secrets Manager

The Mojo Kodiak DB Secrets Manager provides secure storage and management of authentication credentials for remote data access operations.

## Overview

The secrets manager allows you to store sensitive information like API tokens, passwords, and keys securely within the database. Secrets are encrypted at rest using AES-256-GCM encryption and can be referenced in queries for authenticated remote data access.

## Features

- **Secure Storage**: AES-256-GCM encryption for all stored secrets
- **Multiple Types**: Support for tokens, passwords, keys, certificates, and custom types
- **In-Memory or Persistent**: Configurable storage (in-memory by default, file-based optional)
- **PL Integration**: CREATE SECRET syntax for easy management in PL
- **Extension Access**: Extensions can securely access secrets for authentication

## PL Syntax

### Creating Secrets

```sql
CREATE SECRET secret_name TYPE type VALUE 'secret_value'
```

**Parameters:**
- `secret_name`: Identifier for the secret
- `type`: Type of secret ('bearer', 'password', 'key', 'certificate', or 'custom')
- `VALUE`: The actual secret value to store

**Examples:**
```sql
-- Bearer token for API authentication
CREATE SECRET api_token TYPE bearer VALUE 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'

-- Database password
CREATE SECRET db_pass TYPE password VALUE 'mySecurePassword123'

-- SSH private key
CREATE SECRET ssh_key TYPE key VALUE '-----BEGIN PRIVATE KEY-----\n...'
```

### Managing Secrets

```sql
-- List all secrets
SHOW SECRETS

-- Delete a secret
DROP SECRET secret_name TYPE type
```

**Examples:**
```sql
SHOW SECRETS
-- Output: bearer:api_token, password:db_pass

DROP SECRET api_token TYPE bearer
```

### Using Secrets in Queries

Secrets can be referenced in queries using the `USING SECRET` clause:

```sql
SELECT * FROM table WHERE column = value USING SECRET secret_name TYPE type
```

This will use the decrypted secret value in place of the WHERE value.

**Examples:**
```sql
-- Query with secret as filter value
SELECT * FROM users WHERE api_key = 'placeholder' USING SECRET api_token TYPE bearer

-- The secret value replaces the 'placeholder'
```
COPY (SELECT * FROM users WHERE active = true) 
TO 'https://api.example.com/upload' 
WITH (format 'json', secret 'api_token');
```

### Managing Secrets

```sql
-- List all secrets
SHOW SECRETS;

-- Drop a secret
DROP SECRET secret_name;
```

## Security Considerations

- **Encryption**: All secrets are encrypted using AES-256-GCM with a master key
- **Master Key**: Derived from a configurable password or generated automatically
- **Access Control**: Secrets are accessible only within the database context
- **Memory Safety**: Secrets are zeroed from memory when no longer needed

## Configuration

The secrets manager can be configured during database initialization:

```mojo
var secrets_config = SecretsManager.Config{
    .storage_path = "/path/to/secrets.db", // Optional: persistent storage
    .master_password = "your-master-password", // Optional: key derivation
};

var db = Database(secrets_config);
```

## Implementation Details

- **Encryption Algorithm**: ChaCha20-Poly1305 (AEAD)
- **Key Derivation**: PBKDF2 with SHA-256 (if master password provided)
- **Storage Format**: Encrypted binary format with authentication tags
- **Memory Management**: Secure cleanup of sensitive data

## Error Handling

Common errors when working with secrets:

- `SecretAlreadyExists`: Attempting to create a secret with a name that already exists
- `SecretNotFound`: Referencing a secret that doesn't exist
- `InvalidEncryptedData`: Corrupted or tampered secret data
- `DecryptionFailed`: Incorrect master key or corrupted data

## Best Practices

1. **Use Strong Master Passwords**: When configuring persistent storage
2. **Limit Secret Scope**: Create secrets with minimal required permissions
3. **Regular Rotation**: Update secrets periodically for security
4. **Audit Access**: Monitor secret usage through database audit logs
5. **Backup Securely**: Encrypted backups protect against data loss

## Integration with HTTPFS Extension

The secrets manager integrates seamlessly with the HTTPFS extension for authenticated remote data access:

```sql
-- Install and load the extension
LOAD httpfs;

-- Create authentication secret
CREATE SECRET github_token (KIND 'bearer', VALUE 'ghp_your_github_token_here');

-- Query remote data using the secret
SELECT * FROM 'https://api.github.com/repos/owner/repo/issues' WITH (secret 'github_token');
```

This enables secure, authenticated access to cloud storage services like S3, GCS, and HTTP APIs.