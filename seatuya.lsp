; seatuya.lsp -- newLISP module for the seatuya Tuya device library
;
; Usage:
;   (load "seatuya.lsp")
;   (setq dev (tuya:create "3.3"))
;   (tuya:set-credentials dev "device-id" "local-key")
;   (tuya:connect dev "192.168.1.50")
;   (tuya:set-value dev 1 true)
;   (tuya:destroy dev)

(context 'tuya)

;; ---- library path ----

(constant 'LIB (or (env "SEATUYA_LIB")
                   (if (= ostype "OSX") "libseatuya.dylib"
                       (= ostype "Windows") "seatuya.dll"
                       "libseatuya.so")))

;; ---- raw imports ----

(import LIB "tuya_version")
(import LIB "tuya_create")
(import LIB "tuya_alloc")
(import LIB "tuya_destroy")
(import LIB "tuya_set_credentials")
(import LIB "tuya_get_device_id")
(import LIB "tuya_get_local_key")
(import LIB "tuya_get_ip")
(import LIB "tuya_connect")
(import LIB "tuya_disconnect")
(import LIB "tuya_is_connected")
(import LIB "tuya_reconnect")
(import LIB "tuya_negotiate_session")
(import LIB "tuya_negotiate_session_start")
(import LIB "tuya_negotiate_session_finalize")
(import LIB "tuya_get_protocol")
(import LIB "tuya_get_session_state")
(import LIB "tuya_get_socket_state")
(import LIB "tuya_get_last_error")
(import LIB "tuya_set_async_mode")
(import LIB "tuya_is_socket_readable")
(import LIB "tuya_is_socket_writable")
(import LIB "tuya_set_session_ready")
(import LIB "tuya_build_message")
(import LIB "tuya_decode_message")
(import LIB "tuya_generate_payload")
(import LIB "tuya_send")
(import LIB "tuya_receive")
(import LIB "tuya_set_value_bool")
(import LIB "tuya_set_value_int")
(import LIB "tuya_set_value_string")
(import LIB "tuya_set_value_float")
(import LIB "tuya_turn_on")
(import LIB "tuya_turn_off")
(import LIB "tuya_status")
(import LIB "tuya_heartbeat")
(import LIB "tuya_free_string")

;; ---- constants: command types ----

