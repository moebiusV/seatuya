;;; seatuya.scm -- Gauche Scheme FFI bindings for libseatuya
;;;
;;; Pure Gauche binding using the built-in c-wrapper module.
;;; Set SEATUYA_LIB to a custom library path.
;;;
;;; Usage:
;;;   (load "./seatuya.scm")
;;;   (define dev (seatuya-open "id" "192.168.1.100" "key" "3.4"))
;;;   (print (seatuya-turn-on dev 1))
;;;   (seatuya-destroy dev)

(use c-wrapper)
(use gauche.uvector)

;; --- Library path from SEATUYA_LIB env or platform default ---

(define *libpath*
  (or (sys-getenv "SEATUYA_LIB")
      (cond ((member (sys-name) '("windows" "mingw32" "cygwin"))
             "seatuya.dll")
            ((equal? (sys-name) "darwin")
             "libseatuya.dylib")
            (else "libseatuya.so"))))

(c-load-library *libpath*)

;; --- Raw C function declarations ---

;; Version
(define-cproc %tuya-version () ::<const-cstring>)

;; Lifecycle
(define-cproc %tuya-create (::<const-cstring> ::<const-cstring> ::<const-cstring> ::<const-cstring>) ::<c-void*>)
(define-cproc %tuya-alloc (::<const-cstring>) ::<c-void*>)
(define-cproc %tuya-destroy (::<c-void*>) ::<void>)

;; Credentials
(define-cproc %tuya-set-credentials (::<c-void*> ::<const-cstring> ::<const-cstring>) ::<void>)
(define-cproc %tuya-get-device-id (::<c-void*>) ::<const-cstring>)
(define-cproc %tuya-get-local-key (::<c-void*>) ::<const-cstring>)
(define-cproc %tuya-get-ip (::<c-void*>) ::<const-cstring>)

;; Connection
(define-cproc %tuya-connect (::<c-void*> ::<const-cstring>) ::<c-int>)
(define-cproc %tuya-disconnect (::<c-void*>) ::<void>)
(define-cproc %tuya-is-connected (::<c-void*>) ::<c-int>)
(define-cproc %tuya-reconnect (::<c-void*>) ::<c-int>)

;; Retry
(define-cproc %tuya-set-retry-limit (::<c-void*> ::<c-int>) ::<void>)
(define-cproc %tuya-set-retry-delay (::<c-void*> ::<c-int>) ::<void>)
(define-cproc %tuya-get-retry-limit (::<c-void*>) ::<c-int>)
(define-cproc %tuya-get-retry-delay (::<c-void*>) ::<c-int>)

;; Session negotiation
(define-cproc %tuya-negotiate-session (::<c-void*> ::<const-cstring>) ::<c-int>)
(define-cproc %tuya-negotiate-session-start (::<c-void*> ::<const-cstring>) ::<c-int>)
(define-cproc %tuya-negotiate-session-finalize (::<c-void*> ::<c-void*> ::<c-int> ::<const-cstring>) ::<c-int>)

;; State queries
(define-cproc %tuya-get-protocol (::<c-void*>) ::<c-int>)
(define-cproc %tuya-get-session-state (::<c-void*>) ::<c-int>)
(define-cproc %tuya-get-socket-state (::<c-void*>) ::<c-int>)
(define-cproc %tuya-get-last-error (::<c-void*>) ::<c-int>)

;; Async mode
(define-cproc %tuya-set-async-mode (::<c-void*> ::<c-int>) ::<void>)
(define-cproc %tuya-is-socket-readable (::<c-void*>) ::<c-int>)
(define-cproc %tuya-is-socket-writable (::<c-void*>) ::<c-int>)
(define-cproc %tuya-set-session-ready (::<c-void*>) ::<c-int>)

;; Message building and decoding
(define-cproc %tuya-build-message (::<c-void*> ::<c-void*> ::<c-int> ::<const-cstring> ::<const-cstring>) ::<c-int>)
(define-cproc %tuya-decode-message (::<c-void*> ::<c-void*> ::<c-int> ::<const-cstring>) ::<c-string>)
(define-cproc %tuya-generate-payload (::<c-void*> ::<c-int> ::<const-cstring> ::<const-cstring>) ::<c-string>)

;; Raw send/receive
(define-cproc %tuya-send (::<c-void*> ::<c-void*> ::<c-int>) ::<c-int>)
(define-cproc %tuya-receive (::<c-void*> ::<c-void*> ::<c-int> ::<c-int>) ::<c-int>)

;; High-level round-trip
(define-cproc %tuya-set-value-bool (::<c-void*> ::<c-int> ::<c-int>) ::<c-string>)
(define-cproc %tuya-set-value-int (::<c-void*> ::<c-int> ::<c-int>) ::<c-string>)
(define-cproc %tuya-set-value-string (::<c-void*> ::<c-int> ::<const-cstring>) ::<c-string>)
(define-cproc %tuya-set-value-float (::<c-void*> ::<c-int> ::<c-double>) ::<c-string>)
(define-cproc %tuya-turn-on (::<c-void*> ::<c-int>) ::<c-string>)
(define-cproc %tuya-turn-off (::<c-void*> ::<c-int>) ::<c-string>)
(define-cproc %tuya-status (::<c-void*>) ::<c-string>)
(define-cproc %tuya-heartbeat (::<c-void*>) ::<c-string>)

;; Memory
(define-cproc %tuya-free-string (::<c-string>) ::<void>)

;; Device22
(define-cproc %tuya-set-device22 (::<c-void*> ::<const-cstring>) ::<void>)
(define-cproc %tuya-is-device22 (::<c-void*>) ::<c-int>)

;; --- Helpers ---

(define (bool c-int) (not (zero? c-int)))

(define (consume ptr)
  (cond ((null-ptr? ptr) #f)
        (else
         (let ((s (x->string ptr)))
           (%tuya-free-string ptr)
           s))))

(define (internal-str ptr)
  (and (not (null-ptr? ptr)) (x->string ptr)))

;; --- Public API ---

;; Version
(define (seatuya-version)
  (x->string (%tuya-version)))

;; Lifecycle
(define (seatuya-open did addr key ver)
  (let ((p (%tuya-create did addr key ver)))
    (and (not (null-ptr? p)) p)))

(define (seatuya-create did addr key ver)
  (seatuya-open did addr key ver))

(define (seatuya-alloc ver)
  (let ((p (%tuya-alloc ver)))
    (and (not (null-ptr? p)) p)))

(define (seatuya-destroy dev) (%tuya-destroy dev))

;; Credentials
(define (seatuya-set-credentials dev did key)
  (%tuya-set-credentials dev did key))

(define (seatuya-get-device-id dev)
  (internal-str (%tuya-get-device-id dev)))

(define (seatuya-get-local-key dev)
  (internal-str (%tuya-get-local-key dev)))

(define (seatuya-get-ip dev)
  (internal-str (%tuya-get-ip dev)))

;; Connection
(define (seatuya-connect dev host)
  (bool (%tuya-connect dev host)))

(define (seatuya-disconnect dev) (%tuya-disconnect dev))
(define (seatuya-is-connected dev) (bool (%tuya-is-connected dev)))
(define (seatuya-reconnect dev) (bool (%tuya-reconnect dev)))

;; Retry
(define (seatuya-set-retry-limit dev n) (%tuya-set-retry-limit dev n))
(define (seatuya-set-retry-delay dev ms) (%tuya-set-retry-delay dev ms))
(define (seatuya-get-retry-limit dev) (%tuya-get-retry-limit dev))
(define (seatuya-get-retry-delay dev) (%tuya-get-retry-delay dev))

;; Session negotiation
(define (seatuya-negotiate-session dev key)
  (bool (%tuya-negotiate-session dev key)))

(define (seatuya-negotiate-session-start dev key)
  (bool (%tuya-negotiate-session-start dev key)))

(define (seatuya-negotiate-session-finalize dev buf size key)
  (bool (%tuya-negotiate-session-finalize dev buf size key)))

;; State queries
(define (seatuya-get-protocol dev) (%tuya-get-protocol dev))
(define (seatuya-get-session-state dev) (%tuya-get-session-state dev))
(define (seatuya-get-socket-state dev) (%tuya-get-socket-state dev))
(define (seatuya-get-last-error dev) (%tuya-get-last-error dev))

;; Async
(define (seatuya-set-async-mode dev flag)
  (%tuya-set-async-mode dev (if flag 1 0)))

(define (seatuya-is-socket-readable dev) (bool (%tuya-is-socket-readable dev)))
(define (seatuya-is-socket-writable dev) (bool (%tuya-is-socket-writable dev)))
(define (seatuya-set-session-ready dev) (bool (%tuya-set-session-ready dev)))

;; Message building and decoding
(define (seatuya-build-message dev buf cmd payload key)
  (%tuya-build-message dev buf cmd payload key))

(define (seatuya-decode-message dev buf size key)
  (consume (%tuya-decode-message dev buf size key)))

(define (seatuya-generate-payload dev cmd dev-id dps)
  (consume (%tuya-generate-payload dev cmd dev-id dps)))

;; Raw send/receive
(define (seatuya-send dev buf size)
  (%tuya-send dev buf size))

(define (seatuya-receive dev buf maxsize minsize)
  (%tuya-receive dev buf maxsize minsize))

;; High-level round-trip
(define (seatuya-set-value-bool dev dp val)
  (consume (%tuya-set-value-bool dev dp (if val 1 0))))

(define (seatuya-set-value-int dev dp val)
  (consume (%tuya-set-value-int dev dp val)))

(define (seatuya-set-value-string dev dp val)
  (consume (%tuya-set-value-string dev dp val)))

(define (seatuya-set-value-float dev dp val)
  (consume (%tuya-set-value-float dev dp val)))

(define (seatuya-turn-on dev (dp 1))
  (consume (%tuya-turn-on dev dp)))

(define (seatuya-turn-off dev (dp 1))
  (consume (%tuya-turn-off dev dp)))

(define (seatuya-status dev)
  (consume (%tuya-status dev)))

(define (seatuya-heartbeat dev)
  (consume (%tuya-heartbeat dev)))

;; Type-aware dispatcher
(define (seatuya-set-value dev dp value)
  (cond ((boolean? value) (seatuya-set-value-bool dev dp value))
        ((integer? value) (seatuya-set-value-int dev dp value))
        ((real? value)    (seatuya-set-value-float dev dp (exact->inexact value)))
        (else             (seatuya-set-value-string dev dp (x->string value)))))

;; Device22
(define (seatuya-set-device22 dev json)
  (if json
      (%tuya-set-device22 dev json)
      (%tuya-set-device22 dev "")))  ;; empty string, not NULL

(define (seatuya-is-device22 dev)
  (bool (%tuya-is-device22 dev)))

;; --- Constants (43 command types) ---

(define CMD-UDP                       0)
(define CMD-AP-CONFIG                 1)
(define CMD-ACTIVE                    2)
(define CMD-BIND                      3)
(define CMD-RENAME-GW                 4)
(define CMD-RENAME-DEVICE             5)
(define CMD-UNBIND                    6)
(define CMD-CONTROL                   7)
(define CMD-STATUS                    8)
(define CMD-HEART-BEAT                9)
(define CMD-DP-QUERY                  10)
(define CMD-QUERY-WIFI                11)
(define CMD-TOKEN-BIND                12)
(define CMD-CONTROL-NEW               13)
(define CMD-ENABLE-WIFI               14)
(define CMD-DP-QUERY-NEW              16)
(define CMD-SCENE-EXECUTE             17)
(define CMD-UPDATEDPS                 18)
(define CMD-UDP-NEW                   19)
(define CMD-AP-CONFIG-NEW             20)
(define CMD-GET-LOCAL-TIME            28)
(define CMD-WEATHER-OPEN              32)
(define CMD-WEATHER-DATA              33)
(define CMD-STATE-UPLOAD-SYN          34)
(define CMD-STATE-UPLOAD-SYN-RECV     35)
(define CMD-HEART-BEAT-STOP           37)
(define CMD-STREAM-TRANS              38)
(define CMD-GET-WIFI-STATUS           43)
(define CMD-WIFI-CONNECT-TEST         44)
(define CMD-GET-MAC                   45)
(define CMD-GET-IR-STATUS             46)
(define CMD-IR-TX-RX-TEST             47)
(define CMD-LAN-GW-ACTIVE             240)
(define CMD-LAN-SUB-DEV-REQUEST       241)
(define CMD-LAN-DELETE-SUB-DEV        242)
(define CMD-LAN-REPORT-SUB-DEV        243)
(define CMD-LAN-SCENE                 244)
(define CMD-LAN-PUBLISH-CLOUD-CONFIG  245)
(define CMD-LAN-PUBLISH-APP-CONFIG    246)
(define CMD-LAN-EXPORT-APP-CONFIG     247)
(define CMD-LAN-PUBLISH-SCENE-PANEL   248)
(define CMD-LAN-REMOVE-GW             249)
(define CMD-LAN-CHECK-GW-UPDATE       250)
(define CMD-LAN-GW-UPDATE             251)
(define CMD-LAN-SET-GW-CHANNEL        252)

;; Protocol versions
(define PROTO-V31 0)
(define PROTO-V33 1)
(define PROTO-V34 2)
(define PROTO-V35 3)

;; Session states
(define SESSION-INVALID      0)
(define SESSION-STARTING     1)
(define SESSION-FINALIZING   2)
(define SESSION-ESTABLISHED  3)

;; Socket states
(define SOCK-NO-SUCH-HOST   0)
(define SOCK-NO-SOCK-AVAIL  1)
(define SOCK-FAILED         2)
(define SOCK-DISCONNECTED   3)
(define SOCK-CONNECTING     4)
(define SOCK-CONNECTED      5)
(define SOCK-READY          6)
(define SOCK-RECEIVING      7)

;; Misc
(define DEFAULT-PORT 6668)
(define BUFSIZE 1024)
