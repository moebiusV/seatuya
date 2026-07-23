-- seatuya.t — Terra FFI bindings for libseatuya
--
-- Terra is a low-level language embedded in Lua, built on LuaJIT's FFI.
-- This binding wraps the C API directly using Terra's C interop.
-- Requires: Terra (which includes LuaJIT)
--
-- Usage:
--   terra main()
--     var dev = seatuya.create("id", "192.168.1.100", "key", "3.4")
--     seatuya.turn_on(dev, 1)
--     seatuya.destroy(dev)
--   end
--   main()

local ffi = require("ffi")

-- Load library
local libpath = os.getenv("SEATUYA_LIB") or
  (ffi.os == "OSX" and "libseatuya.dylib" or
   ffi.os == "Windows" and "seatuya.dll" or "libseatuya.so")

ffi.cdef[[
  typedef struct tuya_device tuya_device_t;
  enum { TUYA_DEFAULT_PORT = 6668, TUYA_RECOMMENDED_BUFSIZE = 1024,
         TUYA_DEFAULT_RETRY_LIMIT = 5, TUYA_DEFAULT_RETRY_DELAY_MS = 100 };

  const char *tuya_version(void);
  tuya_device_t *tuya_create(const char*, const char*, const char*, const char*);
  tuya_device_t *tuya_alloc(const char*);
  void tuya_destroy(tuya_device_t*);
  void tuya_set_credentials(tuya_device_t*, const char*, const char*);
  const char *tuya_get_device_id(tuya_device_t*);
  const char *tuya_get_local_key(tuya_device_t*);
  const char *tuya_get_ip(tuya_device_t*);
  bool tuya_connect(tuya_device_t*, const char*);
  void tuya_disconnect(tuya_device_t*);
  bool tuya_is_connected(tuya_device_t*);
  bool tuya_reconnect(tuya_device_t*);
  void tuya_set_retry_limit(tuya_device_t*, int);
  void tuya_set_retry_delay(tuya_device_t*, int);
  int tuya_get_retry_limit(tuya_device_t*);
  int tuya_get_retry_delay(tuya_device_t*);
  bool tuya_negotiate_session(tuya_device_t*, const char*);
  bool tuya_negotiate_session_start(tuya_device_t*, const char*);
  bool tuya_negotiate_session_finalize(tuya_device_t*, unsigned char*, int, const char*);
  int tuya_get_protocol(tuya_device_t*);
  int tuya_get_session_state(tuya_device_t*);
  int tuya_get_socket_state(tuya_device_t*);
  int tuya_get_last_error(tuya_device_t*);
  void tuya_set_async_mode(tuya_device_t*, bool);
  bool tuya_is_socket_readable(tuya_device_t*);
  bool tuya_is_socket_writable(tuya_device_t*);
  bool tuya_set_session_ready(tuya_device_t*);
  int tuya_build_message(tuya_device_t*, unsigned char*, int, const char*, const char*);
  char *tuya_decode_message(tuya_device_t*, unsigned char*, int, const char*);
  char *tuya_generate_payload(tuya_device_t*, int, const char*, const char*);
  int tuya_send(tuya_device_t*, unsigned char*, int);
  int tuya_receive(tuya_device_t*, unsigned char*, int, int);
  char *tuya_set_value_bool(tuya_device_t*, int, bool);
  char *tuya_set_value_int(tuya_device_t*, int, int);
  char *tuya_set_value_string(tuya_device_t*, int, const char*);
  char *tuya_set_value_float(tuya_device_t*, int, double);
  char *tuya_turn_on(tuya_device_t*, int);
  char *tuya_turn_off(tuya_device_t*, int);
  char *tuya_status(tuya_device_t*);
  char *tuya_heartbeat(tuya_device_t*);
  void tuya_free_string(char*);
  void tuya_set_device22(tuya_device_t*, const char*);
  bool tuya_is_device22(const tuya_device_t*);
]]

local C = ffi.load(libpath)

-- Terra struct wrapping the opaque pointer
struct Dev { handle: &opaque }

-- Lua helpers (for use from Terra or Lua)
local function consume(ptr)
  if ptr == nil then return nil end
  local s = ffi.string(ptr)
  C.tuya_free_string(ptr)
  return s
end

