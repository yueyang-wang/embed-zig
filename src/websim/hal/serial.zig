//! Websim stub — Serial HAL (placeholder).

const serial = @import("../../hal/serial.zig");

pub const Serial = struct {
    pub fn read(_: *Serial, _: []u8) serial.ReadError!usize { return error.WouldBlock; }
    pub fn write(_: *Serial, _: []const u8) serial.WriteError!usize { return error.WouldBlock; }
    pub fn poll(_: *Serial, _: serial.PollFd, _: i32) serial.PollFd { return .{}; }
};
