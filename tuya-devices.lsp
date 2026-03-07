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
;
; All classes share a common field prefix:
;   0=class  1=handle  2=device-id  3=local-key  4=ip
; Class-specific fields start at index 5.

(load (string (env "SEATUYA_LSP_DIR" (real-path ".")) "/seatuya.lsp"))

;; ====================================================================
;;  Helpers
;; ====================================================================

(define (tuya-devices:connect-device version ip device-id local-key)
  "Create handle, store credentials, connect, negotiate session.
   Returns handle or throws on failure."
  (let (dev (tuya:create version))
    (unless dev (throw (string "unsupported protocol version: " version)))
    (tuya:set-credentials dev device-id local-key)
    (unless (tuya:connect dev ip)
      (tuya:destroy dev)
      (throw (string "connection failed to " ip)))
    (when (>= (tuya:get-protocol dev) tuya:PROTO_V34)
      (unless (tuya:negotiate-session dev local-key)
        (tuya:disconnect dev)
        (tuya:destroy dev)
        (throw "session negotiation failed")))
    dev))

(define (tuya-devices:reconnect-device dev)
  "Reconnect if the connection has dropped.  Re-negotiates session
   for protocol 3.4+.  Returns true if connected, nil on failure."
  (tuya:reconnect dev))

(define (tuya-devices:destroy-device dev)
  "Disconnect and destroy handle."
  (when dev
    (when (tuya:is-connected dev) (tuya:disconnect dev))
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
  "Create an outlet device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list OutletDevice dev device-id local-key ip)))

(define (OutletDevice:turn-on (switch 1))
  "Turn on the outlet (or a specific switch number for multi-switch devices)."
  (tuya:set-value (self 1) switch true))

(define (OutletDevice:turn-off (switch 1))
  "Turn off the outlet."
  (tuya:set-value (self 1) switch nil))

(define (OutletDevice:set-dimmer pct)
  "Set dimmer level.  pct is 0-100, mapped to device range 25-255 on DP 3."
  (tuya:set-value (self 1) 3 (tuya-devices:pct-scale pct 25 255)))

(define (OutletDevice:reconnect)
  "Reconnect if the connection has dropped."
  (tuya-devices:reconnect-device (self 1)))

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
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip, 5=bulb-type,
   6=dp-switch, 7=dp-mode, 8=dp-brightness, 9=dp-colourtemp, 10=dp-colour."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (if (= bulb-type "A")
      (list BulbDevice dev device-id local-key ip "A" 1 2 3 4 5)
      (list BulbDevice dev device-id local-key ip "B" 20 21 22 23 24))))

(define (BulbDevice:turn-on)
  (tuya:set-value (self 1) (self 6) true))

(define (BulbDevice:turn-off)
  (tuya:set-value (self 1) (self 6) nil))

(define (BulbDevice:set-mode mode)
  "Set mode: \"white\", \"colour\", \"scene\", or \"music\"."
  (tuya:set-value (self 1) (self 7) mode))

(define (BulbDevice:set-brightness val)
  "Set raw brightness value.  Type B: 10-1000, type A: 25-255."
  (tuya:set-value (self 1) (self 8) val))

(define (BulbDevice:set-brightness-pct pct)
  "Set brightness as a percentage (0-100)."
  (if (= (self 5) "A")
    (tuya:set-value (self 1) (self 8) (tuya-devices:pct-scale pct 25 255))
    (tuya:set-value (self 1) (self 8) (tuya-devices:pct-scale pct 10 1000))))

(define (BulbDevice:set-colourtemp val)
  "Set raw colour temperature.  Type B: 0-1000, type A: 0-255."
  (tuya:set-value (self 1) (self 9) val))

(define (BulbDevice:set-colourtemp-pct pct)
  "Set colour temperature as a percentage (0-100)."
  (if (= (self 5) "A")
    (tuya:set-value (self 1) (self 9) (tuya-devices:pct-scale pct 0 255))
    (tuya:set-value (self 1) (self 9) (tuya-devices:pct-scale pct 0 1000))))

(define (BulbDevice:set-colour r g b)
  "Set colour from RGB values (0-255 each).  Converts to HSV, encodes as hex,
   sets mode to colour, then writes the colour DP."
  (let (hsv (tuya-devices:rgb-to-hsv r g b)
        hex (if (= (self 5) "A")
              (tuya-devices:hsv-hex-a (hsv 0) (hsv 1) (hsv 2))
              (tuya-devices:hsv-hex-b (hsv 0) (hsv 1) (hsv 2))))
    (tuya:set-value (self 1) (self 7) "colour")
    (tuya:set-value (self 1) (self 10) hex)))

