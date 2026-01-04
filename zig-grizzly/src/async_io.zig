const std = @import("std");
const lakehouse_mod = @import("lakehouse.zig");
const database_mod = @import("database.zig");
const format_mod = @import("format.zig");

const Lakehouse = lakehouse_mod.Lakehouse;
const Database = database_mod.Database;

/// Async I/O wrapper for lakehouse operations
/// Uses Zig's thread pool for non-blocking I/O
pub const AsyncLakehouse = struct {
    allocator: std.mem.Allocator,
    thread_pool: *std.Thread.Pool,
    lakehouse: Lakehouse,

    pub fn init(allocator: std.mem.Allocator, thread_count: ?usize) !AsyncLakehouse {
        const pool = try allocator.create(std.Thread.Pool);
        const count = thread_count orelse (std.Thread.getCpuCount() catch 4);

        try pool.init(.{
            .allocator = allocator,
            .n_jobs = count,
        });

        return .{
            .allocator = allocator,
            .thread_pool = pool,
            .lakehouse = Lakehouse.init(allocator),
        };
    }

    pub fn deinit(self: *AsyncLakehouse) void {
        self.thread_pool.deinit();
        self.allocator.destroy(self.thread_pool);
    }

    /// Async save operation
    pub fn saveAsync(
        self: *AsyncLakehouse,
        db: *Database,
        path: []const u8,
        callback: *const fn (*Database, ?anyerror) void,
    ) !void {
        const ctx = try self.allocator.create(SaveContext);
        ctx.* = .{
            .lakehouse = &self.lakehouse,
            .db = db,
            .path = try self.allocator.dupe(u8, path),
            .callback = callback,
            .allocator = self.allocator,
        };

        try self.thread_pool.spawn(saveWorker, .{ctx});
    }

    const SaveContext = struct {
        lakehouse: *const Lakehouse,
        db: *Database,
        path: []const u8,
        callback: *const fn (*Database, ?anyerror) void,
        allocator: std.mem.Allocator,
    };

    fn saveWorker(ctx: *SaveContext) void {
        const err = ctx.lakehouse.save(ctx.db, ctx.path, format_mod.CompressionType.none) catch |e| e;
        ctx.callback(ctx.db, if (err == void) null else err);

        ctx.allocator.free(ctx.path);
        ctx.allocator.destroy(ctx);
    }

    /// Async load operation
    pub fn loadAsync(
        self: *AsyncLakehouse,
        path: []const u8,
        callback: *const fn (Database, ?anyerror) void,
    ) !void {
        const ctx = try self.allocator.create(LoadContext);
        ctx.* = .{
            .lakehouse = &self.lakehouse,
            .path = try self.allocator.dupe(u8, path),
            .callback = callback,
            .allocator = self.allocator,
        };

        try self.thread_pool.spawn(loadWorker, .{ctx});
    }

    const LoadContext = struct {
        lakehouse: *const Lakehouse,
        path: []const u8,
        callback: *const fn (Database, ?anyerror) void,
        allocator: std.mem.Allocator,
    };

    fn loadWorker(ctx: *LoadContext) void {
        const result = ctx.lakehouse.load(ctx.path) catch |e| {
            // Create empty database on error
            const empty_db = Database.init(ctx.allocator, "error") catch unreachable;
            ctx.callback(empty_db, e);
            ctx.allocator.free(ctx.path);
            ctx.allocator.destroy(ctx);
            return;
        };

        ctx.callback(result, null);
        ctx.allocator.free(ctx.path);
        ctx.allocator.destroy(ctx);
    }

    /// Blocking save (for backwards compatibility)
    pub fn save(self: *AsyncLakehouse, db: *Database, path: []const u8) !void {
        return self.lakehouse.save(db, path, format_mod.CompressionType.none);
    }

    /// Blocking load (for backwards compatibility)
    pub fn load(self: *AsyncLakehouse, path: []const u8) !Database {
        return self.lakehouse.load(path);
    }
};

