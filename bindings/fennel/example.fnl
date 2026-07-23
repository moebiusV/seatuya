;; example.fnl -- demonstrate libseatuya via LuaJIT FFI
;;
;; Usage:
;;   fennel --compile example.fnl > example.lua && luajit example.lua
;;   or: fennel example.fnl
;;
;; Environment variables (with fallback defaults):
;;   TUYA_DEVICE_ID  (default: 0123456789abcdef01234567)
;;   TUYA_LOCAL_KEY  (default: 0123456789abcdef)
;;   TUYA_IP         (default: 192.168.1.100)
;;   TUYA_VERSION    (default: 3.4)

(local seatuya (require :seatuya))

(local device-id (or (os.getenv "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(local local-key (or (os.getenv "TUYA_LOCAL_KEY") "0123456789abcdef"))
(local ip        (or (os.getenv "TUYA_IP")        "192.168.1.100"))
(local ver       (or (os.getenv "TUYA_VERSION")   "3.4"))

(print (.. "seatuya version: " (seatuya.version)))

(local dev (seatuya.create device-id ip local-key ver))

(when (= dev nil)
  (io.stderr:write "ERROR: Could not create device handle (check IP and credentials)\n")
  (os.exit 1))

(print (.. "Connected: " (tostring (seatuya.is-connected dev))))

(print (.. "turn_on: " (seatuya.turn-on dev 1)))
(print (.. "status: " (seatuya.status dev)))
(print (.. "turn_off: " (seatuya.turn-off dev 1)))

(seatuya.destroy dev)
(print "Done.")
