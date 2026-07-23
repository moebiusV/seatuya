// seatuya.vala -- Vala C FFI bindings for libseatuya
//
// Pure Vala binding using [CCode] attributes for C interop.
// Compiles to native code via the Vala-to-C compiler.
//
// Usage:
//   var dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4");
//   print(Seatuya.turnOn(dev, 1));
//   Seatuya.destroy(dev);

namespace Seatuya {

  // ---- Opaque device type -----------------------------------------------

  [Compact, Immutable]
  [CCode (cname = "tuya_device_t", has_type_id = false)]
  public struct Device {
  }

  // ---- Library loading ---------------------------------------------------

  [CCode (cname = "dlopen", cheader_filename = "dlfcn.h")]
  private static void* dlopen(string filename, int flags);

  [CCode (cname = "RTLD_NOW")]
  private const int RTLD_NOW;

  [CCode (cname = "RTLD_GLOBAL")]
  private const int RTLD_GLOBAL;

  private static bool _loaded = false;

  private static bool try_load(string path) {
    void* h = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    return h != null;
  }

  private static void ensure_loaded() {
    if (_loaded) return;
    _loaded = true;
    string? path = Environment.get_variable("SEATUYA_LIB");
    if (path != null) {
      if (!try_load(path))
        warning("seatuya: could not load SEATUYA_LIB=%s", path);
      return;
    }
    // Try platform suffixes in order
    if (!try_load("libseatuya.so") &&
        !try_load("libseatuya.dylib") &&
        !try_load("seatuya.dll")) {
      warning("seatuya: could not find libseatuya on any standard path");
    }
  }

  // ---- Raw C bindings (with [CCode] for C interop) ----------------------

  [CCode (cname = "tuya_version")]
  private static unowned string _version();

  [CCode (cname = "tuya_create")]
  private static Device? _create(string device_id, string address, string local_key, string version);

  [CCode (cname = "tuya_alloc")]
  private static Device? _alloc(string version);

  [CCode (cname = "tuya_destroy")]
  private static void _destroy(Device dev);

  [CCode (cname = "tuya_set_credentials")]
  private static void _set_credentials(Device dev, string device_id, string local_key);

  [CCode (cname = "tuya_get_device_id")]
  private static unowned string _get_device_id(Device dev);

  [CCode (cname = "tuya_get_local_key")]
  private static unowned string _get_local_key(Device dev);

  [CCode (cname = "tuya_get_ip")]
  private static unowned string _get_ip(Device dev);

  [CCode (cname = "tuya_connect")]
  private static int _connect(Device dev, string hostname);

  [CCode (cname = "tuya_disconnect")]
  private static void _disconnect(Device dev);

  [CCode (cname = "tuya_is_connected")]
  private static int _is_connected(Device dev);

  [CCode (cname = "tuya_reconnect")]
  private static int _reconnect(Device dev);

  [CCode (cname = "tuya_set_retry_limit")]
  private static void _set_retry_limit(Device dev, int limit);

  [CCode (cname = "tuya_set_retry_delay")]
  private static void _set_retry_delay(Device dev, int delay_ms);

  [CCode (cname = "tuya_get_retry_limit")]
  private static int _get_retry_limit(Device dev);

  [CCode (cname = "tuya_get_retry_delay")]
  private static int _get_retry_delay(Device dev);

  [CCode (cname = "tuya_negotiate_session")]
  private static int _negotiate_session(Device dev, string local_key);

  [CCode (cname = "tuya_negotiate_session_start")]
  private static int _negotiate_session_start(Device dev, string local_key);

  [CCode (cname = "tuya_negotiate_session_finalize")]
  private static int _negotiate_session_finalize(Device dev, void* buf, int size, string local_key);

  [CCode (cname = "tuya_get_protocol")]
  private static int _get_protocol(Device dev);

  [CCode (cname = "tuya_get_session_state")]
  private static int _get_session_state(Device dev);

