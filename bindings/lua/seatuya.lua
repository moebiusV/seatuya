-- seatuya.lua -- Lua FFI bindings for libseatuya
--
-- Pure Lua binding using LuaJIT's FFI library (also works with
-- plain Lua + luaffi).
--
-- Usage:
--   local seatuya = require("seatuya")
--   local dev = seatuya.create(deviceId, "192.168.1.100", localKey, "3.4")
--   print(seatuya.turn_on(dev, 1))
--   print(seatuya.status(dev))
--   seatuya.destroy(dev)

local ffi = require("ffi")

-- Library discovery
local libpath = os.getenv("SEATUYA_LIB") or
  (ffi.os == "OSX" and "libseatuya.dylib" or
   ffi.os == "Windows" and "seatuya.dll" or
   "libseatuya.so")

-- C declarations
ffi.cdef[[
  typedef struct tuya_device tuya_device_t;

  enum tuya_command {
    TUYA_CMD_UDP                       = 0,
    TUYA_CMD_AP_CONFIG                 = 1,
    TUYA_CMD_ACTIVE                    = 2,
    TUYA_CMD_BIND                      = 3,
    TUYA_CMD_RENAME_GW                 = 4,
    TUYA_CMD_RENAME_DEVICE             = 5,
    TUYA_CMD_UNBIND                    = 6,
    TUYA_CMD_CONTROL                   = 7,
    TUYA_CMD_STATUS                    = 8,
    TUYA_CMD_HEART_BEAT                = 9,
    TUYA_CMD_DP_QUERY                  = 10,
    TUYA_CMD_QUERY_WIFI                = 11,
    TUYA_CMD_TOKEN_BIND                = 12,
    TUYA_CMD_CONTROL_NEW               = 13,
    TUYA_CMD_ENABLE_WIFI               = 14,
    TUYA_CMD_DP_QUERY_NEW              = 16,
    TUYA_CMD_SCENE_EXECUTE             = 17,
    TUYA_CMD_UPDATEDPS                 = 18,
    TUYA_CMD_UDP_NEW                   = 19,
    TUYA_CMD_AP_CONFIG_NEW             = 20,
    TUYA_CMD_GET_LOCAL_TIME            = 28,
    TUYA_CMD_WEATHER_OPEN              = 32,
    TUYA_CMD_WEATHER_DATA              = 33,
    TUYA_CMD_STATE_UPLOAD_SYN          = 34,
    TUYA_CMD_STATE_UPLOAD_SYN_RECV     = 35,
    TUYA_CMD_HEART_BEAT_STOP           = 37,
    TUYA_CMD_STREAM_TRANS              = 38,
    TUYA_CMD_GET_WIFI_STATUS           = 43,
    TUYA_CMD_WIFI_CONNECT_TEST         = 44,
    TUYA_CMD_GET_MAC                   = 45,
    TUYA_CMD_GET_IR_STATUS             = 46,
    TUYA_CMD_IR_TX_RX_TEST             = 47,
    TUYA_CMD_LAN_GW_ACTIVE             = 240,
    TUYA_CMD_LAN_SUB_DEV_REQUEST       = 241,
    TUYA_CMD_LAN_DELETE_SUB_DEV        = 242,
    TUYA_CMD_LAN_REPORT_SUB_DEV        = 243,
    TUYA_CMD_LAN_SCENE                 = 244,
    TUYA_CMD_LAN_PUBLISH_CLOUD_CONFIG  = 245,
    TUYA_CMD_LAN_PUBLISH_APP_CONFIG    = 246,
    TUYA_CMD_LAN_EXPORT_APP_CONFIG     = 247,
    TUYA_CMD_LAN_PUBLISH_SCENE_PANEL   = 248,
    TUYA_CMD_LAN_REMOVE_GW             = 249,
    TUYA_CMD_LAN_CHECK_GW_UPDATE       = 250,
    TUYA_CMD_LAN_GW_UPDATE             = 251,
    TUYA_CMD_LAN_SET_GW_CHANNEL        = 252
  };

  enum tuya_protocol { TUYA_PROTO_V31, TUYA_PROTO_V33, TUYA_PROTO_V34, TUYA_PROTO_V35 };
  enum tuya_session_state { TUYA_SESSION_INVALID, TUYA_SESSION_STARTING, TUYA_SESSION_FINALIZING, TUYA_SESSION_ESTABLISHED };
  enum tuya_socket_state { TUYA_SOCK_NO_SUCH_HOST, TUYA_SOCK_NO_SOCK_AVAIL, TUYA_SOCK_FAILED, TUYA_SOCK_DISCONNECTED, TUYA_SOCK_CONNECTING, TUYA_SOCK_CONNECTED, TUYA_SOCK_READY, TUYA_SOCK_RECEIVING };

  enum { TUYA_DEFAULT_PORT = 6668, TUYA_RECOMMENDED_BUFSIZE = 1024,
         TUYA_DEFAULT_RETRY_LIMIT = 5, TUYA_DEFAULT_RETRY_DELAY_MS = 100 };

  const char *tuya_version(void);
  tuya_device_t *tuya_create(const char *device_id, const char *address, const char *local_key, const char *version);
  tuya_device_t *tuya_alloc(const char *version);
  void tuya_destroy(tuya_device_t *dev);
  void tuya_set_credentials(tuya_device_t *dev, const char *device_id, const char *local_key);
  const char *tuya_get_device_id(tuya_device_t *dev);
  const char *tuya_get_local_key(tuya_device_t *dev);
  const char *tuya_get_ip(tuya_device_t *dev);
  bool tuya_connect(tuya_device_t *dev, const char *hostname);
  void tuya_disconnect(tuya_device_t *dev);
  bool tuya_is_connected(tuya_device_t *dev);
  bool tuya_reconnect(tuya_device_t *dev);
  void tuya_set_retry_limit(tuya_device_t *dev, int limit);
  void tuya_set_retry_delay(tuya_device_t *dev, int delay_ms);
  int tuya_get_retry_limit(tuya_device_t *dev);
  int tuya_get_retry_delay(tuya_device_t *dev);
  bool tuya_negotiate_session(tuya_device_t *dev, const char *local_key);
  bool tuya_negotiate_session_start(tuya_device_t *dev, const char *local_key);
  bool tuya_negotiate_session_finalize(tuya_device_t *dev, unsigned char *buf, int size, const char *local_key);
  enum tuya_protocol tuya_get_protocol(tuya_device_t *dev);
  enum tuya_session_state tuya_get_session_state(tuya_device_t *dev);
  enum tuya_socket_state tuya_get_socket_state(tuya_device_t *dev);
  int tuya_get_last_error(tuya_device_t *dev);
  void tuya_set_async_mode(tuya_device_t *dev, bool async);
  bool tuya_is_socket_readable(tuya_device_t *dev);
  bool tuya_is_socket_writable(tuya_device_t *dev);
  bool tuya_set_session_ready(tuya_device_t *dev);
  int tuya_build_message(tuya_device_t *dev, unsigned char *buf, enum tuya_command cmd, const char *payload, const char *key);
  char *tuya_decode_message(tuya_device_t *dev, unsigned char *buf, int size, const char *key);
  char *tuya_generate_payload(tuya_device_t *dev, enum tuya_command cmd, const char *device_id, const char *datapoints);
  int tuya_send(tuya_device_t *dev, unsigned char *buf, int size);
  int tuya_receive(tuya_device_t *dev, unsigned char *buf, int maxsize, int minsize);
  char *tuya_set_value_bool(tuya_device_t *dev, int dp, bool value);
  char *tuya_set_value_int(tuya_device_t *dev, int dp, int value);
  char *tuya_set_value_string(tuya_device_t *dev, int dp, const char *value);
  char *tuya_set_value_float(tuya_device_t *dev, int dp, double value);
  char *tuya_turn_on(tuya_device_t *dev, int switch_dp);
  char *tuya_turn_off(tuya_device_t *dev, int switch_dp);
  char *tuya_status(tuya_device_t *dev);
  char *tuya_heartbeat(tuya_device_t *dev);
  void tuya_free_string(char *str);
  void tuya_set_device22(tuya_device_t *dev, const char *null_dps_json);
  bool tuya_is_device22(const tuya_device_t *dev);
]]