-- Terra functions
terra seatuya.version() : rawstring
  return C.tuya_version()
end

terra seatuya.create(did: rawstring, addr: rawstring, key: rawstring, ver: rawstring) : &opaque
  return C.tuya_create(did, addr, key, ver)
end

terra seatuya.alloc(ver: rawstring) : &opaque
  return C.tuya_alloc(ver)
end

terra seatuya.destroy(dev: &opaque)
  C.tuya_destroy(dev)
end

terra seatuya.connect(dev: &opaque, host: rawstring) : bool
  return C.tuya_connect(dev, host)
end

terra seatuya.is_connected(dev: &opaque) : bool
  return C.tuya_is_connected(dev)
end

terra seatuya.disconnect(dev: &opaque)
  C.tuya_disconnect(dev)
end

terra seatuya.reconnect(dev: &opaque) : bool
  return C.tuya_reconnect(dev)
end

terra seatuya.turn_on(dev: &opaque, dp: int) : rawstring
  return C.tuya_turn_on(dev, dp)
end

terra seatuya.turn_off(dev: &opaque, dp: int) : rawstring
  return C.tuya_turn_off(dev, dp)
end

terra seatuya.status(dev: &opaque) : rawstring
  return C.tuya_status(dev)
end

terra seatuya.heartbeat(dev: &opaque) : rawstring
  return C.tuya_heartbeat(dev)
end

terra seatuya.set_device22(dev: &opaque, json: rawstring)
  C.tuya_set_device22(dev, json)
end

terra seatuya.is_device22(dev: &opaque) : bool
  return C.tuya_is_device22(dev)
end

terra seatuya.get_protocol(dev: &opaque) : int
  return C.tuya_get_protocol(dev)
end

terra seatuya.get_last_error(dev: &opaque) : int
  return C.tuya_get_last_error(dev)
end

terra seatuya.set_async_mode(dev: &opaque, flag: bool)
  C.tuya_set_async_mode(dev, flag)
end

-- Constants
local CMD_CONTROL = 7
local CMD_DP_QUERY = 10
local CMD_HEART_BEAT = 9
local CMD_STATUS = 8
local CMD_CONTROL_NEW = 13
local CMD_DP_QUERY_NEW = 16
local PROTO_V31, PROTO_V33, PROTO_V34, PROTO_V35 = 0, 1, 2, 3
local DEFAULT_PORT = 6668
local BUFSIZE = 1024

-- Expose Lua wrappers alongside Terra functions
return {
  lib = C, consume = consume,
  version = function() return ffi.string(C.tuya_version()) end,
  create = function(did, addr, key, ver) return C.tuya_create(did, addr, key, ver) end,
  destroy = function(dev) C.tuya_destroy(dev) end,
  connect = function(dev, host) return C.tuya_connect(dev, host) end,
  disconnect = function(dev) C.tuya_disconnect(dev) end,
  is_connected = function(dev) return C.tuya_is_connected(dev) end,
  reconnect = function(dev) return C.tuya_reconnect(dev) end,
  turn_on = function(dev, dp) return consume(C.tuya_turn_on(dev, dp)) end,
  turn_off = function(dev, dp) return consume(C.tuya_turn_off(dev, dp)) end,
  status = function(dev) return consume(C.tuya_status(dev)) end,
  heartbeat = function(dev) return consume(C.tuya_heartbeat(dev)) end,
  set_value = function(dev, dp, value)
    if type(value) == "boolean" then
      return consume(C.tuya_set_value_bool(dev, dp, value))
    elseif type(value) == "number" then
      if value == math.floor(value) then
        return consume(C.tuya_set_value_int(dev, dp, value))
      else
        return consume(C.tuya_set_value_float(dev, dp, value))
      end
    else
      return consume(C.tuya_set_value_string(dev, dp, tostring(value)))
    end
  end,
  set_device22 = function(dev, json) C.tuya_set_device22(dev, json) end,
  is_device22 = function(dev) return C.tuya_is_device22(dev) end,
  get_protocol = function(dev) return tonumber(C.tuya_get_protocol(dev)) end,
  get_last_error = function(dev) return tonumber(C.tuya_get_last_error(dev)) end,
  set_async_mode = function(dev, flag) C.tuya_set_async_mode(dev, flag) end,
}
