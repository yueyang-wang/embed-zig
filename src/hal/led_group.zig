//! HAL LED Group Contract (formerly led_strip)
//!
//! An addressable group of RGB LEDs (e.g. WS2812, SK6812).
//! The driver maintains a pixel buffer; refresh() pushes it to hardware.
//!
//! Impl must provide:
//!   setPixel: fn (*Impl, u32, Color) void
//!   getPixel: fn (*const Impl, u32) Color
//!   count:    fn (*const Impl) u32
//!   refresh:  fn (*Impl) void

pub const Color = packed struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub const black = Color{};
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const red = Color{ .r = 255 };
    pub const green = Color{ .g = 255 };
    pub const blue = Color{ .b = 255 };

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn withBrightness(self: Color, brightness: u8) Color {
        return .{
            .r = @intCast((@as(u16, self.r) * brightness) / 255),
            .g = @intCast((@as(u16, self.g) * brightness) / 255),
            .b = @intCast((@as(u16, self.b) * brightness) / 255),
        };
    }

    pub fn lerp(a: Color, b: Color, t: u8) Color {
        const inv_t = 255 - t;
        return .{
            .r = @intCast((@as(u16, a.r) * inv_t + @as(u16, b.r) * t) / 255),
            .g = @intCast((@as(u16, a.g) * inv_t + @as(u16, b.g) * t) / 255),
            .b = @intCast((@as(u16, a.b) * inv_t + @as(u16, b.b) * t) / 255),
        };
    }
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, u32, Color) void, &Impl.setPixel);
        _ = @as(*const fn (*const Impl, u32) Color, &Impl.getPixel);
        _ = @as(*const fn (*const Impl) u32, &Impl.count);
        _ = @as(*const fn (*Impl) void, &Impl.refresh);
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

        pub fn setPixel(self: Self, index: u32, color: Color) void {
            self.driver.setPixel(index, color);
        }

        pub fn getPixel(self: Self, index: u32) Color {
            return self.driver.getPixel(index);
        }

        pub fn count(self: Self) u32 {
            return self.driver.count();
        }

        pub fn refresh(self: Self) void {
            self.driver.refresh();
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
