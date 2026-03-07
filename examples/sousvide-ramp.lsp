#!/usr/bin/env newlisp
;
; sousvide-ramp.lsp — Ramp an Inkbird sous vide from one temperature to another.
;
; Usage:
;   sousvide-ramp.lsp [options]
;
; Reads device credentials from $XDG_CONFIG_HOME/seatuya/config
; (defaults to ~/.config/seatuya/config), INI-style:
;
;   [sousvide]
;   device_id = <your device id>
;   local_key = <your local key>
;   ip        = <device IP or hostname>
;   version   = 3.3
;
; Default behaviour (no arguments):
;   Start at 90 F, ramp to 145 F over 45 minutes.
;
; Options:
;   -s TEMP   start temperature in Fahrenheit  (default: 90)
;   -e TEMP   end temperature in Fahrenheit    (default: 145)
;   -t MINS   ramp duration in minutes         (default: 45)
;   -c FILE   config file path
;   -d        discover devices on the LAN (UDP broadcast scan)
;   -n        dry run — print steps, don't connect
;

(load (string (env "SEATUYA_LSP_DIR" (real-path "..")) "/tuya-devices.lsp"))

;; ----------------------------------------------------------------
;;  Inkbird sous vide DPS mapping (ISV-100W / ISV-200W)
;; ----------------------------------------------------------------
;;
;; We use ThermostatDevice with custom DP numbers:
;;   DP 101: power switch (bool)
;;   DP 103: target temp (int, Celsius * 10)
;;   DP 104: current temp (int, Celsius * 10)
;;   DP 102: status string ("working"/"stopping") -- mapped to mode DP
;;   temp-scale: 10 (device uses Celsius * 10)

