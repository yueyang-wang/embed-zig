const std = @import("std");

pub const CancellationError = error{
    AlreadyCancelled,
    InvalidHandle,
};

pub const CallbackFn = *const fn (?*anyopaque) void;

const CallbackEntry = struct {
    func: CallbackFn,
    ctx: ?*anyopaque,
};

pub const Source = struct {
    cancelled: bool = false,
    parent: ?*Source = null,
    children: [max_children]*Source = undefined,
    child_count: usize = 0,
    callbacks: [max_callbacks]CallbackEntry = undefined,
    callback_count: usize = 0,
    waiter_count: usize = 0,

    const max_children = 8;
    const max_callbacks = 8;

    pub fn token(self: *Source) Token {
        return .{ .source = self };
    }

    pub fn addChild(self: *Source, child: *Source) CancellationError!void {
        if (self.cancelled) {
            child.propagateCancel();
            return;
        }
        if (self.child_count >= max_children) return error.InvalidHandle;
        child.parent = self;
        self.children[self.child_count] = child;
        self.child_count += 1;
    }

    pub fn onCancel(self: *Source, func: CallbackFn, ctx: ?*anyopaque) CancellationError!void {
        if (self.cancelled) {
            func(ctx);
            return;
        }
        if (self.callback_count >= max_callbacks) return error.InvalidHandle;
        self.callbacks[self.callback_count] = .{ .func = func, .ctx = ctx };
        self.callback_count += 1;
    }

    pub fn cancel(self: *Source) bool {
        if (self.cancelled) return false;
        self.propagateCancel();
        return true;
    }

    fn propagateCancel(self: *Source) void {
        self.cancelled = true;

        var i: usize = 0;
        while (i < self.callback_count) : (i += 1) {
            self.callbacks[i].func(self.callbacks[i].ctx);
        }

        i = 0;
        while (i < self.child_count) : (i += 1) {
            if (!self.children[i].cancelled) {
                self.children[i].propagateCancel();
            }
        }
    }

    pub fn registerWaiter(self: *Source) CancellationError!WaiterHandle {
        if (self.cancelled) return error.AlreadyCancelled;
        self.waiter_count += 1;
        return .{ .source = self, .active = true };
    }
};

pub const Token = struct {
    source: *const Source,

    pub fn isCancelled(self: Token) bool {
        return self.source.cancelled;
    }
};

pub const WaiterHandle = struct {
    source: *Source,
    active: bool,

    pub fn release(self: *WaiterHandle) CancellationError!void {
        if (!self.active) return error.InvalidHandle;
        self.active = false;
        if (self.source.waiter_count > 0) self.source.waiter_count -= 1;
    }
};

test "cancellation single token observes cancel" {
    var src = Source{};
    const tok = src.token();

    try std.testing.expect(!tok.isCancelled());
    try std.testing.expect(src.cancel());
    try std.testing.expect(tok.isCancelled());
}

test "cancellation is idempotent" {
    var src = Source{};
    try std.testing.expect(src.cancel());
    try std.testing.expect(!src.cancel());
    try std.testing.expect(!src.cancel());
}

test "registering waiter after cancel is rejected" {
    var src = Source{};
    _ = src.cancel();
    try std.testing.expectError(error.AlreadyCancelled, src.registerWaiter());
}

test "parent cancel propagates to children" {
    var parent = Source{};
    var child1 = Source{};
    var child2 = Source{};

    try parent.addChild(&child1);
    try parent.addChild(&child2);

    try std.testing.expect(!child1.cancelled);
    try std.testing.expect(!child2.cancelled);

    _ = parent.cancel();

    try std.testing.expect(parent.cancelled);
    try std.testing.expect(child1.cancelled);
    try std.testing.expect(child2.cancelled);
}

test "parent cancel propagates through two levels" {
    var grandparent = Source{};
    var parent = Source{};
    var child = Source{};

    try grandparent.addChild(&parent);
    try parent.addChild(&child);

    _ = grandparent.cancel();

    try std.testing.expect(grandparent.cancelled);
    try std.testing.expect(parent.cancelled);
    try std.testing.expect(child.cancelled);
}

test "adding child to already cancelled parent cancels child immediately" {
    var parent = Source{};
    _ = parent.cancel();

    var child = Source{};
    try parent.addChild(&child);
    try std.testing.expect(child.cancelled);
}

test "onCancel callback fires on cancel" {
    const Counter = struct {
        var count: usize = 0;
        fn inc(_: ?*anyopaque) void {
            count += 1;
        }
    };
    Counter.count = 0;

    var src = Source{};
    try src.onCancel(Counter.inc, null);
    try src.onCancel(Counter.inc, null);

    _ = src.cancel();
    try std.testing.expectEqual(@as(usize, 2), Counter.count);

    // Idempotent cancel should not re-trigger.
    _ = src.cancel();
    try std.testing.expectEqual(@as(usize, 2), Counter.count);
}

