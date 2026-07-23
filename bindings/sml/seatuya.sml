(* seatuya.sml -- Standard ML (MLton) FFI bindings for libseatuya
 *
 * MLton uses _import for C function declarations, resolved via the standard
 * dynamic linker.  Set SEATUYA_LIB at build time to point ld(1) at a custom
 * library directory, or at run time via LD_LIBRARY_PATH / DYLD_LIBRARY_PATH.
 *
 * Build:
 *   mlton -link-opt -lseatuya example.sml
 *
 * Usage:
 *   val dev = Seatuya.create ("id", "192.168.1.100", "key", "3.4")
 *   print (Seatuya.turnOn (dev, 1) ^ "\n")
 *   Seatuya.destroy dev
 *)

structure Seatuya : sig
  (* Types *)
  type device
  type value

  datatype protocol = PROTO_V31 | PROTO_V33 | PROTO_V34 | PROTO_V35
  datatype session_state = SESS_INVALID | SESS_STARTING | SESS_FINALIZING | SESS_ESTABLISHED
  datatype socket_state =
    SOCK_NO_SUCH_HOST | SOCK_NO_SOCK_AVAIL | SOCK_FAILED | SOCK_DISCONNECTED
  | SOCK_CONNECTING | SOCK_CONNECTED | SOCK_READY | SOCK_RECEIVING

  (* Version *)
  val version : unit -> string

  (* Lifecycle *)
  val create : string * string * string * string -> device option
  val alloc : string -> device option
  val destroy : device -> unit

  (* Credentials *)
  val setCredentials : device * string * string -> unit
  val getDeviceId : device -> string
  val getLocalKey : device -> string
  val getIp : device -> string

  (* Connection *)
  val connect : device * string -> bool
  val disconnect : device -> unit
  val isConnected : device -> bool
  val reconnect : device -> bool

  (* Retry *)
  val setRetryLimit : device * int -> unit
  val setRetryDelay : device * int -> unit
  val getRetryLimit : device -> int
  val getRetryDelay : device -> int

  (* Session negotiation *)
  val negotiateSession : device * string -> bool
  val negotiateSessionStart : device * string -> bool
  val negotiateSessionFinalize : device * char ptr * int * string -> bool

  (* State *)
  val getProtocol : device -> protocol
  val getSessionState : device -> session_state
  val getSocketState : device -> socket_state
  val getLastError : device -> int

  (* Async *)
  val setAsyncMode : device * bool -> unit
  val isSocketReadable : device -> bool
  val isSocketWritable : device -> bool
  val setSessionReady : device -> bool

  (* Low-level message *)
  val buildMessage : device * char ptr * int * string * string -> int
  val decodeMessage : device * char ptr * int * string -> string option
  val generatePayload : device * int * string * string -> string option
  val send : device * char ptr * int -> int
  val receive : device * char ptr * int * int -> int

  (* High-level round-trip *)
  val setValueBool : device * int * bool -> string
  val setValueInt : device * int * int -> string
  val setValueString : device * int * string -> string
  val setValueFloat : device * int * real -> string
  val turnOn : device * int -> string
  val turnOff : device * int -> string
  val status : device -> string
  val heartbeat : device -> string

  (* Type-aware dispatcher *)
  val setValue : device * int * value -> string

  (* Device22 *)
  val setDevice22 : device * string -> unit
  val isDevice22 : device -> bool

  (* Constants *)
  val cmdUDP : int
  val cmdApConfig : int
  val cmdActive : int
  val cmdBind : int
  val cmdRenameGw : int
  val cmdRenameDevice : int
  val cmdUnbind : int
  val cmdControl : int
  val cmdStatus : int
  val cmdHeartBeat : int
  val cmdDpQuery : int
  val cmdQueryWifi : int
  val cmdTokenBind : int
  val cmdControlNew : int
  val cmdEnableWifi : int
  val cmdDpQueryNew : int
  val cmdSceneExecute : int
  val cmdUpdateDps : int
  val cmdUdpNew : int
  val cmdApConfigNew : int
  val cmdGetLocalTime : int
  val cmdWeatherOpen : int
  val cmdWeatherData : int
  val cmdStateUploadSyn : int
  val cmdStateUploadSynRecv : int
  val cmdHeartBeatStop : int
  val cmdStreamTrans : int
  val cmdGetWifiStatus : int
  val cmdWifiConnectTest : int
  val cmdGetMac : int
  val cmdGetIrStatus : int
  val cmdIrTxRxTest : int
  val cmdLanGwActive : int
  val cmdLanSubDevRequest : int
  val cmdLanDeleteSubDev : int
  val cmdLanReportSubDev : int
  val cmdLanScene : int
  val cmdLanPublishCloudConfig : int
  val cmdLanPublishAppConfig : int
  val cmdLanExportAppConfig : int
  val cmdLanPublishScenePanel : int
  val cmdLanRemoveGw : int
  val cmdLanCheckGwUpdate : int
  val cmdLanGwUpdate : int
  val cmdLanSetGwChannel : int
  val defaultPort : int
  val bufSize : int
