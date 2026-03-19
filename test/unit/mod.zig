const std = @import("std");

test {
    _ = @import("pkg/app/app_runtime_test.zig");
    _ = @import("pkg/audio/engine_test.zig");
    _ = @import("pkg/audio/mixer_test.zig");
    _ = @import("pkg/audio/override_buffer_test.zig");
    _ = @import("pkg/audio/resampler_test.zig");
    // Keep broader BLE spec coverage available as a direct test file.
    _ = @import("pkg/ble/gatt/server_test.zig");
    _ = @import("pkg/ble/host/att/att_test.zig");
    _ = @import("pkg/ble/host/gap/gap_test.zig");
    _ = @import("pkg/ble/host/hci/acl_test.zig");
    _ = @import("pkg/ble/host/hci/commands_test.zig");
    _ = @import("pkg/ble/host/hci/events_test.zig");
    _ = @import("pkg/ble/host/host_test.zig");
    _ = @import("pkg/ble/host/l2cap/l2cap_test.zig");
    _ = @import("pkg/ble/term/shell_test.zig");
    // Keep BLE terminal integration coverage available as a direct test file.
    _ = @import("pkg/ble/term/transport_test.zig");
    _ = @import("pkg/ble/xfer/chunk_test.zig");
    // Keep transfer E2E coverage available as a direct test file.
    _ = @import("pkg/drivers/qmi8658/src_test.zig");
    _ = @import("pkg/drivers/tca9554/src_test.zig");
    // Keep bus integration coverage available as a direct test file.
    _ = @import("pkg/event/bus_test.zig");
    _ = @import("pkg/event/motion/detector_test.zig");
    _ = @import("pkg/event/motion/motion_test.zig");
    _ = @import("pkg/event/motion/types_test.zig");
    _ = @import("pkg/event/ring_buffer_test.zig");
    _ = @import("pkg/event/types_test.zig");
    _ = @import("pkg/flux/app_state_manager_test.zig");
    _ = @import("pkg/flux/store_test.zig");
    _ = @import("pkg/net/conn_test.zig");
    _ = @import("pkg/net/dns/dns_test.zig");
    _ = @import("pkg/net/http/client_test.zig");
    _ = @import("pkg/net/http/request_test.zig");
    _ = @import("pkg/net/http/response_test.zig");
    _ = @import("pkg/net/http/router_test.zig");
    _ = @import("pkg/net/http/server_test.zig");
    _ = @import("pkg/net/http/static_test.zig");
    _ = @import("pkg/net/http/transport_test.zig");
    _ = @import("pkg/net/ntp/ntp_test.zig");
    _ = @import("pkg/net/tls/alert_test.zig");
    _ = @import("pkg/net/tls/cert/certs_test.zig");
    _ = @import("pkg/net/tls/client_test.zig");
    _ = @import("pkg/net/tls/common_test.zig");
    _ = @import("pkg/net/tls/extensions_test.zig");
    _ = @import("pkg/net/tls/handshake_test.zig");
    _ = @import("pkg/net/tls/kdf_test.zig");
    _ = @import("pkg/net/tls/record_test.zig");
    _ = @import("pkg/net/tls/stream_test.zig");
    // Keep long-running stress coverage available as a direct test file.
    _ = @import("pkg/net/url/url_test.zig");
    _ = @import("pkg/net/ws/base64_test.zig");
    _ = @import("pkg/net/ws/client_test.zig");
    // Keep websocket E2E/benchmark coverage available as a direct test file.
    _ = @import("pkg/net/ws/frame_test.zig");
    _ = @import("pkg/net/ws/handshake_test.zig");
    _ = @import("pkg/net/ws/sha1_test.zig");
    _ = @import("pkg/ui/led_strip/animator_test.zig");
    _ = @import("pkg/ui/led_strip/frame_test.zig");
    _ = @import("pkg/ui/render/font/api_test.zig");
    _ = @import("pkg/ui/render/framebuffer/anim_test.zig");
    _ = @import("pkg/ui/render/framebuffer/dirty_test.zig");
    _ = @import("pkg/ui/render/framebuffer/font_test.zig");
    _ = @import("pkg/ui/render/framebuffer/framebuffer_test.zig");
    _ = @import("pkg/ui/render/framebuffer/image_test.zig");
    _ = @import("pkg/ui/render/framebuffer/scene_test.zig");
    _ = @import("third_party/speexdsp/src_test.zig");
}
