//! Runtime Time Contract

const Seal = struct {};

/// Construct a Time wrapper from an Impl type.
/// Impl must provide:
///   pub fn nowMs(*const Impl) u64
///   pub fn sleepMs(*Impl, u32) void
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*const Impl) u64, &Impl.nowMs);
        _ = @as(*const fn (*Impl, u32) void, &Impl.sleepMs);
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

        pub fn nowMs(self: Self) u64 {
            return self.impl.nowMs();
        }

        pub fn sleepMs(self: Self, ms: u32) void {
            self.impl.sleepMs(ms);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
