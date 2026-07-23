# seatuya.rb — Ruby FFI bindings for libseatuya
#
# Pure Ruby binding using the ffi gem.  Requires: gem install ffi
#
# Usage:
#   require_relative 'seatuya'
#   dev = Seatuya.create(device_id, "192.168.1.100", local_key, "3.4")
#   puts Seatuya.turn_on(dev, 1)
#   Seatuya.destroy(dev)

require 'ffi'

module Seatuya
  extend FFI::Library

  lib = ENV['SEATUYA_LIB'] ||
    case RbConfig::CONFIG['host_os']
    when /darwin/ then 'libseatuya.dylib'
    when /mswin|mingw/ then 'seatuya.dll'
    else 'libseatuya.so'
    end
  ffi_lib lib

  # ── Enums ──
  Command = {
    UDP: 0, AP_CONFIG: 1, ACTIVE: 2, BIND: 3, RENAME_GW: 4,
    RENAME_DEVICE: 5, UNBIND: 6, CONTROL: 7, STATUS: 8, HEART_BEAT: 9,
    DP_QUERY: 10, QUERY_WIFI: 11, TOKEN_BIND: 12, CONTROL_NEW: 13,
    ENABLE_WIFI: 14, DP_QUERY_NEW: 16, SCENE_EXECUTE: 17, UPDATEDPS: 18,
    UDP_NEW: 19, AP_CONFIG_NEW: 20, GET_LOCAL_TIME: 28, WEATHER_OPEN: 32,
    WEATHER_DATA: 33, STATE_UPLOAD_SYN: 34, STATE_UPLOAD_SYN_RECV: 35,
    HEART_BEAT_STOP: 37, STREAM_TRANS: 38, GET_WIFI_STATUS: 43,
    WIFI_CONNECT_TEST: 44, GET_MAC: 45, GET_IR_STATUS: 46, IR_TX_RX_TEST: 47,
    LAN_GW_ACTIVE: 240, LAN_SUB_DEV_REQUEST: 241, LAN_DELETE_SUB_DEV: 242,
    LAN_REPORT_SUB_DEV: 243, LAN_SCENE: 244, LAN_PUBLISH_CLOUD_CONFIG: 245,
    LAN_PUBLISH_APP_CONFIG: 246, LAN_EXPORT_APP_CONFIG: 247,
    LAN_PUBLISH_SCENE_PANEL: 248, LAN_REMOVE_GW: 249, LAN_CHECK_GW_UPDATE: 250,
    LAN_GW_UPDATE: 251, LAN_SET_GW_CHANNEL: 252,
  }.freeze

  Protocol     = { V31: 0, V33: 1, V34: 2, V35: 3 }.freeze
  SessionState = { INVALID: 0, STARTING: 1, FINALIZING: 2, ESTABLISHED: 3 }.freeze
  SocketState  = { NO_SUCH_HOST: 0, NO_SOCK_AVAIL: 1, FAILED: 2, DISCONNECTED: 3,
                   CONNECTING: 4, CONNECTED: 5, READY: 6, RECEIVING: 7 }.freeze

  DEFAULT_PORT          = 6668
  BUFSIZE              = 1024
  DEFAULT_RETRY_LIMIT  = 5
  DEFAULT_RETRY_DELAY  = 100

  # ── FFI function declarations ──
  attach_function :tuya_version, [], :string
  attach_function :tuya_create, [:string, :string, :string, :string], :pointer
  attach_function :tuya_alloc, [:string], :pointer
  attach_function :tuya_destroy, [:pointer], :void
  attach_function :tuya_set_credentials, [:pointer, :string, :string], :void
  attach_function :tuya_get_device_id, [:pointer], :string
  attach_function :tuya_get_local_key, [:pointer], :string
  attach_function :tuya_get_ip, [:pointer], :string
  attach_function :tuya_connect, [:pointer, :string], :bool
  attach_function :tuya_disconnect, [:pointer], :void
  attach_function :tuya_is_connected, [:pointer], :bool
  attach_function :tuya_reconnect, [:pointer], :bool
  attach_function :tuya_set_retry_limit, [:pointer, :int], :void
  attach_function :tuya_set_retry_delay, [:pointer, :int], :void
  attach_function :tuya_get_retry_limit, [:pointer], :int
  attach_function :tuya_get_retry_delay, [:pointer], :int
  attach_function :tuya_negotiate_session, [:pointer, :string], :bool
  attach_function :tuya_negotiate_session_start, [:pointer, :string], :bool
  attach_function :tuya_negotiate_session_finalize, [:pointer, :pointer, :int, :string], :bool
  attach_function :tuya_get_protocol, [:pointer], :int
  attach_function :tuya_get_session_state, [:pointer], :int
  attach_function :tuya_get_socket_state, [:pointer], :int
  attach_function :tuya_get_last_error, [:pointer], :int
  attach_function :tuya_set_async_mode, [:pointer, :bool], :void
  attach_function :tuya_is_socket_readable, [:pointer], :bool
  attach_function :tuya_is_socket_writable, [:pointer], :bool
  attach_function :tuya_set_session_ready, [:pointer], :bool
  attach_function :tuya_build_message, [:pointer, :pointer, :int, :string, :string], :int
  attach_function :tuya_decode_message, [:pointer, :pointer, :int, :string], :string
  attach_function :tuya_generate_payload, [:pointer, :int, :string, :string], :string
  attach_function :tuya_send, [:pointer, :pointer, :int], :int
  attach_function :tuya_receive, [:pointer, :pointer, :int, :int], :int
  attach_function :tuya_set_value_bool, [:pointer, :int, :bool], :string
  attach_function :tuya_set_value_int, [:pointer, :int, :int], :string
  attach_function :tuya_set_value_string, [:pointer, :int, :string], :string
  attach_function :tuya_set_value_float, [:pointer, :int, :double], :string
  attach_function :tuya_turn_on, [:pointer, :int], :string
  attach_function :tuya_turn_off, [:pointer, :int], :string
  attach_function :tuya_status, [:pointer], :string
  attach_function :tuya_heartbeat, [:pointer], :string
  attach_function :tuya_free_string, [:string], :void
  attach_function :tuya_set_device22, [:pointer, :string], :void
  attach_function :tuya_is_device22, [:pointer], :bool

  # ── Convenience module methods ──
  class << self
    def version; tuya_version; end

    def create(device_id, address, local_key, ver)
      dev = tuya_create(device_id, address, local_key, ver)
      dev unless dev.null?
    end

    def alloc(ver)
      dev = tuya_alloc(ver)
      dev unless dev.null?
    end

    def destroy(dev); tuya_destroy(dev); end
    def set_credentials(dev, id, key); tuya_set_credentials(dev, id, key); end
    def get_device_id(dev); tuya_get_device_id(dev); end
    def get_local_key(dev); tuya_get_local_key(dev); end
    def get_ip(dev); tuya_get_ip(dev); end
    def connect(dev, host); tuya_connect(dev, host); end
    def disconnect(dev); tuya_disconnect(dev); end
    def is_connected(dev); tuya_is_connected(dev); end
    def reconnect(dev); tuya_reconnect(dev); end
    def negotiate_session(dev, key); tuya_negotiate_session(dev, key); end
    def get_protocol(dev); tuya_get_protocol(dev); end
    def get_session_state(dev); tuya_get_session_state(dev); end
    def get_socket_state(dev); tuya_get_socket_state(dev); end
    def get_last_error(dev); tuya_get_last_error(dev); end
    def set_async_mode(dev, flag); tuya_set_async_mode(dev, flag); end

    def set_value(dev, dp, value)
      case value
      when TrueClass, FalseClass
        tuya_set_value_bool(dev, dp, value)
      when Integer
        tuya_set_value_int(dev, dp, value)
      when Float
        tuya_set_value_float(dev, dp, value)
      else
        tuya_set_value_string(dev, dp, value.to_s)
      end
    end

    def turn_on(dev, dp = 1); tuya_turn_on(dev, dp); end
    def turn_off(dev, dp = 1); tuya_turn_off(dev, dp); end
    def status(dev); tuya_status(dev); end
    def heartbeat(dev); tuya_heartbeat(dev); end
    def set_device22(dev, json); tuya_set_device22(dev, json); end
    def is_device22(dev); tuya_is_device22(dev); end

    # Low-level
    def build_message(dev, cmd, payload, key)
      buf = FFI::MemoryPointer.new(:char, BUFSIZE)
      n = tuya_build_message(dev, buf, cmd, payload, key)
      n > 0 ? buf.read_bytes(n) : nil
    end

    def decode_message(dev, buf, key)
      tuya_decode_message(dev, buf, buf.bytesize, key)
    end

    def send_frame(dev, buf)
      tuya_send(dev, buf, buf.bytesize)
    end

    def receive_frame(dev, maxsize = BUFSIZE, minsize = 0)
      buf = FFI::MemoryPointer.new(:char, maxsize)
      n = tuya_receive(dev, buf, maxsize, minsize)
      n > 0 ? buf.read_bytes(n) : nil
    end
  end
end
