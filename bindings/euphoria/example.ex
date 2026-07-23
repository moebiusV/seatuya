-- example.ex — demonstrate libseatuya via Euphoria

include std/os.e
include std/io.e
include seatuya.ex

sequence did = getenv("TUYA_DEVICE_ID")
if atom(did) then did = "0123456789abcdef01234567" end if
sequence key = getenv("TUYA_LOCAL_KEY")
if atom(key) then key = "0123456789abcdef" end if
sequence ip = getenv("TUYA_IP")
if atom(ip) then ip = "192.168.1.100" end if
sequence ver = getenv("TUYA_VERSION")
if atom(ver) then ver = "3.4" end if

printf(1, "seatuya version: %s\n", {seatuya_version()})

atom dev = seatuya_create(did, ip, key, ver)
if dev = NULL then
    puts(2, "ERROR: Could not create device handle\n")
    abort(1)
end if

printf(1, "Connected: %d\n", {seatuya_is_connected(dev)})
printf(1, "turn_on: %s\n", {seatuya_turn_on(dev, 1)})
printf(1, "status: %s\n", {seatuya_status(dev)})
printf(1, "turn_off: %s\n", {seatuya_turn_off(dev, 1)})

seatuya_destroy(dev)
puts(1, "Done.\n")