local C = ffi.load(libpath)

local M = {}

-- Helper: consume malloc'd C string into Lua string (auto-free)
local function consume_cstr(ptr)
  if ptr == nil then return nil end
  local s = ffi.string(ptr)
  C.tuya_free_string(ptr)
  return s
end

-- Lifecycle
function M.version() return ffi.string(C.tuya_version()) end

function M.create(device_id, address, local_key, ver)
  return C.tuya_create(device_id, address, local_key, ver)
end

function M.alloc(ver)
  return C.tuya_alloc(ver)
end

function M.destroy(dev)
  C.tuya_destroy(dev)
end

-- Credentials
function M.set_credentials(dev, device_id, local_key)
  C.tuya_set_credentials(dev, device_id, local_key)
end

function M.get_device_id(dev)
  local ptr = C.tuya_get_device_id(dev)
  return ptr ~= nil and ffi.string(ptr) or nil
end

function M.get_local_key(dev)
  local ptr = C.tuya_get_local_key(dev)
  return ptr ~= nil and ffi.string(ptr) or nil
end

function M.get_ip(dev)
  local ptr = C.tuya_get_ip(dev)
  return ptr ~= nil and ffi.string(ptr) or nil
end

-- Connection
function M.connect(dev, hostname) return C.tuya_connect(dev, hostname) end
function M.disconnect(dev) C.tuya_disconnect(dev) end
function M.is_connected(dev) return C.tuya_is_connected(dev) end
function M.reconnect(dev) return C.tuya_reconnect(dev) end

-- Retry
function M.set_retry_limit(dev, limit) C.tuya_set_retry_limit(dev, limit) end
function M.set_retry_delay(dev, ms) C.tuya_set_retry_delay(dev, ms) end
function M.get_retry_limit(dev) return C.tuya_get_retry_limit(dev) end
function M.get_retry_delay(dev) return C.tuya_get_retry_delay(dev) end

