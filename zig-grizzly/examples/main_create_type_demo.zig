const std = @import("std");
const zig_grizzly = @import("zig_grizzly");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create database
    var db = try zig_grizzly.Database.init(allocator, "test_db");
    defer db.deinit();

    // Create query engine
    var engine = zig_grizzly.QueryEngine.init(allocator, &db, &db.functions);

    // Test CREATE TYPE ENUM
    std.debug.print("Testing CREATE TYPE ENUM...\n", .{});

    const sql1 = "CREATE TYPE mood AS ENUM ('happy', 'sad', 'curious');";
    const result1 = try engine.execute(sql1);
    std.debug.print("Result: {s}\n", .{result1.message});

    // Test CREATE TYPE STRUCT
    std.debug.print("Testing CREATE TYPE STRUCT...\n", .{});

    const sql4 = "CREATE TYPE person AS STRUCT (name VARCHAR, age INTEGER);";
    const result4 = try engine.execute(sql4);
    std.debug.print("Result: {s}\n", .{result4.message});

    const sql5 = "CREATE TYPE address AS STRUCT (street VARCHAR, city VARCHAR, zipcode INTEGER);";
    const result5 = try engine.execute(sql5);
    std.debug.print("Result: {s}\n", .{result5.message});

    // Test CREATE TYPE ALIAS
    std.debug.print("Testing CREATE TYPE ALIAS...\n", .{});

    const sql6 = "CREATE TYPE my_int AS mood;";
    const result6 = try engine.execute(sql6);
    std.debug.print("Result: {s}\n", .{result6.message});

    const sql7 = "CREATE TYPE string_alias AS VARCHAR;";
    const result7 = try engine.execute(sql7);
    std.debug.print("Result: {s}\n", .{result7.message});

    // Test SHOW TYPES
    std.debug.print("Testing SHOW TYPES...\n", .{});

    const sql8 = "SHOW TYPES;";
    const result8 = try engine.execute(sql8);
    std.debug.print("Result:\n{s}\n", .{result8.message});

    // Test DESCRIBE TYPE
    std.debug.print("Testing DESCRIBE TYPE...\n", .{});

    const sql9 = "DESCRIBE TYPE mood;";
    const result9 = try engine.execute(sql9);
    std.debug.print("Result:\n{s}\n", .{result9.message});

    const sql10 = "DESCRIBE TYPE person;";
    const result10 = try engine.execute(sql10);
    std.debug.print("Result:\n{s}\n", .{result10.message});

    const sql11 = "DESCRIBE TYPE my_int;";
    const result11 = try engine.execute(sql11);
    std.debug.print("Result:\n{s}\n", .{result11.message});

    const sql3 = "CREATE TYPE invalid AS ENUM ('value1', 'value2'"; // Missing closing paren
    _ = engine.execute(sql3) catch |err| {
        std.debug.print("Expected error for invalid syntax: {}\n", .{err});
        return;
    };
}
