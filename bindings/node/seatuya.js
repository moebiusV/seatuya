/**
 * seatuya.js — Node.js FFI bindings for libseatuya
 *
 * Pure JavaScript binding using ffi-napi.  Requires:
 *   npm install ffi-napi ref-napi ref-struct-napi
 *
 * Usage:
 *   const seatuya = require('./seatuya.js');
 *   const dev = seatuya.create(deviceId, '192.168.1.100', localKey, '3.4');
 *   const resp = seatuya.turnOn(dev, 1);
 *   console.log(resp);
 *   seatuya.destroy(dev);
 */

'use strict';

const ffi = require('ffi-napi');
const ref = require('ref-napi');

/* ------------------------------------------------------------------ */
/*  Library path                                                       */
/* ------------------------------------------------------------------ */

const LIB = process.env.SEATUYA_LIB ||
  (process.platform === 'darwin' ? 'libseatuya.dylib' :
   process.platform === 'win32' ? 'seatuya.dll' :
   'libseatuya.so');

/* ------------------------------------------------------------------ */
/*  Type mappings                                                      */
/* ------------------------------------------------------------------ */

const voidPtr = ref.refType(ref.types.void);
const charPtr = ref.refType(ref.types.char);
const ucharPtr = ref.refType(ref.types.uchar);
const intPtr = ref.refType(ref.types.int);
const bool_t = ref.types.bool;    // C99 _Bool, 1 byte

/* ------------------------------------------------------------------ */
/*  Constants (from seatuya.h enums)                                   */
/* ------------------------------------------------------------------ */

const Command = {
  UDP:                       0,
  AP_CONFIG:                 1,
  ACTIVE:                    2,
  BIND:                      3,
  RENAME_GW:                 4,
  RENAME_DEVICE:             5,
  UNBIND:                    6,
  CONTROL:                   7,
  STATUS:                    8,
  HEART_BEAT:                9,
  DP_QUERY:                 10,
  QUERY_WIFI:               11,
  TOKEN_BIND:               12,
  CONTROL_NEW:              13,
  ENABLE_WIFI:              14,
  DP_QUERY_NEW:             16,
  SCENE_EXECUTE:            17,
  UPDATEDPS:                18,
  UDP_NEW:                  19,
  AP_CONFIG_NEW:            20,
  GET_LOCAL_TIME:           28,
  WEATHER_OPEN:             32,
  WEATHER_DATA:             33,
  STATE_UPLOAD_SYN:         34,
  STATE_UPLOAD_SYN_RECV:    35,
  HEART_BEAT_STOP:          37,
  STREAM_TRANS:             38,
  GET_WIFI_STATUS:          43,
  WIFI_CONNECT_TEST:        44,
  GET_MAC:                  45,
  GET_IR_STATUS:            46,
  IR_TX_RX_TEST:            47,
  LAN_GW_ACTIVE:           240,
  LAN_SUB_DEV_REQUEST:     241,
  LAN_DELETE_SUB_DEV:       242,
  LAN_REPORT_SUB_DEV:       243,
  LAN_SCENE:                244,
  LAN_PUBLISH_CLOUD_CONFIG: 245,
  LAN_PUBLISH_APP_CONFIG:   246,
  LAN_EXPORT_APP_CONFIG:    247,
  LAN_PUBLISH_SCENE_PANEL:  248,
  LAN_REMOVE_GW:            249,
  LAN_CHECK_GW_UPDATE:      250,
  LAN_GW_UPDATE:            251,
  LAN_SET_GW_CHANNEL:       252,
};

const Protocol = {
  V31: 0,
  V33: 1,
  V34: 2,
  V35: 3,
};

const SessionState = {
  INVALID:      0,
  STARTING:     1,
  FINALIZING:   2,
  ESTABLISHED:  3,
};

const SocketState = {
  NO_SUCH_HOST:  0,
  NO_SOCK_AVAIL: 1,
  FAILED:        2,
  DISCONNECTED:  3,
  CONNECTING:    4,
  CONNECTED:     5,
  READY:         6,
  RECEIVING:     7,
};

const DEFAULT_PORT = 6668;
const BUFSIZE = 1024;
const DEFAULT_RETRY_LIMIT = 5;
const DEFAULT_RETRY_DELAY_MS = 100;

/* ------------------------------------------------------------------ */
/*  FFI function declarations                                          */
/* ------------------------------------------------------------------ */

