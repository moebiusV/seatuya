;;; seatuya.scm — GNU Guile FFI bindings for libseatuya
;;;
;;; Pure Guile Scheme binding using the built-in (system foreign) module.
;;; Guile's dynamic FFI is part of the core — no packages needed.
;;;
;;; Usage:
;;;   (use-modules (seatuya))
;;;   (define dev (seatuya-create "dev-id" "192.168.1.100" "key" "3.4"))
;;;   (format #t "~A~%" (seatuya-turn-on dev 1))
;;;   (seatuya-destroy dev)

(define-module (seatuya)
  #:use-module (system foreign)
  #:use-module (system foreign-library)
  #:use-module (rnrs bytevectors)
  #:export (seatuya-version
            seatuya-create seatuya-alloc seatuya-destroy
            seatuya-set-credentials seatuya-get-device-id seatuya-get-local-key seatuya-get-ip
            seatuya-connect seatuya-disconnect seatuya-is-connected seatuya-reconnect
            seatuya-set-retry-limit seatuya-set-retry-delay seatuya-get-retry-limit seatuya-get-retry-delay
            seatuya-negotiate-session
            seatuya-get-protocol seatuya-get-session-state seatuya-get-socket-state seatuya-get-last-error
            seatuya-set-async-mode
            seatuya-set-value seatuya-set-value-bool seatuya-set-value-int
            seatuya-set-value-string seatuya-set-value-float
            seatuya-turn-on seatuya-turn-off seatuya-status seatuya-heartbeat
            seatuya-build-message seatuya-decode-message seatuya-send seatuya-receive
            seatuya-set-device22 seatuya-is-device22
            CMD-CONTROL CMD-DP-QUERY CMD-HEART-BEAT CMD-STATUS CMD-CONTROL-NEW CMD-DP-QUERY-NEW
            PROTO-V31 PROTO-V33 PROTO-V34 PROTO-V35))

;; ── Library ──
(define lib-path
  (or (getenv "SEATUYA_LIB")
      "libseatuya.so"))

(define libseatuya (dynamic-link lib-path))

