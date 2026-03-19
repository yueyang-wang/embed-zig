//! Websim stub — Modem HAL (placeholder).

const modem = @import("../../hal/modem.zig");
const serial = @import("../../hal/serial.zig");

pub const Modem = struct {
    pub fn getImei(_: *const Modem, _: []u8) modem.InfoError!usize { return error.NotAvailable; }
    pub fn getModel(_: *const Modem, _: []u8) modem.InfoError!usize { return error.NotAvailable; }
    pub fn getFirmwareVersion(_: *const Modem, _: []u8) modem.InfoError!usize { return error.NotAvailable; }
    pub fn getSimStatus(_: *const Modem) modem.SimStatus { return .not_inserted; }
    pub fn getImsi(_: *const Modem, _: []u8) modem.InfoError!usize { return error.NotAvailable; }
    pub fn getIccid(_: *const Modem, _: []u8) modem.InfoError!usize { return error.NotAvailable; }
    pub fn unlockPin(_: *Modem, _: []const u8) modem.PinError!void { return error.Unexpected; }
    pub fn getRegStatus(_: *const Modem) modem.RegStatus { return .not_registered; }
    pub fn getNetworkType(_: *const Modem) ?modem.NetworkType { return null; }
    pub fn getOperator(_: *const Modem, _: []u8) modem.InfoError!usize { return error.NotAvailable; }
    pub fn getRssi(_: *const Modem) ?i8 { return null; }
    pub fn setNetworkMode(_: *Modem, _: modem.NetworkMode) void {}
    pub fn getNetworkMode(_: *const Modem) modem.NetworkMode { return .auto; }
    pub fn setApn(_: *Modem, _: modem.ApnConfig) void {}
    pub fn activate(_: *Modem, _: u8) modem.ConnectError!void { return error.Unexpected; }
    pub fn deactivate(_: *Modem, _: u8) void {}
    pub fn getDataStatus(_: *const Modem) modem.DataStatus { return .disconnected; }
    pub fn sendSms(_: *Modem, _: []const u8, _: []const u8) modem.SmsError!void { return error.Unexpected; }
    pub fn setPowerMode(_: *Modem, _: modem.PowerMode) void {}
    pub fn getPowerMode(_: *const Modem) modem.PowerMode { return .full; }
    pub fn setSleep(_: *Modem, _: modem.SleepConfig) void {}
    pub fn reset(_: *Modem) void {}
    pub fn addEventHook(_: *Modem, _: ?*anyopaque, _: *const fn (?*anyopaque, modem.ModemEvent) void) void {}
    pub fn read(_: *Modem, _: []u8) serial.ReadError!usize { return error.WouldBlock; }
    pub fn write(_: *Modem, _: []const u8) serial.WriteError!usize { return error.WouldBlock; }
    pub fn poll(_: *Modem, _: serial.PollFd, _: i32) serial.PollFd { return .{}; }
};
