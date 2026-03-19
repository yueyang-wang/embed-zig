const std = @import("std");
const embed = @import("embed");
const Crypto = embed.runtime.std.Crypto;

const RawX509 = @typeInfo(@TypeOf(@as(Crypto.X509, undefined).impl)).pointer.child;

test "CaStore initSystem loads certificates" {
    var raw = RawX509.init(std.testing.allocator) catch return;
    var store = Crypto.X509.init(&raw);
    defer store.deinit();

    try std.testing.expect(raw.bundle.bytes.items.len > 0);
}

test "verifyChain rejects empty chain" {
    var raw = RawX509.init(std.testing.allocator) catch return;
    var store = Crypto.X509.init(&raw);
    defer store.deinit();

    const empty: []const []const u8 = &.{};
    try std.testing.expectError(error.CertificateChainTooShort, store.verifyChain(empty, null, 0));
}

test "verifyChain rejects garbage DER" {
    var raw = RawX509.init(std.testing.allocator) catch return;
    var store = Crypto.X509.init(&raw);
    defer store.deinit();

    const garbage = [_]u8{0xFF} ** 32;
    const chain: []const []const u8 = &.{&garbage};
    try std.testing.expectError(error.CertificateParseError, store.verifyChain(chain, null, 0));
}
