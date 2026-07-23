// seatuya.odin -- Odin FFI bindings for libseatuya
//
// Loads libseatuya at runtime via dlopen/LoadLibrary.
// Set SEATUYA_LIB to a custom library path.
//
// Usage:
//   lib, ok := seatuya.load()
//   dev := lib.create(device_id, "192.168.1.100", local_key, "3.4")
//   lib.turn_on(dev, 1)
//   lib.destroy(dev)

package seatuya

import "core:os"
import "core:strings"

when ODIN_OS == .Windows {
    import "core:sys/windows"
    LibHandle :: windows.HINSTANCE
} else {
    import "core:sys/unix"
    LibHandle :: rawptr
}

// --- Constants ---

Cmd :: enum i32 {
    UDP = 0,
    AP_CONFIG = 1,
    ACTIVE = 2,
    BIND = 3,
    RENAME_GW = 4,
    RENAME_DEVICE = 5,
    UNBIND = 6,
    CONTROL = 7,
    STATUS = 8,
    HEART_BEAT = 9,
    DP_QUERY = 10,
    QUERY_WIFI = 11,
    TOKEN_BIND = 12,
    CONTROL_NEW = 13,
    ENABLE_WIFI = 14,
    DP_QUERY_NEW = 16,
    SCENE_EXECUTE = 17,
    UPDATEDPS = 18,
    UDP_NEW = 19,
    AP_CONFIG_NEW = 20,
    GET_LOCAL_TIME = 28,
    WEATHER_OPEN = 32,
    WEATHER_DATA = 33,
    STATE_UPLOAD_SYN = 34,
    STATE_UPLOAD_SYN_RECV = 35,
    HEART_BEAT_STOP = 37,
    STREAM_TRANS = 38,
    GET_WIFI_STATUS = 43,
    WIFI_CONNECT_TEST = 44,
    GET_MAC = 45,
    GET_IR_STATUS = 46,
    IR_TX_RX_TEST = 47,
    LAN_GW_ACTIVE = 240,
    LAN_SUB_DEV_REQUEST = 241,
    LAN_DELETE_SUB_DEV = 242,
    LAN_REPORT_SUB_DEV = 243,
    LAN_SCENE = 244,
    LAN_PUBLISH_CLOUD_CONFIG = 245,
    LAN_PUBLISH_APP_CONFIG = 246,
    LAN_EXPORT_APP_CONFIG = 247,
    LAN_PUBLISH_SCENE_PANEL = 248,
    LAN_REMOVE_GW = 249,
    LAN_CHECK_GW_UPDATE = 250,
    LAN_GW_UPDATE = 251,
    LAN_SET_GW_CHANNEL = 252,

    CMD_CONTROL :: CONTROL,
    CMD_DP_QUERY :: DP_QUERY,
    CMD_HEART_BEAT :: HEART_BEAT,
    CMD_STATUS :: STATUS,
    CMD_CONTROL_NEW :: CONTROL_NEW,
    CMD_DP_QUERY_NEW :: DP_QUERY_NEW,
}

Protocol :: enum i32 { V31 = 0, V33 = 1, V34 = 2, V35 = 3 }
SessionState :: enum i32 { INVALID = 0, STARTING = 1, FINALIZING = 2, ESTABLISHED = 3 }
SocketState :: enum i32 {
    NO_SUCH_HOST = 0,
    NO_SOCK_AVAIL = 1,
    FAILED = 2,
    DISCONNECTED = 3,
    CONNECTING = 4,
    CONNECTED = 5,
    READY = 6,
    RECEIVING = 7,
}

DEFAULT_PORT :: 6668
BUFSIZE :: 1024

// --- Library handle ---

