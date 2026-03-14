const std = @import("std");
const testing = std.testing;
const embed = @import("embed");
const module = embed.websim.hal.led_strip;
const Color = embed.hal.led_strip.Color;
const max_pixels = module.max_pixels;
const LedStrip = module.LedStrip;

test "websim led_strip satisfies hal contract" {
    const LedStripHal = embed.hal.led_strip.from(struct {
        pub const Driver = LedStrip;
        pub const meta = .{ .id = "led_strip.websim" };
    });

    var drv = LedStrip.init();
    var strip = LedStripHal.init(&drv);

    try std.testing.expectEqual(@as(u32, 1), strip.getPixelCount());

    strip.setPixel(0, Color.red);
    try std.testing.expectEqual(Color.red, drv.pixels[0]);
}
