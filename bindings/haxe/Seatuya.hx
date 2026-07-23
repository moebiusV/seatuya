// Seatuya.hx -- Haxe C++ FFI bindings for libseatuya
//
// Pure Haxe binding using cpp.Lib.load for the C++ backend.
//
// Usage:
//   var dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4");
//   trace(Seatuya.turnOn(dev, 1));
//   Seatuya.destroy(dev);
//
// Compile: haxe -main Example -cpp build -lib seatuya Example.hx Seatuya.hx

package seatuya;

import cpp.Lib;
import cpp.RawPointer;
import cpp.Void;

@:keep
@:unreflective
@:native("tuya_device_t")
extern class DeviceHandle {}

class Seatuya {

  // ---- Library loading --------------------------------------------------

  private static var _libName:String;

  private static function getLibName():String {
    if (_libName != null) return _libName;
    _libName = Sys.getEnv("SEATUYA_LIB");
    if (_libName == null) {
      #if (cpp && windows)
      _libName = "seatuya.dll";
      #elseif (cpp && mac)
      _libName = "libseatuya.dylib";
      #else
      _libName = "libseatuya.so";
      #end
    }
    return _libName;
  }

  private static function loadFn(name:String, nargs:Int):Dynamic {
    return cpp.Lib.load(getLibName(), name, nargs);
  }

  // ---- Helper: consume a malloc'd C string ------------------------------

  private static var _freeStr:Dynamic = loadFn("tuya_free_string", 1);

  private static function consume(ptr:Dynamic):String {
    if (ptr == null) return null;
    var s:String = cast ptr;
    _freeStr(ptr);
    return s;
  }

  // ---- Function references ----------------------------------------------

  private static var _version:Dynamic = loadFn("tuya_version", 0);
  private static var _create:Dynamic = loadFn("tuya_create", 4);
  private static var _alloc:Dynamic = loadFn("tuya_alloc", 1);
  private static var _destroy:Dynamic = loadFn("tuya_destroy", 1);
  private static var _setCreds:Dynamic = loadFn("tuya_set_credentials", 3);
  private static var _getDeviceId:Dynamic = loadFn("tuya_get_device_id", 1);
  private static var _getLocalKey:Dynamic = loadFn("tuya_get_local_key", 1);
  private static var _getIp:Dynamic = loadFn("tuya_get_ip", 1);
  private static var _connect:Dynamic = loadFn("tuya_connect", 2);
  private static var _disconnect:Dynamic = loadFn("tuya_disconnect", 1);
  private static var _isConnected:Dynamic = loadFn("tuya_is_connected", 1);
  private static var _reconnect:Dynamic = loadFn("tuya_reconnect", 1);
  private static var _setRetryLimit:Dynamic = loadFn("tuya_set_retry_limit", 2);
  private static var _setRetryDelay:Dynamic = loadFn("tuya_set_retry_delay", 2);
  private static var _getRetryLimit:Dynamic = loadFn("tuya_get_retry_limit", 1);
  private static var _getRetryDelay:Dynamic = loadFn("tuya_get_retry_delay", 1);
  private static var _negotiate:Dynamic = loadFn("tuya_negotiate_session", 2);
  private static var _negotiateStart:Dynamic = loadFn("tuya_negotiate_session_start", 2);
  private static var _negotiateFinalize:Dynamic = loadFn("tuya_negotiate_session_finalize", 4);
  private static var _getProtocol:Dynamic = loadFn("tuya_get_protocol", 1);
  private static var _getSessionState:Dynamic = loadFn("tuya_get_session_state", 1);
  private static var _getSocketState:Dynamic = loadFn("tuya_get_socket_state", 1);
  private static var _getLastError:Dynamic = loadFn("tuya_get_last_error", 1);
  private static var _setAsync:Dynamic = loadFn("tuya_set_async_mode", 2);
  private static var _isReadable:Dynamic = loadFn("tuya_is_socket_readable", 1);
  private static var _isWritable:Dynamic = loadFn("tuya_is_socket_writable", 1);
  private static var _setReady:Dynamic = loadFn("tuya_set_session_ready", 1);
  private static var _buildMsg:Dynamic = loadFn("tuya_build_message", 5);
  private static var _decodeMsg:Dynamic = loadFn("tuya_decode_message", 4);
  private static var _genPayload:Dynamic = loadFn("tuya_generate_payload", 4);
  private static var _send:Dynamic = loadFn("tuya_send", 3);
  private static var _receive:Dynamic = loadFn("tuya_receive", 4);
  private static var _setValueBool:Dynamic = loadFn("tuya_set_value_bool", 3);
  private static var _setValueInt:Dynamic = loadFn("tuya_set_value_int", 3);
  private static var _setValueString:Dynamic = loadFn("tuya_set_value_string", 3);
  private static var _setValueFloat:Dynamic = loadFn("tuya_set_value_float", 3);
  private static var _turnOn:Dynamic = loadFn("tuya_turn_on", 2);
  private static var _turnOff:Dynamic = loadFn("tuya_turn_off", 2);
  private static var _status:Dynamic = loadFn("tuya_status", 1);
  private static var _heartbeat:Dynamic = loadFn("tuya_heartbeat", 1);
  private static var _setDevice22:Dynamic = loadFn("tuya_set_device22", 2);
  private static var _isDevice22:Dynamic = loadFn("tuya_is_device22", 1);

