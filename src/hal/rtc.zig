//! HAL RTC Contract
//!
//! Real-time clock providing wall-clock time as Unix epoch seconds
//! and monotonic uptime. The driver manages the underlying RTC
//! peripheral or NTP-synced software clock.
//!
//! Impl must provide:
//!   now:      fn (*const Impl) i64
//!   set:      fn (*Impl, i64) Error!void
//!   isValid:  fn (*const Impl) bool
//!   uptimeMs: fn (*const Impl) u64

pub const Error = error{
    InvalidTime,
    HardwareFault,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*const Impl) i64, &Impl.now);
        _ = @as(*const fn (*Impl, i64) Error!void, &Impl.set);
        _ = @as(*const fn (*const Impl) bool, &Impl.isValid);
        _ = @as(*const fn (*const Impl) u64, &Impl.uptimeMs);
    }

    return struct {
        pub const seal: Seal = .{};
        driver: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .driver = driver };
        }

        pub fn deinit(self: *Self) void {
            self.driver = undefined;
        }

        pub fn now(self: Self) i64 {
            return self.driver.now();
        }

        pub fn set(self: Self, epoch_sec: i64) Error!void {
            return self.driver.set(epoch_sec);
        }

        pub fn isValid(self: Self) bool {
            return self.driver.isValid();
        }

        pub fn uptimeMs(self: Self) u64 {
            return self.driver.uptimeMs();
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
