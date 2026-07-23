##
## seatuya.nim -- Nim FFI bindings for libseatuya
##
## Loads libseatuya at runtime via Nim's dynlib module.
## Set the SEATUYA_LIB environment variable to override the library path.
##
## Usage:
##   import seatuya
##   let dev = tuyaCreate("dev_id", "192.168.1.100", "local_key", "3.3")
##
## Compile: nim c -r example.nim

import dynlib, os, strutils

# ==================================================================
#  Library loading
# ==================================================================

var libHandle: LibHandle

proc loadLibrary(): bool =
  if libHandle != nil: return true
  let path = getEnv("SEATUYA_LIB",
    when defined(windows): "seatuya.dll"
    elif defined(macosx):  "libseatuya.dylib"
    else:                  "libseatuya.so")
  libHandle = loadLib(path)
  if libHandle == nil:
    stderr.writeLine "Failed to load libseatuya: ", path
    return false
  result = true

proc symAddr(name: cstring): pointer =
  discard loadLibrary()
  result = libHandle.symAddr(name)
  if result == nil:
    stderr.writeLine "Symbol not found: ", name

# ==================================================================
#  Helper: consume malloc'd C string and free it
# ==================================================================

proc consumeCString(p: pointer): string =
  ## Convert a malloc'd C string to a Nim string and free it.
  if p == nil: return nil
  result = $cast[cstring](p)
  let freeFn = cast[proc(s: cstring) {.cdecl.}](libHandle.symAddr("tuya_free_string"))
  if freeFn != nil:
    freeFn(cast[cstring](p))

# ==================================================================
#  C function pointer types and wrappers
# ==================================================================

type
  TuyaDevice = object
  TuyaDevicePtr = ptr TuyaDevice

# -- Version --------------------------------------------------------

proc tuyaVersion*(): string =
  let fn = cast[proc(): cstring {.cdecl.}](symAddr("tuya_version"))
  result = $fn()

# -- Lifecycle ------------------------------------------------------

proc tuyaCreate*(deviceId, address, localKey, version: string): TuyaDevicePtr =
  let fn = cast[proc(a, b, c, d: cstring): TuyaDevicePtr {.cdecl.}](symAddr("tuya_create"))
  result = fn(deviceId.cstring, address.cstring, localKey.cstring, version.cstring)

proc tuyaAlloc*(version: string): TuyaDevicePtr =
  let fn = cast[proc(v: cstring): TuyaDevicePtr {.cdecl.}](symAddr("tuya_alloc"))
  result = fn(version.cstring)

proc tuyaDestroy*(dev: TuyaDevicePtr) =
  let fn = cast[proc(d: TuyaDevicePtr) {.cdecl.}](symAddr("tuya_destroy"))
  fn(dev)

# -- Credentials ----------------------------------------------------

proc tuyaSetCredentials*(dev: TuyaDevicePtr; deviceId, localKey: string) =
  let fn = cast[proc(d: TuyaDevicePtr; a, b: cstring) {.cdecl.}](symAddr("tuya_set_credentials"))
  fn(dev, deviceId.cstring, localKey.cstring)

proc tuyaGetDeviceId*(dev: TuyaDevicePtr): string =
  let fn = cast[proc(d: TuyaDevicePtr): cstring {.cdecl.}](symAddr("tuya_get_device_id"))
  result = $fn(dev)

proc tuyaGetLocalKey*(dev: TuyaDevicePtr): string =
  let fn = cast[proc(d: TuyaDevicePtr): cstring {.cdecl.}](symAddr("tuya_get_local_key"))
  result = $fn(dev)

proc tuyaGetIp*(dev: TuyaDevicePtr): string =
  let fn = cast[proc(d: TuyaDevicePtr): cstring {.cdecl.}](symAddr("tuya_get_ip"))
  result = $fn(dev)

# -- Connection -----------------------------------------------------

