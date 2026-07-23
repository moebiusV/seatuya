# seatuya.cr -- Crystal FFI bindings for libseatuya
#
# Usage: require "./seatuya"
#
# Set SEATUYA_LIB environment variable to override the library search path,
# or install libseatuya.so in the standard library path.
# Compile with: crystal build --link-flags "-lseatuya" example.cr

require "c/dlfcn"

# Link against libseatuya at compile time.
@[Link("seatuya")]
lib LibSeatuya
  # Lifecycle
  fun tuya_version : UInt8*
  fun tuya_create(device_id : UInt8*, address : UInt8*, local_key : UInt8*, version : UInt8*) : Void*
  fun tuya_alloc(version : UInt8*) : Void*
  fun tuya_destroy(dev : Void*) : Void

  # Credentials
  fun tuya_set_credentials(dev : Void*, device_id : UInt8*, local_key : UInt8*) : Void
  fun tuya_get_device_id(dev : Void*) : UInt8*
  fun tuya_get_local_key(dev : Void*) : UInt8*
  fun tuya_get_ip(dev : Void*) : UInt8*

  # Connection
  fun tuya_connect(dev : Void*, hostname : UInt8*) : Bool
  fun tuya_disconnect(dev : Void*) : Void
  fun tuya_is_connected(dev : Void*) : Bool
  fun tuya_reconnect(dev : Void*) : Bool

  # Retry
  fun tuya_set_retry_limit(dev : Void*, limit : Int32) : Void
  fun tuya_set_retry_delay(dev : Void*, delay_ms : Int32) : Void
  fun tuya_get_retry_limit(dev : Void*) : Int32
  fun tuya_get_retry_delay(dev : Void*) : Int32

  # Session negotiation
  fun tuya_negotiate_session(dev : Void*, local_key : UInt8*) : Bool
  fun tuya_negotiate_session_start(dev : Void*, local_key : UInt8*) : Bool
  fun tuya_negotiate_session_finalize(dev : Void*, buf : UInt8*, size : Int32, local_key : UInt8*) : Bool

  # State queries
  fun tuya_get_protocol(dev : Void*) : Int32
  fun tuya_get_session_state(dev : Void*) : Int32
  fun tuya_get_socket_state(dev : Void*) : Int32
  fun tuya_get_last_error(dev : Void*) : Int32

  # Async mode
  fun tuya_set_async_mode(dev : Void*, async : Bool) : Void
  fun tuya_is_socket_readable(dev : Void*) : Bool
  fun tuya_is_socket_writable(dev : Void*) : Bool
  fun tuya_set_session_ready(dev : Void*) : Bool

  # Message building / decoding
  fun tuya_build_message(dev : Void*, buf : UInt8*, cmd : Int32, payload : UInt8*, key : UInt8*) : Int32
  fun tuya_decode_message(dev : Void*, buf : UInt8*, size : Int32, key : UInt8*) : UInt8*
  fun tuya_generate_payload(dev : Void*, cmd : Int32, device_id : UInt8*, datapoints : UInt8*) : UInt8*

  # Raw send / receive
  fun tuya_send(dev : Void*, buf : UInt8*, size : Int32) : Int32
  fun tuya_receive(dev : Void*, buf : UInt8*, maxsize : Int32, minsize : Int32) : Int32

  # device22 mode
  fun tuya_set_device22(dev : Void*, null_dps_json : UInt8*) : Void
  fun tuya_is_device22(dev : Void*) : Bool

  # High-level round-trip
  fun tuya_set_value_bool(dev : Void*, dp : Int32, value : Bool) : UInt8*
  fun tuya_set_value_int(dev : Void*, dp : Int32, value : Int32) : UInt8*
  fun tuya_set_value_string(dev : Void*, dp : Int32, value : UInt8*) : UInt8*
  fun tuya_set_value_float(dev : Void*, dp : Int32, value : Float64) : UInt8*

  fun tuya_turn_on(dev : Void*, switch_dp : Int32) : UInt8*
  fun tuya_turn_off(dev : Void*, switch_dp : Int32) : UInt8*
  fun tuya_status(dev : Void*) : UInt8*
  fun tuya_heartbeat(dev : Void*) : UInt8*

  # Memory
  fun tuya_free_string(str : UInt8*) : Void
end

