const std = @import("std");

pub fn sha256(_: *@This(), out: *[32]u8, msg: []const u8, key: []const u8) void {
    std.crypto.auth.hmac.sha2.HmacSha256.create(out, msg, key);
}

pub fn sha384(_: *@This(), out: *[48]u8, msg: []const u8, key: []const u8) void {
    std.crypto.auth.hmac.sha2.HmacSha384.create(out, msg, key);
}

pub fn sha512(_: *@This(), out: *[64]u8, msg: []const u8, key: []const u8) void {
    std.crypto.auth.hmac.sha2.HmacSha512.create(out, msg, key);
}
