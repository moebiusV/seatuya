(* seatuya.sml — Standard ML (MLton) FFI bindings for libseatuya
 *
 * MLton uses _import for C function declarations.
 * The opaque pointer is represented as an ML word ref.
 *
 * Usage:
 *   val dev = Seatuya.create "id" "192.168.1.100" "key" "3.4"
 *   print (Seatuya.turn_on dev 1 ^ "\n")
 *   Seatuya.destroy dev
 *)

structure Seatuya :> sig
  val version : unit -> string
  val create : string * string * string * string -> word
  val alloc : string -> word
  val destroy : word -> unit
  val connect : word * string -> bool
  val disconnect : word -> unit
  val isConnected : word -> bool
  val reconnect : word -> bool
  val setCredentials : word * string * string -> unit
  val getDeviceId : word -> string
  val getLocalKey : word -> string
  val getIp : word -> string
  val turnOn : word * int -> string
  val turnOff : word * int -> string
  val status : word -> string
  val heartbeat : word -> string
  val setValueBool : word * int * bool -> string
  val setValueInt : word * int * int -> string
  val setValueString : word * int * string -> string
  val setValueFloat : word * int * real -> string
  val getProtocol : word -> int
  val getLastError : word -> int
  val setAsyncMode : word * bool -> unit
  val setDevice22 : word * string -> unit
  val isDevice22 : word -> bool
  val cmdControl : int
  val cmdDpQuery : int
end = struct
  (* The MLton way: import each C function *)
  val version' = _import "tuya_version" : unit -> string;
  val create' = _import "tuya_create" : string * string * string * string -> word;
  val alloc' = _import "tuya_alloc" : string -> word;
  val destroy' = _import "tuya_destroy" : word -> unit;
  val connect' = _import "tuya_connect" : word * string -> int;
  val disconnect' = _import "tuya_disconnect" : word -> unit;
  val isConnected' = _import "tuya_is_connected" : word -> int;
  val reconnect' = _import "tuya_reconnect" : word -> int;
  val setCredentials' = _import "tuya_set_credentials" : word * string * string -> unit;
  val getDeviceId' = _import "tuya_get_device_id" : word -> string;
  val getLocalKey' = _import "tuya_get_local_key" : word -> string;
  val getIp' = _import "tuya_get_ip" : word -> string;
  val setValueBool' = _import "tuya_set_value_bool" : word * int * int -> string;
  val setValueInt' = _import "tuya_set_value_int" : word * int * int -> string;
  val setValueString' = _import "tuya_set_value_string" : word * int * string -> string;
  val setValueFloat' = _import "tuya_set_value_float" : word * int * real -> string;
  val turnOn' = _import "tuya_turn_on" : word * int -> string;
  val turnOff' = _import "tuya_turn_off" : word * int -> string;
  val status' = _import "tuya_status" : word -> string;
  val heartbeat' = _import "tuya_heartbeat" : word -> string;
  val freeString' = _import "tuya_free_string" : string -> unit;
  val getProtocol' = _import "tuya_get_protocol" : word -> int;
  val getLastError' = _import "tuya_get_last_error" : word -> int;
  val setAsyncMode' = _import "tuya_set_async_mode" : word * int -> unit;
  val setDevice22' = _import "tuya_set_device22" : word * string -> unit;
  val isDevice22' = _import "tuya_is_device22" : word -> int;

  fun toBool 0 = false | toBool _ = true
  fun version () = version' ()
  fun create (did, ip, key, ver) = create' (did, ip, key, ver)
  fun alloc ver = alloc' ver
  fun destroy dev = destroy' dev
  fun connect (dev, host) = toBool (connect' (dev, host))
  fun disconnect dev = disconnect' dev
  fun isConnected dev = toBool (isConnected' dev)
  fun reconnect dev = toBool (reconnect' dev)
  fun setCredentials (dev, did, key) = setCredentials' (dev, did, key)
  fun getDeviceId dev = getDeviceId' dev
  fun getLocalKey dev = getLocalKey' dev
  fun getIp dev = getIp' dev
  fun turnOn (dev, dp) = turnOn' (dev, dp)
  fun turnOff (dev, dp) = turnOff' (dev, dp)
  fun status dev = status' dev
  fun heartbeat dev = heartbeat' dev
  fun setValueBool (dev, dp, v) = setValueBool' (dev, dp, if v then 1 else 0)
  fun setValueInt (dev, dp, v) = setValueInt' (dev, dp, v)
  fun setValueString (dev, dp, v) = setValueString' (dev, dp, v)
  fun setValueFloat (dev, dp, v) = setValueFloat' (dev, dp, v)
  fun getProtocol dev = getProtocol' dev
  fun getLastError dev = getLastError' dev
  fun setAsyncMode (dev, b) = setAsyncMode' (dev, if b then 1 else 0)
  fun setDevice22 (dev, json) = setDevice22' (dev, json)
  fun isDevice22 dev = toBool (isDevice22' dev)

  val cmdControl = 7
  val cmdDpQuery = 10
end