const lib = ffi.Library(LIB, {
  'tuya_version':               ['string',  []],
  'tuya_create':                [voidPtr,   ['string', 'string', 'string', 'string']],
  'tuya_alloc':                 [voidPtr,   ['string']],
  'tuya_destroy':               ['void',    [voidPtr]],
  'tuya_set_credentials':       ['void',    [voidPtr, 'string', 'string']],
  'tuya_get_device_id':         ['string',  [voidPtr]],
  'tuya_get_local_key':         ['string',  [voidPtr]],
  'tuya_get_ip':                ['string',  [voidPtr]],
  'tuya_connect':               [bool_t,    [voidPtr, 'string']],
  'tuya_disconnect':            ['void',    [voidPtr]],
  'tuya_is_connected':          [bool_t,    [voidPtr]],
  'tuya_reconnect':             [bool_t,    [voidPtr]],
  'tuya_set_retry_limit':       ['void',    [voidPtr, 'int']],
  'tuya_set_retry_delay':       ['void',    [voidPtr, 'int']],
  'tuya_get_retry_limit':       ['int',     [voidPtr]],
  'tuya_get_retry_delay':       ['int',     [voidPtr]],
  'tuya_negotiate_session':      [bool_t,    [voidPtr, 'string']],
  'tuya_negotiate_session_start':[bool_t,    [voidPtr, 'string']],
  'tuya_negotiate_session_finalize': [bool_t, [voidPtr, ucharPtr, 'int', 'string']],
  'tuya_get_protocol':          ['int',     [voidPtr]],
  'tuya_get_session_state':     ['int',     [voidPtr]],
  'tuya_get_socket_state':      ['int',     [voidPtr]],
  'tuya_get_last_error':        ['int',     [voidPtr]],
  'tuya_set_async_mode':        ['void',    [voidPtr, bool_t]],
  'tuya_is_socket_readable':    [bool_t,    [voidPtr]],
  'tuya_is_socket_writable':    [bool_t,    [voidPtr]],
  'tuya_set_session_ready':     [bool_t,    [voidPtr]],
  'tuya_build_message':         ['int',     [voidPtr, ucharPtr, 'int', 'string', 'string']],
  'tuya_decode_message':        ['string',  [voidPtr, ucharPtr, 'int', 'string']],
  'tuya_generate_payload':      ['string',  [voidPtr, 'int', 'string', 'string']],
  'tuya_send':                  ['int',     [voidPtr, ucharPtr, 'int']],
  'tuya_receive':               ['int',     [voidPtr, ucharPtr, 'int', 'int']],
  'tuya_set_value_bool':        ['string',  [voidPtr, 'int', bool_t]],
  'tuya_set_value_int':         ['string',  [voidPtr, 'int', 'int']],
  'tuya_set_value_string':      ['string',  [voidPtr, 'int', 'string']],
  'tuya_set_value_float':       ['string',  [voidPtr, 'int', 'double']],
  'tuya_turn_on':               ['string',  [voidPtr, 'int']],
  'tuya_turn_off':              ['string',  [voidPtr, 'int']],
  'tuya_status':                ['string',  [voidPtr]],
  'tuya_heartbeat':             ['string',  [voidPtr]],
  'tuya_free_string':           ['void',    ['string']],
  'tuya_set_device22':          ['void',    [voidPtr, 'string']],
  'tuya_is_device22':           [bool_t,    [voidPtr]],
});

/* ------------------------------------------------------------------ */
/*  Convenience wrappers                                               */
/* ------------------------------------------------------------------ */

function version() {
  return lib.tuya_version();
}

function create(deviceId, address, localKey, ver) {
  const ptr = lib.tuya_create(deviceId, address, localKey, ver);
  if (ref.isNull(ptr)) return null;
  return ptr;
}

function alloc(ver) {
  const ptr = lib.tuya_alloc(ver);
  if (ref.isNull(ptr)) return null;
  return ptr;
}

function destroy(dev) {
  lib.tuya_destroy(dev);
}

function connect(dev, hostname) {
  return Boolean(lib.tuya_connect(dev, hostname));
}

function disconnect(dev) {
  lib.tuya_disconnect(dev);
}

function reconnect(dev) {
  return Boolean(lib.tuya_reconnect(dev));
}

function setCredentials(dev, deviceId, localKey) {
  lib.tuya_set_credentials(dev, deviceId, localKey);
}

function getDeviceId(dev) {
  return lib.tuya_get_device_id(dev);
}

function getLocalKey(dev) {
  return lib.tuya_get_local_key(dev);
}

function getIp(dev) {
  return lib.tuya_get_ip(dev);
}

function setRetryLimit(dev, limit) {
  lib.tuya_set_retry_limit(dev, limit);
}

function setRetryDelay(dev, delayMs) {
  lib.tuya_set_retry_delay(dev, delayMs);
}

function getRetryLimit(dev) {
  return lib.tuya_get_retry_limit(dev);
}

function getRetryDelay(dev) {
  return lib.tuya_get_retry_delay(dev);
}

function negotiateSession(dev, key) {
  return Boolean(lib.tuya_negotiate_session(dev, key));
}

