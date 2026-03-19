//! Runtime crypto X.509 contracts.

const std = @import("std");

const Seal = struct {};

pub const VerifyError = error{
    CertificateVerificationFailed,
    CertificateHostMismatch,
    CertificateParseError,
    CertificateChainTooShort,
};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl) void, &Impl.deinit);
        _ = @as(
            *const fn (*Impl, []const []const u8, ?[]const u8, i64) VerifyError!void,
            &Impl.verifyChain,
        );
    }

    return struct {
        pub const seal: Seal = .{};
        impl: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .impl = driver };
        }

        pub fn deinit(self: *Self) void {
            self.impl.deinit();
            self.impl = undefined;
        }

        pub fn verifyChain(
            self: Self,
            chain: []const []const u8,
            hostname: ?[]const u8,
            now_sec: i64,
        ) VerifyError!void {
            return self.impl.verifyChain(chain, hostname, now_sec);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
