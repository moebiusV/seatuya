# Seatuya.jl — Julia FFI bindings for libseatuya
#
# Pure Julia module using the built-in `ccall` for every function
# in libseatuya.  No external dependencies.
#
# Usage:
#   using Seatuya
#   dev = Seatuya.create(device_id, "192.168.1.100", local_key, "3.4")
#   println(Seatuya.turn_on(dev, 1))
#   println(Seatuya.status(dev))
#   Seatuya.destroy(dev)

module Seatuya

export version, create, alloc, destroy,
       set_credentials, get_device_id, get_local_key, get_ip,
       connect, disconnect, is_connected, reconnect,
       set_retry_limit, set_retry_delay, get_retry_limit, get_retry_delay,
       negotiate_session, negotiate_session_start, negotiate_session_finalize,
       get_protocol, get_session_state, get_socket_state, get_last_error,
       set_async_mode, is_socket_readable, is_socket_writable, set_session_ready,
       build_message, decode_message, generate_payload, send_frame, receive_frame,
       set_value, turn_on, turn_off, status, heartbeat,
       set_device22, is_device22,
       Command, Protocol, SessionState, SocketState,
       DEFAULT_PORT, BUFSIZE, DEFAULT_RETRY_LIMIT, DEFAULT_RETRY_DELAY_MS

# --- Library path ---
const lib = if haskey(ENV, "SEATUYA_LIB")
    ENV["SEATUYA_LIB"]
elseif Sys.isapple()
    "libseatuya.dylib"
elseif Sys.iswindows()
    "seatuya.dll"
else
    "libseatuya.so"
end

# --- Enums ---
@enum TuyaCommand::Cint begin
    CMD_UDP = 0
    CMD_AP_CONFIG = 1
    CMD_ACTIVE = 2
    CMD_BIND = 3
    CMD_RENAME_GW = 4
    CMD_RENAME_DEVICE = 5
    CMD_UNBIND = 6
    CMD_CONTROL = 7
    CMD_STATUS = 8
    CMD_HEART_BEAT = 9
    CMD_DP_QUERY = 10
    CMD_QUERY_WIFI = 11
    CMD_TOKEN_BIND = 12
    CMD_CONTROL_NEW = 13
    CMD_ENABLE_WIFI = 14
    CMD_DP_QUERY_NEW = 16
    CMD_SCENE_EXECUTE = 17
    CMD_UPDATEDPS = 18
    CMD_UDP_NEW = 19
    CMD_AP_CONFIG_NEW = 20
    CMD_GET_LOCAL_TIME = 28
    CMD_WEATHER_OPEN = 32
    CMD_WEATHER_DATA = 33
    CMD_STATE_UPLOAD_SYN = 34
    CMD_STATE_UPLOAD_SYN_RECV = 35
    CMD_HEART_BEAT_STOP = 37
    CMD_STREAM_TRANS = 38
    CMD_GET_WIFI_STATUS = 43
    CMD_WIFI_CONNECT_TEST = 44
    CMD_GET_MAC = 45
    CMD_GET_IR_STATUS = 46
    CMD_IR_TX_RX_TEST = 47
    CMD_LAN_GW_ACTIVE = 240
    CMD_LAN_SUB_DEV_REQUEST = 241
    CMD_LAN_DELETE_SUB_DEV = 242
    CMD_LAN_REPORT_SUB_DEV = 243
    CMD_LAN_SCENE = 244
    CMD_LAN_PUBLISH_CLOUD_CONFIG = 245
    CMD_LAN_PUBLISH_APP_CONFIG = 246
    CMD_LAN_EXPORT_APP_CONFIG = 247
    CMD_LAN_PUBLISH_SCENE_PANEL = 248
    CMD_LAN_REMOVE_GW = 249
    CMD_LAN_CHECK_GW_UPDATE = 250
    CMD_LAN_GW_UPDATE = 251
    CMD_LAN_SET_GW_CHANNEL = 252
end

@enum TuyaProtocol::Cint PROTO_V31=0 PROTO_V33=1 PROTO_V34=2 PROTO_V35=3
@enum SessionState::Cint SESSION_INVALID=0 SESSION_STARTING=1 SESSION_FINALIZING=2 SESSION_ESTABLISHED=3
@enum SocketState::Cint SOCK_NO_SUCH_HOST=0 SOCK_NO_SOCK_AVAIL=1 SOCK_FAILED=2 SOCK_DISCONNECTED=3 SOCK_CONNECTING=4 SOCK_CONNECTED=5 SOCK_READY=6 SOCK_RECEIVING=7

