const esp = @import("esp");
const embed_zig = @import("embed");

const heap = esp.component.heap;
const esp_hal = esp.hal;
const esp_runtime = esp.runtime;
const hal = embed_zig.hal;
const runtime = embed_zig.runtime;

const btn_pin: u8 = 0;
const led_gpio_num: i32 = 48;
const led_count: u32 = 1;

pub const hw = struct {
    pub const name: []const u8 = "esp32s3_devkit";
    pub const button_pin: u8 = btn_pin;

    pub const allocator = struct {
        pub const user = heap.psram;
        pub const system = heap.dram;
        pub const default = heap.default;
    };

    pub const thread = struct {
        pub const Thread = esp_runtime.Thread;
        pub const user_defaults: runtime.thread.SpawnConfig = .{
            .allocator = heap.psram,
            .priority = 3,
            .name = "user",
            .core_id = 0,
        };
        pub const system_defaults: runtime.thread.SpawnConfig = .{
            .allocator = heap.dram,
            .priority = 5,
            .name = "sys",
        };
        pub const default_defaults: runtime.thread.SpawnConfig = .{
            .allocator = heap.default,
            .priority = 5,
            .name = "zig-task",
        };
    };

    pub const log = esp_runtime.Log;
    pub const time = esp_runtime.Time;
    pub const io = esp_runtime.IO;

    pub const rtc_spec = struct {
        pub const Driver = esp_hal.RtcReader.DriverType;
        pub const meta = .{ .id = "rtc.esp32s3" };
    };

    pub const gpio_spec = struct {
        pub const Driver = esp_hal.Gpio.DriverType;
        pub const meta = .{ .id = "gpio.esp32s3" };
    };

    pub const led_strip_spec = struct {
        pub const Driver = struct {
            inner: esp_hal.LedStrip.DriverType,

            const Self = @This();

            pub fn init() !Self {
                return .{
                    .inner = try esp_hal.LedStrip.DriverType.initRmt(led_gpio_num, led_count),
                };
            }

            pub fn deinit(self: *Self) void {
                self.inner.deinit();
            }

            pub fn setPixel(self: *Self, index: u32, color: hal.led_strip.Color) void {
                self.inner.setPixel(index, color);
            }

            pub fn getPixelCount(self: *Self) u32 {
                return self.inner.getPixelCount();
            }

            pub fn refresh(self: *Self) void {
                self.inner.refresh();
            }
        };

        pub const meta = .{ .id = "led_strip.esp32s3_rmt" };
    };
};