  // ---- Helper: convert C int 0/1 to Bool -------------------------------

  private static function toBool(v:Dynamic):Bool {
    return (cast v : Int) != 0;
  }

  // ---- Public API -------------------------------------------------------

  // Version
  public static function version():String {
    return cast _version();
  }

  // Lifecycle
  public static function create(deviceId:String, address:String, localKey:String, version:String):RawPointer<Void> {
    return cast _create(deviceId, address, localKey, version);
  }

  public static function alloc(version:String):RawPointer<Void> {
    return cast _alloc(version);
  }

  public static function destroy(dev:RawPointer<Void>):Void {
    _destroy(dev);
  }

  // Credentials
  public static function setCredentials(dev:RawPointer<Void>, deviceId:String, localKey:String):Void {
    _setCreds(dev, deviceId, localKey);
  }

  public static function getDeviceId(dev:RawPointer<Void>):String {
    return cast _getDeviceId(dev);
  }

  public static function getLocalKey(dev:RawPointer<Void>):String {
    return cast _getLocalKey(dev);
  }

  public static function getIp(dev:RawPointer<Void>):String {
    return cast _getIp(dev);
  }

  // Connection
  public static function connect(dev:RawPointer<Void>, hostname:String):Bool {
    return toBool(_connect(dev, hostname));
  }

  public static function disconnect(dev:RawPointer<Void>):Void {
    _disconnect(dev);
  }

  public static function isConnected(dev:RawPointer<Void>):Bool {
    return toBool(_isConnected(dev));
  }

  public static function reconnect(dev:RawPointer<Void>):Bool {
    return toBool(_reconnect(dev));
  }

  // Retry
  public static function setRetryLimit(dev:RawPointer<Void>, limit:Int):Void {
    _setRetryLimit(dev, limit);
  }

  public static function setRetryDelay(dev:RawPointer<Void>, delayMs:Int):Void {
    _setRetryDelay(dev, delayMs);
  }

  public static function getRetryLimit(dev:RawPointer<Void>):Int {
    return cast _getRetryLimit(dev);
  }

  public static function getRetryDelay(dev:RawPointer<Void>):Int {
    return cast _getRetryDelay(dev);
  }

  // Session negotiation
  public static function negotiateSession(dev:RawPointer<Void>, localKey:String):Bool {
    return toBool(_negotiate(dev, localKey));
  }

  public static function negotiateSessionStart(dev:RawPointer<Void>, localKey:String):Bool {
    return toBool(_negotiateStart(dev, localKey));
  }

  public static function negotiateSessionFinalize(dev:RawPointer<Void>, buf:RawPointer<Void>, size:Int, localKey:String):Bool {
    return toBool(_negotiateFinalize(dev, buf, size, localKey));
  }

  // State queries
  public static function getProtocol(dev:RawPointer<Void>):Int {
    return cast _getProtocol(dev);
  }

  public static function getSessionState(dev:RawPointer<Void>):Int {
    return cast _getSessionState(dev);
  }

