//! 100-button_led_cycle firmware application.
//!
//! Button-driven LED color cycling.
//!
//! Behavior:
//!   - Long press (>=1s) release: toggle off <-> white
//!   - Single short click: switch to red
//!   - Double click (within 300ms): switch to green

const board_spec = @import("board_spec.zig");
const Color = @import("embed_zig").hal.led_strip.Color;

const long_press_ms: u64 = 1000;
const double_click_window_ms: u64 = 300;
const poll_interval_ms: u32 = 10;

const Mode = enum {
    off,
    white,
    red,
    green,

    fn color(self: Mode) Color {
        return switch (self) {
            .off => Color.black,
            .white => Color.white,
            .red => Color.red,
            .green => Color.green,
        };
    }
};

pub fn run(comptime board: type, env: anytype) void {
    _ = env;

    const Board = board_spec.Board(board);
    const log: Board.log = .{};
    const time: Board.time = .{};

    board.init() catch {
        log.err("hw init failed");
        return;
    };
    defer board.deinit();

    log.info("100-button_led_cycle started");

    var mode: Mode = .off;
    var pressed: bool = false;
    var press_start_ms: u64 = 0;
    var pending_short_release_ms: ?u64 = null;

    while (true) {
        const now_ms = time.nowMs();
        const btn_down = board.readButton();

        if (btn_down and !pressed) {
            pressed = true;
            press_start_ms = now_ms;
        } else if (!btn_down and pressed) {
            pressed = false;
            const duration = if (now_ms >= press_start_ms) now_ms - press_start_ms else 0;

            if (duration >= long_press_ms) {
                pending_short_release_ms = null;
                mode = if (mode == .off) .white else .off;
                log.info("long press -> toggle");
            } else {
                if (pending_short_release_ms) |prev_ms| {
                    if (now_ms <= prev_ms + double_click_window_ms) {
                        pending_short_release_ms = null;
                        mode = .green;
                        log.info("double click -> green");
                    } else {
                        pending_short_release_ms = now_ms;
                        mode = .red;
                        log.info("single click -> red");
                    }
                } else {
                    pending_short_release_ms = now_ms;
                    mode = .red;
                    log.info("single click -> red");
                }
            }
            board.setLed(mode.color());
        }

        time.sleepMs(poll_interval_ms);
    }
}
