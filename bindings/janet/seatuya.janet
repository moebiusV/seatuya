# seatuya.janet — Janet FFI bindings for libseatuya
#
# Pure Janet binding using the built-in ffi/ module.
# Janet's ffi/native is similar to newLISP's import — declare function
# signatures once, then call them natively.
#
# Usage:
#   (import seatuya :prefix "")
#   (def dev (seatuya/create device-id "192.168.1.100" local-key "3.4"))
#   (print (seatuya/turn-on dev 1))
#   (seatuya/destroy dev)

(import ffi/native)

# Library path
(def- lib
  (or (os/getenv "SEATUYA_LIB")
      (case (os/which)
        :macos "libseatuya.dylib"
        :windows "seatuya.dll"
        "libseatuya.so")))

# Load the library
(ffi/context lib)

# --- Raw C imports ---
(ffi/defbind "tuya_version" :pointer [])

(ffi/defbind "tuya_create" :pointer [:string :string :string :string])
(ffi/defbind "tuya_alloc" :pointer [:string])
(ffi/defbind "tuya_destroy" :void [:pointer])

(ffi/defbind "tuya_set_credentials" :void [:pointer :string :string])
(ffi/defbind "tuya_get_device_id" :pointer [:pointer])
(ffi/defbind "tuya_get_local_key" :pointer [:pointer])
(ffi/defbind "tuya_get_ip" :pointer [:pointer])

(ffi/defbind "tuya_connect" :bool [:pointer :string])
(ffi/defbind "tuya_disconnect" :void [:pointer])
(ffi/defbind "tuya_is_connected" :bool [:pointer])
(ffi/defbind "tuya_reconnect" :bool [:pointer])

(ffi/defbind "tuya_set_retry_limit" :void [:pointer :int])
(ffi/defbind "tuya_set_retry_delay" :void [:pointer :int])
(ffi/defbind "tuya_get_retry_limit" :int [:pointer])
(ffi/defbind "tuya_get_retry_delay" :int [:pointer])

(ffi/defbind "tuya_negotiate_session" :bool [:pointer :string])
(ffi/defbind "tuya_negotiate_session_start" :bool [:pointer :string])
(ffi/defbind "tuya_negotiate_session_finalize" :bool [:pointer :pointer :int :string])

(ffi/defbind "tuya_get_protocol" :int [:pointer])
(ffi/defbind "tuya_get_session_state" :int [:pointer])
(ffi/defbind "tuya_get_socket_state" :int [:pointer])
(ffi/defbind "tuya_get_last_error" :int [:pointer])

(ffi/defbind "tuya_set_async_mode" :void [:pointer :bool])
(ffi/defbind "tuya_is_socket_readable" :bool [:pointer])
(ffi/defbind "tuya_is_socket_writable" :bool [:pointer])
(ffi/defbind "tuya_set_session_ready" :bool [:pointer])

(ffi/defbind "tuya_build_message" :int [:pointer :pointer :int :string :string])
(ffi/defbind "tuya_decode_message" :pointer [:pointer :pointer :int :string])
(ffi/defbind "tuya_generate_payload" :pointer [:pointer :int :string :string])

(ffi/defbind "tuya_send" :int [:pointer :pointer :int])
(ffi/defbind "tuya_receive" :int [:pointer :pointer :int :int])

(ffi/defbind "tuya_set_value_bool" :pointer [:pointer :int :bool])
(ffi/defbind "tuya_set_value_int" :pointer [:pointer :int :int])
(ffi/defbind "tuya_set_value_string" :pointer [:pointer :int :string])
(ffi/defbind "tuya_set_value_float" :pointer [:pointer :int :double])

(ffi/defbind "tuya_turn_on" :pointer [:pointer :int])
(ffi/defbind "tuya_turn_off" :pointer [:pointer :int])
(ffi/defbind "tuya_status" :pointer [:pointer])
(ffi/defbind "tuya_heartbeat" :pointer [:pointer])

