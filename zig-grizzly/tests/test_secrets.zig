const std = @import("std");
const testing = std.testing;
const SecretsManager = @import("zig_grizzly").SecretsManager;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("Running SecretsManager tests...\n", .{});

    // Test 1: create and retrieve secret
    std.debug.print("Test 1: create and retrieve secret\n", .{});
    {
        var manager = try SecretsManager.init(allocator, .{});
        defer manager.deinit();

        try manager.createSecret("test_token", .token, "secret_value");

        var secret = try manager.getSecret("test_token");
        defer secret.deinit(allocator);
        std.testing.expectEqual(SecretsManager.Secret.SecretType.token, secret.type) catch |err| {
            std.debug.print("FAILED: {}\n", .{err});
            return err;
        };
        std.testing.expectEqualStrings("test_token", secret.name) catch |err| {
            std.debug.print("FAILED: {}\n", .{err});
            return err;
        };

        const value = try manager.getSecretValue("test_token", allocator);
        defer allocator.free(value);
        std.testing.expectEqualStrings("secret_value", value) catch |err| {
            std.debug.print("FAILED: {}\n", .{err});
            return err;
        };
        std.debug.print("PASSED\n", .{});
    }

    // Test 2: update secret
    std.debug.print("Test 2: update secret\n", .{});
    {
        var manager = try SecretsManager.init(allocator, .{});
        defer manager.deinit();

        try manager.createSecret("test_key", .key, "old_value");
        try manager.updateSecret("test_key", "new_value");

        const value = try manager.getSecretValue("test_key", allocator);
        defer allocator.free(value);
        std.testing.expectEqualStrings("new_value", value) catch |err| {
            std.debug.print("FAILED: {}\n", .{err});
            return err;
        };
        std.debug.print("PASSED\n", .{});
    }

    // Test 3: delete secret
    std.debug.print("Test 3: delete secret\n", .{});
    {
        var manager = try SecretsManager.init(allocator, .{});
        defer manager.deinit();

        try manager.createSecret("temp_secret", .password, "temp_value");
        try manager.deleteSecret("temp_secret");

        std.testing.expectError(error.SecretNotFound, manager.getSecret("temp_secret")) catch |err| {
            std.debug.print("FAILED: {}\n", .{err});
            return err;
        };
        std.debug.print("PASSED\n", .{});
    }

    // Test 4: list secrets
    std.debug.print("Test 4: list secrets\n", .{});
    {
        var manager = try SecretsManager.init(allocator, .{});
        defer manager.deinit();

        try manager.createSecret("secret1", .token, "value1");
        try manager.createSecret("secret2", .password, "value2");
        try manager.createSecret("secret3", .key, "value3");

        var secret_names = try manager.listSecrets(allocator);
        defer secret_names.deinit(allocator);

        std.testing.expectEqual(@as(usize, 3), secret_names.items.len) catch |err| {
            std.debug.print("FAILED: {}\n", .{err});
            return err;
        };

        var found1 = false;
        var found2 = false;
        var found3 = false;
        for (secret_names.items) |name| {
            if (std.mem.eql(u8, name, "secret1")) found1 = true;
            if (std.mem.eql(u8, name, "secret2")) found2 = true;
            if (std.mem.eql(u8, name, "secret3")) found3 = true;
        }
        if (!(found1 and found2 and found3)) {
            std.debug.print("FAILED: Not all secrets found in list\n", .{});
            return error.TestFailed;
        }
        std.debug.print("PASSED\n", .{});
    }

    // Test 5: duplicate secret error
    std.debug.print("Test 5: duplicate secret error\n", .{});
    {
        var manager = try SecretsManager.init(allocator, .{});
        defer manager.deinit();

        try manager.createSecret("duplicate", .token, "value1");

        std.testing.expectError(error.SecretAlreadyExists, manager.createSecret("duplicate", .password, "value2")) catch |err| {
            std.debug.print("FAILED: {}\n", .{err});
            return err;
        };
        std.debug.print("PASSED\n", .{});
    }

    std.debug.print("All SecretsManager tests passed!\n", .{});
}
