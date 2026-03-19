//! Websim stub — LED Group HAL (placeholder).

const led_group = @import("../../hal/led_group.zig");

pub const LedGroup = struct {
    pub fn setPixel(_: *LedGroup, _: u32, _: led_group.Color) void {}
    pub fn getPixel(_: *const LedGroup, _: u32) led_group.Color { return .{}; }
    pub fn count(_: *const LedGroup) u32 { return 0; }
    pub fn refresh(_: *LedGroup) void {}
};
