#lang racket/base
;;; seatuya.rkt — Racket FFI bindings for libseatuya
;;;
;;; Pure Racket binding using the built-in ffi/unsafe module.
;;; Racket's FFI is part of the core — no packages needed.
;;;
;;; Usage:
;;;   #lang racket
;;;   (require "seatuya.rkt")
;;;   (define dev (seatuya-create device-id "192.168.1.100" local-key "3.4"))
;;;   (printf "~A~%" (seatuya-turn-on dev 1))
;;;   (seatuya-destroy dev)

(require ffi/unsafe
         ffi/unsafe/define
         racket/runtime-path)

;; ── Library loading ──
(define-runtime-path libseatuya-so
  (or (getenv "SEATUYA_LIB")
      (system-type 'so-suffix)
      (case (system-type 'os)
        ((macosx) "libseatuya.dylib")
        (else "libseatuya.so"))))

(define libseatuya (ffi-lib libseatuya-so))

;; ── FFI function definitions ──
(define-ffi-definer define-seatuya libseatuya)

(define-seatuya tuya-version (_fun -> _string))
(define-seatuya tuya_create (_fun _string _string _string _string -> _pointer))
(define-seatuya tuya_alloc (_fun _string -> _pointer))
(define-seatuya tuya_destroy (_fun _pointer -> _void))
(define-seatuya tuya_set_credentials (_fun _pointer _string _string -> _void))
(define-seatuya tuya_get_device_id (_fun _pointer -> _string))
(define-seatuya tuya_get_local_key (_fun _pointer -> _string))
(define-seatuya tuya_get_ip (_fun _pointer -> _string))
(define-seatuya tuya_connect (_fun _pointer _string -> _bool))
(define-seatuya tuya_disconnect (_fun _pointer -> _void))
(define-seatuya tuya_is_connected (_fun _pointer -> _bool))
(define-seatuya tuya_reconnect (_fun _pointer -> _bool))
(define-seatuya tuya_set_retry_limit (_fun _pointer _int -> _void))
(define-seatuya tuya_set_retry_delay (_fun _pointer _int -> _void))
(define-seatuya tuya_get_retry_limit (_fun _pointer -> _int))
(define-seatuya tuya_get_retry_delay (_fun _pointer -> _int))
(define-seatuya tuya_negotiate_session (_fun _pointer _string -> _bool))
(define-seatuya tuya_negotiate_session_start (_fun _pointer _string -> _bool))
(define-seatuya tuya_negotiate_session_finalize (_fun _pointer _pointer _int _string -> _bool))
(define-seatuya tuya_get_protocol (_fun _pointer -> _int))
(define-seatuya tuya_get_session_state (_fun _pointer -> _int))
(define-seatuya tuya_get_socket_state (_fun _pointer -> _int))
(define-seatuya tuya_get_last_error (_fun _pointer -> _int))
(define-seatuya tuya_set_async_mode (_fun _pointer _bool -> _void))
(define-seatuya tuya_is_socket_readable (_fun _pointer -> _bool))
(define-seatuya tuya_is_socket_writable (_fun _pointer -> _bool))
(define-seatuya tuya_set_session_ready (_fun _pointer -> _bool))
(define-seatuya tuya_build_message (_fun _pointer _pointer _int _string _string -> _int))
(define-seatuya tuya_decode_message (_fun _pointer _pointer _int _string -> _string))
(define-seatuya tuya_generate_payload (_fun _pointer _int _string _string -> _string))
(define-seatuya tuya_send (_fun _pointer _pointer _int -> _int))
(define-seatuya tuya_receive (_fun _pointer _pointer _int _int -> _int))
(define-seatuya tuya_set_value_bool (_fun _pointer _int _bool -> _string))
(define-seatuya tuya_set_value_int (_fun _pointer _int _int -> _string))
(define-seatuya tuya_set_value_string (_fun _pointer _int _string -> _string))
(define-seatuya tuya_set_value_float (_fun _pointer _int _double -> _string))
(define-seatuya tuya_turn_on (_fun _pointer _int -> _string))
(define-seatuya tuya_turn_off (_fun _pointer _int -> _string))
(define-seatuya tuya_status (_fun _pointer -> _string))
(define-seatuya tuya_heartbeat (_fun _pointer -> _string))
(define-seatuya tuya_free_string (_fun _string -> _void))
(define-seatuya tuya_set_device22 (_fun _pointer _string -> _void))
(define-seatuya tuya_is_device22 (_fun _pointer -> _bool))

;; ── Constants ──
(define CMD-CONTROL 7)
(define CMD-DP-QUERY 10)
(define CMD-HEART-BEAT 9)
(define CMD-STATUS 8)
(define CMD-CONTROL-NEW 13)
(define CMD-DP-QUERY-NEW 16)
(define PROTO-V31 0)
(define PROTO-V33 1)
(define PROTO-V34 2)
(define PROTO-V35 3)
(define DEFAULT-PORT 6668)
(define BUFSIZE 1024)
(define DEFAULT-RETRY-LIMIT 5)
(define DEFAULT-RETRY-DELAY 100)

;; ── Convenience wrappers ──
(define (seatuya-version) (tuya-version))

(define (seatuya-create device-id address local-key ver)
  (let ((ptr (tuya_create device-id address local-key ver)))
    (and (not (ptr-equal? ptr #f)) ptr)))

(define (seatuya-alloc ver)
  (let ((ptr (tuya_alloc ver)))
    (and (not (ptr-equal? ptr #f)) ptr)))

(define (seatuya-destroy dev) (tuya_destroy dev))

(define (seatuya-set-credentials dev id key) (tuya_set_credentials dev id key))
(define (seatuya-get-device-id dev) (tuya_get_device_id dev))
(define (seatuya-get-local-key dev) (tuya_get_local_key dev))
(define (seatuya-get-ip dev) (tuya_get_ip dev))

(define (seatuya-connect dev hostname) (tuya_connect dev hostname))
(define (seatuya-disconnect dev) (tuya_disconnect dev))
(define (seatuya-is-connected dev) (tuya_is_connected dev))
(define (seatuya-reconnect dev) (tuya_reconnect dev))

(define (seatuya-set-retry-limit dev limit) (tuya_set_retry_limit dev limit))
(define (seatuya-set-retry-delay dev ms) (tuya_set_retry_delay dev ms))
(define (seatuya-get-retry-limit dev) (tuya_get_retry_limit dev))
(define (seatuya-get-retry-delay dev) (tuya_get_retry_delay dev))

(define (seatuya-negotiate-session dev key) (tuya_negotiate_session dev key))

(define (seatuya-get-protocol dev) (tuya_get_protocol dev))
(define (seatuya-get-session-state dev) (tuya_get_session_state dev))
(define (seatuya-get-socket-state dev) (tuya_get_socket_state dev))
(define (seatuya-get-last-error dev) (tuya_get_last_error dev))

(define (seatuya-set-async-mode dev flag) (tuya_set_async_mode dev flag))

(define (seatuya-set-value-bool dev dp value) (tuya_set_value_bool dev dp value))
(define (seatuya-set-value-int dev dp value) (tuya_set_value_int dev dp value))
(define (seatuya-set-value-string dev dp value) (tuya_set_value_string dev dp value))
(define (seatuya-set-value-float dev dp value) (tuya_set_value_float dev dp value))

(define (seatuya-set-value dev dp value)
  (cond
    ((boolean? value) (tuya_set_value_bool dev dp value))
    ((exact-integer? value) (tuya_set_value_int dev dp value))
    ((real? value) (tuya_set_value_float dev dp (exact->inexact value)))
    (else (tuya_set_value_string dev dp (~a value)))))

(define (seatuya-turn-on dev (dp 1)) (tuya_turn_on dev dp))
(define (seatuya-turn-off dev (dp 1)) (tuya_turn_off dev dp))
(define (seatuya-status dev) (tuya_status dev))
(define (seatuya-heartbeat dev) (tuya_heartbeat dev))

(define (seatuya-set-device22 dev null-dps-json) (tuya_set_device22 dev null-dps-json))
(define (seatuya-is-device22 dev) (tuya_is_device22 dev))

;; Low-level
(define (seatuya-build-message dev cmd payload key)
  (define buf (make-bytes BUFSIZE))
  (define n (tuya_build_message dev buf cmd payload key))
  (and (> n 0) (subbytes buf 0 n)))

(define (seatuya-decode-message dev buf key)
  (tuya_decode_message dev buf (bytes-length buf) key))

(define (seatuya-send dev buf)
  (tuya_send dev buf (bytes-length buf)))

(define (seatuya-receive dev (maxsize BUFSIZE) (minsize 0))
  (define buf (make-bytes maxsize))
  (define n (tuya_receive dev buf maxsize minsize))
  (and (> n 0) (subbytes buf 0 n)))

;; ── Exports ──
(provide
 seatuya-version seatuya-create seatuya-alloc seatuya-destroy
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
 PROTO-V31 PROTO-V33 PROTO-V34 PROTO-V35
 DEFAULT-PORT BUFSIZE DEFAULT-RETRY-LIMIT DEFAULT-RETRY-DELAY)