proc tuyaConnect*(dev: TuyaDevicePtr; hostname: string): bool =
  let fn = cast[proc(d: TuyaDevicePtr; h: cstring): bool {.cdecl.}](symAddr("tuya_connect"))
  result = fn(dev, hostname.cstring)

proc tuyaDisconnect*(dev: TuyaDevicePtr) =
  let fn = cast[proc(d: TuyaDevicePtr) {.cdecl.}](symAddr("tuya_disconnect"))
  fn(dev)

proc tuyaIsConnected*(dev: TuyaDevicePtr): bool =
  let fn = cast[proc(d: TuyaDevicePtr): bool {.cdecl.}](symAddr("tuya_is_connected"))
  result = fn(dev)

proc tuyaReconnect*(dev: TuyaDevicePtr): bool =
  let fn = cast[proc(d: TuyaDevicePtr): bool {.cdecl.}](symAddr("tuya_reconnect"))
  result = fn(dev)

# -- Retry ----------------------------------------------------------

proc tuyaSetRetryLimit*(dev: TuyaDevicePtr; limit: int32) =
  let fn = cast[proc(d: TuyaDevicePtr; n: int32) {.cdecl.}](symAddr("tuya_set_retry_limit"))
  fn(dev, limit)

proc tuyaSetRetryDelay*(dev: TuyaDevicePtr; delayMs: int32) =
  let fn = cast[proc(d: TuyaDevicePtr; n: int32) {.cdecl.}](symAddr("tuya_set_retry_delay"))
  fn(dev, delayMs)

proc tuyaGetRetryLimit*(dev: TuyaDevicePtr): int32 =
  let fn = cast[proc(d: TuyaDevicePtr): int32 {.cdecl.}](symAddr("tuya_get_retry_limit"))
  result = fn(dev)

proc tuyaGetRetryDelay*(dev: TuyaDevicePtr): int32 =
  let fn = cast[proc(d: TuyaDevicePtr): int32 {.cdecl.}](symAddr("tuya_get_retry_delay"))
  result = fn(dev)

# -- Session negotiation --------------------------------------------

proc tuyaNegotiateSession*(dev: TuyaDevicePtr; localKey: string): bool =
  let fn = cast[proc(d: TuyaDevicePtr; k: cstring): bool {.cdecl.}](symAddr("tuya_negotiate_session"))
  result = fn(dev, localKey.cstring)

proc tuyaNegotiateSessionStart*(dev: TuyaDevicePtr; localKey: string): bool =
  let fn = cast[proc(d: TuyaDevicePtr; k: cstring): bool {.cdecl.}](symAddr("tuya_negotiate_session_start"))
  result = fn(dev, localKey.cstring)

proc tuyaNegotiateSessionFinalize*(dev: TuyaDevicePtr; buf: pointer; size: int32; localKey: string): bool =
  let fn = cast[proc(d: TuyaDevicePtr; b: pointer; s: int32; k: cstring): bool {.cdecl.}](symAddr("tuya_negotiate_session_finalize"))
  result = fn(dev, buf, size, localKey.cstring)

# -- State queries --------------------------------------------------

proc tuyaGetProtocol*(dev: TuyaDevicePtr): int32 =
  let fn = cast[proc(d: TuyaDevicePtr): int32 {.cdecl.}](symAddr("tuya_get_protocol"))
  result = fn(dev)

proc tuyaGetSessionState*(dev: TuyaDevicePtr): int32 =
  let fn = cast[proc(d: TuyaDevicePtr): int32 {.cdecl.}](symAddr("tuya_get_session_state"))
  result = fn(dev)

proc tuyaGetSocketState*(dev: TuyaDevicePtr): int32 =
  let fn = cast[proc(d: TuyaDevicePtr): int32 {.cdecl.}](symAddr("tuya_get_socket_state"))
  result = fn(dev)

