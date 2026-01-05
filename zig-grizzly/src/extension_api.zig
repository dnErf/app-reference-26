const std = @import("std");

/// Extension capabilities
pub const ExtensionCapability = enum {
    http_client,
    https_client,
    remote_data_access,
    data_export,
    secrets_management,
    custom_storage,
    custom_functions,
};

/// Extension configuration
pub const ExtensionConfig = struct {
    name: []const u8,
    version: []const u8,
    capabilities: []const ExtensionCapability,
    config_data: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ExtensionConfig) void {
        self.allocator.free(self.name);
        self.allocator.free(self.version);
        if (self.config_data) |data| {
            self.allocator.free(data);
        }
    }
};

/// Extension interface
pub const Extension = struct {
    name: []const u8,
    version: []const u8,
    capabilities: []const ExtensionCapability,

    /// Initialize the extension
    init: *const fn (config: ExtensionConfig) anyerror!void,

    /// Deinitialize the extension
    deinit: *const fn () void,

    /// Handle a query (for extensions that provide custom query handling)
    handle_query: ?*const fn (query: []const u8) anyerror![]const u8,

    /// Get extension metadata
    get_metadata: ?*const fn () ExtensionMetadata,

    pub const ExtensionMetadata = struct {
        description: []const u8,
        author: []const u8,
        license: []const u8,
        repository: ?[]const u8 = null,
    };
};

/// Extension registry entry
pub const ExtensionEntry = struct {
    extension: Extension,
    config: ExtensionConfig,
    is_loaded: bool = false,

    pub fn deinit(self: *ExtensionEntry) void {
        self.config.deinit();
    }
};
