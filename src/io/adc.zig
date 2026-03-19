//! HAL ADC Contract
//!
//! Analog-to-digital converter. Each channel maps to a physical analog
//! input pin. Reads return raw sample values; the caller converts to
//! voltage using the reference and resolution.
//!
//! Impl must provide:
//!   setResolution : fn (*Impl, Resolution) Error!void
//!   resolution    : fn (*const Impl) Resolution
//!   setAttenuation: fn (*Impl, Channel, Attenuation) Error!void
//!   attenuation   : fn (*const Impl, Channel) Attenuation
//!   read          : fn (*Impl, Channel) Error!u16

pub const Channel = u8;

pub const Resolution = enum(u8) {
    bits_8 = 8,
    bits_10 = 10,
    bits_12 = 12,
    bits_13 = 13,
};

pub const Attenuation = enum {
    db_0,
    db_2_5,
    db_6,
    db_11,
};

pub const Error = error{
    InvalidChannel,
    Timeout,
    Unsupported,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, Resolution) Error!void, &Impl.setResolution);
        _ = @as(*const fn (*const Impl) Resolution, &Impl.resolution);
        _ = @as(*const fn (*Impl, Channel, Attenuation) Error!void, &Impl.setAttenuation);
        _ = @as(*const fn (*const Impl, Channel) Attenuation, &Impl.attenuation);
        _ = @as(*const fn (*Impl, Channel) Error!u16, &Impl.read);
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

        pub fn setResolution(self: Self, val: Resolution) Error!void {
            return self.driver.setResolution(val);
        }

        pub fn resolution(self: Self) Resolution {
            return self.driver.resolution();
        }

        pub fn setAttenuation(self: Self, ch: Channel, val: Attenuation) Error!void {
            return self.driver.setAttenuation(ch, val);
        }

        pub fn attenuation(self: Self, ch: Channel) Attenuation {
            return self.driver.attenuation(ch);
        }

        pub fn read(self: Self, ch: Channel) Error!u16 {
            return self.driver.read(ch);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
