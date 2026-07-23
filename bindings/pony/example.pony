// example.pony -- Demonstrate libseatuya via Pony FFI
//
// Build and run:
//   ponyc --library seatuya --librarypath /usr/local/lib
//   ./example
//
// Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP, TUYA_VERSION env vars.

use @pony_os_getenv[Pointer[U8]](name: Pointer[U8] tag)

actor Main
  new create(env: Env) =>
    let deviceId = _env_or("TUYA_DEVICE_ID", "0123456789abcdef01234567")
    let localKey = _env_or("TUYA_LOCAL_KEY", "0123456789abcdef")
    let ip       = _env_or("TUYA_IP",        "192.168.1.100")
    let ver      = _env_or("TUYA_VERSION",   "3.4")

    env.out.print("seatuya version: " + Seatuya.version())

    try
      let dev = Device.create(deviceId, ip, localKey, ver)?
      env.out.print("Connected: " + dev.is_connected().string())
      env.out.print("turn_on: "  + dev.turn_on(1)?)
      env.out.print("status: "   + dev.status()?)
      env.out.print("turn_off: " + dev.turn_off(1)?)
      env.out.print("Done.")
    else
      env.err.print("ERROR: Could not create device handle")
    end

  fun _env_or(key: String, fallback: String): String =>
    let ptr = @pony_os_getenv[Pointer[U8]](key.cstring())
    if ptr.is_null() then fallback else String.from_cstring(ptr) end
