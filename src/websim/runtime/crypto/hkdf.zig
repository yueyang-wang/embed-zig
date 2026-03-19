const std = @import("std");

const HkdfSha256 = std.crypto.kdf.hkdf.HkdfSha256;
const HkdfSha384 = std.crypto.kdf.hkdf.Hkdf(std.crypto.auth.hmac.sha2.HmacSha384);

pub fn sha256Extract(_: *@This(), salt: ?[]const u8, ikm: []const u8, out: *[32]u8) void {
    out.* = HkdfSha256.extract(salt orelse &[_]u8{}, ikm);
}

pub fn sha256Expand(_: *@This(), prk: *const [32]u8, ctx: []const u8, out: []u8) void {
    HkdfSha256.expand(out, ctx, prk.*);
}

pub fn sha384Extract(_: *@This(), salt: ?[]const u8, ikm: []const u8, out: *[48]u8) void {
    out.* = HkdfSha384.extract(salt orelse &[_]u8{}, ikm);
}

pub fn sha384Expand(_: *@This(), prk: *const [48]u8, ctx: []const u8, out: []u8) void {
    HkdfSha384.expand(out, ctx, prk.*);
}
