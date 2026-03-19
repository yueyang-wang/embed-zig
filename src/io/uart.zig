//! HAL UART Contract
//!
//! Asynchronous byte-stream transport over UART hardware.
//!
//! Impl must provide:
//!   setBaudRate : fn (*Impl, u32) Error!void
//!   baudRate    : fn (*const Impl) u32
//!   setDataBits : fn (*Impl, DataBits) Error!void
//!   dataBits    : fn (*const Impl) DataBits
//!   setParity   : fn (*Impl, Parity) Error!void
//!   parity      : fn (*const Impl) Parity
//!   setStopBits : fn (*Impl, StopBits) Error!void
//!   stopBits    : fn (*const Impl) StopBits
//!   read        : fn (*Impl, []u8) Error!usize
//!   write       : fn (*Impl, []const u8) Error!usize
//!   poll        : fn (*Impl, PollFd, i32) PollFd

pub const Error = error{
    WouldBlock,
    FramingError,
    ParityError,
    Overrun,
    Timeout,
    Unexpected,
};

pub const DataBits = enum { seven, eight };

pub const Parity = enum { none, even, odd };

pub const StopBits = enum { one, two };

pub const PollFd = struct {
    readable: bool = false,
    writable: bool = false,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, u32) Error!void, &Impl.setBaudRate);
        _ = @as(*const fn (*const Impl) u32, &Impl.baudRate);
        _ = @as(*const fn (*Impl, DataBits) Error!void, &Impl.setDataBits);
        _ = @as(*const fn (*const Impl) DataBits, &Impl.dataBits);
        _ = @as(*const fn (*Impl, Parity) Error!void, &Impl.setParity);
        _ = @as(*const fn (*const Impl) Parity, &Impl.parity);
        _ = @as(*const fn (*Impl, StopBits) Error!void, &Impl.setStopBits);
        _ = @as(*const fn (*const Impl) StopBits, &Impl.stopBits);
        _ = @as(*const fn (*Impl, []u8) Error!usize, &Impl.read);
        _ = @as(*const fn (*Impl, []const u8) Error!usize, &Impl.write);
        _ = @as(*const fn (*Impl, PollFd, i32) PollFd, &Impl.poll);
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

        pub fn setBaudRate(self: Self, baud_rate: u32) Error!void {
            return self.driver.setBaudRate(baud_rate);
        }

        pub fn baudRate(self: Self) u32 {
            return self.driver.baudRate();
        }

        pub fn setDataBits(self: Self, data_bits: DataBits) Error!void {
            return self.driver.setDataBits(data_bits);
        }

        pub fn dataBits(self: Self) DataBits {
            return self.driver.dataBits();
        }

        pub fn setParity(self: Self, val: Parity) Error!void {
            return self.driver.setParity(val);
        }

        pub fn parity(self: Self) Parity {
            return self.driver.parity();
        }

        pub fn setStopBits(self: Self, stop_bits: StopBits) Error!void {
            return self.driver.setStopBits(stop_bits);
        }

        pub fn stopBits(self: Self) StopBits {
            return self.driver.stopBits();
        }

        pub fn read(self: Self, buf: []u8) Error!usize {
            return self.driver.read(buf);
        }

        pub fn write(self: Self, data: []const u8) Error!usize {
            return self.driver.write(data);
        }

        pub fn poll(self: Self, request: PollFd, timeout_ms: i32) PollFd {
            return self.driver.poll(request, timeout_ms);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
