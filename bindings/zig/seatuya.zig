// seatuya.zig -- Zig FFI bindings for libseatuya
//
// Loads libseatuya at runtime and provides safe wrapper functions.
// Set SEATUYA_LIB to a custom library path.
//
// Usage:
//   const seatuya = @import("seatuya.zig");
//   const lib = seatuya.Library.open();
//   const dev = lib.create(device_id, "192.168.1.100", local_key, "3.4");
//   _ = lib.turnOn(dev, 1);
//   lib.destroy(dev);

const std = @import("std");
const builtin = @import("builtin");

pub const Device = opaque {};

// --- Constants ---

pub const Command = enum(i32) {
    udp = 0,
    ap_config = 1,
    active = 2,
    bind = 3,
    rename_gw = 4,
    rename_device = 5,
    unbind = 6,
    control = 7,
    status = 8,
    heart_beat = 9,
    dp_query = 10,
    query_wifi = 11,
    token_bind = 12,
    control_new = 13,
    enable_wifi = 14,
    dp_query_new = 16,
    scene_execute = 17,
    updatedps = 18,
    udp_new = 19,
    ap_config_new = 20,
    get_local_time = 28,
    weather_open = 32,
    weather_data = 33,
    state_upload_syn = 34,
    state_upload_syn_recv = 35,
    heart_beat_stop = 37,
    stream_trans = 38,
    get_wifi_status = 43,
    wifi_connect_test = 44,
    get_mac = 45,
    get_ir_status = 46,
    ir_tx_rx_test = 47,
    lan_gw_active = 240,
    lan_sub_dev_request = 241,
    lan_delete_sub_dev = 242,
    lan_report_sub_dev = 243,
    lan_scene = 244,
    lan_publish_cloud_config = 245,
    lan_publish_app_config = 246,
    lan_export_app_config = 247,
    lan_publish_scene_panel = 248,
    lan_remove_gw = 249,
    lan_check_gw_update = 250,
    lan_gw_update = 251,
    lan_set_gw_channel = 252,

    pub const CMD_CONTROL: Command = .control;
    pub const CMD_DP_QUERY: Command = .dp_query;
    pub const CMD_HEART_BEAT: Command = .heart_beat;
    pub const CMD_STATUS: Command = .status;
    pub const CMD_CONTROL_NEW: Command = .control_new;
    pub const CMD_DP_QUERY_NEW: Command = .dp_query_new;
};

pub const Protocol = enum(i32) { v31 = 0, v33 = 1, v34 = 2, v35 = 3 };

pub const SessionState = enum(i32) {
    invalid = 0,
    starting = 1,
    finalizing = 2,
    established = 3,
};

pub const SocketState = enum(i32) {
    no_such_host = 0,
    no_sock_avail = 1,
    failed = 2,
    disconnected = 3,
    connecting = 4,
    connected = 5,
    ready = 6,
    receiving = 7,
};

pub const DEFAULT_PORT: i32 = 6668;
pub const BUFSIZE: i32 = 1024;

// --- Library loading ---

const default_path: [:0]const u8 = switch (builtin.target.os.tag) {
    .macos, .ios, .tvos, .watchos => "libseatuya.dylib",
    .windows => "seatuya.dll",
    else => "libseatuya.so",
};

