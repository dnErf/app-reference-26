const std = @import("std");

pub fn main() !void {
    const writer = std.io.getStdOut().writer();
    try writer.print("Testing IO\n", .{});
}
