;;; example.ss -- demonstrate seatuya Gerbil bindings
;;;
;;; Usage: gxi -e '(load "seatuya")' -e '(load "example")'
;;; Environment: DEVICE_ID, LOCAL_KEY, IP, VERSION
;;;
;;; Requires compiling seatuya.ss first:
;;;   gxc seatuya.ss
;;;   gxi -e '(load "example")'

(import :gerbil/core :gerbil/gambit/os)
(import :seatuya/seatuya)

;; Initialize library (dlopen)
(seatuya-init!)

;; Read config from environment
(def device-id (or (getenv "DEVICE_ID" #f) "0123456789abcdef"))
(def local-key (or (getenv "LOCAL_KEY" #f) "0123456789abcdef"))
(def ip        (or (getenv "IP" #f)        "192.168.1.100"))
(def version   (or (getenv "VERSION" #f)   "3.3"))

(displayln "seatuya version: " (tuya-version))
(displayln "Device ID: " device-id)
(displayln "IP: " ip)
(displayln "Protocol: " version)
(displayln "")

;; Create device handle
(def dev (tuya-create device-id ip local-key version))
(unless dev
  (error "Failed to create device"))

(displayln "Connected! Getting status...")

(let (status (tuya-status* dev))
  (if status
    (displayln "Status: " status)
    (displayln "No status response")))

(displayln "Turning on DP 1...")
(let (result (tuya-turn-on* dev 1))
  (if result
    (displayln "Turn-on response: " result)
    (displayln "Turn-on: no response")))

(let (status (tuya-status* dev))
  (if status
    (displayln "Status after on: " status)
    (displayln "No status response")))

(displayln "Turning off DP 1...")
(let (result (tuya-turn-off* dev 1))
  (if result
    (displayln "Turn-off response: " result)
    (displayln "Turn-off: no response")))

(displayln "")
(displayln "Using type-aware dispatcher:")
(let (result (tuya-set-value dev 1 'bool #t))
  (if result
    (displayln "set-value response: " result)
    (displayln "set-value: no response")))

(tuya-destroy dev)
(displayln "Done.")
