; seatuya.lsp — newLISP module for the seatuya Tuya device library
;
; Usage:
;   (load "seatuya.lsp")
;   (setq dev (tuya:create "3.3"))
;   (tuya:connect dev "192.168.1.50")
;   (tuya:destroy dev)

(context 'tuya)

;; ---- library path ----

(constant 'LIB (or (env "SEATUYA_LIB")
                   (if (= ostype "OSX") "libseatuya.dylib"
                       (= ostype "Windows") "seatuya.dll"
                       "libseatuya.so")))

;; ---- raw imports ----

(import LIB "seatuya_version")
(import LIB "seatuya_create")
(import LIB "seatuya_destroy")
(import LIB "seatuya_connect")
(import LIB "seatuya_disconnect")
(import LIB "seatuya_is_connected")
(import LIB "seatuya_negotiate_session")
(import LIB "seatuya_negotiate_session_start")
(import LIB "seatuya_negotiate_session_finalize")
(import LIB "seatuya_get_protocol")
(import LIB "seatuya_get_session_state")
(import LIB "seatuya_get_socket_state")
(import LIB "seatuya_get_last_error")
(import LIB "seatuya_set_async_mode")
(import LIB "seatuya_is_socket_readable")
(import LIB "seatuya_is_socket_writable")
(import LIB "seatuya_set_session_ready")
(import LIB "seatuya_build_message")
(import LIB "seatuya_decode_message")
(import LIB "seatuya_generate_payload")
(import LIB "seatuya_send")
(import LIB "seatuya_receive")
(import LIB "seatuya_free_string")

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

;; ---- wrapper functions ----

(define (version)
  (get-string (seatuya_version)))

(define (create ver)
  (let (ptr (seatuya_create ver))
    (if (!= ptr 0) ptr nil)))

(define (destroy dev)
  (seatuya_destroy dev))

(define (connect dev hostname)
  (bool? (seatuya_connect dev hostname)))

(define (disconnect dev)
  (seatuya_disconnect dev))

(define (is-connected dev)
  (bool? (seatuya_is_connected dev)))

(define (negotiate-session dev local-key)
  (bool? (seatuya_negotiate_session dev local-key)))

(define (negotiate-session-start dev local-key)
  (bool? (seatuya_negotiate_session_start dev local-key)))

(define (negotiate-session-finalize dev buf local-key)
  (bool? (seatuya_negotiate_session_finalize dev buf (length buf) local-key)))

(define (get-protocol dev)
  (seatuya_get_protocol dev))

(define (get-session-state dev)
  (seatuya_get_session_state dev))

(define (get-socket-state dev)
  (seatuya_get_socket_state dev))

(define (get-last-error dev)
  (seatuya_get_last_error dev))

(define (set-async-mode dev flag)
  (seatuya_set_async_mode dev (if flag 1 0)))

(define (is-socket-readable dev)
  (bool? (seatuya_is_socket_readable dev)))

(define (is-socket-writable dev)
  (bool? (seatuya_is_socket_writable dev)))

(define (set-session-ready dev)
  (bool? (seatuya_set_session_ready dev)))

(define (build-message dev cmd payload key)
  (let (buf (dup "\000" BUFSIZE)
        n   (seatuya_build_message dev buf cmd payload key))
    (if (> n 0) (slice buf 0 n) nil)))

(define (decode-message dev buf key)
  (let (ptr (seatuya_decode_message dev buf (length buf) key))
    (if (!= ptr 0)
      (let (str (get-string ptr))
        (seatuya_free_string ptr)
        str)
      nil)))

(define (generate-payload dev cmd device-id datapoints)
  (let (ptr (seatuya_generate_payload dev cmd device-id (or datapoints "")))
    (if (!= ptr 0)
      (let (str (get-string ptr))
        (seatuya_free_string ptr)
        str)
      nil)))

(define (send dev buf)
  (seatuya_send dev buf (length buf)))

(define (receive dev (maxsize BUFSIZE) (minsize 0))
  (let (buf (dup "\000" maxsize)
        n   (seatuya_receive dev buf maxsize minsize))
    (if (> n 0) (slice buf 0 n) nil)))

;; ---- credential store ----
;; Maps handle -> (device-id local-key) for high-level functions.

(setq credentials '())

(define (set-credentials dev device-id local-key)
  "Store device-id and local-key for a handle, used by set-value and status."
  (if (assoc dev credentials)
    (setf (assoc dev credentials) (list dev device-id local-key))
    (push (list dev device-id local-key) credentials))
  true)

(define (get-credentials dev)
  "Return (device-id local-key) for a handle, or nil."
  (let (entry (assoc dev credentials))
    (when entry (rest entry))))

(define (clear-credentials dev)
  "Remove stored credentials for a handle."
  (setq credentials (clean (fn (e) (= (first e) dev)) credentials))
  true)

;; ---- high-level convenience functions ----

(define (set-value dev dp value)
  "Set a single data point on the device.  Full round-trip: generate payload,
   build message, send, receive, decode.  Returns decoded response or nil."
  (let (creds (get-credentials dev))
    (unless creds
      (throw "tuya:set-value -- no credentials stored (call set-credentials first)"))
    (let (device-id (creds 0)
          local-key (creds 1)
          ;; Format the DPS JSON depending on value type
          dps-json  (cond
                      ((= value true)  (format "{\"%d\":true}" dp))
                      ((= value nil)   (format "{\"%d\":false}" dp))
                      ((string? value) (format "{\"%d\":\"%s\"}" dp value))
                      ((float? value)  (format "{\"%d\":%g}" dp (float value)))
                      (true            (format "{\"%d\":%d}" dp (int value))))
          payload   (generate-payload dev CMD_CONTROL device-id dps-json))
      (unless payload (throw "tuya:set-value -- failed to generate payload"))
      (let (msg (build-message dev CMD_CONTROL payload local-key))
        (unless msg (throw "tuya:set-value -- failed to build message"))
        (let (n (send dev msg))
          (when (< n 0) (throw "tuya:set-value -- send failed"))
          (sleep 200)
          (let (raw (receive dev))
            (when raw
              (decode-message dev raw local-key))))))))

(define (status dev)
  "Query all data points from the device.  Returns decoded response or nil."
  (let (creds (get-credentials dev))
    (unless creds
      (throw "tuya:status -- no credentials stored (call set-credentials first)"))
    (let (device-id (creds 0)
          local-key (creds 1)
          payload   (generate-payload dev CMD_DP_QUERY device-id ""))
      (unless payload (throw "tuya:status -- failed to generate payload"))
      (let (msg (build-message dev CMD_DP_QUERY payload local-key))
        (unless msg (throw "tuya:status -- failed to build message"))
        (let (n (send dev msg))
          (when (< n 0) (throw "tuya:status -- send failed"))
          (sleep 200)
          (let (raw (receive dev))
            (when raw
              (decode-message dev raw local-key))))))))

(context MAIN)
