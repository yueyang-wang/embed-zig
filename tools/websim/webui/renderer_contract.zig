pub const LedState = struct {
    t: u64,
    on: bool,
    r: i64,
    g: i64,
    b: i64,
};

pub const RenderSnapshot = struct {
    led0: LedState,
};

pub const Renderer = struct {
    pub fn initial() RenderSnapshot {
        return .{
            .led0 = .{
                .t = 0,
                .on = false,
                .r = 0,
                .g = 0,
                .b = 0,
            },
        };
    }
};