proc tuyaGetLastError*(dev: TuyaDevicePtr): int32 =
  let fn = cast[proc(d: TuyaDevicePtr): int32 {.cdecl.}](symAddr("tuya_get_last_error"))
  result = fn(dev)

# -- Async mode -----------------------------------------------------

proc tuyaSetAsyncMode*(dev: TuyaDevicePtr; asyncMode: bool) =
  let fn = cast[proc(d: TuyaDevicePtr; a: bool) {.cdecl.}](symAddr("tuya_set_async_mode"))
  fn(dev, asyncMode)

proc tuyaIsSocketReadable*(dev: TuyaDevicePtr): bool =
  let fn = cast[proc(d: TuyaDevicePtr): bool {.cdecl.}](symAddr("tuya_is_socket_readable"))
  result = fn(dev)

proc tuyaIsSocketWritable*(dev: TuyaDevicePtr): bool =
  let fn = cast[proc(d: TuyaDevicePtr): bool {.cdecl.}](symAddr("tuya_is_socket_writable"))
  result = fn(dev)

proc tuyaSetSessionReady*(dev: TuyaDevicePtr): bool =
  let fn = cast[proc(d: TuyaDevicePtr): bool {.cdecl.}](symAddr("tuya_set_session_ready"))
  result = fn(dev)

# -- Message building/decoding --------------------------------------

proc tuyaBuildMessage*(dev: TuyaDevicePtr; buf: pointer; cmd: int32; payload, key: string): int32 =
  let fn = cast[proc(d: TuyaDevicePtr; b: pointer; c: int32; p, k: cstring): int32 {.cdecl.}](symAddr("tuya_build_message"))
  result = fn(dev, buf, cmd, payload.cstring, key.cstring)

proc tuyaDecodeMessage*(dev: TuyaDevicePtr; buf: pointer; size: int32; key: string): string =
  let fn = cast[proc(d: TuyaDevicePtr; b: pointer; s: int32; k: cstring): pointer {.cdecl.}](symAddr("tuya_decode_message"))
  result = consumeCString(fn(dev, buf, size, key.cstring))

proc tuyaGeneratePayload*(dev: TuyaDevicePtr; cmd: int32; deviceId, datapoints: string): string =
  let fn = cast[proc(d: TuyaDevicePtr; c: int32; did, dps: cstring): pointer {.cdecl.}](symAddr("tuya_generate_payload"))
  result = consumeCString(fn(dev, cmd, deviceId.cstring, datapoints.cstring))

# -- Raw send/receive ------------------------------------------------

proc tuyaSend*(dev: TuyaDevicePtr; buf: pointer; size: int32): int32 =
  let fn = cast[proc(d: TuyaDevicePtr; b: pointer; s: int32): int32 {.cdecl.}](symAddr("tuya_send"))
  result = fn(dev, buf, size)

proc tuyaReceive*(dev: TuyaDevicePtr; buf: pointer; maxsize, minsize: int32): int32 =
  let fn = cast[proc(d: TuyaDevicePtr; b: pointer; mx, mn: int32): int32 {.cdecl.}](symAddr("tuya_receive"))
  result = fn(dev, buf, maxsize, minsize)

# -- device22 mode ---------------------------------------------------

proc tuyaSetDevice22*(dev: TuyaDevicePtr; nullDpsJson: string) =
  let fn = cast[proc(d: TuyaDevicePtr; j: cstring) {.cdecl.}](symAddr("tuya_set_device22"))
  fn(dev, nullDpsJson.cstring)

proc tuyaIsDevice22*(dev: TuyaDevicePtr): bool =
  let fn = cast[proc(d: TuyaDevicePtr): bool {.cdecl.}](symAddr("tuya_is_device22"))
  result = fn(dev)

# -- High-level round-trip -------------------------------------------

proc tuyaSetValueBool*(dev: TuyaDevicePtr; dp: int32; value: bool): string =
  let fn = cast[proc(d: TuyaDevicePtr; dp: int32; v: bool): pointer {.cdecl.}](symAddr("tuya_set_value_bool"))
  result = consumeCString(fn(dev, dp, value))

