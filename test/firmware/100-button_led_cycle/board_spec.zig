//! Board specification for 100-button_led_cycle.
//!
//! Required from `hw`:
//!   - name: []const u8
//!   - log:  struct { debug, info, warn, err }
//!   - time: struct { nowMs, sleepMs }
//!   - readButton() bool          — true when button is pressed
//!   - setLed(Color) void         — apply color to the LED

const embed_zig = @import("embed_zig");
const runtime = embed_zig.runtime;

pub fn Board(comptime hw: type) type {
    return struct {
        pub const meta = .{ .id = hw.name };
        pub const log = runtime.log.from(hw.log);
        pub const time = runtime.time.from(hw.time);
    };
}
