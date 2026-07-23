////
//// seatuya.gleam -- Gleam FFI bindings for libseatuya
////
//// Pure Gleam module wrapping libseatuya via Erlang NIF.
//// Requires the compiled NIF at seatuya_nif.so / seatuya_nif.dylib
//// and the Erlang FFI wrapper seatuya_ffi.beam.
////
//// Usage:
////   import seatuya.{TuyaDevice}
////
////   let assert Ok(dev) = seatuya.create("dev_id", "ip", "key", "3.3")
////   let assert Ok(resp) = seatuya.turn_on(dev, 1)
////   io.debug(resp)
////   seatuya.destroy(dev)
////

/// Opaque handle to a Tuya device instance.
pub external type TuyaDevice

// -------------------------------------------------------------------
//  Lifecycle
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "version")
pub fn version() -> String

@external(erlang, "seatuya_ffi", "create")
pub fn create(
  device_id: String,
  address: String,
  local_key: String,
  version: String,
) -> Result(TuyaDevice, String)

@external(erlang, "seatuya_ffi", "alloc")
pub fn alloc(version: String) -> Result(TuyaDevice, String)

@external(erlang, "seatuya_ffi", "destroy")
pub fn destroy(dev: TuyaDevice) -> Nil

// -------------------------------------------------------------------
//  Credentials
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "set_credentials")
pub fn set_credentials(dev: TuyaDevice, device_id: String, local_key: String) -> Nil

@external(erlang, "seatuya_ffi", "get_device_id")
pub fn get_device_id(dev: TuyaDevice) -> String

@external(erlang, "seatuya_ffi", "get_local_key")
pub fn get_local_key(dev: TuyaDevice) -> String

@external(erlang, "seatuya_ffi", "get_ip")
pub fn get_ip(dev: TuyaDevice) -> String

// -------------------------------------------------------------------
//  Connection
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "connect")
pub fn connect(dev: TuyaDevice, hostname: String) -> Bool

@external(erlang, "seatuya_ffi", "disconnect")
pub fn disconnect(dev: TuyaDevice) -> Nil

@external(erlang, "seatuya_ffi", "is_connected")
pub fn is_connected(dev: TuyaDevice) -> Bool

@external(erlang, "seatuya_ffi", "reconnect")
pub fn reconnect(dev: TuyaDevice) -> Bool

// -------------------------------------------------------------------
//  Retry settings
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "set_retry_limit")
pub fn set_retry_limit(dev: TuyaDevice, limit: Int) -> Nil

@external(erlang, "seatuya_ffi", "set_retry_delay")
pub fn set_retry_delay(dev: TuyaDevice, delay_ms: Int) -> Nil

@external(erlang, "seatuya_ffi", "get_retry_limit")
pub fn get_retry_limit(dev: TuyaDevice) -> Int

@external(erlang, "seatuya_ffi", "get_retry_delay")
pub fn get_retry_delay(dev: TuyaDevice) -> Int

// -------------------------------------------------------------------
//  Session negotiation
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "negotiate_session")
pub fn negotiate_session(dev: TuyaDevice, local_key: String) -> Bool

@external(erlang, "seatuya_ffi", "negotiate_session_start")
pub fn negotiate_session_start(dev: TuyaDevice, local_key: String) -> Bool

@external(erlang, "seatuya_ffi", "negotiate_session_finalize")
pub fn negotiate_session_finalize(dev: TuyaDevice, buf: BitArray, local_key: String) -> Bool

// -------------------------------------------------------------------
//  State queries
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "get_protocol")
pub fn get_protocol(dev: TuyaDevice) -> Int

@external(erlang, "seatuya_ffi", "get_session_state")
pub fn get_session_state(dev: TuyaDevice) -> Int

@external(erlang, "seatuya_ffi", "get_socket_state")
pub fn get_socket_state(dev: TuyaDevice) -> Int

@external(erlang, "seatuya_ffi", "get_last_error")
pub fn get_last_error(dev: TuyaDevice) -> Int

// -------------------------------------------------------------------
//  Async mode
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "set_async_mode")
pub fn set_async_mode(dev: TuyaDevice, async: Bool) -> Nil

