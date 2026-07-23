(* seatuya.ml -- OCaml FFI bindings for libseatuya using ctypes
 *
 * Requires: opam install ctypes
 * Set SEATUYA_LIB to a custom library path.
 *
 * Usage:
 *   let dev = Seatuya.create "id" "192.168.1.100" "key" "3.4" in
 *   ignore (Seatuya.turn_on dev 1);
 *   Seatuya.destroy dev
 *)

open Ctypes
open Foreign

(* ------------------------------------------------------------------ *)
(*  Library loading                                                    *)
(* ------------------------------------------------------------------ *)

let libname =
  try Sys.getenv "SEATUYA_LIB"
  with Not_found ->
    match Sys.os_type with
    | "Win32" -> "seatuya.dll"
    | "Darwin" -> "libseatuya.dylib"
    | _ -> "libseatuya.so"

let lib = Dl.dlopen ~filename:libname ~flags:[Dl.RTLD_NOW]

(* ------------------------------------------------------------------ *)
(*  Helper: consume a malloc'd C string                                *)
(* ------------------------------------------------------------------ *)

let consume_nullable fn arg =
  let p = fn arg in
  if is_null p then None
  else
    let s = !@ (from_ptr p string) in
    let free = foreign ~from:lib "tuya_free_string" (ptr char @-> returning void) in
    free p;
    Some s

let consume fn arg =
  match consume_nullable fn arg with
  | None -> ""
  | Some s -> s

let string_of_internal p =
  if is_null p then ""
  else !@ (from_ptr p string)

let to_bool n = n <> 0

(* ------------------------------------------------------------------ *)
(*  Types                                                              *)
(* ------------------------------------------------------------------ *)

type device = unit ptr
let device : unit ptr typ = ptr void

(* ------------------------------------------------------------------ *)
(*  Version                                                            *)
(* ------------------------------------------------------------------ *)

let version : unit -> string =
  foreign ~from:lib "tuya_version" (void @-> returning string)

(* ------------------------------------------------------------------ *)
(*  Lifecycle                                                          *)
(* ------------------------------------------------------------------ *)

let create_raw : string -> string -> string -> string -> device =
  foreign ~from:lib "tuya_create"
    (string @-> string @-> string @-> string @-> returning device)

let create did addr key ver =
  let d = create_raw did addr key ver in
  if is_null d then None else Some d

let alloc_raw : string -> device =
  foreign ~from:lib "tuya_alloc" (string @-> returning device)

let alloc ver =
  let d = alloc_raw ver in
  if is_null d then None else Some d

let destroy : device -> unit =
  foreign ~from:lib "tuya_destroy" (device @-> returning void)

(* ------------------------------------------------------------------ *)
(*  Credentials                                                        *)
(* ------------------------------------------------------------------ *)

let set_credentials : device -> string -> string -> unit =
  foreign ~from:lib "tuya_set_credentials"
    (device @-> string @-> string @-> returning void)

let get_device_id_raw : device -> string ptr =
  foreign ~from:lib "tuya_get_device_id" (device @-> returning (ptr char))

let get_device_id d = string_of_internal (get_device_id_raw d)

let get_local_key_raw : device -> string ptr =
  foreign ~from:lib "tuya_get_local_key" (device @-> returning (ptr char))

let get_local_key d = string_of_internal (get_local_key_raw d)

let get_ip_raw : device -> string ptr =
  foreign ~from:lib "tuya_get_ip" (device @-> returning (ptr char))

let get_ip d = string_of_internal (get_ip_raw d)

(* ------------------------------------------------------------------ *)
(*  Connection                                                         *)
(* ------------------------------------------------------------------ *)

let connect_raw : device -> string -> int =
  foreign ~from:lib "tuya_connect" (device @-> string @-> returning int)

let connect d h = to_bool (connect_raw d h)

let disconnect : device -> unit =
  foreign ~from:lib "tuya_disconnect" (device @-> returning void)

let is_connected_raw : device -> int =
  foreign ~from:lib "tuya_is_connected" (device @-> returning int)

let is_connected d = to_bool (is_connected_raw d)

let reconnect_raw : device -> int =
  foreign ~from:lib "tuya_reconnect" (device @-> returning int)

let reconnect d = to_bool (reconnect_raw d)

(* ------------------------------------------------------------------ *)
(*  Retry                                                              *)
(* ------------------------------------------------------------------ *)

let set_retry_limit : device -> int -> unit =
  foreign ~from:lib "tuya_set_retry_limit"
    (device @-> int @-> returning void)

let set_retry_delay : device -> int -> unit =
  foreign ~from:lib "tuya_set_retry_delay"
    (device @-> int @-> returning void)

let get_retry_limit : device -> int =
  foreign ~from:lib "tuya_get_retry_limit" (device @-> returning int)

let get_retry_delay : device -> int =
  foreign ~from:lib "tuya_get_retry_delay" (device @-> returning int)

(* ------------------------------------------------------------------ *)
(*  Session negotiation                                                *)
(* ------------------------------------------------------------------ *)

let negotiate_session_raw : device -> string -> int =
  foreign ~from:lib "tuya_negotiate_session"
    (device @-> string @-> returning int)

let negotiate_session d k = to_bool (negotiate_session_raw d k)

let negotiate_session_start_raw : device -> string -> int =
  foreign ~from:lib "tuya_negotiate_session_start"
    (device @-> string @-> returning int)

let negotiate_session_start d k =
  to_bool (negotiate_session_start_raw d k)

let negotiate_session_finalize_raw : device -> char ptr -> int -> string -> int =
  foreign ~from:lib "tuya_negotiate_session_finalize"
    (device @-> ptr char @-> int @-> string @-> returning int)

let negotiate_session_finalize d buf sz k =
  to_bool (negotiate_session_finalize_raw d buf sz k)

(* ------------------------------------------------------------------ *)
(*  State queries                                                      *)
(* ------------------------------------------------------------------ *)

let get_protocol : device -> int =
  foreign ~from:lib "tuya_get_protocol" (device @-> returning int)

let get_session_state : device -> int =
  foreign ~from:lib "tuya_get_session_state" (device @-> returning int)

let get_socket_state : device -> int =
  foreign ~from:lib "tuya_get_socket_state" (device @-> returning int)

let get_last_error : device -> int =
  foreign ~from:lib "tuya_get_last_error" (device @-> returning int)

(* ------------------------------------------------------------------ *)
(*  Async mode                                                         *)
(* ------------------------------------------------------------------ *)

let set_async_mode_raw : device -> int -> unit =
  foreign ~from:lib "tuya_set_async_mode"
    (device @-> int @-> returning void)

let set_async_mode d flag = set_async_mode_raw d (if flag then 1 else 0)

let is_socket_readable_raw : device -> int =
  foreign ~from:lib "tuya_is_socket_readable" (device @-> returning int)

let is_socket_readable d = to_bool (is_socket_readable_raw d)

let is_socket_writable_raw : device -> int =
  foreign ~from:lib "tuya_is_socket_writable" (device @-> returning int)

let is_socket_writable d = to_bool (is_socket_writable_raw d)

let set_session_ready_raw : device -> int =
  foreign ~from:lib "tuya_set_session_ready" (device @-> returning int)

let set_session_ready d = to_bool (set_session_ready_raw d)

(* ------------------------------------------------------------------ *)
(*  Low-level message building and decoding                            *)
(* ------------------------------------------------------------------ *)

let build_message : device -> char ptr -> int -> string -> string -> int =
  foreign ~from:lib "tuya_build_message"
    (device @-> ptr char @-> int @-> string @-> string @-> returning int)

let decode_message_raw : device -> char ptr -> int -> string -> char ptr =
  foreign ~from:lib "tuya_decode_message"
    (device @-> ptr char @-> int @-> string @-> returning (ptr char))

let decode_message d buf sz k =
  consume_nullable (decode_message_raw d buf sz) k

let generate_payload_raw : device -> int -> string -> string -> char ptr =
  foreign ~from:lib "tuya_generate_payload"
    (device @-> int @-> string @-> string @-> returning (ptr char))

let generate_payload d cmd dev_id dps =
  let p = generate_payload_raw d cmd dev_id dps in
  if is_null p then None
  else
    let s = !@ (from_ptr p string) in
    let free = foreign ~from:lib "tuya_free_string" (ptr char @-> returning void) in
    free p;
    Some s

let send : device -> char ptr -> int -> int =
  foreign ~from:lib "tuya_send"
    (device @-> ptr char @-> int @-> returning int)

let receive : device -> char ptr -> int -> int -> int =
  foreign ~from:lib "tuya_receive"
    (device @-> ptr char @-> int @-> int @-> returning int)

(* ------------------------------------------------------------------ *)
(*  High-level round-trip operations                                   *)
(* ------------------------------------------------------------------ *)

let set_value_bool_raw : device -> int -> int -> char ptr =
  foreign ~from:lib "tuya_set_value_bool"
    (device @-> int @-> int @-> returning (ptr char))

let set_value_bool d dp v = consume (set_value_bool_raw d dp (if v then 1 else 0))

let set_value_int_raw : device -> int -> int -> char ptr =
  foreign ~from:lib "tuya_set_value_int"
    (device @-> int @-> int @-> returning (ptr char))

let set_value_int d dp v = consume (set_value_int_raw d dp v)

let set_value_string_raw : device -> int -> string -> char ptr =
  foreign ~from:lib "tuya_set_value_string"
    (device @-> int @-> string @-> returning (ptr char))

let set_value_string d dp v = consume (set_value_string_raw d dp v)

let set_value_float_raw : device -> int -> float -> char ptr =
  foreign ~from:lib "tuya_set_value_float"
    (device @-> int @-> float @-> returning (ptr char))

let set_value_float d dp v = consume (set_value_float_raw d dp v)

let turn_on_raw : device -> int -> char ptr =
  foreign ~from:lib "tuya_turn_on"
    (device @-> int @-> returning (ptr char))

let turn_on d dp = consume (turn_on_raw d dp)

let turn_off_raw : device -> int -> char ptr =
  foreign ~from:lib "tuya_turn_off"
    (device @-> int @-> returning (ptr char))

let turn_off d dp = consume (turn_off_raw d dp)

let status_raw : device -> char ptr =
  foreign ~from:lib "tuya_status" (device @-> returning (ptr char))

let status d = consume (status_raw d)

let heartbeat_raw : device -> char ptr =
  foreign ~from:lib "tuya_heartbeat" (device @-> returning (ptr char))

let heartbeat d = consume (heartbeat_raw d)

(* ------------------------------------------------------------------ *)
(*  Type-aware dispatcher                                              *)
(* ------------------------------------------------------------------ *)

type set_value_arg = Bool of bool | Int of int | Float of float | String of string

let set_value dev dp = function
  | Bool b   -> set_value_bool dev dp b
  | Int n    -> set_value_int dev dp n
  | Float f  -> set_value_float dev dp f
  | String s -> set_value_string dev dp s

(* ------------------------------------------------------------------ *)
(*  Device22                                                           *)
(* ------------------------------------------------------------------ *)

let set_device22_raw : device -> char ptr -> unit =
  foreign ~from:lib "tuya_set_device22"
    (device @-> ptr char @-> returning void)

let set_device22 d = function
  | None -> set_device22_raw d null
  | Some json ->
    let cjson = CArray.make char (String.length json + 1) in
    CArray.blit_of_string json cjson;
    CArray.set cjson (String.length json) '\x00';
    set_device22_raw d (CArray.start cjson)

let is_device22_raw : device -> int =
  foreign ~from:lib "tuya_is_device22" (device @-> returning int)

let is_device22 d = to_bool (is_device22_raw d)

(* ------------------------------------------------------------------ *)
(*  Constants                                                          *)
(* ------------------------------------------------------------------ *)

(* Tuya command types -- all 43 values *)
type command =
  | CmdUDP | CmdApConfig | CmdActive | CmdBind | CmdRenameGw
  | CmdRenameDevice | CmdUnbind | CmdControl | CmdStatus | CmdHeartBeat
  | CmdDpQuery | CmdQueryWifi | CmdTokenBind | CmdControlNew | CmdEnableWifi
  | CmdDpQueryNew | CmdSceneExecute | CmdUpdateDps | CmdUdpNew | CmdApConfigNew
  | CmdGetLocalTime | CmdWeatherOpen | CmdWeatherData | CmdStateUploadSyn
  | CmdStateUploadSynRecv | CmdHeartBeatStop | CmdStreamTrans
  | CmdGetWifiStatus | CmdWifiConnectTest | CmdGetMac | CmdGetIrStatus
  | CmdIrTxRxTest | CmdLanGwActive | CmdLanSubDevRequest | CmdLanDeleteSubDev
  | CmdLanReportSubDev | CmdLanScene | CmdLanPublishCloudConfig
  | CmdLanPublishAppConfig | CmdLanExportAppConfig | CmdLanPublishScenePanel
  | CmdLanRemoveGw | CmdLanCheckGwUpdate | CmdLanGwUpdate | CmdLanSetGwChannel

let cmd_value = function
  | CmdUDP -> 0 | CmdApConfig -> 1 | CmdActive -> 2 | CmdBind -> 3
  | CmdRenameGw -> 4 | CmdRenameDevice -> 5 | CmdUnbind -> 6
  | CmdControl -> 7 | CmdStatus -> 8 | CmdHeartBeat -> 9
  | CmdDpQuery -> 10 | CmdQueryWifi -> 11 | CmdTokenBind -> 12
  | CmdControlNew -> 13 | CmdEnableWifi -> 14 | CmdDpQueryNew -> 16
  | CmdSceneExecute -> 17 | CmdUpdateDps -> 18 | CmdUdpNew -> 19
  | CmdApConfigNew -> 20 | CmdGetLocalTime -> 28 | CmdWeatherOpen -> 32
  | CmdWeatherData -> 33 | CmdStateUploadSyn -> 34
  | CmdStateUploadSynRecv -> 35 | CmdHeartBeatStop -> 37
  | CmdStreamTrans -> 38 | CmdGetWifiStatus -> 43
  | CmdWifiConnectTest -> 44 | CmdGetMac -> 45 | CmdGetIrStatus -> 46
  | CmdIrTxRxTest -> 47 | CmdLanGwActive -> 240
  | CmdLanSubDevRequest -> 241 | CmdLanDeleteSubDev -> 242
  | CmdLanReportSubDev -> 243 | CmdLanScene -> 244
  | CmdLanPublishCloudConfig -> 245 | CmdLanPublishAppConfig -> 246
  | CmdLanExportAppConfig -> 247 | CmdLanPublishScenePanel -> 248
  | CmdLanRemoveGw -> 249 | CmdLanCheckGwUpdate -> 250
  | CmdLanGwUpdate -> 251 | CmdLanSetGwChannel -> 252

let cmd_control = 7
let cmd_dp_query = 10
let cmd_heart_beat = 9
let cmd_status = 8
let cmd_control_new = 13
let cmd_dp_query_new = 16

(* Protocol versions *)
type protocol = ProtoV31 | ProtoV33 | ProtoV34 | ProtoV35

let protocol_of_int = function
  | 0 -> ProtoV31 | 1 -> ProtoV33 | 2 -> ProtoV34 | _ -> ProtoV35

(* Session states *)
type session_state = SessInvalid | SessStarting | SessFinalizing | SessEstablished

let session_state_of_int = function
  | 0 -> SessInvalid | 1 -> SessStarting | 2 -> SessFinalizing | _ -> SessEstablished

(* Socket states *)
type socket_state =
  | SockNoSuchHost | SockNoSockAvail | SockFailed | SockDisconnected
  | SockConnecting | SockConnected | SockReady | SockReceiving

let socket_state_of_int = function
  | 0 -> SockNoSuchHost | 1 -> SockNoSockAvail | 2 -> SockFailed
  | 3 -> SockDisconnected | 4 -> SockConnecting | 5 -> SockConnected
  | 6 -> SockReady | _ -> SockReceiving

(* Misc *)
let default_port = 6668
let bufsize = 1024
let default_retry_limit = 5
let default_retry_delay = 100