/// Cached function pointers from the loaded shared library.
const FnTable = struct {
    tuya_version: *const fn() callconv(.C) ?[*:0]const u8,
    tuya_create: *const fn(?[*:0]const u8, ?[*:0]const u8, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) ?*Device,
    tuya_alloc: *const fn(?[*:0]const u8) callconv(.C) ?*Device,
    tuya_destroy: *const fn(?*Device) callconv(.C) void,
    tuya_set_credentials: *const fn(?*Device, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) void,
    tuya_get_device_id: *const fn(?*Device) callconv(.C) ?[*:0]const u8,
    tuya_get_local_key: *const fn(?*Device) callconv(.C) ?[*:0]const u8,
    tuya_get_ip: *const fn(?*Device) callconv(.C) ?[*:0]const u8,
    tuya_connect: *const fn(?*Device, ?[*:0]const u8) callconv(.C) i32,
    tuya_disconnect: *const fn(?*Device) callconv(.C) void,
    tuya_is_connected: *const fn(?*Device) callconv(.C) i32,
    tuya_reconnect: *const fn(?*Device) callconv(.C) i32,
    tuya_set_retry_limit: *const fn(?*Device, i32) callconv(.C) void,
    tuya_set_retry_delay: *const fn(?*Device, i32) callconv(.C) void,
    tuya_get_retry_limit: *const fn(?*Device) callconv(.C) i32,
    tuya_get_retry_delay: *const fn(?*Device) callconv(.C) i32,
    tuya_negotiate_session: *const fn(?*Device, ?[*:0]const u8) callconv(.C) i32,
    tuya_negotiate_session_start: *const fn(?*Device, ?[*:0]const u8) callconv(.C) i32,
    tuya_negotiate_session_finalize: *const fn(?*Device, [*]u8, i32, ?[*:0]const u8) callconv(.C) i32,
    tuya_get_protocol: *const fn(?*Device) callconv(.C) i32,
    tuya_get_session_state: *const fn(?*Device) callconv(.C) i32,
    tuya_get_socket_state: *const fn(?*Device) callconv(.C) i32,
    tuya_get_last_error: *const fn(?*Device) callconv(.C) i32,
    tuya_set_async_mode: *const fn(?*Device, i32) callconv(.C) void,
    tuya_is_socket_readable: *const fn(?*Device) callconv(.C) i32,
    tuya_is_socket_writable: *const fn(?*Device) callconv(.C) i32,
    tuya_set_session_ready: *const fn(?*Device) callconv(.C) i32,
    tuya_build_message: *const fn(?*Device, [*]u8, i32, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) i32,
    tuya_decode_message: *const fn(?*Device, [*]u8, i32, ?[*:0]const u8) callconv(.C) ?[*:0]u8,
    tuya_generate_payload: *const fn(?*Device, i32, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) ?[*:0]u8,
    tuya_send: *const fn(?*Device, [*]u8, i32) callconv(.C) i32,
    tuya_receive: *const fn(?*Device, [*]u8, i32, i32) callconv(.C) i32,
    tuya_set_value_bool: *const fn(?*Device, i32, i32) callconv(.C) ?[*:0]u8,
    tuya_set_value_int: *const fn(?*Device, i32, i32) callconv(.C) ?[*:0]u8,
    tuya_set_value_string: *const fn(?*Device, i32, ?[*:0]const u8) callconv(.C) ?[*:0]u8,
    tuya_set_value_float: *const fn(?*Device, i32, f64) callconv(.C) ?[*:0]u8,
    tuya_turn_on: *const fn(?*Device, i32) callconv(.C) ?[*:0]u8,
    tuya_turn_off: *const fn(?*Device, i32) callconv(.C) ?[*:0]u8,
    tuya_status: *const fn(?*Device) callconv(.C) ?[*:0]u8,
    tuya_heartbeat: *const fn(?*Device) callconv(.C) ?[*:0]u8,
    tuya_free_string: *const fn(?[*:0]u8) callconv(.C) void,
    tuya_set_device22: *const fn(?*Device, ?[*:0]const u8) callconv(.C) void,
    tuya_is_device22: *const fn(?*Device) callconv(.C) i32,
};

