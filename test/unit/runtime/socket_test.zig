const module = @import("embed").runtime.socket;
const Ipv4Address = module.Ipv4Address;
const Error = module.Error;
const RecvFromResult = module.RecvFromResult;
const from = module.from;
const parseIpv4 = module.parseIpv4;

const std = @import("std");
const testing = std.testing;

test "parseIpv4" {
    const addr = parseIpv4("192.168.1.1").?;
    try std.testing.expectEqual(@as(u8, 192), addr[0]);
    try std.testing.expectEqual(@as(u8, 168), addr[1]);
    try std.testing.expectEqual(@as(u8, 1), addr[2]);
    try std.testing.expectEqual(@as(u8, 1), addr[3]);

    try std.testing.expectEqual(@as(?Ipv4Address, null), parseIpv4("invalid"));
    try std.testing.expectEqual(@as(?Ipv4Address, null), parseIpv4("256.1.1.1"));
    try std.testing.expectEqual(@as(?Ipv4Address, null), parseIpv4("1.2.3."));
    try std.testing.expectEqual(@as(?Ipv4Address, null), parseIpv4(".1.2.3"));
    try std.testing.expectEqual(@as(?Ipv4Address, null), parseIpv4("1..2.3"));
}