(constant 'CMD_UDP                       0)
(constant 'CMD_AP_CONFIG                 1)
(constant 'CMD_ACTIVE                    2)
(constant 'CMD_BIND                      3)
(constant 'CMD_RENAME_GW                 4)
(constant 'CMD_RENAME_DEVICE             5)
(constant 'CMD_UNBIND                    6)
(constant 'CMD_CONTROL                   7)
(constant 'CMD_STATUS                    8)
(constant 'CMD_HEART_BEAT                9)
(constant 'CMD_DP_QUERY                  10)
(constant 'CMD_QUERY_WIFI                11)
(constant 'CMD_TOKEN_BIND                12)
(constant 'CMD_CONTROL_NEW               13)
(constant 'CMD_ENABLE_WIFI               14)
(constant 'CMD_DP_QUERY_NEW              16)
(constant 'CMD_SCENE_EXECUTE             17)
(constant 'CMD_UPDATEDPS                 18)
(constant 'CMD_UDP_NEW                   19)
(constant 'CMD_AP_CONFIG_NEW             20)
(constant 'CMD_GET_LOCAL_TIME            28)
(constant 'CMD_WEATHER_OPEN              32)
(constant 'CMD_WEATHER_DATA              33)
(constant 'CMD_STATE_UPLOAD_SYN          34)
(constant 'CMD_STATE_UPLOAD_SYN_RECV     35)
(constant 'CMD_HEART_BEAT_STOP           37)
(constant 'CMD_STREAM_TRANS              38)
(constant 'CMD_GET_WIFI_STATUS           43)
(constant 'CMD_WIFI_CONNECT_TEST         44)
(constant 'CMD_GET_MAC                   45)
(constant 'CMD_GET_IR_STATUS             46)
(constant 'CMD_IR_TX_RX_TEST             47)
(constant 'CMD_LAN_GW_ACTIVE            240)
(constant 'CMD_LAN_SUB_DEV_REQUEST      241)
(constant 'CMD_LAN_DELETE_SUB_DEV        242)
(constant 'CMD_LAN_REPORT_SUB_DEV       243)
(constant 'CMD_LAN_SCENE                 244)
(constant 'CMD_LAN_PUBLISH_CLOUD_CONFIG  245)
(constant 'CMD_LAN_PUBLISH_APP_CONFIG    246)
(constant 'CMD_LAN_EXPORT_APP_CONFIG     247)
(constant 'CMD_LAN_PUBLISH_SCENE_PANEL   248)
(constant 'CMD_LAN_REMOVE_GW             249)
(constant 'CMD_LAN_CHECK_GW_UPDATE       250)
(constant 'CMD_LAN_GW_UPDATE             251)
(constant 'CMD_LAN_SET_GW_CHANNEL        252)

;; ---- constants: protocol versions ----

(constant 'PROTO_V31  0)
(constant 'PROTO_V33  1)
(constant 'PROTO_V34  2)
(constant 'PROTO_V35  3)

;; ---- constants: session state ----

(constant 'SESSION_INVALID      0)
(constant 'SESSION_STARTING     1)
(constant 'SESSION_FINALIZING   2)
(constant 'SESSION_ESTABLISHED  3)

;; ---- constants: socket state ----

(constant 'SOCK_NO_SUCH_HOST  0)
(constant 'SOCK_NO_SOCK_AVAIL 1)
(constant 'SOCK_FAILED        2)
(constant 'SOCK_DISCONNECTED  3)
(constant 'SOCK_CONNECTING    4)
(constant 'SOCK_CONNECTED     5)
(constant 'SOCK_READY         6)
(constant 'SOCK_RECEIVING     7)

;; ---- constants: misc ----

(constant 'DEFAULT_PORT   6668)
(constant 'BUFSIZE        1024)

;; ---- helper: convert C bool (int) to newLISP true/nil ----

(define (bool? n) (if (!= n 0) true nil))

;; ---- helper: extract malloc'd C string, free original ----

(define (consume-cstr ptr)
  (if (!= ptr 0)
    (let (str (get-string ptr))
      (tuya_free_string ptr)
      str)
    nil))

;; ---- wrapper functions ----

(define (version)
  (get-string (tuya_version)))

(define (create device-id address local-key ver)
  "Create handle, store credentials, connect, and negotiate session.
   Returns handle or nil on failure."
  (let (ptr (tuya_create device-id address local-key ver))
    (if (!= ptr 0) ptr nil)))

(define (alloc ver)
  "Allocate handle without connecting (for incremental setup)."
  (let (ptr (tuya_alloc ver))
    (if (!= ptr 0) ptr nil)))

(define (destroy dev)
  (tuya_destroy dev))

(define (set-credentials dev device-id local-key)
  (tuya_set_credentials dev device-id local-key))

(define (get-device-id dev)
  (let (ptr (tuya_get_device_id dev))
    (if (!= ptr 0) (get-string ptr) nil)))

(define (get-local-key dev)
  (let (ptr (tuya_get_local_key dev))
    (if (!= ptr 0) (get-string ptr) nil)))

(define (get-ip dev)
  (let (ptr (tuya_get_ip dev))
    (if (!= ptr 0) (get-string ptr) nil)))

(define (connect dev hostname)
  (bool? (tuya_connect dev hostname)))

(define (disconnect dev)
  (tuya_disconnect dev))

(define (is-connected dev)
  (bool? (tuya_is_connected dev)))

(define (reconnect dev)
  (bool? (tuya_reconnect dev)))

(define (negotiate-session dev local-key)
  (bool? (tuya_negotiate_session dev local-key)))

(define (negotiate-session-start dev local-key)
  (bool? (tuya_negotiate_session_start dev local-key)))

(define (negotiate-session-finalize dev buf local-key)
  (bool? (tuya_negotiate_session_finalize dev buf (length buf) local-key)))

(define (get-protocol dev)
  (tuya_get_protocol dev))

(define (get-session-state dev)
  (tuya_get_session_state dev))

(define (get-socket-state dev)
  (tuya_get_socket_state dev))

(define (get-last-error dev)
  (tuya_get_last_error dev))

(define (set-async-mode dev flag)
  (tuya_set_async_mode dev (if flag 1 0)))

(define (is-socket-readable dev)
  (bool? (tuya_is_socket_readable dev)))

(define (is-socket-writable dev)
  (bool? (tuya_is_socket_writable dev)))

(define (set-session-ready dev)
  (bool? (tuya_set_session_ready dev)))

;; ---- low-level message functions (still available for advanced use) ----

(define (build-message dev cmd payload key)
  (let (buf (dup "\000" BUFSIZE)
        n   (tuya_build_message dev buf cmd payload key))
    (if (> n 0) (slice buf 0 n) nil)))

(define (decode-message dev buf key)
  (consume-cstr (tuya_decode_message dev buf (length buf) key)))

(define (generate-payload dev cmd device-id datapoints)
  (consume-cstr (tuya_generate_payload dev cmd device-id (or datapoints ""))))

(define (send dev buf)
  (tuya_send dev buf (length buf)))

(define (receive dev (maxsize BUFSIZE) (minsize 0))
  (let (buf (dup "\000" maxsize)
        n   (tuya_receive dev buf maxsize minsize))
    (if (> n 0) (slice buf 0 n) nil)))

;; ---- high-level convenience functions ----

(define (set-value dev dp value)
  "Set a single data point on the device.  Value type is auto-detected.
   Returns decoded JSON response or nil."
  (consume-cstr
    (cond
      ((= value true)  (tuya_set_value_bool dev dp 1))
      ((= value nil)   (tuya_set_value_bool dev dp 0))
      ((string? value) (tuya_set_value_string dev dp value))
      ((float? value)  (tuya_set_value_float dev dp (float value)))
      (true            (tuya_set_value_int dev dp (int value))))))

(define (turn-on dev (switch-dp 1))
  "Turn on a switch data point."
  (consume-cstr (tuya_turn_on dev switch-dp)))

(define (turn-off dev (switch-dp 1))
  "Turn off a switch data point."
  (consume-cstr (tuya_turn_off dev switch-dp)))

(define (status dev)
  "Query all data points from the device."
  (consume-cstr (tuya_status dev)))

(define (heartbeat dev)
  "Send a heartbeat to the device."
  (consume-cstr (tuya_heartbeat dev)))

(context MAIN)
