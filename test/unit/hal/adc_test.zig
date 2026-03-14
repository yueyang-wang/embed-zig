const module = @import("embed").hal.adc;
const Error = module.Error;
const Resolution = module.Resolution;
const Config = module.Config;
const is = module.is;
const from = module.from;
const hal_marker = module.hal_marker;

const std = @import("std");
const testing = std.testing;

test "adc wrapper" {
    const Mock = struct {
        pub fn read(_: *@This(), channel: u8) Error!u16 {
            return 100 + channel;
        }
        pub fn readMv(self: *@This(), channel: u8) Error!u16 {
            const raw = try self.read(channel);
            return @intCast((@as(u32, raw) * 3300) / 4095);
        }
    };

    const Adc = from(struct {
        pub const Driver = Mock;
        pub const meta = .{ .id = "adc.test" };
        pub const config = Config{ .resolution = .bits_12, .vref_mv = 3300 };
    });

    var d = Mock{};
    var adc = Adc.init(&d);
    try std.testing.expectEqual(@as(u16, 101), try adc.read(1));
    try std.testing.expect((try adc.readMv(0)) > 0);
}
