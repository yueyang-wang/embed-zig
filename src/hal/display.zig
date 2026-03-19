//! HAL Display Contract
//!
//! SPI LCD panel transport: no framebuffer, no pixel operations.
//! The driver initializes the panel and provides drawBitmap to push
//! contiguous pixel data to a screen region.
//!
//! Impl must provide:
//!   width:             fn (*const Impl) u16
//!   height:            fn (*const Impl) u16
//!   setDisplayEnabled: fn (*Impl, bool) Error!void
//!   sleep:             fn (*Impl, bool) Error!void
//!   drawBitmap:        fn (*Impl, u16, u16, u16, u16, []const Color565) Error!void

pub const Error = error{
    OutOfBounds,
    Busy,
    Timeout,
    DisplayError,
};

pub const Color565 = u16;

pub fn rgb565(r: u8, g: u8, b: u8) Color565 {
    const rr: u16 = (@as(u16, r) >> 3) & 0x1F;
    const gg: u16 = (@as(u16, g) >> 2) & 0x3F;
    const bb: u16 = (@as(u16, b) >> 3) & 0x1F;
    return (rr << 11) | (gg << 5) | bb;
}

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*const Impl) u16, &Impl.width);
        _ = @as(*const fn (*const Impl) u16, &Impl.height);
        _ = @as(*const fn (*Impl, bool) Error!void, &Impl.setDisplayEnabled);
        _ = @as(*const fn (*Impl, bool) Error!void, &Impl.sleep);
        _ = @as(*const fn (*Impl, u16, u16, u16, u16, []const Color565) Error!void, &Impl.drawBitmap);
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

        pub fn width(self: Self) u16 {
            return self.driver.width();
        }

        pub fn height(self: Self) u16 {
            return self.driver.height();
        }

        pub fn setDisplayEnabled(self: Self, enabled: bool) Error!void {
            return self.driver.setDisplayEnabled(enabled);
        }

        pub fn sleep(self: Self, enabled: bool) Error!void {
            return self.driver.sleep(enabled);
        }

        pub fn drawBitmap(self: Self, x: u16, y: u16, w: u16, h: u16, data: []const Color565) Error!void {
            if (w == 0 or h == 0) return;
            if (@as(u32, x) + w > self.width() or @as(u32, y) + h > self.height()) return error.OutOfBounds;
            if (data.len < @as(usize, w) * @as(usize, h)) return error.OutOfBounds;
            return self.driver.drawBitmap(x, y, w, h, data);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