function negotiateSessionStart(dev, key) {
  return Boolean(lib.tuya_negotiate_session_start(dev, key));
}

function negotiateSessionFinalize(dev, buf, key) {
  return Boolean(lib.tuya_negotiate_session_finalize(dev, buf, buf.length, key));
}

/* --- State queries --- */

function getProtocol(dev) { return lib.tuya_get_protocol(dev); }
function getSessionState(dev) { return lib.tuya_get_session_state(dev); }
function getSocketState(dev) { return lib.tuya_get_socket_state(dev); }
function getLastError(dev) { return lib.tuya_get_last_error(dev); }

/* --- Async mode --- */

function setAsyncMode(dev, flag) {
  lib.tuya_set_async_mode(dev, flag);
}

function isSocketReadable(dev) {
  return Boolean(lib.tuya_is_socket_readable(dev));
}

function isSocketWritable(dev) {
  return Boolean(lib.tuya_is_socket_writable(dev));
}

function setSessionReady(dev) {
  return Boolean(lib.tuya_set_session_ready(dev));
}

/* --- Low-level message functions --- */

function buildMessage(dev, cmd, payload, key) {
  const buf = Buffer.alloc(BUFSIZE);
  const n = lib.tuya_build_message(dev, buf, cmd, payload, key);
  if (n > 0) return buf.subarray(0, n);
  return null;
}

function decodeMessage(dev, buf, key) {
  return lib.tuya_decode_message(dev, buf, buf.length, key);
}

function generatePayload(dev, cmd, deviceId, datapoints) {
  return lib.tuya_generate_payload(dev, cmd, deviceId, datapoints || '');
}

function send(dev, buf) {
  return lib.tuya_send(dev, buf, buf.length);
}

function receive(dev, maxsize, minsize) {
  maxsize = maxsize || BUFSIZE;
  minsize = minsize || 0;
  const buf = Buffer.alloc(maxsize);
  const n = lib.tuya_receive(dev, buf, maxsize, minsize);
  if (n > 0) return buf.subarray(0, n);
  return null;
}

/* --- High-level round-trip functions --- */

function setValue(dev, dp, value) {
  // Type-dispatch: route to the correct typed C function
  switch (typeof value) {
    case 'boolean':
      return lib.tuya_set_value_bool(dev, dp, value);
    case 'number':
      if (Number.isInteger(value))
        return lib.tuya_set_value_int(dev, dp, value);
      return lib.tuya_set_value_float(dev, dp, value);
    case 'string':
      return lib.tuya_set_value_string(dev, dp, value);
    default:
      return lib.tuya_set_value_string(dev, dp, String(value));
  }
}

function turnOn(dev, switchDp) {
  switchDp = switchDp || 1;
  return lib.tuya_turn_on(dev, switchDp);
}

function turnOff(dev, switchDp) {
  switchDp = switchDp || 1;
  return lib.tuya_turn_off(dev, switchDp);
}

function status(dev) {
  return lib.tuya_status(dev);
}

function heartbeat(dev) {
  return lib.tuya_heartbeat(dev);
}

/* --- device22 mode --- */

function setDevice22(dev, nullDpsJson) {
  lib.tuya_set_device22(dev, nullDpsJson || null);
}

function isDevice22(dev) {
  return Boolean(lib.tuya_is_device22(dev));
}

/* ------------------------------------------------------------------ */
/*  Exports                                                            */
/* ------------------------------------------------------------------ */

module.exports = {
  // Constants
  Command,
  Protocol,
  SessionState,
  SocketState,
  DEFAULT_PORT,
  BUFSIZE,
  DEFAULT_RETRY_LIMIT,
  DEFAULT_RETRY_DELAY_MS,
  // Lifecycle
  version,
  create,
  alloc,
  destroy,
  // Credentials
  setCredentials,
  getDeviceId,
  getLocalKey,
  getIp,
  // Connection
  connect,
  disconnect,
  isConnected: (dev) => Boolean(lib.tuya_is_connected(dev)),
  reconnect,
  setRetryLimit,
  setRetryDelay,
  getRetryLimit,
  getRetryDelay,
  // Session negotiation
  negotiateSession,
  negotiateSessionStart,
  negotiateSessionFinalize,
  // State queries
  getProtocol,
  getSessionState,
  getSocketState,
  getLastError,
  // Async mode
  setAsyncMode,
  isSocketReadable,
  isSocketWritable,
  setSessionReady,
  // Low-level
  buildMessage,
  decodeMessage,
  generatePayload,
  send,
  receive,
  // High-level
  setValue,
  turnOn,
  turnOff,
  status,
  heartbeat,
  // device22
  setDevice22,
  isDevice22,
  // Raw library handle
  _lib: lib,
};