  public static function getSocketState(dev:RawPointer<Void>):Int {
    return cast _getSocketState(dev);
  }

  public static function getLastError(dev:RawPointer<Void>):Int {
    return cast _getLastError(dev);
  }

  // Async mode
  public static function setAsyncMode(dev:RawPointer<Void>, flag:Bool):Void {
    _setAsync(dev, flag ? 1 : 0);
  }

  public static function isSocketReadable(dev:RawPointer<Void>):Bool {
    return toBool(_isReadable(dev));
  }

  public static function isSocketWritable(dev:RawPointer<Void>):Bool {
    return toBool(_isWritable(dev));
  }

  public static function setSessionReady(dev:RawPointer<Void>):Bool {
    return toBool(_setReady(dev));
  }

  // Message building and decoding
  public static function buildMessage(dev:RawPointer<Void>, buf:RawPointer<Void>, cmd:Int, payload:String, key:String):Int {
    return cast _buildMsg(dev, buf, cmd, payload, key);
  }

  public static function decodeMessage(dev:RawPointer<Void>, buf:RawPointer<Void>, size:Int, key:String):String {
    return consume(_decodeMsg(dev, buf, size, key));
  }

  public static function generatePayload(dev:RawPointer<Void>, cmd:Int, deviceId:String, datapoints:String):String {
    return consume(_genPayload(dev, cmd, deviceId, datapoints));
  }

  // Raw send/receive
  public static function sendFrame(dev:RawPointer<Void>, buf:RawPointer<Void>, size:Int):Int {
    return cast _send(dev, buf, size);
  }

  public static function receiveFrame(dev:RawPointer<Void>, buf:RawPointer<Void>, maxsize:Int, minsize:Int):Int {
    return cast _receive(dev, buf, maxsize, minsize);
  }

  // device22 mode
  public static function setDevice22(dev:RawPointer<Void>, nullDpsJson:String):Void {
    _setDevice22(dev, nullDpsJson);
  }

  public static function isDevice22(dev:RawPointer<Void>):Bool {
    return toBool(_isDevice22(dev));
  }

  // High-level round-trip
  public static function setValueBool(dev:RawPointer<Void>, dp:Int, value:Bool):String {
    return consume(_setValueBool(dev, dp, value ? 1 : 0));
  }

  public static function setValueInt(dev:RawPointer<Void>, dp:Int, value:Int):String {
    return consume(_setValueInt(dev, dp, value));
  }

  public static function setValueString(dev:RawPointer<Void>, dp:Int, value:String):String {
    return consume(_setValueString(dev, dp, value));
  }

  public static function setValueFloat(dev:RawPointer<Void>, dp:Int, value:Float):String {
    return consume(_setValueFloat(dev, dp, value));
  }

  /** Type-aware setValue dispatcher. */
  public static function setValue(dev:RawPointer<Void>, dp:Int, value:Dynamic):String {
    if (Std.isOfType(value, Bool))   return setValueBool(dev, dp, cast value);
    if (Std.isOfType(value, Int))    return setValueInt(dev, dp, cast value);
    if (Std.isOfType(value, Float))  return setValueFloat(dev, dp, cast value);
    return setValueString(dev, dp, Std.string(value));
  }

  public static function turnOn(dev:RawPointer<Void>, ?switchDp:Int = 1):String {
    return consume(_turnOn(dev, switchDp));
  }

  public static function turnOff(dev:RawPointer<Void>, ?switchDp:Int = 1):String {
    return consume(_turnOff(dev, switchDp));
  }

  public static function status(dev:RawPointer<Void>):String {
    return consume(_status(dev));
  }

  public static function heartbeat(dev:RawPointer<Void>):String {
    return consume(_heartbeat(dev));
  }

  // ---- Constants --------------------------------------------------------

