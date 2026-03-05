const board = @import("board");
const test_firmware = @import("test_firmware");

export fn zig_esp_main() callconv(.c) void {
    test_firmware.@"100-button_led_cycle".run(board.hw, .{});
}
