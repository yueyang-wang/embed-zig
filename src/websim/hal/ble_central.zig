//! Websim stub — BLE Central HAL (placeholder).

const ble_central = @import("../../hal/ble_central.zig");

pub const BleCentral = struct {
    pub fn startScanning(_: *BleCentral, _: ble_central.ScanConfig) ble_central.ScanError!void { return error.Unexpected; }
    pub fn stopScanning(_: *BleCentral) void {}
    pub fn connect(_: *BleCentral, _: ble_central.BdAddr, _: ble_central.AddrType, _: ble_central.ConnParams) ble_central.ConnectError!void { return error.Unexpected; }
    pub fn disconnect(_: *BleCentral, _: u16) void {}
    pub fn discoverServices(_: *BleCentral, _: u16, _: []ble_central.DiscoveredService) ble_central.GattError!usize { return error.Unexpected; }
    pub fn discoverChars(_: *BleCentral, _: u16, _: u16, _: u16, _: []ble_central.DiscoveredChar) ble_central.GattError!usize { return error.Unexpected; }
    pub fn gattRead(_: *BleCentral, _: u16, _: u16, _: []u8) ble_central.GattError!usize { return error.Unexpected; }
    pub fn gattWrite(_: *BleCentral, _: u16, _: u16, _: []const u8) ble_central.GattError!void { return error.Unexpected; }
    pub fn gattWriteCmd(_: *BleCentral, _: u16, _: u16, _: []const u8) ble_central.GattError!void { return error.Unexpected; }
    pub fn subscribe(_: *BleCentral, _: u16, _: u16) ble_central.GattError!void { return error.Unexpected; }
    pub fn unsubscribe(_: *BleCentral, _: u16, _: u16) ble_central.GattError!void { return error.Unexpected; }
    pub fn getState(_: *const BleCentral) ble_central.State { return .idle; }
    pub fn addEventHook(_: *BleCentral, _: ?*anyopaque, _: *const fn (?*anyopaque, ble_central.CentralEvent) void) void {}
    pub fn getAddr(_: *const BleCentral) ?ble_central.BdAddr { return null; }
};