(define (BulbDevice:set-hsv h s v)
  "Set colour from HSV directly.  h=0-360, s and v use device scale
   (type B: 0-1000, type A: 0-255)."
  (let (hex (if (= (self 5) "A")
              (tuya-devices:hsv-hex-a h s v)
              (tuya-devices:hsv-hex-b h s v)))
    (tuya:set-value (self 1) (self 7) "colour")
    (tuya:set-value (self 1) (self 10) hex)))

(define (BulbDevice:set-white brightness colourtemp)
  "Set white mode with brightness and colour temperature (raw values)."
  (tuya:set-value (self 1) (self 7) "white")
  (tuya:set-value (self 1) (self 8) brightness)
  (tuya:set-value (self 1) (self 9) colourtemp))

(define (BulbDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

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
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip, 5=cover-type."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list CoverDevice dev device-id local-key ip 1)))

(define (CoverDevice:set-cover-type typ)
  "Override auto-detected cover type (1-8)."
  (setf (self 5) typ))

(define (CoverDevice:open-cover)
  "Open the cover."
  (tuya:set-value (self 1) 1 (CoverDevice:open-cmds (self 5))))

(define (CoverDevice:close-cover)
  "Close the cover."
  (tuya:set-value (self 1) 1 (CoverDevice:close-cmds (self 5))))

(define (CoverDevice:stop-cover)
  "Stop the cover."
  (let (cmd (CoverDevice:stop-cmds (self 5)))
    (when cmd (tuya:set-value (self 1) 1 cmd))))

(define (CoverDevice:set-position pct)
  "Set cover position (0-100).  Uses DP 2."
  (tuya:set-value (self 1) 2 pct))

(define (CoverDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

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
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip,
   5=dp-switch, 6=dp-target, 7=dp-current, 8=dp-mode, 9=temp-scale."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list ThermostatDevice dev device-id local-key ip
          dp-switch dp-target dp-current dp-mode temp-scale)))

(define (ThermostatDevice:turn-on)
  (tuya:set-value (self 1) (self 5) true))

(define (ThermostatDevice:turn-off)
  (tuya:set-value (self 1) (self 5) nil))

(define (ThermostatDevice:set-temperature temp)
  "Set target temperature.  Multiplied by temp-scale before sending."
  (tuya:set-value (self 1) (self 6) (int (round (mul temp (self 9)) 0))))

(define (ThermostatDevice:set-mode mode)
  "Set mode: \"heat\", \"cool\", \"auto\", or \"off\"."
  (tuya:set-value (self 1) (self 8) mode))

(define (ThermostatDevice:get-temperature)
  "Read current temperature from device status.  Returns float or nil."
  (let (resp (tuya:status (self 1)))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps
              (let (raw (lookup (string (self 7)) dps))
                (when raw (div raw (self 9)))))))))))

