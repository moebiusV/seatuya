/**
 * seatuya.d -- D FFI bindings for libseatuya
 *
 * Loads libseatuya at runtime via dlopen. Set the SEATUYA_LIB environment
 * variable to override the default library path.
 *
 * Usage:
 *   import seatuya;
 *   auto dev = tuya_create("dev_id", "192.168.1.100", "local_key", "3.3");
 *
 * Compile with: dmd -ofexample example.d seatuya.d
 */
module seatuya;

import core.sys.posix.dlfcn;
import std.string : toStringz;
import std.process : environment;

// ==================================================================
//  Internal: library loading and symbol lookup
// ==================================================================

private void* libHandle;

private void ensureLoaded()
{
    if (libHandle !is null) return;

    auto path = environment.get("SEATUYA_LIB");
    if (path.empty)
    {
        version (Windows)   path = "seatuya.dll";
        else version (OSX)  path = "libseatuya.dylib";
        else                path = "libseatuya.so";
    }

    libHandle = dlopen(path.toStringz(), RTLD_LAZY | RTLD_GLOBAL);
    assert(libHandle !is null, "Failed to load libseatuya (" ~ path ~ ")");
}

private void* getSym(const(char)* name)
{
    ensureLoaded();
    auto p = dlsym(libHandle, name);
    assert(p !is null, "Symbol not found: " ~ name[0 .. strlen(name)]);
    return p;
}

// Helper: convert C string to D string and free
private string freeResult(void* ptr)
{
    if (ptr is null) return null;
    auto cstr = cast(const(char)*)ptr;
    auto result = cstr[0 .. strlen(cstr)].idup;
    (cast(void function(char*))getSym("tuya_free_string"))(cast(char*)ptr);
    return result;
}

// ==================================================================
//  Function pointer type aliases and wrappers
// ==================================================================

// -- Version ---------------------------------------------------------

@property const(char)* tuya_version()
{
    alias Fn = const(char)* function();
    return (cast(Fn)getSym("tuya_version"))();
}

// -- Lifecycle -------------------------------------------------------

struct tuya_device {}
alias tuya_device_t = tuya_device;

tuya_device_t* tuya_create(const(char)* device_id, const(char)* address,
                           const(char)* local_key, const(char)* version)
{
    alias Fn = tuya_device_t* function(const(char)*, const(char)*,
                                        const(char)*, const(char)*);
    return (cast(Fn)getSym("tuya_create"))(device_id, address, local_key, version);
}

tuya_device_t* tuya_alloc(const(char)* version)
{
    alias Fn = tuya_device_t* function(const(char)*);
    return (cast(Fn)getSym("tuya_alloc"))(version);
}

void tuya_destroy(tuya_device_t* dev)
{
    alias Fn = void function(tuya_device_t*);
    (cast(Fn)getSym("tuya_destroy"))(dev);
}

// -- Credentials -----------------------------------------------------

void tuya_set_credentials(tuya_device_t* dev,
                          const(char)* device_id,
                          const(char)* local_key)
{
    alias Fn = void function(tuya_device_t*, const(char)*, const(char)*);
    (cast(Fn)getSym("tuya_set_credentials"))(dev, device_id, local_key);
}

@property const(char)* tuya_get_device_id(tuya_device_t* dev)
{
    alias Fn = const(char)* function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_device_id"))(dev);
}

@property const(char)* tuya_get_local_key(tuya_device_t* dev)
{
    alias Fn = const(char)* function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_local_key"))(dev);
}

@property const(char)* tuya_get_ip(tuya_device_t* dev)
{
    alias Fn = const(char)* function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_ip"))(dev);
}

// -- Connection ------------------------------------------------------

bool tuya_connect(tuya_device_t* dev, const(char)* hostname)
{
    alias Fn = bool function(tuya_device_t*, const(char)*);
    return (cast(Fn)getSym("tuya_connect"))(dev, hostname);
}

void tuya_disconnect(tuya_device_t* dev)
{
    alias Fn = void function(tuya_device_t*);
    (cast(Fn)getSym("tuya_disconnect"))(dev);
}

bool tuya_is_connected(tuya_device_t* dev)
{
    alias Fn = bool function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_is_connected"))(dev);
}

