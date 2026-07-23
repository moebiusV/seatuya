#!/usr/bin/env janet
# example.janet — demonstrate libseatuya via Janet FFI
#
# Usage: janet example.janet
# Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP env vars before running.

(import ./seatuya :prefix "")

(def device-id (or (os/getenv "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(def local-key (or (os/getenv "TUYA_LOCAL_KEY") "0123456789abcdef"))
(def ip        (or (os/getenv "TUYA_IP")        "192.168.1.100"))
(def ver       (or (os/getenv "TUYA_VERSION")    "3.4"))

(print "seatuya version: " (version))

(def dev (create device-id ip local-key ver))
(if (nil? dev)
  (do
    (eprint "ERROR: Could not create device handle (check IP and credentials)")
    (os/exit 1)))

(printf "Connected: %q" (is-connected dev))

(print "turn_on: " (turn-on dev 1))
(print "status: " (status dev))
(print "turn_off: " (turn-off dev 1))

(destroy dev)
(print "Done.")
