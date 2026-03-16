//! Runtime Sync Contracts — Mutex / Condition / Notify

/// Shared contract data types.
pub const types = struct {
    pub const TimedWaitResult = enum {
        signaled,
        timed_out,
    };
};

const MutexSeal = struct {};
const ConditionSeal = struct {};
const NotifySeal = struct {};

/// Construct a sealed Mutex wrapper from a backend Impl type.
/// Impl must provide: init, deinit, lock, unlock.
pub fn Mutex(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn () Impl, &Impl.init);
        _ = @as(*const fn (*Impl) void, &Impl.deinit);
        _ = @as(*const fn (*Impl) void, &Impl.lock);
        _ = @as(*const fn (*Impl) void, &Impl.unlock);
    }

    const MutexType = struct {
        impl: Impl,
        pub const seal: MutexSeal = .{};
        pub const BackendType = Impl;

        pub fn init() @This() {
            return .{ .impl = Impl.init() };
        }

        pub fn deinit(self: *@This()) void {
            self.impl.deinit();
        }

        pub fn lock(self: *@This()) void {
            self.impl.lock();
        }

        pub fn unlock(self: *@This()) void {
            self.impl.unlock();
        }
    };
    return isMutex(MutexType);
}

/// Validate that Impl satisfies the sealed Mutex contract.
pub fn isMutex(comptime Impl: type) type {
    comptime {
        if (!@hasDecl(Impl, "seal") or @TypeOf(Impl.seal) != MutexSeal) {
            @compileError("Impl must have pub const seal: sync.MutexSeal — use sync.Mutex(Backend) to construct");
        }
    }
    return Impl;
}

/// Explicit binding form for Condition with a given raw backend Mutex type.
pub fn Condition(comptime Impl: type, comptime MutexImpl: type) type {
    const SealedMutex = Mutex(MutexImpl);

    comptime {
        if (@hasDecl(Impl, "MutexType") and Impl.MutexType != MutexImpl) {
            @compileError("Condition.MutexType does not match provided MutexImpl");
        }

        _ = @as(*const fn () Impl, &Impl.init);
        _ = @as(*const fn (*Impl) void, &Impl.deinit);
        _ = @as(*const fn (*Impl, *MutexImpl) void, &Impl.wait);
        _ = @as(*const fn (*Impl) void, &Impl.signal);
        _ = @as(*const fn (*Impl) void, &Impl.broadcast);
        _ = @as(*const fn (*Impl, *MutexImpl, u64) types.TimedWaitResult, &Impl.timedWait);
    }

    const ConditionType = struct {
        impl: Impl,
        pub const seal: ConditionSeal = .{};
        pub const MutexType = SealedMutex;
        pub const BackendType = Impl;

        pub fn init() @This() {
            return .{ .impl = Impl.init() };
        }

        pub fn deinit(self: *@This()) void {
            self.impl.deinit();
        }

        pub fn wait(self: *@This(), mutex: *SealedMutex) void {
            self.impl.wait(&mutex.impl);
        }

        pub fn signal(self: *@This()) void {
            self.impl.signal();
        }

        pub fn broadcast(self: *@This()) void {
            self.impl.broadcast();
        }

        pub fn timedWait(self: *@This(), mutex: *SealedMutex, timeout_ns: u64) types.TimedWaitResult {
            return self.impl.timedWait(&mutex.impl, timeout_ns);
        }
    };
    return isCondition(ConditionType);
}

/// Validate that Impl satisfies the sealed Condition contract.
pub fn isCondition(comptime Impl: type) type {
    comptime {
        if (!@hasDecl(Impl, "seal") or @TypeOf(Impl.seal) != ConditionSeal) {
            @compileError("Impl must have pub const seal: sync.ConditionSeal — use sync.Condition(Backend) to construct");
        }
    }
    return Impl;
}

/// Construct a sealed Notify wrapper from a backend Impl type.
/// Impl must provide: init, deinit, signal, wait, timedWait.
pub fn Notify(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn () Impl, &Impl.init);
        _ = @as(*const fn (*Impl) void, &Impl.deinit);
        _ = @as(*const fn (*Impl) void, &Impl.signal);
        _ = @as(*const fn (*Impl) void, &Impl.wait);
        _ = @as(*const fn (*Impl, u64) bool, &Impl.timedWait);
    }

    const NotifyType = struct {
        impl: Impl,
        pub const seal: NotifySeal = .{};
        pub const BackendType = Impl;

        pub fn init() @This() {
            return .{ .impl = Impl.init() };
        }

        pub fn deinit(self: *@This()) void {
            self.impl.deinit();
        }

        pub fn signal(self: *@This()) void {
            self.impl.signal();
        }

        pub fn wait(self: *@This()) void {
            self.impl.wait();
        }

        pub fn timedWait(self: *@This(), timeout_ns: u64) bool {
            return self.impl.timedWait(timeout_ns);
        }
    };
    return isNotify(NotifyType);
}

/// Validate that Impl satisfies the sealed Notify contract.
pub fn isNotify(comptime Impl: type) type {
    comptime {
        if (!@hasDecl(Impl, "seal") or @TypeOf(Impl.seal) != NotifySeal) {
            @compileError("Impl must have pub const seal: sync.NotifySeal — use sync.Notify(Backend) to construct");
        }
    }
    return Impl;
}