  // Command types (43 values)
  public static inline var CMD_UDP:Int = 0;
  public static inline var CMD_AP_CONFIG:Int = 1;
  public static inline var CMD_ACTIVE:Int = 2;
  public static inline var CMD_BIND:Int = 3;
  public static inline var CMD_RENAME_GW:Int = 4;
  public static inline var CMD_RENAME_DEVICE:Int = 5;
  public static inline var CMD_UNBIND:Int = 6;
  public static inline var CMD_CONTROL:Int = 7;
  public static inline var CMD_STATUS:Int = 8;
  public static inline var CMD_HEART_BEAT:Int = 9;
  public static inline var CMD_DP_QUERY:Int = 10;
  public static inline var CMD_QUERY_WIFI:Int = 11;
  public static inline var CMD_TOKEN_BIND:Int = 12;
  public static inline var CMD_CONTROL_NEW:Int = 13;
  public static inline var CMD_ENABLE_WIFI:Int = 14;
  public static inline var CMD_DP_QUERY_NEW:Int = 16;
  public static inline var CMD_SCENE_EXECUTE:Int = 17;
  public static inline var CMD_UPDATEDPS:Int = 18;
  public static inline var CMD_UDP_NEW:Int = 19;
  public static inline var CMD_AP_CONFIG_NEW:Int = 20;
  public static inline var CMD_GET_LOCAL_TIME:Int = 28;
  public static inline var CMD_WEATHER_OPEN:Int = 32;
  public static inline var CMD_WEATHER_DATA:Int = 33;
  public static inline var CMD_STATE_UPLOAD_SYN:Int = 34;
  public static inline var CMD_STATE_UPLOAD_SYN_RECV:Int = 35;
  public static inline var CMD_HEART_BEAT_STOP:Int = 37;
  public static inline var CMD_STREAM_TRANS:Int = 38;
  public static inline var CMD_GET_WIFI_STATUS:Int = 43;
  public static inline var CMD_WIFI_CONNECT_TEST:Int = 44;
  public static inline var CMD_GET_MAC:Int = 45;
  public static inline var CMD_GET_IR_STATUS:Int = 46;
  public static inline var CMD_IR_TX_RX_TEST:Int = 47;
  public static inline var CMD_LAN_GW_ACTIVE:Int = 240;
  public static inline var CMD_LAN_SUB_DEV_REQUEST:Int = 241;
  public static inline var CMD_LAN_DELETE_SUB_DEV:Int = 242;
  public static inline var CMD_LAN_REPORT_SUB_DEV:Int = 243;
  public static inline var CMD_LAN_SCENE:Int = 244;
  public static inline var CMD_LAN_PUBLISH_CLOUD_CONFIG:Int = 245;
  public static inline var CMD_LAN_PUBLISH_APP_CONFIG:Int = 246;
  public static inline var CMD_LAN_EXPORT_APP_CONFIG:Int = 247;
  public static inline var CMD_LAN_PUBLISH_SCENE_PANEL:Int = 248;
  public static inline var CMD_LAN_REMOVE_GW:Int = 249;
  public static inline var CMD_LAN_CHECK_GW_UPDATE:Int = 250;
  public static inline var CMD_LAN_GW_UPDATE:Int = 251;
  public static inline var CMD_LAN_SET_GW_CHANNEL:Int = 252;

  // Protocol versions
  public static inline var PROTO_V31:Int = 0;
  public static inline var PROTO_V33:Int = 1;
  public static inline var PROTO_V34:Int = 2;
  public static inline var PROTO_V35:Int = 3;

  // Session states
  public static inline var SESSION_INVALID:Int = 0;
  public static inline var SESSION_STARTING:Int = 1;
  public static inline var SESSION_FINALIZING:Int = 2;
  public static inline var SESSION_ESTABLISHED:Int = 3;

  // Socket states
  public static inline var SOCK_NO_SUCH_HOST:Int = 0;
  public static inline var SOCK_NO_SOCK_AVAIL:Int = 1;
  public static inline var SOCK_FAILED:Int = 2;
  public static inline var SOCK_DISCONNECTED:Int = 3;
  public static inline var SOCK_CONNECTING:Int = 4;
  public static inline var SOCK_CONNECTED:Int = 5;
  public static inline var SOCK_READY:Int = 6;
  public static inline var SOCK_RECEIVING:Int = 7;

  // Misc
  public static inline var DEFAULT_PORT:Int = 6668;
  public static inline var BUFSIZE:Int = 1024;
  public static inline var DEFAULT_RETRY_LIMIT:Int = 5;
  public static inline var DEFAULT_RETRY_DELAY_MS:Int = 100;
}
