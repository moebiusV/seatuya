;;; seatuya.scm -- Chicken Scheme FFI bindings for libseatuya
;;;
;;; Usage: (require-library seatuya) or (import seatuya)
;;;
;;; Set SEATUYA_LIB environment variable to override the library path.
;;; Compile with: csc -s seatuya.scm -L -lseatuya
;;; Or compile and use at runtime (dlopen with RTLD_GLOBAL).

(module seatuya
    (seatuya-initialize!
     ;; Lifecycle
     tuya-create tuya-alloc tuya-destroy
     ;; Credentials
     tuya-set-credentials tuya-get-device-id tuya-get-local-key tuya-get-ip
     ;; Connection
     tuya-connect tuya-disconnect tuya-is-connected tuya-reconnect
     tuya-set-retry-limit tuya-set-retry-delay
     tuya-get-retry-limit tuya-get-retry-delay
     ;; High-level
     tuya-set-value-bool tuya-set-value-int
     tuya-set-value-string tuya-set-value-float
     tuya-turn-on tuya-turn-off tuya-status tuya-heartbeat
     tuya-set-value
     ;; Memory
     tuya-free-string
     ;; State
     tuya-get-protocol tuya-get-session-state
     tuya-get-socket-state tuya-get-last-error
     ;; Async
     tuya-set-async-mode tuya-is-socket-readable
     tuya-is-socket-writable tuya-set-session-ready
     ;; device22
     tuya-set-device22 tuya-is-device22
     ;; Low-level
     tuya-build-message tuya-decode-message tuya-generate-payload
     tuya-send tuya-receive
     ;; Session negotiation
     tuya-negotiate-session tuya-negotiate-session-start
     tuya-negotiate-session-finalize
     ;; Version
     tuya-version
     ;; --- Constants ---
     ;; Protocol versions
     proto-v31 proto-v33 proto-v34 proto-v35
     ;; Command constants (all 45 from seatuya.h)
     cmd-udp cmd-ap-config cmd-active cmd-bind
     cmd-rename-gw cmd-rename-device cmd-unbind
     cmd-control cmd-status cmd-heart-beat cmd-dp-query
     cmd-query-wifi cmd-token-bind cmd-control-new
     cmd-enable-wifi cmd-dp-query-new cmd-scene-execute
     cmd-updatedps cmd-udp-new cmd-ap-config-new
     cmd-get-local-time cmd-weather-open cmd-weather-data
     cmd-state-upload-syn cmd-state-upload-syn-recv
     cmd-heart-beat-stop cmd-stream-trans cmd-get-wifi-status
     cmd-wifi-connect-test cmd-get-mac cmd-get-ir-status
     cmd-ir-tx-rx-test
     cmd-lan-gw-active cmd-lan-sub-dev-request
     cmd-lan-delete-sub-dev cmd-lan-report-sub-dev
     cmd-lan-scene cmd-lan-publish-cloud-config
     cmd-lan-publish-app-config cmd-lan-export-app-config
     cmd-lan-publish-scene-panel cmd-lan-remove-gw
     cmd-lan-check-gw-update cmd-lan-gw-update
     cmd-lan-set-gw-channel
     ;; Session states
     session-invalid session-starting session-finalizing session-established
     ;; Socket states
     sock-no-such-host sock-no-sock-avail sock-failed
     sock-disconnected sock-connecting sock-connected
     sock-ready sock-receiving
     ;; Misc constants
     default-port recommended-bufsize
     default-retry-limit default-retry-delay-ms)

  (import scheme chicken.base chicken.foreign chicken.process-context)

  (foreign-declare "#include <dlfcn.h>")
  (foreign-declare "#include <stdbool.h>")
  (foreign-declare "#include <string.h>")

  ;; ------------------------------------------------------------------
  ;;  Library loading
  ;; ------------------------------------------------------------------

  (foreign-code "
static void *seatuya_lib = NULL;

int seatuya_load_lib(const char *path) {
    if (seatuya_lib) return 0;
    seatuya_lib = dlopen(path, RTLD_LAZY | RTLD_GLOBAL);
    return (seatuya_lib != NULL) ? 0 : -1;
}

void *seatuya_find_sym(const char *name) {
    if (!seatuya_lib) return NULL;
    return dlsym(seatuya_lib, name);
}
")

  (define (seatuya-initialize!)
    (let* ((path (or (get-environment-variable "SEATUYA_LIB")
                     "libseatuya.so"))
           (result ((foreign-lambda* int (c-string p)
                      \"return seatuya_load_lib(p);\") path)))
      (unless (zero? result)
        (error (string-append "Failed to load libseatuya from: " path)))))

  ;; ------------------------------------------------------------------
  ;;  Version
  ;; ------------------------------------------------------------------

  (define tuya-version
    (foreign-lambda c-string "tuya_version"))

  ;; ------------------------------------------------------------------
  ;;  Lifecycle
  ;; ------------------------------------------------------------------

  (define tuya-create
    (foreign-lambda c-pointer "tuya_create"
      c-string c-string c-string c-string))

  (define tuya-alloc
    (foreign-lambda c-pointer "tuya_alloc" c-string))

  (define tuya-destroy
    (foreign-lambda void "tuya_destroy" c-pointer))

  ;; ------------------------------------------------------------------
  ;;  Credentials
  ;; ------------------------------------------------------------------

  (define tuya-set-credentials
    (foreign-lambda void "tuya_set_credentials"
      c-pointer c-string c-string))

  (define tuya-get-device-id
    (foreign-lambda c-string "tuya_get_device_id" c-pointer))

  (define tuya-get-local-key
    (foreign-lambda c-string "tuya_get_local_key" c-pointer))

  (define tuya-get-ip
    (foreign-lambda c-string "tuya_get_ip" c-pointer))

  ;; ------------------------------------------------------------------
  ;;  Connection
  ;; ------------------------------------------------------------------

  (define tuya-connect
    (foreign-lambda bool "tuya_connect" c-pointer c-string))

  (define tuya-disconnect
    (foreign-lambda void "tuya_disconnect" c-pointer))

  (define tuya-is-connected
    (foreign-lambda bool "tuya_is_connected" c-pointer))

  (define tuya-reconnect
    (foreign-lambda bool "tuya_reconnect" c-pointer))

  ;; ------------------------------------------------------------------
  ;;  Retry settings
  ;; ------------------------------------------------------------------

  (define tuya-set-retry-limit
    (foreign-lambda void "tuya_set_retry_limit" c-pointer int))

  (define tuya-set-retry-delay
    (foreign-lambda void "tuya_set_retry_delay" c-pointer int))

  (define tuya-get-retry-limit
    (foreign-lambda int "tuya_get_retry_limit" c-pointer))

  (define tuya-get-retry-delay
    (foreign-lambda int "tuya_get_retry_delay" c-pointer))

  ;; ------------------------------------------------------------------
  ;;  Session negotiation
  ;; ------------------------------------------------------------------

  (define tuya-negotiate-session
    (foreign-lambda bool "tuya_negotiate_session" c-pointer c-string))

  (define tuya-negotiate-session-start
    (foreign-lambda bool "tuya_negotiate_session_start" c-pointer c-string))

  (define tuya-negotiate-session-finalize
    (foreign-lambda bool "tuya_negotiate_session_finalize"
      c-pointer c-pointer int c-string))

  ;; ------------------------------------------------------------------
  ;;  State queries
  ;; ------------------------------------------------------------------

  (define tuya-get-protocol
    (foreign-lambda int "tuya_get_protocol" c-pointer))

  (define tuya-get-session-state
    (foreign-lambda int "tuya_get_session_state" c-pointer))

  (define tuya-get-socket-state
    (foreign-lambda int "tuya_get_socket_state" c-pointer))

  (define tuya-get-last-error
    (foreign-lambda int "tuya_get_last_error" c-pointer))

  ;; ------------------------------------------------------------------
  ;;  Async mode
  ;; ------------------------------------------------------------------

  (define tuya-set-async-mode
    (foreign-lambda void "tuya_set_async_mode" c-pointer bool))

  (define tuya-is-socket-readable
    (foreign-lambda bool "tuya_is_socket_readable" c-pointer))

  (define tuya-is-socket-writable
    (foreign-lambda bool "tuya_is_socket_writable" c-pointer))

  (define tuya-set-session-ready
    (foreign-lambda bool "tuya_set_session_ready" c-pointer))

  ;; ------------------------------------------------------------------
  ;;  Message building / decoding
  ;; ------------------------------------------------------------------

  (define tuya-build-message
    (foreign-lambda int "tuya_build_message"
      c-pointer c-pointer int c-string c-string))

  (define tuya-decode-message
    (foreign-lambda c-string "tuya_decode_message"
      c-pointer c-pointer int c-string))

  (define tuya-generate-payload
    (foreign-lambda c-string "tuya_generate_payload"
      c-pointer int c-string c-string))

  ;; ------------------------------------------------------------------
  ;;  Raw send / receive
  ;; ------------------------------------------------------------------

  (define tuya-send
    (foreign-lambda int "tuya_send" c-pointer c-pointer int))

  (define tuya-receive
    (foreign-lambda int "tuya_receive" c-pointer c-pointer int int))

  ;; ------------------------------------------------------------------
  ;;  device22 mode
  ;; ------------------------------------------------------------------

  (define tuya-set-device22
    (foreign-lambda void "tuya_set_device22" c-pointer c-string))

  (define tuya-is-device22
    (foreign-lambda bool "tuya_is_device22" c-pointer))

  ;; ------------------------------------------------------------------
  ;;  High-level set_value helpers (return malloc'd strings -> auto-free)
  ;; ------------------------------------------------------------------

  (define (%make-free-ret ffi-lambda)
    ;; Given a foreign-lambda that returns a c-pointer (malloc'd string),
    ;; return a procedure that converts to a Scheme string and frees the
    ;; C memory.
    (lambda args
      (let ((ptr (apply ffi-lambda args)))
        (if (null-pointer? ptr)
            #f
            (let ((s ((foreign-lambda* c-string (c-pointer p)
                        "return (const char *)p;") ptr)))
              (tuya-free-string ptr)
              s))))))

  (define %set-value-bool-ptr
    (foreign-lambda c-pointer "tuya_set_value_bool" c-pointer int bool))

  (define tuya-set-value-bool
    (%make-free-ret %set-value-bool-ptr))

  (define %set-value-int-ptr
    (foreign-lambda c-pointer "tuya_set_value_int" c-pointer int int))

  (define tuya-set-value-int
    (%make-free-ret %set-value-int-ptr))

  (define %set-value-string-ptr
    (foreign-lambda c-pointer "tuya_set_value_string" c-pointer int c-string))

  (define tuya-set-value-string
    (%make-free-ret %set-value-string-ptr))

  (define %set-value-float-ptr
    (foreign-lambda c-pointer "tuya_set_value_float" c-pointer int double))

  (define tuya-set-value-float
    (%make-free-ret %set-value-float-ptr))

  ;; ------------------------------------------------------------------
  ;;  High-level convenience wrappers (return malloc'd strings)
  ;; ------------------------------------------------------------------

  (define %turn-on-ptr
    (foreign-lambda c-pointer "tuya_turn_on" c-pointer int))

  (define tuya-turn-on
    (%make-free-ret %turn-on-ptr))

  (define %turn-off-ptr
    (foreign-lambda c-pointer "tuya_turn_off" c-pointer int))

  (define tuya-turn-off
    (%make-free-ret %turn-off-ptr))

  (define %status-ptr
    (foreign-lambda c-pointer "tuya_status" c-pointer))

  (define tuya-status
    (%make-free-ret %status-ptr))

  (define %heartbeat-ptr
    (foreign-lambda c-pointer "tuya_heartbeat" c-pointer))

  (define tuya-heartbeat
    (%make-free-ret %heartbeat-ptr))

  ;; ------------------------------------------------------------------
  ;;  Type-aware set_value dispatcher
  ;; ------------------------------------------------------------------
  ;;
  ;;  (tuya-set-value DEV dp 'bool #t)
  ;;  (tuya-set-value DEV dp 'int 42)
  ;;  (tuya-set-value DEV dp 'string "hello")
  ;;  (tuya-set-value DEV dp 'float 3.14)
  ;;
  ;; ------------------------------------------------------------------

  (define (tuya-set-value dev dp typ val)
    (case typ
      ((bool)   (tuya-set-value-bool   dev dp val))
      ((int)    (tuya-set-value-int    dev dp val))
      ((string) (tuya-set-value-string dev dp val))
      ((float)  (tuya-set-value-float  dev dp val))
      (else (error "Unknown type for tuya-set-value: " typ))))

  ;; ------------------------------------------------------------------
  ;;  Memory management
  ;; ------------------------------------------------------------------

  (define tuya-free-string
    (foreign-lambda void "tuya_free_string" c-pointer))

  ;; ==================================================================
  ;;  Constants
  ;; ==================================================================

  ;; Protocol versions
  (define proto-v31 0)
  (define proto-v33 1)
  (define proto-v34 2)
  (define proto-v35 3)

  ;; Tuya command types (all 45 from seatuya.h)
  (define cmd-udp                  0)
  (define cmd-ap-config            1)
  (define cmd-active               2)
  (define cmd-bind                 3)
  (define cmd-rename-gw            4)
  (define cmd-rename-device        5)
  (define cmd-unbind               6)
  (define cmd-control              7)
  (define cmd-status               8)
  (define cmd-heart-beat           9)
  (define cmd-dp-query            10)
  (define cmd-query-wifi          11)
  (define cmd-token-bind          12)
  (define cmd-control-new         13)
  (define cmd-enable-wifi         14)
  (define cmd-dp-query-new        16)
  (define cmd-scene-execute       17)
  (define cmd-updatedps           18)
  (define cmd-udp-new             19)
  (define cmd-ap-config-new       20)
  (define cmd-get-local-time      28)
  (define cmd-weather-open        32)
  (define cmd-weather-data        33)
  (define cmd-state-upload-syn    34)
  (define cmd-state-upload-syn-recv 35)
  (define cmd-heart-beat-stop     37)
  (define cmd-stream-trans        38)
  (define cmd-get-wifi-status     43)
  (define cmd-wifi-connect-test   44)
  (define cmd-get-mac             45)
  (define cmd-get-ir-status       46)
  (define cmd-ir-tx-rx-test       47)
  (define cmd-lan-gw-active       240)
  (define cmd-lan-sub-dev-request 241)
  (define cmd-lan-delete-sub-dev  242)
  (define cmd-lan-report-sub-dev  243)
  (define cmd-lan-scene           244)
  (define cmd-lan-publish-cloud-config 245)
  (define cmd-lan-publish-app-config   246)
  (define cmd-lan-export-app-config    247)
  (define cmd-lan-publish-scene-panel  248)
  (define cmd-lan-remove-gw       249)
  (define cmd-lan-check-gw-update 250)
  (define cmd-lan-gw-update       251)
  (define cmd-lan-set-gw-channel  252)

  ;; Session states
  (define session-invalid      0)
  (define session-starting     1)
  (define session-finalizing   2)
  (define session-established  3)

  ;; Socket states
  (define sock-no-such-host   0)
  (define sock-no-sock-avail  1)
  (define sock-failed         2)
  (define sock-disconnected   3)
  (define sock-connecting     4)
  (define sock-connected      5)
  (define sock-ready          6)
  (define sock-receiving      7)

  ;; Misc
  (define default-port           6668)
  (define recommended-bufsize    1024)
  (define default-retry-limit    5)
  (define default-retry-delay-ms 100)

) ;; end module seatuya
