const board = @import("board");
const test_firmware = @import("test_firmware");

export fn zig_esp_main() callconv(.c) void {
    test_firmware.@"101-hello_world".run(board.hw, .{});
}
