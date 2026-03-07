#!/usr/bin/env newlisp
;
; seatuya-wizard.lsp — Setup wizard for Tuya devices (clone of tinytuya wizard).
;
; Connects to the Tuya Cloud API to fetch all registered devices and
; their local keys, then optionally scans the local network via UDP
; broadcast to discover device IP addresses.
;
; Requires libtls for HTTPS (via libtls.lsp module).
;
; Usage:
;   seatuya-wizard.lsp [options]
;
; Options:
;   -k KEY      Tuya Cloud API Key
;   -s SECRET   Tuya Cloud API Secret
;   -r REGION   API region (us, eu, cn, in, sg, us-e, eu-w)
;   -i DEVID    Any registered Device ID (used to pull full list)
;   -c FILE     Config file to load/save credentials (default: tinytuya.json)
;   -o FILE     Device list output file (default: devices.json)
;   -t SECS     UDP scan timeout (default: 8)
;   -N          No cloud — skip cloud fetch, only scan local network
;   -y          Assume yes to all prompts
;

(load (string (or (env "SEATUYA_LSP_DIR") (real-path "..")) "/seatuya.lsp"))
(load (string (or (env "SEATUYA_LSP_DIR") (real-path "..")) "/libtls.lsp"))

;; Check that libtls loaded successfully
(unless tls:available?
  (tls:install-hint)
  (println "Alternatively, use the C version: seatuya-wizard or seatuya-wizard-openssl")
  (exit 1))

;; ----------------------------------------------------------------
;;  Minimal JSON helpers
;; ----------------------------------------------------------------