# Export-friendly aliases
const Command = TuyaCommand; const Protocol = TuyaProtocol
const DEFAULT_PORT = 6668; const BUFSIZE = 1024
const DEFAULT_RETRY_LIMIT = 5; const DEFAULT_RETRY_DELAY_MS = 100

# --- Lifecycle ---
version() = unsafe_string(ccall((:tuya_version, lib), Cstring, ()))

function create(device_id::String, address::String, local_key::String, ver::String)
    ptr = ccall((:tuya_create, lib), Ptr{Cvoid},
                (Cstring, Cstring, Cstring, Cstring),
                device_id, address, local_key, ver)
    return ptr == C_NULL ? nothing : ptr
end

function alloc(ver::String)
    ptr = ccall((:tuya_alloc, lib), Ptr{Cvoid}, (Cstring,), ver)
    return ptr == C_NULL ? nothing : ptr
end

destroy(dev) = ccall((:tuya_destroy, lib), Cvoid, (Ptr{Cvoid},), dev)

# --- Credentials ---
function set_credentials(dev, device_id::String, local_key::String)
    ccall((:tuya_set_credentials, lib), Cvoid, (Ptr{Cvoid}, Cstring, Cstring), dev, device_id, local_key)
end
get_device_id(dev) = unsafe_string(ccall((:tuya_get_device_id, lib), Cstring, (Ptr{Cvoid},), dev))
get_local_key(dev) = unsafe_string(ccall((:tuya_get_local_key, lib), Cstring, (Ptr{Cvoid},), dev))
get_ip(dev) = unsafe_string(ccall((:tuya_get_ip, lib), Cstring, (Ptr{Cvoid},), dev))

# --- Connection ---
connect(dev, hostname::String) = ccall((:tuya_connect, lib), Bool, (Ptr{Cvoid}, Cstring), dev, hostname)
disconnect(dev) = ccall((:tuya_disconnect, lib), Cvoid, (Ptr{Cvoid},), dev)
is_connected(dev) = ccall((:tuya_is_connected, lib), Bool, (Ptr{Cvoid},), dev)
reconnect(dev) = ccall((:tuya_reconnect, lib), Bool, (Ptr{Cvoid},), dev)

# --- Retry settings ---
set_retry_limit(dev, limit::Integer) = ccall((:tuya_set_retry_limit, lib), Cvoid, (Ptr{Cvoid}, Cint), dev, limit)
set_retry_delay(dev, ms::Integer) = ccall((:tuya_set_retry_delay, lib), Cvoid, (Ptr{Cvoid}, Cint), dev, ms)
get_retry_limit(dev) = Int(ccall((:tuya_get_retry_limit, lib), Cint, (Ptr{Cvoid},), dev))
get_retry_delay(dev) = Int(ccall((:tuya_get_retry_delay, lib), Cint, (Ptr{Cvoid},), dev))

# --- Session ---
negotiate_session(dev, key::String) = ccall((:tuya_negotiate_session, lib), Bool, (Ptr{Cvoid}, Cstring), dev, key)
negotiate_session_start(dev, key::String) = ccall((:tuya_negotiate_session_start, lib), Bool, (Ptr{Cvoid}, Cstring), dev, key)
function negotiate_session_finalize(dev, buf::Vector{UInt8}, key::String)
    ccall((:tuya_negotiate_session_finalize, lib), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Cstring), dev, buf, length(buf), key)
end

# --- State queries ---
get_protocol(dev) = TuyaProtocol(ccall((:tuya_get_protocol, lib), Cint, (Ptr{Cvoid},), dev))
get_session_state(dev) = SessionState(ccall((:tuya_get_session_state, lib), Cint, (Ptr{Cvoid},), dev))
get_socket_state(dev) = SocketState(ccall((:tuya_get_socket_state, lib), Cint, (Ptr{Cvoid},), dev))
get_last_error(dev) = Int(ccall((:tuya_get_last_error, lib), Cint, (Ptr{Cvoid},), dev))

