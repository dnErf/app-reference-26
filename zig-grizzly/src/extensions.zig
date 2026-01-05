const std = @import("std");
const extension_api = @import("extension_api.zig");
const dynamic_loader = @import("dynamic_loader.zig");

const Extension = extension_api.Extension;
const ExtensionConfig = extension_api.ExtensionConfig;
const ExtensionEntry = extension_api.ExtensionEntry;
const ExtensionCapability = extension_api.ExtensionCapability;
const DynamicLoader = dynamic_loader.DynamicLoader;

/// Extension manager
pub const ExtensionManager = struct {
    allocator: std.mem.Allocator,
    registry: std.StringHashMap(ExtensionEntry),
    loader: DynamicLoader,
    loaded_extensions: std.StringHashMap(Extension),

    pub fn init(allocator: std.mem.Allocator) ExtensionManager {
        return ExtensionManager{
            .allocator = allocator,
            .registry = std.StringHashMap(ExtensionEntry).init(allocator),
            .loader = DynamicLoader.init(allocator),
            .loaded_extensions = std.StringHashMap(Extension).init(allocator),
        };
    }

    pub fn deinit(self: *ExtensionManager) void {
        // Deinit loaded extensions
        var loaded_it = self.loaded_extensions.valueIterator();
        while (loaded_it.next()) |ext| {
            ext.deinit();
        }
        self.loaded_extensions.deinit();

        // Deinit registry
        var registry_it = self.registry.valueIterator();
        while (registry_it.next()) |entry| {
            entry.deinit();
        }
        self.registry.deinit();

        self.loader.deinit();
    }

    /// Register an extension
    pub fn register(self: *ExtensionManager, config: ExtensionConfig) !void {
        if (self.registry.contains(config.name)) {
            return error.ExtensionAlreadyRegistered;
        }

        const entry = ExtensionEntry{
            .extension = undefined, // Will be set when loaded
            .config = config,
            .is_loaded = false,
        };

        try self.registry.put(try self.allocator.dupe(u8, config.name), entry);
    }

    /// Install an extension (register + load)
    pub fn install(self: *ExtensionManager, config: ExtensionConfig) !void {
        try self.register(config);
        try self.load(config.name);
    }

    /// Load an extension by name
    pub fn load(self: *ExtensionManager, name: []const u8) !void {
        const entry = self.registry.getPtr(name) orelse return error.ExtensionNotFound;
        if (entry.is_loaded) return;

        // For now, assume built-in extensions
        // In future, check if it's a shared library or built-in
        const extension = try self.loader.loadFromFile("dummy", entry.config);

        try self.loaded_extensions.put(try self.allocator.dupe(u8, name), extension);
        entry.is_loaded = true;
    }

    /// Unload an extension
    pub fn unload(self: *ExtensionManager, name: []const u8) !void {
        const entry = self.registry.getPtr(name) orelse return error.ExtensionNotFound;
        if (!entry.is_loaded) return;

        if (self.loaded_extensions.get(name)) |ext| {
            ext.deinit();
            _ = self.loaded_extensions.remove(name);
        }

        entry.is_loaded = false;
    }

    /// Check if extension is loaded
    pub fn isLoaded(self: *ExtensionManager, name: []const u8) bool {
        const entry = self.registry.get(name) orelse return false;
        return entry.is_loaded;
    }

    /// Get loaded extension
    pub fn getExtension(self: *ExtensionManager, name: []const u8) ?Extension {
        return self.loaded_extensions.get(name);
    }

    /// List all registered extensions
    pub fn listExtensions(self: *ExtensionManager, allocator: std.mem.Allocator) ![][]const u8 {
        var temp_list = std.ArrayListUnmanaged([]const u8){};
        defer temp_list.deinit(allocator);
        var it = self.registry.keyIterator();
        while (it.next()) |key| {
            try temp_list.append(allocator, try allocator.dupe(u8, key.*));
        }
        return temp_list.toOwnedSlice(allocator);
    }

    /// Handle query with extensions
    pub fn handleQuery(self: *ExtensionManager, query: []const u8) ?[]const u8 {
        var it = self.loaded_extensions.valueIterator();
        while (it.next()) |ext| {
            if (ext.handle_query) |handler| {
                if (handler(query)) |result| {
                    return result;
                } else |_| {
                    continue;
                }
            }
        }
        return null;
    }
};