-- Session
function M.negotiate_session(dev, key) return C.tuya_negotiate_session(dev, key) end

-- State queries
function M.get_protocol(dev) return tonumber(C.tuya_get_protocol(dev)) end
function M.get_session_state(dev) return tonumber(C.tuya_get_session_state(dev)) end
function M.get_socket_state(dev) return tonumber(C.tuya_get_socket_state(dev)) end
function M.get_last_error(dev) return tonumber(C.tuya_get_last_error(dev)) end

-- Async
function M.set_async_mode(dev, flag) C.tuya_set_async_mode(dev, flag) end

-- Low-level
function M.build_message(dev, cmd, payload, key)
  local buf = ffi.new("unsigned char[?]", 1024)
  local n = C.tuya_build_message(dev, buf, cmd, payload, key)
  if n > 0 then return ffi.string(buf, n) end
  return nil
end

function M.decode_message(dev, buf, key)
  return consume_cstr(C.tuya_decode_message(dev, buf, #buf, key))
end

function M.generate_payload(dev, cmd, device_id, datapoints)
  return consume_cstr(C.tuya_generate_payload(dev, cmd, device_id, datapoints or ""))
end

function M.send_frame(dev, buf)
  return tonumber(C.tuya_send(dev, buf, #buf))
end

function M.receive_frame(dev, maxsize, minsize)
  maxsize = maxsize or 1024
  minsize = minsize or 0
  local buf = ffi.new("unsigned char[?]", maxsize)
  local n = C.tuya_receive(dev, buf, maxsize, minsize)
  if n > 0 then return ffi.string(buf, n) end
  return nil
end

-- High-level round-trip
function M.set_value(dev, dp, value)
  local ptr
  if type(value) == "boolean" then
    ptr = C.tuya_set_value_bool(dev, dp, value)
  elseif type(value) == "number" then
    if value == math.floor(value) then
      ptr = C.tuya_set_value_int(dev, dp, value)
    else
      ptr = C.tuya_set_value_float(dev, dp, value)
    end
  else
    ptr = C.tuya_set_value_string(dev, dp, tostring(value))
  end
  return consume_cstr(ptr)
end

function M.turn_on(dev, switch_dp)
  return consume_cstr(C.tuya_turn_on(dev, switch_dp or 1))
end

function M.turn_off(dev, switch_dp)
  return consume_cstr(C.tuya_turn_off(dev, switch_dp or 1))
end

function M.status(dev)
  return consume_cstr(C.tuya_status(dev))
end

function M.heartbeat(dev)
  return consume_cstr(C.tuya_heartbeat(dev))
end

-- device22
function M.set_device22(dev, null_dps_json)
  C.tuya_set_device22(dev, null_dps_json)
end

function M.is_device22(dev)
  return C.tuya_is_device22(dev)
end

-- Constants
M.Command = {
  UDP=0, AP_CONFIG=1, ACTIVE=2, BIND=3, RENAME_GW=4, RENAME_DEVICE=5,
  UNBIND=6, CONTROL=7, STATUS=8, HEART_BEAT=9, DP_QUERY=10,
  QUERY_WIFI=11, TOKEN_BIND=12, CONTROL_NEW=13, ENABLE_WIFI=14,
  DP_QUERY_NEW=16, SCENE_EXECUTE=17, UPDATEDPS=18, UDP_NEW=19,
  AP_CONFIG_NEW=20, GET_LOCAL_TIME=28, WEATHER_OPEN=32, WEATHER_DATA=33,
  STATE_UPLOAD_SYN=34, STATE_UPLOAD_SYN_RECV=35, HEART_BEAT_STOP=37,
  STREAM_TRANS=38, GET_WIFI_STATUS=43, WIFI_CONNECT_TEST=44, GET_MAC=45,
  GET_IR_STATUS=46, IR_TX_RX_TEST=47, LAN_GW_ACTIVE=240,
  LAN_SUB_DEV_REQUEST=241, LAN_DELETE_SUB_DEV=242, LAN_REPORT_SUB_DEV=243,
  LAN_SCENE=244, LAN_PUBLISH_CLOUD_CONFIG=245, LAN_PUBLISH_APP_CONFIG=246,
  LAN_EXPORT_APP_CONFIG=247, LAN_PUBLISH_SCENE_PANEL=248, LAN_REMOVE_GW=249,
  LAN_CHECK_GW_UPDATE=250, LAN_GW_UPDATE=251, LAN_SET_GW_CHANNEL=252,
}
M.Protocol = { V31=0, V33=1, V34=2, V35=3 }
M.SessionState = { INVALID=0, STARTING=1, FINALIZING=2, ESTABLISHED=3 }
M.SocketState = { NO_SUCH_HOST=0, NO_SOCK_AVAIL=1, FAILED=2, DISCONNECTED=3,
                  CONNECTING=4, CONNECTED=5, READY=6, RECEIVING=7 }
M.DEFAULT_PORT = 6668
M.BUFSIZE = 1024

return M