(constant 'DPS_POWER        101)
(constant 'DPS_STATUS       102)
(constant 'DPS_TARGET_TEMP  103)
(constant 'DPS_CURRENT_TEMP 104)
(constant 'DPS_TIMER        105)
(constant 'DPS_TIME_LEFT    106)
(constant 'DPS_TEMP_UNIT    108)
(constant 'DPS_TEMP_CAL     110)

;; ----------------------------------------------------------------
;;  UDP discovery
;; ----------------------------------------------------------------
;;
;; Tuya devices broadcast on UDP port 6666 (plaintext) and 6667
;; (encrypted with AES-ECB, key = MD5("yGAdlopoPVldABfn")).
;; The broadcast frame uses the Tuya protocol wrapper:
;;   prefix(4) 0x000055aa + seqno(4) + cmd(4) + length(4)
;;   + payload + crc(4) + suffix(4) 0x0000aa55
;; On port 6666 the payload is plaintext JSON containing at minimum:
;;   {"ip": "...", "gwId": "...", "version": "..."}

(constant 'UDP_PORT      6666)
(constant 'UDP_PREFIX    "\000\000\085\170")   ; 0x000055aa
(constant 'UDP_SUFFIX    "\000\000\170\085")   ; 0x0000aa55
(constant 'SCAN_TIMEOUT  8)                    ; seconds

(define (extract-json-from-frame data)
  "Pull the first JSON object out of a Tuya UDP frame (or raw data)."
  (let (start (find "{" data)
        end   (find "}" data -1))
    (when (and start end (>= end start))
      (slice data start (+ (- end start) 1)))))

(define (discover-devices (timeout SCAN_TIMEOUT))
  "Listen for Tuya UDP broadcasts and return a list of device assoc-lists."
  (let (sock    (net-listen UDP_PORT "" "udp")
        devices '()
        seen    '()
        deadline (+ (time-of-day) (* timeout 1000)))
    (unless sock
      (println "error: cannot bind UDP port " UDP_PORT
               " (try running as root or check if another process has it)")
      (exit 1))
    (println "Scanning for Tuya devices on UDP port " UDP_PORT
             " (" timeout "s timeout)...")
    (while (< (time-of-day) deadline)
      (when (net-select sock "r" 1000000)
        (let (result (net-receive-from sock 1024))
          (when result
            (let (data    (result 1)
                  sender  (result 0)
                  json-str (extract-json-from-frame data))
              (when json-str
                (let (info (json-parse json-str))
                  (when (and info (lookup "gwId" info))
                    (let (gw-id (lookup "gwId" info))
                      (unless (member gw-id seen)
                        (push gw-id seen)
                        (push (list
                                (list "ip"      (or (lookup "ip" info) sender))
                                (list "gwId"    gw-id)
                                (list "version" (or (lookup "version" info) "?"))
                                (list "active"  (or (lookup "active" info) "?"))
                                (list "productKey" (or (lookup "productKey" info) "?")))
                              devices -1)
                        (println "  found: " (lookup "ip" (last devices))
                                 "  id=" gw-id
                                 "  v=" (lookup "version" (last devices)))))))))))))
    (net-close sock)
    (println "Scan complete. " (length devices) " device(s) found.")
    devices))

;; ----------------------------------------------------------------
;;  Config file reader
;; ----------------------------------------------------------------

(define (default-config-path)
  (let (xdg (env "XDG_CONFIG_HOME"))
    (if (and xdg (!= xdg ""))
      (string xdg "/seatuya/config")
      (string (env "HOME") "/.config/seatuya/config"))))

(define (read-config path)
  "Read INI config, return assoc-list of [sousvide] keys or nil on error."
  (unless (file? path)
    (println "error: cannot open " path)
    (exit 1))
  (let (lines      (parse (read-file path) "\n")
        in-section nil
        cfg        '())
    (dolist (line lines)
      (let (trimmed (trim line))
        (cond
          ((or (starts-with trimmed "#")
               (starts-with trimmed ";")
               (= trimmed ""))  nil)
          ((starts-with trimmed "[")
           (setq in-section (find "[sousvide]" trimmed)))
          (in-section
           (let (parts (parse trimmed "=" 2))
             (when (= (length parts) 2)
               (push (list (trim (parts 0)) (trim (parts 1))) cfg -1)))))))
    (unless (and (lookup "device_id" cfg)
                 (lookup "local_key" cfg)
                 (lookup "ip" cfg))
      (println "error: missing device_id, local_key, or ip in [sousvide] section of " path)
      (exit 1))
    (unless (lookup "version" cfg)
      (push '("version" "3.3") cfg -1))
    cfg))

;; ----------------------------------------------------------------
;;  Temperature helpers
;; ----------------------------------------------------------------

(define (f-to-c f)
  (div (mul (sub f 32.0) 5.0) 9.0))

;; ----------------------------------------------------------------
;;  Inkbird convenience wrappers
;; ----------------------------------------------------------------

(define (power-on sv)
  (println "  powering on")
  (:turn-on sv))

(define (set-temperature-f sv temp-f)
  (println (format "  set target: %.1f F (%.1f C)" temp-f (f-to-c temp-f)))
  (:set-temperature sv (f-to-c temp-f)))

(define (query-status sv)
  (println "  querying status")
  (let (resp (:status sv))
    (when resp (println "  response: " resp))))

;; ----------------------------------------------------------------
;;  Argument parsing
;; ----------------------------------------------------------------

(define (usage prog)
  (println
    (format "Usage: %s [-s start_F] [-e end_F] [-t minutes] [-c configfile] [-d] [-n]" prog)
    "\n"
    "\nRamp an Inkbird sous vide from start to end temperature."
    "\nReads credentials from $XDG_CONFIG_HOME/seatuya/config [sousvide]."
    "\n"
    "\nOptions:"
    "\n  -s TEMP   start temperature in Fahrenheit  (default: 90)"
    "\n  -e TEMP   end temperature in Fahrenheit    (default: 145)"
    "\n  -t MINS   ramp duration in minutes         (default: 45)"
    "\n  -c FILE   config file path"
    "\n  -d        discover Tuya devices on the LAN"
    "\n  -n        dry run"))

(define (parse-args)
  (let (args   (rest (main-args))
        result (list '("start_f" 90.0)
                     '("end_f" 145.0)
                     '("ramp_minutes" 45)
                     '("config_path" nil)
                     '("dry_run" nil)
                     '("discover" nil))
        i 0)
    (while (< i (length args))
      (let (a (args i))
        (cond
          ((= a "-s") (inc i) (setf (assoc "start_f" result)       (list "start_f" (float (args i)))))
          ((= a "-e") (inc i) (setf (assoc "end_f" result)         (list "end_f" (float (args i)))))
          ((= a "-t") (inc i) (setf (assoc "ramp_minutes" result)  (list "ramp_minutes" (int (args i)))))
          ((= a "-c") (inc i) (setf (assoc "config_path" result)   (list "config_path" (args i))))
          ((= a "-d") (setf (assoc "discover" result)              (list "discover" true)))
          ((= a "-n") (setf (assoc "dry_run" result)               (list "dry_run" true)))
          ((or (= a "-h") (= a "--help"))
           (usage ((main-args) 0))
           (exit 0))
          (true
           (println "unknown option: " a)
           (usage ((main-args) 0))
           (exit 1))))
      (inc i))
    result))

;; ----------------------------------------------------------------
;;  Main
;; ----------------------------------------------------------------

(define (main)
  (let (opts          (parse-args)
        start-f       (lookup "start_f" opts)
        end-f         (lookup "end_f" opts)
        ramp-minutes  (lookup "ramp_minutes" opts)
        config-path   (or (lookup "config_path" opts) (default-config-path))
        dry-run       (lookup "dry_run" opts)
        do-discover   (lookup "discover" opts))

    ;; Discovery mode
    (when do-discover
      (discover-devices)
      (exit 0))

    (when (< ramp-minutes 1)
      (println "error: ramp duration must be at least 1 minute")
      (exit 1))

    ;; Ramp strategy: adjust temperature once per minute
    (let (steps  ramp-minutes
          step-f (div (sub end-f start-f) steps))

      (println (format "sousvide-ramp: %.1f F -> %.1f F over %d minutes (%d steps of %.2f F)"
                       start-f end-f ramp-minutes steps step-f))

      ;; Dry run
      (when dry-run
        (println "\n[dry run]")
        (for (i 0 steps)
          (let (temp (min end-f (add start-f (mul step-f i))))
            (println (format "  t=%3d min  target=%.1f F  (%.1f C)"
                             i temp (f-to-c temp)))))
        (exit 0))

      ;; Read config
      (let (cfg        (read-config config-path)
            device-id  (lookup "device_id" cfg)
            local-key  (lookup "local_key" cfg)
            ip         (lookup "ip" cfg)
            version    (lookup "version" cfg))

        (println (format "device: %s @ %s (protocol %s)" device-id ip version))

        ;; Create ThermostatDevice with Inkbird DP mapping:
        ;;   dp-switch=101, dp-target=103, dp-current=104, dp-mode=102, temp-scale=10
        (let (sv (ThermostatDevice version ip device-id local-key
                   DPS_POWER DPS_TARGET_TEMP DPS_CURRENT_TEMP DPS_STATUS 10))

          ;; Query current status, power on, set initial temperature
          (query-status sv)
          (power-on sv)
          (set-temperature-f sv start-f)

          ;; Ramp loop: one adjustment per minute
          (for (i 1 steps)
            (let (temp (min end-f (add start-f (mul step-f i))))
              (print (format "[%3d/%d min] " i steps))
              (sleep 60000)

              ;; Reconnect if connection dropped
              (:reconnect sv)

              (set-temperature-f sv temp)))

          (println (format "\nramp complete -- holding at %.1f F" end-f))

          ;; Clean up
          (:destroy sv))))))

(main)
(exit)
