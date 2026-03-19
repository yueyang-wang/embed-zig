const std = @import("std");

pub fn update(_: *@This(), _: []const u8) void {}

pub fn sha256(_: *@This(), data: []const u8, out: *[32]u8) void {
    std.crypto.hash.sha2.Sha256.hash(data, out, .{});
}

pub fn sha384(_: *@This(), data: []const u8, out: *[48]u8) void {
    std.crypto.hash.sha2.Sha384.hash(data, out, .{});
}

pub fn sha512(_: *@This(), data: []const u8, out: *[64]u8) void {
    std.crypto.hash.sha2.Sha512.hash(data, out, .{});
}
