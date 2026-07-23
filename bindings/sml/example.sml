val did = case OS.Process.getEnv "TUYA_DEVICE_ID" of SOME s => s | NONE => "0123456789abcdef01234567"
val key = case OS.Process.getEnv "TUYA_LOCAL_KEY" of SOME s => s | NONE => "0123456789abcdef"
val ip  = case OS.Process.getEnv "TUYA_IP"        of SOME s => s | NONE => "192.168.1.100"
val ver = case OS.Process.getEnv "TUYA_VERSION"    of SOME s => s | NONE => "3.4"

val _ = print ("seatuya version: " ^ Seatuya.version () ^ "\n")
val dev = Seatuya.create (did, ip, key, ver)
val _ = if dev = 0w0 then (print "ERROR: Could not create device handle\n"; OS.Process.exit OS.Process.failure) else ()
val _ = print ("Connected: " ^ Bool.toString (Seatuya.isConnected dev) ^ "\n")
val _ = print ("turn_on: " ^ Seatuya.turnOn (dev, 1) ^ "\n")
val _ = print ("status: " ^ Seatuya.status dev ^ "\n")
val _ = print ("turn_off: " ^ Seatuya.turnOff (dev, 1) ^ "\n")
val _ = Seatuya.destroy dev
val _ = print "Done.\n"
