//! Runtime RNG Contract

pub const Error = error{
    RngFailed,
};

const Seal = struct {};

/// Construct a sealed Rng wrapper from a backend Impl type.
/// Impl must provide: fill(self: *Impl, buf: []u8) Error!void
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, []u8) Error!void, &Impl.fill);
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

        pub fn fill(self: Self, buf: []u8) Error!void {
            return self.impl.fill(buf);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
