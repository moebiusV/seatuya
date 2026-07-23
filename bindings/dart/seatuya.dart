// seatuya.dart — Dart FFI bindings for libseatuya
//
// Pure Dart binding using dart:ffi.  Requires Dart 2.12+.
//
// Usage:
//   import 'seatuya.dart';
//   final dev = seatuya.create(deviceId, "192.168.1.100", localKey, "3.4");
//   print(seatuya.turnOn(dev, 1));
//   seatuya.destroy(dev);

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

// ── Library loading ──
final DynamicLibrary _lib = () {
  final name = Platform.environment['SEATUYA_LIB'] ??
    (Platform.isMacOS ? 'libseatuya.dylib' :
     Platform.isWindows ? 'seatuya.dll' :
     'libseatuya.so');
  return DynamicLibrary.open(name);
}();

// ── Type aliases ──
typedef _CString = Pointer<Utf8>;
typedef _TUYA_DEVICE = Pointer<Void>;

// ── Function typedefs ──
typedef _VersionNative = Pointer<Utf8> Function();
typedef _CreateNative = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _AllocNative = Pointer<Void> Function(Pointer<Utf8>);
typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _SetCredsNative = Void Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _GetStrNative = Pointer<Utf8> Function(Pointer<Void>);
typedef _ConnectNative = Int8 Function(Pointer<Void>, Pointer<Utf8>);
typedef _VoidNative = Void Function(Pointer<Void>);
typedef _BoolNative = Int8 Function(Pointer<Void>);
typedef _SetIntNative = Void Function(Pointer<Void>, Int32);
typedef _GetIntNative = Int32 Function(Pointer<Void>);
typedef _NegotiateNative = Int8 Function(Pointer<Void>, Pointer<Utf8>);
typedef _GetEnumNative = Int32 Function(Pointer<Void>);
typedef _SetAsyncNative = Void Function(Pointer<Void>, Int8);
typedef _BuildMsgNative = Int32 Function(Pointer<Void>, Pointer<Void>, Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef _DecodeNative = Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>, Int32, Pointer<Utf8>);
typedef _GenPayloadNative = Pointer<Utf8> Function(Pointer<Void>, Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef _SendRecvNative = Int32 Function(Pointer<Void>, Pointer<Void>, Int32, Int32);
typedef _SetBoolNative = Pointer<Utf8> Function(Pointer<Void>, Int32, Int8);
typedef _SetIntValNative = Pointer<Utf8> Function(Pointer<Void>, Int32, Int32);
typedef _SetStrNative = Pointer<Utf8> Function(Pointer<Void>, Int32, Pointer<Utf8>);
typedef _SetFloatNative = Pointer<Utf8> Function(Pointer<Void>, Int32, Double);
typedef _OnOffNative = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _StatusNative = Pointer<Utf8> Function(Pointer<Void>);
typedef _FreeStrNative = Void Function(Pointer<Utf8>);

// ── Lazy lookups ──
final _version = _lib.lookupFunction<_VersionNative, _VersionNative>('tuya_version');
final _create = _lib.lookupFunction<_CreateNative, _CreateNative>('tuya_create');
final _alloc = _lib.lookupFunction<_AllocNative, _AllocNative>('tuya_alloc');
final _destroy = _lib.lookupFunction<_DestroyNative, _DestroyNative>('tuya_destroy');
final _setCreds = _lib.lookupFunction<_SetCredsNative, _SetCredsNative>('tuya_set_credentials');
final _getDeviceId = _lib.lookupFunction<_GetStrNative, _GetStrNative>('tuya_get_device_id');
final _getLocalKey = _lib.lookupFunction<_GetStrNative, _GetStrNative>('tuya_get_local_key');
final _getIp = _lib.lookupFunction<_GetStrNative, _GetStrNative>('tuya_get_ip');
final _connect = _lib.lookupFunction<_ConnectNative, _ConnectNative>('tuya_connect');
final _disconnect = _lib.lookupFunction<_VoidNative, _VoidNative>('tuya_disconnect');
final _isConnected = _lib.lookupFunction<_BoolNative, _BoolNative>('tuya_is_connected');
final _reconnect = _lib.lookupFunction<_BoolNative, _BoolNative>('tuya_reconnect');
final _setRetryLimit = _lib.lookupFunction<_SetIntNative, _SetIntNative>('tuya_set_retry_limit');
final _setRetryDelay = _lib.lookupFunction<_SetIntNative, _SetIntNative>('tuya_set_retry_delay');
final _getRetryLimit = _lib.lookupFunction<_GetIntNative, _GetIntNative>('tuya_get_retry_limit');
final _getRetryDelay = _lib.lookupFunction<_GetIntNative, _GetIntNative>('tuya_get_retry_delay');
final _negotiate = _lib.lookupFunction<_NegotiateNative, _NegotiateNative>('tuya_negotiate_session');
final _getProtocol = _lib.lookupFunction<_GetEnumNative, _GetEnumNative>('tuya_get_protocol');
final _getSessionState = _lib.lookupFunction<_GetEnumNative, _GetEnumNative>('tuya_get_session_state');
final _getSocketState = _lib.lookupFunction<_GetEnumNative, _GetEnumNative>('tuya_get_socket_state');
final _getLastError = _lib.lookupFunction<_GetIntNative, _GetIntNative>('tuya_get_last_error');
final _setAsync = _lib.lookupFunction<_SetAsyncNative, _SetAsyncNative>('tuya_set_async_mode');
final _setValueBool = _lib.lookupFunction<_SetBoolNative, _SetBoolNative>('tuya_set_value_bool');
final _setValueInt = _lib.lookupFunction<_SetIntValNative, _SetIntValNative>('tuya_set_value_int');
final _setValueString = _lib.lookupFunction<_SetStrNative, _SetStrNative>('tuya_set_value_string');
final _setValueFloat = _lib.lookupFunction<_SetFloatNative, _SetFloatNative>('tuya_set_value_float');
final _turnOn = _lib.lookupFunction<_OnOffNative, _OnOffNative>('tuya_turn_on');
final _turnOff = _lib.lookupFunction<_OnOffNative, _OnOffNative>('tuya_turn_off');
final _status = _lib.lookupFunction<_StatusNative, _StatusNative>('tuya_status');
final _heartbeat = _lib.lookupFunction<_StatusNative, _StatusNative>('tuya_heartbeat');
final _freeStr = _lib.lookupFunction<_FreeStrNative, _FreeStrNative>('tuya_free_string');
final _send = _lib.lookupFunction<_SendRecvNative, _SendRecvNative>('tuya_send');
final _receive = _lib.lookupFunction<_SendRecvNative, _SendRecvNative>('tuya_receive');
final _setDevice22 = _lib.lookupFunction<_SetCredsNative, _SetCredsNative>('tuya_set_device22');
final _isDevice22 = _lib.lookupFunction<_BoolNative, _BoolNative>('tuya_is_device22');

// ── Constants ──
class Command { static const control = 7, dpQuery = 10, heartBeat = 9, controlNew = 13, dpQueryNew = 16, status = 8; }
const defaultPort = 6668, bufsize = 1024, defaultRetryLimit = 5, defaultRetryDelay = 100;
class Proto { static const v31 = 0, v33 = 1, v34 = 2, v35 = 3; }

// ── Convenience functions ──
String version() => _version().toDartString();

Pointer<Void> create(String deviceId, String address, String localKey, String ver) {
  return _create(deviceId.toNativeUtf8(), address.toNativeUtf8(), localKey.toNativeUtf8(), ver.toNativeUtf8());
}

Pointer<Void> alloc(String ver) => _alloc(ver.toNativeUtf8());
void destroy(Pointer<Void> dev) => _destroy(dev);

void setCredentials(Pointer<Void> dev, String id, String key) =>
    _setCreds(dev, id.toNativeUtf8(), key.toNativeUtf8());

String getDeviceId(Pointer<Void> dev) => _getDeviceId(dev).toDartString();
String getLocalKey(Pointer<Void> dev) => _getLocalKey(dev).toDartString();
String getIp(Pointer<Void> dev) => _getIp(dev).toDartString();

bool doConnect(Pointer<Void> dev, String host) => _connect(dev, host.toNativeUtf8()) != 0;
void doDisconnect(Pointer<Void> dev) => _disconnect(dev);
bool isConnected(Pointer<Void> dev) => _isConnected(dev) != 0;
bool reconnect(Pointer<Void> dev) => _reconnect(dev) != 0;
bool negotiateSession(Pointer<Void> dev, String key) => _negotiate(dev, key.toNativeUtf8()) != 0;

int getProtocol(Pointer<Void> dev) => _getProtocol(dev);
int getSessionState(Pointer<Void> dev) => _getSessionState(dev);
int getSocketState(Pointer<Void> dev) => _getSocketState(dev);
int getLastError(Pointer<Void> dev) => _getLastError(dev);
void setAsyncMode(Pointer<Void> dev, bool flag) => _setAsync(dev, flag ? 1 : 0);

String? _consume(Pointer<Utf8> ptr) {
  if (ptr == nullptr) return null;
  final s = ptr.toDartString();
  _freeStr(ptr);
  return s;
}

String? setValue(Pointer<Void> dev, int dp, Object value) {
  if (value is bool) return _consume(_setValueBool(dev, dp, value ? 1 : 0));
  if (value is int) return _consume(_setValueInt(dev, dp, value));
  if (value is double) return _consume(_setValueFloat(dev, dp, value));
  return _consume(_setValueString(dev, dp, value.toString().toNativeUtf8()));
}

String? turnOn(Pointer<Void> dev, [int dp = 1]) => _consume(_turnOn(dev, dp));
String? turnOff(Pointer<Void> dev, [int dp = 1]) => _consume(_turnOff(dev, dp));
String? status(Pointer<Void> dev) => _consume(_status(dev));
String? heartbeat(Pointer<Void> dev) => _consume(_heartbeat(dev));

void setDevice22(Pointer<Void> dev, String json) => _setDevice22(dev, json.toNativeUtf8());
bool isDevice22(Pointer<Void> dev) => _isDevice22(dev) != 0;

Uint8List? sendFrame(Pointer<Void> dev, Uint8List data) {
  final n = _send(dev, data.buffer.asByteData().cast<Void>(), data.length);
  return n > 0 ? Uint8List.sublistView(data, 0, n) : null;
}

Uint8List? receiveFrame(Pointer<Void> dev, [int maxsize = bufsize, int minsize = 0]) {
  final buf = Uint8List(maxsize);
  final n = _receive(dev, buf.buffer.asByteData().cast<Void>(), maxsize, minsize);
  return n > 0 ? Uint8List.sublistView(buf, 0, n) : null;
}
