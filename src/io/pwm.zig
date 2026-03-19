//! HAL PWM Contract
//!
//! Pulse width modulation output. Each channel drives one pin with a
//! configurable frequency and duty cycle.
//!
//! Duty is expressed as a u16 where 0 = 0% and 65535 = 100%.
//!
//! Impl must provide:
//!   setFrequency : fn (*Impl, Channel, u32) Error!void
//!   frequency    : fn (*const Impl, Channel) u32
//!   setDuty      : fn (*Impl, Channel, u16) Error!void
//!   duty         : fn (*const Impl, Channel) u16
//!   setPolarity  : fn (*Impl, Channel, Polarity) Error!void
//!   polarity     : fn (*const Impl, Channel) Polarity
//!   enable       : fn (*Impl, Channel) Error!void
//!   disable      : fn (*Impl, Channel) void

pub const Channel = u8;

pub const Polarity = enum { normal, inverted };

pub const Error = error{
    InvalidChannel,
    InvalidFrequency,
    Unsupported,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, Channel, u32) Error!void, &Impl.setFrequency);
        _ = @as(*const fn (*const Impl, Channel) u32, &Impl.frequency);
        _ = @as(*const fn (*Impl, Channel, u16) Error!void, &Impl.setDuty);
        _ = @as(*const fn (*const Impl, Channel) u16, &Impl.duty);
        _ = @as(*const fn (*Impl, Channel, Polarity) Error!void, &Impl.setPolarity);
        _ = @as(*const fn (*const Impl, Channel) Polarity, &Impl.polarity);
        _ = @as(*const fn (*Impl, Channel) Error!void, &Impl.enable);
        _ = @as(*const fn (*Impl, Channel) void, &Impl.disable);
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

        pub fn setFrequency(self: Self, ch: Channel, hz: u32) Error!void {
            return self.driver.setFrequency(ch, hz);
        }

        pub fn frequency(self: Self, ch: Channel) u32 {
            return self.driver.frequency(ch);
        }

        /// Set duty cycle. 0 = 0%, 65535 = 100%.
        pub fn setDuty(self: Self, ch: Channel, val: u16) Error!void {
            return self.driver.setDuty(ch, val);
        }

        pub fn duty(self: Self, ch: Channel) u16 {
            return self.driver.duty(ch);
        }

        pub fn setPolarity(self: Self, ch: Channel, val: Polarity) Error!void {
            return self.driver.setPolarity(ch, val);
        }

        pub fn polarity(self: Self, ch: Channel) Polarity {
            return self.driver.polarity(ch);
        }

        pub fn enable(self: Self, ch: Channel) Error!void {
            return self.driver.enable(ch);
        }

        pub fn disable(self: Self, ch: Channel) void {
            self.driver.disable(ch);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
