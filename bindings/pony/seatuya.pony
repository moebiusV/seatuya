// seatuya.pony -- Pony FFI bindings for libseatuya
//
// Compile-time linkage with `use "lib:seatuya"`.  Build with:
//   ponyc --library seatuya --librarypath /usr/local/lib ...
//
// The Device class wraps the opaque C handle and calls tuya_destroy
// in _final().  All functions using malloc'd C strings (Status,
// TurnOn, TurnOff, Heartbeat, SetValue*) auto-consume and free the
// C memory.
//
// Usage:
//   let dev = Device.create(deviceId, ip, localKey, version)?
//   dev.turn_on(1)
//
// Set SEATUYA_LIB env var at link/load time for custom paths.

use "lib:seatuya" if posix

use @pony_os_getenv[Pointer[U8]](name: Pointer[U8] tag)
use @dlopen[Pointer[None]](path: Pointer[U8] tag, flags: I32)
use @dlerror[Pointer[U8]]()

class Device
  var _h: Pointer[None] = Pointer[None]

  // --- Lifecycle ---

  new create(device_id: String, address: String, local_key: String,
    version: String)
  ?
    _ensure_library()
    _h = @tuya_create[Pointer[None]](
      device_id.cstring(), address.cstring(),
      local_key.cstring(), version.cstring())
    if _h.is_null() then error end

  new alloc(version: String) ?
    _ensure_library()
    _h = @tuya_alloc[Pointer[None]](version.cstring())
    if _h.is_null() then error end

  fun _final() =>
    if not _h.is_null() then @tuya_destroy[None](_h) end

  // --- Credentials ---

  fun ref set_credentials(device_id: String, local_key: String) =>
    @tuya_set_credentials[None](_h, device_id.cstring(), local_key.cstring())

  fun device_id(): String =>
    String.from_cstring(@tuya_get_device_id[Pointer[U8]](_h))

  fun local_key(): String =>
    String.from_cstring(@tuya_get_local_key[Pointer[U8]](_h))

  fun ip(): String =>
    String.from_cstring(@tuya_get_ip[Pointer[U8]](_h))

  // --- Connection ---

  fun connect(hostname: String): Bool =>
    @tuya_connect[Bool](_h, hostname.cstring())

  fun disconnect() =>
    @tuya_disconnect[None](_h)

  fun is_connected(): Bool =>
    @tuya_is_connected[Bool](_h)

  fun reconnect(): Bool =>
    @tuya_reconnect[Bool](_h)

  // --- Retry ---

  fun ref set_retry_limit(limit: I32) =>
    @tuya_set_retry_limit[None](_h, limit)

  fun ref set_retry_delay(delay_ms: I32) =>
    @tuya_set_retry_delay[None](_h, delay_ms)

  fun retry_limit(): I32 =>
    @tuya_get_retry_limit[I32](_h)

  fun retry_delay(): I32 =>
    @tuya_get_retry_delay[I32](_h)

  // --- Session ---

  fun negotiate_session(key: String): Bool =>
    @tuya_negotiate_session[Bool](_h, key.cstring())

  fun negotiate_session_start(key: String): Bool =>
    @tuya_negotiate_session_start[Bool](_h, key.cstring())

  // --- State queries ---

  fun protocol(): I32 =>
    @tuya_get_protocol[I32](_h)

  fun session_state(): I32 =>
    @tuya_get_session_state[I32](_h)

  fun socket_state(): I32 =>
    @tuya_get_socket_state[I32](_h)

  fun last_error(): I32 =>
    @tuya_get_last_error[I32](_h)

  // --- Async ---

  fun ref set_async_mode(async: Bool) =>
    @tuya_set_async_mode[None](_h, async)

  fun is_socket_readable(): Bool =>
    @tuya_is_socket_readable[Bool](_h)

  fun is_socket_writable(): Bool =>
    @tuya_is_socket_writable[Bool](_h)

  fun ref set_session_ready(): Bool =>
    @tuya_set_session_ready[Bool](_h)

  // --- High-level round-trip (auto-consume C strings) ---

  fun turn_on(switch_dp: I32): String ? =>
    _consume(@tuya_turn_on[Pointer[U8]](_h, switch_dp))

  fun turn_off(switch_dp: I32): String ? =>
    _consume(@tuya_turn_off[Pointer[U8]](_h, switch_dp))

  fun status(): String ? =>
    _consume(@tuya_status[Pointer[U8]](_h))

  fun heartbeat(): String ? =>
    _consume(@tuya_heartbeat[Pointer[U8]](_h))

  fun set_value_bool(dp: I32, value: Bool): String ? =>
    _consume(@tuya_set_value_bool[Pointer[U8]](_h, dp, value))

  fun set_value_int(dp: I32, value: I32): String ? =>
    _consume(@tuya_set_value_int[Pointer[U8]](_h, dp, value))

  fun set_value_float(dp: I32, value: F64): String ? =>
    _consume(@tuya_set_value_float[Pointer[U8]](_h, dp, value))

  fun set_value_string(dp: I32, value: String): String ? =>
    _consume(@tuya_set_value_string[Pointer[U8]](_h, dp, value.cstring()))

  // --- Type-aware dispatcher ---

  fun set_value(dp: I32, value: (Bool | I32 | F64 | String)): String ? =>
    match value
    | let b: Bool   => set_value_bool(dp, b)
    | let i: I32    => set_value_int(dp, i)
    | let f: F64    => set_value_float(dp, f)
    | let s: String => set_value_string(dp, s)
    end

  // --- device22 ---

  fun ref set_device22(null_dps: String) =>
    @tuya_set_device22[None](_h, null_dps.cstring())

  fun is_device22(): Bool =>
    @tuya_is_device22[Bool](_h)

  // --- Private helpers ---

  fun _consume(ptr: Pointer[U8]): String ? =>
    if ptr.is_null() then error end
    let s = String.from_cstring(ptr)
    @tuya_free_string[None](ptr)
    s

  fun _ensure_library() =>
    let env_ptr = @pony_os_getenv[Pointer[U8]]("SEATUYA_LIB".cstring())
    if not env_ptr.is_null() then
      @dlopen[Pointer[None]](env_ptr, 1)  // RTLD_LAZY
    end

// --- Standalone functions ---

primitive Seatuya
  fun version(): String =>
    String.from_cstring(@tuya_version[Pointer[U8]]())
