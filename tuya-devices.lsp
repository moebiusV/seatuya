; tuya-devices.lsp — FOOP device classes for Tuya devices
;
; Convenience layer over seatuya.lsp.  Each device class maps tinytuya's
; device-class methods to the right data point (DP) numbers, so you get
; idiomatic (:turn-on my-outlet) instead of raw set-value calls.
;
; Usage:
;   (load "tuya-devices.lsp")
;   (setq plug (OutletDevice "3.3" "192.168.1.50" "device-id" "local-key"))
;   (:turn-on plug)
;   (:status plug)
;   (:destroy plug)

(load (string (env "SEATUYA_LSP_DIR" (real-path ".")) "/seatuya.lsp"))

;; ====================================================================
;;  Helpers
;; ====================================================================

(define (tuya-devices:connect-device version ip device-id local-key)
  "Create handle, connect, negotiate session, store credentials.
   Returns handle or throws on failure."
  (let (dev (tuya:create version))
    (unless dev (throw (string "unsupported protocol version: " version)))
    (unless (tuya:connect dev ip)
      (tuya:destroy dev)
      (throw (string "connection failed to " ip)))
    (when (>= (tuya:get-protocol dev) tuya:PROTO_V34)
      (unless (tuya:negotiate-session dev local-key)
        (tuya:disconnect dev)
        (tuya:destroy dev)
        (throw "session negotiation failed")))
    (tuya:set-credentials dev device-id local-key)
    dev))

(define (tuya-devices:destroy-device dev)
  "Disconnect, clear credentials, destroy handle."
  (when dev
    (when (tuya:is-connected dev) (tuya:disconnect dev))
    (tuya:clear-credentials dev)
    (tuya:destroy dev)))

;; RGB-to-HSV conversion (pure newLISP math)
(define (tuya-devices:rgb-to-hsv r g b)
  "Convert RGB (0-255 each) to HSV.  Returns (h s v) where
   h=0-360, s=0-1000, v=0-1000 (type B scale)."
  (let (rf (div r 255.0) gf (div g 255.0) bf (div b 255.0)
        cmax (max rf gf bf)
        cmin (min rf gf bf)
        delta (sub cmax cmin)
        h 0 s 0 v (mul cmax 1000.0))
    (when (!= delta 0)
      (setq s (mul (div delta cmax) 1000.0))
      (setq h (cond
                ((= cmax rf) (mul 60 (mod (div (sub gf bf) delta) 6)))
                ((= cmax gf) (mul 60 (add (div (sub bf rf) delta) 2)))
                (true         (mul 60 (add (div (sub rf gf) delta) 4)))))
      (when (< h 0) (setq h (add h 360))))
    (list (int (round h 0)) (int (round s 0)) (int (round v 0)))))

;; HSV hex encoding for bulb colour DPs
(define (tuya-devices:hsv-hex-b h s v)
  "Encode HSV to type B hex: hhhhssssvvvv (h=0-360, s=0-1000, v=0-1000)."
  (format "%04x%04x%04x" h s v))

(define (tuya-devices:hsv-hex-a h s v)
  "Encode HSV to type A hex: 0000000000hhhssvv (h=0-360, s=0-255, v=0-255).
   The first 6 chars are the RGB hex (cosmetic, device ignores them)."
  (let (s8 (int (round (div (mul s 255.0) 1000.0) 0))
        v8 (int (round (div (mul v 255.0) 1000.0) 0)))
    (format "000000%04x%02x%02x" h s8 v8)))

;; Scale percentage to a range
(define (tuya-devices:pct-scale pct lo hi)
  "Map percentage 0-100 to integer range lo-hi."
  (int (round (add lo (mul (div pct 100.0) (sub hi lo))) 0)))


;; ====================================================================
;;  OutletDevice (smart plugs, power strips, wall switches)
;; ====================================================================

(new Class 'OutletDevice)

(define (OutletDevice:OutletDevice version ip device-id local-key)
  "Create an outlet device.  Fields: 0=class, 1=handle, 2=device-id, 3=local-key."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list OutletDevice dev device-id local-key)))

(define (OutletDevice:turn-on (switch 1))
  "Turn on the outlet (or a specific switch number for multi-switch devices)."
  (tuya:set-value (self 1) switch true))

(define (OutletDevice:turn-off (switch 1))
  "Turn off the outlet."
  (tuya:set-value (self 1) switch nil))

(define (OutletDevice:set-dimmer pct)
  "Set dimmer level.  pct is 0-100, mapped to device range 25-255 on DP 3."
  (tuya:set-value (self 1) 3 (tuya-devices:pct-scale pct 25 255)))

(define (OutletDevice:status)
  "Query all data points."
  (tuya:status (self 1)))

