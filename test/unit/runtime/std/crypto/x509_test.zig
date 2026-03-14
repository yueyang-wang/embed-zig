const std = @import("std");
const testing = std.testing;
const module = @import("embed").runtime.std.std_crypto_x509;
const CaStore = module.CaStore;
const VerifyError = module.VerifyError;
const verifyChain = module.verifyChain;
const Certificate = module.Certificate;
const Bundle = module.Bundle;

test "CaStore initSystem loads certificates" {
    var store = CaStore.initSystem(std.testing.allocator) catch return;
    defer store.deinit();

    try std.testing.expect(store.bundle.bytes.items.len > 0);
}

test "verifyChain rejects empty chain" {
    var store = CaStore.initSystem(std.testing.allocator) catch return;
    defer store.deinit();

    const empty: []const []const u8 = &.{};
    try std.testing.expectError(error.CertificateChainTooShort, verifyChain(empty, null, store, 0));
}

test "verifyChain rejects garbage DER" {
    var store = CaStore.initSystem(std.testing.allocator) catch return;
    defer store.deinit();

    const garbage = [_]u8{0xFF} ** 32;
    const chain: []const []const u8 = &.{&garbage};
    try std.testing.expectError(error.CertificateParseError, verifyChain(chain, null, store, 0));
}
