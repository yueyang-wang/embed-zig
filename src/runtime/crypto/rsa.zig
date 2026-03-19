//! Runtime crypto RSA contracts.

const Seal = struct {};

pub const HashType = enum { sha256, sha384, sha512 };

pub const DerKey = struct {
    modulus: []const u8,
    exponent: []const u8,
};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, []const u8, []const u8, []const u8, HashType) anyerror!void, &Impl.verifyPKCS1v1_5);
        _ = @as(*const fn (*Impl, []const u8, []const u8, []const u8, HashType) anyerror!void, &Impl.verifyPSS);
        _ = @as(*const fn (*Impl, []const u8) anyerror!DerKey, &Impl.parseDer);
    }

    return struct {
        pub const seal: Seal = .{};
        impl: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .impl = driver };
        }

        pub fn deinit(self: *Self) void {
            self.impl = undefined;
        }

        pub fn verifyPKCS1v1_5(self: Self, sig: []const u8, msg: []const u8, pk: []const u8, hash_type: HashType) !void {
            return self.impl.verifyPKCS1v1_5(sig, msg, pk, hash_type);
        }

        pub fn verifyPSS(self: Self, sig: []const u8, msg: []const u8, pk: []const u8, hash_type: HashType) !void {
            return self.impl.verifyPSS(sig, msg, pk, hash_type);
        }

        pub fn parseDer(self: Self, pub_key: []const u8) !DerKey {
            return self.impl.parseDer(pub_key);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
