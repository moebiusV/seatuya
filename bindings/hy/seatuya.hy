;; seatuya.hy — Hy Lisp FFI bindings for libseatuya
;;
;; Hy compiles to Python AST, so it inherits Python's ctypes.
;; This is a thin Lisp-syntax wrapper around the Python ctypes binding.
;;
;; Usage:
;;   (import seatuya)
;;   (setv dev (seatuya.create device-id "192.168.1.100" local-key "3.4"))
;;   (print (seatuya.turn-on dev 1))
;;   (seatuya.destroy dev)

(import ctypes)
(import os)
(import sys)

(setv _lib-name
  (or (os.environ.get "SEATUYA_LIB")
      (cond [(= sys.platform "darwin") "libseatuya.dylib"]
            [(= "win32" (cut sys.platform 0 3)) "seatuya.dll"]
            [True "libseatuya.so"])))

(setv _lib (ctypes.cdll.LoadLibrary _lib-name))

;; Type aliases
(setv c-bool ctypes.c_bool) (setv c-int ctypes.c_int)
(setv c-double ctypes.c_double) (setv c-char-p ctypes.c_char_p)
(setv c-void-p ctypes.c_void_p)

;; Configure function signatures
(setv _lib.tuya_version.restype c-char-p)

(_lib.tuya_create.argtypes [c-char-p c-char-p c-char-p c-char-p])
(_lib.tuya_create.restype c-void-p)

(_lib.tuya_alloc.argtypes [c-char-p]) (_lib.tuya_alloc.restype c-void-p)
(_lib.tuya_destroy.argtypes [c-void-p]) (_lib.tuya_destroy.restype None)

(_lib.tuya_connect.argtypes [c-void-p c-char-p]) (_lib.tuya_connect.restype c-bool)
(_lib.tuya_disconnect.argtypes [c-void-p])
(_lib.tuya_is_connected.argtypes [c-void-p]) (_lib.tuya_is_connected.restype c-bool)
(_lib.tuya_reconnect.argtypes [c-void-p]) (_lib.tuya_reconnect.restype c-bool)

(_lib.tuya_set_credentials.argtypes [c-void-p c-char-p c-char-p])
(_lib.tuya_get_device_id.argtypes [c-void-p]) (_lib.tuya_get_device_id.restype c-char-p)
(_lib.tuya_get_local_key.argtypes [c-void-p]) (_lib.tuya_get_local_key.restype c-char-p)
(_lib.tuya_get_ip.argtypes [c-void-p]) (_lib.tuya_get_ip.restype c-char-p)

(_lib.tuya_get_protocol.argtypes [c-void-p]) (_lib.tuya_get_protocol.restype c-int)
(_lib.tuya_get_last_error.argtypes [c-void-p]) (_lib.tuya_get_last_error.restype c-int)
(_lib.tuya_set_async_mode.argtypes [c-void-p c-bool])

(_lib.tuya_set_value_bool.argtypes [c-void-p c-int c-bool]) (_lib.tuya_set_value_bool.restype c-char-p)
(_lib.tuya_set_value_int.argtypes [c-void-p c-int c-int]) (_lib.tuya_set_value_int.restype c-char-p)
(_lib.tuya_set_value_string.argtypes [c-void-p c-int c-char-p]) (_lib.tuya_set_value_string.restype c-char-p)
(_lib.tuya_set_value_float.argtypes [c-void-p c-int c-double]) (_lib.tuya_set_value_float.restype c-char-p)

(_lib.tuya_turn_on.argtypes [c-void-p c-int]) (_lib.tuya_turn_on.restype c-char-p)
(_lib.tuya_turn_off.argtypes [c-void-p c-int]) (_lib.tuya_turn_off.restype c-char-p)
(_lib.tuya_status.argtypes [c-void-p]) (_lib.tuya_status.restype c-char-p)
(_lib.tuya_heartbeat.argtypes [c-void-p]) (_lib.tuya_heartbeat.restype c-char-p)
(_lib.tuya_free_string.argtypes [c-char-p])

(_lib.tuya_set_device22.argtypes [c-void-p c-char-p])
(_lib.tuya_is_device22.argtypes [c-void-p]) (_lib.tuya_is_device22.restype c-bool)

