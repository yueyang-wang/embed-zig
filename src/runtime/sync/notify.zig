//! Runtime Notify Contract — sealed wrapper over a backend Impl.

const Seal = struct {};

/// Construct a sealed Notify wrapper from a backend Impl type.
/// Impl must provide: signal, wait, timedWait.
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl) void, &Impl.signal);
        _ = @as(*const fn (*Impl) void, &Impl.wait);
        _ = @as(*const fn (*Impl, u64) bool, &Impl.timedWait);
    }

    return struct {
        pub const seal: Seal = .{};
        impl: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .impl = driver };
        }

        pub fn deinit(self: *Self) void {
            self.impl = undefined;
        }

        pub fn signal(self: Self) void {
            self.impl.signal();
        }

        pub fn wait(self: Self) void {
            self.impl.wait();
        }

        pub fn timedWait(self: Self, timeout_ns: u64) bool {
            return self.impl.timedWait(timeout_ns);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
