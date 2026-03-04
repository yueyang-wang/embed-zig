const std = @import("std");
const cancellation = @import("cancellation.zig");

pub const TimerError = error{
    TimerNotFound,
};

pub const TimerId = usize;

pub const CallbackFn = *const fn (?*anyopaque) void;

pub const Entry = struct {
    id: TimerId,
    deadline_ms: u64,
    cancelled: bool = false,
    fired: bool = false,
    callback: ?CallbackFn = null,
    callback_ctx: ?*anyopaque = null,
    cancel_source: ?*cancellation.Source = null,
};

pub const Scheduler = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry),
    next_id: TimerId = 1,

    pub fn init(allocator: std.mem.Allocator) Scheduler {
        return .{
            .allocator = allocator,
            .entries = .empty,
        };
    }

    pub fn deinit(self: *Scheduler) void {
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn schedule(
        self: *Scheduler,
        now_ms: u64,
        timeout_ms: u64,
    ) std.mem.Allocator.Error!TimerId {
        return self.scheduleWithCallback(now_ms, timeout_ms, null, null, null);
    }

    pub fn scheduleWithCallback(
        self: *Scheduler,
        now_ms: u64,
        timeout_ms: u64,
        callback: ?CallbackFn,
        callback_ctx: ?*anyopaque,
        cancel_source: ?*cancellation.Source,
    ) std.mem.Allocator.Error!TimerId {
        const id = self.next_id;
        self.next_id += 1;
        try self.entries.append(self.allocator, .{
            .id = id,
            .deadline_ms = now_ms + timeout_ms,
            .callback = callback,
            .callback_ctx = callback_ctx,
            .cancel_source = cancel_source,
        });
        return id;
    }

    pub fn cancel(self: *Scheduler, id: TimerId) TimerError!void {
        for (self.entries.items) |*entry| {
            if (entry.id != id) continue;
            entry.cancelled = true;
            return;
        }
        return error.TimerNotFound;
    }

    pub fn collectReady(self: *Scheduler, now_ms: u64, out_ids: *std.ArrayList(TimerId)) std.mem.Allocator.Error!void {
        for (self.entries.items) |*entry| {
            if (entry.cancelled or entry.fired) continue;
            if (entry.cancel_source) |src| {
                if (src.cancelled) {
                    entry.cancelled = true;
                    continue;
                }
            }
            if (entry.deadline_ms <= now_ms) {
                entry.fired = true;
                try out_ids.append(self.allocator, entry.id);
                if (entry.callback) |cb| {
                    cb(entry.callback_ctx);
                }
            }
        }
    }

    /// Returns the nearest deadline among active (non-cancelled, non-fired) entries,
    /// or null if no active timers remain.
    pub fn nextDeadline(self: *const Scheduler) ?u64 {
        var min: ?u64 = null;
        for (self.entries.items) |entry| {
            if (entry.cancelled or entry.fired) continue;
            if (entry.cancel_source) |src| {
                if (src.cancelled) continue;
            }
            if (min == null or entry.deadline_ms < min.?) {
                min = entry.deadline_ms;
            }
        }
        return min;
    }

    /// Remove all fired and cancelled entries to reclaim memory.
    pub fn compact(self: *Scheduler) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].fired or self.entries.items[i].cancelled) {
                _ = self.entries.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn activeCount(self: *const Scheduler) usize {
        var count: usize = 0;
        for (self.entries.items) |entry| {
            if (!entry.fired and !entry.cancelled) count += 1;
        }
        return count;
    }
};

test "single timer fires once in window" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    _ = try scheduler.schedule(0, 50);
    try scheduler.collectReady(49, &ready);
    try std.testing.expectEqual(@as(usize, 0), ready.items.len);

    try scheduler.collectReady(50, &ready);
    try std.testing.expectEqual(@as(usize, 1), ready.items.len);

    try scheduler.collectReady(100, &ready);
    try std.testing.expectEqual(@as(usize, 1), ready.items.len);
}

test "cancelled timer does not fire" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    const id = try scheduler.schedule(0, 100);
    try scheduler.cancel(id);

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    try scheduler.collectReady(200, &ready);
    try std.testing.expectEqual(@as(usize, 0), ready.items.len);
}

test "zero timeout timer is immediately ready" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(123, 0);

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    try scheduler.collectReady(123, &ready);
    try std.testing.expectEqual(@as(usize, 1), ready.items.len);
}

