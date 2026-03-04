const std = @import("std");
const runtime = @import("runtime");

pub const cancellation = @import("cancellation.zig");
pub const channel = @import("channel.zig");
pub const waitgroup = @import("wait_group.zig");
pub const timer = @import("timer.zig");
pub const reactor = @import("reactor.zig");
pub const executor = @import("executor.zig");

test {
    _ = cancellation;
    _ = channel;
    _ = waitgroup;
    _ = timer;
    _ = reactor;
    _ = executor;
}

const Ch = channel.Channel(u32, runtime.std.Mutex, runtime.std.Condition);
const Wg = waitgroup.WaitGroup(runtime.std.Mutex, runtime.std.Condition);
const Exec = executor.Executor(runtime.std.Mutex);
const React = reactor.Reactor(runtime.std.IO);

test "integration: executor tasks communicate through channel" {
    var ch = try Ch.init(std.testing.allocator, 16);
    defer ch.deinit();

    const Sender = struct {
        ch_ptr: *Ch,
        fn run(raw: ?*anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(raw orelse return));
            var i: u32 = 0;
            while (i < 10) : (i += 1) {
                self.ch_ptr.trySend(i) catch return error.ChannelFull;
            }
        }
    };

    var sender = Sender{ .ch_ptr = &ch };
    var exec = Exec.init(std.testing.allocator);
    defer exec.deinit();

    try exec.submit(.{ .func = Sender.run, .ctx = &sender });
    try exec.runAll();

    try std.testing.expectEqual(@as(usize, 1), exec.stats().completed);
    try std.testing.expectEqual(@as(usize, 10), ch.count());

    var sum: u64 = 0;
    while (!ch.isEmpty()) {
        sum += try ch.tryRecv();
    }
    try std.testing.expectEqual(@as(u64, 45), sum);
}

test "integration: cancellation aborts executor tasks and timer" {
    var cancel_src = cancellation.Source{};

    var sched = timer.Scheduler.init(std.testing.allocator);
    defer sched.deinit();

    _ = try sched.scheduleWithCallback(0, 100, null, null, &cancel_src);
    _ = try sched.scheduleWithCallback(0, 200, null, null, &cancel_src);

    const tok = cancel_src.token();

    const noop = struct {
        fn run(_: ?*anyopaque) !void {}
    }.run;

    var exec = Exec.init(std.testing.allocator);
    defer exec.deinit();

    try exec.submit(.{ .func = noop, .ctx = null, .cancel_token = tok });
    try exec.submit(.{ .func = noop, .ctx = null, .cancel_token = tok });
    try exec.submit(.{ .func = noop, .ctx = null });

    _ = cancel_src.cancel();

    try exec.runAll();
    try std.testing.expectEqual(@as(usize, 1), exec.stats().completed);
    try std.testing.expectEqual(@as(usize, 2), exec.stats().cancelled);

    var ready = std.ArrayList(timer.TimerId).empty;
    defer ready.deinit(std.testing.allocator);
    try sched.collectReady(300, &ready);
    try std.testing.expectEqual(@as(usize, 0), ready.items.len);
}

test "integration: waitgroup tracks executor task completion" {
    var wg = Wg.init();
    defer wg.deinit();
    const Counter = struct {
        var done_count: usize = 0;
        fn onAllDone(_: ?*anyopaque) void {
            done_count = 1;
        }
    };
    Counter.done_count = 0;
    wg.onComplete(Counter.onAllDone, null);
    wg.add(3);

    const TaskCtx = struct {
        wg_ptr: *Wg,
        fn run(raw: ?*anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(raw orelse return));
            self.wg_ptr.done() catch {};
        }
    };

    var ctx1 = TaskCtx{ .wg_ptr = &wg };
    var ctx2 = TaskCtx{ .wg_ptr = &wg };
    var ctx3 = TaskCtx{ .wg_ptr = &wg };

    var exec = Exec.init(std.testing.allocator);
    defer exec.deinit();

    try exec.submit(.{ .func = TaskCtx.run, .ctx = &ctx1 });
    try exec.submit(.{ .func = TaskCtx.run, .ctx = &ctx2 });
    try exec.submit(.{ .func = TaskCtx.run, .ctx = &ctx3 });

    try exec.runAll();
    try std.testing.expectEqual(@as(usize, 3), exec.stats().completed);
    try std.testing.expect(wg.isDone());
    try std.testing.expectEqual(@as(usize, 1), Counter.done_count);
}

test "integration: reactor timer drives executor task scheduling" {
    var io = try runtime.std.IO.init(std.testing.allocator);
    defer io.deinit();
    var r = React.init(&io, std.testing.allocator);
    defer r.deinit();

    const TaskState = struct {
        var timer_fired: bool = false;
        fn onTimer(_: ?*anyopaque) void {
            timer_fired = true;
        }
    };
    TaskState.timer_fired = false;

    _ = try r.scheduleTimerWithCallback(0, 50, TaskState.onTimer, null, null);

    var ready = std.ArrayList(timer.TimerId).empty;
    defer ready.deinit(std.testing.allocator);

    const events = try r.tick(50, &ready);
    try std.testing.expectEqual(@as(usize, 1), events);
    try std.testing.expect(TaskState.timer_fired);

    const noop = struct {
        fn run(_: ?*anyopaque) !void {}
    }.run;

    var exec = Exec.init(std.testing.allocator);
    defer exec.deinit();

    for (ready.items) |_| {
        try exec.submit(.{ .func = noop, .ctx = null });
    }
    try exec.runAll();
    try std.testing.expectEqual(@as(usize, 1), exec.stats().completed);
}

test "integration: channel producer cancelled mid-stream" {
    var ch = try Ch.init(std.testing.allocator, 32);
    defer ch.deinit();

    var cancel_src = cancellation.Source{};
    const tok = cancel_src.token();

    const Producer = struct {
        ch_ptr: *Ch,
        token: cancellation.Token,
        fn run(raw: ?*anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(raw orelse return));
            var i: u32 = 0;
            while (i < 100) : (i += 1) {
                if (self.token.isCancelled()) return;
                self.ch_ptr.trySend(i) catch return;
            }
        }
    };

    var producer = Producer{ .ch_ptr = &ch, .token = tok };

    var exec = Exec.init(std.testing.allocator);
    defer exec.deinit();

    ch.trySend(0) catch {};
    ch.trySend(1) catch {};
    ch.trySend(2) catch {};

    _ = cancel_src.cancel();

    try exec.submit(.{ .func = Producer.run, .ctx = &producer });
    try exec.runAll();

    try std.testing.expectEqual(@as(usize, 3), ch.count());
}
