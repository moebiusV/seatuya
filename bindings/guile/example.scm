#!/usr/bin/env guile -s
!#
;;; example.scm — demonstrate libseatuya via Guile FFI
;;;
;;; Usage: guile -L . example.scm

(add-to-load-path (dirname (current-filename)))
(use-modules (seatuya))

(define device-id (or (getenv "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(define local-key (or (getenv "TUYA_LOCAL_KEY") "0123456789abcdef"))
(define ip        (or (getenv "TUYA_IP")        "192.168.1.100"))
(define ver       (or (getenv "TUYA_VERSION")    "3.4"))

(format #t "seatuya version: ~A~%" (seatuya-version))

(define dev (seatuya-create device-id ip local-key ver))
(unless dev
  (format (current-error-port) "ERROR: Could not create device handle~%")
  (exit 1))

(format #t "Connected: ~A~%" (seatuya-is-connected dev))
(format #t "turn_on: ~A~%" (seatuya-turn-on dev 1))
(format #t "status: ~A~%" (seatuya-status dev))
(format #t "turn_off: ~A~%" (seatuya-turn-off dev 1))

(seatuya-destroy dev)
(format #t "Done.~%")
