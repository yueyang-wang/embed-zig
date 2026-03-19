//! Runtime Condition Contract — sealed wrapper over a backend Impl.

const mutex_mod = @import("mutex.zig");

pub const TimedWaitResult = enum {
    signaled,
    timed_out,
};

const Seal = struct {};

/// Construct a sealed Condition wrapper from a backend Impl and raw Mutex type.
/// Impl must provide: wait, signal, broadcast, timedWait.
pub fn Make(comptime Impl: type, comptime MutexImpl: type) type {
    const SealedMutex = mutex_mod.Make(MutexImpl);

    comptime {
        if (@hasDecl(Impl, "MutexType") and Impl.MutexType != MutexImpl) {
            @compileError("Condition.MutexType does not match provided MutexImpl");
        }

        _ = @as(*const fn (*Impl, *MutexImpl) void, &Impl.wait);
        _ = @as(*const fn (*Impl) void, &Impl.signal);
        _ = @as(*const fn (*Impl) void, &Impl.broadcast);
        _ = @as(*const fn (*Impl, *MutexImpl, u64) TimedWaitResult, &Impl.timedWait);
    }

    return struct {
        pub const seal: Seal = .{};
        pub const MutexType = SealedMutex;
        impl: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .impl = driver };
        }

        pub fn deinit(self: *Self) void {
            self.impl = undefined;
        }

        pub fn wait(self: Self, mutex: *SealedMutex) void {
            self.impl.wait(mutex.impl);
        }

        pub fn signal(self: Self) void {
            self.impl.signal();
        }

        pub fn broadcast(self: Self) void {
            self.impl.broadcast();
        }

        pub fn timedWait(self: Self, mutex: *SealedMutex, timeout_ns: u64) TimedWaitResult {
            return self.impl.timedWait(mutex.impl, timeout_ns);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