@external(erlang, "seatuya_ffi", "is_socket_readable")
pub fn is_socket_readable(dev: TuyaDevice) -> Bool

@external(erlang, "seatuya_ffi", "is_socket_writable")
pub fn is_socket_writable(dev: TuyaDevice) -> Bool

@external(erlang, "seatuya_ffi", "set_session_ready")
pub fn set_session_ready(dev: TuyaDevice) -> Bool

// -------------------------------------------------------------------
//  Message building / decoding / payload generation
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "build_message")
pub fn build_message(dev: TuyaDevice, cmd: Int, payload: String, key: String) -> Result(BitArray, String)

@external(erlang, "seatuya_ffi", "decode_message")
pub fn decode_message(dev: TuyaDevice, buf: BitArray, key: String) -> Result(String, String)

@external(erlang, "seatuya_ffi", "generate_payload")
pub fn generate_payload(
  dev: TuyaDevice,
  cmd: Int,
  device_id: String,
  datapoints: String,
) -> Result(String, String)

// -------------------------------------------------------------------
//  Raw send / receive
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "send")
pub fn send(dev: TuyaDevice, buf: BitArray) -> Result(Int, String)

@external(erlang, "seatuya_ffi", "receive")
pub fn receive(dev: TuyaDevice, maxsize: Int, minsize: Int) -> Result(BitArray, String)

// -------------------------------------------------------------------
//  device22 mode
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "set_device22")
pub fn set_device22(dev: TuyaDevice, null_dps_json: String) -> Nil

@external(erlang, "seatuya_ffi", "is_device22")
pub fn is_device22(dev: TuyaDevice) -> Bool

// -------------------------------------------------------------------
//  High-level round-trip operations
// -------------------------------------------------------------------

@external(erlang, "seatuya_ffi", "set_value_bool")
pub fn set_value_bool(dev: TuyaDevice, dp: Int, value: Bool) -> Result(String, String)

@external(erlang, "seatuya_ffi", "set_value_int")
pub fn set_value_int(dev: TuyaDevice, dp: Int, value: Int) -> Result(String, String)

@external(erlang, "seatuya_ffi", "set_value_string")
pub fn set_value_string(dev: TuyaDevice, dp: Int, value: String) -> Result(String, String)

@external(erlang, "seatuya_ffi", "set_value_float")
pub fn set_value_float(dev: TuyaDevice, dp: Int, value: Float) -> Result(String, String)

@external(erlang, "seatuya_ffi", "turn_on")
pub fn turn_on(dev: TuyaDevice, switch_dp: Int) -> Result(String, String)

@external(erlang, "seatuya_ffi", "turn_off")
pub fn turn_off(dev: TuyaDevice, switch_dp: Int) -> Result(String, String)

@external(erlang, "seatuya_ffi", "status")
pub fn status(dev: TuyaDevice) -> Result(String, String)

@external(erlang, "seatuya_ffi", "heartbeat")
pub fn heartbeat(dev: TuyaDevice) -> Result(String, String)

// -------------------------------------------------------------------
//  Constants
// -------------------------------------------------------------------

/// Command type: Control (standard DP write).
pub const cmd_control = 7

/// Command type: DP query (standard).
pub const cmd_dp_query = 10

/// Command type: Heartbeat.
pub const cmd_heart_beat = 9

/// Command type: Status response.
pub const cmd_status = 8

/// Command type: Control (new protocol).
pub const cmd_control_new = 13

/// Command type: DP query (new protocol).
pub const cmd_dp_query_new = 16

/// Command type: UDP.
pub const cmd_udp = 0

/// Command type: AP config.
pub const cmd_ap_config = 1

/// Command type: Active.
pub const cmd_active = 2

/// Command type: Bind.
pub const cmd_bind = 3

/// Command type: Rename gateway.
pub const cmd_rename_gw = 4

/// Command type: Rename device.
pub const cmd_rename_device = 5

/// Command type: Unbind.
pub const cmd_unbind = 6

/// Command type: Query WiFi.
pub const cmd_query_wifi = 11