test "compact removes fired and cancelled entries" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(0, 10);
    _ = try scheduler.schedule(0, 20);
    const id3 = try scheduler.schedule(0, 100);
    _ = try scheduler.schedule(0, 200);

    try scheduler.cancel(id3);

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);
    try scheduler.collectReady(25, &ready);

    try std.testing.expectEqual(@as(usize, 2), ready.items.len);
    try std.testing.expectEqual(@as(usize, 4), scheduler.entries.items.len);

    scheduler.compact();
    try std.testing.expectEqual(@as(usize, 1), scheduler.entries.items.len);
    try std.testing.expectEqual(@as(usize, 1), scheduler.activeCount());
}

test "nextDeadline returns nearest active deadline" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(0, 100);
    _ = try scheduler.schedule(0, 50);
    _ = try scheduler.schedule(0, 200);

    try std.testing.expectEqual(@as(?u64, 50), scheduler.nextDeadline());
}

test "timer with callback fires callback" {
    const Counter = struct {
        var count: usize = 0;
        fn inc(_: ?*anyopaque) void {
            count += 1;
        }
    };
    Counter.count = 0;

    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.scheduleWithCallback(0, 50, Counter.inc, null, null);

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    try scheduler.collectReady(50, &ready);
    try std.testing.expectEqual(@as(usize, 1), Counter.count);
}

test "timer linked to cancel source is auto-cancelled" {
    var cancel_src = cancellation.Source{};

    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.scheduleWithCallback(0, 100, null, null, &cancel_src);

    _ = cancel_src.cancel();

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    try scheduler.collectReady(200, &ready);
    try std.testing.expectEqual(@as(usize, 0), ready.items.len);
}

test "cancel non-existent timer returns TimerNotFound" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    try std.testing.expectError(error.TimerNotFound, scheduler.cancel(999));
}

test "nextDeadline returns null when no timers" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    try std.testing.expectEqual(@as(?u64, null), scheduler.nextDeadline());
}

test "nextDeadline returns null after all timers fired" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(0, 10);
    _ = try scheduler.schedule(0, 20);

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    try scheduler.collectReady(30, &ready);
    try std.testing.expectEqual(@as(?u64, null), scheduler.nextDeadline());
}

test "activeCount tracks live timers" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.schedule(0, 50);
    _ = try scheduler.schedule(0, 100);
    const id3 = try scheduler.schedule(0, 200);

    try std.testing.expectEqual(@as(usize, 3), scheduler.activeCount());

    try scheduler.cancel(id3);
    try std.testing.expectEqual(@as(usize, 2), scheduler.activeCount());

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);
    try scheduler.collectReady(60, &ready);
    try std.testing.expectEqual(@as(usize, 1), scheduler.activeCount());
}

test "multiple timers fire in chronological order" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    const id1 = try scheduler.schedule(0, 30);
    const id2 = try scheduler.schedule(0, 10);
    const id3 = try scheduler.schedule(0, 20);

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    try scheduler.collectReady(10, &ready);
    try std.testing.expectEqual(@as(usize, 1), ready.items.len);
    try std.testing.expectEqual(id2, ready.items[0]);

    try scheduler.collectReady(20, &ready);
    try std.testing.expectEqual(@as(usize, 2), ready.items.len);
    try std.testing.expectEqual(id3, ready.items[1]);

    try scheduler.collectReady(30, &ready);
    try std.testing.expectEqual(@as(usize, 3), ready.items.len);
    try std.testing.expectEqual(id1, ready.items[2]);
}

test "scheduleWithCallback context pointer passed correctly" {
    const Ctx = struct {
        value: usize,
    };
    const handler = struct {
        fn cb(raw: ?*anyopaque) void {
            const ctx: *Ctx = @ptrCast(@alignCast(raw orelse return));
            ctx.value += 10;
        }
    }.cb;

    var ctx = Ctx{ .value = 0 };
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.scheduleWithCallback(0, 50, handler, &ctx, null);
    _ = try scheduler.scheduleWithCallback(0, 50, handler, &ctx, null);

    var ready = std.ArrayList(TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    try scheduler.collectReady(50, &ready);
    try std.testing.expectEqual(@as(usize, 20), ctx.value);
}

test "compact on empty scheduler is safe" {
    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    scheduler.compact();
    try std.testing.expectEqual(@as(usize, 0), scheduler.activeCount());
}

test "nextDeadline skips cancelled-source timers" {
    var cancel_src = cancellation.Source{};

    var scheduler = Scheduler.init(std.testing.allocator);
    defer scheduler.deinit();

    _ = try scheduler.scheduleWithCallback(0, 50, null, null, &cancel_src);
    _ = try scheduler.schedule(0, 200);

    try std.testing.expectEqual(@as(?u64, 50), scheduler.nextDeadline());

    _ = cancel_src.cancel();
    try std.testing.expectEqual(@as(?u64, 200), scheduler.nextDeadline());
}
