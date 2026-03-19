//! Runtime crypto suite contract.

const hash_mod = @import("hash.zig");
const hmac_mod = @import("hmac.zig");
const hkdf_mod = @import("hkdf.zig");
const aead_mod = @import("aead.zig");
const pki_mod = @import("pki.zig");
const x25519_mod = @import("x25519.zig");
const p256_mod = @import("p256.zig");
const rsa_mod = @import("rsa.zig");
const x509_mod = @import("x509.zig");

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    return struct {
        pub const seal: Seal = .{};

        pub const Hash = hash_mod.Make(Impl.hash);
        pub const Hmac = hmac_mod.Make(Impl.hmac);
        pub const Hkdf = hkdf_mod.Make(Impl.hkdf);
        pub const Aead = aead_mod.Make(Impl.aead);
        pub const Pki = pki_mod.Make(Impl.pki);
        pub const Rsa = rsa_mod.Make(Impl.rsa);
        pub const X509 = x509_mod.Make(Impl.X509);
        pub const X25519 = x25519_mod.Make(Impl.X25519);
        pub const P256 = p256_mod.Make(Impl.P256);

        hash: Hash,
        hmac: Hmac,
        hkdf: Hkdf,
        aead: Aead,
        pki: Pki,
        rsa: Rsa,
        x509: X509,
        x25519: X25519,
        p256: P256,

        const Self = @This();

        pub fn init(
            hash_impl: *Impl.hash,
            hmac_impl: *Impl.hmac,
            hkdf_impl: *Impl.hkdf,
            aead_impl: *Impl.aead,
            pki_impl: *Impl.pki,
            rsa_impl: *Impl.rsa,
            x509_impl: *Impl.X509,
            x25519_impl: *Impl.X25519,
            p256_impl: *Impl.P256,
        ) Self {
            return .{
                .hash = Hash.init(hash_impl),
                .hmac = Hmac.init(hmac_impl),
                .hkdf = Hkdf.init(hkdf_impl),
                .aead = Aead.init(aead_impl),
                .pki = Pki.init(pki_impl),
                .rsa = Rsa.init(rsa_impl),
                .x509 = X509.init(x509_impl),
                .x25519 = X25519.init(x25519_impl),
                .p256 = P256.init(p256_impl),
            };
        }

        pub fn deinit(self: *Self) void {
            self.x509.deinit();
            self.hash.deinit();
            self.hmac.deinit();
            self.hkdf.deinit();
            self.aead.deinit();
            self.pki.deinit();
            self.rsa.deinit();
            self.x25519.deinit();
            self.p256.deinit();
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
