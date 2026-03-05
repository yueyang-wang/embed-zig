const modules = @import("sdkconfig_modules");
const partition = @import("idf_partition");
const rom = @import("esp_rom");
const freertos = @import("freertos");
const esp_timer = @import("esp_timer");
const esp_gpio = @import("esp_driver_gpio");
const esp_led = @import("led_strip");
const Color = @import("embed_zig").hal.led_strip.Color;

pub const config = .{
    .core = modules.esp_system_config.default,
    .freertos = modules.freertos_config.default,
    .app_metadata = modules.app_metadata_config.default,
    .app_trace = modules.app_trace_config.default,
    .bootloader = modules.bootloader_config.default,
    .bt = modules.bt_config.default,
    .console = modules.console_config.default,
    .efuse = modules.efuse_config.default,
    .esp_adc = modules.esp_adc_config.default,
    .esp_coex = modules.esp_coex_config.default,
    .esp_driver_gdma = modules.esp_driver_gdma_config.default,
    .esp_driver_gpio = modules.esp_driver_gpio_config.default,
    .esp_driver_gptimer = modules.esp_driver_gptimer_config.default,
    .esp_driver_i2c = modules.esp_driver_i2c_config.default,
    .esp_driver_i2s = modules.esp_driver_i2s_config.default,
    .esp_driver_ledc = modules.esp_driver_ledc_config.default,
    .esp_driver_mcpwm = modules.esp_driver_mcpwm_config.default,
    .esp_driver_pcnt = modules.esp_driver_pcnt_config.default,
    .esp_driver_rmt = modules.esp_driver_rmt_config.default,
    .esp_driver_sdm = modules.esp_driver_sdm_config.default,
    .esp_driver_spi = modules.esp_driver_spi_config.default,
    .esp_driver_touch_sens = modules.esp_driver_touch_sens_config.default,
    .esp_driver_tsens = modules.esp_driver_tsens_config.default,
    .esp_driver_twai = modules.esp_driver_twai_config.default,
    .esp_driver_uart = modules.esp_driver_uart_config.default,
    .esp_eth = modules.esp_eth_config.default,
    .esp_event = modules.esp_event_config.default,
    .esp_gdbstub = modules.esp_gdbstub_config.default,
    .esp_http_client = modules.esp_http_client_config.default,
    .esp_http_server = modules.esp_http_server_config.default,
    .esp_https_ota = modules.esp_https_ota_config.default,
    .esp_https_server = modules.esp_https_server_config.default,
    .esp_hw_support = modules.esp_hw_support_config.default,
    .esp_lcd = modules.esp_lcd_config.default,
    .esp_misc = modules.esp_misc_config.default,
    .esp_mm = modules.esp_mm_config.default,
    .esp_netif = modules.esp_netif_config.default,
    .esp_phy = modules.esp_phy_config.default,
    .esp_pm = modules.esp_pm_config.default,
    .esp_psram = modules.esp_psram_config.default,
    .esp_security = modules.esp_security_config.default,
    .esp_timer = modules.esp_timer_config.default,
    .esp_wifi = modules.esp_wifi_config.default,
    .espcoredump = modules.espcoredump_config.default,
    .esptool_py = modules.esptool_py_config.default,
    .fatfs = modules.fatfs_config.default,
    .hal = modules.hal_config.default,
    .heap = modules.heap_config.default,
    .idf_build_system = modules.idf_build_system_config.default,
    .log = modules.log_config.default,
    .lwip = modules.lwip_config.default,
    .mbedtls = modules.mbedtls_config.default,
    .mqtt = modules.mqtt_config.default,
    .newlib = modules.newlib_config.default,
    .nvs_flash = modules.nvs_flash_config.default,
    .openthread = modules.openthread_config.default,
    .partition_table_cfg = modules.partition_table_config.default,
    .pthread = modules.pthread_config.default,
    .soc = modules.soc_config.default,
    .spi_flash = modules.spi_flash_config.default,
    .spiffs = modules.spiffs_config.default,
    .target_soc = modules.target_soc_config.default,
    .tcp_transport = modules.tcp_transport_config.default,
    .toolchain = modules.toolchain_config.default,
    .ulp = modules.ulp_config.default,
    .unity = modules.unity_config.default,
    .usb = modules.usb_config.default,
    .vfs = modules.vfs_config.default,
    .wear_levelling = modules.wear_levelling_config.default,
    .wpa_supplicant = modules.wpa_supplicant_config.default,
    .board = .{
        .name = @as([]const u8, "board.esp32s3_devkit"),
        .chip = @as([]const u8, "esp32s3"),
        .target_arch = @as([]const u8, "xtensa"),
        .target_arch_config_flag = @as([]const u8, "CONFIG_IDF_TARGET_ARCH_XTENSA"),
        .target_config_flag = @as([]const u8, "CONFIG_IDF_TARGET_ESP32S3"),
    },
    .partition_table = partition.default_table,
};

const tick_rate_hz: u32 = 100;
const btn_pin: i32 = 0;
const led_gpio: i32 = 48;
const led_count: u32 = 1;

var strip: ?esp_led.LedStrip = null;

fn printMsg(prefix: [*:0]const u8, msg: []const u8) void {
    rom.printf("%s", .{prefix});
    for (msg) |c| rom.printf("%c", .{c});
    rom.printf("\n", .{});
}

pub const hw = struct {
    pub const name: []const u8 = "esp32s3_devkit";

    pub const log = struct {
        pub fn debug(_: @This(), msg: []const u8) void { printMsg("[D] ", msg); }
        pub fn info(_: @This(), msg: []const u8) void { printMsg("[I] ", msg); }
        pub fn warn(_: @This(), msg: []const u8) void { printMsg("[W] ", msg); }
        pub fn err(_: @This(), msg: []const u8) void { printMsg("[E] ", msg); }
    };

    pub const time = struct {
        pub fn nowMs(_: @This()) u64 { return esp_timer.getTimeMs(); }
        pub fn sleepMs(_: @This(), ms: u32) void { freertos.delay(ms * tick_rate_hz / 1000); }
    };

    pub fn init() !void {
        esp_gpio.gpio.setDirection(btn_pin, .input) catch return error.InitFailed;
        esp_gpio.gpio.setPullMode(btn_pin, .pullup_only) catch return error.InitFailed;

        strip = esp_led.LedStrip.initRmt(.{
            .gpio_num = led_gpio,
            .max_leds = led_count,
        }, .{}) catch return error.InitFailed;

        if (strip) |s| {
            s.clear() catch {};
            s.refresh() catch {};
        }
    }

    pub fn deinit() void {
        if (strip) |s| {
            s.clear() catch {};
            s.refresh() catch {};
            s.deinit() catch {};
        }
        strip = null;
    }

    pub fn readButton() bool {
        return esp_gpio.gpio.getLevel(btn_pin) == 0;
    }

    pub fn setLed(color: Color) void {
        const s = strip orelse return;
        s.setPixel(0, color.r, color.g, color.b) catch {};
        s.refresh() catch {};
    }
};