# --- Async ---
set_async_mode(dev, flag::Bool) = ccall((:tuya_set_async_mode, lib), Cvoid, (Ptr{Cvoid}, Bool), dev, flag)
is_socket_readable(dev) = ccall((:tuya_is_socket_readable, lib), Bool, (Ptr{Cvoid},), dev)
is_socket_writable(dev) = ccall((:tuya_is_socket_writable, lib), Bool, (Ptr{Cvoid},), dev)
set_session_ready(dev) = ccall((:tuya_set_session_ready, lib), Bool, (Ptr{Cvoid},), dev)

# --- Low-level ---
function build_message(dev, cmd::TuyaCommand, payload::String, key::String)
    buf = zeros(UInt8, BUFSIZE)
    n = ccall((:tuya_build_message, lib), Cint,
              (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Cstring, Cstring),
              dev, buf, Int(cmd), payload, key)
    return n > 0 ? buf[1:n] : nothing
end

function decode_message(dev, buf::Vector{UInt8}, key::String)
    ptr = ccall((:tuya_decode_message, lib), Cstring,
                (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Cstring),
                dev, buf, length(buf), key)
    if ptr == C_NULL; return nothing; end
    s = unsafe_string(ptr)
    ccall((:tuya_free_string, lib), Cvoid, (Cstring,), ptr)
    return s
end

function generate_payload(dev, cmd::TuyaCommand, device_id::String, datapoints::String="")
    ptr = ccall((:tuya_generate_payload, lib), Cstring,
                (Ptr{Cvoid}, Cint, Cstring, Cstring),
                dev, Int(cmd), device_id, datapoints)
    if ptr == C_NULL; return nothing; end
    s = unsafe_string(ptr)
    ccall((:tuya_free_string, lib), Cvoid, (Cstring,), ptr)
    return s
end

send_frame(dev, buf::Vector{UInt8}) = Int(ccall((:tuya_send, lib), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Cint), dev, buf, length(buf)))

function receive_frame(dev, maxsize::Integer=BUFSIZE, minsize::Integer=0)
    buf = zeros(UInt8, maxsize)
    n = ccall((:tuya_receive, lib), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Cint), dev, buf, maxsize, minsize)
    return n > 0 ? buf[1:n] : nothing
end

# --- High-level round-trip ---
function _consume(ptr::Ptr{Cvoid})
    if ptr == C_NULL; return nothing; end
    s = unsafe_string(ptr)
    ccall((:tuya_free_string, lib), Cvoid, (Cstring,), ptr)
    return s
end

function set_value(dev, dp::Integer, value)
    ptr = if value isa Bool
        ccall((:tuya_set_value_bool, lib), Cstring, (Ptr{Cvoid}, Cint, Bool), dev, dp, value)
    elseif value isa Integer
        ccall((:tuya_set_value_int, lib), Cstring, (Ptr{Cvoid}, Cint, Cint), dev, dp, value)
    elseif value isa AbstractFloat
        ccall((:tuya_set_value_float, lib), Cstring, (Ptr{Cvoid}, Cint, Float64), dev, dp, value)
    else
        ccall((:tuya_set_value_string, lib), Cstring, (Ptr{Cvoid}, Cint, Cstring), dev, dp, string(value))
    end
    return _consume(ptr)
end

turn_on(dev, switch_dp::Integer=1) = _consume(ccall((:tuya_turn_on, lib), Cstring, (Ptr{Cvoid}, Cint), dev, switch_dp))
turn_off(dev, switch_dp::Integer=1) = _consume(ccall((:tuya_turn_off, lib), Cstring, (Ptr{Cvoid}, Cint), dev, switch_dp))
status(dev) = _consume(ccall((:tuya_status, lib), Cstring, (Ptr{Cvoid},), dev))
heartbeat(dev) = _consume(ccall((:tuya_heartbeat, lib), Cstring, (Ptr{Cvoid},), dev))

# --- device22 ---
set_device22(dev, null_dps_json::String) = ccall((:tuya_set_device22, lib), Cvoid, (Ptr{Cvoid}, Cstring), dev, null_dps_json)
is_device22(dev) = ccall((:tuya_is_device22, lib), Bool, (Ptr{Cvoid},), dev)

end # module Seatuya
