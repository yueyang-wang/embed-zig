//! Runtime Mutex Contract — sealed wrapper over a backend Impl.

const Seal = struct {};

/// Construct a sealed Mutex wrapper from a backend Impl type.
/// Impl must provide: lock, unlock.
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl) void, &Impl.lock);
        _ = @as(*const fn (*Impl) void, &Impl.unlock);
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

        pub fn lock(self: Self) void {
            self.impl.lock();
        }

        pub fn unlock(self: Self) void {
            self.impl.unlock();
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