  [CCode (cname = "tuya_get_socket_state")]
  private static int _get_socket_state(Device dev);

  [CCode (cname = "tuya_get_last_error")]
  private static int _get_last_error(Device dev);

  [CCode (cname = "tuya_set_async_mode")]
  private static void _set_async_mode(Device dev, int flag);

  [CCode (cname = "tuya_is_socket_readable")]
  private static int _is_socket_readable(Device dev);

  [CCode (cname = "tuya_is_socket_writable")]
  private static int _is_socket_writable(Device dev);

  [CCode (cname = "tuya_set_session_ready")]
  private static int _set_session_ready(Device dev);

  [CCode (cname = "tuya_build_message")]
  private static int _build_message(Device dev, void* buf, int cmd, string payload, string key);

  [CCode (cname = "tuya_decode_message")]
  private static unowned string _decode_message(Device dev, void* buf, int size, string key);

  [CCode (cname = "tuya_generate_payload")]
  private static unowned string _generate_payload(Device dev, int cmd, string device_id, string datapoints);

  [CCode (cname = "tuya_send")]
  private static int _send(Device dev, void* buf, int size);

  [CCode (cname = "tuya_receive")]
  private static int _receive(Device dev, void* buf, int maxsize, int minsize);

  [CCode (cname = "tuya_set_value_bool")]
  private static unowned string _set_value_bool(Device dev, int dp, int value);

  [CCode (cname = "tuya_set_value_int")]
  private static unowned string _set_value_int(Device dev, int dp, int value);

  [CCode (cname = "tuya_set_value_string")]
  private static unowned string _set_value_string(Device dev, int dp, string value);

  [CCode (cname = "tuya_set_value_float")]
  private static unowned string _set_value_float(Device dev, int dp, double value);

  [CCode (cname = "tuya_turn_on")]
  private static unowned string _turn_on(Device dev, int switch_dp);

  [CCode (cname = "tuya_turn_off")]
  private static unowned string _turn_off(Device dev, int switch_dp);

  [CCode (cname = "tuya_status")]
  private static unowned string _status(Device dev);

  [CCode (cname = "tuya_heartbeat")]
  private static unowned string _heartbeat(Device dev);

  [CCode (cname = "tuya_free_string")]
  private static void _free_string([CCode (type = "gchar*")] unowned string str);

  [CCode (cname = "tuya_set_device22")]
  private static void _set_device22(Device dev, string null_dps_json);

  [CCode (cname = "tuya_is_device22")]
  private static int _is_device22(Device dev);

  // ---- Helper: consume a malloc'd C string ------------------------------

  private static string? consume(unowned string raw) {
    if (raw == null) return null;
    string copy = raw;
    _free_string(raw);
    return copy;
  }

  // ---- Public API -------------------------------------------------------

  // Version
  public string version() {
    ensure_loaded();
    return _version();
  }

  // Lifecycle
  public Device? create(string device_id, string address, string local_key, string ver) {
    ensure_loaded();
    return _create(device_id, address, local_key, ver);
  }

  public Device? alloc(string ver) {
    ensure_loaded();
    return _alloc(ver);
  }

  public void destroy(Device dev) {
    _destroy(dev);
  }

  // Credentials
  public void set_credentials(Device dev, string device_id, string local_key) {
    _set_credentials(dev, device_id, local_key);
  }

  public string get_device_id(Device dev) {
    return _get_device_id(dev);
  }

  public string get_local_key(Device dev) {
    return _get_local_key(dev);
  }

  public string get_ip(Device dev) {
    return _get_ip(dev);
  }

  // Connection
  public bool connect(Device dev, string hostname) {
    return _connect(dev, hostname) != 0;
  }

  public void disconnect(Device dev) {
    _disconnect(dev);
  }

  public bool is_connected(Device dev) {
    return _is_connected(dev) != 0;
  }

  public bool reconnect(Device dev) {
    return _reconnect(dev) != 0;
  }

