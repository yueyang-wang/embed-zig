const std = @import("std");
const embed = @import("embed");
const time = embed.runtime.std.std_time;
const sync = embed.runtime.std.std_sync;
const thread = embed.runtime.std.std_thread;

const std_time: time.Time = .{};

fn markDone(ctx: ?*anyopaque) void {
    const value: *std.atomic.Value(u32) = @ptrCast(@alignCast(ctx.?));
    _ = value.fetchAdd(1, .seq_cst);
}

fn notifyAfterDelay(ctx: ?*anyopaque) void {
    const n: *sync.Notify = @ptrCast(@alignCast(ctx.?));
    std_time.sleepMs(20);
    n.signal();
}

test "std thread spawn/join executes task" {
    var counter = std.atomic.Value(u32).init(0);
    var th = try thread.Thread.spawn(.{}, markDone, @ptrCast(&counter));
    th.join();
    try std.testing.expectEqual(@as(u32, 1), counter.load(.seq_cst));
}

test "std condition wait/signal works" {
    const Ctx = struct {
        mutex: sync.Mutex,
        cond: sync.Condition,
        ready: bool,
    };

    const waiter = struct {
        fn run(ptr: ?*anyopaque) void {
            const ctx: *Ctx = @ptrCast(@alignCast(ptr.?));
            ctx.mutex.lock();
            defer ctx.mutex.unlock();
            while (!ctx.ready) {
                ctx.cond.wait(&ctx.mutex);
            }
        }
    };

    var ctx = Ctx{ .mutex = sync.Mutex.init(), .cond = sync.Condition.init(), .ready = false };
    defer ctx.cond.deinit();
    defer ctx.mutex.deinit();

    var th = try thread.Thread.spawn(.{}, waiter.run, @ptrCast(&ctx));
    std_time.sleepMs(10);

    ctx.mutex.lock();
    ctx.ready = true;
    ctx.cond.signal();
    ctx.mutex.unlock();

    th.join();
    try std.testing.expect(ctx.ready);
}

test "std notify timedWait" {
    var notify = sync.Notify.init();
    defer notify.deinit();

    var th = try thread.Thread.spawn(.{}, notifyAfterDelay, @ptrCast(&notify));

    const early = notify.timedWait(5 * std.time.ns_per_ms);
    try std.testing.expect(!early);

    const later = notify.timedWait(300 * std.time.ns_per_ms);
    try std.testing.expect(later);

    th.join();
}
