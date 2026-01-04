const std = @import("std");
pub fn main() !void {
    try std.fs.File.writeAll(std.fs.cwd(), "test.txt", "Hello\n");
}
