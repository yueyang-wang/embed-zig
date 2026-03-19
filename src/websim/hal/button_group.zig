//! Websim stub — ButtonGroup HAL (placeholder).

const button = @import("../../hal/button.zig");
const button_group = @import("../../hal/button_group.zig");

pub const ButtonGroup = struct {
    pub fn pollEvent(_: *ButtonGroup) button_group.State { return .{ .index = 0, .state = .release }; }
    pub fn stateOf(_: *const ButtonGroup, _: u8) button.State { return .release; }
    pub fn count(_: *const ButtonGroup) u8 { return 0; }
};
