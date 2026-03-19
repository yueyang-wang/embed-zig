const std = @import("std");

pub fn encrypt(_: *@This(), buf: []u8, tag: *[16]u8, plaintext: []const u8, ad: []const u8, nonce: [12]u8, key: []const u8) void {
    if (key.len == 16) {
        std.crypto.aead.aes_gcm.Aes128Gcm.encrypt(buf[0..plaintext.len], tag, plaintext, ad, nonce, key[0..16].*);
    } else {
        std.crypto.aead.aes_gcm.Aes256Gcm.encrypt(buf[0..plaintext.len], tag, plaintext, ad, nonce, key[0..32].*);
    }
}

pub fn decrypt(_: *@This(), buf: []u8, ciphertext: []const u8, tag: [16]u8, ad: []const u8, nonce: [12]u8, key: []const u8) error{AuthenticationFailed}!void {
    if (key.len == 16) {
        std.crypto.aead.aes_gcm.Aes128Gcm.decrypt(buf[0..ciphertext.len], ciphertext, tag, ad, nonce, key[0..16].*) catch {
            return error.AuthenticationFailed;
        };
    } else {
        std.crypto.aead.aes_gcm.Aes256Gcm.decrypt(buf[0..ciphertext.len], ciphertext, tag, ad, nonce, key[0..32].*) catch {
            return error.AuthenticationFailed;
        };
    }
}