bool tuya_reconnect(tuya_device_t* dev)
{
    alias Fn = bool function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_reconnect"))(dev);
}

// -- Retry -----------------------------------------------------------

void tuya_set_retry_limit(tuya_device_t* dev, int limit)
{
    alias Fn = void function(tuya_device_t*, int);
    (cast(Fn)getSym("tuya_set_retry_limit"))(dev, limit);
}

void tuya_set_retry_delay(tuya_device_t* dev, int delay_ms)
{
    alias Fn = void function(tuya_device_t*, int);
    (cast(Fn)getSym("tuya_set_retry_delay"))(dev, delay_ms);
}

int tuya_get_retry_limit(tuya_device_t* dev)
{
    alias Fn = int function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_retry_limit"))(dev);
}

int tuya_get_retry_delay(tuya_device_t* dev)
{
    alias Fn = int function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_retry_delay"))(dev);
}

// -- Session negotiation ---------------------------------------------

bool tuya_negotiate_session(tuya_device_t* dev, const(char)* local_key)
{
    alias Fn = bool function(tuya_device_t*, const(char)*);
    return (cast(Fn)getSym("tuya_negotiate_session"))(dev, local_key);
}

bool tuya_negotiate_session_start(tuya_device_t* dev, const(char)* local_key)
{
    alias Fn = bool function(tuya_device_t*, const(char)*);
    return (cast(Fn)getSym("tuya_negotiate_session_start"))(dev, local_key);
}

bool tuya_negotiate_session_finalize(tuya_device_t* dev,
                                     ubyte* buf, int size,
                                     const(char)* local_key)
{
    alias Fn = bool function(tuya_device_t*, ubyte*, int, const(char)*);
    return (cast(Fn)getSym("tuya_negotiate_session_finalize"))(dev, buf, size, local_key);
}

// -- State queries ---------------------------------------------------

int tuya_get_protocol(tuya_device_t* dev)
{
    alias Fn = int function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_protocol"))(dev);
}

int tuya_get_session_state(tuya_device_t* dev)
{
    alias Fn = int function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_session_state"))(dev);
}

int tuya_get_socket_state(tuya_device_t* dev)
{
    alias Fn = int function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_socket_state"))(dev);
}

int tuya_get_last_error(tuya_device_t* dev)
{
    alias Fn = int function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_get_last_error"))(dev);
}

// -- Async mode ------------------------------------------------------

void tuya_set_async_mode(tuya_device_t* dev, bool async)
{
    alias Fn = void function(tuya_device_t*, bool);
    (cast(Fn)getSym("tuya_set_async_mode"))(dev, async);
}

bool tuya_is_socket_readable(tuya_device_t* dev)
{
    alias Fn = bool function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_is_socket_readable"))(dev);
}

bool tuya_is_socket_writable(tuya_device_t* dev)
{
    alias Fn = bool function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_is_socket_writable"))(dev);
}

bool tuya_set_session_ready(tuya_device_t* dev)
{
    alias Fn = bool function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_set_session_ready"))(dev);
}

// -- Message building/decoding ---------------------------------------

int tuya_build_message(tuya_device_t* dev, ubyte* buf,
                       int cmd, const(char)* payload, const(char)* key)
{
    alias Fn = int function(tuya_device_t*, ubyte*, int, const(char)*, const(char)*);
    return (cast(Fn)getSym("tuya_build_message"))(dev, buf, cmd, payload, key);
}

string tuya_decode_message(tuya_device_t* dev,
                           ubyte* buf, int size, const(char)* key)
{
    alias Fn = void* function(tuya_device_t*, ubyte*, int, const(char)*);
    return freeResult((cast(Fn)getSym("tuya_decode_message"))(dev, buf, size, key));
}

string tuya_generate_payload(tuya_device_t* dev,
                             int cmd, const(char)* device_id,
                             const(char)* datapoints)
{
    alias Fn = void* function(tuya_device_t*, int, const(char)*, const(char)*);
    return freeResult((cast(Fn)getSym("tuya_generate_payload"))(dev, cmd, device_id, datapoints));
}

// -- Raw send/receive -------------------------------------------------

