#!/usr/bin/env gosh
(use gauche.uvector)
(load "./seatuya.scm")

(define did (or (sys-getenv "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(define key (or (sys-getenv "TUYA_LOCAL_KEY") "0123456789abcdef"))
(define ip  (or (sys-getenv "TUYA_IP")        "192.168.1.100"))
(define ver (or (sys-getenv "TUYA_VERSION")    "3.4"))

(print "seatuya version: " (seatuya-version))
(define dev (seatuya-create did ip key ver))
(unless dev (print "ERROR: Could not create device handle") (exit 1))
(print "Connected: " (seatuya-is-connected dev))
(print "turn_on: " (seatuya-turn-on dev 1))
(print "status: " (seatuya-status dev))
(print "turn_off: " (seatuya-turn-off dev 1))
(seatuya-destroy dev)
(print "Done.")
