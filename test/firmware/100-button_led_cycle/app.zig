const std = @import("std");

pub const LedState = struct {
    on: bool,
    r: u8,
    g: u8,
    b: u8,
};

pub const InputAction = enum {
    press_down,
    release,
    reset,
};

const Mode = enum {
    off,
    white,
    red,
    green,
};

pub const Config = struct {
    long_press_ms: u64 = 1000,
    double_click_window_ms: u64 = 300,
};

pub const App = struct {
    mode: Mode = .off,
    pressed: bool = false,
    press_start_t: u64 = 0,
    pending_short_release_t: ?u64 = null,

    pub fn init() App {
        return .{};
    }

    pub fn onInput(self: *App, cfg: Config, now_t: u64, action: InputAction) ?LedState {
        switch (action) {
            .reset => {
                self.mode = .off;
                self.pressed = false;
                self.press_start_t = 0;
                self.pending_short_release_t = null;
                return modeLed(self.mode);
            },
            .press_down => {
                if (!self.pressed) {
                    self.pressed = true;
                    self.press_start_t = now_t;
                }
                return null;
            },
            .release => {
                if (!self.pressed) return null;

                self.pressed = false;
                const press_duration = if (now_t >= self.press_start_t) now_t - self.press_start_t else 0;

                if (press_duration >= cfg.long_press_ms) {
                    self.pending_short_release_t = null;
                    self.mode = if (self.mode == .off) .white else .off;
                    return modeLed(self.mode);
                }

                if (self.pending_short_release_t) |prev_t| {
                    if (now_t <= prev_t + cfg.double_click_window_ms) {
                        self.pending_short_release_t = null;
                        self.mode = .green;
                        return modeLed(self.mode);
                    }
                }

                self.pending_short_release_t = now_t;
                self.mode = .red;
                return modeLed(self.mode);
            },
        }
    }

    fn modeLed(mode: Mode) LedState {
        return switch (mode) {
            .off => .{ .on = false, .r = 0, .g = 0, .b = 0 },
            .white => .{ .on = true, .r = 255, .g = 255, .b = 255 },
            .red => .{ .on = true, .r = 255, .g = 0, .b = 0 },
            .green => .{ .on = true, .r = 0, .g = 255, .b = 0 },
        };
    }
};

test "app supports long/single/double behavior" {
    var app = App.init();
    const cfg = Config{};

    const reset_led = app.onInput(cfg, 0, .reset) orelse return error.ExpectedResetLed;
    try std.testing.expect(!reset_led.on);

    _ = app.onInput(cfg, 100, .press_down);
    const white = app.onInput(cfg, 1200, .release) orelse return error.ExpectedWhite;
    try std.testing.expect(white.on);
    try std.testing.expectEqual(@as(u8, 255), white.r);
    try std.testing.expectEqual(@as(u8, 255), white.g);

    _ = app.onInput(cfg, 2000, .press_down);
    const red = app.onInput(cfg, 2060, .release) orelse return error.ExpectedRed;
    try std.testing.expectEqual(@as(u8, 255), red.r);
    try std.testing.expectEqual(@as(u8, 0), red.g);

    _ = app.onInput(cfg, 2300, .press_down);
    const green = app.onInput(cfg, 2360, .release) orelse return error.ExpectedGreen;
    try std.testing.expectEqual(@as(u8, 0), green.r);
    try std.testing.expectEqual(@as(u8, 255), green.g);
}