;; Retry
(_lib.tuya_set_retry_limit.argtypes [c-void-p c-int])
(_lib.tuya_set_retry_delay.argtypes [c-void-p c-int])
(_lib.tuya_get_retry_limit.argtypes [c-void-p]) (_lib.tuya_get_retry_limit.restype c-int)
(_lib.tuya_get_retry_delay.argtypes [c-void-p]) (_lib.tuya_get_retry_delay.restype c-int)

;; Negotiate session
(_lib.tuya_negotiate_session.argtypes [c-void-p c-char-p]) (_lib.tuya_negotiate_session.restype c-bool)
(_lib.tuya_negotiate_session_start.argtypes [c-void-p c-char-p]) (_lib.tuya_negotiate_session_start.restype c-bool)

;; Constants
(setv CMD-CONTROL 7) (setv CMD-DP-QUERY 10) (setv CMD-HEART-BEAT 9)
(setv CMD-STATUS 8) (setv CMD-CONTROL-NEW 13) (setv CMD-DP-QUERY-NEW 16)
(setv PROTO-V31 0) (setv PROTO-V33 1) (setv PROTO-V34 2) (setv PROTO-V35 3)
(setv DEFAULT-PORT 6668) (setv BUFSIZE 1024)

;; Helpers
(defn _consume [ptr]
  (when ptr
    (setv s (.decode ptr))
    (_lib.tuya_free_string ptr)
    s))

(defn version [] (.decode (_lib.tuya_version)))

(defn create [device-id address local-key ver]
  (_lib.tuya_create (.encode device-id) (.encode address)
                     (.encode local-key) (.encode ver)))

(defn alloc [ver]
  (_lib.tuya_alloc (.encode ver)))

(defn destroy [dev] (_lib.tuya_destroy dev))

(defn set-credentials [dev device-id local-key]
  (_lib.tuya_set_credentials dev (.encode device-id) (.encode local-key)))

(defn get-device-id [dev]
  (setv r (_lib.tuya_get_device_id dev)) (when r (.decode r)))

(defn get-local-key [dev]
  (setv r (_lib.tuya_get_local_key dev)) (when r (.decode r)))

(defn get-ip [dev]
  (setv r (_lib.tuya_get_ip dev)) (when r (.decode r)))

(defn connect [dev hostname] (_lib.tuya_connect dev (.encode hostname)))
(defn disconnect [dev] (_lib.tuya_disconnect dev))
(defn is-connected [dev] (_lib.tuya_is_connected dev))
(defn reconnect [dev] (_lib.tuya_reconnect dev))
(defn negotiate-session [dev key] (_lib.tuya_negotiate_session dev (.encode key)))

(defn get-protocol [dev] (_lib.tuya_get_protocol dev))
(defn get-last-error [dev] (_lib.tuya_get_last_error dev))
(defn set-async-mode [dev flag] (_lib.tuya_set_async_mode dev flag))

(defn set-retry-limit [dev limit] (_lib.tuya_set_retry_limit dev limit))
(defn set-retry-delay [dev ms] (_lib.tuya_set_retry_delay dev ms))
(defn get-retry-limit [dev] (_lib.tuya_get_retry_limit dev))
(defn get-retry-delay [dev] (_lib.tuya_get_retry_delay dev))

(defn set-value [dev dp value]
  (setv ptr
    (cond [(isinstance value bool) (_lib.tuya_set_value_bool dev dp value)]
          [(isinstance value int)  (_lib.tuya_set_value_int dev dp value)]
          [(isinstance value float) (_lib.tuya_set_value_float dev dp value)]
          [True (_lib.tuya_set_value_string dev dp (.encode (str value)))]))
  (_consume ptr))

(defn turn-on [dev [dp 1]] (_consume (_lib.tuya_turn_on dev dp)))
(defn turn-off [dev [dp 1]] (_consume (_lib.tuya_turn_off dev dp)))
(defn status [dev] (_consume (_lib.tuya_status dev)))
(defn heartbeat [dev] (_consume (_lib.tuya_heartbeat dev)))

(defn set-device22 [dev json]
  (_lib.tuya_set_device22 dev (.encode json)))
(defn is-device22 [dev] (_lib.tuya_is_device22 dev))
