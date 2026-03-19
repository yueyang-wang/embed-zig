//! Websim stub — LED HAL (placeholder).

pub const Led = struct {
    brightness: u8 = 0,

    pub fn setBrightness(self: *Led, b: u8) void { self.brightness = b; }
    pub fn getBrightness(self: *const Led) u8 { return self.brightness; }
    pub fn fade(_: *Led, _: u8, _: u32) void {}
};