  // Retry
  public void set_retry_limit(Device dev, int limit) {
    _set_retry_limit(dev, limit);
  }

  public void set_retry_delay(Device dev, int delay_ms) {
    _set_retry_delay(dev, delay_ms);
  }

  public int get_retry_limit(Device dev) {
    return _get_retry_limit(dev);
  }

  public int get_retry_delay(Device dev) {
    return _get_retry_delay(dev);
  }

  // Session negotiation
  public bool negotiate_session(Device dev, string local_key) {
    return _negotiate_session(dev, local_key) != 0;
  }

  public bool negotiate_session_start(Device dev, string local_key) {
    return _negotiate_session_start(dev, local_key) != 0;
  }

  public bool negotiate_session_finalize(Device dev, void* buf, int size, string local_key) {
    return _negotiate_session_finalize(dev, buf, size, local_key) != 0;
  }

  // State queries
  public int get_protocol(Device dev) {
    return _get_protocol(dev);
  }

  public int get_session_state(Device dev) {
    return _get_session_state(dev);
  }

  public int get_socket_state(Device dev) {
    return _get_socket_state(dev);
  }

  public int get_last_error(Device dev) {
    return _get_last_error(dev);
  }

  // Async mode
  public void set_async_mode(Device dev, bool flag) {
    _set_async_mode(dev, flag ? 1 : 0);
  }

  public bool is_socket_readable(Device dev) {
    return _is_socket_readable(dev) != 0;
  }

  public bool is_socket_writable(Device dev) {
    return _is_socket_writable(dev) != 0;
  }

  public bool set_session_ready(Device dev) {
    return _set_session_ready(dev) != 0;
  }

  // Message building and decoding
  public int build_message(Device dev, void* buf, int cmd, string payload, string key) {
    return _build_message(dev, buf, cmd, payload, key);
  }

  public string? decode_message(Device dev, void* buf, int size, string key) {
    return consume(_decode_message(dev, buf, size, key));
  }

  public string? generate_payload(Device dev, int cmd, string device_id, string datapoints) {
    return consume(_generate_payload(dev, cmd, device_id, datapoints));
  }

  // Raw send/receive
  public int send_frame(Device dev, void* buf, int size) {
    return _send(dev, buf, size);
  }

  public int receive_frame(Device dev, void* buf, int maxsize, int minsize) {
    return _receive(dev, buf, maxsize, minsize);
  }

  // device22 mode
  public void set_device22(Device dev, string null_dps_json) {
    _set_device22(dev, null_dps_json);
  }

  public bool is_device22(Device dev) {
    return _is_device22(dev) != 0;
  }

  // High-level round-trip
  public string? set_value_bool(Device dev, int dp, bool value) {
    return consume(_set_value_bool(dev, dp, value ? 1 : 0));
  }

  public string? set_value_int(Device dev, int dp, int value) {
    return consume(_set_value_int(dev, dp, value));
  }

  public string? set_value_string(Device dev, int dp, string value) {
    return consume(_set_value_string(dev, dp, value));
  }

  public string? set_value_float(Device dev, int dp, double value) {
    return consume(_set_value_float(dev, dp, value));
  }

  /** Type-aware setValue dispatcher (overloaded). */
  public string? set_value(Device dev, int dp, bool value) {
    return set_value_bool(dev, dp, value);
  }

  public string? set_value(Device dev, int dp, int value) {
    return set_value_int(dev, dp, value);
  }

  public string? set_value(Device dev, int dp, double value) {
    return set_value_float(dev, dp, value);
  }

  public string? set_value(Device dev, int dp, string value) {
    return set_value_string(dev, dp, value);
  }

  public string? turn_on(Device dev, int switch_dp = 1) {
    return consume(_turn_on(dev, switch_dp));
  }

  public string? turn_off(Device dev, int switch_dp = 1) {
    return consume(_turn_off(dev, switch_dp));
  }

  public string? status(Device dev) {
    return consume(_status(dev));
  }

