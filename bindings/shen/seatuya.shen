;; seatuya.shen -- Shen FFI bindings for libseatuya
;;
;; Uses Shen's `foreign` mechanism which calls through the underlying
;; Common Lisp host's FFI.  The shared library must be loaded before
;; any foreign calls -- see README.md for host-specific instructions.
;;
;; Usage:
;;   (load "seatuya.shen")
;;   (seatuya:load (or (getenv "SEATUYA_LIB") "libseatuya.so"))
;;   (seatuya:create "devid" "1.2.3.4" "localkey" "3.4")
;;
;; NOTE: malloc'd C strings from tuya_status, tuya_turn_on, etc. are
;; auto-converted to Shen strings but the original C memory is leaked
;; (Shen's foreign interface does not expose the raw pointer after
;; conversion).  This is negligible in typical short-lived scripts.
;;

(package seatuya []

;; ---------------------------------------------------------------------
;; Library loading (host-specific)
;; ---------------------------------------------------------------------

(define load
  {string --> symbol}
  Path -> (cd (str "(load-shared-object \"" Path "\")")))

;; ---------------------------------------------------------------------
;; Version
;; ---------------------------------------------------------------------

(define version
  {--> string}
  (foreign "tuya_version" (--> string)))

;; ---------------------------------------------------------------------
;; Lifecycle
;; ---------------------------------------------------------------------

(define create
  {string --> string --> string --> string --> number}
  (foreign "tuya_create" (string string string string --> number)))

(define alloc
  {string --> number}
  (foreign "tuya_alloc" (string --> number)))

(define destroy
  {number --> symbol}
  (foreign "tuya_destroy" (number --> symbol)))

;; ---------------------------------------------------------------------
;; Credentials
;; ---------------------------------------------------------------------

(define set-credentials
  {number --> string --> string --> symbol}
  (foreign "tuya_set_credentials" (number string string --> symbol)))

(define get-device-id
  {number --> string}
  (foreign "tuya_get_device_id" (number --> string)))

(define get-local-key
  {number --> string}
  (foreign "tuya_get_local_key" (number --> string)))

(define get-ip
  {number --> string}
  (foreign "tuya_get_ip" (number --> string)))

;; ---------------------------------------------------------------------
;; Connection
;; ---------------------------------------------------------------------

(define connect
  {number --> string --> number}
  (foreign "tuya_connect" (number string --> number)))

(define disconnect
  {number --> symbol}
  (foreign "tuya_disconnect" (number --> symbol)))

(define reconnect
  {number --> number}
  (foreign "tuya_reconnect" (number --> number)))

(define is-connected
  {number --> boolean}
  Dev -> (= 1 ((foreign "tuya_is_connected" (number --> number)) Dev)))

;; ---------------------------------------------------------------------
;; Retry
;; ---------------------------------------------------------------------

(define set-retry-limit
  {number --> number --> symbol}
  (foreign "tuya_set_retry_limit" (number number --> symbol)))

(define set-retry-delay
  {number --> number --> symbol}
  (foreign "tuya_set_retry_delay" (number number --> symbol)))

(define get-retry-limit
  {number --> number}
  (foreign "tuya_get_retry_limit" (number --> number)))

(define get-retry-delay
  {number --> number}
  (foreign "tuya_get_retry_delay" (number --> number)))

;; ---------------------------------------------------------------------
;; Session negotiation
;; ---------------------------------------------------------------------

(define negotiate-session
  {number --> string --> number}
  (foreign "tuya_negotiate_session" (number string --> number)))

(define negotiate-session-start
  {number --> string --> number}
  (foreign "tuya_negotiate_session_start" (number string --> number)))

(define negotiate-session-finalize
  {number --> number --> number --> string --> number}
  (foreign "tuya_negotiate_session_finalize"
     (number number number string --> number)))

;; ---------------------------------------------------------------------
;; State queries
;; ---------------------------------------------------------------------

(define get-protocol
  {number --> number}
  (foreign "tuya_get_protocol" (number --> number)))

(define get-session-state
  {number --> number}
  (foreign "tuya_get_session_state" (number --> number)))

(define get-socket-state
  {number --> number}
  (foreign "tuya_get_socket_state" (number --> number)))

(define get-last-error
  {number --> number}
  (foreign "tuya_get_last_error" (number --> number)))

;; ---------------------------------------------------------------------
;; Async
;; ---------------------------------------------------------------------

(define set-async-mode
  {number --> number --> symbol}
  (foreign "tuya_set_async_mode" (number number --> symbol)))

(define is-socket-readable
  {number --> boolean}
  Dev -> (= 1 ((foreign "tuya_is_socket_readable" (number --> number)) Dev)))

(define is-socket-writable
  {number --> boolean}
  Dev -> (= 1 ((foreign "tuya_is_socket_writable" (number --> number)) Dev)))

(define set-session-ready
  {number --> number}
  (foreign "tuya_set_session_ready" (number --> number)))

;; ---------------------------------------------------------------------
;; Message building / decoding
;; ---------------------------------------------------------------------

(define build-message
  {number --> number --> number --> string --> string --> number}
  (foreign "tuya_build_message" (number number number string string --> number)))

(define decode-message
  {number --> number --> number --> string --> string}
  (foreign "tuya_decode_message" (number number number string --> string)))

(define generate-payload
  {number --> number --> string --> string --> string}
  (foreign "tuya_generate_payload" (number number string string --> string)))

;; ---------------------------------------------------------------------
;; Raw send / receive
;; ---------------------------------------------------------------------

(define send
  {number --> number --> number --> number}
  (foreign "tuya_send" (number number number --> number)))

(define receive
  {number --> number --> number --> number --> number}
  (foreign "tuya_receive" (number number number number --> number)))

;; ---------------------------------------------------------------------
;; High-level round-trip (these return malloc'd C strings -- see note)
;; ---------------------------------------------------------------------

(define set-value-bool
  {number --> number --> number --> string}
  (foreign "tuya_set_value_bool" (number number number --> string)))

(define set-value-int
  {number --> number --> number --> string}
  (foreign "tuya_set_value_int" (number number number --> string)))

(define set-value-string
  {number --> number --> string --> string}
  (foreign "tuya_set_value_string" (number number string --> string)))

(define set-value-float
  {number --> number --> number --> string}
  (foreign "tuya_set_value_float" (number number number --> string)))

(define turn-on
  {number --> number --> string}
  (foreign "tuya_turn_on" (number number --> string)))

(define turn-off
  {number --> number --> string}
  (foreign "tuya_turn_off" (number number --> string)))

(define status
  {number --> string}
  (foreign "tuya_status" (number --> string)))

(define heartbeat
  {number --> string}
  (foreign "tuya_heartbeat" (number --> string)))

;; ---------------------------------------------------------------------
;; Memory management
;; ---------------------------------------------------------------------

(define free-string
  {string --> symbol}
  (foreign "tuya_free_string" (string --> symbol)))

;; ---------------------------------------------------------------------
;; device22
;; ---------------------------------------------------------------------

(define set-device22
  {number --> string --> symbol}
  (foreign "tuya_set_device22" (number string --> symbol)))

(define is-device22
  {number --> boolean}
  Dev -> (= 1 ((foreign "tuya_is_device22" (number --> number)) Dev)))

;; ---------------------------------------------------------------------
;; Type-aware set-value dispatcher
;; ---------------------------------------------------------------------

(define set-value
  Dev Dp Value -> (if (boolean? Value)
                     (set-value-bool Dev Dp (if Value 1 0))
                     (if (number? Value)
                         (if (= (floor Value) Value)
                             (set-value-int Dev Dp Value)
                             (set-value-float Dev Dp Value))
                         (set-value-string Dev Dp (str Value)))))

;; ---------------------------------------------------------------------
;; Command constants
;; ---------------------------------------------------------------------

(define cmd-udp                   0)
(define cmd-ap-config             1)
(define cmd-active                2)
(define cmd-bind                  3)
(define cmd-rename-gw             4)
(define cmd-rename-device         5)
(define cmd-unbind                6)
(define cmd-control               7)
(define cmd-status                8)
(define cmd-heart-beat            9)
(define cmd-dp-query             10)
(define cmd-query-wifi           11)
(define cmd-token-bind           12)
(define cmd-control-new          13)
(define cmd-enable-wifi          14)
(define cmd-dp-query-new         16)
(define cmd-scene-execute        17)
(define cmd-updatedps            18)
(define cmd-udp-new              19)
(define cmd-ap-config-new        20)
(define cmd-get-local-time       28)
(define cmd-weather-open         32)
(define cmd-weather-data         33)
(define cmd-state-upload-syn     34)
(define cmd-state-upload-syn-rec 35)
(define cmd-heart-beat-stop      37)
(define cmd-stream-trans         38)
(define cmd-get-wifi-status      43)
(define cmd-wifi-connect-test    44)
(define cmd-get-mac              45)
(define cmd-get-ir-status        46)
(define cmd-ir-tx-rx-test        47)
(define cmd-lan-gw-active       240)
(define cmd-lan-sub-dev-request 241)
(define cmd-lan-delete-sub-dev  242)
(define cmd-lan-report-sub-dev  243)
(define cmd-lan-scene           244)
(define cmd-lan-pub-cloud-config 245)
(define cmd-lan-pub-app-config  246)
(define cmd-lan-export-app-config 247)
(define cmd-lan-pub-scene-panel 248)
(define cmd-lan-remove-gw       249)
(define cmd-lan-check-gw-update 250)
(define cmd-lan-gw-update       251)
(define cmd-lan-set-gw-channel  252)

(define proto-v31 0)
(define proto-v33 1)
(define proto-v34 2)
(define proto-v35 3)

(define default-port        6668)
(define bufsize             1024)
(define default-retry-limit 5)
(define default-retry-delay 100)

)  ;; end package seatuya
