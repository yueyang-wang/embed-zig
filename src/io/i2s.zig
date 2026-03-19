//! HAL I2S Bus Contract
//!
//! Synchronous audio serial bus (BCLK / WS / DATA).
//! Read captures audio frames (DATA_IN), write plays audio frames (DATA_OUT).
//! A frame is one WS period containing all slots. The frame size in bytes
//! is determined by bits_per_sample × slot_count.
//!
//! TDM is handled at the codec level (via I2C configuration). The MCU side
//! controls slot count indirectly through bits_per_sample and slot_count,
//! which together determine the BCLK frequency:
//!   BCLK = sample_rate × bits_per_sample × slot_count
//!
//! Impl must provide:
//!   setRole         : fn (*Impl, Role) Error!void
//!   role            : fn (*const Impl) Role
//!   setSampleRate   : fn (*Impl, u32) Error!void
//!   sampleRate      : fn (*const Impl) u32
//!   setBitsPerSample: fn (*Impl, BitsPerSample) Error!void
//!   bitsPerSample   : fn (*const Impl) BitsPerSample
//!   setSlotCount    : fn (*Impl, SlotCount) Error!void
//!   slotCount       : fn (*const Impl) SlotCount
//!   setFormat       : fn (*Impl, Format) Error!void
//!   format          : fn (*const Impl) Format
//!   read            : fn (*Impl, []u8) Error!usize
//!   write           : fn (*Impl, []const u8) Error!usize

pub const Error = error{
    Busy,
    Timeout,
    Overflow,
    Underrun,
    Unexpected,
};

pub const Role = enum { master, slave };

pub const BitsPerSample = enum(u8) {
    bits_8 = 8,
    bits_16 = 16,
    bits_24 = 24,
    bits_32 = 32,
};

pub const SlotCount = enum(u8) {
    slots_1 = 1,
    slots_2 = 2,
    slots_4 = 4,
    slots_6 = 6,
    slots_8 = 8,
    slots_16 = 16,
};

pub const Format = enum {
    philips,
    msb,
    pcm_short,
    pcm_long,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, Role) Error!void, &Impl.setRole);
        _ = @as(*const fn (*const Impl) Role, &Impl.role);
        _ = @as(*const fn (*Impl, u32) Error!void, &Impl.setSampleRate);
        _ = @as(*const fn (*const Impl) u32, &Impl.sampleRate);
        _ = @as(*const fn (*Impl, BitsPerSample) Error!void, &Impl.setBitsPerSample);
        _ = @as(*const fn (*const Impl) BitsPerSample, &Impl.bitsPerSample);
        _ = @as(*const fn (*Impl, SlotCount) Error!void, &Impl.setSlotCount);
        _ = @as(*const fn (*const Impl) SlotCount, &Impl.slotCount);
        _ = @as(*const fn (*Impl, Format) Error!void, &Impl.setFormat);
        _ = @as(*const fn (*const Impl) Format, &Impl.format);
        _ = @as(*const fn (*Impl, []u8) Error!usize, &Impl.read);
        _ = @as(*const fn (*Impl, []const u8) Error!usize, &Impl.write);
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

        pub fn setRole(self: Self, val: Role) Error!void {
            return self.driver.setRole(val);
        }

        pub fn role(self: Self) Role {
            return self.driver.role();
        }

        pub fn setSampleRate(self: Self, hz: u32) Error!void {
            return self.driver.setSampleRate(hz);
        }

        pub fn sampleRate(self: Self) u32 {
            return self.driver.sampleRate();
        }

        pub fn setBitsPerSample(self: Self, bits: BitsPerSample) Error!void {
            return self.driver.setBitsPerSample(bits);
        }

        pub fn bitsPerSample(self: Self) BitsPerSample {
            return self.driver.bitsPerSample();
        }

        pub fn setSlotCount(self: Self, count: SlotCount) Error!void {
            return self.driver.setSlotCount(count);
        }

        pub fn slotCount(self: Self) SlotCount {
            return self.driver.slotCount();
        }

        pub fn setFormat(self: Self, fmt: Format) Error!void {
            return self.driver.setFormat(fmt);
        }

        pub fn format(self: Self) Format {
            return self.driver.format();
        }

        /// Bytes per frame: (bits_per_sample / 8) × slot_count.
        pub fn frameSize(self: Self) u16 {
            const bps: u16 = @intFromEnum(self.bitsPerSample());
            const slots: u16 = @intFromEnum(self.slotCount());
            return (bps / 8) * slots;
        }

        pub fn read(self: Self, buf: []u8) Error!usize {
            return self.driver.read(buf);
        }

        pub fn write(self: Self, data: []const u8) Error!usize {
            return self.driver.write(data);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
