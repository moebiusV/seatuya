;; seatuya.clj -- Clojure JNA bindings for libseatuya
;;
;; Usage: (require 'seatuya)
;;
;; Set SEATUYA_LIB environment variable to override the library path.
;; Requires JNA (com.sun.jna) on the classpath.
;;
;; Run: java -cp jna.jar:clojure.jar clojure.main -i seatuya.clj
;; Or from Leiningen:
;;   :dependencies [[net.java.dev.jna/jna "5.14.0"]]

(ns seatuya
  (:import (com.sun.jna NativeLibrary Function Pointer)
           (java.util Map HashMap)))

;; ==================================================================
;;  Library loading with SEATUYA_LIB env var support
;; ==================================================================

(defonce ^:private native-lib
  (delay
    (let [path (or (System/getenv "SEATUYA_LIB")
                   (let [os (-> (System/getProperty "os.name") (.toLowerCase))]
                     (cond (.contains os "win")  "seatuya.dll"
                           (.contains os "mac")  "libseatuya.dylib"
                           :else                 "libseatuya.so")))]
      (try
        (NativeLibrary/getInstance path)
        (catch Exception e
          (throw (RuntimeException.
                   (str "Failed to load libseatuya from " path ": " (.getMessage e)))))))))

(defn- get-fn [name]
  (.getFunction @native-lib name))

(defn- invoke [ret-type name & args]
  (.invoke (get-fn name) ret-type (into-array Object args)))

;; ==================================================================
;;  Internal helpers
;; ==================================================================

(defn- ptr->bool [x]
  "Convert a JNA boolean (or nil) to Clojure boolean."
  (if x true false))

(defn- consume-ptr
  "Convert a Pointer (malloc'd C string) to Clojure string and free it."
  [ptr]
  (when (and ptr (not (.equals ptr Pointer/NULL)))
    (let [s (.getString ptr 0 "UTF-8")]
      (.invoke (get-fn "tuya_free_string") Void (into-array Object [ptr]))
      s)))

;; ==================================================================
;;  Public API
;; ==================================================================

;; -- Version --------------------------------------------------------

(defn tuya-version []
  (invoke String "tuya_version"))

;; -- Lifecycle ------------------------------------------------------

(defn tuya-create
  "Create a device handle, connect, and negotiate session.
  Returns a Pointer to the device, or nil on failure."
  [device-id address local-key version]
  (let [ptr (invoke Pointer "tuya_create" device-id address local-key version)]
    (when (and ptr (not (.equals ptr Pointer/NULL))) ptr)))

(defn tuya-alloc
  "Allocate a device handle without connecting."
  [version]
  (let [ptr (invoke Pointer "tuya_alloc" version)]
    (when (and ptr (not (.equals ptr Pointer/NULL))) ptr)))

(defn tuya-destroy [dev]
  (invoke Void "tuya_destroy" dev))

;; -- Credentials ----------------------------------------------------

(defn tuya-set-credentials [dev device-id local-key]
  (invoke Void "tuya_set_credentials" dev device-id local-key))

(defn tuya-get-device-id [dev]
  (invoke String "tuya_get_device_id" dev))

(defn tuya-get-local-key [dev]
  (invoke String "tuya_get_local_key" dev))

(defn tuya-get-ip [dev]
  (invoke String "tuya_get_ip" dev))

;; -- Connection -----------------------------------------------------

(defn tuya-connect [dev hostname]
  (ptr->bool (invoke Boolean "tuya_connect" dev hostname)))

(defn tuya-disconnect [dev]
  (invoke Void "tuya_disconnect" dev))

(defn tuya-is-connected [dev]
  (ptr->bool (invoke Boolean "tuya_is_connected" dev)))

(defn tuya-reconnect [dev]
  (ptr->bool (invoke Boolean "tuya_reconnect" dev)))

;; -- Retry ----------------------------------------------------------

(defn tuya-set-retry-limit [dev limit]
  (invoke Void "tuya_set_retry_limit" dev (int limit)))

(defn tuya-set-retry-delay [dev delay-ms]
  (invoke Void "tuya_set_retry_delay" dev (int delay-ms)))

(defn tuya-get-retry-limit [dev]
  (invoke Integer "tuya_get_retry_limit" dev))

(defn tuya-get-retry-delay [dev]
  (invoke Integer "tuya_get_retry_delay" dev))

;; -- Session negotiation --------------------------------------------

(defn tuya-negotiate-session [dev local-key]
  (ptr->bool (invoke Boolean "tuya_negotiate_session" dev local-key)))

(defn tuya-negotiate-session-start [dev local-key]
  (ptr->bool (invoke Boolean "tuya_negotiate_session_start" dev local-key)))

(defn tuya-negotiate-session-finalize [dev buf size local-key]
  (ptr->bool (invoke Boolean "tuya_negotiate_session_finalize" dev buf (int size) local-key)))

;; -- State queries --------------------------------------------------

(defn tuya-get-protocol [dev]
  (invoke Integer "tuya_get_protocol" dev))

(defn tuya-get-session-state [dev]
  (invoke Integer "tuya_get_session_state" dev))

(defn tuya-get-socket-state [dev]
  (invoke Integer "tuya_get_socket_state" dev))

(defn tuya-get-last-error [dev]
  (invoke Integer "tuya_get_last_error" dev))

;; -- Async mode -----------------------------------------------------

(defn tuya-set-async-mode [dev async]
  (invoke Void "tuya_set_async_mode" dev (boolean async)))

(defn tuya-is-socket-readable [dev]
  (ptr->bool (invoke Boolean "tuya_is_socket_readable" dev)))

(defn tuya-is-socket-writable [dev]
  (ptr->bool (invoke Boolean "tuya_is_socket_writable" dev)))

(defn tuya-set-session-ready [dev]
  (ptr->bool (invoke Boolean "tuya_set_session_ready" dev)))

;; -- Message building/decoding --------------------------------------

(defn tuya-build-message [dev buf cmd payload key]
  (invoke Integer "tuya_build_message" dev buf (int cmd) payload key))

(defn tuya-decode-message [dev buf size key]
  (invoke String "tuya_decode_message" dev buf (int size) key))

(defn tuya-generate-payload [dev cmd device-id datapoints]
  (invoke String "tuya_generate_payload" dev (int cmd) device-id datapoints))

;; -- Raw send/receive ------------------------------------------------

(defn tuya-send [dev buf size]
  (invoke Integer "tuya_send" dev buf (int size)))

(defn tuya-receive [dev buf maxsize minsize]
  (invoke Integer "tuya_receive" dev buf (int maxsize) (int minsize)))

;; -- device22 mode ---------------------------------------------------

(defn tuya-set-device22 [dev null-dps-json]
  (invoke Void "tuya_set_device22" dev null-dps-json))

(defn tuya-is-device22 [dev]
  (ptr->bool (invoke Boolean "tuya_is_device22" dev)))

;; -- High-level round-trip (auto-free strings) -----------------------

(defn tuya-set-value-bool [dev dp value]
  (consume-ptr (invoke Pointer "tuya_set_value_bool" dev (int dp) (boolean value))))

(defn tuya-set-value-int [dev dp value]
  (consume-ptr (invoke Pointer "tuya_set_value_int" dev (int dp) (int value))))

(defn tuya-set-value-string [dev dp value]
  (consume-ptr (invoke Pointer "tuya_set_value_string" dev (int dp) value)))

(defn tuya-set-value-float [dev dp value]
  (consume-ptr (invoke Pointer "tuya_set_value_float" dev (int dp) (double value))))

(defn tuya-turn-on
  ([dev] (tuya-turn-on dev 1))
  ([dev switch-dp]
   (consume-ptr (invoke Pointer "tuya_turn_on" dev (int switch-dp)))))

(defn tuya-turn-off
  ([dev] (tuya-turn-off dev 1))
  ([dev switch-dp]
   (consume-ptr (invoke Pointer "tuya_turn_off" dev (int switch-dp)))))

(defn tuya-status [dev]
  (consume-ptr (invoke Pointer "tuya_status" dev)))

(defn tuya-heartbeat [dev]
  (consume-ptr (invoke Pointer "tuya_heartbeat" dev)))

;; -- Type-aware set_value dispatcher ----------------------------------
;;
;;   (tuya-set-value dev dp :bool   true)
;;   (tuya-set-value dev dp :int    42)
;;   (tuya-set-value dev dp :string "hello")
;;   (tuya-set-value dev dp :float  3.14)
;;

(defn tuya-set-value
  "Set a device value by type keyword."
  [dev dp typ value]
  (case typ
    :bool   (tuya-set-value-bool   dev dp value)
    :int    (tuya-set-value-int    dev dp value)
    :string (tuya-set-value-string dev dp value)
    :float  (tuya-set-value-float  dev dp value)
    (throw (IllegalArgumentException. (str "Unknown type: " typ)))))

;; ==================================================================
;;  Constants
;; ==================================================================

;; Protocol versions
(def ^:const PROTO-V31 0)
(def ^:const PROTO-V33 1)
(def ^:const PROTO-V34 2)
(def ^:const PROTO-V35 3)

;; Session states
(def ^:const SESSION-INVALID      0)
(def ^:const SESSION-STARTING     1)
(def ^:const SESSION-FINALIZING   2)
(def ^:const SESSION-ESTABLISHED  3)

;; Socket states
(def ^:const SOCK-NO-SUCH-HOST   0)
(def ^:const SOCK-NO-SOCK-AVAIL  1)
(def ^:const SOCK-FAILED         2)
(def ^:const SOCK-DISCONNECTED   3)
(def ^:const SOCK-CONNECTING     4)
(def ^:const SOCK-CONNECTED      5)
(def ^:const SOCK-READY          6)
(def ^:const SOCK-RECEIVING      7)

;; Misc
(def ^:const DEFAULT-PORT           6668)
(def ^:const RECOMMENDED-BUFSIZE    1024)
(def ^:const DEFAULT-RETRY-LIMIT    5)
(def ^:const DEFAULT-RETRY-DELAY-MS 100)

;; Tuya command types (all 45)
(def ^:const CMD-UDP                     0)
(def ^:const CMD-AP-CONFIG               1)
(def ^:const CMD-ACTIVE                  2)
(def ^:const CMD-BIND                    3)
(def ^:const CMD-RENAME-GW               4)
(def ^:const CMD-RENAME-DEVICE           5)
(def ^:const CMD-UNBIND                  6)
(def ^:const CMD-CONTROL                 7)
(def ^:const CMD-STATUS                  8)
(def ^:const CMD-HEART-BEAT              9)
(def ^:const CMD-DP-QUERY               10)
(def ^:const CMD-QUERY-WIFI             11)
(def ^:const CMD-TOKEN-BIND             12)
(def ^:const CMD-CONTROL-NEW            13)
(def ^:const CMD-ENABLE-WIFI            14)
(def ^:const CMD-DP-QUERY-NEW           16)
(def ^:const CMD-SCENE-EXECUTE          17)
(def ^:const CMD-UPDATEDPS              18)
(def ^:const CMD-UDP-NEW                19)
(def ^:const CMD-AP-CONFIG-NEW          20)
(def ^:const CMD-GET-LOCAL-TIME         28)
(def ^:const CMD-WEATHER-OPEN           32)
(def ^:const CMD-WEATHER-DATA           33)
(def ^:const CMD-STATE-UPLOAD-SYN       34)
(def ^:const CMD-STATE-UPLOAD-SYN-RECV  35)
(def ^:const CMD-HEART-BEAT-STOP        37)
(def ^:const CMD-STREAM-TRANS           38)
(def ^:const CMD-GET-WIFI-STATUS        43)
(def ^:const CMD-WIFI-CONNECT-TEST      44)
(def ^:const CMD-GET-MAC                45)
(def ^:const CMD-GET-IR-STATUS          46)
(def ^:const CMD-IR-TX-RX-TEST          47)
(def ^:const CMD-LAN-GW-ACTIVE          240)
(def ^:const CMD-LAN-SUB-DEV-REQUEST    241)
(def ^:const CMD-LAN-DELETE-SUB-DEV     242)
(def ^:const CMD-LAN-REPORT-SUB-DEV     243)
(def ^:const CMD-LAN-SCENE              244)
(def ^:const CMD-LAN-PUBLISH-CLOUD-CONFIG  245)
(def ^:const CMD-LAN-PUBLISH-APP-CONFIG     246)
(def ^:const CMD-LAN-EXPORT-APP-CONFIG      247)
(def ^:const CMD-LAN-PUBLISH-SCENE-PANEL    248)
(def ^:const CMD-LAN-REMOVE-GW          249)
(def ^:const CMD-LAN-CHECK-GW-UPDATE    250)
(def ^:const CMD-LAN-GW-UPDATE          251)
(def ^:const CMD-LAN-SET-GW-CHANNEL     252)