Lib :: struct {
    _handle: LibHandle,

    tuya_version:             proc "c" () -> cstring,
    tuya_create:              proc "c" (device_id, address, local_key, version: cstring) -> rawptr,
    tuya_alloc:               proc "c" (version: cstring) -> rawptr,
    tuya_destroy:             proc "c" (dev: rawptr),
    tuya_set_credentials:     proc "c" (dev: rawptr, device_id, local_key: cstring),
    tuya_get_device_id:       proc "c" (dev: rawptr) -> cstring,
    tuya_get_local_key:       proc "c" (dev: rawptr) -> cstring,
    tuya_get_ip:              proc "c" (dev: rawptr) -> cstring,
    tuya_connect:             proc "c" (dev: rawptr, hostname: cstring) -> i32,
    tuya_disconnect:          proc "c" (dev: rawptr),
    tuya_is_connected:        proc "c" (dev: rawptr) -> i32,
    tuya_reconnect:           proc "c" (dev: rawptr) -> i32,
    tuya_set_retry_limit:     proc "c" (dev: rawptr, limit: i32),
    tuya_set_retry_delay:     proc "c" (dev: rawptr, delay_ms: i32),
    tuya_get_retry_limit:     proc "c" (dev: rawptr) -> i32,
    tuya_get_retry_delay:     proc "c" (dev: rawptr) -> i32,
    tuya_negotiate_session:   proc "c" (dev: rawptr, key: cstring) -> i32,
    tuya_negotiate_session_start:    proc "c" (dev: rawptr, key: cstring) -> i32,
    tuya_negotiate_session_finalize: proc "c" (dev: rawptr, buf: rawptr, size: i32, key: cstring) -> i32,
    tuya_get_protocol:        proc "c" (dev: rawptr) -> i32,
    tuya_get_session_state:   proc "c" (dev: rawptr) -> i32,
    tuya_get_socket_state:    proc "c" (dev: rawptr) -> i32,
    tuya_get_last_error:      proc "c" (dev: rawptr) -> i32,
    tuya_set_async_mode:      proc "c" (dev: rawptr, flag: i32),
    tuya_is_socket_readable:  proc "c" (dev: rawptr) -> i32,
    tuya_is_socket_writable:  proc "c" (dev: rawptr) -> i32,
    tuya_set_session_ready:   proc "c" (dev: rawptr) -> i32,
    tuya_build_message:       proc "c" (dev: rawptr, buf: rawptr, cmd: i32, payload, key: cstring) -> i32,
    tuya_decode_message:      proc "c" (dev: rawptr, buf: rawptr, size: i32, key: cstring) -> cstring,
    tuya_generate_payload:    proc "c" (dev: rawptr, cmd: i32, device_id, datapoints: cstring) -> cstring,
    tuya_send:                proc "c" (dev: rawptr, buf: rawptr, size: i32) -> i32,
    tuya_receive:             proc "c" (dev: rawptr, buf: rawptr, maxsize, minsize: i32) -> i32,
    tuya_set_value_bool:      proc "c" (dev: rawptr, dp: i32, value: i32) -> cstring,
    tuya_set_value_int:       proc "c" (dev: rawptr, dp: i32, value: i32) -> cstring,
    tuya_set_value_string:    proc "c" (dev: rawptr, dp: i32, value: cstring) -> cstring,
    tuya_set_value_float:     proc "c" (dev: rawptr, dp: i32, value: f64) -> cstring,
    tuya_turn_on:             proc "c" (dev: rawptr, switch_dp: i32) -> cstring,
    tuya_turn_off:            proc "c" (dev: rawptr, switch_dp: i32) -> cstring,
    tuya_status:              proc "c" (dev: rawptr) -> cstring,
    tuya_heartbeat:           proc "c" (dev: rawptr) -> cstring,
    tuya_free_string:         proc "c" (str: cstring),
    tuya_set_device22:        proc "c" (dev: rawptr, null_dps_json: cstring),
    tuya_is_device22:         proc "c" (dev: rawptr) -> i32,
}

// --- Platform-specific dynamic loading ---

when ODIN_OS == .Windows {
    default_lib := "seatuya.dll"

    dlopen :: proc(path: cstring) -> (LibHandle, bool) {
        h := windows.LoadLibraryA(path)
        return h, h != nil
    }

    dlsym :: proc(handle: LibHandle, name: cstring) -> rawptr {
        return windows.GetProcAddress(handle, name)
    }
} else {
    when ODIN_OS == .Darwin {
        default_lib := "libseatuya.dylib"
    } else {
        default_lib := "libseatuya.so"
    }

    dlopen :: proc(path: cstring) -> (LibHandle, bool) {
        h := unix.dlopen(path, unix.RTLD_NOW | unix.RTLD_GLOBAL)
        return h, h != nil
    }

    dlsym :: proc(handle: LibHandle, name: cstring) -> rawptr {
        return unix.dlsym(handle, name)
    }
}

// --- Public load function ---