(ffi/defbind "tuya_free_string" :void [:string])

(ffi/defbind "tuya_set_device22" :void [:pointer :string])
(ffi/defbind "tuya_is_device22" :bool [:pointer])

# --- Constants ---
(def CMD_UDP 0)
(def CMD_AP_CONFIG 1)
(def CMD_ACTIVE 2)
(def CMD_BIND 3)
(def CMD_RENAME_GW 4)
(def CMD_RENAME_DEVICE 5)
(def CMD_UNBIND 6)
(def CMD_CONTROL 7)
(def CMD_STATUS 8)
(def CMD_HEART_BEAT 9)
(def CMD_DP_QUERY 10)
(def CMD_QUERY_WIFI 11)
(def CMD_TOKEN_BIND 12)
(def CMD_CONTROL_NEW 13)
(def CMD_ENABLE_WIFI 14)
(def CMD_DP_QUERY_NEW 16)
(def CMD_SCENE_EXECUTE 17)
(def CMD_UPDATEDPS 18)
(def CMD_UDP_NEW 19)
(def CMD_AP_CONFIG_NEW 20)
(def CMD_GET_LOCAL_TIME 28)
(def CMD_WEATHER_OPEN 32)
(def CMD_WEATHER_DATA 33)
(def CMD_STATE_UPLOAD_SYN 34)
(def CMD_STATE_UPLOAD_SYN_RECV 35)
(def CMD_HEART_BEAT_STOP 37)
(def CMD_STREAM_TRANS 38)
(def CMD_GET_WIFI_STATUS 43)
(def CMD_WIFI_CONNECT_TEST 44)
(def CMD_GET_MAC 45)
(def CMD_GET_IR_STATUS 46)
(def CMD_IR_TX_RX_TEST 47)
(def CMD_LAN_GW_ACTIVE 240)
(def CMD_LAN_SUB_DEV_REQUEST 241)
(def CMD_LAN_DELETE_SUB_DEV 242)
(def CMD_LAN_REPORT_SUB_DEV 243)
(def CMD_LAN_SCENE 244)
(def CMD_LAN_PUBLISH_CLOUD_CONFIG 245)
(def CMD_LAN_PUBLISH_APP_CONFIG 246)
(def CMD_LAN_EXPORT_APP_CONFIG 247)
(def CMD_LAN_PUBLISH_SCENE_PANEL 248)
(def CMD_LAN_REMOVE_GW 249)
(def CMD_LAN_CHECK_GW_UPDATE 250)
(def CMD_LAN_GW_UPDATE 251)
(def CMD_LAN_SET_GW_CHANNEL 252)

(def PROTO_V31 0) (def PROTO_V33 1) (def PROTO_V34 2) (def PROTO_V35 3)
(def SESSION_INVALID 0) (def SESSION_STARTING 1) (def SESSION_FINALIZING 2) (def SESSION_ESTABLISHED 3)
(def SOCK_NO_SUCH_HOST 0) (def SOCK_NO_SOCK_AVAIL 1) (def SOCK_FAILED 2) (def SOCK_DISCONNECTED 3) (def SOCK_CONNECTING 4) (def SOCK_CONNECTED 5) (def SOCK_READY 6) (def SOCK_RECEIVING 7)

(def DEFAULT_PORT 6668)
(def BUFSIZE 1024)
(def DEFAULT_RETRY_LIMIT 5)
(def DEFAULT_RETRY_DELAY_MS 100)

# --- Convenience wrappers ---

(defn consume-cstr [ptr]
  "Copy a malloc'd C string to a Janet string, then free the C copy."
  (when (not (zero? ptr))
    (def s (ffi/string ptr))
    (tuya_free_string ptr)
    s))

# Lifecycle
(defn version [] (ffi/string (tuya_version)))

(defn create [device-id address local-key ver]
  (def ptr (tuya_create device-id address local-key ver))
  (if (zero? ptr) nil ptr))