int tuya_send(tuya_device_t* dev, ubyte* buf, int size)
{
    alias Fn = int function(tuya_device_t*, ubyte*, int);
    return (cast(Fn)getSym("tuya_send"))(dev, buf, size);
}

int tuya_receive(tuya_device_t* dev, ubyte* buf, int maxsize, int minsize)
{
    alias Fn = int function(tuya_device_t*, ubyte*, int, int);
    return (cast(Fn)getSym("tuya_receive"))(dev, buf, maxsize, minsize);
}

// -- device22 mode ----------------------------------------------------

void tuya_set_device22(tuya_device_t* dev, const(char)* null_dps_json)
{
    alias Fn = void function(tuya_device_t*, const(char)*);
    (cast(Fn)getSym("tuya_set_device22"))(dev, null_dps_json);
}

bool tuya_is_device22(tuya_device_t* dev)
{
    alias Fn = bool function(tuya_device_t*);
    return (cast(Fn)getSym("tuya_is_device22"))(dev);
}

// -- High-level round-trip -------------------------------------------

string tuya_set_value_bool(tuya_device_t* dev, int dp, bool value)
{
    alias Fn = void* function(tuya_device_t*, int, bool);
    return freeResult((cast(Fn)getSym("tuya_set_value_bool"))(dev, dp, value));
}

string tuya_set_value_int(tuya_device_t* dev, int dp, int value)
{
    alias Fn = void* function(tuya_device_t*, int, int);
    return freeResult((cast(Fn)getSym("tuya_set_value_int"))(dev, dp, value));
}

string tuya_set_value_string(tuya_device_t* dev, int dp, const(char)* value)
{
    alias Fn = void* function(tuya_device_t*, int, const(char)*);
    return freeResult((cast(Fn)getSym("tuya_set_value_string"))(dev, dp, value));
}

string tuya_set_value_float(tuya_device_t* dev, int dp, double value)
{
    alias Fn = void* function(tuya_device_t*, int, double);
    return freeResult((cast(Fn)getSym("tuya_set_value_float"))(dev, dp, value));
}

string tuya_turn_on(tuya_device_t* dev, int switch_dp)
{
    alias Fn = void* function(tuya_device_t*, int);
    return freeResult((cast(Fn)getSym("tuya_turn_on"))(dev, switch_dp));
}

string tuya_turn_off(tuya_device_t* dev, int switch_dp)
{
    alias Fn = void* function(tuya_device_t*, int);
    return freeResult((cast(Fn)getSym("tuya_turn_off"))(dev, switch_dp));
}

string tuya_status(tuya_device_t* dev)
{
    alias Fn = void* function(tuya_device_t*);
    return freeResult((cast(Fn)getSym("tuya_status"))(dev));
}

string tuya_heartbeat(tuya_device_t* dev)
{
    alias Fn = void* function(tuya_device_t*);
    return freeResult((cast(Fn)getSym("tuya_heartbeat"))(dev));
}

// -- Memory ----------------------------------------------------------

void tuya_free_string(char* str)
{
    alias Fn = void function(char*);
    (cast(Fn)getSym("tuya_free_string"))(str);
}

// ==================================================================
//  Type-aware set_value dispatcher
// ==================================================================
//
//  tuya_set_value(dev, dp, "bool",   true)
//  tuya_set_value(dev, dp, "int",    42)
//  tuya_set_value(dev, dp, "string", "hello")
//  tuya_set_value(dev, dp, "float",  3.14)
//

string tuya_set_value(T)(tuya_device_t* dev, int dp, string typ, T value)
{
    import std.conv : to;

    if (typ == "bool")
        return tuya_set_value_bool(dev, dp, to!bool(value));
    else if (typ == "int")
        return tuya_set_value_int(dev, dp, to!int(value));
    else if (typ == "string")
        return tuya_set_value_string(dev, dp, to!string(value).toStringz());
    else if (typ == "float")
        return tuya_set_value_float(dev, dp, to!double(value));
    else
        throw new Exception("Unknown type: " ~ typ);
}

// ==================================================================
//  Constants
// ==================================================================

// Protocol versions
enum TUYA_PROTO_V31 = 0;
enum TUYA_PROTO_V33 = 1;
enum TUYA_PROTO_V34 = 2;
enum TUYA_PROTO_V35 = 3;

