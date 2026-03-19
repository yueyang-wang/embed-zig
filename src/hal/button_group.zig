//! HAL Button Group Contract
//!
//! Multiple buttons sharing one driver (e.g. ADC resistor ladder,
//! GPIO matrix). The driver handles debouncing internally; the upper
//! layer polls for events via pollEvent().
//!
//! Impl must provide:
//!   pollEvent: fn (*Impl) State
//!   stateOf:   fn (*const Impl, u8) button.State
//!   count:     fn (*const Impl) u8

const button = @import("button.zig");

pub const State = struct {
    index: u8,
    state: button.State,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl) State, &Impl.pollEvent);
        _ = @as(*const fn (*const Impl, u8) button.State, &Impl.stateOf);
        _ = @as(*const fn (*const Impl) u8, &Impl.count);
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

        pub fn stateOf(self: Self, index: u8) button.State {
            return self.driver.stateOf(index);
        }

        pub fn count(self: Self) u8 {
            return self.driver.count();
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