module Seatuya
  CString = UInt8*

  # ------------------------------------------------------------------
  #  Library loading with SEATUYA_LIB env var support
  # ------------------------------------------------------------------

  @@loaded = false

  # Initialize the library.
  # If SEATUYA_LIB is set, dlopen from that path; otherwise rely on
  # compile-time linking via @[Link("seatuya")].
  def self.load_library
    return if @@loaded
    if path = ENV["SEATUYA_LIB"]?
      handle = LibC.dlopen(path, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
      raise "Failed to load libseatuya from #{path}" if handle.null?
    end
    @@loaded = true
  end

  # ------------------------------------------------------------------
  #  Helpers
  # ------------------------------------------------------------------

  private def self._string(ptr : UInt8*) : String?
    ptr.null? ? nil : String.new(ptr)
  end

  # Call a C function that returns a malloc'd string and auto-free it.
  private def self._free_result(ptr : UInt8*) : String?
    return nil if ptr.null?
    s = String.new(ptr)
    LibSeatuya.tuya_free_string(ptr)
    s
  end

  private def self._to_ptr(s : String?) : UInt8*
    s ? s.to_unsafe : Pointer(UInt8).null
  end

  # ------------------------------------------------------------------
  #  Version
  # ------------------------------------------------------------------

  def self.version : String
    _string(LibSeatuya.tuya_version).not_nil!
  end

  # ------------------------------------------------------------------
  #  Lifecycle
  # ------------------------------------------------------------------

  def self.create(device_id : String, address : String,
                  local_key : String, version : String) : Void*
    LibSeatuya.tuya_create(
      _to_ptr(device_id), _to_ptr(address),
      _to_ptr(local_key), _to_ptr(version))
  end

  def self.alloc(version : String) : Void*
    LibSeatuya.tuya_alloc(_to_ptr(version))
  end

  def self.destroy(dev : Void*) : Void
    LibSeatuya.tuya_destroy(dev)
  end

  # ------------------------------------------------------------------
  #  Credentials
  # ------------------------------------------------------------------

  def self.set_credentials(dev : Void*, device_id : String, local_key : String) : Void
    LibSeatuya.tuya_set_credentials(dev, _to_ptr(device_id), _to_ptr(local_key))
  end

  def self.get_device_id(dev : Void*) : String?
    _string(LibSeatuya.tuya_get_device_id(dev))
  end

  def self.get_local_key(dev : Void*) : String?
    _string(LibSeatuya.tuya_get_local_key(dev))
  end

  def self.get_ip(dev : Void*) : String?
    _string(LibSeatuya.tuya_get_ip(dev))
  end

  # ------------------------------------------------------------------
  #  Connection
  # ------------------------------------------------------------------

  def self.connect(dev : Void*, hostname : String) : Bool
    LibSeatuya.tuya_connect(dev, _to_ptr(hostname))
  end

  def self.disconnect(dev : Void*) : Void
    LibSeatuya.tuya_disconnect(dev)
  end

  def self.connected?(dev : Void*) : Bool
    LibSeatuya.tuya_is_connected(dev)
  end

  def self.reconnect(dev : Void*) : Bool
    LibSeatuya.tuya_reconnect(dev)
  end

  # ------------------------------------------------------------------
  #  Retry
  # ------------------------------------------------------------------

  def self.set_retry_limit(dev : Void*, limit : Int32) : Void
    LibSeatuya.tuya_set_retry_limit(dev, limit)
  end

  def self.set_retry_delay(dev : Void*, delay_ms : Int32) : Void
    LibSeatuya.tuya_set_retry_delay(dev, delay_ms)
  end

  def self.get_retry_limit(dev : Void*) : Int32
    LibSeatuya.tuya_get_retry_limit(dev)
  end

  def self.get_retry_delay(dev : Void*) : Int32
    LibSeatuya.tuya_get_retry_delay(dev)
  end

  # ------------------------------------------------------------------
  #  Session negotiation
  # ------------------------------------------------------------------

  def self.negotiate_session(dev : Void*, local_key : String) : Bool
    LibSeatuya.tuya_negotiate_session(dev, _to_ptr(local_key))
  end

  def self.negotiate_session_start(dev : Void*, local_key : String) : Bool
    LibSeatuya.tuya_negotiate_session_start(dev, _to_ptr(local_key))
  end

  def self.negotiate_session_finalize(dev : Void*, buf : UInt8*, size : Int32, local_key : String) : Bool
    LibSeatuya.tuya_negotiate_session_finalize(dev, buf, size, _to_ptr(local_key))
  end

  # ------------------------------------------------------------------
  #  State queries
  # ------------------------------------------------------------------

  def self.protocol(dev : Void*) : Int32
    LibSeatuya.tuya_get_protocol(dev)
  end

  def self.session_state(dev : Void*) : Int32
    LibSeatuya.tuya_get_session_state(dev)
  end

  def self.socket_state(dev : Void*) : Int32
    LibSeatuya.tuya_get_socket_state(dev)
  end

  def self.last_error(dev : Void*) : Int32
    LibSeatuya.tuya_get_last_error(dev)
  end

  # ------------------------------------------------------------------
  #  Async mode
  # ------------------------------------------------------------------

  def self.set_async_mode(dev : Void*, async : Bool) : Void
    LibSeatuya.tuya_set_async_mode(dev, async)
  end

  def self.socket_readable?(dev : Void*) : Bool
    LibSeatuya.tuya_is_socket_readable(dev)
  end

  def self.socket_writable?(dev : Void*) : Bool
    LibSeatuya.tuya_is_socket_writable(dev)
  end

  def self.set_session_ready(dev : Void*) : Bool
    LibSeatuya.tuya_set_session_ready(dev)
  end

  # ------------------------------------------------------------------
  #  Message building / decoding
  # ------------------------------------------------------------------

  def self.build_message(dev : Void*, buf : UInt8*, cmd : Int32,
                         payload : String, key : String) : Int32
    LibSeatuya.tuya_build_message(dev, buf, cmd, _to_ptr(payload), _to_ptr(key))
  end

  def self.decode_message(dev : Void*, buf : UInt8*, size : Int32, key : String) : String?
    _free_result(LibSeatuya.tuya_decode_message(dev, buf, size, _to_ptr(key)))
  end

  def self.generate_payload(dev : Void*, cmd : Int32,
                            device_id : String, datapoints : String) : String?
    _free_result(LibSeatuya.tuya_generate_payload(dev, cmd, _to_ptr(device_id), _to_ptr(datapoints)))
  end

  # ------------------------------------------------------------------
  #  Raw send / receive
  # ------------------------------------------------------------------

  def self.send(dev : Void*, buf : UInt8*, size : Int32) : Int32
    LibSeatuya.tuya_send(dev, buf, size)
  end

  def self.receive(dev : Void*, buf : UInt8*, maxsize : Int32, minsize : Int32) : Int32
    LibSeatuya.tuya_receive(dev, buf, maxsize, minsize)
  end

  # ------------------------------------------------------------------
  #  device22 mode
  # ------------------------------------------------------------------

  def self.set_device22(dev : Void*, null_dps_json : String?) : Void
    LibSeatuya.tuya_set_device22(dev, _to_ptr(null_dps_json))
  end

  def self.device22?(dev : Void*) : Bool
    LibSeatuya.tuya_is_device22(dev)
  end

  # ------------------------------------------------------------------
  #  High-level round-trip
  # ------------------------------------------------------------------

  def self.set_value_bool(dev : Void*, dp : Int32, value : Bool) : String?
    _free_result(LibSeatuya.tuya_set_value_bool(dev, dp, value))
  end

  def self.set_value_int(dev : Void*, dp : Int32, value : Int32) : String?
    _free_result(LibSeatuya.tuya_set_value_int(dev, dp, value))
  end

  def self.set_value_string(dev : Void*, dp : Int32, value : String) : String?
    _free_result(LibSeatuya.tuya_set_value_string(dev, dp, _to_ptr(value)))
  end

  def self.set_value_float(dev : Void*, dp : Int32, value : Float64) : String?
    _free_result(LibSeatuya.tuya_set_value_float(dev, dp, value))
  end

  def self.turn_on(dev : Void*, switch_dp : Int32 = 1) : String?
    _free_result(LibSeatuya.tuya_turn_on(dev, switch_dp))
  end

  def self.turn_off(dev : Void*, switch_dp : Int32 = 1) : String?
    _free_result(LibSeatuya.tuya_turn_off(dev, switch_dp))
  end

  def self.status(dev : Void*) : String?
    _free_result(LibSeatuya.tuya_status(dev))
  end

  def self.heartbeat(dev : Void*) : String?
    _free_result(LibSeatuya.tuya_heartbeat(dev))
  end

  # ------------------------------------------------------------------
  #  Type-aware set_value dispatcher
  # ------------------------------------------------------------------
  #
  #   Seatuya.set_value(dev, dp, :bool, true)
  #   Seatuya.set_value(dev, dp, :int, 42)
  #   Seatuya.set_value(dev, dp, :string, "hello")
  #   Seatuya.set_value(dev, dp, :float, 3.14)
  #
  # ------------------------------------------------------------------

  def self.set_value(dev : Void*, dp : Int32, typ : Symbol, value) : String?
    case typ
    when :bool   then set_value_bool(dev, dp, value.as(Bool))
    when :int    then set_value_int(dev, dp, value.as(Int32))
    when :string then set_value_string(dev, dp, value.as(String))
    when :float  then set_value_float(dev, dp, value.as(Float64))
    else raise "Unknown type: #{typ}"
    end
  end

  # ==================================================================
  #  Constants
  # ==================================================================

  # Protocol versions
  PROTO_V31 = 0
  PROTO_V33 = 1
  PROTO_V34 = 2
  PROTO_V35 = 3

  # Session states
  SESSION_INVALID      = 0
  SESSION_STARTING     = 1
  SESSION_FINALIZING   = 2
  SESSION_ESTABLISHED  = 3

  # Socket states
  SOCK_NO_SUCH_HOST   = 0
  SOCK_NO_SOCK_AVAIL  = 1
  SOCK_FAILED         = 2
  SOCK_DISCONNECTED   = 3
  SOCK_CONNECTING     = 4
  SOCK_CONNECTED      = 5
  SOCK_READY          = 6
  SOCK_RECEIVING      = 7

  # Misc
  DEFAULT_PORT           = 6668
  RECOMMENDED_BUFSIZE    = 1024
  DEFAULT_RETRY_LIMIT    = 5
  DEFAULT_RETRY_DELAY_MS = 100

  # Command constants (all 45)
  CMD_UDP                     = 0
  CMD_AP_CONFIG               = 1
  CMD_ACTIVE                  = 2
  CMD_BIND                    = 3
  CMD_RENAME_GW               = 4
  CMD_RENAME_DEVICE           = 5
  CMD_UNBIND                  = 6
  CMD_CONTROL                 = 7
  CMD_STATUS                  = 8
  CMD_HEART_BEAT              = 9
  CMD_DP_QUERY                = 10
  CMD_QUERY_WIFI              = 11
  CMD_TOKEN_BIND              = 12
  CMD_CONTROL_NEW             = 13
  CMD_ENABLE_WIFI             = 14
  CMD_DP_QUERY_NEW            = 16
  CMD_SCENE_EXECUTE           = 17
  CMD_UPDATEDPS               = 18
  CMD_UDP_NEW                 = 19
  CMD_AP_CONFIG_NEW           = 20
  CMD_GET_LOCAL_TIME          = 28
  CMD_WEATHER_OPEN            = 32
  CMD_WEATHER_DATA            = 33
  CMD_STATE_UPLOAD_SYN        = 34
  CMD_STATE_UPLOAD_SYN_RECV   = 35
  CMD_HEART_BEAT_STOP         = 37
  CMD_STREAM_TRANS            = 38
  CMD_GET_WIFI_STATUS         = 43
  CMD_WIFI_CONNECT_TEST       = 44
  CMD_GET_MAC                 = 45
  CMD_GET_IR_STATUS           = 46
  CMD_IR_TX_RX_TEST           = 47
  CMD_LAN_GW_ACTIVE           = 240
  CMD_LAN_SUB_DEV_REQUEST     = 241
  CMD_LAN_DELETE_SUB_DEV      = 242
  CMD_LAN_REPORT_SUB_DEV      = 243
  CMD_LAN_SCENE               = 244
  CMD_LAN_PUBLISH_CLOUD_CONFIG = 245
  CMD_LAN_PUBLISH_APP_CONFIG  = 246
  CMD_LAN_EXPORT_APP_CONFIG   = 247
  CMD_LAN_PUBLISH_SCENE_PANEL = 248
  CMD_LAN_REMOVE_GW           = 249
  CMD_LAN_CHECK_GW_UPDATE     = 250
  CMD_LAN_GW_UPDATE           = 251
  CMD_LAN_SET_GW_CHANNEL      = 252
end
