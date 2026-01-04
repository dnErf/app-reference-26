const std = @import("std");
const Database = @import("src/database.zig").Database;
const audit_mod = @import("src/audit.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Create database
    var db = try Database.init(allocator, "test_db");
    defer db.deinit();
    
    // Create audit log
    var audit_log = audit_mod.AuditLog.init(allocator);
    defer audit_log.deinit();
    
    // Attach audit log
    db.attachAuditLog(&audit_log);
    
    // Create a virtual view
    try db.createView("test_view", "SELECT 1 as id");
    
    // Create a materialized view
    try db.createMaterializedView("test_mv", "SELECT 2 as id");
    
    // Refresh the materialized view
    try db.refreshMaterializedView("test_mv");
    
    // Get view info
    if (try db.getViewInfo("test_view", allocator)) |info| {
        defer allocator.free(info.name);
        defer allocator.free(info.sql_definition);
        std.debug.print("View: {s}, Type: {}, SQL: {s}\n", .{info.name, info.view_type, info.sql_definition});
    }
    
    // Get materialized view info
    if (try db.getMaterializedViewInfo("test_mv", allocator)) |info| {
        defer allocator.free(info.name);
        defer allocator.free(info.sql_definition);
        std.debug.print("MV: {s}, SQL: {s}, Policy: {}\n", .{info.name, info.sql_definition, info.refresh_policy});
    }
    
    // List all view infos
    const all_views = try db.listAllViewInfos(allocator);
    defer {
        for (all_views.virtual) |info| {
            allocator.free(info.name);
            allocator.free(info.sql_definition);
        }
        allocator.free(all_views.virtual);
        for (all_views.materialized) |info| {
            allocator.free(info.name);
            allocator.free(info.sql_definition);
        }
        allocator.free(all_views.materialized);
    }
    
    std.debug.print("Total views: {} virtual, {} materialized\n", .{all_views.virtual.len, all_views.materialized.len});
    
    // Export audit log
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try audit_log.exportJSON(buffer.writer());
    std.debug.print("Audit log: {s}\n", .{buffer.items});
}