// Session states
enum TUYA_SESSION_INVALID      = 0;
enum TUYA_SESSION_STARTING     = 1;
enum TUYA_SESSION_FINALIZING   = 2;
enum TUYA_SESSION_ESTABLISHED  = 3;

// Socket states
enum TUYA_SOCK_NO_SUCH_HOST  = 0;
enum TUYA_SOCK_NO_SOCK_AVAIL = 1;
enum TUYA_SOCK_FAILED        = 2;
enum TUYA_SOCK_DISCONNECTED  = 3;
enum TUYA_SOCK_CONNECTING    = 4;
enum TUYA_SOCK_CONNECTED     = 5;
enum TUYA_SOCK_READY         = 6;
enum TUYA_SOCK_RECEIVING     = 7;

// Misc
enum TUYA_DEFAULT_PORT        = 6668;
enum TUYA_RECOMMENDED_BUFSIZE = 1024;
enum TUYA_DEFAULT_RETRY_LIMIT = 5;
enum TUYA_DEFAULT_RETRY_DELAY = 100;

// Tuya command types (all 45)
enum {
    TUYA_CMD_UDP                     = 0,
    TUYA_CMD_AP_CONFIG               = 1,
    TUYA_CMD_ACTIVE                  = 2,
    TUYA_CMD_BIND                    = 3,
    TUYA_CMD_RENAME_GW               = 4,
    TUYA_CMD_RENAME_DEVICE           = 5,
    TUYA_CMD_UNBIND                  = 6,
    TUYA_CMD_CONTROL                 = 7,
    TUYA_CMD_STATUS                  = 8,
    TUYA_CMD_HEART_BEAT              = 9,
    TUYA_CMD_DP_QUERY                = 10,
    TUYA_CMD_QUERY_WIFI              = 11,
    TUYA_CMD_TOKEN_BIND              = 12,
    TUYA_CMD_CONTROL_NEW             = 13,
    TUYA_CMD_ENABLE_WIFI             = 14,
    TUYA_CMD_DP_QUERY_NEW            = 16,
    TUYA_CMD_SCENE_EXECUTE           = 17,
    TUYA_CMD_UPDATEDPS               = 18,
    TUYA_CMD_UDP_NEW                 = 19,
    TUYA_CMD_AP_CONFIG_NEW           = 20,
    TUYA_CMD_GET_LOCAL_TIME          = 28,
    TUYA_CMD_WEATHER_OPEN            = 32,
    TUYA_CMD_WEATHER_DATA            = 33,
    TUYA_CMD_STATE_UPLOAD_SYN        = 34,
    TUYA_CMD_STATE_UPLOAD_SYN_RECV   = 35,
    TUYA_CMD_HEART_BEAT_STOP         = 37,
    TUYA_CMD_STREAM_TRANS            = 38,
    TUYA_CMD_GET_WIFI_STATUS         = 43,
    TUYA_CMD_WIFI_CONNECT_TEST       = 44,
    TUYA_CMD_GET_MAC                 = 45,
    TUYA_CMD_GET_IR_STATUS           = 46,
    TUYA_CMD_IR_TX_RX_TEST           = 47,
    TUYA_CMD_LAN_GW_ACTIVE           = 240,
    TUYA_CMD_LAN_SUB_DEV_REQUEST     = 241,
    TUYA_CMD_LAN_DELETE_SUB_DEV      = 242,
    TUYA_CMD_LAN_REPORT_SUB_DEV      = 243,
    TUYA_CMD_LAN_SCENE               = 244,
    TUYA_CMD_LAN_PUBLISH_CLOUD_CONFIG = 245,
    TUYA_CMD_LAN_PUBLISH_APP_CONFIG  = 246,
    TUYA_CMD_LAN_EXPORT_APP_CONFIG   = 247,
    TUYA_CMD_LAN_PUBLISH_SCENE_PANEL = 248,
    TUYA_CMD_LAN_REMOVE_GW           = 249,
    TUYA_CMD_LAN_CHECK_GW_UPDATE     = 250,
    TUYA_CMD_LAN_GW_UPDATE           = 251,
    TUYA_CMD_LAN_SET_GW_CHANNEL      = 252,
}
