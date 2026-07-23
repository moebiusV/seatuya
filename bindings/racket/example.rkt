#lang racket
;;; example.rkt — demonstrate libseatuya via Racket FFI
;;;
;;; Usage: racket example.rkt

(require "seatuya.rkt")

(define device-id (or (getenv "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(define local-key (or (getenv "TUYA_LOCAL_KEY") "0123456789abcdef"))
(define ip        (or (getenv "TUYA_IP")        "192.168.1.100"))
(define ver       (or (getenv "TUYA_VERSION")    "3.4"))

(printf "seatuya version: ~A~%" (seatuya-version))

(define dev (seatuya-create device-id ip local-key ver))
(unless dev
  (eprintf "ERROR: Could not create device handle~%")
  (exit 1))

(printf "Connected: ~A~%" (seatuya-is-connected dev))
(printf "turn_on: ~A~%" (seatuya-turn-on dev 1))
(printf "status: ~A~%" (seatuya-status dev))
(printf "turn_off: ~A~%" (seatuya-turn-off dev 1))

(seatuya-destroy dev)
(printf "Done.~%")
