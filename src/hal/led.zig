//! HAL Single LED Contract
//!
//! A single LED with brightness control and hardware fade.
//!
//! Impl must provide:
//!   setBrightness: fn (*Impl, u8) void
//!   getBrightness: fn (*const Impl) u8
//!   fade:          fn (*Impl, target: u8, duration_ms: u32) void

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, u8) void, &Impl.setBrightness);
        _ = @as(*const fn (*const Impl) u8, &Impl.getBrightness);
        _ = @as(*const fn (*Impl, u8, u32) void, &Impl.fade);
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

        pub fn setBrightness(self: Self, brightness: u8) void {
            self.driver.setBrightness(brightness);
        }

        pub fn getBrightness(self: Self) u8 {
            return self.driver.getBrightness();
        }

        pub fn fade(self: Self, target: u8, duration_ms: u32) void {
            self.driver.fade(target, duration_ms);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