end = struct
  type device = word
  type 'a ptr = 'a ptr
  type char ptr = char ptr

  datatype value = BOOL of bool | INT of int | FLOAT of real | STRING of string

  datatype protocol = PROTO_V31 | PROTO_V33 | PROTO_V34 | PROTO_V35
  datatype session_state = SESS_INVALID | SESS_STARTING | SESS_FINALIZING | SESS_ESTABLISHED
  datatype socket_state =
    SOCK_NO_SUCH_HOST | SOCK_NO_SOCK_AVAIL | SOCK_FAILED | SOCK_DISCONNECTED
  | SOCK_CONNECTING | SOCK_CONNECTED | SOCK_READY | SOCK_RECEIVING

  (* ---- raw imports ---- *)

  val c_version = _import "tuya_version" : unit -> string
  val c_create = _import "tuya_create" : string * string * string * string -> word
  val c_alloc = _import "tuya_alloc" : string -> word
  val c_destroy = _import "tuya_destroy" : word -> unit

  val c_set_creds = _import "tuya_set_credentials" : word * string * string -> unit
  val c_get_devid = _import "tuya_get_device_id" : word -> string
  val c_get_key = _import "tuya_get_local_key" : word -> string
  val c_get_ip = _import "tuya_get_ip" : word -> string

  val c_connect = _import "tuya_connect" : word * string -> int
  val c_disconnect = _import "tuya_disconnect" : word -> unit
  val c_is_conn = _import "tuya_is_connected" : word -> int
  val c_reconnect = _import "tuya_reconnect" : word -> int

  val c_set_retry_limit = _import "tuya_set_retry_limit" : word * int -> unit
  val c_set_retry_delay = _import "tuya_set_retry_delay" : word * int -> unit
  val c_get_retry_limit = _import "tuya_get_retry_limit" : word -> int
  val c_get_retry_delay = _import "tuya_get_retry_delay" : word -> int

  val c_neg_sess = _import "tuya_negotiate_session" : word * string -> int
  val c_neg_start = _import "tuya_negotiate_session_start" : word * string -> int
  val c_neg_final = _import "tuya_negotiate_session_finalize" : word * char ptr * int * string -> int

  val c_get_proto = _import "tuya_get_protocol" : word -> int
  val c_get_sess = _import "tuya_get_session_state" : word -> int
  val c_get_sock = _import "tuya_get_socket_state" : word -> int
  val c_get_err = _import "tuya_get_last_error" : word -> int

  val c_set_async = _import "tuya_set_async_mode" : word * int -> unit
  val c_readable = _import "tuya_is_socket_readable" : word -> int
  val c_writable = _import "tuya_is_socket_writable" : word -> int
  val c_set_ready = _import "tuya_set_session_ready" : word -> int

  val c_build = _import "tuya_build_message" : word * char ptr * int * string * string -> int
  val c_decode = _import "tuya_decode_message" : word * char ptr * int * string -> string
  val c_gen = _import "tuya_generate_payload" : word * int * string * string -> string
  val c_send = _import "tuya_send" : word * char ptr * int -> int
  val c_recv = _import "tuya_receive" : word * char ptr * int * int -> int

  val c_set_bool = _import "tuya_set_value_bool" : word * int * int -> string
  val c_set_int = _import "tuya_set_value_int" : word * int * int -> string
  val c_set_str = _import "tuya_set_value_string" : word * int * string -> string
  val c_set_flt = _import "tuya_set_value_float" : word * int * real -> string

  val c_turn_on = _import "tuya_turn_on" : word * int -> string
  val c_turn_off = _import "tuya_turn_off" : word * int -> string
  val c_status = _import "tuya_status" : word -> string
  val c_heartbeat = _import "tuya_heartbeat" : word -> string

  val c_free_str = _import "tuya_free_string" : word -> unit
  val c_set_d22 = _import "tuya_set_device22" : word * string -> unit
  val c_is_d22 = _import "tuya_is_device22" : word -> int

  (* ---- helpers ---- *)

  fun toBool 0 = false | toBool _ = true

  fun asDevice 0w0 = NONE
    | asDevice w = SOME w

  (* ---- public API ---- *)

  fun version () = c_version ()

  fun create (did, addr, key, ver) = asDevice (c_create (did, addr, key, ver))
  fun alloc ver = asDevice (c_alloc ver)
  fun destroy dev = c_destroy dev

  fun setCredentials (dev, did, key) = c_set_creds (dev, did, key)
  fun getDeviceId dev = c_get_devid dev
  fun getLocalKey dev = c_get_key dev
  fun getIp dev = c_get_ip dev

  fun connect (dev, host) = toBool (c_connect (dev, host))
  fun disconnect dev = c_disconnect dev
  fun isConnected dev = toBool (c_is_conn dev)
  fun reconnect dev = toBool (c_reconnect dev)

  fun setRetryLimit (dev, n) = c_set_retry_limit (dev, n)
  fun setRetryDelay (dev, ms) = c_set_retry_delay (dev, ms)
  fun getRetryLimit dev = c_get_retry_limit dev
  fun getRetryDelay dev = c_get_retry_delay dev

  fun negotiateSession (dev, key) = toBool (c_neg_sess (dev, key))
  fun negotiateSessionStart (dev, key) = toBool (c_neg_start (dev, key))
  fun negotiateSessionFinalize (dev, buf, sz, key) = toBool (c_neg_final (dev, buf, sz, key))

  fun getProtocol dev =
    case c_get_proto dev of
      0 => PROTO_V31 | 1 => PROTO_V33 | 2 => PROTO_V34 | _ => PROTO_V35

  fun getSessionState dev =
    case c_get_sess dev of
      0 => SESS_INVALID | 1 => SESS_STARTING | 2 => SESS_FINALIZING | _ => SESS_ESTABLISHED

  fun getSocketState dev =
    case c_get_sock dev of
      0 => SOCK_NO_SUCH_HOST | 1 => SOCK_NO_SOCK_AVAIL | 2 => SOCK_FAILED
    | 3 => SOCK_DISCONNECTED | 4 => SOCK_CONNECTING | 5 => SOCK_CONNECTED
    | 6 => SOCK_READY | _ => SOCK_RECEIVING

  fun getLastError dev = c_get_err dev

  fun setAsyncMode (dev, flag) = c_set_async (dev, if flag then 1 else 0)
  fun isSocketReadable dev = toBool (c_readable dev)
  fun isSocketWritable dev = toBool (c_writable dev)
  fun setSessionReady dev = toBool (c_set_ready dev)

  fun buildMessage (dev, buf, cmd, payload, key) = c_build (dev, buf, cmd, payload, key)

  fun decodeMessage (dev, buf, sz, key) =
    let val s = c_decode (dev, buf, sz, key)
    in if s = "" then NONE else SOME s end

  fun generatePayload (dev, cmd, devId, dps) =
    let val s = c_gen (dev, cmd, devId, dps)
    in if s = "" then NONE else SOME s end

  fun send (dev, buf, sz) = c_send (dev, buf, sz)
  fun receive (dev, buf, maxsz, minsz) = c_recv (dev, buf, maxsz, minsz)

  fun setValueBool (dev, dp, v) = c_set_bool (dev, dp, if v then 1 else 0)
  fun setValueInt (dev, dp, v) = c_set_int (dev, dp, v)
  fun setValueString (dev, dp, v) = c_set_str (dev, dp, v)
  fun setValueFloat (dev, dp, v) = c_set_flt (dev, dp, v)

  fun turnOn (dev, dp) = c_turn_on (dev, dp)
  fun turnOff (dev, dp) = c_turn_off (dev, dp)
  fun status dev = c_status dev
  fun heartbeat dev = c_heartbeat dev

  fun setValue (dev, dp, BOOL b) = setValueBool (dev, dp, b)
    | setValue (dev, dp, INT n) = setValueInt (dev, dp, n)
    | setValue (dev, dp, FLOAT r) = setValueFloat (dev, dp, r)
    | setValue (dev, dp, STRING s) = setValueString (dev, dp, s)

  fun setDevice22 (dev, json) = c_set_d22 (dev, json)
  fun isDevice22 dev = toBool (c_is_d22 dev)

  (* ---- constants (43 command types) ---- *)

  val cmdUDP = 0
  val cmdApConfig = 1
  val cmdActive = 2
  val cmdBind = 3
  val cmdRenameGw = 4
  val cmdRenameDevice = 5
  val cmdUnbind = 6
  val cmdControl = 7
  val cmdStatus = 8
  val cmdHeartBeat = 9
  val cmdDpQuery = 10
  val cmdQueryWifi = 11
  val cmdTokenBind = 12
  val cmdControlNew = 13
  val cmdEnableWifi = 14
  val cmdDpQueryNew = 16
  val cmdSceneExecute = 17
  val cmdUpdateDps = 18
  val cmdUdpNew = 19
  val cmdApConfigNew = 20
  val cmdGetLocalTime = 28
  val cmdWeatherOpen = 32
  val cmdWeatherData = 33
  val cmdStateUploadSyn = 34
  val cmdStateUploadSynRecv = 35
  val cmdHeartBeatStop = 37
  val cmdStreamTrans = 38
  val cmdGetWifiStatus = 43
  val cmdWifiConnectTest = 44
  val cmdGetMac = 45
  val cmdGetIrStatus = 46
  val cmdIrTxRxTest = 47
  val cmdLanGwActive = 240
  val cmdLanSubDevRequest = 241
  val cmdLanDeleteSubDev = 242
  val cmdLanReportSubDev = 243
  val cmdLanScene = 244
  val cmdLanPublishCloudConfig = 245
  val cmdLanPublishAppConfig = 246
  val cmdLanExportAppConfig = 247
  val cmdLanPublishScenePanel = 248
  val cmdLanRemoveGw = 249
  val cmdLanCheckGwUpdate = 250
  val cmdLanGwUpdate = 251
  val cmdLanSetGwChannel = 252
  val defaultPort = 6668
  val bufSize = 1024
end
