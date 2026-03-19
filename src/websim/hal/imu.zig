//! Websim stub — IMU HAL (placeholder).

const imu = @import("../../hal/imu.zig");

const zero_sample: imu.Sample = .{
    .accel = .{ .x = 0, .y = 0, .z = 0 },
    .gyro = .{ .x = 0, .y = 0, .z = 0 },
};

pub const Imu = struct {
    pub fn pollEvent(_: *Imu) imu.Sample { return zero_sample; }
    pub fn sample(_: *const Imu) imu.Sample { return zero_sample; }
};
