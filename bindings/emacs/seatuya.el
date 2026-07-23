;;; seatuya.el — Emacs Lisp FFI bindings for libseatuya
;;;
;;; Emacs 28+ has native module support via emacs-module.h.  This
;;; binding ships a small C module (seatuya_module.c) that exports
;;; all functions as Emacs primitives.  Once compiled, load with:
;;;
;;;   (load-file "seatuya.el")
;;;   (require 'seatuya-module)
;;;
;;; Or use the pure-Lisp dynamic FFI via:
;;;   M-x package-install RET emacs-ffi RET
;;;
;;; Usage:
;;;   (setq dev (seatuya-create device-id "192.168.1.100" local-key "3.4"))
;;;   (message "%s" (seatuya-turn-on dev 1))
;;;   (seatuya-destroy dev)

(require 'ffi nil t)  ; emacs-ffi package, if installed

(defvar seatuya-lib
  (or (getenv "SEATUYA_LIB")
      (cond ((eq system-type 'darwin) "libseatuya.dylib")
            ((eq system-type 'windows-nt) "seatuya.dll")
            (t "libseatuya.so"))))

(defvar seatuya--loaded nil)

(defun seatuya--ensure ()
  "Load the shared library if not already loaded."
  (unless seatuya--loaded
    (if (featurep 'ffi)
        ;; Use emacs-ffi for pure-Lisp dynamic FFI
        (progn
          (ffi-load-library seatuya-lib)
          (setq seatuya--loaded 'ffi))
      ;; Fallback: use the native module approach
      (require 'seatuya-module)
      (setq seatuya--loaded 'module))))

;; ── Function wrappers ──
(defmacro seatuya--defun (name return-type args &rest body)
  "Define a seatuya function wrapper."
  `(defun ,(intern (concat "seatuya-" (symbol-name name))) ,args
     (seatuya--ensure)
     (cond ((eq seatuya--loaded 'ffi)
            (ffi-call ,(format "tuya_%s" (symbol-name name)) ,@args))
           ((eq seatuya--loaded 'module)
            (,(intern (concat "seatuya-module-" (symbol-name name))) ,@args)))))

(defun seatuya-version ()
  "Return the library version string."
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_version"))
        ((featurep 'seatuya-module) (seatuya-module-version))))

(defun seatuya-create (device-id address local-key version)
  "Create a device handle.  Returns an opaque integer (C pointer)."
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi)
         (or (ffi-call "tuya_create" device-id address local-key version) nil))
        ((featurep 'seatuya-module)
         (or (seatuya-module-create device-id address local-key version) nil))))

(defun seatuya-destroy (dev)
  "Destroy a device handle."
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_destroy" dev))
        ((featurep 'seatuya-module) (seatuya-module-destroy dev))))

(defun seatuya-connect (dev hostname)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (/= 0 (ffi-call "tuya_connect" dev hostname)))
        ((featurep 'seatuya-module) (> (seatuya-module-connect dev hostname) 0))))

(defun seatuya-disconnect (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_disconnect" dev))
        ((featurep 'seatuya-module) (seatuya-module-disconnect dev))))

(defun seatuya-is-connected (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (/= 0 (ffi-call "tuya_is_connected" dev)))
        ((featurep 'seatuya-module) (> (seatuya-module-is-connected dev) 0))))

(defun seatuya-reconnect (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (/= 0 (ffi-call "tuya_reconnect" dev)))
        ((featurep 'seatuya-module) (> (seatuya-module-reconnect dev) 0))))

(defun seatuya-set-credentials (dev device-id local-key)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_set_credentials" dev device-id local-key))
        ((featurep 'seatuya-module) (seatuya-module-set-credentials dev device-id local-key))))

(defun seatuya-get-device-id (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_get_device_id" dev))
        ((featurep 'seatuya-module) (seatuya-module-get-device-id dev))))

(defun seatuya-get-local-key (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_get_local_key" dev))
        ((featurep 'seatuya-module) (seatuya-module-get-local-key dev))))

(defun seatuya-get-ip (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_get_ip" dev))
        ((featurep 'seatuya-module) (seatuya-module-get-ip dev))))

(defun seatuya-turn-on (dev dp)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_turn_on" dev dp))
        ((featurep 'seatuya-module) (seatuya-module-turn-on dev dp))))

(defun seatuya-turn-off (dev dp)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_turn_off" dev dp))
        ((featurep 'seatuya-module) (seatuya-module-turn-off dev dp))))

(defun seatuya-status (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_status" dev))
        ((featurep 'seatuya-module) (seatuya-module-status dev))))

(defun seatuya-heartbeat (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_heartbeat" dev))
        ((featurep 'seatuya-module) (seatuya-module-heartbeat dev))))

(defun seatuya-set-value (dev dp value)
  "Set a DP value, auto-detecting the type."
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi)
         (cond ((booleanp value) (ffi-call "tuya_set_value_bool" dev dp (if value 1 0)))
               ((integerp value) (ffi-call "tuya_set_value_int" dev dp value))
               ((floatp value)   (ffi-call "tuya_set_value_float" dev dp value))
               (t                (ffi-call "tuya_set_value_string" dev dp (format "%s" value)))))
        ((featurep 'seatuya-module)
         (seatuya-module-set-value dev dp value))))

(defun seatuya-set-device22 (dev json)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_set_device22" dev json))
        ((featurep 'seatuya-module) (seatuya-module-set-device22 dev json))))

(defun seatuya-is-device22 (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (/= 0 (ffi-call "tuya_is_device22" dev)))
        ((featurep 'seatuya-module) (> (seatuya-module-is-device22 dev) 0))))

(defun seatuya-get-protocol (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_get_protocol" dev))
        ((featurep 'seatuya-module) (seatuya-module-get-protocol dev))))

(defun seatuya-get-last-error (dev)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_get_last_error" dev))
        ((featurep 'seatuya-module) (seatuya-module-get-last-error dev))))

(defun seatuya-set-async-mode (dev flag)
  (seatuya--ensure)
  (cond ((eq seatuya--loaded 'ffi) (ffi-call "tuya_set_async_mode" dev (if flag 1 0)))
        ((featurep 'seatuya-module) (seatuya-module-set-async-mode dev flag))))

;; ── Constants ──
(defconst seatuya-cmd-control 7)
(defconst seatuya-cmd-dp-query 10)
(defconst seatuya-cmd-heart-beat 9)
(defconst seatuya-cmd-status 8)
(defconst seatuya-cmd-control-new 13)
(defconst seatuya-cmd-dp-query-new 16)
(defconst seatuya-proto-v31 0)
(defconst seatuya-proto-v33 1)
(defconst seatuya-proto-v34 2)
(defconst seatuya-proto-v35 3)
(defconst seatuya-default-port 6668)
(defconst seatuya-bufsize 1024)

(provide 'seatuya)
