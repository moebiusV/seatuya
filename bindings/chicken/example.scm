;;; example.scm -- demonstrate seatuya Chicken bindings
;;;
;;; Usage: csi -s example.scm
;;; Requires: seatuya.so in the library path, or SEATUYA_LIB env var set.
;;;
;;; Environment variables (with defaults):
;;;   DEVICE_ID  (default "0123456789abcdef")
;;;   LOCAL_KEY  (default "0123456789abcdef")
;;;   IP         (default "192.168.1.100")
;;;   VERSION    (default "3.3")

(import seatuya)

;; Initialize library (dlopen libseatuya.so)
(seatuya-initialize!)

;; Read config from environment
(define device-id (or (get-environment-variable "DEVICE_ID")
                      "0123456789abcdef"))
(define local-key (or (get-environment-variable "LOCAL_KEY")
                      "0123456789abcdef"))
(define ip        (or (get-environment-variable "IP")
                      "192.168.1.100"))
(define version   (or (get-environment-variable "VERSION")
                      "3.3"))

(display (string-append "seatuya version: " (tuya-version) "\n"))
(display (string-append "Device ID: " device-id "\n"))
(display (string-append "IP: " ip "\n"))
(display (string-append "Protocol: " version "\n"))
(newline)

;; Create device handle
(define dev (tuya-create device-id ip local-key version))
(unless dev
  (error "Failed to create device -- check IP, credentials, and protocol version"))

(display "Connected! Getting status...\n")

;; Get status (auto-freed response)
(let ((status (tuya-status dev)))
  (if status
      (begin (display "Status: ") (display status) (newline))
      (display "No status response\n")))

;; Turn on DP 1
(display "Turning on DP 1...\n")
(let ((result (tuya-turn-on dev 1)))
  (if result
      (begin (display "Turn-on response: ") (display result) (newline))
      (display "Turn-on: no response\n")))

;; Print status again
(let ((status (tuya-status dev)))
  (if status
      (begin (display "Status after on: ") (display status) (newline))
      (display "No status response\n")))

;; Turn off DP 1
(display "Turning off DP 1...\n")
(let ((result (tuya-turn-off dev 1)))
  (if result
      (begin (display "Turn-off response: ") (display result) (newline))
      (display "Turn-off: no response\n")))

;; Demonstrate type-aware dispatcher
(display "\nUsing type-aware dispatcher:\n")
(let ((result (tuya-set-value dev 1 'bool #t)))
  (if result
      (begin (display "set-value response: ") (display result) (newline))
      (display "set-value: no response\n")))

;; Cleanup
(tuya-destroy dev)
(display "Done.\n")
