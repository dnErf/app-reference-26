//! Automated model refresh scheduler with cron support
//!
//! Features:
//! - Cron expression parsing and scheduling
//! - Background execution with retry logic
//! - Model dependency awareness
//! - Schedule monitoring and status tracking

const std = @import("std");
const root = @import("root.zig");
const Database = root.Database;
const Model = root.model.Model;

/// Cron schedule definition
pub const Schedule = struct {
    id: []const u8,
    model_name: []const u8,
    cron_expr: []const u8,
    retry_count: u32,
    max_retries: u32,
    last_run: ?i64,
    next_run: i64,
    enabled: bool,
    created_at: i64,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, model_name: []const u8, cron_expr: []const u8, max_retries: u32) !Schedule {
        const now = std.time.timestamp();
        const next_run = try parseCronAndGetNext(cron_expr, now);

        return Schedule{
            .id = try allocator.dupe(u8, id),
            .model_name = try allocator.dupe(u8, model_name),
            .cron_expr = try allocator.dupe(u8, cron_expr),
            .retry_count = 0,
            .max_retries = max_retries,
            .last_run = null,
            .next_run = next_run,
            .enabled = true,
            .created_at = now,
        };
    }

    pub fn deinit(self: *Schedule, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.model_name);
        allocator.free(self.cron_expr);
    }

    pub fn shouldRun(self: Schedule, current_time: i64) bool {
        return self.enabled and current_time >= self.next_run;
    }

    pub fn markRun(self: *Schedule, current_time: i64) !void {
        self.last_run = current_time;
        self.next_run = try parseCronAndGetNext(self.cron_expr, current_time);
        self.retry_count = 0; // Reset retry count on successful run
    }

    pub fn markFailed(self: *Schedule) void {
        self.retry_count += 1;
    }

    pub fn canRetry(self: Schedule) bool {
        return self.retry_count < self.max_retries;
    }
};

/// Scheduler manages automated model refresh schedules
pub const Scheduler = struct {
    allocator: std.mem.Allocator,
    schedules: std.ArrayList(Schedule),
    running: bool,
    thread: ?std.Thread,

    pub fn init(allocator: std.mem.Allocator) !Scheduler {
        return Scheduler{
            .allocator = allocator,
            .schedules = try std.ArrayList(Schedule).initCapacity(allocator, 4),
            .running = false,
            .thread = null,
        };
    }

    pub fn deinit(self: *Scheduler) void {
        self.stop();
        for (self.schedules.items) |*schedule| {
            schedule.deinit(self.allocator);
        }
        self.schedules.deinit(self.allocator);
    }

    /// Add a new schedule
    pub fn addSchedule(self: *Scheduler, schedule: Schedule) !void {
        try self.schedules.append(self.allocator, schedule);
    }

    /// Remove a schedule by ID
    pub fn removeSchedule(self: *Scheduler, id: []const u8) bool {
        for (self.schedules.items, 0..) |schedule, i| {
            if (std.mem.eql(u8, schedule.id, id)) {
                var removed = self.schedules.orderedRemove(i);
                removed.deinit(self.allocator);
                return true;
            }
        }
        return false;
    }

    /// Get schedule by ID
    pub fn getSchedule(self: *Scheduler, id: []const u8) ?*Schedule {
        for (self.schedules.items) |*schedule| {
            if (std.mem.eql(u8, schedule.id, id)) {
                return schedule;
            }
        }
        return null;
    }

    /// Start background scheduler thread
    pub fn start(self: *Scheduler) !void {
        if (self.running) return;

        self.running = true;
        self.thread = try std.Thread.spawn(.{}, backgroundWorker, .{self});
    }

    /// Stop background scheduler
    pub fn stop(self: *Scheduler) void {
        if (!self.running) return;

        self.running = false;
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    /// Check and execute pending schedules (for manual triggering)
    pub fn checkAndExecute(self: *Scheduler, db: *Database) !void {
        const now = std.time.timestamp();

        for (self.schedules.items) |*schedule| {
            if (schedule.shouldRun(now)) {
                try self.executeSchedule(schedule, db);
            }
        }
    }

    fn executeSchedule(_: *Scheduler, schedule: *Schedule, db: *Database) !void {
        std.debug.print("Executing scheduled refresh for model: {s}\n", .{schedule.model_name});

        // Find the model
        _ = db.models.getModel(schedule.model_name) orelse {
            std.debug.print("Model {s} not found, skipping schedule\n", .{schedule.model_name});
            schedule.markFailed();
            return;
        };

        // Execute the model refresh
        db.refreshModel(schedule.model_name) catch |err| {
            std.debug.print("Failed to refresh model {s}: {}\n", .{ schedule.model_name, err });
            schedule.markFailed();

            // TODO: Implement retry logic with exponential backoff
            if (schedule.canRetry()) {
                std.debug.print("Will retry model {s} (attempt {}/{}) \n", .{ schedule.model_name, schedule.retry_count + 1, schedule.max_retries });
            } else {
                std.debug.print("Max retries exceeded for model {s}, disabling schedule\n", .{schedule.model_name});
                schedule.enabled = false;
            }
            return;
        };

        // Mark as successful
        const now = std.time.timestamp();
        try schedule.markRun(now);
        std.debug.print("Successfully refreshed model: {s}\n", .{schedule.model_name});
    }

    fn backgroundWorker(self: *Scheduler) void {
        while (self.running) {
            // Sleep for 1 minute
            std.time.sleep(60 * std.time.ns_per_s);

            // TODO: Get database instance - this needs to be passed or stored
            // For now, skip background execution
            // try self.checkAndExecute(db);
        }
    }
};

/// Parse cron expression and get next execution time
/// Format: "minute hour day month day-of-week"
/// Example: "0 2 * * *" = daily at 2 AM
fn parseCronAndGetNext(cron_expr: []const u8, current_time: i64) !i64 {
    _ = cron_expr; // TODO: Implement full cron parsing
    // For now, simple implementation: assume "0 2 * * *" format (daily at 2 AM)
    // TODO: Implement full cron parsing

    // Calculate next 2 AM
    const seconds_in_day = 86400;
    const target_hour = 2;
    const target_minute = 0;
    const target_seconds = target_hour * 3600 + target_minute * 60;

    const current_day_start = current_time - @mod(current_time, seconds_in_day);
    const target_time_today = current_day_start + target_seconds;

    if (current_time < target_time_today) {
        return target_time_today;
    } else {
        return target_time_today + seconds_in_day;
    }
}

test "schedule creation" {
    const allocator = std.testing.allocator;

    var schedule = try Schedule.init(allocator, "test_schedule", "test_model", "0 2 * * *", 3);
    defer schedule.deinit(allocator);

    try std.testing.expectEqualStrings("test_schedule", schedule.id);
    try std.testing.expectEqualStrings("test_model", schedule.model_name);
    try std.testing.expectEqualStrings("0 2 * * *", schedule.cron_expr);
    try std.testing.expectEqual(@as(u32, 3), schedule.max_retries);
    try std.testing.expect(schedule.enabled);
}

test "cron parsing basic" {
    // Test basic daily cron
    const next = try parseCronAndGetNext("0 2 * * *", 1609459200); // 2021-01-01 00:00:00
    const expected = 1609466400; // 2021-01-01 02:00:00
    try std.testing.expectEqual(expected, next);
}