(define (OutletDevice:destroy)
  "Disconnect and free the device handle."
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  BulbDevice (RGB/RGBW smart lighting)
;; ====================================================================
;;
;; Two DP layouts:
;;   Type A (legacy):  DP 1=switch, 2=mode, 3=brightness(25-255),
;;                     4=colourtemp(0-255), 5=colour
;;   Type B (common):  DP 20=switch, 21=mode, 22=brightness(10-1000),
;;                     23=colourtemp(0-1000), 24=colour, 25=scene

(new Class 'BulbDevice)

(define (BulbDevice:BulbDevice version ip device-id local-key (bulb-type "B"))
  "Create a bulb device.  bulb-type: \"A\" (legacy) or \"B\" (default).
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=bulb-type,
   5=dp-switch, 6=dp-mode, 7=dp-brightness, 8=dp-colourtemp, 9=dp-colour."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (if (= bulb-type "A")
      (list BulbDevice dev device-id local-key "A" 1 2 3 4 5)
      (list BulbDevice dev device-id local-key "B" 20 21 22 23 24))))

(define (BulbDevice:turn-on)
  (tuya:set-value (self 1) (self 5) true))

(define (BulbDevice:turn-off)
  (tuya:set-value (self 1) (self 5) nil))

(define (BulbDevice:set-mode mode)
  "Set mode: \"white\", \"colour\", \"scene\", or \"music\"."
  (tuya:set-value (self 1) (self 6) mode))

(define (BulbDevice:set-brightness val)
  "Set raw brightness value.  Type B: 10-1000, type A: 25-255."
  (tuya:set-value (self 1) (self 7) val))

(define (BulbDevice:set-brightness-pct pct)
  "Set brightness as a percentage (0-100)."
  (if (= (self 4) "A")
    (tuya:set-value (self 1) (self 7) (tuya-devices:pct-scale pct 25 255))
    (tuya:set-value (self 1) (self 7) (tuya-devices:pct-scale pct 10 1000))))

(define (BulbDevice:set-colourtemp val)
  "Set raw colour temperature.  Type B: 0-1000, type A: 0-255."
  (tuya:set-value (self 1) (self 8) val))

(define (BulbDevice:set-colourtemp-pct pct)
  "Set colour temperature as a percentage (0-100)."
  (if (= (self 4) "A")
    (tuya:set-value (self 1) (self 8) (tuya-devices:pct-scale pct 0 255))
    (tuya:set-value (self 1) (self 8) (tuya-devices:pct-scale pct 0 1000))))

(define (BulbDevice:set-colour r g b)
  "Set colour from RGB values (0-255 each).  Converts to HSV, encodes as hex,
   sets mode to colour, then writes the colour DP."
  (let (hsv (tuya-devices:rgb-to-hsv r g b)
        hex (if (= (self 4) "A")
              (tuya-devices:hsv-hex-a (hsv 0) (hsv 1) (hsv 2))
              (tuya-devices:hsv-hex-b (hsv 0) (hsv 1) (hsv 2))))
    (tuya:set-value (self 1) (self 6) "colour")
    (tuya:set-value (self 1) (self 9) hex)))

(define (BulbDevice:set-hsv h s v)
  "Set colour from HSV directly.  h=0-360, s and v use device scale
   (type B: 0-1000, type A: 0-255)."
  (let (hex (if (= (self 4) "A")
              (tuya-devices:hsv-hex-a h s v)
              (tuya-devices:hsv-hex-b h s v)))
    (tuya:set-value (self 1) (self 6) "colour")
    (tuya:set-value (self 1) (self 9) hex)))

(define (BulbDevice:set-white brightness colourtemp)
  "Set white mode with brightness and colour temperature (raw values)."
  (tuya:set-value (self 1) (self 6) "white")
  (tuya:set-value (self 1) (self 7) brightness)
  (tuya:set-value (self 1) (self 8) colourtemp))

(define (BulbDevice:status)
  (tuya:status (self 1)))

