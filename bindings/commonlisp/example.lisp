#!/usr/bin/env sbcl --script
;;; example.lisp — demonstrate libseatuya via Common Lisp CFFI
;;;
;;; Usage: sbcl --script example.lisp
;;; Also works with: ecl --load example.lisp

(load "seatuya.lisp")

(defparameter device-id
  (or (uiop:getenv "TUYA_DEVICE_ID") "0123456789abcdef01234567"))
(defparameter local-key
  (or (uiop:getenv "TUYA_LOCAL_KEY") "0123456789abcdef"))
(defparameter ip
  (or (uiop:getenv "TUYA_IP") "192.168.1.100"))
(defparameter ver
  (or (uiop:getenv "TUYA_VERSION") "3.4"))

(format t "seatuya version: ~A~%" (seatuya:version))

(defvar dev (seatuya:create device-id ip local-key ver))
(unless dev
  (format *error-output* "ERROR: Could not create device handle~%")
  (uiop:quit 1))

(format t "Connected: ~A~%" (seatuya:is-connected dev))
(format t "turn_on: ~A~%" (seatuya:turn-on dev 1))
(format t "status: ~A~%" (seatuya:status dev))
(format t "turn_off: ~A~%" (seatuya:turn-off dev 1))

(seatuya:destroy dev)
(format t "Done.~%")