/// Future-based async operations (alternative API)
pub const AsyncFuture = struct {
    completed: std.atomic.Value(bool),
    result: ?anyerror,
    mutex: std.Thread.Mutex,

    pub fn init() AsyncFuture {
        return .{
            .completed = std.atomic.Value(bool).init(false),
            .result = null,
            .mutex = .{},
        };
    }

    pub fn wait(self: *AsyncFuture) !void {
        // Spin until completed
        while (!self.completed.load(.acquire)) {
            std.atomic.spinLoopHint();
        }

        if (self.result) |err| {
            return err;
        }
    }

    pub fn complete(self: *AsyncFuture, result: ?anyerror) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.result = result;
        self.completed.store(true, .release);
    }

    pub fn isReady(self: *const AsyncFuture) bool {
        return self.completed.load(.acquire);
    }
};

/// Work-stealing scheduler for parallel query execution
pub const WorkStealingScheduler = struct {
    allocator: std.mem.Allocator,
    thread_pool: *std.Thread.Pool,
    work_queues: []std.ArrayList(WorkItem),
    workers: []Worker,
    running: std.atomic.Value(bool),

    const WorkItem = struct {
        func: *const fn (*anyopaque) void,
        context: *anyopaque,
    };

    const Worker = struct {
        id: usize,
        scheduler: *WorkStealingScheduler,
        local_queue: *std.ArrayList(WorkItem),
    };

    pub fn init(allocator: std.mem.Allocator, thread_count: ?usize) !WorkStealingScheduler {
        const count = thread_count orelse (std.Thread.getCpuCount() catch 4);

        const pool = try allocator.create(std.Thread.Pool);
        try pool.init(.{
            .allocator = allocator,
            .n_jobs = count,
        });

        const queues = try allocator.alloc(std.ArrayList(WorkItem), count);
        for (queues) |*queue| {
            queue.* = std.ArrayList(WorkItem){};
        }

        const workers = try allocator.alloc(Worker, count);

        return .{
            .allocator = allocator,
            .thread_pool = pool,
            .work_queues = queues,
            .workers = workers,
            .running = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *WorkStealingScheduler) void {
        self.running.store(false, .release);

        for (self.work_queues) |*queue| {
            queue.deinit(self.allocator);
        }
        self.allocator.free(self.work_queues);
        self.allocator.free(self.workers);

        self.thread_pool.deinit();
        self.allocator.destroy(self.thread_pool);
    }

    pub fn start(self: *WorkStealingScheduler) !void {
        self.running.store(true, .release);

        // Start worker threads
        for (self.workers, 0..) |*worker, i| {
            worker.* = .{
                .id = i,
                .scheduler = self,
                .local_queue = &self.work_queues[i],
            };
            try self.thread_pool.spawn(workerLoop, .{worker});
        }
    }

    fn workerLoop(worker: *Worker) void {
        while (worker.scheduler.running.load(.acquire)) {
            // Try to get work from local queue
            if (worker.local_queue.popOrNull()) |item| {
                item.func(item.context);
                continue;
            }

            // Try to steal from other workers
            var attempts: usize = 0;
            while (attempts < worker.scheduler.workers.len) : (attempts += 1) {
                const target = (worker.id + attempts + 1) % worker.scheduler.workers.len;
                const target_queue = &worker.scheduler.work_queues[target];

                if (target_queue.items.len > 0) {
                    // Steal from the back (LIFO for better cache locality)
                    const stolen = target_queue.pop();
                    stolen.func(stolen.context);
                    break;
                }
            }

            // No work available, yield
            std.Thread.yield() catch {};
        }
    }

    pub fn submit(self: *WorkStealingScheduler, func: *const fn (*anyopaque) void, context: *anyopaque) !void {
        // Simple round-robin distribution for now
        // In production, use thread-local counters
        const target = @mod(std.crypto.random.int(usize), self.work_queues.len);
        try self.work_queues[target].append(self.allocator, .{
            .func = func,
            .context = context,
        });
    }
};

test "AsyncLakehouse creation" {
    const allocator = std.testing.allocator;

    var async_lh = try AsyncLakehouse.init(allocator, 2);
    defer async_lh.deinit();

    // Basic smoke test - just check it doesn't crash
}

test "AsyncFuture wait" {
    var future = AsyncFuture.init();

    try std.testing.expect(!future.isReady());

    future.complete(null);

    try std.testing.expect(future.isReady());
    try future.wait();
}

test "WorkStealingScheduler creation" {
    const allocator = std.testing.allocator;

    var scheduler = try WorkStealingScheduler.init(allocator, 2);
    defer scheduler.deinit();

    // Basic smoke test
}