(defn alloc [ver]
  (def ptr (tuya_alloc ver))
  (if (zero? ptr) nil ptr))

(defn destroy [dev] (tuya_destroy dev))

# Credentials
(defn set-credentials [dev device-id local-key]
  (tuya_set_credentials dev device-id local-key))

(defn get-device-id [dev] (ffi/string (tuya_get_device_id dev)))
(defn get-local-key [dev] (ffi/string (tuya_get_local_key dev)))
(defn get-ip [dev] (ffi/string (tuya_get_ip dev)))

# Connection
(defn connect [dev hostname] (tuya_connect dev hostname))
(defn disconnect [dev] (tuya_disconnect dev))
(defn is-connected [dev] (tuya_is_connected dev))
(defn reconnect [dev] (tuya_reconnect dev))

# Retry
(defn set-retry-limit [dev limit] (tuya_set_retry_limit dev limit))
(defn set-retry-delay [dev ms] (tuya_set_retry_delay dev ms))
(defn get-retry-limit [dev] (tuya_get_retry_limit dev))
(defn get-retry-delay [dev] (tuya_get_retry_delay dev))

# Session
(defn negotiate-session [dev key] (tuya_negotiate_session dev key))
(defn negotiate-session-start [dev key] (tuya_negotiate_session_start dev key))
(defn negotiate-session-finalize [dev buf key]
  (tuya_negotiate_session_finalize dev buf (length buf) key))

# State queries
(defn get-protocol [dev] (tuya_get_protocol dev))
(defn get-session-state [dev] (tuya_get_session_state dev))
(defn get-socket-state [dev] (tuya_get_socket_state dev))
(defn get-last-error [dev] (tuya_get_last_error dev))

# Async mode
(defn set-async-mode [dev flag] (tuya_set_async_mode dev flag))
(defn is-socket-readable [dev] (tuya_is_socket_readable dev))
(defn is-socket-writable [dev] (tuya_is_socket_writable dev))
(defn set-session-ready [dev] (tuya_set_session_ready dev))

# Low-level
(defn build-message [dev cmd payload key]
  (def buf (ffi/array :uint8 BUFSIZE))
  (def n (tuya_build_message dev buf cmd payload key))
  (if (> n 0) (ffi/string buf n) nil))

(defn decode-message [dev buf key]
  (consume-cstr (tuya_decode_message dev buf (length buf) key)))

(defn generate-payload [dev cmd device-id datapoints]
  (consume-cstr (tuya_generate_payload dev cmd device-id (or datapoints ""))))

(defn send-frame [dev buf]
  (tuya_send dev buf (length buf)))

(defn receive-frame [dev maxsize minsize]
  (default maxsize BUFSIZE)
  (default minsize 0)
  (def buf (ffi/array :uint8 maxsize))
  (def n (tuya_receive dev buf maxsize minsize))
  (if (> n 0) (ffi/string buf n) nil))

# High-level
(defn set-value [dev dp value]
  (consume-cstr
    (cond
      (= value true)  (tuya_set_value_bool dev dp true)
      (= value false) (tuya_set_value_bool dev dp false)
      (number? value) (if (int? value)
                        (tuya_set_value_int dev dp value)
                        (tuya_set_value_float dev dp value))
      (tuya_set_value_string dev dp (string value)))))

(defn turn-on [dev &opt switch-dp]
  (default switch-dp 1)
  (consume-cstr (tuya_turn_on dev switch-dp)))

(defn turn-off [dev &opt switch-dp]
  (default switch-dp 1)
  (consume-cstr (tuya_turn_off dev switch-dp)))

(defn status [dev] (consume-cstr (tuya_status dev)))
(defn heartbeat [dev] (consume-cstr (tuya_heartbeat dev)))

# device22
(defn set-device22 [dev null-dps-json]
  (tuya_set_device22 dev null-dps-json))

(defn is-device22 [dev] (tuya_is_device22 dev))
