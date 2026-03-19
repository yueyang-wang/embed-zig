//! HAL IMU Contract
//!
//! Inertial measurement unit providing accelerometer and gyroscope
//! data. The driver handles I2C/SPI communication, register
//! configuration, and sampling internally.
//! Upper layers poll for sensor samples via pollEvent().
//!
//! Impl must provide:
//!   pollEvent: fn (*Impl) Sample
//!   sample:    fn (*const Impl) Sample

pub const AccelData = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn magnitude(self: AccelData) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }
};

pub const GyroData = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn magnitude(self: GyroData) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }
};

pub const Sample = struct {
    accel: AccelData,
    gyro: GyroData,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl) Sample, &Impl.pollEvent);
        _ = @as(*const fn (*const Impl) Sample, &Impl.sample);
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

        pub fn pollEvent(self: Self) Sample {
            return self.driver.pollEvent();
        }

        pub fn sample(self: Self) Sample {
            return self.driver.sample();
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
