//! Runtime System Contract

/// Fixed error set for system queries.
pub const Error = error{
    Unsupported,
    QueryFailed,
};

const Seal = struct {};

/// Construct a sealed System wrapper from a backend Impl type.
/// Impl must provide: getCpuCount(self: *const Impl) Error!usize
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*const Impl) Error!usize, &Impl.getCpuCount);
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

        pub fn getCpuCount(self: Self) Error!usize {
            return self.impl.getCpuCount();
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