proc tuyaSetValueInt*(dev: TuyaDevicePtr; dp, value: int32): string =
  let fn = cast[proc(d: TuyaDevicePtr; dp, v: int32): pointer {.cdecl.}](symAddr("tuya_set_value_int"))
  result = consumeCString(fn(dev, dp, value))

proc tuyaSetValueString*(dev: TuyaDevicePtr; dp: int32; value: string): string =
  let fn = cast[proc(d: TuyaDevicePtr; dp: int32; v: cstring): pointer {.cdecl.}](symAddr("tuya_set_value_string"))
  result = consumeCString(fn(dev, dp, value.cstring))

proc tuyaSetValueFloat*(dev: TuyaDevicePtr; dp: int32; value: float64): string =
  let fn = cast[proc(d: TuyaDevicePtr; dp: int32; v: float64): pointer {.cdecl.}](symAddr("tuya_set_value_float"))
  result = consumeCString(fn(dev, dp, value))

proc tuyaTurnOn*(dev: TuyaDevicePtr; switchDp: int32 = 1): string =
  let fn = cast[proc(d: TuyaDevicePtr; dp: int32): pointer {.cdecl.}](symAddr("tuya_turn_on"))
  result = consumeCString(fn(dev, switchDp))

proc tuyaTurnOff*(dev: TuyaDevicePtr; switchDp: int32 = 1): string =
  let fn = cast[proc(d: TuyaDevicePtr; dp: int32): pointer {.cdecl.}](symAddr("tuya_turn_off"))
  result = consumeCString(fn(dev, switchDp))

proc tuyaStatus*(dev: TuyaDevicePtr): string =
  let fn = cast[proc(d: TuyaDevicePtr): pointer {.cdecl.}](symAddr("tuya_status"))
  result = consumeCString(fn(dev))

proc tuyaHeartbeat*(dev: TuyaDevicePtr): string =
  let fn = cast[proc(d: TuyaDevicePtr): pointer {.cdecl.}](symAddr("tuya_heartbeat"))
  result = consumeCString(fn(dev))

# -- Memory ----------------------------------------------------------

proc tuyaFreeString*(s: cstring) =
  let fn = cast[proc(s: cstring) {.cdecl.}](symAddr("tuya_free_string"))
  if fn != nil: fn(s)

# ==================================================================
#  Type-aware set_value dispatcher
# ==================================================================
#
#  tuyaSetValue(dev, dp, "bool",   true)
#  tuyaSetValue(dev, dp, "int",    42)
#  tuyaSetValue(dev, dp, "string", "hello")
#  tuyaSetValue(dev, dp, "float",  3.14)
#

proc tuyaSetValue*[T](dev: TuyaDevicePtr; dp: int32; typ: string; value: T): string =
  case typ
  of "bool":   tuyaSetValueBool(dev, dp, cast[bool](value))
  of "int":    tuyaSetValueInt(dev, dp, cast[int32](value))
  of "string": tuyaSetValueString(dev, dp, cast[string](value))
  of "float":  tuyaSetValueFloat(dev, dp, cast[float64](value))
  else: raise newException(ValueError, "Unknown type: " & typ)

when isMainModule:
  ## Self-test (run with: nim c -r seatuya.nim)
  echo "seatuya.nim loaded. Library path: ", getEnv("SEATUYA_LIB", "libseatuya.so")

# ==================================================================
#  Constants
# ==================================================================

# Protocol versions
const
  TUYA_PROTO_V31* = 0
  TUYA_PROTO_V33* = 1
  TUYA_PROTO_V34* = 2
  TUYA_PROTO_V35* = 3

# Session states
const
  TUYA_SESSION_INVALID*     = 0
  TUYA_SESSION_STARTING*    = 1
  TUYA_SESSION_FINALIZING*  = 2
  TUYA_SESSION_ESTABLISHED* = 3

