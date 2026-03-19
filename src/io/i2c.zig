//! HAL I2C Bus Contract
//!
//! Multi-device I2C master. Devices are addressed by 7-bit address.
//! Supports raw read/write and register-level read/write.
//!
//! Impl must provide:
//!   setClockHz: fn (*Impl, u32) Error!void
//!   clockHz   : fn (*const Impl) u32
//!   write     : fn (*Impl, Address, []const u8) Error!void
//!   read      : fn (*Impl, Address, []u8) Error!void
//!   writeRead : fn (*Impl, Address, []const u8, []u8) Error!void
//!   probe     : fn (*Impl, Address) bool

pub const Address = u7;

pub const Error = error{
    Nack,
    BusError,
    ArbitrationLost,
    Timeout,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, u32) Error!void, &Impl.setClockHz);
        _ = @as(*const fn (*const Impl) u32, &Impl.clockHz);
        _ = @as(*const fn (*Impl, Address, []const u8) Error!void, &Impl.write);
        _ = @as(*const fn (*Impl, Address, []u8) Error!void, &Impl.read);
        _ = @as(*const fn (*Impl, Address, []const u8, []u8) Error!void, &Impl.writeRead);
        _ = @as(*const fn (*Impl, Address) bool, &Impl.probe);
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

        pub fn setClockHz(self: Self, hz: u32) Error!void {
            return self.driver.setClockHz(hz);
        }

        pub fn clockHz(self: Self) u32 {
            return self.driver.clockHz();
        }

        /// Raw write — send bytes to device at `addr`.
        pub fn write(self: Self, addr: Address, data: []const u8) Error!void {
            return self.driver.write(addr, data);
        }

        /// Raw read — read bytes from device at `addr`.
        pub fn read(self: Self, addr: Address, buf: []u8) Error!void {
            return self.driver.read(addr, buf);
        }

        /// Write then read in a single I2C transaction (repeated START).
        /// Typical usage: write register address, then read register value.
        pub fn writeRead(self: Self, addr: Address, tx: []const u8, rx: []u8) Error!void {
            return self.driver.writeRead(addr, tx, rx);
        }

        /// Check if a device responds at `addr` (sends address, checks ACK).
        pub fn probe(self: Self, addr: Address) bool {
            return self.driver.probe(addr);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
