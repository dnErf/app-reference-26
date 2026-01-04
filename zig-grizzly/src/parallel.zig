const std = @import("std");
const types = @import("types.zig");
const column_mod = @import("column.zig");
const table_mod = @import("table.zig");

const Value = types.Value;
const Column = column_mod.Column;
const Table = table_mod.Table;

/// Thread pool for parallel operations
pub const ParallelEngine = struct {
    allocator: std.mem.Allocator,
    thread_count: usize,

    pub fn init(allocator: std.mem.Allocator) ParallelEngine {
        const cpu_count = std.Thread.getCpuCount() catch 4;
        return .{
            .allocator = allocator,
            .thread_count = cpu_count,
        };
    }

    /// Parallel map operation on a column
    pub fn mapColumn(
        self: ParallelEngine,
        col: *Column,
        result: *Column,
        comptime func: fn (Value) Value,
    ) !void {
        if (col.len == 0) return;

        const chunk_size = (col.len + self.thread_count - 1) / self.thread_count;
        var threads = try self.allocator.alloc(std.Thread, self.thread_count);
        defer self.allocator.free(threads);

        const Context = struct {
            col: *Column,
            result: *Column,
            start: usize,
            end: usize,

            fn worker(ctx: *const @This()) void {
                var i = ctx.start;
                while (i < ctx.end) : (i += 1) {
                    const val = ctx.col.get(i) catch unreachable;
                    const new_val = func(val);
                    ctx.result.append(new_val) catch unreachable;
                }
            }
        };

        var contexts = try self.allocator.alloc(Context, self.thread_count);
        defer self.allocator.free(contexts);

        // Launch threads
        var i: usize = 0;
        while (i < self.thread_count) : (i += 1) {
            const start = i * chunk_size;
            const end = @min(start + chunk_size, col.len);

            if (start >= col.len) break;

            contexts[i] = .{
                .col = col,
                .result = result,
                .start = start,
                .end = end,
            };

            threads[i] = try std.Thread.spawn(.{}, Context.worker, .{&contexts[i]});
        }

        // Wait for completion
        for (threads[0..i]) |thread| {
            thread.join();
        }
    }

    /// Parallel reduce operation on a column
    pub fn reduceColumn(
        self: ParallelEngine,
        col: *Column,
        comptime func: fn (Value, Value) Value,
        initial: Value,
    ) !Value {
        if (col.len == 0) return initial;
        if (col.len == 1) return try col.get(0);

        const chunk_size = (col.len + self.thread_count - 1) / self.thread_count;
        var threads = try self.allocator.alloc(std.Thread, self.thread_count);
        defer self.allocator.free(threads);

        var results = try self.allocator.alloc(Value, self.thread_count);
        defer self.allocator.free(results);

        const Context = struct {
            col: *Column,
            result: *Value,
            start: usize,
            end: usize,
            initial_val: Value,

            fn worker(ctx: *const @This()) void {
                var acc = ctx.initial_val;
                var i = ctx.start;
                while (i < ctx.end) : (i += 1) {
                    const val = ctx.col.get(i) catch unreachable;
                    acc = func(acc, val);
                }
                ctx.result.* = acc;
            }
        };

        var contexts = try self.allocator.alloc(Context, self.thread_count);
        defer self.allocator.free(contexts);

        // Launch threads
        var i: usize = 0;
        while (i < self.thread_count) : (i += 1) {
            const start = i * chunk_size;
            const end = @min(start + chunk_size, col.len);

            if (start >= col.len) break;

            results[i] = initial;
            contexts[i] = .{
                .col = col,
                .result = &results[i],
                .start = start,
                .end = end,
                .initial_val = initial,
            };

            threads[i] = try std.Thread.spawn(.{}, Context.worker, .{&contexts[i]});
        }

        // Wait and combine results
        for (threads[0..i]) |thread| {
            thread.join();
        }

        var final_result = results[0];
        for (results[1..i]) |result| {
            final_result = func(final_result, result);
        }

        return final_result;
    }

    /// Parallel filter operation on a table
    pub fn filterTable(
        self: ParallelEngine,
        table: *Table,
        predicate: *const fn ([]const Value) bool,
    ) !Table {
        var result = try Table.init(self.allocator, table.name, table.schema.columns);
        errdefer result.deinit();

        if (table.row_count == 0) return result;

        const chunk_size = (table.row_count + self.thread_count - 1) / self.thread_count;

        // Each thread filters its chunk and stores matching rows
        var thread_results = try self.allocator.alloc(std.ArrayList([]Value), self.thread_count);
        defer {
            for (thread_results) |*list| {
                for (list.items) |row| {
                    self.allocator.free(row);
                }
                list.deinit(self.allocator);
            }
            self.allocator.free(thread_results);
        }

        for (thread_results) |*list| {
            list.* = std.ArrayList([]Value){};
        }

        var threads = try self.allocator.alloc(std.Thread, self.thread_count);
        defer self.allocator.free(threads);

        const Context = struct {
            table: *Table,
            results: *std.ArrayList([]Value),
            start: usize,
            end: usize,
            pred: *const fn ([]const Value) bool,
            allocator: std.mem.Allocator,

            fn worker(ctx: *const @This()) void {
                var row_values = ctx.allocator.alloc(Value, ctx.table.columns.len) catch unreachable;

                var row = ctx.start;
                while (row < ctx.end) : (row += 1) {
                    for (0..ctx.table.columns.len) |col| {
                        row_values[col] = ctx.table.getCell(row, col) catch unreachable;
                    }

                    if (ctx.pred(row_values)) {
                        const owned_row = ctx.allocator.dupe(Value, row_values) catch unreachable;
                        ctx.results.append(ctx.allocator, owned_row) catch unreachable;
                    }
                }

                ctx.allocator.free(row_values);
            }
        };

        var contexts = try self.allocator.alloc(Context, self.thread_count);
        defer self.allocator.free(contexts);

        // Launch threads
        var i: usize = 0;
        while (i < self.thread_count) : (i += 1) {
            const start = i * chunk_size;
            const end = @min(start + chunk_size, table.row_count);

            if (start >= table.row_count) break;

            contexts[i] = .{
                .table = table,
                .results = &thread_results[i],
                .start = start,
                .end = end,
                .pred = predicate,
                .allocator = self.allocator,
            };

            threads[i] = try std.Thread.spawn(.{}, Context.worker, .{&contexts[i]});
        }

        // Wait for completion
        for (threads[0..i]) |thread| {
            thread.join();
        }

        // Combine results
        for (thread_results[0..i]) |list| {
            for (list.items) |row| {
                try result.insertRow(row);
            }
        }

        return result;
    }

    /// SIMD-accelerated sum for numeric columns (when available)
    pub fn vectorSum(col: *Column) !Value {
        return switch (col.data_type) {
            .int32 => blk: {
                var total: i64 = 0;
                const slice = col.asSlice(i32);

                // Process in chunks for better cache locality
                const chunk_size = 64;
                var i: usize = 0;
                while (i + chunk_size <= col.len) : (i += chunk_size) {
                    var chunk_sum: i64 = 0;
                    for (slice[i .. i + chunk_size]) |v| {
                        chunk_sum += v;
                    }
                    total += chunk_sum;
                }

                // Handle remaining elements
                while (i < col.len) : (i += 1) {
                    total += slice[i];
                }

                break :blk Value{ .int64 = total };
            },
            .int64 => blk: {
                var total: i64 = 0;
                const slice = col.asSlice(i64);

                const chunk_size = 64;
                var i: usize = 0;
                while (i + chunk_size <= col.len) : (i += chunk_size) {
                    var chunk_sum: i64 = 0;
                    for (slice[i .. i + chunk_size]) |v| {
                        chunk_sum += v;
                    }
                    total += chunk_sum;
                }

                while (i < col.len) : (i += 1) {
                    total += slice[i];
                }

                break :blk Value{ .int64 = total };
            },
            .float64 => blk: {
                var total: f64 = 0;
                const slice = col.asSlice(f64);

                const chunk_size = 64;
                var i: usize = 0;
                while (i + chunk_size <= col.len) : (i += chunk_size) {
                    var chunk_sum: f64 = 0;
                    for (slice[i .. i + chunk_size]) |v| {
                        chunk_sum += v;
                    }
                    total += chunk_sum;
                }

                while (i < col.len) : (i += 1) {
                    total += slice[i];
                }

                break :blk Value{ .float64 = total };
            },
            else => return error.UnsupportedOperation,
        };
    }
};

test "Parallel sum" {
    const allocator = std.testing.allocator;

    var col = try Column.init(allocator, .int64, 100, .{});
    defer col.deinit();

    var i: i64 = 0;
    while (i < 100) : (i += 1) {
        try col.append(Value{ .int64 = i });
    }

    const engine = ParallelEngine.init(allocator);

    const addFunc = struct {
        fn add(a: Value, b: Value) Value {
            return Value{ .int64 = a.int64 + b.int64 };
        }
    }.add;

    const result = try engine.reduceColumn(&col, addFunc, Value{ .int64 = 0 });

    // Sum of 0..99 = 4950
    try std.testing.expectEqual(@as(i64, 4950), result.int64);
}
