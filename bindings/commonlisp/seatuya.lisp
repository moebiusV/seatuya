;;; seatuya.lisp — Common Lisp CFFI bindings for libseatuya
;;;
;;; Portable across SBCL, ECL, CCL, Allegro, LispWorks — anything
;;; that CFFI supports.  Requires: (ql:quickload :cffi)
;;;
;;; Usage:
;;;   (ql:quickload :cffi)
;;;   (load "seatuya.lisp")
;;;   (defvar dev (seatuya:create device-id "192.168.1.100" local-key "3.4"))
;;;   (format t "~A~%" (seatuya:turn-on dev 1))
;;;   (seatuya:destroy dev)

(unless (find-package :cffi)
  (eval-when (:compile-toplevel :load-toplevel :execute)
    (require :cffi)))

(defpackage :seatuya
  (:use :cl :cffi)
  (:export
   ;; Library
   #:version
   ;; Lifecycle
   #:create #:alloc #:destroy
   ;; Credentials
   #:set-credentials #:get-device-id #:get-local-key #:get-ip
   ;; Connection
   #:connect #:disconnect #:is-connected #:reconnect
   ;; Retry
   #:set-retry-limit #:set-retry-delay #:get-retry-limit #:get-retry-delay
   ;; Session
   #:negotiate-session #:negotiate-session-start #:negotiate-session-finalize
   ;; State
   #:get-protocol #:get-session-state #:get-socket-state #:get-last-error
   ;; Async
   #:set-async-mode #:is-socket-readable #:is-socket-writable #:set-session-ready
   ;; Low-level
   #:build-message #:decode-message #:generate-payload #:send-frame #:receive-frame
   ;; High-level
   #:set-value #:set-value-bool #:set-value-int #:set-value-string #:set-value-float
   #:turn-on #:turn-off #:status #:heartbeat
   ;; device22
   #:set-device22 #:is-device22
   ;; Constants
   #:+cmd-control+ #:+cmd-dp-query+ #:+cmd-heart-beat+ #:+cmd-status+
   #:+cmd-control-new+ #:+cmd-dp-query-new+
   #:+proto-v31+ #:+proto-v33+ #:+proto-v34+ #:+proto-v35+
   #:+default-port+ #:+bufsize+ #:+default-retry-limit+ #:+default-retry-delay+))

(in-package :seatuya)

;; ── Library loading ──
(define-foreign-library seatuya-lib
  (:darwin (:or "libseatuya.dylib" "libseatuya.so"))
  (:windows "seatuya.dll")
  (:unix "libseatuya.so")
  (t (:default "libseatuya")))

(use-foreign-library seatuya-lib)

;; ── Type definitions ──
(defctype tuya-device-t :pointer)
(defctype bool-t :bool)

;; ── Foreign function declarations ──
(defcfun "tuya_version" :string)
(defcfun ("tuya_create" %create) tuya-device-t (device-id :string) (address :string) (local-key :string) (version :string))
(defcfun ("tuya_alloc" %alloc) tuya-device-t (version :string))
(defcfun "tuya_destroy" :void (dev tuya-device-t))
(defcfun "tuya_set_credentials" :void (dev tuya-device-t) (device-id :string) (local-key :string))
(defcfun "tuya_get_device_id" :string (dev tuya-device-t))
(defcfun "tuya_get_local_key" :string (dev tuya-device-t))
(defcfun "tuya_get_ip" :string (dev tuya-device-t))
(defcfun "tuya_connect" bool-t (dev tuya-device-t) (hostname :string))
(defcfun "tuya_disconnect" :void (dev tuya-device-t))
(defcfun "tuya_is_connected" bool-t (dev tuya-device-t))
(defcfun "tuya_reconnect" bool-t (dev tuya-device-t))
(defcfun "tuya_set_retry_limit" :void (dev tuya-device-t) (limit :int))
(defcfun "tuya_set_retry_delay" :void (dev tuya-device-t) (delay-ms :int))
(defcfun "tuya_get_retry_limit" :int (dev tuya-device-t))
(defcfun "tuya_get_retry_delay" :int (dev tuya-device-t))
(defcfun "tuya_negotiate_session" bool-t (dev tuya-device-t) (key :string))
(defcfun "tuya_negotiate_session_start" bool-t (dev tuya-device-t) (key :string))
(defcfun "tuya_negotiate_session_finalize" bool-t (dev tuya-device-t) (buf :pointer) (size :int) (key :string))
(defcfun "tuya_get_protocol" :int (dev tuya-device-t))
(defcfun "tuya_get_session_state" :int (dev tuya-device-t))
(defcfun "tuya_get_socket_state" :int (dev tuya-device-t))
(defcfun "tuya_get_last_error" :int (dev tuya-device-t))
(defcfun "tuya_set_async_mode" :void (dev tuya-device-t) (flag bool-t))
(defcfun "tuya_is_socket_readable" bool-t (dev tuya-device-t))
(defcfun "tuya_is_socket_writable" bool-t (dev tuya-device-t))
(defcfun "tuya_set_session_ready" bool-t (dev tuya-device-t))
(defcfun "tuya_build_message" :int (dev tuya-device-t) (buf :pointer) (cmd :int) (payload :string) (key :string))
(defcfun "tuya_decode_message" :string (dev tuya-device-t) (buf :pointer) (size :int) (key :string))
(defcfun "tuya_generate_payload" :string (dev tuya-device-t) (cmd :int) (device-id :string) (datapoints :string))
(defcfun "tuya_send" :int (dev tuya-device-t) (buf :pointer) (size :int))
(defcfun "tuya_receive" :int (dev tuya-device-t) (buf :pointer) (maxsize :int) (minsize :int))
(defcfun "tuya_set_value_bool" :string (dev tuya-device-t) (dp :int) (value bool-t))
(defcfun "tuya_set_value_int" :string (dev tuya-device-t) (dp :int) (value :int))
(defcfun "tuya_set_value_string" :string (dev tuya-device-t) (dp :int) (value :string))
(defcfun "tuya_set_value_float" :string (dev tuya-device-t) (dp :int) (value :double))
(defcfun "tuya_turn_on" :string (dev tuya-device-t) (switch-dp :int))
(defcfun "tuya_turn_off" :string (dev tuya-device-t) (switch-dp :int))
(defcfun "tuya_status" :string (dev tuya-device-t))
(defcfun "tuya_heartbeat" :string (dev tuya-device-t))
(defcfun "tuya_free_string" :void (str :string))
(defcfun "tuya_set_device22" :void (dev tuya-device-t) (null-dps-json :string))
(defcfun "tuya_is_device22" bool-t (dev tuya-device-t))

;; ── Constants ──
(defconstant +cmd-u+ 0) (defconstant +cmd-ap-config+ 1) (defconstant +cmd-active+ 2)
(defconstant +cmd-bind+ 3) (defconstant +cmd-rename-gw+ 4) (defconstant +cmd-rename-device+ 5)
(defconstant +cmd-unbind+ 6) (defconstant +cmd-control+ 7) (defconstant +cmd-status+ 8)
(defconstant +cmd-heart-beat+ 9) (defconstant +cmd-dp-query+ 10) (defconstant +cmd-query-wifi+ 11)
(defconstant +cmd-token-bind+ 12) (defconstant +cmd-control-new+ 13) (defconstant +cmd-enable-wifi+ 14)
(defconstant +cmd-dp-query-new+ 16) (defconstant +cmd-scene-execute+ 17) (defconstant +cmd-updatedps+ 18)
(defconstant +cmd-udp-new+ 19) (defconstant +cmd-ap-config-new+ 20) (defconstant +cmd-get-local-time+ 28)
(defconstant +cmd-weather-open+ 32) (defconstant +cmd-weather-data+ 33) (defconstant +cmd-state-upload-syn+ 34)
(defconstant +cmd-state-upload-syn-recv+ 35) (defconstant +cmd-heart-beat-stop+ 37)
(defconstant +cmd-stream-trans+ 38) (defconstant +cmd-get-wifi-status+ 43) (defconstant +cmd-wifi-connect-test+ 44)
(defconstant +cmd-get-mac+ 45) (defconstant +cmd-get-ir-status+ 46) (defconstant +cmd-ir-tx-rx-test+ 47)
(defconstant +cmd-lan-gw-active+ 240) (defconstant +cmd-lan-sub-dev-request+ 241)
(defconstant +cmd-lan-delete-sub-dev+ 242) (defconstant +cmd-lan-report-sub-dev+ 243)
(defconstant +cmd-lan-scene+ 244) (defconstant +cmd-lan-publish-cloud-config+ 245)
(defconstant +cmd-lan-publish-app-config+ 246) (defconstant +cmd-lan-export-app-config+ 247)
(defconstant +cmd-lan-publish-scene-panel+ 248) (defconstant +cmd-lan-remove-gw+ 249)
(defconstant +cmd-lan-check-gw-update+ 250) (defconstant +cmd-lan-gw-update+ 251)
(defconstant +cmd-lan-set-gw-channel+ 252)
(defconstant +proto-v31+ 0) (defconstant +proto-v33+ 1) (defconstant +proto-v34+ 2) (defconstant +proto-v35+ 3)
(defconstant +session-invalid+ 0) (defconstant +session-starting+ 1) (defconstant +session-finalizing+ 2) (defconstant +session-established+ 3)
(defconstant +sock-no-such-host+ 0) (defconstant +sock-no-sock-avail+ 1) (defconstant +sock-failed+ 2)
(defconstant +sock-disconnected+ 3) (defconstant +sock-connecting+ 4) (defconstant +sock-connected+ 5)
(defconstant +sock-ready+ 6) (defconstant +sock-receiving+ 7)
(defconstant +default-port+ 6668) (defconstant +bufsize+ 1024)
(defconstant +default-retry-limit+ 5) (defconstant +default-retry-delay+ 100)

;; ── Convenience wrappers ──
(defun version () (tuya_version))

(defun create (device-id address local-key ver)
  (let ((ptr (%create device-id address local-key ver)))
    (unless (null-pointer-p ptr) ptr)))

(defun alloc (ver)
  (let ((ptr (%alloc ver)))
    (unless (null-pointer-p ptr) ptr)))

(defun destroy (dev) (tuya_destroy dev))

(defun set-credentials (dev id key) (tuya_set_credentials dev id key))
(defun get-device-id (dev) (tuya_get_device_id dev))
(defun get-local-key (dev) (tuya_get_local_key dev))
(defun get-ip (dev) (tuya_get_ip dev))

(defun connect (dev hostname) (tuya_connect dev hostname))
(defun disconnect (dev) (tuya_disconnect dev))
(defun is-connected (dev) (tuya_is_connected dev))
(defun reconnect (dev) (tuya_reconnect dev))

(defun set-retry-limit (dev limit) (tuya_set_retry_limit dev limit))
(defun set-retry-delay (dev ms) (tuya_set_retry_delay dev ms))
(defun get-retry-limit (dev) (tuya_get_retry_limit dev))
(defun get-retry-delay (dev) (tuya_get_retry_delay dev))

(defun negotiate-session (dev key) (tuya_negotiate_session dev key))
(defun negotiate-session-start (dev key) (tuya_negotiate_session_start dev key))
(defun negotiate-session-finalize (dev buf key)
  (tuya_negotiate_session_finalize dev buf (length buf) key))

(defun get-protocol (dev) (tuya_get_protocol dev))
(defun get-session-state (dev) (tuya_get_session_state dev))
(defun get-socket-state (dev) (tuya_get_socket_state dev))
(defun get-last-error (dev) (tuya_get_last_error dev))

(defun set-async-mode (dev flag) (tuya_set_async_mode dev flag))
(defun is-socket-readable (dev) (tuya_is_socket_readable dev))
(defun is-socket-writable (dev) (tuya_is_socket_writable dev))
(defun set-session-ready (dev) (tuya_set_session_ready dev))

(defun set-value-bool (dev dp value) (tuya_set_value_bool dev dp value))
(defun set-value-int (dev dp value) (tuya_set_value_int dev dp value))
(defun set-value-string (dev dp value) (tuya_set_value_string dev dp value))
(defun set-value-float (dev dp value) (tuya_set_value_float dev dp value))

(defun set-value (dev dp value)
  (typecase value
    (boolean (tuya_set_value_bool dev dp (if value 1 0)))
    (integer (tuya_set_value_int dev dp value))
    (float   (tuya_set_value_float dev dp (coerce value 'double-float)))
    (t       (tuya_set_value_string dev dp (princ-to-string value)))))

(defun turn-on (dev &optional (switch-dp 1)) (tuya_turn_on dev switch-dp))
(defun turn-off (dev &optional (switch-dp 1)) (tuya_turn_off dev switch-dp))
(defun status (dev) (tuya_status dev))
(defun heartbeat (dev) (tuya_heartbeat dev))

(defun set-device22 (dev null-dps-json) (tuya_set_device22 dev null-dps-json))
(defun is-device22 (dev) (tuya_is_device22 dev))

;; Low-level
(defun build-message (dev cmd payload key)
  (cffi:with-foreign-object (buf :char +bufsize+)
    (let ((n (tuya_build_message dev buf cmd payload key)))
      (when (> n 0)
        (let ((vec (make-array n :element-type '(unsigned-byte 8))))
          (loop for i below n do (setf (aref vec i) (mem-aref buf :unsigned-char i)))
          vec)))))

(defun decode-message (dev buf key)
  (tuya_decode_message dev buf (length buf) key))

(defun generate-payload (dev cmd device-id datapoints)
  (tuya_generate_payload dev cmd device-id (or datapoints "")))

(defun send-frame (dev buf)
  (tuya_send dev buf (length buf)))

(defun receive-frame (dev &optional (maxsize +bufsize+) (minsize 0))
  (cffi:with-foreign-object (buf :char maxsize)
    (let ((n (tuya_receive dev buf maxsize minsize)))
      (when (> n 0)
        (let ((vec (make-array n :element-type '(unsigned-byte 8))))
          (loop for i below n do (setf (aref vec i) (mem-aref buf :unsigned-char i)))
          vec)))))