/// Runtime-loaded seatuya library handle.
pub const Library = struct {
    _handle: std.DynLib,

    pub fn open() Library {
        const alloc = std.heap.page_allocator;
        const env_path = std.process.getEnvVarOwned(alloc, "SEATUYA_LIB") catch null;
        defer if (env_path) |p| alloc.free(p);
        const path = env_path orelse default_path;
        const lib = std.DynLib.open(path) catch |err| {
            std.debug.panic("failed to open seatuya library '{s}': {s}", .{ path, @errorName(err) });
        };
        return Library{ ._handle = lib };
    }

    fn lookupSymbol(self: Library, comptime T: type, comptime name: [:0]const u8) T {
        return self._handle.lookup(T, name) orelse
            @panic("symbol not found in seatuya: " ++ name);
    }

    fn symbols(self: Library) FnTable {
        return FnTable{
            .tuya_version = self.lookupSymbol(*const fn() callconv(.C) ?[*:0]const u8, "tuya_version"),
            .tuya_create = self.lookupSymbol(*const fn(?[*:0]const u8, ?[*:0]const u8, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) ?*Device, "tuya_create"),
            .tuya_alloc = self.lookupSymbol(*const fn(?[*:0]const u8) callconv(.C) ?*Device, "tuya_alloc"),
            .tuya_destroy = self.lookupSymbol(*const fn(?*Device) callconv(.C) void, "tuya_destroy"),
            .tuya_set_credentials = self.lookupSymbol(*const fn(?*Device, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) void, "tuya_set_credentials"),
            .tuya_get_device_id = self.lookupSymbol(*const fn(?*Device) callconv(.C) ?[*:0]const u8, "tuya_get_device_id"),
            .tuya_get_local_key = self.lookupSymbol(*const fn(?*Device) callconv(.C) ?[*:0]const u8, "tuya_get_local_key"),
            .tuya_get_ip = self.lookupSymbol(*const fn(?*Device) callconv(.C) ?[*:0]const u8, "tuya_get_ip"),
            .tuya_connect = self.lookupSymbol(*const fn(?*Device, ?[*:0]const u8) callconv(.C) i32, "tuya_connect"),
            .tuya_disconnect = self.lookupSymbol(*const fn(?*Device) callconv(.C) void, "tuya_disconnect"),
            .tuya_is_connected = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_is_connected"),
            .tuya_reconnect = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_reconnect"),
            .tuya_set_retry_limit = self.lookupSymbol(*const fn(?*Device, i32) callconv(.C) void, "tuya_set_retry_limit"),
            .tuya_set_retry_delay = self.lookupSymbol(*const fn(?*Device, i32) callconv(.C) void, "tuya_set_retry_delay"),
            .tuya_get_retry_limit = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_get_retry_limit"),
            .tuya_get_retry_delay = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_get_retry_delay"),
            .tuya_negotiate_session = self.lookupSymbol(*const fn(?*Device, ?[*:0]const u8) callconv(.C) i32, "tuya_negotiate_session"),
            .tuya_negotiate_session_start = self.lookupSymbol(*const fn(?*Device, ?[*:0]const u8) callconv(.C) i32, "tuya_negotiate_session_start"),
            .tuya_negotiate_session_finalize = self.lookupSymbol(*const fn(?*Device, [*]u8, i32, ?[*:0]const u8) callconv(.C) i32, "tuya_negotiate_session_finalize"),
            .tuya_get_protocol = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_get_protocol"),
            .tuya_get_session_state = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_get_session_state"),
            .tuya_get_socket_state = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_get_socket_state"),
            .tuya_get_last_error = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_get_last_error"),
            .tuya_set_async_mode = self.lookupSymbol(*const fn(?*Device, i32) callconv(.C) void, "tuya_set_async_mode"),
            .tuya_is_socket_readable = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_is_socket_readable"),
            .tuya_is_socket_writable = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_is_socket_writable"),
            .tuya_set_session_ready = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_set_session_ready"),
            .tuya_build_message = self.lookupSymbol(*const fn(?*Device, [*]u8, i32, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) i32, "tuya_build_message"),
            .tuya_decode_message = self.lookupSymbol(*const fn(?*Device, [*]u8, i32, ?[*:0]const u8) callconv(.C) ?[*:0]u8, "tuya_decode_message"),
            .tuya_generate_payload = self.lookupSymbol(*const fn(?*Device, i32, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) ?[*:0]u8, "tuya_generate_payload"),
            .tuya_send = self.lookupSymbol(*const fn(?*Device, [*]u8, i32) callconv(.C) i32, "tuya_send"),
            .tuya_receive = self.lookupSymbol(*const fn(?*Device, [*]u8, i32, i32) callconv(.C) i32, "tuya_receive"),
            .tuya_set_value_bool = self.lookupSymbol(*const fn(?*Device, i32, i32) callconv(.C) ?[*:0]u8, "tuya_set_value_bool"),
            .tuya_set_value_int = self.lookupSymbol(*const fn(?*Device, i32, i32) callconv(.C) ?[*:0]u8, "tuya_set_value_int"),
            .tuya_set_value_string = self.lookupSymbol(*const fn(?*Device, i32, ?[*:0]const u8) callconv(.C) ?[*:0]u8, "tuya_set_value_string"),
            .tuya_set_value_float = self.lookupSymbol(*const fn(?*Device, i32, f64) callconv(.C) ?[*:0]u8, "tuya_set_value_float"),
            .tuya_turn_on = self.lookupSymbol(*const fn(?*Device, i32) callconv(.C) ?[*:0]u8, "tuya_turn_on"),
            .tuya_turn_off = self.lookupSymbol(*const fn(?*Device, i32) callconv(.C) ?[*:0]u8, "tuya_turn_off"),
            .tuya_status = self.lookupSymbol(*const fn(?*Device) callconv(.C) ?[*:0]u8, "tuya_status"),
            .tuya_heartbeat = self.lookupSymbol(*const fn(?*Device) callconv(.C) ?[*:0]u8, "tuya_heartbeat"),
            .tuya_free_string = self.lookupSymbol(*const fn(?[*:0]u8) callconv(.C) void, "tuya_free_string"),
            .tuya_set_device22 = self.lookupSymbol(*const fn(?*Device, ?[*:0]const u8) callconv(.C) void, "tuya_set_device22"),
            .tuya_is_device22 = self.lookupSymbol(*const fn(?*Device) callconv(.C) i32, "tuya_is_device22"),
        };
    }

    fn toBool(v: i32) bool { return v != 0; }

    fn consumeStr(ptr: ?[*:0]u8, freeFn: *const fn(?[*:0]u8) callconv(.C) void) ?[]const u8 {
        const p = ptr orelse return null;
        const len = std.mem.len(p);
        const slice = p[0..len :0];
        const result = slice[0..len];
        freeFn(p);
        return result;
    }

    fn internalStr(ptr: ?[*:0]const u8) ?[]const u8 {
        const p = ptr orelse return null;
        return std.mem.sliceTo(p, 0);
    }

    // --- Version ---

    pub fn version(self: Library) ?[]const u8 {
        const fns = self.symbols();
        return internalStr(fns.tuya_version());
    }

    // --- Lifecycle ---

    pub fn create(self: Library, device_id: [:0]const u8, address: [:0]const u8, local_key: [:0]const u8, ver: [:0]const u8) ?*Device {
        const fns = self.symbols();
        return fns.tuya_create(device_id, address, local_key, ver);
    }

    pub fn alloc(self: Library, ver: [:0]const u8) ?*Device {
        const fns = self.symbols();
        return fns.tuya_alloc(ver);
    }

    pub fn destroy(self: Library, dev: ?*Device) void {
        const fns = self.symbols();
        fns.tuya_destroy(dev);
    }

    // --- Credentials ---

    pub fn setCredentials(self: Library, dev: ?*Device, device_id: [:0]const u8, local_key: [:0]const u8) void {
        const fns = self.symbols();
        fns.tuya_set_credentials(dev, device_id, local_key);
    }

    pub fn getDeviceId(self: Library, dev: ?*Device) ?[]const u8 {
        const fns = self.symbols();
        return internalStr(fns.tuya_get_device_id(dev));
    }

    pub fn getLocalKey(self: Library, dev: ?*Device) ?[]const u8 {
        const fns = self.symbols();
        return internalStr(fns.tuya_get_local_key(dev));
    }

    pub fn getIp(self: Library, dev: ?*Device) ?[]const u8 {
        const fns = self.symbols();
        return internalStr(fns.tuya_get_ip(dev));
    }

    // --- Connection ---

    pub fn connect(self: Library, dev: ?*Device, hostname: [:0]const u8) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_connect(dev, hostname));
    }

    pub fn disconnect(self: Library, dev: ?*Device) void {
        const fns = self.symbols();
        fns.tuya_disconnect(dev);
    }

    pub fn isConnected(self: Library, dev: ?*Device) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_is_connected(dev));
    }

    pub fn reconnect(self: Library, dev: ?*Device) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_reconnect(dev));
    }

    // --- Retry ---

    pub fn setRetryLimit(self: Library, dev: ?*Device, limit: i32) void {
        const fns = self.symbols();
        fns.tuya_set_retry_limit(dev, limit);
    }

    pub fn setRetryDelay(self: Library, dev: ?*Device, delay_ms: i32) void {
        const fns = self.symbols();
        fns.tuya_set_retry_delay(dev, delay_ms);
    }

    pub fn getRetryLimit(self: Library, dev: ?*Device) i32 {
        const fns = self.symbols();
        return fns.tuya_get_retry_limit(dev);
    }

    pub fn getRetryDelay(self: Library, dev: ?*Device) i32 {
        const fns = self.symbols();
        return fns.tuya_get_retry_delay(dev);
    }

    // --- Session negotiation ---

    pub fn negotiateSession(self: Library, dev: ?*Device, key: [:0]const u8) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_negotiate_session(dev, key));
    }

    pub fn negotiateSessionStart(self: Library, dev: ?*Device, key: [:0]const u8) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_negotiate_session_start(dev, key));
    }

    pub fn negotiateSessionFinalize(self: Library, dev: ?*Device, buf: []u8, size: i32, key: [:0]const u8) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_negotiate_session_finalize(dev, buf.ptr, size, key));
    }

    // --- State ---

    pub fn getProtocol(self: Library, dev: ?*Device) i32 {
        const fns = self.symbols();
        return fns.tuya_get_protocol(dev);
    }

    pub fn getSessionState(self: Library, dev: ?*Device) i32 {
        const fns = self.symbols();
        return fns.tuya_get_session_state(dev);
    }

    pub fn getSocketState(self: Library, dev: ?*Device) i32 {
        const fns = self.symbols();
        return fns.tuya_get_socket_state(dev);
    }

    pub fn getLastError(self: Library, dev: ?*Device) i32 {
        const fns = self.symbols();
        return fns.tuya_get_last_error(dev);
    }

    // --- Async ---

    pub fn setAsyncMode(self: Library, dev: ?*Device, flag: bool) void {
        const fns = self.symbols();
        fns.tuya_set_async_mode(dev, if (flag) 1 else 0);
    }

    pub fn isSocketReadable(self: Library, dev: ?*Device) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_is_socket_readable(dev));
    }

    pub fn isSocketWritable(self: Library, dev: ?*Device) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_is_socket_writable(dev));
    }

    pub fn setSessionReady(self: Library, dev: ?*Device) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_set_session_ready(dev));
    }

    // --- Low-level message ---

    pub fn buildMessage(self: Library, dev: ?*Device, buf: []u8, cmd: i32, payload: [:0]const u8, key: [:0]const u8) i32 {
        const fns = self.symbols();
        return fns.tuya_build_message(dev, buf.ptr, cmd, payload, key);
    }

    pub fn decodeMessage(self: Library, dev: ?*Device, buf: []u8, size: i32, key: [:0]const u8) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_decode_message(dev, buf.ptr, size, key), fns.tuya_free_string);
    }

    pub fn generatePayload(self: Library, dev: ?*Device, cmd: i32, device_id: [:0]const u8, datapoints: [:0]const u8) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_generate_payload(dev, cmd, device_id, datapoints), fns.tuya_free_string);
    }

    pub fn send(self: Library, dev: ?*Device, buf: []u8, size: i32) i32 {
        const fns = self.symbols();
        return fns.tuya_send(dev, buf.ptr, size);
    }

    pub fn receive(self: Library, dev: ?*Device, buf: []u8, maxsize: i32, minsize: i32) i32 {
        const fns = self.symbols();
        return fns.tuya_receive(dev, buf.ptr, maxsize, minsize);
    }

    // --- High-level round-trip ---

    pub fn setValueBool(self: Library, dev: ?*Device, dp: i32, value: bool) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_set_value_bool(dev, dp, if (value) 1 else 0), fns.tuya_free_string);
    }

    pub fn setValueInt(self: Library, dev: ?*Device, dp: i32, value: i32) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_set_value_int(dev, dp, value), fns.tuya_free_string);
    }

    pub fn setValueString(self: Library, dev: ?*Device, dp: i32, value: [:0]const u8) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_set_value_string(dev, dp, value), fns.tuya_free_string);
    }

    pub fn setValueFloat(self: Library, dev: ?*Device, dp: i32, value: f64) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_set_value_float(dev, dp, value), fns.tuya_free_string);
    }

    pub fn turnOn(self: Library, dev: ?*Device, switch_dp: i32) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_turn_on(dev, switch_dp), fns.tuya_free_string);
    }

    pub fn turnOff(self: Library, dev: ?*Device, switch_dp: i32) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_turn_off(dev, switch_dp), fns.tuya_free_string);
    }

    pub fn status(self: Library, dev: ?*Device) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_status(dev), fns.tuya_free_string);
    }

    pub fn heartbeat(self: Library, dev: ?*Device) ?[]const u8 {
        const fns = self.symbols();
        return consumeStr(fns.tuya_heartbeat(dev), fns.tuya_free_string);
    }

    /// Type-aware dispatcher: bool, i32, f64, or [:0]const u8.
    pub fn setValue(self: Library, dev: ?*Device, dp: i32, value: anytype) ?[]const u8 {
        const T = @TypeOf(value);
        if (T == bool) {
            return self.setValueBool(dev, dp, value);
        } else if (T == i32) {
            return self.setValueInt(dev, dp, value);
        } else if (T == f64 or T == f32) {
            return self.setValueFloat(dev, dp, @as(f64, value));
        } else if (T == []const u8 or T == [:0]const u8) {
            return self.setValueString(dev, dp, value);
        }
        @compileError("unsupported setValue type: " ++ @typeName(T));
    }

    // --- Device22 ---

    pub fn setDevice22(self: Library, dev: ?*Device, null_dps_json: ?[:0]const u8) void {
        const fns = self.symbols();
        fns.tuya_set_device22(dev, null_dps_json);
    }

    pub fn isDevice22(self: Library, dev: ?*Device) bool {
        const fns = self.symbols();
        return toBool(fns.tuya_is_device22(dev));
    }

    // --- Raw ptr access ---

    pub fn handle(self: Library) std.DynLib {
        return self._handle;
    }
};
