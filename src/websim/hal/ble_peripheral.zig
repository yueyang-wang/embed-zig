//! Websim stub — BLE Peripheral HAL (placeholder).

const ble_peripheral = @import("../../hal/ble_peripheral.zig");

pub const BlePeripheral = struct {
    pub fn startAdvertising(_: *BlePeripheral, _: ble_peripheral.AdvConfig) ble_peripheral.AdvError!void { return error.Unexpected; }
    pub fn stopAdvertising(_: *BlePeripheral) void {}
    pub fn handle(_: *BlePeripheral, _: u16, _: u16, _: ble_peripheral.HandlerFn, _: ?*anyopaque) void {}
    pub fn notify(_: *BlePeripheral, _: u16, _: u16, _: []const u8) ble_peripheral.GattError!void { return error.Unexpected; }
    pub fn indicate(_: *BlePeripheral, _: u16, _: u16, _: []const u8) ble_peripheral.GattError!void { return error.Unexpected; }
    pub fn disconnect(_: *BlePeripheral, _: u16) void {}
    pub fn getState(_: *const BlePeripheral) ble_peripheral.State { return .idle; }
    pub fn addEventHook(_: *BlePeripheral, _: ?*anyopaque, _: *const fn (?*anyopaque, ble_peripheral.PeripheralEvent) void) void {}
    pub fn getAddr(_: *const BlePeripheral) ?ble_peripheral.BdAddr { return null; }
};
