#!/usr/bin/env hy
;; example.hy — demonstrate libseatuya via Hy Lisp

(import os sys seatuya)

(setv device-id (or (os.environ.get "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(setv local-key (or (os.environ.get "TUYA_LOCAL_KEY") "0123456789abcdef"))
(setv ip        (or (os.environ.get "TUYA_IP")        "192.168.1.100"))
(setv ver       (or (os.environ.get "TUYA_VERSION")    "3.4"))

(print f"seatuya version: {(seatuya.version)}")

(setv dev (seatuya.create device-id ip local-key ver))
(when (not dev)
  (print "ERROR: Could not create device handle" :file sys.stderr)
  (sys.exit 1))

(print f"Connected: {(seatuya.is-connected dev)}")
(print f"turn_on: {(seatuya.turn-on dev 1)}")
(print f"status: {(seatuya.status dev)}")
(print f"turn_off: {(seatuya.turn-off dev 1)}")

(seatuya.destroy dev)
(print "Done.")
