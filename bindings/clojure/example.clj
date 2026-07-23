;; example.clj -- demonstrate seatuya Clojure bindings
;;
;; Usage:
;;   java -cp jna.jar:clojure.jar clojure.main -i example.clj
;;
;; Environment variables (with defaults):
;;   DEVICE_ID  (default "0123456789abcdef")
;;   LOCAL_KEY  (default "0123456789abcdef")
;;   IP         (default "192.168.1.100")
;;   VERSION    (default "3.3")

(require 'seatuya)

;; Read config from environment
(def device-id (or (System/getenv "DEVICE_ID") "0123456789abcdef"))
(def local-key (or (System/getenv "LOCAL_KEY") "0123456789abcdef"))
(def ip        (or (System/getenv "IP")        "192.168.1.100"))
(def version   (or (System/getenv "VERSION")   "3.3"))

(println (str "seatuya version: " (tuya-version)))
(println (str "Device ID: " device-id))
(println (str "IP: " ip))
(println (str "Protocol: " version))
(println)

;; Create device handle
(def dev (tuya-create device-id ip local-key version))
(if (nil? dev)
  (throw (RuntimeException. "Failed to create device"))
  (println "Created device."))

;; Get status
(println "Getting status...")
(let [status (tuya-status dev)]
  (if status
    (println (str "Status: " status))
    (println "No status response")))

;; Turn on DP 1
(println "Turning on DP 1...")
(let [result (tuya-turn-on dev 1)]
  (if result
    (println (str "Turn-on response: " result))
    (println "Turn-on: no response")))

;; Status after
(let [status (tuya-status dev)]
  (if status
    (println (str "Status after on: " status))
    (println "No status response")))

;; Turn off DP 1
(println "Turning off DP 1...")
(let [result (tuya-turn-off dev 1)]
  (if result
    (println (str "Turn-off response: " result))
    (println "Turn-off: no response")))

;; Demonstrate type-aware dispatcher
(println)
(println "Using type-aware dispatcher:")
(let [result (tuya-set-value dev 1 :bool true)]
  (if result
    (println (str "set-value response: " result))
    (println "set-value: no response")))

;; Cleanup
(tuya-destroy dev)
(println "Done.")