/// Command type: Token bind.
pub const cmd_token_bind = 12

/// Command type: Enable WiFi.
pub const cmd_enable_wifi = 14

/// Command type: Scene execute.
pub const cmd_scene_execute = 17

/// Command type: Updated DP's.
pub const cmd_updatedps = 18

/// Command type: UDP (new protocol).
pub const cmd_udp_new = 19

/// Command type: AP config (new protocol).
pub const cmd_ap_config_new = 20

/// Command type: Get local time.
pub const cmd_get_local_time = 28

/// Command type: Weather open.
pub const cmd_weather_open = 32

/// Command type: Weather data.
pub const cmd_weather_data = 33

/// Command type: State upload syn.
pub const cmd_state_upload_syn = 34

/// Command type: State upload syn recv.
pub const cmd_state_upload_syn_recv = 35

/// Command type: Heartbeat stop.
pub const cmd_heart_beat_stop = 37

/// Command type: Stream transfer.
pub const cmd_stream_trans = 38

/// Command type: Get WiFi status.
pub const cmd_get_wifi_status = 43

/// Command type: WiFi connect test.
pub const cmd_wifi_connect_test = 44

/// Command type: Get MAC.
pub const cmd_get_mac = 45

/// Command type: Get IR status.
pub const cmd_get_ir_status = 46

/// Command type: IR TX RX test.
pub const cmd_ir_tx_rx_test = 47

/// Command type: LAN gateway active.
pub const cmd_lan_gw_active = 240

/// Command type: LAN sub-device request.
pub const cmd_lan_sub_dev_request = 241

/// Command type: LAN delete sub-device.
pub const cmd_lan_delete_sub_dev = 242

/// Command type: LAN report sub-device.
pub const cmd_lan_report_sub_dev = 243

/// Command type: LAN scene.
pub const cmd_lan_scene = 244

/// Command type: LAN publish cloud config.
pub const cmd_lan_publish_cloud_config = 245

/// Command type: LAN publish app config.
pub const cmd_lan_publish_app_config = 246

/// Command type: LAN export app config.
pub const cmd_lan_export_app_config = 247

/// Command type: LAN publish scene panel.
pub const cmd_lan_publish_scene_panel = 248

/// Command type: LAN remove gateway.
pub const cmd_lan_remove_gw = 249

/// Command type: LAN check gateway update.
pub const cmd_lan_check_gw_update = 250

/// Command type: LAN gateway update.
pub const cmd_lan_gw_update = 251

/// Command type: LAN set gateway channel.
pub const cmd_lan_set_gw_channel = 252

/// Protocol version 3.1.
pub const proto_v31 = 0

/// Protocol version 3.3.
pub const proto_v33 = 1

/// Protocol version 3.4.
pub const proto_v34 = 2

/// Protocol version 3.5.
pub const proto_v35 = 3

/// Default Tuya device port.
pub const default_port = 6668

/// Recommended buffer size for round-trip operations.
pub const bufsize = 1024

// -------------------------------------------------------------------
//  Type-aware set_value dispatcher
// -------------------------------------------------------------------

/// Represents a value of any type that can be written to a Tuya DP.
pub type Value {
  BoolVal(Bool)
  IntVal(Int)
  FloatVal(Float)
  StringVal(String)
}

/// Set a DP value, dispatching by the Gleam type of `value`.
///
/// ```gleam
/// seatuya.set_value(dev, 1, BoolVal(True))     // boolean
/// seatuya.set_value(dev, 2, IntVal(25))        // integer
/// seatuya.set_value(dev, 3, StringVal("hello")) // string
/// seatuya.set_value(dev, 4, FloatVal(23.5))    // float
/// ```
pub fn set_value(dev: TuyaDevice, dp: Int, value: Value) -> Result(String, String) {
  case value {
    BoolVal(b) -> set_value_bool(dev, dp, b)
    IntVal(i) -> set_value_int(dev, dp, i)
    FloatVal(f) -> set_value_float(dev, dp, f)
    StringVal(s) -> set_value_string(dev, dp, s)
  }
}
