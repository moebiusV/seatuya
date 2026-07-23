;;; seatuya.scm — Gauche Scheme FFI bindings for libseatuya
;;;
;;; Pure Gauche binding using the built-in c-wrapper module.
;;;   (use c-wrapper)
;;;
;;; Usage:
;;;   (load "./seatuya.scm")
;;;   (define dev (seatuya-create "id" "192.168.1.100" "key" "3.4"))
;;;   (print (seatuya-turn-on dev 1))
;;;   (seatuya-destroy dev)

(use c-wrapper)
(use gauche.uvector)

;; Library path
(define *lib* (or (sys-getenv "SEATUYA_LIB") "libseatuya.so"))

;; Open library
(c-load-library *lib*)

;; ── C function declarations ──
(define-cproc tuya-version () ::<const-cstring>)
(define-cproc tuya-create (::<const-cstring> ::<const-cstring> ::<const-cstring> ::<const-cstring>) ::<c-void*>)
(define-cproc tuya-alloc (::<const-cstring>) ::<c-void*>)
(define-cproc tuya-destroy (::<c-void*>) ::<void>)
(define-cproc tuya-set-credentials (::<c-void*> ::<const-cstring> ::<const-cstring>) ::<void>)
(define-cproc tuya-get-device-id (::<c-void*>) ::<const-cstring>)
(define-cproc tuya-get-local-key (::<c-void*>) ::<const-cstring>)
(define-cproc tuya-get-ip (::<c-void*>) ::<const-cstring>)
(define-cproc tuya-connect (::<c-void*> ::<const-cstring>) ::<c-int>)
(define-cproc tuya-disconnect (::<c-void*>) ::<void>)
(define-cproc tuya-is-connected (::<c-void*>) ::<c-int>)
(define-cproc tuya-reconnect (::<c-void*>) ::<c-int>)
(define-cproc tuya-negotiate-session (::<c-void*> ::<const-cstring>) ::<c-int>)
(define-cproc tuya-get-protocol (::<c-void*>) ::<c-int>)
(define-cproc tuya-get-session-state (::<c-void*>) ::<c-int>)
(define-cproc tuya-get-socket-state (::<c-void*>) ::<c-int>)
(define-cproc tuya-get-last-error (::<c-void*>) ::<c-int>)
(define-cproc tuya-set-async-mode (::<c-void*> ::<c-int>) ::<void>)
(define-cproc tuya-set-value-bool (::<c-void*> ::<c-int> ::<c-int>) ::<c-string>)
(define-cproc tuya-set-value-int (::<c-void*> ::<c-int> ::<c-int>) ::<c-string>)
(define-cproc tuya-set-value-string (::<c-void*> ::<c-int> ::<const-cstring>) ::<c-string>)
(define-cproc tuya-set-value-float (::<c-void*> ::<c-int> ::<c-double>) ::<c-string>)
(define-cproc tuya-turn-on (::<c-void*> ::<c-int>) ::<c-string>)
(define-cproc tuya-turn-off (::<c-void*> ::<c-int>) ::<c-string>)
(define-cproc tuya-status (::<c-void*>) ::<c-string>)
(define-cproc tuya-heartbeat (::<c-void*>) ::<c-string>)
(define-cproc tuya-free-string (::<c-string>) ::<void>)
(define-cproc tuya-set-device22 (::<c-void*> ::<const-cstring>) ::<void>)
(define-cproc tuya-is-device22 (::<c-void*>) ::<c-int>)

;; ── Constants ──
(define +cmd-control+ 7) (define +cmd-dp-query+ 10) (define +cmd-heart-beat+ 9)
(define +cmd-status+ 8) (define +cmd-control-new+ 13) (define +cmd-dp-query-new+ 16)
(define +default-port+ 6668) (define +bufsize+ 1024)

;; ── Convenience wrappers ──
(define (seatuya-version) (x->string (tuya-version)))

(define (seatuya-create did addr key ver)
  (let ((p (tuya-create did addr key ver)))
    (and (not (null-ptr? p)) p)))

(define (seatuya-alloc ver)
  (let ((p (tuya-alloc ver)))
    (and (not (null-ptr? p)) p)))

(define (seatuya-destroy dev) (tuya-destroy dev))

(define (seatuya-set-credentials dev did key) (tuya-set-credentials dev did key))
(define (seatuya-get-device-id dev) (x->string (tuya-get-device-id dev)))
(define (seatuya-get-local-key dev) (x->string (tuya-get-local-key dev)))
(define (seatuya-get-ip dev) (x->string (tuya-get-ip dev)))

(define (seatuya-connect dev host) (not (zero? (tuya-connect dev host))))
(define (seatuya-disconnect dev) (tuya-disconnect dev))
(define (seatuya-is-connected dev) (not (zero? (tuya-is-connected dev))))
(define (seatuya-reconnect dev) (not (zero? (tuya-reconnect dev))))

(define (seatuya-get-protocol dev) (tuya-get-protocol dev))
(define (seatuya-get-last-error dev) (tuya-get-last-error dev))
(define (seatuya-set-async-mode dev flag) (tuya-set-async-mode dev (if flag 1 0)))

(define (_consume p)
  (if (null-ptr? p) #f
      (let ((s (x->string p)))
        (tuya-free-string p) s)))

(define (seatuya-set-value dev dp value)
  (cond
   ((boolean? value) (_consume (tuya-set-value-bool dev dp (if value 1 0))))
   ((integer? value) (_consume (tuya-set-value-int dev dp value)))
   ((real? value)    (_consume (tuya-set-value-float dev dp (exact->inexact value))))
   (else             (_consume (tuya-set-value-string dev dp (x->string value))))))

(define (seatuya-turn-on dev (dp 1)) (_consume (tuya-turn-on dev dp)))
(define (seatuya-turn-off dev (dp 1)) (_consume (tuya-turn-off dev dp)))
(define (seatuya-status dev) (_consume (tuya-status dev)))
(define (seatuya-heartbeat dev) (_consume (tuya-heartbeat dev)))

(define (seatuya-set-device22 dev json) (tuya-set-device22 dev json))
(define (seatuya-is-device22 dev) (not (zero? (tuya-is-device22 dev))))
