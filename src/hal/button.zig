//! HAL Single Button Contract
//!
//! A single hardware button that produces press/release events.
//! The driver handles debouncing internally; the upper layer polls
//! for events via pollEvent().
//!
//! Impl must provide:
//!   pollEvent: fn (*Impl) State
//!   state:     fn (*const Impl) State

pub const State = enum {
    press,
    release,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl) State, &Impl.pollEvent);
        _ = @as(*const fn (*const Impl) State, &Impl.state);
    }

    return struct {
        pub const seal: Seal = .{};
        driver: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .driver = driver };
        }

        pub fn deinit(self: *Self) void {
            self.driver = undefined;
        }

        pub fn pollEvent(self: Self) State {
            return self.driver.pollEvent();
        }

        pub fn state(self: Self) State {
            return self.driver.state();
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
