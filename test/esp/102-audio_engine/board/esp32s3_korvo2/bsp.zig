const embed = @import("embed");
const esp = @import("esp");

const event = embed.pkg.event;
const hal = embed.hal;
const runtime = embed.runtime;

const heap = esp.component.heap;
const esp_hal = esp.hal;
const esp_runtime = esp.runtime;

const adc_button_channel: u8 = 6;

const i2s_bclk: u8 = 9;
const i2s_ws: u8 = 45;
const i2s_din: u8 = 10;
const i2s_dout: u8 = 8;
const i2s_mclk: u8 = 16;

const i2c_sda: u8 = 17;
const i2c_scl: u8 = 18;

const InnerAudioDriver = esp_hal.AudioSystemEs7210Es8311.DriverType;

pub const hw = struct {
    pub const name: []const u8 = "esp32s3_korvo2";

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

    pub const sync = struct {
        pub const Mutex = esp_runtime.Mutex;
        pub const Condition = esp_runtime.Condition;
    };

    pub const log = esp_runtime.Log;
    pub const time = esp_runtime.Time;
    pub const io = esp_runtime.IO;

    pub const adc_button_config = event.button.AdcButtonConfig{
        .ranges = &.{
            .{ .id = "vol_up", .min_mv = 200, .max_mv = 483 },
            .{ .id = "vol_down", .min_mv = 604, .max_mv = 886 },
            .{ .id = "set", .min_mv = 894, .max_mv = 1208 },
            .{ .id = "play", .min_mv = 1216, .max_mv = 1692 },
            .{ .id = "mute", .min_mv = 1700, .max_mv = 2054 },
            .{ .id = "rec", .min_mv = 2135, .max_mv = 2497 },
        },
        .adc_channel = adc_button_channel,
        .poll_interval_ms = 20,
        .debounce_samples = 3,
    };

    pub const rtc_spec = struct {
        pub const Driver = esp_hal.RtcReader.DriverType;
        pub const meta = .{ .id = "rtc.korvo2" };
    };

    pub const adc_spec = struct {
        pub const Driver = struct {
            inner: esp_hal.Adc.DriverType,

            const Self = @This();

            pub fn init() !Self {
                return .{ .inner = try esp_hal.Adc.DriverType.init() };
            }

            pub fn read(self: *Self, channel: u8) hal.adc.Error!u16 {
                return self.inner.read(channel);
            }

            pub fn readMv(self: *Self, channel: u8) hal.adc.Error!u16 {
                return self.inner.readMv(channel);
            }
        };

        pub const meta = .{ .id = "adc.korvo2" };
    };

    pub const audio_system_spec = struct {
        const I2cDriver = esp_hal.I2c.DriverType;
        const I2sDriver = esp_hal.I2s.DriverType;

        const audio_codec_cfg = esp_hal.audio_system_config.Config{
            .mics = .{
                .{ .enabled = true, .gain_db = 24 },
                .{ .enabled = true, .gain_db = 24 },
                .{ .enabled = true, .gain_db = 0 },
                .{},
            },
            .ref = .{ .hw = .{ .channel = 2 } },
            .frame_samples = 160,
            .spk_duplicate_mono = true,
        };

        pub const Driver = struct {
            inner: InnerAudioDriver,
            i2c_heap: *I2cDriver,
            i2s_heap: *I2sDriver,

            const Self = @This();

            pub fn init() hal.audio_system.Error!Self {
                const alloc = heap.dram;

                const i2c_ptr = alloc.create(I2cDriver) catch return error.AudioSystemError;
                errdefer alloc.destroy(i2c_ptr);
                i2c_ptr.* = I2cDriver.initMaster(.{
                    .sda = i2c_sda,
                    .scl = i2c_scl,
                }) catch return error.AudioSystemError;

                const i2s_ptr = alloc.create(I2sDriver) catch return error.AudioSystemError;
                errdefer alloc.destroy(i2s_ptr);
                i2s_ptr.* = I2sDriver.initBus(.{
                    .bclk = i2s_bclk,
                    .ws = i2s_ws,
                    .mclk = i2s_mclk,
                    .sample_rate_hz = 16_000,
                    .bits_per_sample = .bits16,
                    .slot_mode = .stereo,
                }) catch return error.AudioSystemError;
                errdefer i2s_ptr.deinitBus();

                const rx_handle = i2s_ptr.registerEndpoint(.{
                    .direction = .rx,
                    .data_pin = i2s_din,
                }) catch return error.AudioSystemError;

                const tx_handle = i2s_ptr.registerEndpoint(.{
                    .direction = .tx,
                    .data_pin = i2s_dout,
                }) catch return error.AudioSystemError;

                const inner = InnerAudioDriver.init(
                    i2c_ptr,
                    i2s_ptr,
                    rx_handle,
                    tx_handle,
                    alloc,
                    audio_codec_cfg,
                ) catch return error.AudioSystemError;

                return .{
                    .inner = inner,
                    .i2c_heap = i2c_ptr,
                    .i2s_heap = i2s_ptr,
                };
            }

            pub fn deinit(self: *Self) void {
                const alloc = heap.dram;
                self.inner.deinit();
                self.i2s_heap.deinitBus();
                alloc.destroy(self.i2s_heap);
                alloc.destroy(self.i2c_heap);
            }

            pub fn readFrame(self: *Self) hal.audio_system.Error!hal.audio_system.Frame(4) {
                return self.inner.readFrame();
            }

            pub fn writeSpk(self: *Self, buffer: []const i16) hal.audio_system.Error!usize {
                return self.inner.writeSpk(buffer);
            }

            pub fn setMicGain(self: *Self, mic_index: u8, gain_db: i8) hal.audio_system.Error!void {
                return self.inner.setMicGain(mic_index, gain_db);
            }

            pub fn setSpkGain(self: *Self, gain_db: i8) hal.audio_system.Error!void {
                return self.inner.setSpkGain(gain_db);
            }

            pub fn start(self: *Self) hal.audio_system.Error!void {
                return self.inner.start();
            }

            pub fn stop(self: *Self) hal.audio_system.Error!void {
                return self.inner.stop();
            }
        };

        pub const meta = .{ .id = "audio_system.korvo2" };
        pub const config = hal.audio_system.Config{ .sample_rate = 16000, .mic_count = 4 };
    };
};