(define (BulbDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  CoverDevice (blinds, curtains, garage doors)
;; ====================================================================
;;
;; 8 command type variations.  Auto-detected from device status on first
;; use, or set manually via :set-cover-type.
;;
;;   1: "open"/"close"/"stop"         (default)
;;   2: true/false                    (garage doors, locks)
;;   3: "0"/"1"/"2"
;;   4: "00"/"01"/"02"/"03"           (03 = continue)
;;   5: "fopen"/"fclose"
;;   6: "on"/"off"/"stop"
;;   7: "up"/"down"/"stop"
;;   8: "ZZ"/"FZ"/"STOP"

(new Class 'CoverDevice)

;; Command tables indexed by cover type (1-8)
(setq CoverDevice:open-cmds  '(nil "open" true   "1" "00" "fopen"  "on" "up"   "ZZ"))
(setq CoverDevice:close-cmds '(nil "close" nil   "0" "01" "fclose" "off" "down" "FZ"))
(setq CoverDevice:stop-cmds  '(nil "stop"  nil   "2" "02" nil      "stop" "stop" "STOP"))

(define (CoverDevice:CoverDevice version ip device-id local-key)
  "Create a cover device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=cover-type."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list CoverDevice dev device-id local-key 1)))

(define (CoverDevice:set-cover-type typ)
  "Override auto-detected cover type (1-8)."
  (setf (self 4) typ))

(define (CoverDevice:open-cover)
  "Open the cover."
  (tuya:set-value (self 1) 1 (CoverDevice:open-cmds (self 4))))

(define (CoverDevice:close-cover)
  "Close the cover."
  (tuya:set-value (self 1) 1 (CoverDevice:close-cmds (self 4))))

(define (CoverDevice:stop-cover)
  "Stop the cover."
  (let (cmd (CoverDevice:stop-cmds (self 4)))
    (when cmd (tuya:set-value (self 1) 1 cmd))))

(define (CoverDevice:set-position pct)
  "Set cover position (0-100).  Uses DP 2."
  (tuya:set-value (self 1) 2 pct))

(define (CoverDevice:status)
  (tuya:status (self 1)))

(define (CoverDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  ThermostatDevice
;; ====================================================================
;;
;; Common DP layout (overridable via constructor):
;;   DP 1: switch (bool)
;;   DP 2: target temp (int, often x10)
;;   DP 3: current temp (int, read-only)
;;   DP 4: mode (enum: "heat"/"cool"/"auto"/"off")

(new Class 'ThermostatDevice)

(define (ThermostatDevice:ThermostatDevice version ip device-id local-key
          (dp-switch 1) (dp-target 2) (dp-current 3) (dp-mode 4) (temp-scale 10))
  "Create a thermostat device.  DP numbers and temp-scale (divisor for raw
   values, e.g. 10 means device sends 720 for 72.0) are overridable.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key,
   4=dp-switch, 5=dp-target, 6=dp-current, 7=dp-mode, 8=temp-scale."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list ThermostatDevice dev device-id local-key
          dp-switch dp-target dp-current dp-mode temp-scale)))

(define (ThermostatDevice:turn-on)
  (tuya:set-value (self 1) (self 4) true))

(define (ThermostatDevice:turn-off)
  (tuya:set-value (self 1) (self 4) nil))

(define (ThermostatDevice:set-temperature temp)
  "Set target temperature.  Multiplied by temp-scale before sending."
  (tuya:set-value (self 1) (self 5) (int (round (mul temp (self 8)) 0))))

(define (ThermostatDevice:set-mode mode)
  "Set mode: \"heat\", \"cool\", \"auto\", or \"off\"."
  (tuya:set-value (self 1) (self 7) mode))

(define (ThermostatDevice:get-temperature)
  "Read current temperature from device status.  Returns float or nil."
  (let (resp (tuya:status (self 1)))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps
              (let (raw (lookup (string (self 6)) dps))
                (when raw (div raw (self 8)))))))))))

(define (ThermostatDevice:status)
  (tuya:status (self 1)))

(define (ThermostatDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  FanDevice (fans, air purifiers)
;; ====================================================================
;;
;; Common DPs:
;;   DP 1: switch (bool)
;;   DP 3: speed (int or enum)
;;   DP 4: oscillation (bool)

(new Class 'FanDevice)

(define (FanDevice:FanDevice version ip device-id local-key
          (dp-switch 1) (dp-speed 3) (dp-oscillation 4))
  "Create a fan device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key,
   4=dp-switch, 5=dp-speed, 6=dp-oscillation."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list FanDevice dev device-id local-key dp-switch dp-speed dp-oscillation)))

(define (FanDevice:turn-on)
  (tuya:set-value (self 1) (self 4) true))

(define (FanDevice:turn-off)
  (tuya:set-value (self 1) (self 4) nil))

(define (FanDevice:set-speed speed)
  "Set fan speed (int or string depending on device)."
  (tuya:set-value (self 1) (self 5) speed))

(define (FanDevice:set-oscillation flag)
  "Enable or disable oscillation."
  (tuya:set-value (self 1) (self 6) (if flag true nil)))

(define (FanDevice:status)
  (tuya:status (self 1)))

(define (FanDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  LockDevice
;; ====================================================================

(new Class 'LockDevice)

(define (LockDevice:LockDevice version ip device-id local-key (dp-lock 1))
  "Create a lock device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=dp-lock."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list LockDevice dev device-id local-key dp-lock)))

(define (LockDevice:lock)
  (tuya:set-value (self 1) (self 4) true))

(define (LockDevice:unlock)
  (tuya:set-value (self 1) (self 4) nil))

(define (LockDevice:status)
  (tuya:status (self 1)))

(define (LockDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  SirenDevice
;; ====================================================================

(new Class 'SirenDevice)

(define (SirenDevice:SirenDevice version ip device-id local-key
          (dp-switch 104) (dp-volume 5) (dp-duration 7))
  "Create a siren device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key,
   4=dp-switch, 5=dp-volume, 6=dp-duration."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list SirenDevice dev device-id local-key dp-switch dp-volume dp-duration)))

(define (SirenDevice:turn-on)
  (tuya:set-value (self 1) (self 4) true))

(define (SirenDevice:turn-off)
  (tuya:set-value (self 1) (self 4) nil))

(define (SirenDevice:set-volume vol)
  "Set siren volume (device-specific scale)."
  (tuya:set-value (self 1) (self 5) vol))

(define (SirenDevice:set-duration secs)
  "Set siren duration in seconds."
  (tuya:set-value (self 1) (self 6) secs))

(define (SirenDevice:status)
  (tuya:status (self 1)))

(define (SirenDevice:destroy)
  (tuya-devices:destroy-device (self 1)))