  public string? heartbeat(Device dev) {
    return consume(_heartbeat(dev));
  }

  // ---- Constants --------------------------------------------------------

  // Command types
  public const int CMD_UDP = 0;
  public const int CMD_AP_CONFIG = 1;
  public const int CMD_ACTIVE = 2;
  public const int CMD_BIND = 3;
  public const int CMD_RENAME_GW = 4;
  public const int CMD_RENAME_DEVICE = 5;
  public const int CMD_UNBIND = 6;
  public const int CMD_CONTROL = 7;
  public const int CMD_STATUS = 8;
  public const int CMD_HEART_BEAT = 9;
  public const int CMD_DP_QUERY = 10;
  public const int CMD_QUERY_WIFI = 11;
  public const int CMD_TOKEN_BIND = 12;
  public const int CMD_CONTROL_NEW = 13;
  public const int CMD_ENABLE_WIFI = 14;
  public const int CMD_DP_QUERY_NEW = 16;
  public const int CMD_SCENE_EXECUTE = 17;
  public const int CMD_UPDATEDPS = 18;
  public const int CMD_UDP_NEW = 19;
  public const int CMD_AP_CONFIG_NEW = 20;
  public const int CMD_GET_LOCAL_TIME = 28;
  public const int CMD_WEATHER_OPEN = 32;
  public const int CMD_WEATHER_DATA = 33;
  public const int CMD_STATE_UPLOAD_SYN = 34;
  public const int CMD_STATE_UPLOAD_SYN_RECV = 35;
  public const int CMD_HEART_BEAT_STOP = 37;
  public const int CMD_STREAM_TRANS = 38;
  public const int CMD_GET_WIFI_STATUS = 43;
  public const int CMD_WIFI_CONNECT_TEST = 44;
  public const int CMD_GET_MAC = 45;
  public const int CMD_GET_IR_STATUS = 46;
  public const int CMD_IR_TX_RX_TEST = 47;
  public const int CMD_LAN_GW_ACTIVE = 240;
  public const int CMD_LAN_SUB_DEV_REQUEST = 241;
  public const int CMD_LAN_DELETE_SUB_DEV = 242;
  public const int CMD_LAN_REPORT_SUB_DEV = 243;
  public const int CMD_LAN_SCENE = 244;
  public const int CMD_LAN_PUBLISH_CLOUD_CONFIG = 245;
  public const int CMD_LAN_PUBLISH_APP_CONFIG = 246;
  public const int CMD_LAN_EXPORT_APP_CONFIG = 247;
  public const int CMD_LAN_PUBLISH_SCENE_PANEL = 248;
  public const int CMD_LAN_REMOVE_GW = 249;
  public const int CMD_LAN_CHECK_GW_UPDATE = 250;
  public const int CMD_LAN_GW_UPDATE = 251;
  public const int CMD_LAN_SET_GW_CHANNEL = 252;

  // Protocol versions
  public const int PROTO_V31 = 0;
  public const int PROTO_V33 = 1;
  public const int PROTO_V34 = 2;
  public const int PROTO_V35 = 3;

  // Session states
  public const int SESSION_INVALID = 0;
  public const int SESSION_STARTING = 1;
  public const int SESSION_FINALIZING = 2;
  public const int SESSION_ESTABLISHED = 3;

  // Socket states
  public const int SOCK_NO_SUCH_HOST = 0;
  public const int SOCK_NO_SOCK_AVAIL = 1;
  public const int SOCK_FAILED = 2;
  public const int SOCK_DISCONNECTED = 3;
  public const int SOCK_CONNECTING = 4;
  public const int SOCK_CONNECTED = 5;
  public const int SOCK_READY = 6;
  public const int SOCK_RECEIVING = 7;

  // General
  public const int DEFAULT_PORT = 6668;
  public const int BUFSIZE = 1024;
  public const int DEFAULT_RETRY_LIMIT = 5;
  public const int DEFAULT_RETRY_DELAY_MS = 100;
}
