;;; seatuya.ss -- Gerbil Scheme FFI bindings for libseatuya
;;;
;;; Usage: (import :seatuya/seatuya)
;;;
;;; Set SEATUYA_LIB environment variable to override the library path.
;;; Load at compile time with: gxc seatuya.ss ; gxi -e '(load "seatuya")'
;;; Link with libseatuya at compile time, or use runtime dlopen.

(export #t)

(import
  :gerbil/core
  :gerbil/gambit/ports
  :std/misc/ports
  :std/sugar)

;; ==================================================================
;;  FFI declarations
;; ==================================================================

;; Load libseatuya symbols at compile/link time.
;; The library must be linkable. Use SEATUYA_LIB env var at runtime
;; to override via LD_LIBRARY_PATH or LD_PRELOAD.

(c-declare "#include <seatuya.h>")
(c-declare "
static int gerbil_seatuya_loaded = 0;
static void gerbil_seatuya_load(void) {
    if (gerbil_seatuya_loaded) return;
    const char *path = getenv(\"SEATUYA_LIB\");
    if (!path) path = \"libseatuya.so\";
    void *h = dlopen(path, RTLD_LAZY | RTLD_GLOBAL);
    if (!h) {
        fprintf(stderr, \"seatuya: failed to load %s\\n\", path);
        exit(1);
    }
    gerbil_seatuya_loaded = 1;
}
")

;; ==================================================================
;;  Helper: allocate a uint8 buffer on the C heap
;; ==================================================================

(c-declare "
static unsigned char *seatuya_alloc_buf(int size) {
    return (unsigned char *)calloc(1, (size_t)size);
}
")

;; ==================================================================
;;  Library initialization
;; ==================================================================

(def (seatuya-init!)
  ;; Call dlopen to make symbols globally visible
  ((c-lambda () void "gerbil_seatuya_load")))

;; ==================================================================
;;  Version
;; ==================================================================

(def tuya-version
  (c-lambda () char-string "tuya_version"))

;; ==================================================================
;;  Lifecycle
;; ==================================================================

(def tuya-create
  (c-lambda (char-string char-string char-string char-string) pointer "tuya_create"))

(def tuya-alloc
  (c-lambda (char-string) pointer "tuya_alloc"))

(def tuya-destroy
  (c-lambda (pointer) void "tuya_destroy"))

;; ==================================================================
;;  Credentials
;; ==================================================================

(def tuya-set-credentials
  (c-lambda (pointer char-string char-string) void "tuya_set_credentials"))

(def tuya-get-device-id
  (c-lambda (pointer) char-string "tuya_get_device_id"))

(def tuya-get-local-key
  (c-lambda (pointer) char-string "tuya_get_local_key"))

(def tuya-get-ip
  (c-lambda (pointer) char-string "tuya_get_ip"))

;; ==================================================================
;;  Connection
;; ==================================================================

(def tuya-connect
  (c-lambda (pointer char-string) bool "tuya_connect"))

(def tuya-disconnect
  (c-lambda (pointer) void "tuya_disconnect"))

(def tuya-is-connected
  (c-lambda (pointer) bool "tuya_is_connected"))

(def tuya-reconnect
  (c-lambda (pointer) bool "tuya_reconnect"))

;; ==================================================================
;;  Retry
;; ==================================================================

(def tuya-set-retry-limit
  (c-lambda (pointer int) void "tuya_set_retry_limit"))

(def tuya-set-retry-delay
  (c-lambda (pointer int) void "tuya_set_retry_delay"))

(def tuya-get-retry-limit
  (c-lambda (pointer) int "tuya_get_retry_limit"))

(def tuya-get-retry-delay
  (c-lambda (pointer) int "tuya_get_retry_delay"))

;; ==================================================================
;;  Session negotiation
;; ==================================================================

(def tuya-negotiate-session
  (c-lambda (pointer char-string) bool "tuya_negotiate_session"))

(def tuya-negotiate-session-start
  (c-lambda (pointer char-string) bool "tuya_negotiate_session_start"))

(def tuya-negotiate-session-finalize
  (c-lambda (pointer pointer int char-string) bool "tuya_negotiate_session_finalize"))

;; ==================================================================
;;  State queries
;; ==================================================================

(def tuya-get-protocol
  (c-lambda (pointer) int "tuya_get_protocol"))

(def tuya-get-session-state
  (c-lambda (pointer) int "tuya_get_session_state"))

(def tuya-get-socket-state
  (c-lambda (pointer) int "tuya_get_socket_state"))

(def tuya-get-last-error
  (c-lambda (pointer) int "tuya_get_last_error"))

;; ==================================================================
;;  Async mode
;; ==================================================================

(def tuya-set-async-mode
  (c-lambda (pointer bool) void "tuya_set_async_mode"))

(def tuya-is-socket-readable
  (c-lambda (pointer) bool "tuya_is_socket_readable"))

(def tuya-is-socket-writable
  (c-lambda (pointer) bool "tuya_is_socket_writable"))

(def tuya-set-session-ready
  (c-lambda (pointer) bool "tuya_set_session_ready"))

;; ==================================================================
;;  Message building / decoding
;; ==================================================================

(def tuya-build-message
  (c-lambda (pointer pointer int char-string char-string) int "tuya_build_message"))

(def tuya-decode-message
  (c-lambda (pointer pointer int char-string) char-string "tuya_decode_message"))

(def tuya-generate-payload
  (c-lambda (pointer int char-string char-string) char-string "tuya_generate_payload"))

;; ==================================================================
;;  Raw send / receive
;; ==================================================================

(def tuya-send
  (c-lambda (pointer pointer int) int "tuya_send"))

(def tuya-receive
  (c-lambda (pointer pointer int int) int "tuya_receive"))

;; ==================================================================
;;  device22 mode
;; ==================================================================

(def tuya-set-device22
  (c-lambda (pointer char-string) void "tuya_set_device22"))

(def tuya-is-device22
  (c-lambda (pointer) bool "tuya_is_device22"))

;; ==================================================================
;;  High-level round-trip (return malloc'd strings -> auto-free)
;; ==================================================================

;; Internal: call a C function returning malloc'd char*, convert to
;; Gerbil string, free the C memory.
(def (consume-c-string ptr)
  (if (not (##fx= (pointer->address ptr) 0))
    (let (result (pointer->string ptr))
      (tuya-free-string ptr)
      result)
    #f))

;; We use c-lambda with pointer return, then consume-c-string
(def tuya-set-value-bool
  (c-lambda (pointer int bool) pointer "tuya_set_value_bool"))

(def tuya-set-value-int
  (c-lambda (pointer int int) pointer "tuya_set_value_int"))

(def tuya-set-value-string
  (c-lambda (pointer int char-string) pointer "tuya_set_value_string"))

(def tuya-set-value-float
  (c-lambda (pointer int double) pointer "tuya_set_value_float"))

(def tuya-turn-on
  (c-lambda (pointer int) pointer "tuya_turn_on"))

(def tuya-turn-off
  (c-lambda (pointer int) pointer "tuya_turn_off"))

(def tuya-status
  (c-lambda (pointer) pointer "tuya_status"))

(def tuya-heartbeat
  (c-lambda (pointer) pointer "tuya_heartbeat"))

;; ==================================================================
;;  Memory
;; ==================================================================

(def tuya-free-string
  (c-lambda (pointer) void "tuya_free_string"))

;; ==================================================================
;;  Buffer allocator
;; ==================================================================

(def (seatuya-alloc-buf size)
  ((c-lambda (int) pointer "seatuya_alloc_buf") size))

;; ==================================================================
;;  Wrappers with auto-free for string-returning functions
;; ==================================================================

(def (tuya-set-value-bool* dev dp val)
  (consume-c-string (tuya-set-value-bool dev dp val)))

(def (tuya-set-value-int* dev dp val)
  (consume-c-string (tuya-set-value-int dev dp val)))

(def (tuya-set-value-string* dev dp val)
  (consume-c-string (tuya-set-value-string dev dp val)))

(def (tuya-set-value-float* dev dp val)
  (consume-c-string (tuya-set-value-float dev dp val)))

(def (tuya-turn-on* dev (switch-dp 1))
  (consume-c-string (tuya-turn-on dev switch-dp)))

(def (tuya-turn-off* dev (switch-dp 1))
  (consume-c-string (tuya-turn-off dev switch-dp)))

(def (tuya-status* dev)
  (consume-c-string (tuya-status dev)))

(def (tuya-heartbeat* dev)
  (consume-c-string (tuya-heartbeat dev)))

;; ==================================================================
;;  Type-aware set_value dispatcher
;; ==================================================================
;;
;;  (tuya-set-value dev dp 'bool   #t)
;;  (tuya-set-value dev dp 'int    42)
;;  (tuya-set-value dev dp 'string "hello")
;;  (tuya-set-value dev dp 'float  3.14)
;;

(def (tuya-set-value dev dp typ val)
  (case typ
    ((bool)   (tuya-set-value-bool*   dev dp val))
    ((int)    (tuya-set-value-int*    dev dp val))
    ((string) (tuya-set-value-string* dev dp val))
    ((float)  (tuya-set-value-float*  dev dp val))
    (else (error "Unknown type for tuya-set-value: " typ))))

;; ==================================================================
;;  Constants
;; ==================================================================

;; Protocol versions
(def proto-v31 0)
(def proto-v33 1)
(def proto-v34 2)
(def proto-v35 3)

;; Session states
(def session-invalid      0)
(def session-starting     1)
(def session-finalizing   2)
(def session-established  3)

;; Socket states
(def sock-no-such-host   0)
(def sock-no-sock-avail  1)
(def sock-failed         2)
(def sock-disconnected   3)
(def sock-connecting     4)
(def sock-connected      5)
(def sock-ready          6)
(def sock-receiving      7)

;; Misc
(def default-port           6668)
(def recommended-bufsize    1024)
(def default-retry-limit    5)
(def default-retry-delay-ms 100)

;; Tuya command types (all 45)
(def cmd-udp                     0)
(def cmd-ap-config               1)
(def cmd-active                  2)
(def cmd-bind                    3)
(def cmd-rename-gw               4)
(def cmd-rename-device           5)
(def cmd-unbind                  6)
(def cmd-control                 7)
(def cmd-status                  8)
(def cmd-heart-beat              9)
(def cmd-dp-query               10)
(def cmd-query-wifi             11)
(def cmd-token-bind             12)
(def cmd-control-new            13)
(def cmd-enable-wifi            14)
(def cmd-dp-query-new           16)
(def cmd-scene-execute          17)
(def cmd-updatedps              18)
(def cmd-udp-new                19)
(def cmd-ap-config-new          20)
(def cmd-get-local-time         28)
(def cmd-weather-open           32)
(def cmd-weather-data           33)
(def cmd-state-upload-syn       34)
(def cmd-state-upload-syn-recv  35)
(def cmd-heart-beat-stop        37)
(def cmd-stream-trans           38)
(def cmd-get-wifi-status        43)
(def cmd-wifi-connect-test      44)
(def cmd-get-mac                45)
(def cmd-get-ir-status          46)
(def cmd-ir-tx-rx-test          47)
(def cmd-lan-gw-active          240)
(def cmd-lan-sub-dev-request    241)
(def cmd-lan-delete-sub-dev     242)
(def cmd-lan-report-sub-dev     243)
(def cmd-lan-scene              244)
(def cmd-lan-publish-cloud-config  245)
(def cmd-lan-publish-app-config    246)
(def cmd-lan-export-app-config     247)
(def cmd-lan-publish-scene-panel   248)
(def cmd-lan-remove-gw          249)
(def cmd-lan-check-gw-update    250)
(def cmd-lan-gw-update          251)
(def cmd-lan-set-gw-channel     252)
