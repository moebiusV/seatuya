; tuya-devices.lsp -- Context-based device classes for Tuya devices
;
; Convenience layer over seatuya.lsp.  TuyaDevice is the base class
; (mirrors tinytuya's Device).  Subclasses add named methods that map
; to the right data point (DP) numbers for each device category.
;
; Usage:
;   (load "tuya-devices.lsp")
;   (new TuyaDevice 'd)
;   (d "3.3" "192.168.1.50" "device-id" "local-key")
;   (d:turn-on 1)
;   (d:status)
;   (d:destroy)
;   (delete 'd)
;
;   (new OutletDevice 'my-plug)
;   (my-plug "3.3" "192.168.1.50" "device-id" "local-key")
;   (my-plug:turn-on)
;   (my-plug:destroy)
;   (delete 'my-plug)

(load (string (env "SEATUYA_LSP_DIR" (real-path ".")) "/seatuya.lsp"))

;; ====================================================================
;;  Shared utilities (tuya-devices context)
;; ====================================================================

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
;;  TuyaDevice (base class -- mirrors tinytuya's Device)
;; ====================================================================
;;
;; Provides turn-on, turn-off, set-value, status, heartbeat, reconnect,
;; destroy.  All subclasses inherit these via (new TuyaDevice 'SubClass).
;;
;; Constructor stores id, address, local-key, version as context variables
;; so they are accessible as d:id, d:address, d:local-key, d:version.

(context 'TuyaDevice)

(define (TuyaDevice:TuyaDevice _version _address _id _local-key)
  "Constructor: connect to a Tuya device."
  (setq id _id)
  (setq address _address)
  (setq local-key _local-key)
  (setq version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "TuyaDevice: connect failed to " address))))

(define (TuyaDevice:turn-on (dp 1))
  (tuya:turn-on handle dp))

(define (TuyaDevice:turn-off (dp 1))
  (tuya:turn-off handle dp))

(define (TuyaDevice:set-value dp val)
  (tuya:set-value handle dp val))

(define (TuyaDevice:status)
  (tuya:status handle))

(define (TuyaDevice:heartbeat)
  (tuya:heartbeat handle))

(define (TuyaDevice:reconnect)
  (tuya:reconnect handle))

(define (TuyaDevice:destroy)
  (when handle
    (when (tuya:is-connected handle) (tuya:disconnect handle))
    (tuya:destroy handle)
    (setq handle nil)))

(context MAIN)


;; ====================================================================
;;  OutletDevice (smart plugs, power strips, wall switches)
;; ====================================================================

(new TuyaDevice 'OutletDevice)

(define (OutletDevice:OutletDevice _version _address _id _local-key)
  "Constructor: connect to an outlet device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "OutletDevice: connect failed to " address))))

(define (OutletDevice:set-dimmer pct)
  "Set dimmer level.  pct is 0-100, mapped to device range 25-255 on DP 3."
  (tuya:set-value handle 3 (tuya-devices:pct-scale pct 25 255)))


;; ====================================================================
;;  BulbDevice (RGB/RGBW smart lighting)
;; ====================================================================
;;
;; Two DP layouts:
;;   Type A (legacy):  DP 1=switch, 2=mode, 3=brightness(25-255),
;;                     4=colourtemp(0-255), 5=colour
;;   Type B (common):  DP 20=switch, 21=mode, 22=brightness(10-1000),
;;                     23=colourtemp(0-1000), 24=colour, 25=scene

(new TuyaDevice 'BulbDevice)

(define (BulbDevice:BulbDevice _version _address _id _local-key (bulb-type "B"))
  "Constructor: connect to a bulb device.  bulb-type: \"A\" or \"B\" (default)."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "BulbDevice: connect failed to " address)))
  (setq type bulb-type)
  (if (= bulb-type "A")
    (map set '(dp-switch dp-mode dp-brightness dp-colourtemp dp-colour) '(1 2 3 4 5))
    (map set '(dp-switch dp-mode dp-brightness dp-colourtemp dp-colour) '(20 21 22 23 24))))

(define (BulbDevice:turn-on)
  (tuya:turn-on handle dp-switch))

(define (BulbDevice:turn-off)
  (tuya:turn-off handle dp-switch))

(define (BulbDevice:set-mode mode)
  "Set mode: \"white\", \"colour\", \"scene\", or \"music\"."
  (tuya:set-value handle dp-mode mode))

(define (BulbDevice:set-brightness val)
  "Set raw brightness value.  Type B: 10-1000, type A: 25-255."
  (tuya:set-value handle dp-brightness val))

(define (BulbDevice:set-brightness-pct pct)
  "Set brightness as a percentage (0-100)."
  (if (= type "A")
    (tuya:set-value handle dp-brightness (tuya-devices:pct-scale pct 25 255))
    (tuya:set-value handle dp-brightness (tuya-devices:pct-scale pct 10 1000))))

(define (BulbDevice:set-colourtemp val)
  "Set raw colour temperature.  Type B: 0-1000, type A: 0-255."
  (tuya:set-value handle dp-colourtemp val))

(define (BulbDevice:set-colourtemp-pct pct)
  "Set colour temperature as a percentage (0-100)."
  (if (= type "A")
    (tuya:set-value handle dp-colourtemp (tuya-devices:pct-scale pct 0 255))
    (tuya:set-value handle dp-colourtemp (tuya-devices:pct-scale pct 0 1000))))

(define (BulbDevice:set-colour r g b)
  "Set colour from RGB values (0-255 each).  Converts to HSV, encodes as hex,
   sets mode to colour, then writes the colour DP."
  (let (hsv (tuya-devices:rgb-to-hsv r g b)
        hex (if (= type "A")
              (tuya-devices:hsv-hex-a (hsv 0) (hsv 1) (hsv 2))
              (tuya-devices:hsv-hex-b (hsv 0) (hsv 1) (hsv 2))))
    (tuya:set-value handle dp-mode "colour")
    (tuya:set-value handle dp-colour hex)))

(define (BulbDevice:set-hsv h s v)
  "Set colour from HSV directly.  h=0-360, s and v use device scale
   (type B: 0-1000, type A: 0-255)."
  (let (hex (if (= type "A")
              (tuya-devices:hsv-hex-a h s v)
              (tuya-devices:hsv-hex-b h s v)))
    (tuya:set-value handle dp-mode "colour")
    (tuya:set-value handle dp-colour hex)))

(define (BulbDevice:set-white brightness colourtemp)
  "Set white mode with brightness and colour temperature (raw values)."
  (tuya:set-value handle dp-mode "white")
  (tuya:set-value handle dp-brightness brightness)
  (tuya:set-value handle dp-colourtemp colourtemp))


;; ====================================================================
;;  CoverDevice (blinds, curtains, garage doors)
;; ====================================================================
;;
;; 8 command type variations.  Set manually via set-cover-type.
;;
;;   1: "open"/"close"/"stop"         (default)
;;   2: true/false                    (garage doors, locks)
;;   3: "0"/"1"/"2"
;;   4: "00"/"01"/"02"/"03"           (03 = continue)
;;   5: "fopen"/"fclose"
;;   6: "on"/"off"/"stop"
;;   7: "up"/"down"/"stop"
;;   8: "ZZ"/"FZ"/"STOP"

(new TuyaDevice 'CoverDevice)

(setq CoverDevice:open-cmds  '(nil "open" true   "1" "00" "fopen"  "on" "up"   "ZZ"))
(setq CoverDevice:close-cmds '(nil "close" nil   "0" "01" "fclose" "off" "down" "FZ"))
(setq CoverDevice:stop-cmds  '(nil "stop"  nil   "2" "02" nil      "stop" "stop" "STOP"))

(define (CoverDevice:CoverDevice _version _address _id _local-key)
  "Constructor: connect to a cover device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "CoverDevice: connect failed to " address)))
  (setq cover-type 1))

(define (CoverDevice:set-cover-type typ)
  "Override cover type (1-8)."
  (setq cover-type typ))

(define (CoverDevice:open-cover)
  (tuya:set-value handle 1 (open-cmds cover-type)))

(define (CoverDevice:close-cover)
  (tuya:set-value handle 1 (close-cmds cover-type)))

(define (CoverDevice:stop-cover)
  (let (cmd (stop-cmds cover-type))
    (when cmd (tuya:set-value handle 1 cmd))))

(define (CoverDevice:set-position pct)
  "Set cover position (0-100).  Uses DP 2."
  (tuya:set-value handle 2 pct))


;; ====================================================================
;;  ThermostatDevice
;; ====================================================================
;;
;; Common DP layout (overridable via constructor):
;;   DP 1: switch (bool)
;;   DP 2: target temp (int, often x10)
;;   DP 3: current temp (int, read-only)
;;   DP 4: mode (enum: "heat"/"cool"/"auto"/"off")

(new TuyaDevice 'ThermostatDevice)

(define (ThermostatDevice:ThermostatDevice _version _address _id _local-key
          (_dp-switch 1) (_dp-target 2) (_dp-current 3) (_dp-mode 4) (_temp-scale 10))
  "Constructor: connect to a thermostat device.  DP numbers and temp-scale
   (divisor for raw values, e.g. 10 means device sends 720 for 72.0)
   are overridable."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "ThermostatDevice: connect failed to " address)))
  (setq dp-switch _dp-switch)
  (setq dp-target _dp-target)
  (setq dp-current _dp-current)
  (setq dp-mode _dp-mode)
  (setq temp-scale _temp-scale))

(define (ThermostatDevice:turn-on)
  (tuya:turn-on handle dp-switch))

(define (ThermostatDevice:turn-off)
  (tuya:turn-off handle dp-switch))

(define (ThermostatDevice:set-temperature temp)
  "Set target temperature.  Multiplied by temp-scale before sending."
  (tuya:set-value handle dp-target (int (round (mul temp temp-scale) 0))))

(define (ThermostatDevice:set-mode mode)
  "Set mode: \"heat\", \"cool\", \"auto\", or \"off\"."
  (tuya:set-value handle dp-mode mode))

(define (ThermostatDevice:get-temperature)
  "Read current temperature from device status.  Returns float or nil."
  (let (resp (tuya:status handle))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps
              (let (raw (lookup (string dp-current) dps))
                (when raw (div raw temp-scale))))))))))


;; ====================================================================
;;  SocketDevice (energy-monitoring smart sockets)
;; ====================================================================
;;
;; Follows tinytuya Contrib SocketDevice.
;; DP 1: switch (bool)
;; DP 18: current (mA)
;; DP 19: power (dW, divide by 10 for watts)
;; DP 20: voltage (dV, divide by 10 for volts)

(new TuyaDevice 'SocketDevice)

(define (SocketDevice:SocketDevice _version _address _id _local-key)
  "Constructor: connect to an energy-monitoring socket device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "SocketDevice: connect failed to " address))))

(define (SocketDevice:get-energy)
  "Query status and return assoc-list of current (mA), power (W), voltage (V)."
  (let (resp (tuya:status handle))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps
              (list
                (list "current_mA" (or (lookup "18" dps) 0))
                (list "power_W"    (div (or (lookup "19" dps) 0) 10.0))
                (list "voltage_V"  (div (or (lookup "20" dps) 0) 10.0))))))))))


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

(new TuyaDevice 'ClimateDevice)

(define (ClimateDevice:ClimateDevice _version _address _id _local-key)
  "Constructor: connect to a portable AC / climate device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "ClimateDevice: connect failed to " address))))

(define (ClimateDevice:set-temperature temp)
  "Set target temperature (integer, in device's current unit)."
  (tuya:set-value handle 2 (int temp)))

(define (ClimateDevice:get-temperature)
  "Read current room temperature from status.  Returns int or nil."
  (let (resp (tuya:status handle))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (lookup "3" dps))))))))

