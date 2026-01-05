const std = @import("std");
const crypto = std.crypto;

/// Secrets Manager for secure credential storage
pub const SecretsManager = struct {
    allocator: std.mem.Allocator,
    secrets: std.StringHashMap(Secret),
    master_key: ?[32]u8, // AES-256 key
    storage_path: ?[]const u8,

    pub const Secret = struct {
        name: []const u8,
        type: SecretType,
        data: []const u8, // Encrypted data
        created_at: i64,
        updated_at: i64,

        pub const SecretType = enum {
            token,
            password,
            key,
            certificate,
            custom,
        };

        pub fn deinit(self: *Secret, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.data);
        }
    };

    pub const Config = struct {
        storage_path: ?[]const u8 = null, // If null, use in-memory only
        master_password: ?[]const u8 = null, // For key derivation
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) !SecretsManager {
        var manager = SecretsManager{
            .allocator = allocator,
            .secrets = std.StringHashMap(Secret).init(allocator),
            .master_key = null,
            .storage_path = null,
        };

        // Set storage path
        if (config.storage_path) |path| {
            manager.storage_path = try allocator.dupe(u8, path);
        }

        // Derive master key from password if provided
        if (config.master_password) |password| {
            manager.master_key = try deriveKey(password);
        }

        // Load existing secrets if storage path is set
        if (manager.storage_path != null) {
            try manager.loadSecrets();
        }

        return manager;
    }

    pub fn deinit(self: *SecretsManager) void {
        // Save secrets before deinit if persistent storage
        if (self.storage_path != null) {
            self.saveSecrets() catch |err| {
                std.debug.print("Warning: Failed to save secrets: {any}\n", .{err});
            };
        }

        // Clean up secrets
        var it = self.secrets.valueIterator();
        while (it.next()) |secret| {
            secret.deinit(self.allocator);
        }
        self.secrets.deinit();

        if (self.storage_path) |path| {
            self.allocator.free(path);
        }
    }

    /// Create a new secret
    pub fn createSecret(self: *SecretsManager, name: []const u8, secret_type: Secret.SecretType, data: []const u8) !void {
        // Check if secret already exists
        if (self.secrets.contains(name)) {
            return error.SecretAlreadyExists;
        }

        // Encrypt data if master key is available
        const encrypted_data = if (self.master_key) |key| blk: {
            break :blk try self.encryptData(data, key);
        } else data;

        const now = std.time.timestamp();

        const secret = Secret{
            .name = try self.allocator.dupe(u8, name),
            .type = secret_type,
            .data = try self.allocator.dupe(u8, encrypted_data),
            .created_at = now,
            .updated_at = now,
        };

        try self.secrets.put(secret.name, secret);
    }

    /// Get a secret by name
    pub fn getSecret(self: *SecretsManager, name: []const u8) !Secret {
        const secret = self.secrets.get(name) orelse return error.SecretNotFound;

        // Decrypt data if master key is available
        const decrypted_data = if (self.master_key) |key| blk: {
            break :blk try self.decryptData(secret.data, key);
        } else secret.data;

        return Secret{
            .name = try self.allocator.dupe(u8, secret.name),
            .type = secret.type,
            .data = try self.allocator.dupe(u8, decrypted_data),
            .created_at = secret.created_at,
            .updated_at = secret.updated_at,
        };
    }

    /// Update an existing secret
    pub fn updateSecret(self: *SecretsManager, name: []const u8, data: []const u8) !void {
        const secret_ptr = self.secrets.getPtr(name) orelse return error.SecretNotFound;

        // Encrypt data if master key is available
        const encrypted_data = if (self.master_key) |key| blk: {
            break :blk try self.encryptData(data, key);
        } else data;

        // Free old data and update
        self.allocator.free(secret_ptr.data);
        secret_ptr.data = try self.allocator.dupe(u8, encrypted_data);
        secret_ptr.updated_at = std.time.timestamp();
    }

    /// Delete a secret
    pub fn deleteSecret(self: *SecretsManager, name: []const u8) !void {
        var secret = self.secrets.fetchRemove(name) orelse return error.SecretNotFound;
        secret.value.deinit(self.allocator);
    }

    /// List all secret names
    pub fn listSecrets(self: *SecretsManager, allocator: std.mem.Allocator) !std.ArrayListUnmanaged([]const u8) {
        var names = std.ArrayListUnmanaged([]const u8){};
        errdefer names.deinit(allocator);

        var it = self.secrets.keyIterator();
        while (it.next()) |key| {
            try names.append(allocator, try allocator.dupe(u8, key.*));
        }

        return names;
    }

    /// Get secret value for use in authentication (decrypts automatically)
    pub fn getSecretValue(self: *SecretsManager, name: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        var secret = try self.getSecret(name);
        defer secret.deinit(allocator);

        return try allocator.dupe(u8, secret.data);
    }

    /// Load secrets from persistent storage
    fn loadSecrets(self: *SecretsManager) !void {
        _ = self;
        // TODO: Implement persistent storage loading
        // For now, secrets are in-memory only
    }

    /// Save secrets to persistent storage
    fn saveSecrets(self: *SecretsManager) !void {
        _ = self;
        // TODO: Implement persistent storage saving
        // For now, secrets are in-memory only
    }

    /// Derive encryption key from password using PBKDF2
    fn deriveKey(password: []const u8) ![32]u8 {
        var key: [32]u8 = undefined;
        const salt = "grizzly_secrets_salt"; // Fixed salt for simplicity
        try crypto.pwhash.pbkdf2(&key, password, salt, 100_000, crypto.auth.hmac.sha2.HmacSha256);
        return key;
    }

    /// Encrypt data using AES-256-GCM
    fn encryptData(self: *SecretsManager, data: []const u8, key: [32]u8) ![]const u8 {
        var nonce: [12]u8 = undefined; // ChaCha20Poly1305 nonce length
        crypto.random.bytes(&nonce);

        var tag: [16]u8 = undefined; // ChaCha20Poly1305 tag length
        const ciphertext = try self.allocator.alloc(u8, data.len);
        errdefer self.allocator.free(ciphertext);

        crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(ciphertext, &tag, data, "", nonce, key);

        // Combine nonce + tag + ciphertext
        var result = try self.allocator.alloc(u8, nonce.len + tag.len + ciphertext.len);
        errdefer self.allocator.free(result);

        @memcpy(result[0..nonce.len], &nonce);
        @memcpy(result[nonce.len .. nonce.len + tag.len], &tag);
        @memcpy(result[nonce.len + tag.len ..], ciphertext);

        self.allocator.free(ciphertext);
        return result;
    }

    /// Decrypt data using AES-256-GCM
    fn decryptData(self: *SecretsManager, encrypted_data: []const u8, key: [32]u8) ![]const u8 {
        const nonce_len = 12; // ChaCha20Poly1305 nonce length
        const tag_len = 16; // ChaCha20Poly1305 tag length

        if (encrypted_data.len < nonce_len + tag_len) {
            return error.InvalidEncryptedData;
        }

        var nonce: [nonce_len]u8 = undefined;
        @memcpy(&nonce, encrypted_data[0..nonce_len]);

        var tag: [tag_len]u8 = undefined;
        @memcpy(&tag, encrypted_data[nonce_len .. nonce_len + tag_len]);

        const ciphertext = encrypted_data[nonce_len + tag_len ..];

        const plaintext = try self.allocator.alloc(u8, ciphertext.len);
        errdefer self.allocator.free(plaintext);

        crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(plaintext, ciphertext, tag, "", nonce, key) catch {
            self.allocator.free(plaintext);
            return error.DecryptionFailed;
        };

        return plaintext;
    }
};
