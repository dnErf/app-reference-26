const std = @import("std");

pub const Checkpoint = struct {
    task: []const u8,
    step: []const u8,
    table: ?[]const u8 = null,
    column_index: ?usize = null,
    status: []const u8,
    timestamp: i64,
    error_msg: ?[]const u8 = null,

    pub fn deinit(self: Checkpoint, allocator: std.mem.Allocator) void {
        allocator.free(self.task);
        allocator.free(self.step);
        if (self.table) |t| allocator.free(t);
        allocator.free(self.status);
        if (self.error_msg) |e| allocator.free(e);
    }
};

pub fn path() []const u8 {
    return ".ai_checkpoint.json";
}

pub fn write(allocator: std.mem.Allocator, cp: Checkpoint) !void {
    const tmp = ".ai_checkpoint.json.tmp";

    const file = try std.fs.cwd().createFile(tmp, .{ .truncate = true });
    defer file.close();

    var json = std.ArrayList(u8){};
    defer json.deinit(allocator);
    const w = json.writer(allocator);

    try w.writeAll("{\n");
    try w.print("  \"task\": \"{s}\",\n", .{cp.task});
    try w.print("  \"step\": \"{s}\",\n", .{cp.step});
    if (cp.table) |t| try w.print("  \"table\": \"{s}\",\n", .{t});
    if (cp.column_index) |ci| try w.print("  \"column_index\": {d},\n", .{ci});
    try w.print("  \"status\": \"{s}\",\n", .{cp.status});
    try w.print("  \"timestamp\": {d}\n", .{cp.timestamp});
    if (cp.error_msg) |e| {
        try w.writeAll(",\n");
        try w.print("  \"error_msg\": \"{s}\"\n", .{e});
    }
    try w.writeAll("}\n");

    try file.writeAll(json.items);
    // atomic replace
    try std.fs.cwd().rename(tmp, path());
}

pub fn clear() void {
    _ = std.fs.cwd().deleteFile(path()) catch {};
}

pub fn read(allocator: std.mem.Allocator) !?Checkpoint {
    const file = std.fs.cwd().openFile(path(), .{}) catch return null;
    defer file.close();

    const size = (try file.stat()).size;
    const data = try allocator.alloc(u8, size);
    defer allocator.free(data);
    const bytes_read = try file.readAll(data);
    if (bytes_read != size) return null;

    const Doc = struct {
        task: []const u8,
        step: []const u8,
        table: ?[]const u8 = null,
        column_index: ?usize = null,
        status: []const u8,
        timestamp: i64,
        error_msg: ?[]const u8 = null,
    };

    var parsed = try std.json.parseFromSlice(Doc, allocator, data, .{});

    // Duplicate parsed strings into the provided allocator so we can safely
    // deinit the parser and free the temporary buffer.
    const task_copy = try allocator.dupe(u8, parsed.value.task);
    const step_copy = try allocator.dupe(u8, parsed.value.step);
    var table_copy: ?[]const u8 = null;
    if (parsed.value.table) |t| table_copy = try allocator.dupe(u8, t);
    const column_index_copy = parsed.value.column_index;
    const status_copy = try allocator.dupe(u8, parsed.value.status);
    const timestamp_copy = parsed.value.timestamp;
    var error_copy: ?[]const u8 = null;
    if (parsed.value.error_msg) |e| error_copy = try allocator.dupe(u8, e);

    parsed.deinit();

    return Checkpoint{
        .task = task_copy,
        .step = step_copy,
        .table = table_copy,
        .column_index = column_index_copy,
        .status = status_copy,
        .timestamp = timestamp_copy,
        .error_msg = error_copy,
    };
}

// Basic tests
test "checkpoint write/read/clear" {
    const alloc = std.testing.allocator;
    clear();

    const cp = Checkpoint{ .task = "save", .step = "writeTable", .table = "users", .column_index = null, .status = "in-progress", .timestamp = std.time.timestamp(), .error_msg = null };
    try write(alloc, cp);

    const got = try read(alloc) orelse @panic("missing");
    defer got.deinit(alloc);
    try std.testing.expect(std.mem.eql(u8, got.task, "save"));
    try std.testing.expect(std.mem.eql(u8, got.step, "writeTable"));
    try std.testing.expect(std.mem.eql(u8, got.table.?, "users"));

    clear();
    const none = try read(alloc);
    try std.testing.expect(none == null);
}