load :: proc() -> (Lib, bool) {
    env := os.get_env("SEATUYA_LIB")
    path := env or_else default_lib

    handle, ok := dlopen(path)
    if !ok {
        return {}, false
    }

    sym :: proc(h: LibHandle, name: cstring) -> rawptr {
        return dlsym(h, name)
    }

    lib := Lib {
        _handle = handle,
        tuya_version             = auto_cast sym(handle, "tuya_version"),
        tuya_create              = auto_cast sym(handle, "tuya_create"),
        tuya_alloc               = auto_cast sym(handle, "tuya_alloc"),
        tuya_destroy             = auto_cast sym(handle, "tuya_destroy"),
        tuya_set_credentials     = auto_cast sym(handle, "tuya_set_credentials"),
        tuya_get_device_id       = auto_cast sym(handle, "tuya_get_device_id"),
        tuya_get_local_key       = auto_cast sym(handle, "tuya_get_local_key"),
        tuya_get_ip              = auto_cast sym(handle, "tuya_get_ip"),
        tuya_connect             = auto_cast sym(handle, "tuya_connect"),
        tuya_disconnect          = auto_cast sym(handle, "tuya_disconnect"),
        tuya_is_connected        = auto_cast sym(handle, "tuya_is_connected"),
        tuya_reconnect           = auto_cast sym(handle, "tuya_reconnect"),
        tuya_set_retry_limit     = auto_cast sym(handle, "tuya_set_retry_limit"),
        tuya_set_retry_delay     = auto_cast sym(handle, "tuya_set_retry_delay"),
        tuya_get_retry_limit     = auto_cast sym(handle, "tuya_get_retry_limit"),
        tuya_get_retry_delay     = auto_cast sym(handle, "tuya_get_retry_delay"),
        tuya_negotiate_session   = auto_cast sym(handle, "tuya_negotiate_session"),
        tuya_negotiate_session_start    = auto_cast sym(handle, "tuya_negotiate_session_start"),
        tuya_negotiate_session_finalize = auto_cast sym(handle, "tuya_negotiate_session_finalize"),
        tuya_get_protocol        = auto_cast sym(handle, "tuya_get_protocol"),
        tuya_get_session_state   = auto_cast sym(handle, "tuya_get_session_state"),
        tuya_get_socket_state    = auto_cast sym(handle, "tuya_get_socket_state"),
        tuya_get_last_error      = auto_cast sym(handle, "tuya_get_last_error"),
        tuya_set_async_mode      = auto_cast sym(handle, "tuya_set_async_mode"),
        tuya_is_socket_readable  = auto_cast sym(handle, "tuya_is_socket_readable"),
        tuya_is_socket_writable  = auto_cast sym(handle, "tuya_is_socket_writable"),
        tuya_set_session_ready   = auto_cast sym(handle, "tuya_set_session_ready"),
        tuya_build_message       = auto_cast sym(handle, "tuya_build_message"),
        tuya_decode_message      = auto_cast sym(handle, "tuya_decode_message"),
        tuya_generate_payload    = auto_cast sym(handle, "tuya_generate_payload"),
        tuya_send                = auto_cast sym(handle, "tuya_send"),
        tuya_receive             = auto_cast sym(handle, "tuya_receive"),
        tuya_set_value_bool      = auto_cast sym(handle, "tuya_set_value_bool"),
        tuya_set_value_int       = auto_cast sym(handle, "tuya_set_value_int"),
        tuya_set_value_string    = auto_cast sym(handle, "tuya_set_value_string"),
        tuya_set_value_float     = auto_cast sym(handle, "tuya_set_value_float"),
        tuya_turn_on             = auto_cast sym(handle, "tuya_turn_on"),
        tuya_turn_off            = auto_cast sym(handle, "tuya_turn_off"),
        tuya_status              = auto_cast sym(handle, "tuya_status"),
        tuya_heartbeat           = auto_cast sym(handle, "tuya_heartbeat"),
        tuya_free_string         = auto_cast sym(handle, "tuya_free_string"),
        tuya_set_device22        = auto_cast sym(handle, "tuya_set_device22"),
        tuya_is_device22         = auto_cast sym(handle, "tuya_is_device22"),
    };

    return lib, true
}

// --- Helper utilities ---

to_bool :: proc(v: i32) -> bool { return v != 0 }

// Consume a malloc'd C string, free it, return Odin string.
consume :: proc(lib: Lib, ptr: cstring) -> string {
    if ptr == nil { return "" }
    str := string(ptr)
    lib.tuya_free_string(ptr)
    return str
}

// Type-aware set_value dispatcher.
set_value :: proc(lib: Lib, dev: rawptr, dp: i32, value: anytype) -> string {
    #partial switch v in value {
    case bool:
        return consume(lib, lib.tuya_set_value_bool(dev, dp, v ? 1 : 0))
    case int:
        return consume(lib, lib.tuya_set_value_int(dev, dp, i32(v)))
    case f64:
        return consume(lib, lib.tuya_set_value_float(dev, dp, v))
    case f32:
        return consume(lib, lib.tuya_set_value_float(dev, dp, f64(v)))
    case string:
        return consume(lib, lib.tuya_set_value_string(dev, dp, strings.clone_to_cstring(value, context.temp_allocator)))
    case cstring:
        return consume(lib, lib.tuya_set_value_string(dev, dp, v))
    }
    return ""
}
