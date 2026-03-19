//! HAL GPIO Contract
//!
//! Digital pin input/output with optional interrupt support.
//! Each pin is identified by a platform-defined Pin number.
//!
//! Impl must provide:
//!   setMode     : fn (*Impl, Pin, Mode) Error!void
//!   mode        : fn (*const Impl, Pin) Mode
//!   read        : fn (*const Impl, Pin) Level
//!   write       : fn (*Impl, Pin, Level) void
//!   toggle      : fn (*Impl, Pin) void
//!   setTrigger  : fn (*Impl, Pin, Trigger) Error!void
//!   enableIrq   : fn (*Impl, Pin) Error!void
//!   disableIrq  : fn (*Impl, Pin) void

pub const Pin = u8;

pub const Level = enum(u1) { low = 0, high = 1 };

pub const Mode = enum {
    input,
    input_pullup,
    input_pulldown,
    output,
    output_open_drain,
};

pub const Trigger = enum {
    none,
    rising,
    falling,
    both,
    level_low,
    level_high,
};

pub const Error = error{
    InvalidPin,
    Unsupported,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, Pin, Mode) Error!void, &Impl.setMode);
        _ = @as(*const fn (*const Impl, Pin) Mode, &Impl.mode);
        _ = @as(*const fn (*const Impl, Pin) Level, &Impl.read);
        _ = @as(*const fn (*Impl, Pin, Level) void, &Impl.write);
        _ = @as(*const fn (*Impl, Pin) void, &Impl.toggle);
        _ = @as(*const fn (*Impl, Pin, Trigger) Error!void, &Impl.setTrigger);
        _ = @as(*const fn (*Impl, Pin) Error!void, &Impl.enableIrq);
        _ = @as(*const fn (*Impl, Pin) void, &Impl.disableIrq);
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

        pub fn setMode(self: Self, pin: Pin, val: Mode) Error!void {
            return self.driver.setMode(pin, val);
        }

        pub fn mode(self: Self, pin: Pin) Mode {
            return self.driver.mode(pin);
        }

        pub fn read(self: Self, pin: Pin) Level {
            return self.driver.read(pin);
        }

        pub fn write(self: Self, pin: Pin, level: Level) void {
            self.driver.write(pin, level);
        }

        pub fn toggle(self: Self, pin: Pin) void {
            self.driver.toggle(pin);
        }

        pub fn setTrigger(self: Self, pin: Pin, trigger: Trigger) Error!void {
            return self.driver.setTrigger(pin, trigger);
        }

        pub fn enableIrq(self: Self, pin: Pin) Error!void {
            return self.driver.enableIrq(pin);
        }

        pub fn disableIrq(self: Self, pin: Pin) void {
            self.driver.disableIrq(pin);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
