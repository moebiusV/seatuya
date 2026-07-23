-- seatuya.ex -- Euphoria FFI bindings for libseatuya
--
-- Euphoria 4.1+ has c_func() and c_proc() for calling C functions.
-- The opaque tuya_device_t* is stored as an atom (Euphoria's
-- universal 31/63-bit value type).
--
-- Usage:
--   include seatuya.ex
--   atom dev = seatuya_create("id", "192.168.1.100", "key", "3.4")
--   printf(1, "%s\n", {seatuya_turn_on(dev, 1)})
--   seatuya_destroy(dev)

include std/os.e
include std/machine.e

-- Library handle
constant LIB = iff(platform() = LINUX, "libseatuya.so",
               iff(platform() = OSX, "libseatuya.dylib",
               iff(platform() = WIN32, "seatuya.dll", "libseatuya.so")))
atom lib = open_dll(LIB)

-- Define C function IDs
constant
    TUYA_VERSION       = define_c_func(lib, "tuya_version", {}, C_POINTER),
    TUYA_CREATE        = define_c_func(lib, "tuya_create",
                          {C_POINTER,C_POINTER,C_POINTER,C_POINTER}, C_POINTER),
    TUYA_ALLOC         = define_c_func(lib, "tuya_alloc", {C_POINTER}, C_POINTER),
    TUYA_DESTROY       = define_c_proc(lib, "tuya_destroy", {C_POINTER}),
    TUYA_CONNECT       = define_c_func(lib, "tuya_connect",
                          {C_POINTER,C_POINTER}, C_INT),
    TUYA_DISCONNECT    = define_c_proc(lib, "tuya_disconnect", {C_POINTER}),
    TUYA_IS_CONNECTED  = define_c_func(lib, "tuya_is_connected",
                          {C_POINTER}, C_INT),
    TUYA_RECONNECT     = define_c_func(lib, "tuya_reconnect",
                          {C_POINTER}, C_INT),
    TUYA_SET_CREDS     = define_c_proc(lib, "tuya_set_credentials",
                          {C_POINTER,C_POINTER,C_POINTER}),
    TUYA_GET_DEVICE_ID = define_c_func(lib, "tuya_get_device_id",
                          {C_POINTER}, C_POINTER),
    TUYA_GET_LOCAL_KEY = define_c_func(lib, "tuya_get_local_key",
                          {C_POINTER}, C_POINTER),
    TUYA_GET_IP        = define_c_func(lib, "tuya_get_ip",
                          {C_POINTER}, C_POINTER),
    TUYA_NEGOTIATE     = define_c_func(lib, "tuya_negotiate_session",
                          {C_POINTER,C_POINTER}, C_INT),
    TUYA_GET_PROTOCOL  = define_c_func(lib, "tuya_get_protocol",
                          {C_POINTER}, C_INT),
    TUYA_GET_LAST_ERR  = define_c_func(lib, "tuya_get_last_error",
                          {C_POINTER}, C_INT),
    TUYA_SET_ASYNC     = define_c_proc(lib, "tuya_set_async_mode",
                          {C_POINTER,C_INT}),
    TUYA_TURN_ON       = define_c_func(lib, "tuya_turn_on",
                          {C_POINTER,C_INT}, C_POINTER),
    TUYA_TURN_OFF      = define_c_func(lib, "tuya_turn_off",
                          {C_POINTER,C_INT}, C_POINTER),
    TUYA_STATUS        = define_c_func(lib, "tuya_status",
                          {C_POINTER}, C_POINTER),
    TUYA_HEARTBEAT     = define_c_func(lib, "tuya_heartbeat",
                          {C_POINTER}, C_POINTER),
    TUYA_SET_BOOL      = define_c_func(lib, "tuya_set_value_bool",
                          {C_POINTER,C_INT,C_INT}, C_POINTER),
    TUYA_SET_INT       = define_c_func(lib, "tuya_set_value_int",
                          {C_POINTER,C_INT,C_INT}, C_POINTER),
    TUYA_SET_STR       = define_c_func(lib, "tuya_set_value_string",
                          {C_POINTER,C_INT,C_POINTER}, C_POINTER),
    TUYA_SET_FLOAT     = define_c_func(lib, "tuya_set_value_float",
                          {C_POINTER,C_INT,C_DOUBLE}, C_POINTER),
    TUYA_FREE_STR      = define_c_proc(lib, "tuya_free_string",
                          {C_POINTER}),
    TUYA_SET_D22       = define_c_proc(lib, "tuya_set_device22",
                          {C_POINTER,C_POINTER}),
    TUYA_IS_D22        = define_c_func(lib, "tuya_is_device22",
                          {C_POINTER}, C_INT),
    TUYA_RETRY_LIMIT   = define_c_func(lib, "tuya_get_retry_limit",
                          {C_POINTER}, C_INT),
    TUYA_SET_RETRY_L   = define_c_proc(lib, "tuya_set_retry_limit",
                          {C_POINTER,C_INT}),
    TUYA_RETRY_DELAY   = define_c_func(lib, "tuya_get_retry_delay",
                          {C_POINTER}, C_INT),
    TUYA_SET_RETRY_D   = define_c_proc(lib, "tuya_set_retry_delay",
                          {C_POINTER,C_INT})

