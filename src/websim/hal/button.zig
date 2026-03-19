//! Websim stub — Button HAL (placeholder).

const button = @import("../../hal/button.zig");

pub const Button = struct {
    pub fn pollEvent(_: *Button) button.State { return .release; }
    pub fn state(_: *const Button) button.State { return .release; }
};
