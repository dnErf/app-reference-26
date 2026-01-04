const std = @import("std");
const checkpoint = @import("../src/checkpoint.zig");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const args_it = std.process.argsAlloc(allocator) catch return;
    defer std.process.argsFree(allocator, args_it);

    var clear_flag = false;
    var i: usize = 1;
    while (i < args_it.len) : (i += 1) {
        const s = args_it[i];
        if (std.mem.eql(u8, s, "--clear")) {
            clear_flag = true;
        }
    }

    const cp = checkpoint.read(allocator) catch null;
    if (cp == null) {
        std.debug.print("No AI checkpoint present.\n", .{});
        return;
    }
    defer cp.?.deinit(allocator);

    std.debug.print("AI Checkpoint:\n", .{});
    std.debug.print("  task: {s}\n", .{cp.?.task});
    std.debug.print("  step: {s}\n", .{cp.?.step});
    if (cp.?.table) |t| std.debug.print("  table: {s}\n", .{t});
    if (cp.?.column_index) |ci| std.debug.print("  column_index: {d}\n", .{ci});
    std.debug.print("  status: {s}\n", .{cp.?.status});
    if (cp.?.error_msg) |e| std.debug.print("  error: {s}\n", .{e});

    if (clear_flag) {
        checkpoint.clear();
        std.debug.print("Checkpoint cleared.\n", .{});
    } else {
        std.debug.print("Use --clear to remove the checkpoint after manual inspection.\n", .{});
    }
}