test "onCancel on already cancelled source fires immediately" {
    const Counter = struct {
        var count: usize = 0;
        fn inc(_: ?*anyopaque) void {
            count += 1;
        }
    };
    Counter.count = 0;

    var src = Source{};
    _ = src.cancel();

    try src.onCancel(Counter.inc, null);
    try std.testing.expectEqual(@as(usize, 1), Counter.count);
}

test "callback deduplication: same callback registered twice fires twice" {
    const Counter = struct {
        var count: usize = 0;
        fn inc(_: ?*anyopaque) void {
            count += 1;
        }
    };
    Counter.count = 0;

    var src = Source{};
    try src.onCancel(Counter.inc, null);
    try src.onCancel(Counter.inc, null);
    _ = src.cancel();
    try std.testing.expectEqual(@as(usize, 2), Counter.count);
}

test "waiter handle release and double release" {
    var src = Source{};
    var handle = try src.registerWaiter();

    try std.testing.expect(handle.active);
    try std.testing.expectEqual(@as(usize, 1), src.waiter_count);

    try handle.release();
    try std.testing.expect(!handle.active);
    try std.testing.expectEqual(@as(usize, 0), src.waiter_count);

    try std.testing.expectError(error.InvalidHandle, handle.release());
}

test "multiple waiters register and release independently" {
    var src = Source{};
    var h1 = try src.registerWaiter();
    var h2 = try src.registerWaiter();
    var h3 = try src.registerWaiter();

    try std.testing.expectEqual(@as(usize, 3), src.waiter_count);

    try h2.release();
    try std.testing.expectEqual(@as(usize, 2), src.waiter_count);
    try h1.release();
    try std.testing.expectEqual(@as(usize, 1), src.waiter_count);
    try h3.release();
    try std.testing.expectEqual(@as(usize, 0), src.waiter_count);
}

test "max children overflow returns InvalidHandle" {
    var parent = Source{};
    var children: [Source.max_children + 1]Source = undefined;
    for (&children) |*c| c.* = Source{};

    var i: usize = 0;
    while (i < Source.max_children) : (i += 1) {
        try parent.addChild(&children[i]);
    }
    try std.testing.expectError(error.InvalidHandle, parent.addChild(&children[Source.max_children]));
}

test "max callbacks overflow returns InvalidHandle" {
    var src = Source{};
    const noop = struct {
        fn cb(_: ?*anyopaque) void {}
    }.cb;

    var i: usize = 0;
    while (i < Source.max_callbacks) : (i += 1) {
        try src.onCancel(noop, null);
    }
    try std.testing.expectError(error.InvalidHandle, src.onCancel(noop, null));
}

test "callback receives context pointer" {
    const Ctx = struct {
        value: usize,
    };
    const handler = struct {
        fn cb(raw: ?*anyopaque) void {
            const ctx: *Ctx = @ptrCast(@alignCast(raw orelse return));
            ctx.value = 42;
        }
    }.cb;

    var ctx = Ctx{ .value = 0 };
    var src = Source{};
    try src.onCancel(handler, &ctx);
    _ = src.cancel();
    try std.testing.expectEqual(@as(usize, 42), ctx.value);
}

test "child cancel does not propagate to parent" {
    var parent = Source{};
    var child = Source{};
    try parent.addChild(&child);

    _ = child.cancel();
    try std.testing.expect(child.cancelled);
    try std.testing.expect(!parent.cancelled);
}

test "cancel fires callbacks before propagating to children" {
    const Tracker = struct {
        var order: [3]u8 = .{ 0, 0, 0 };
        var idx: usize = 0;
        fn cbParent(_: ?*anyopaque) void {
            order[idx] = 'P';
            idx += 1;
        }
    };
    Tracker.idx = 0;
    Tracker.order = .{ 0, 0, 0 };

    var parent = Source{};
    var child = Source{};
    try parent.addChild(&child);
    try parent.onCancel(Tracker.cbParent, null);

    _ = parent.cancel();
    try std.testing.expect(parent.cancelled);
    try std.testing.expect(child.cancelled);
    try std.testing.expectEqual(@as(u8, 'P'), Tracker.order[0]);
}

test "token from uncancelled source reports not cancelled" {
    var src = Source{};
    const tok = src.token();
    try std.testing.expect(!tok.isCancelled());
}

test "deeply nested three-level cancellation propagates" {
    var root_src = Source{};
    var mid = Source{};
    var leaf = Source{};

    try root_src.addChild(&mid);
    try mid.addChild(&leaf);

    const tok = leaf.token();
    try std.testing.expect(!tok.isCancelled());

    _ = root_src.cancel();
    try std.testing.expect(tok.isCancelled());
    try std.testing.expect(mid.cancelled);
    try std.testing.expect(leaf.cancelled);
}
