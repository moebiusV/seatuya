#!/usr/bin/env emacs --script
;;; example.el — demonstrate libseatuya via Emacs Lisp

(setq device-id (or (getenv "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(setq local-key (or (getenv "TUYA_LOCAL_KEY") "0123456789abcdef"))
(setq ip        (or (getenv "TUYA_IP")        "192.168.1.100"))
(setq ver       (or (getenv "TUYA_VERSION")    "3.4"))

(load-file "seatuya.el")

(message "seatuya version: %s" (seatuya-version))

(setq dev (seatuya-create device-id ip local-key ver))
(unless dev
  (message "ERROR: Could not create device handle")
  (kill-emacs 1))

(message "Connected: %s" (if (seatuya-is-connected dev) "yes" "no"))
(message "turn_on: %s" (seatuya-turn-on dev 1))
(message "status: %s" (seatuya-status dev))
(message "turn_off: %s" (seatuya-turn-off dev 1))

(seatuya-destroy dev)
(message "Done.")