(define (json-get-string json key)
  "Extract a string value for key from JSON. Returns string or nil."
  (let (needle (string "\"" key "\"")
        pos (find needle json))
    (when pos
      (let (p (+ pos (length needle)))
        (while (and (< p (length json))
                    (find (json p) '(" " "\t" ":")))
          (inc p))
        (when (and (< p (length json)) (= (json p) "\""))
          (inc p)
          (let (end (find "\"" (slice json p)))
            (when end
              (slice json p end))))))))

(define (json-get-bool json key)
  "Check if key has value true in JSON."
  (let (needle (string "\"" key "\"")
        pos (find needle json))
    (when pos
      (let (p (+ pos (length needle)))
        (while (and (< p (length json))
                    (find (json p) '(" " "\t" ":")))
          (inc p))
        (and (< (+ p 3) (length json))
             (= (slice json p 4) "true"))))))

(define (json-get-result-array json)
  "Return the position of the '[' starting the result array, or nil."
  (let (pos (find "\"result\"" json))
    (when pos
      (let (p (+ pos 8))
        (while (and (< p (length json)) (!= (json p) "["))
          (inc p))
        (when (and (< p (length json)) (= (json p) "["))
          p)))))

(define (json-skip-object json pos)
  "Skip past one JSON object starting at pos. Returns position after '}'."
  (when (= (json pos) "{")
    (let (depth 1 in-str nil p (+ pos 1))
      (while (and (< p (length json)) (> depth 0))
        (if in-str
          (begin
            (if (= (json p) "\\") (inc p)
                (= (json p) "\"") (setq in-str nil)))
          (begin
            (if (= (json p) "\"") (setq in-str true)
                (= (json p) "{") (inc depth)
                (= (json p) "}") (dec depth))))
        (inc p))
      p)))

;; ----------------------------------------------------------------
;;  Tuya Cloud API region mapping
;; ----------------------------------------------------------------

(define (region-to-host region)
  (cond
    ((or (= region "us") (= region "az"))   "openapi.tuyaus.com")
    ((or (= region "us-e") (= region "ue")) "openapi-ueaz.tuyaus.com")
    ((= region "eu")                         "openapi.tuyaeu.com")
    ((or (= region "eu-w") (= region "we")) "openapi-weaz.tuyaeu.com")
    ((or (= region "cn") (= region "ay"))   "openapi.tuyacn.com")
    ((= region "in")                         "openapi.tuyain.com")
    ((= region "sg")                         "openapi-sg.iotbing.com")
    (true                                    "openapi.tuyaus.com")))

;; ----------------------------------------------------------------
;;  Tuya Cloud API client
;; ----------------------------------------------------------------

(define (tuya-api-call cloud method uri body)
  (let (path (string "/v1.0/" uri)
        host (cloud "host"))

    ;; Millisecond timestamp
    (let (ts (string (int (* (date-value) 1000))))

      ;; String to sign
      (let (content-hash (crypto:sha256 (or body ""))
            sign-str (string (cloud "api_key")
                             (if (cloud "token") (cloud "token") "")
                             ts
                             method "\n"
                             content-hash "\n"
                             "\n"
                             path))

        ;; HMAC-SHA256
        (let (hmac-raw (crypto:hmac-sha256 (cloud "api_secret") sign-str)
              signature (crypto:to-upper-hex hmac-raw))

          ;; Headers
          (let (headers (list
                  (list "client_id" (cloud "api_key"))
                  (list "sign" signature)
                  (list "t" ts)
                  (list "sign_method" "HMAC-SHA256")
                  (list "mode" "cors")))
            (when (and body (!= body ""))
              (push (list "Content-type" "application/json") headers -1))

            (catch (tls:request-json host method path headers body))))))))

(define (tuya-get-token cloud)
  (setf (cloud "token") nil)
  (let (resp (tuya-api-call cloud "GET" "token?grant_type=1" nil))
    (unless resp
      (println "error: failed to connect to Tuya Cloud")
      (throw nil))
    (unless (json-get-bool resp "success")
      (println "error: token request failed: " (or (json-get-string resp "msg") "unknown"))
      (throw nil))
    (let (tok (json-get-string resp "access_token"))
      (unless tok
        (println "error: no access_token in response")
        (throw nil))
      (setf (cloud "token") tok)
      true)))

(define (tuya-get-uid cloud device-id)
  (let (resp (tuya-api-call cloud "GET" (string "devices/" device-id) nil))
    (unless resp (throw nil))
    (unless (json-get-bool resp "success")
      (println "error: get device failed: " (or (json-get-string resp "msg") "unknown"))
      (throw nil))
    (json-get-string resp "uid")))

(define (tuya-get-devices cloud)
  "Fetch all devices. Returns list of assoc-lists or nil."
  (let (uid (tuya-get-uid cloud (cloud "api_device_id")))
    (unless uid
      (println "error: could not get UID for device " (cloud "api_device_id"))
      (throw nil))
    (let (resp (tuya-api-call cloud "GET" (string "users/" uid "/devices") nil))
      (unless resp (throw nil))
      (unless (json-get-bool resp "success")
        (println "error: get devices failed: " (or (json-get-string resp "msg") "unknown"))
        (throw nil))
      (let (arr-pos (json-get-result-array resp))
        (unless arr-pos '())
        (let (devices '() p (+ arr-pos 1))
          (while (< p (length resp))
            (while (and (< p (length resp)) (!= (resp p) "{"))
              (inc p))
            (when (>= p (length resp)) (throw devices))
            (let (end (json-skip-object resp p))
              (unless end (throw devices))
              (let (obj (slice resp p (- end p))
                    dev (list
                      (list "id"         (or (json-get-string obj "id") ""))
                      (list "name"       (or (json-get-string obj "name") ""))
                      (list "key"        (or (json-get-string obj "local_key") ""))
                      (list "product_id" (or (json-get-string obj "product_id") ""))
                      (list "sub"        (json-get-bool obj "sub"))
                      (list "ip"         "")
                      (list "version"    "")))
                (when (!= (lookup "id" dev) "")
                  (push dev devices -1)))
              (setq p end)))
          devices)))))

;; ----------------------------------------------------------------
;;  UDP discovery
;; ----------------------------------------------------------------

(constant 'UDP_PORT 6666)

(define (extract-json-from-frame data)
  (let (start (find "{" data)
        end   (find "}" data -1))
    (when (and start end (>= end start))
      (slice data start (+ (- end start) 1)))))

(define (udp-discover devices timeout)
  "Scan for devices on the local network. Updates IP/version in devices list.
   Returns number of devices found."
  (let (sock (net-listen UDP_PORT "" "udp"))
    (unless sock
      (println "error: cannot bind UDP port " UDP_PORT)
      (throw 0))
    (println (format "\nScanning local network on UDP port %d (%ds)..." UDP_PORT timeout))
    (let (deadline (+ (time-of-day) (* timeout 1000))
          found 0)
      (while (< (time-of-day) deadline)
        (when (net-select sock "r" 1000000)
          (let (result (net-receive-from sock 1024))
            (when result
              (let (data     (result 1)
                    sender   (result 0)
                    json-str (extract-json-from-frame data))
                (when json-str
                  (let (info (json-parse json-str))
                    (when (and info (lookup "gwId" info))
                      (let (gw-id (lookup "gwId" info)
                            ip    (or (lookup "ip" info) sender)
                            ver   (or (lookup "version" info) "?"))
                        (dolist (d devices)
                          (when (and (= (lookup "id" d) gw-id)
                                     (= (lookup "ip" d) ""))
                            (setf (assoc "ip" d) (list "ip" ip))
                            (when (!= ver "?")
                              (setf (assoc "version" d) (list "version" ver)))
                            (inc found)
                            (println (format "  %-40s %s  v%s"
                                            (lookup "name" d) ip ver)))))))))))))
      (net-close sock)
      (println (format "  %d device(s) found on local network." found))
      found)))

(define (udp-discover-standalone timeout)
  "Scan for devices with no cloud list. Returns list of device assoc-lists."
  (let (sock (net-listen UDP_PORT "" "udp"))
    (unless sock
      (println "error: cannot bind UDP port " UDP_PORT)
      (throw '()))
    (println (format "\nScanning local network on UDP port %d (%ds)..." UDP_PORT timeout))
    (let (deadline (+ (time-of-day) (* timeout 1000))
          devices '()
          seen    '())
      (while (< (time-of-day) deadline)
        (when (net-select sock "r" 1000000)
          (let (result (net-receive-from sock 1024))
            (when result
              (let (data     (result 1)
                    sender   (result 0)
                    json-str (extract-json-from-frame data))
                (when json-str
                  (let (info (json-parse json-str))
                    (when (and info (lookup "gwId" info))
                      (let (gw-id (lookup "gwId" info))
                        (unless (member gw-id seen)
                          (push gw-id seen)
                          (let (ip  (or (lookup "ip" info) sender)
                                ver (or (lookup "version" info) "?"))
                            (push (list
                                    (list "id" gw-id)
                                    (list "name" "")
                                    (list "key" "")
                                    (list "product_id" "")
                                    (list "sub" nil)
                                    (list "ip" ip)
                                    (list "version" ver))
                                  devices -1)
                            (println (format "  %s  id=%s  v=%s" ip gw-id ver)))))))))))))
      (net-close sock)
      (println (format "  %d device(s) found." (length devices)))
      devices)))

;; ----------------------------------------------------------------
;;  Config file I/O
;; ----------------------------------------------------------------

(define (load-config path)
  "Load JSON config file. Returns assoc-list or empty list."
  (if (not (file? path)) '()
    (let (buf (read-file path))
      (list
        (list "api_key"       (or (json-get-string buf "apiKey") ""))
        (list "api_secret"    (or (json-get-string buf "apiSecret") ""))
        (list "api_region"    (or (json-get-string buf "apiRegion") ""))
        (list "api_device_id" (or (json-get-string buf "apiDeviceID") ""))
        (list "token"         nil)
        (list "host"          nil)))))

(define (save-config path cloud)
  (let (fp (open path "w"))
    (unless fp
      (println "error: cannot write " path)
      (throw nil))
    (write fp "{\n")
    (write fp (format "    \"apiKey\": \"%s\",\n" (cloud "api_key")))
    (write fp (format "    \"apiSecret\": \"%s\",\n" (cloud "api_secret")))
    (write fp (format "    \"apiRegion\": \"%s\",\n" (cloud "api_region")))
    (write fp (format "    \"apiDeviceID\": \"%s\"\n" (cloud "api_device_id")))
    (write fp "}\n")
    (close fp)
    (println ">> Configuration saved to " path)))

(define (save-devices path devices)
  (let (fp (open path "w"))
    (unless fp
      (println "error: cannot write " path)
      (throw nil))
    (write fp "[\n")
    (dolist (d devices)
      (write fp "    {\n")
      (write fp (format "        \"id\": \"%s\",\n" (lookup "id" d)))
      (write fp (format "        \"name\": \"%s\",\n" (lookup "name" d)))
      (write fp (format "        \"key\": \"%s\",\n" (lookup "key" d)))
      (write fp (format "        \"product_id\": \"%s\",\n" (lookup "product_id" d)))
      (write fp (format "        \"sub\": %s" (if (lookup "sub" d) "true" "false")))
      (when (!= (lookup "ip" d) "")
        (write fp (format ",\n        \"ip\": \"%s\"" (lookup "ip" d)))
        (when (!= (lookup "version" d) "")
          (write fp (format ",\n        \"version\": \"%s\"" (lookup "version" d)))))
      (write fp (string "\n    }" (if (< $idx (- (length devices) 1)) "," "") "\n")))
    (write fp "]\n")
    (close fp)
    (println (format ">> %d device(s) saved to %s" (length devices) path))))

;; ----------------------------------------------------------------
;;  User interaction
;; ----------------------------------------------------------------

(define (prompt-string msg dflt)
  (if (and dflt (!= dflt ""))
    (print msg " [" dflt "]: ")
    (print msg ": "))
  (let (line (read-line))
    (if (!= line "") line (or dflt ""))))

(define (prompt-yn msg dflt)
  (print msg (if dflt " [Y/n]: " " [y/N]: "))
  (let (line (read-line))
    (if (= line "") dflt
        (or (= (lower-case (slice line 0 1)) "y")))))

;; ----------------------------------------------------------------
;;  Argument parsing
;; ----------------------------------------------------------------

(define (parse-args)
  (let (args   (rest (main-args))
        result (list '("api_key" "")
                     '("api_secret" "")
                     '("api_region" "")
                     '("api_device_id" "")
                     '("config_file" "tinytuya.json")
                     '("device_file" "devices.json")
                     '("scan_timeout" 8)
                     '("no_cloud" nil)
                     '("assume_yes" nil)
                     '("token" nil)
                     '("host" nil))
        i 0)
    (while (< i (length args))
      (let (a (args i))
        (cond
          ((= a "-k") (inc i) (setf (assoc "api_key" result) (list "api_key" (args i))))
          ((= a "-s") (inc i) (setf (assoc "api_secret" result) (list "api_secret" (args i))))
          ((= a "-r") (inc i) (setf (assoc "api_region" result) (list "api_region" (args i))))
          ((= a "-i") (inc i) (setf (assoc "api_device_id" result) (list "api_device_id" (args i))))
          ((= a "-c") (inc i) (setf (assoc "config_file" result) (list "config_file" (args i))))
          ((= a "-o") (inc i) (setf (assoc "device_file" result) (list "device_file" (args i))))
          ((= a "-t") (inc i) (setf (assoc "scan_timeout" result) (list "scan_timeout" (int (args i)))))
          ((= a "-N") (setf (assoc "no_cloud" result) (list "no_cloud" true)))
          ((= a "-y") (setf (assoc "assume_yes" result) (list "assume_yes" true)))
          ((or (= a "-h") (= a "--help"))
           (println "Usage: " ((main-args) 0) " [options]"
                    "\n"
                    "\nTuya device setup wizard (clone of tinytuya wizard)."
                    "\nFetches device list and local keys from the Tuya Cloud API,"
                    "\nthen scans the local network for device IP addresses."
                    "\n"
                    "\nOptions:"
                    "\n  -k KEY      API Key"
                    "\n  -s SECRET   API Secret"
                    "\n  -r REGION   Region (us, eu, cn, in, sg, us-e, eu-w)"
                    "\n  -i DEVID    Any registered Device ID"
                    "\n  -c FILE     Credentials file  (default: tinytuya.json)"
                    "\n  -o FILE     Device list output (default: devices.json)"
                    "\n  -t SECS     UDP scan timeout   (default: 8)"
                    "\n  -N          No cloud (scan only)"
                    "\n  -y          Assume yes")
           (exit 0))
          (true
           (println "unknown option: " a)
           (exit 1))))
      (inc i))
    result))

;; ----------------------------------------------------------------
;;  Main
;; ----------------------------------------------------------------

(define (main)
  (let (cloud       (parse-args)
        config-file (lookup "config_file" cloud)
        device-file (lookup "device_file" cloud)
        timeout     (lookup "scan_timeout" cloud)
        no-cloud    (lookup "no_cloud" cloud)
        assume-yes  (lookup "assume_yes" cloud))

    (println (format "seatuya setup wizard [%s]\n" (tuya:version)))

    ;; Load saved credentials
    (let (saved (load-config config-file))
      (when saved
        (dolist (pair saved)
          (when (and (lookup (pair 0) cloud)
                     (= (lookup (pair 0) cloud) "")
                     (!= (pair 1) "")
                     (pair 1))
            (setf (assoc (pair 0) cloud) pair)))))

    (let (devices '()
          device-count 0)

      (if no-cloud
        ;; No-cloud mode
        (begin
          (setq devices (catch (udp-discover-standalone timeout) 'err))
          (when (list? devices)
            (setq device-count (length devices))
            (when (> device-count 0)
              (save-devices device-file devices))))

        ;; Cloud mode
        (begin
          (let (have-creds (and (!= (cloud "api_key") "")
                               (!= (cloud "api_secret") "")
                               (!= (cloud "api_region") "")))

            (when (and have-creds (not assume-yes))
              (println "    Existing settings:")
              (println "        API Key    = " (cloud "api_key"))
              (println "        API Secret = " (cloud "api_secret"))
              (println "        Region     = " (cloud "api_region"))
              (when (!= (cloud "api_device_id") "")
                (println "        Device ID  = " (cloud "api_device_id")))
              (println)
              (unless (prompt-yn "    Use existing credentials?" true)
                (setq have-creds nil)))

            (unless have-creds
              (println)
              (setf (assoc "api_key" cloud)
                (list "api_key" (prompt-string "    Enter API Key from tuya.com" (cloud "api_key"))))
              (setf (assoc "api_secret" cloud)
                (list "api_secret" (prompt-string "    Enter API Secret from tuya.com" (cloud "api_secret"))))
              (setf (assoc "api_device_id" cloud)
                (list "api_device_id" (prompt-string "    Enter any Device ID registered in Tuya App" (cloud "api_device_id"))))
              (println "\n    Region list:")
              (println "        cn      China")
              (println "        us      US — Western America")
              (println "        us-e    US — Eastern America")
              (println "        eu      Central Europe")
              (println "        eu-w    Western Europe")
              (println "        in      India")
              (println "        sg      Singapore\n")
              (setf (assoc "api_region" cloud)
                (list "api_region" (prompt-string "    Enter your region" (cloud "api_region"))))))

          ;; Lowercase the region
          (setf (assoc "api_region" cloud)
            (list "api_region" (lower-case (cloud "api_region"))))

          ;; Save credentials
          (catch (save-config config-file cloud))

          ;; Set host
          (setf (assoc "host" cloud)
            (list "host" (region-to-host (cloud "api_region"))))

          ;; Authenticate
          (println "\nConnecting to Tuya Cloud (" (cloud "host") ")...")
          (unless (catch (tuya-get-token cloud) 'err)
            (println "Authentication failed. Check API Key and Secret.")
            (exit 1))
          (println "  authenticated.")

          ;; Fetch devices
          (println "Fetching device list...")
          (setq devices (catch (tuya-get-devices cloud) 'err))
          (unless (list? devices)
            (println "error: failed to fetch devices")
            (exit 1))
          (setq device-count (length devices))

          ;; Display
          (println (format "\nDevice listing (%d devices):\n" device-count))
          (dolist (d devices)
            (println (format "  %-40s id=%-24s key=%s%s"
                            (lookup "name" d)
                            (lookup "id" d)
                            (lookup "key" d)
                            (if (lookup "sub" d) "  [sub-device]" ""))))

          ;; Save device list
          (catch (save-devices device-file devices))

          ;; Poll local network
          (let (do-scan (if assume-yes true
                            (prompt-yn "\nPoll local devices?" true)))
            (when (and do-scan (> device-count 0))
              (catch (udp-discover devices timeout))
              (catch (save-devices device-file devices)))))))

    (println "\nDone.")))

(main)
(exit)