(define (ClimateDevice:set-mode mode)
  "Set operating mode: \"cold\", \"hot\", \"wind\", or \"auto\"."
  (tuya:set-value handle 4 mode))

(define (ClimateDevice:set-fan-speed speed)
  "Set fan speed: \"1\" (low), \"2\" (medium), \"3\" (high)."
  (tuya:set-value handle 5 speed))

(define (ClimateDevice:set-temp-unit unit)
  "Set temperature unit: \"c\" or \"f\"."
  (tuya:set-value handle 19 unit))

(define (ClimateDevice:set-timer minutes)
  "Set timer in minutes."
  (tuya:set-value handle 22 (int minutes)))


;; ====================================================================
;;  DoorbellDevice (video doorbells)
;; ====================================================================
;;
;; Follows tinytuya Contrib DoorbellDevice.
;; Note: most battery-powered doorbells stay offline to conserve power
;; and only connect briefly when the button is pressed or motion is
;; detected.  This class is most useful for mains-powered doorbells.

(new TuyaDevice 'DoorbellDevice)

(define (DoorbellDevice:DoorbellDevice _version _address _id _local-key)
  "Constructor: connect to a video doorbell device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "DoorbellDevice: connect failed to " address))))

(define (DoorbellDevice:set-volume vol)
  "Set device volume (1-10).  DP 160."
  (tuya:set-value handle 160 (int vol)))

(define (DoorbellDevice:set-motion-switch flag)
  "Enable or disable motion detection alarm.  DP 134."
  (tuya:set-value handle 134 (if flag true nil)))

(define (DoorbellDevice:set-indicator flag)
  "Enable or disable status indicator LED.  DP 101."
  (tuya:set-value handle 101 (if flag true nil)))

(define (DoorbellDevice:set-motion-sensitivity level)
  "Set motion sensitivity: \"0\" (low), \"1\" (medium), \"2\" (high).  DP 106."
  (tuya:set-value handle 106 level))


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

(new TuyaDevice 'IRRemoteControlDevice)

(define (IRRemoteControlDevice:IRRemoteControlDevice _version _address _id _local-key (_control-type 2))
  "Constructor: connect to an IR remote control device.
   control-type: 1 (older, DP 201/202) or 2 (newer, DP 1-13)."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "IRRemoteControlDevice: connect failed to " address)))
  (setq control-type _control-type))

(define (IRRemoteControlDevice:study-start)
  "Enter study mode (device listens for IR signals from a real remote)."
  (if (= control-type 1)
    (tuya:set-value handle 201 "{\"control\":\"study_exit\"}")
    (tuya:set-value handle 13 "study")))

(define (IRRemoteControlDevice:study-end)
  "Exit study mode."
  (if (= control-type 1)
    (tuya:set-value handle 201 "{\"control\":\"study_exit\"}")
    (tuya:set-value handle 13 "study_exit")))

(define (IRRemoteControlDevice:send-button base64-code)
  "Send a learned IR code (base64-encoded)."
  (if (= control-type 1)
    (tuya:set-value handle 201 (string "{\"control\":\"send_ir\",\"key1\":\"" base64-code "\"}"))
    (tuya:set-value handle 7 base64-code)))

(define (IRRemoteControlDevice:send-key head key)
  "Send an IR head/key pair."
  (if (= control-type 1)
    (tuya:set-value handle 201 (string "{\"control\":\"send_ir\",\"head\":\"" head "\",\"key1\":\"" key "\"}"))
    (begin
      (tuya:set-value handle 3 head)
      (tuya:set-value handle 4 key)
      (tuya:set-value handle 13 "send"))))


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

(new TuyaDevice 'InverterHeatPumpDevice)

(define (InverterHeatPumpDevice:InverterHeatPumpDevice _version _address _id _local-key)
  "Constructor: connect to an inverter heat pump device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "InverterHeatPumpDevice: connect failed to " address))))

(define (InverterHeatPumpDevice:set-target-temp temp)
  "Set target water temperature (integer, in device's current unit)."
  (tuya:set-value handle 106 (int temp)))

(define (InverterHeatPumpDevice:set-silence-mode flag)
  "Enable or disable silence mode."
  (tuya:set-value handle 117 (if flag true nil)))

(define (InverterHeatPumpDevice:set-temp-unit unit)
  "Set temperature unit: \"c\" or \"f\"."
  (tuya:set-value handle 103 unit))

(define (InverterHeatPumpDevice:get-inlet-temp)
  "Read inlet water temperature from status.  Returns int or nil."
  (let (resp (tuya:status handle))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (lookup "102" dps))))))))


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

(new TuyaDevice 'PresenceDetectorDevice)

(define (PresenceDetectorDevice:PresenceDetectorDevice _version _address _id _local-key)
  "Constructor: connect to a presence detector device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "PresenceDetectorDevice: connect failed to " address))))

(define (PresenceDetectorDevice:set-sensitivity val)
  "Set detection sensitivity (int)."
  (tuya:set-value handle 2 (int val)))

(define (PresenceDetectorDevice:set-near-detection dist)
  "Set near detection distance in cm."
  (tuya:set-value handle 3 (int dist)))

(define (PresenceDetectorDevice:set-far-detection dist)
  "Set far detection distance in cm."
  (tuya:set-value handle 4 (int dist)))

(define (PresenceDetectorDevice:set-detection-delay secs)
  "Set detection delay in seconds."
  (tuya:set-value handle 101 (int secs)))

(define (PresenceDetectorDevice:set-fading-time secs)
  "Set fading time in seconds."
  (tuya:set-value handle 102 (int secs)))