-- Constants
constant CMD_CONTROL = 7, CMD_DP_QUERY = 10, CMD_HEART_BEAT = 9,
         CMD_STATUS = 8, CMD_CONTROL_NEW = 13, CMD_DP_QUERY_NEW = 16,
         PROTO_V31 = 0, PROTO_V33 = 1, PROTO_V34 = 2, PROTO_V35 = 3,
         DEFAULT_PORT = 6668, BUFSIZE = 1024,
         DEFAULT_RETRY_LIMIT = 5, DEFAULT_RETRY_DELAY = 100

-- Helpers
function consume(atom ptr)
    if ptr = NULL then return "" end if
    sequence s = peek_string(ptr)
    c_proc(TUYA_FREE_STR, {ptr})
    return s
end function

function to_bool(atom n) return n != 0 end function

-- Public API
global function seatuya_version()
    return peek_string(c_func(TUYA_VERSION, {}))
end function

global function seatuya_create(sequence did, sequence addr, sequence key, sequence ver)
    atom d = c_func(TUYA_CREATE, {allocate_string(did,1), allocate_string(addr,1),
                                    allocate_string(key,1), allocate_string(ver,1)})
    return d
end function

global procedure seatuya_destroy(atom dev)
    c_proc(TUYA_DESTROY, {dev})
end procedure

global function seatuya_connect(atom dev, sequence host)
    return to_bool(c_func(TUYA_CONNECT, {dev, allocate_string(host,1)}))
end function

global procedure seatuya_disconnect(atom dev)
    c_proc(TUYA_DISCONNECT, {dev})
end procedure

global function seatuya_is_connected(atom dev)
    return to_bool(c_func(TUYA_IS_CONNECTED, {dev}))
end function

global function seatuya_reconnect(atom dev)
    return to_bool(c_func(TUYA_RECONNECT, {dev}))
end function

global function seatuya_turn_on(atom dev, integer dp)
    return consume(c_func(TUYA_TURN_ON, {dev, dp}))
end function

global function seatuya_turn_off(atom dev, integer dp)
    return consume(c_func(TUYA_TURN_OFF, {dev, dp}))
end function

global function seatuya_status(atom dev)
    return consume(c_func(TUYA_STATUS, {dev}))
end function

global function seatuya_heartbeat(atom dev)
    return consume(c_func(TUYA_HEARTBEAT, {dev}))
end function

global function seatuya_set_value(atom dev, integer dp, object value)
    if integer(value) then
        return consume(c_func(TUYA_SET_INT, {dev, dp, value}))
    elsif atom(value) then
        return consume(c_func(TUYA_SET_FLOAT, {dev, dp, value}))
    elsif sequence(value) then
        return consume(c_func(TUYA_SET_STR, {dev, dp, allocate_string(value,1)}))
    end if
    return ""
end function

global procedure seatuya_set_device22(atom dev, sequence json)
    c_proc(TUYA_SET_D22, {dev, allocate_string(json,1)})
end procedure

global function seatuya_is_device22(atom dev)
    return to_bool(c_func(TUYA_IS_D22, {dev}))
end function

global function seatuya_get_protocol(atom dev)
    return c_func(TUYA_GET_PROTOCOL, {dev})
end function

global function seatuya_get_last_error(atom dev)
    return c_func(TUYA_GET_LAST_ERR, {dev})
end function

global procedure seatuya_set_async_mode(atom dev, integer flag)
    c_proc(TUYA_SET_ASYNC, {dev, flag})
end procedure

global function seatuya_get_retry_limit(atom dev)
    return c_func(TUYA_RETRY_LIMIT, {dev})
end function

global procedure seatuya_set_retry_limit(atom dev, integer limit)
    c_proc(TUYA_SET_RETRY_L, {dev, limit})
end procedure

global function seatuya_get_retry_delay(atom dev)
    return c_func(TUYA_RETRY_DELAY, {dev})
end function

global procedure seatuya_set_retry_delay(atom dev, integer ms)
    c_proc(TUYA_SET_RETRY_D, {dev, ms})
end procedure
