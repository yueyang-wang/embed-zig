//! HAL SPI Bus Contract
//!
//! Full-duplex SPI master with per-device chip-select management.
//! The bus owns the physical lines (MOSI/MISO/SCLK); each logical device
//! is represented by a Device handle obtained via addDevice().
//!
//! Single write/read/transfer calls auto-manage CS (pull low before,
//! pull high after). For multi-step sequences that require CS to stay
//! low across calls, wrap them in startTransaction / endTransaction.
//!
//! Impl must provide:
//!   addDevice       : fn (*Impl, DeviceConfig) Error!DeviceHandle
//!   removeDevice    : fn (*Impl, DeviceHandle) void
//!   startTransaction: fn (*Impl, DeviceHandle) Error!void
//!   endTransaction  : fn (*Impl, DeviceHandle) void
//!   transfer        : fn (*Impl, DeviceHandle, []const u8, []u8) Error!void
//!   write           : fn (*Impl, DeviceHandle, []const u8) Error!void
//!   read            : fn (*Impl, DeviceHandle, []u8) Error!void

pub const Error = error{
    TransferFailed,
    InvalidDevice,
    Busy,
    Timeout,
    Unexpected,
};

pub const ClockPolarity = enum(u1) {
    idle_low = 0,
    idle_high = 1,
};

pub const ClockPhase = enum(u1) {
    leading_edge = 0,
    trailing_edge = 1,
};

pub const DeviceConfig = struct {
    cs_pin: i32,
    polarity: ClockPolarity = .idle_low,
    phase: ClockPhase = .leading_edge,
    clock_hz: u32 = 1_000_000,
};

pub const DeviceHandle = enum(u8) { _ };

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, DeviceConfig) Error!DeviceHandle, &Impl.addDevice);
        _ = @as(*const fn (*Impl, DeviceHandle) void, &Impl.removeDevice);
        _ = @as(*const fn (*Impl, DeviceHandle) Error!void, &Impl.startTransaction);
        _ = @as(*const fn (*Impl, DeviceHandle) void, &Impl.endTransaction);
        _ = @as(*const fn (*Impl, DeviceHandle, []const u8, []u8) Error!void, &Impl.transfer);
        _ = @as(*const fn (*Impl, DeviceHandle, []const u8) Error!void, &Impl.write);
        _ = @as(*const fn (*Impl, DeviceHandle, []u8) Error!void, &Impl.read);
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

        pub fn addDevice(self: Self, config: DeviceConfig) Error!Device {
            const handle = try self.driver.addDevice(config);
            return .{ .driver = self.driver, .handle = handle };
        }

        pub const Device = struct {
            driver: *Impl,
            handle: DeviceHandle,

            pub fn remove(self: *Device) void {
                self.driver.removeDevice(self.handle);
                self.* = undefined;
            }

            pub fn startTransaction(self: Device) Error!void {
                return self.driver.startTransaction(self.handle);
            }

            pub fn endTransaction(self: Device) void {
                self.driver.endTransaction(self.handle);
            }

            pub fn transfer(self: Device, tx: []const u8, rx: []u8) Error!void {
                return self.driver.transfer(self.handle, tx, rx);
            }

            pub fn write(self: Device, data: []const u8) Error!void {
                return self.driver.write(self.handle, data);
            }

            pub fn read(self: Device, buf: []u8) Error!void {
                return self.driver.read(self.handle, buf);
            }
        };
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