# Socket states
const
  TUYA_SOCK_NO_SUCH_HOST*  = 0
  TUYA_SOCK_NO_SOCK_AVAIL* = 1
  TUYA_SOCK_FAILED*        = 2
  TUYA_SOCK_DISCONNECTED*  = 3
  TUYA_SOCK_CONNECTING*    = 4
  TUYA_SOCK_CONNECTED*     = 5
  TUYA_SOCK_READY*         = 6
  TUYA_SOCK_RECEIVING*     = 7

# Misc
const
  TUYA_DEFAULT_PORT*        = 6668
  TUYA_RECOMMENDED_BUFSIZE* = 1024
  TUYA_DEFAULT_RETRY_LIMIT* = 5
  TUYA_DEFAULT_RETRY_DELAY* = 100

# Tuya command types (all 45)
const
  TUYA_CMD_UDP*              = 0
  TUYA_CMD_AP_CONFIG*        = 1
  TUYA_CMD_ACTIVE*           = 2
  TUYA_CMD_BIND*             = 3
  TUYA_CMD_RENAME_GW*        = 4
  TUYA_CMD_RENAME_DEVICE*    = 5
  TUYA_CMD_UNBIND*           = 6
  TUYA_CMD_CONTROL*          = 7
  TUYA_CMD_STATUS*           = 8
  TUYA_CMD_HEART_BEAT*       = 9
  TUYA_CMD_DP_QUERY*         = 10
  TUYA_CMD_QUERY_WIFI*       = 11
  TUYA_CMD_TOKEN_BIND*       = 12
  TUYA_CMD_CONTROL_NEW*      = 13
  TUYA_CMD_ENABLE_WIFI*      = 14
  TUYA_CMD_DP_QUERY_NEW*     = 16
  TUYA_CMD_SCENE_EXECUTE*    = 17
  TUYA_CMD_UPDATEDPS*        = 18
  TUYA_CMD_UDP_NEW*          = 19
  TUYA_CMD_AP_CONFIG_NEW*    = 20
  TUYA_CMD_GET_LOCAL_TIME*   = 28
  TUYA_CMD_WEATHER_OPEN*     = 32
  TUYA_CMD_WEATHER_DATA*     = 33
  TUYA_CMD_STATE_UPLOAD_SYN* = 34
  TUYA_CMD_STATE_UPLOAD_SYN_RECV* = 35
  TUYA_CMD_HEART_BEAT_STOP*  = 37
  TUYA_CMD_STREAM_TRANS*     = 38
  TUYA_CMD_GET_WIFI_STATUS*  = 43
  TUYA_CMD_WIFI_CONNECT_TEST* = 44
  TUYA_CMD_GET_MAC*          = 45
  TUYA_CMD_GET_IR_STATUS*    = 46
  TUYA_CMD_IR_TX_RX_TEST*    = 47
  TUYA_CMD_LAN_GW_ACTIVE*    = 240
  TUYA_CMD_LAN_SUB_DEV_REQUEST* = 241
  TUYA_CMD_LAN_DELETE_SUB_DEV*  = 242
  TUYA_CMD_LAN_REPORT_SUB_DEV*  = 243
  TUYA_CMD_LAN_SCENE*        = 244
  TUYA_CMD_LAN_PUBLISH_CLOUD_CONFIG* = 245
  TUYA_CMD_LAN_PUBLISH_APP_CONFIG*   = 246
  TUYA_CMD_LAN_EXPORT_APP_CONFIG*    = 247
  TUYA_CMD_LAN_PUBLISH_SCENE_PANEL*  = 248
  TUYA_CMD_LAN_REMOVE_GW*   = 249
  TUYA_CMD_LAN_CHECK_GW_UPDATE* = 250
  TUYA_CMD_LAN_GW_UPDATE*   = 251
  TUYA_CMD_LAN_SET_GW_CHANNEL* = 252
