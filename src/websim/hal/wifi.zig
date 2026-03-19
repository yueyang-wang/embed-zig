//! Websim stub — WiFi HAL (placeholder).

const wifi = @import("../../hal/wifi.zig");
const serial = @import("../../hal/serial.zig");

pub const Wifi = struct {
    pub fn connect(_: *Wifi, _: wifi.ConnectConfig) wifi.ConnectError!void { return error.Unexpected; }
    pub fn disconnect(_: *Wifi) void {}
    pub fn status(_: *const Wifi) wifi.Status { return .disconnected; }
    pub fn addEventHook(_: *Wifi, _: ?*anyopaque, _: *const fn (?*anyopaque, wifi.WifiEvent) void) void {}
    pub fn getRssi(_: *const Wifi) ?i8 { return null; }
    pub fn getMac(_: *const Wifi) ?wifi.Mac { return null; }
    pub fn getChannel(_: *const Wifi) ?u8 { return null; }
    pub fn scanStart(_: *Wifi, _: wifi.ScanConfig) wifi.ScanError!void { return error.Unexpected; }
    pub fn setPowerSave(_: *Wifi, _: wifi.PowerSaveMode) void {}
    pub fn setTxPower(_: *Wifi, _: i8) void {}
    pub fn startAp(_: *Wifi, _: wifi.ApConfig) wifi.ApError!void { return error.Unexpected; }
    pub fn stopAp(_: *Wifi) void {}
    pub fn read(_: *Wifi, _: []u8) serial.ReadError!usize { return error.WouldBlock; }
    pub fn write(_: *Wifi, _: []const u8) serial.WriteError!usize { return error.WouldBlock; }
    pub fn poll(_: *Wifi, _: serial.PollFd, _: i32) serial.PollFd { return .{}; }
};