(define (ThermostatDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

(define (ThermostatDevice:status)
  (tuya:status (self 1)))

(define (ThermostatDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  SocketDevice (energy-monitoring smart sockets)
;; ====================================================================
;;
;; Follows tinytuya Contrib SocketDevice.
;; DP 1: switch (bool)
;; DP 18: current (mA)
;; DP 19: power (dW, divide by 10 for watts)
;; DP 20: voltage (dV, divide by 10 for volts)

(new Class 'SocketDevice)

(define (SocketDevice:SocketDevice version ip device-id local-key)
  "Create an energy-monitoring socket device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list SocketDevice dev device-id local-key ip)))

(define (SocketDevice:turn-on (switch 1))
  (tuya:set-value (self 1) switch true))

(define (SocketDevice:turn-off (switch 1))
  (tuya:set-value (self 1) switch nil))

(define (SocketDevice:get-energy)
  "Query status and return assoc-list of current (mA), power (W), voltage (V).
   Returns nil if status query fails."
  (let (resp (tuya:status (self 1)))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps
              (list
                (list "current_mA" (or (lookup "18" dps) 0))
                (list "power_W"    (div (or (lookup "19" dps) 0) 10.0))
                (list "voltage_V"  (div (or (lookup "20" dps) 0) 10.0))))))))))

(define (SocketDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

(define (SocketDevice:status)
  (tuya:status (self 1)))

(define (SocketDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  ClimateDevice (portable air conditioners)
;; ====================================================================
;;
;; Follows tinytuya Contrib ClimateDevice.
;; DP 1: power (bool)
;; DP 2: target temp (int)
;; DP 3: current temp (int)
;; DP 4: mode (enum: "cold"/"hot"/"wind"/"auto")
;; DP 5: fan speed (enum: "1"/"2"/"3")
;; DP 19: temp unit (enum: "c"/"f")
;; DP 22: timer (int, minutes)

(new Class 'ClimateDevice)

(define (ClimateDevice:ClimateDevice version ip device-id local-key)
  "Create a portable AC / climate device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list ClimateDevice dev device-id local-key ip)))

(define (ClimateDevice:turn-on)
  (tuya:set-value (self 1) 1 true))

(define (ClimateDevice:turn-off)
  (tuya:set-value (self 1) 1 nil))

(define (ClimateDevice:set-temperature temp)
  "Set target temperature (integer, in device's current unit)."
  (tuya:set-value (self 1) 2 (int temp)))

(define (ClimateDevice:get-temperature)
  "Read current room temperature from status.  Returns int or nil."
  (let (resp (tuya:status (self 1)))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (lookup "3" dps))))))))

(define (ClimateDevice:set-mode mode)
  "Set operating mode: \"cold\", \"hot\", \"wind\", or \"auto\"."
  (tuya:set-value (self 1) 4 mode))

(define (ClimateDevice:set-fan-speed speed)
  "Set fan speed: \"1\" (low), \"2\" (medium), \"3\" (high)."
  (tuya:set-value (self 1) 5 speed))

(define (ClimateDevice:set-temp-unit unit)
  "Set temperature unit: \"c\" or \"f\"."
  (tuya:set-value (self 1) 19 unit))

(define (ClimateDevice:set-timer minutes)
  "Set timer in minutes."
  (tuya:set-value (self 1) 22 (int minutes)))

(define (ClimateDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

(define (ClimateDevice:status)
  (tuya:status (self 1)))

(define (ClimateDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  DoorbellDevice (video doorbells)
;; ====================================================================
;;
;; Follows tinytuya Contrib DoorbellDevice.
;; Note: most battery-powered doorbells stay offline to conserve power
;; and only connect briefly when the button is pressed or motion is
;; detected.  This class is most useful for mains-powered doorbells.

(new Class 'DoorbellDevice)

(define (DoorbellDevice:DoorbellDevice version ip device-id local-key)
  "Create a video doorbell device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list DoorbellDevice dev device-id local-key ip)))

(define (DoorbellDevice:set-volume vol)
  "Set device volume (1-10).  DP 160."
  (tuya:set-value (self 1) 160 (int vol)))

(define (DoorbellDevice:set-motion-switch flag)
  "Enable or disable motion detection alarm.  DP 134."
  (tuya:set-value (self 1) 134 (if flag true nil)))

(define (DoorbellDevice:set-indicator flag)
  "Enable or disable status indicator LED.  DP 101."
  (tuya:set-value (self 1) 101 (if flag true nil)))

(define (DoorbellDevice:set-motion-sensitivity level)
  "Set motion sensitivity: \"0\" (low), \"1\" (medium), \"2\" (high).  DP 106."
  (tuya:set-value (self 1) 106 level))

(define (DoorbellDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

(define (DoorbellDevice:status)
  (tuya:status (self 1)))

(define (DoorbellDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  IRRemoteControlDevice (WiFi IR blaster)
;; ====================================================================
;;
;; Follows tinytuya Contrib IRRemoteControlDevice.
;; Supports study mode (learn from a real remote) and playback.
;; Control type 1: older devices using DP 201/202
;; Control type 2: newer devices using DP 1-13
;;
;; IR encoding/decoding (base64, NEC, Pronto, etc.) is left to the
;; caller -- this class handles the device communication only.

(new Class 'IRRemoteControlDevice)

(define (IRRemoteControlDevice:IRRemoteControlDevice version ip device-id local-key
          (control-type 2))
  "Create an IR remote control device.
   control-type: 1 (older, DP 201/202) or 2 (newer, DP 1-13).
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip, 5=control-type."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list IRRemoteControlDevice dev device-id local-key ip control-type)))

(define (IRRemoteControlDevice:study-start)
  "Enter study mode (device listens for IR signals from a real remote)."
  (if (= (self 5) 1)
    (tuya:set-value (self 1) 201 "{\"control\":\"study_exit\"}")
    (tuya:set-value (self 1) 13 "study")))

(define (IRRemoteControlDevice:study-end)
  "Exit study mode."
  (if (= (self 5) 1)
    (tuya:set-value (self 1) 201 "{\"control\":\"study_exit\"}")
    (tuya:set-value (self 1) 13 "study_exit")))

(define (IRRemoteControlDevice:send-button base64-code)
  "Send a learned IR code (base64-encoded)."
  (if (= (self 5) 1)
    (tuya:set-value (self 1) 201
      (string "{\"control\":\"send_ir\",\"key1\":\"" base64-code "\"}"))
    (tuya:set-value (self 1) 7 base64-code)))

(define (IRRemoteControlDevice:send-key head key)
  "Send an IR head/key pair."
  (if (= (self 5) 1)
    (tuya:set-value (self 1) 201
      (string "{\"control\":\"send_ir\",\"head\":\"" head "\",\"key1\":\"" key "\"}"))
    (begin
      (tuya:set-value (self 1) 3 head)
      (tuya:set-value (self 1) 4 key)
      (tuya:set-value (self 1) 13 "send"))))

(define (IRRemoteControlDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

(define (IRRemoteControlDevice:status)
  (tuya:status (self 1)))

(define (IRRemoteControlDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  InverterHeatPumpDevice (pool/spa heat pumps)
;; ====================================================================
;;
;; Follows tinytuya Contrib InverterHeatPumpDevice.
;; DP 1: power (bool)
;; DP 102: inlet water temp (int)
;; DP 103: temp unit ("c"/"f")
;; DP 104: heating capacity percent (int)
;; DP 105: mode (string)
;; DP 106: target water temp (int)
;; DP 107: lower limit target temp (int)
;; DP 108: upper limit target temp (int)
;; DP 115: fault code (int)
;; DP 117: silence mode (bool)

(new Class 'InverterHeatPumpDevice)

(define (InverterHeatPumpDevice:InverterHeatPumpDevice version ip device-id local-key)
  "Create an inverter heat pump device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list InverterHeatPumpDevice dev device-id local-key ip)))

(define (InverterHeatPumpDevice:turn-on)
  (tuya:set-value (self 1) 1 true))

(define (InverterHeatPumpDevice:turn-off)
  (tuya:set-value (self 1) 1 nil))

(define (InverterHeatPumpDevice:set-target-temp temp)
  "Set target water temperature (integer, in device's current unit)."
  (tuya:set-value (self 1) 106 (int temp)))

(define (InverterHeatPumpDevice:set-silence-mode flag)
  "Enable or disable silence mode."
  (tuya:set-value (self 1) 117 (if flag true nil)))

(define (InverterHeatPumpDevice:set-temp-unit unit)
  "Set temperature unit: \"c\" or \"f\"."
  (tuya:set-value (self 1) 103 unit))

(define (InverterHeatPumpDevice:get-inlet-temp)
  "Read inlet water temperature from status.  Returns int or nil."
  (let (resp (tuya:status (self 1)))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (lookup "102" dps))))))))

(define (InverterHeatPumpDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

(define (InverterHeatPumpDevice:status)
  (tuya:status (self 1)))

(define (InverterHeatPumpDevice:destroy)
  (tuya-devices:destroy-device (self 1)))


;; ====================================================================
;;  PresenceDetectorDevice (mmWave presence sensors)
;; ====================================================================
;;
;; Follows tinytuya Contrib PresenceDetectorDevice.
;; DP 1: presence (bool, read-only)
;; DP 2: sensitivity (int)
;; DP 3: near detection distance (int, cm)
;; DP 4: far detection distance (int, cm)
;; DP 9: target distance (int, cm, read-only)
;; DP 101: detection delay (int, seconds)
;; DP 102: fading time (int, seconds)
;; DP 104: light sense (int, read-only)

(new Class 'PresenceDetectorDevice)

(define (PresenceDetectorDevice:PresenceDetectorDevice version ip device-id local-key)
  "Create a presence detector device.
   Fields: 0=class, 1=handle, 2=device-id, 3=local-key, 4=ip."
  (let (dev (tuya-devices:connect-device version ip device-id local-key))
    (list PresenceDetectorDevice dev device-id local-key ip)))

(define (PresenceDetectorDevice:set-sensitivity val)
  "Set detection sensitivity (int)."
  (tuya:set-value (self 1) 2 (int val)))

(define (PresenceDetectorDevice:set-near-detection dist)
  "Set near detection distance in cm."
  (tuya:set-value (self 1) 3 (int dist)))

(define (PresenceDetectorDevice:set-far-detection dist)
  "Set far detection distance in cm."
  (tuya:set-value (self 1) 4 (int dist)))

(define (PresenceDetectorDevice:set-detection-delay secs)
  "Set detection delay in seconds."
  (tuya:set-value (self 1) 101 (int secs)))

(define (PresenceDetectorDevice:set-fading-time secs)
  "Set fading time in seconds."
  (tuya:set-value (self 1) 102 (int secs)))

(define (PresenceDetectorDevice:reconnect)
  (tuya-devices:reconnect-device (self 1)))

(define (PresenceDetectorDevice:status)
  (tuya:status (self 1)))

(define (PresenceDetectorDevice:destroy)
  (tuya-devices:destroy-device (self 1)))