;; ── Helper: define a foreign function ──
(define-syntax define-cfun
  (syntax-rules ()
    ((_ name ret args ...)
     (define name
       (pointer->procedure ret
         (dynamic-func (symbol->string 'name) libseatuya)
         (list args ...))))))

(define-cfun tuya-version '*)
(define-cfun tuya_create '* '* '* '* '*)
(define-cfun tuya_alloc '* '*)
(define-cfun tuya_destroy void '*)
(define-cfun tuya_set_credentials void '* '* '*)
(define-cfun tuya_get_device_id '* '*)
(define-cfun tuya_get_local_key '* '*)
(define-cfun tuya_get_ip '* '*)
(define-cfun tuya_connect int '* '*)
(define-cfun tuya_disconnect void '*)
(define-cfun tuya_is_connected int '*)
(define-cfun tuya_reconnect int '*)
(define-cfun tuya_set_retry_limit void '* int)
(define-cfun tuya_set_retry_delay void '* int)
(define-cfun tuya_get_retry_limit int '*)
(define-cfun tuya_get_retry_delay int '*)
(define-cfun tuya_negotiate_session int '* '*)
(define-cfun tuya_negotiate_session_start int '* '*)
(define-cfun tuya_negotiate_session_finalize int '* '* int '*)
(define-cfun tuya_get_protocol int '*)
(define-cfun tuya_get_session_state int '*)
(define-cfun tuya_get_socket_state int '*)
(define-cfun tuya_get_last_error int '*)
(define-cfun tuya_set_async_mode void '* int)
(define-cfun tuya_is_socket_readable int '*)
(define-cfun tuya_is_socket_writable int '*)
(define-cfun tuya_set_session_ready int '*)
(define-cfun tuya_build_message int '* '* int '* '*)
(define-cfun tuya_decode_message '* '* int '*)
(define-cfun tuya_generate_payload '* int '* '*)
(define-cfun tuya_send int '* '* int)
(define-cfun tuya_receive int '* '* int int)
(define-cfun tuya_set_value_bool '* '* int int)
(define-cfun tuya_set_value_int '* '* int int)
(define-cfun tuya_set_value_string '* '* int '*)
(define-cfun tuya_set_value_float '* '* int double)
(define-cfun tuya_turn_on '* '* int)
(define-cfun tuya_turn_off '* '* int)
(define-cfun tuya_status '* '*)
(define-cfun tuya_heartbeat '* '*)
(define-cfun tuya_free_string void '*)
(define-cfun tuya_set_device22 void '* '*)
(define-cfun tuya_is_device22 int '*)

;; ── Constants ──
(define CMD-CONTROL 7) (define CMD-DP-QUERY 10) (define CMD-HEART-BEAT 9)
(define CMD-STATUS 8) (define CMD-CONTROL-NEW 13) (define CMD-DP-QUERY-NEW 16)
(define PROTO-V31 0) (define PROTO-V33 1) (define PROTO-V34 2) (define PROTO-V35 3)
(define DEFAULT-PORT 6668) (define BUFSIZE 1024)

;; ── Convenience wrappers ──
(define (seatuya-version)
  (pointer->string (tuya-version)))

(define (seatuya-create device-id address local-key ver)
  (let ((ptr (tuya_create (string->pointer device-id)
                          (string->pointer address)
                          (string->pointer local-key)
                          (string->pointer ver))))
    (if (null-pointer? ptr) #f ptr)))

(define (seatuya-alloc ver)
  (let ((ptr (tuya_alloc (string->pointer ver))))
    (if (null-pointer? ptr) #f ptr)))

(define (seatuya-destroy dev) (tuya_destroy dev))

(define (seatuya-set-credentials dev id key)
  (tuya_set_credentials dev (string->pointer id) (string->pointer key)))

(define (seatuya-get-device-id dev) (pointer->string (tuya_get_device_id dev)))
(define (seatuya-get-local-key dev) (pointer->string (tuya_get_local_key dev)))
(define (seatuya-get-ip dev) (pointer->string (tuya_get_ip dev)))

(define (seatuya-connect dev hostname)
  (not (zero? (tuya_connect dev (string->pointer hostname)))))

(define (seatuya-disconnect dev) (tuya_disconnect dev))
(define (seatuya-is-connected dev) (not (zero? (tuya_is_connected dev))))
(define (seatuya-reconnect dev) (not (zero? (tuya_reconnect dev))))

(define (seatuya-set-retry-limit dev limit) (tuya_set_retry_limit dev limit))
(define (seatuya-set-retry-delay dev ms) (tuya_set_retry_delay dev ms))
(define (seatuya-get-retry-limit dev) (tuya_get_retry_limit dev))
(define (seatuya-get-retry-delay dev) (tuya_get_retry_delay dev))

(define (seatuya-negotiate-session dev key)
  (not (zero? (tuya_negotiate_session dev (string->pointer key)))))

(define (seatuya-get-protocol dev) (tuya_get_protocol dev))
(define (seatuya-get-session-state dev) (tuya_get_session_state dev))
(define (seatuya-get-socket-state dev) (tuya_get_socket_state dev))
(define (seatuya-get-last-error dev) (tuya_get_last_error dev))

(define (seatuya-set-async-mode dev flag)
  (tuya_set_async_mode dev (if flag 1 0)))

(define (_consume-cstr ptr)
  (if (null-pointer? ptr) #f
      (let ((s (pointer->string ptr)))
        (tuya_free_string ptr)
        s)))

(define (seatuya-set-value-bool dev dp value)
  (_consume-cstr (tuya_set_value_bool dev dp (if value 1 0))))

(define (seatuya-set-value-int dev dp value)
  (_consume-cstr (tuya_set_value_int dev dp value)))

(define (seatuya-set-value-string dev dp value)
  (_consume-cstr (tuya_set_value_string dev dp (string->pointer value))))

(define (seatuya-set-value-float dev dp value)
  (_consume-cstr (tuya_set_value_float dev dp value)))

(define (seatuya-set-value dev dp value)
  (cond
    ((boolean? value) (seatuya-set-value-bool dev dp value))
    ((integer? value) (seatuya-set-value-int dev dp value))
    ((real? value)    (seatuya-set-value-float dev dp (exact->inexact value)))
    (else             (seatuya-set-value-string dev dp (object->string value)))))

(define (seatuya-turn-on dev . rest)
  (let ((dp (if (null? rest) 1 (car rest))))
    (_consume-cstr (tuya_turn_on dev dp))))

(define (seatuya-turn-off dev . rest)
  (let ((dp (if (null? rest) 1 (car rest))))
    (_consume-cstr (tuya_turn_off dev dp))))

(define (seatuya-status dev)
  (_consume-cstr (tuya_status dev)))

(define (seatuya-heartbeat dev)
  (_consume-cstr (tuya_heartbeat dev)))

(define (seatuya-set-device22 dev null-dps-json)
  (tuya_set_device22 dev (string->pointer null-dps-json)))

(define (seatuya-is-device22 dev)
  (not (zero? (tuya_is_device22 dev))))

;; Low-level
(define (seatuya-build-message dev cmd payload key)
  (let ((buf (make-bytevector BUFSIZE)))
    (let ((n (tuya_build_message dev (bytevector->pointer buf) cmd
                                  (string->pointer payload)
                                  (string->pointer key))))
      (if (> n 0) (bytevector-slice buf 0 n) #f))))

(define (seatuya-decode-message dev buf key)
  (_consume-cstr (tuya_decode_message dev (bytevector->pointer buf)
                                      (bytevector-length buf)
                                      (string->pointer key))))

(define (seatuya-send dev buf)
  (tuya_send dev (bytevector->pointer buf) (bytevector-length buf)))

(define (seatuya-receive dev . rest)
  (let ((maxsize (if (null? rest) BUFSIZE (car rest)))
        (minsize (if (or (null? rest) (null? (cdr rest))) 0 (cadr rest))))
    (let ((buf (make-bytevector maxsize)))
      (let ((n (tuya_receive dev (bytevector->pointer buf) maxsize minsize)))
        (if (> n 0) (bytevector-slice buf 0 n) #f)))))
