Red [
    file:    %example.red
    purpose: "Demonstrate libseatuya via Red FFI"
]

; example.red -- Demonstrate libseatuya via Red FFI
;
; Usage:
;   red example.red
;
; Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP, TUYA_VERSION env vars.

#include %seatuya.red

device-id: any [get-env "TUYA_DEVICE_ID" "0123456789abcdef01234567"]
local-key: any [get-env "TUYA_LOCAL_KEY" "0123456789abcdef"]
ip:        any [get-env "TUYA_IP"        "192.168.1.100"]
ver:       any [get-env "TUYA_VERSION"   "3.4"]

; Initialize library
seatuya/init

print ["seatuya version:" seatuya/version]

dev: seatuya/create device-id ip local-key ver
if dev = null [
    print "ERROR: Could not create device handle"
    quit -1
]

print ["Connected:" seatuya/is-connected dev]
print ["turn_on:"  seatuya/turn-on dev 1]
print ["status:"   seatuya/status dev]
print ["turn_off:" seatuya/turn-off dev 1]

seatuya/destroy dev
print "Done."
