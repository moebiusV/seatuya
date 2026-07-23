;; example.shen -- Demonstrate libseatuya via Shen FFI
;;
;; Usage:
;;   (load "seatuya.shen")
;;   (load "example.shen")
;;
;; Or from command line:
;;   shen --load seatuya.shen --eval '(load "example.shen")'
;;
;; Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP, TUYA_VERSION
;; environment variables before running.

(load "seatuya.shen")

(define env-or
  Key Default -> (let X (getenv Key) (if X X Default)))

(set *example-device-id* (env-or "TUYA_DEVICE_ID" "0123456789abcdef01234567"))
(set *example-local-key* (env-or "TUYA_LOCAL_KEY" "0123456789abcdef"))
(set *example-ip*        (env-or "TUYA_IP"        "192.168.1.100"))
(set *example-version*   (env-or "TUYA_VERSION"   "3.4"))

(define run-example
  {--> symbol}
  (do
    (output "seatuya version: ~A~%" (seatuya:version))
    (let Dev (seatuya:create (value *example-device-id*)
                              (value *example-ip*)
                              (value *example-local-key*)
                              (value *example-version*))
      (if (number? Dev)
          (do (output "Connected: ~A~%" (seatuya:is-connected Dev))
              (output "turn_on: ~A~%"  (seatuya:turn-on Dev 1))
              (output "status: ~A~%"   (seatuya:status Dev))
              (output "turn_off: ~A~%" (seatuya:turn-off Dev 1))
              (seatuya:destroy Dev)
              (output "Done.~%"))
          (output "ERROR: Could not create device~%")))))

;; Load the shared library first -- adjust path for your system.
;; SBCL:  (seatuya:load "libseatuya.so")
;; CCL:   (cd (str "(ccl:open-shared-library \"" *libpath* "\")"))
;; ECL:   (cd (str "(ffi:load-foreign-library \"" *libpath* "\")"))

(package example []
  (define main
    {--> symbol}
    (do (seatuya:load (env-or "SEATUYA_LIB" "libseatuya.so"))
        (output "~%--- seatuya Shen Example ---~%~%")
        (run-example)
        $)))
