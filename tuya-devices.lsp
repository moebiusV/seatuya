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

(load (string (or (env "SEATUYA_LSP_DIR") (real-path ".")) "/seatuya.lsp"))

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
;; Constructor stores id, address, local-key, version as context
;; variables so they are accessible as d:id, d:address, etc.
;;
;; Connection retry lives in the C transport layer (like tinytuya's
;; _send_receive), not here.  These methods are simple pass-throughs.

(context 'TuyaDevice)

(define (TuyaDevice:TuyaDevice _version _address _id _local-key (opts '()))
  "Constructor: connect to a Tuya device.
   opts is an optional association list.  Keys:
     :cloud-region  - enable cloud mode (e.g. \"us\", \"eu\")
     :cloud-id      - Tuya cloud access ID
     :cloud-secret  - Tuya cloud access secret
   When cloud mode is enabled, all operations go through the
   Tuya Cloud REST API instead of local TCP.  Requires crypto.lsp
   and libtls.lsp."
  (setq id _id)
  (setq address _address)
  (setq local-key _local-key)
  (setq version _version)
  (setq cloud? (lookup ":cloud-region" opts))
  (when cloud?
    (setq cloud-region cloud?)
    (setq cloud-id (or (lookup ":cloud-id" opts) (env "TUYA_ACCESS_ID")))
    (setq cloud-secret (or (lookup ":cloud-secret" opts) (env "TUYA_ACCESS_SECRET")))
    (setq access-token nil token-expiry nil)
    (unless (and cloud-id cloud-secret)
      (throw "Cloud mode requires :cloud-id and :cloud-secret in opts or TUYA_ACCESS_ID/TUYA_ACCESS_SECRET env vars")))
  (if cloud?
    (begin
      (setq handle nil)
      (TuyaDevice:cloud-token)
      (println (string "TuyaDevice: cloud mode " cloud-region " for device " id)))
    (begin
      (setq handle (tuya:create id address local-key version))
      (unless handle (throw (string "TuyaDevice: connect failed to " address))))))

(define (TuyaDevice:turn-on (dp 1))
  (if cloud?
    (TuyaDevice:cloud-cmd id (list (list (string dp) true)))
    (tuya:turn-on handle dp)))

(define (TuyaDevice:turn-off (dp 1))
  (if cloud?
    (TuyaDevice:cloud-cmd id (list (list (string dp) false)))
    (tuya:turn-off handle dp)))

(define (TuyaDevice:set-value dp val)
  (if cloud?
    (TuyaDevice:cloud-cmd id (list (list (string dp) val)))
    (tuya:set-value handle dp val)))

(define (TuyaDevice:status)
  (if cloud?
    (let (resp (TuyaDevice:cloud-cmd id nil))
      (and resp resp))
    (tuya:status handle)))

(define (TuyaDevice:heartbeat)
  (tuya:heartbeat handle))

(define (TuyaDevice:reconnect)
  (tuya:reconnect handle))

(define (TuyaDevice:destroy)
  (when handle
    (when (and (not cloud?) (tuya:is-connected handle)) (tuya:disconnect handle))
    (when (not cloud?) (tuya:destroy handle))
    (setq handle nil)))

(define (TuyaDevice:detect-dps (start 1) (end 130) (step 1))
  "Probe the device for supported data points in range start-end.
   Queries status and returns a sorted list of DP numbers that
   returned a value."
  (let (resp (status) found '())
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps
          (dolist (i (sequence start end step))
            (when (lookup (string i) dps)
              (push i found -1))))))
    (sort found)))

;; ── Internal cloud helper ──
(define (TuyaDevice:cloud-token)
  "Get or refresh cloud OAuth2 token."
  (when (and cloud? (not access-token))
    (let (now (date-value)
          ts (string (int (div now 1000)))
          path "/v1.0/token?grant_type=1"
          canon (string "GET\n" (hmac-sha256 "" "" true) "\n\n\n" path)
          sig  (hmac-sha256 canon cloud-secret)
          sign (join (map (fn (x) (format "%02x" x)) (unpack "b" sig)) "")
          headers (list
            (list "client_id" cloud-id)
            (list "sign" sign)
            (list "sign_method" "HMAC-SHA256")
            (list "t" ts)
            (list "nonce" (string (time-of-day)))
            (list "Content-Type" "application/json")))
      (let (resp (tls-get (string "openapi.tuyacn." cloud-region ".com") path headers))
        (when resp
          (let (parsed (json-parse resp))
            (when parsed (setq access-token (lookup "access_token" parsed) token-expiry (+ now (* 60 60 1000))))))))))

(define (TuyaDevice:cloud-cmd device-id dps-map)
  "Send DP values via cloud REST API."
  (TuyaDevice:cloud-token)
  (when access-token
    (let (path (string "/v1.0/devices/" device-id "/commands")
          body (json-json (list
            (list "commands" (list (list "code" (string (first (first dps-map))) "value" (last (first dps-map)))))))
          headers (list
            (list "client_id" cloud-id)
            (list "access_token" access-token)
            (list "sign_method" "HMAC-SHA256")))
      (tls-post (string "openapi.tuyacn." cloud-region ".com") path body headers))))

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
  (set-value 3 (tuya-devices:pct-scale pct 25 255)))


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

(define (BulbDevice:BulbDevice _version _address _id _local-key (bulb-type "auto"))
  "Constructor: connect to a bulb device.  bulb-type:
   \"A\" (legacy: DP 1-5), \"B\" (common: DP 20-25, default),
   \"C\" (simple white: DP 1-3, no colour), \"auto\" (probes device).
   Type A:  DP 1=switch, 2=mode, 3=brightness(25-255), 4=colourtemp(0-255), 5=colour
   Type B:  DP 20=switch, 21=mode, 22=brightness(10-1000), 23=colourtemp(0-1000), 24=colour, 25=scene
   Type C:  DP 1=switch, 2=brightness(10-1000), 3=colourtemp(0-1000).  White-only, no colour/scene/music."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "BulbDevice: connect failed to " address)))
  (if (= bulb-type "auto")
    (BulbDevice:auto-detect-type)
    (BulbDevice:set-type bulb-type)))

(define (BulbDevice:set-type bulb-type)
  "Configure DP layout for a known bulb type."
  (setq type bulb-type)
  (cond
    ((= bulb-type "A")
     (map set '(dp-switch dp-mode dp-brightness dp-colourtemp dp-colour) '(1 2 3 4 5)))
    ((= bulb-type "B")
     (map set '(dp-switch dp-mode dp-brightness dp-colourtemp dp-colour) '(20 21 22 23 24)))
    ((= bulb-type "C")
     (map set '(dp-switch dp-mode dp-brightness dp-colourtemp dp-colour) '(1 nil 2 3 nil)))))

(define (BulbDevice:auto-detect-type)
  "Query device and determine bulb type from which DPs are present."
  (let (resp (status) detected nil)
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps
          ;; Type C: has DP 2 (brightness) and DP 3 (colourtemp) but no DP 5 or DP 24 (colour)
          (if (and (lookup "2" dps) (lookup "3" dps)
                   (not (lookup "5" dps)) (not (lookup "24" dps)))
            (setq detected "C")
          ;; Type B: has DP 20-24 range
          (if (or (lookup "20" dps) (lookup "22" dps) (lookup "24" dps))
            (setq detected "B")
          ;; Type A: has DP 1-5 range
          (if (lookup "5" dps)
            (setq detected "A")
            (setq detected "B")))))))  ; default fallback
    (BulbDevice:set-type detected)
    (println (string "BulbDevice: auto-detected type " detected))))

(define (BulbDevice:turn-on)
  (set-value dp-switch true))

(define (BulbDevice:turn-off)
  (set-value dp-switch nil))

(define (BulbDevice:set-mode mode)
  "Set mode: \"white\", \"colour\", \"scene\", or \"music\"."
  (set-value dp-mode mode))

(define (BulbDevice:set-brightness val)
  "Set raw brightness value.  Type B: 10-1000, type A: 25-255."
  (set-value dp-brightness val))

(define (BulbDevice:set-brightness-pct pct)
  "Set brightness as a percentage (0-100)."
  (if (= type "A")
    (set-value dp-brightness (tuya-devices:pct-scale pct 25 255))
    (set-value dp-brightness (tuya-devices:pct-scale pct 10 1000))))

(define (BulbDevice:set-colourtemp val)
  "Set raw colour temperature.  Type B: 0-1000, type A: 0-255."
  (set-value dp-colourtemp val))

(define (BulbDevice:set-colourtemp-pct pct)
  "Set colour temperature as a percentage (0-100)."
  (if (= type "A")
    (set-value dp-colourtemp (tuya-devices:pct-scale pct 0 255))
    (set-value dp-colourtemp (tuya-devices:pct-scale pct 0 1000))))

(define (BulbDevice:set-colour r g b)
  "Set colour from RGB values (0-255 each).  Converts to HSV, encodes as hex,
   sets mode to colour, then writes the colour DP."
  (let (hsv (tuya-devices:rgb-to-hsv r g b)
        hex (if (= type "A")
              (tuya-devices:hsv-hex-a (hsv 0) (hsv 1) (hsv 2))
              (tuya-devices:hsv-hex-b (hsv 0) (hsv 1) (hsv 2))))
    (set-value dp-mode "colour")
    (set-value dp-colour hex)))

(define (BulbDevice:set-hsv h s v)
  "Set colour from HSV directly.  h=0-360, s and v use device scale
   (type B: 0-1000, type A: 0-255)."
  (let (hex (if (= type "A")
              (tuya-devices:hsv-hex-a h s v)
              (tuya-devices:hsv-hex-b h s v)))
    (set-value dp-mode "colour")
    (set-value dp-colour hex)))

(define (BulbDevice:set-white brightness colourtemp)
  "Set white mode with brightness and colour temperature (raw values)."
  (set-value dp-mode "white")
  (set-value dp-brightness brightness)
  (set-value dp-colourtemp colourtemp))


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

(define (CoverDevice:auto-detect-type)
  "Query device status and determine cover command type from DP 1 value."
  (let (resp (status) val nil)
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps (setq val (lookup "1" dps)))))
    (when val
      (cond
        ((or (= val "open") (= val "close") (= val "stop")) (setq cover-type 1))
        ((or (= val true) (= val false)) (setq cover-type 2))
        ((member val '("0" "1" "2")) (setq cover-type 3))
        ((member val '("00" "01" "02" "03")) (setq cover-type 4))
        ((or (= val "fopen") (= val "fclose")) (setq cover-type 5))
        ((or (= val "on") (= val "off") (= val "stop")) (setq cover-type 6))
        ((or (= val "up") (= val "down") (= val "stop")) (setq cover-type 7))
        ((or (= val "ZZ") (= val "FZ") (= val "STOP")) (setq cover-type 8))
        (true (setq cover-type 1))))
    (println (string "CoverDevice: auto-detected type " cover-type))))

(define (CoverDevice:open-cover)
  (set-value 1 (open-cmds cover-type)))

(define (CoverDevice:close-cover)
  (set-value 1 (close-cmds cover-type)))

(define (CoverDevice:stop-cover)
  (let (cmd (stop-cmds cover-type))
    (when cmd (set-value 1 cmd))))

(define (CoverDevice:set-position pct)
  "Set cover position (0-100).  Uses DP 2."
  (set-value 2 pct))


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
  (set-value dp-switch true))

(define (ThermostatDevice:turn-off)
  (set-value dp-switch nil))

(define (ThermostatDevice:set-temperature temp)
  "Set target temperature.  Multiplied by temp-scale before sending."
  (set-value dp-target (int (round (mul temp temp-scale) 0))))

(define (ThermostatDevice:set-mode mode)
  "Set mode: \"heat\", \"cool\", \"auto\", or \"off\"."
  (set-value dp-mode mode))

(define (ThermostatDevice:get-temperature)
  "Read current temperature from device status.  Returns float or nil."
  (let (resp (status))
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
  (let (resp (status))
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
  (set-value 2 (int temp)))

(define (ClimateDevice:get-temperature)
  "Read current room temperature from status.  Returns int or nil."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (lookup "3" dps))))))))

(define (ClimateDevice:set-mode mode)
  "Set operating mode: \"cold\", \"hot\", \"wind\", or \"auto\"."
  (set-value 4 mode))

(define (ClimateDevice:set-fan-speed speed)
  "Set fan speed: \"1\" (low), \"2\" (medium), \"3\" (high)."
  (set-value 5 speed))

(define (ClimateDevice:set-temp-unit unit)
  "Set temperature unit: \"c\" or \"f\"."
  (set-value 19 unit))

(define (ClimateDevice:set-timer minutes)
  "Set timer in minutes."
  (set-value 22 (int minutes)))


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
  (set-value 160 (int vol)))

(define (DoorbellDevice:set-motion-switch flag)
  "Enable or disable motion detection alarm.  DP 134."
  (set-value 134 (if flag true nil)))

(define (DoorbellDevice:set-indicator flag)
  "Enable or disable status indicator LED.  DP 101."
  (set-value 101 (if flag true nil)))

(define (DoorbellDevice:set-motion-sensitivity level)
  "Set motion sensitivity: \"0\" (low), \"1\" (medium), \"2\" (high).  DP 106."
  (set-value 106 level))


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
    (set-value 201 "{\"control\":\"study_exit\"}")
    (set-value 13 "study")))

(define (IRRemoteControlDevice:study-end)
  "Exit study mode."
  (if (= control-type 1)
    (set-value 201 "{\"control\":\"study_exit\"}")
    (set-value 13 "study_exit")))

(define (IRRemoteControlDevice:send-button base64-code)
  "Send a learned IR code (base64-encoded)."
  (if (= control-type 1)
    (set-value 201 (string "{\"control\":\"send_ir\",\"key1\":\"" base64-code "\"}"))
    (set-value 7 base64-code)))

(define (IRRemoteControlDevice:send-key head key)
  "Send an IR head/key pair."
  (if (= control-type 1)
    (set-value 201 (string "{\"control\":\"send_ir\",\"head\":\"" head "\",\"key1\":\"" key "\"}"))
    (begin
      (set-value 3 head)
      (set-value 4 key)
      (set-value 13 "send"))))


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
  (set-value 106 (int temp)))

(define (InverterHeatPumpDevice:set-silence-mode flag)
  "Enable or disable silence mode."
  (set-value 117 (if flag true nil)))

(define (InverterHeatPumpDevice:set-temp-unit unit)
  "Set temperature unit: \"c\" or \"f\"."
  (set-value 103 unit))

(define (InverterHeatPumpDevice:get-inlet-temp)
  "Read inlet water temperature from status.  Returns int or nil."
  (let (resp (status))
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
  (set-value 2 (int val)))

(define (PresenceDetectorDevice:set-near-detection dist)
  "Set near detection distance in cm."
  (set-value 3 (int dist)))

(define (PresenceDetectorDevice:set-far-detection dist)
  "Set far detection distance in cm."
  (set-value 4 (int dist)))

(define (PresenceDetectorDevice:set-detection-delay secs)
  "Set detection delay in seconds."
  (set-value 101 (int secs)))

(define (PresenceDetectorDevice:set-fading-time secs)
  "Set fading time in seconds."
  (set-value 102 (int secs)))

(define (PresenceDetectorDevice:presence?)
  "Query presence state from status.  Returns true/nil or nil on error."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (= (lookup "1" dps) true))))))))

(define (PresenceDetectorDevice:get-sensitivity)
  "Read current sensitivity setting."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (int (or (lookup "2" dps) 0)))))))))

(define (PresenceDetectorDevice:get-near-detection)
  "Read near detection distance from status.  Returns int or nil."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (int (or (lookup "3" dps) 0)))))))))

(define (PresenceDetectorDevice:get-far-detection)
  "Read far detection distance from status.  Returns int or nil."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed))
            (when dps (int (or (lookup "4" dps) 0)))))))))


;; ====================================================================
;;  BlanketDevice (dual-zone electric heating blankets)
;; ====================================================================
;;
;; Follows tinytuya Contrib BlanketDevice.
;; Protocol: v3.3 (typical).  Dual-zone control with per-zone heat
;; levels and independent timers.  Heat levels are encoded as strings
;; "level_1" through "level_7" (mapping to user values 0-6).
;;
;; DP 14: body heat level  (string: "level_1".."level_7")
;; DP 15: feet heat level   (string: "level_1".."level_7")
;; DP 16: body timer        (string: "1h".."12h")
;; DP 17: feet timer        (string: "1h".."12h")
;; DP 18: body countdown    (int, remaining hours, read-only)
;; DP 19: feet countdown    (int, remaining hours, read-only)

(new TuyaDevice 'BlanketDevice)

(define (BlanketDevice:BlanketDevice _version _address _id _local-key)
  "Constructor: connect to a dual-zone electric blanket."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "BlanketDevice: connect failed to " address))))

(define (BlanketDevice:set-body-level n)
  "Set body heat level (0-6).  Maps to device strings level_1..level_7."
  (when (and (>= n 0) (<= n 6))
    (set-value 14 (string "level_" (+ n 1)))))

(define (BlanketDevice:set-feet-level n)
  "Set feet heat level (0-6)."
  (when (and (>= n 0) (<= n 6))
    (set-value 15 (string "level_" (+ n 1)))))

(define (BlanketDevice:set-body-time hours)
  "Set body zone timer (1-12 hours)."
  (when (and (>= hours 1) (<= hours 12))
    (set-value 16 (string hours "h"))))

(define (BlanketDevice:set-feet-time hours)
  "Set feet zone timer (1-12 hours)."
  (when (and (>= hours 1) (<= hours 12))
    (set-value 17 (string hours "h"))))

(define (BlanketDevice:get-body-level)
  "Read current body heat level (0-6 or nil)."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed) raw (when dps (lookup "14" dps)))
            (when raw (- (int (slice raw 6)) 1))))))))

(define (BlanketDevice:get-feet-level)
  "Read current feet heat level (0-6 or nil)."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed) raw (when dps (lookup "15" dps)))
            (when raw (- (int (slice raw 6)) 1))))))))

(define (BlanketDevice:get-body-time)
  "Read body timer remaining (int hours or nil)."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed) raw (when dps (lookup "16" dps)))
            (when raw (int (chop raw)))))))))

(define (BlanketDevice:get-feet-time)
  "Read feet timer remaining (int hours or nil)."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed) raw (when dps (lookup "17" dps)))
            (when raw (int (chop raw)))))))))


;; ====================================================================
;;  FloorFanDevice (standing/pedestal floor fans)
;; ====================================================================
;;
;; Follows tinytuya Contrib FloorFanDevice.
;; Protocol: v3.3 (typical).
;;
;; DP 1:  power (bool)
;; DP 2:  speed (enum: "1".."5" for speeds 1-5)
;; DP 3:  mode  (enum: "normal", "nature", "sleep")
;; DP 4:  oscillation (bool)
;; DP 14: setoff timer (int, minutes)

(new TuyaDevice 'FloorFanDevice)

(define (FloorFanDevice:FloorFanDevice _version _address _id _local-key)
  "Constructor: connect to a floor fan device."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "FloorFanDevice: connect failed to " address))))

(define (FloorFanDevice:set-speed n)
  "Set fan speed (1-5)."
  (when (and (>= n 1) (<= n 5))
    (set-value 2 (string n))))

(define (FloorFanDevice:set-mode mode)
  "Set wind mode: \"normal\", \"nature\", or \"sleep\"."
  (set-value 3 mode))

(define (FloorFanDevice:set-oscillation flag)
  "Enable or disable oscillation."
  (set-value 4 (if flag true nil)))

(define (FloorFanDevice:set-timer minutes)
  "Set auto-off timer in minutes."
  (set-value 14 (int minutes)))

(define (FloorFanDevice:get-speed)
  "Read current speed (int 1-5 or nil)."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp))
        (when parsed
          (let (dps (lookup "dps" parsed) raw (when dps (lookup "2" dps)))
            (when raw (int raw))))))))


;; ====================================================================
;;  RFRemoteControlDevice (WiFi RF remote blaster)
;; ====================================================================
;;
;; Extends IRRemoteControlDevice.  Adds RF-specific study and send
;; modes using the CMT2300A radio configuration banks.
;; Protocol: v3.3 or 3.4 depending on device generation.
;;
;; DP 201: control JSON for type-1 (older)
;; DP 1-13: distributed control for type-2 (newer)
;; Shared DPs with IRRemoteControlDevice via inherited methods.

(new TuyaDevice 'RFRemoteControlDevice)

(define (RFRemoteControlDevice:RFRemoteControlDevice _version _address _id _local-key (_control-type 2))
  "Constructor: connect to an RF remote control device.
   control-type: 1 (older, DP 201) or 2 (newer, DP 1-13)."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "RFRemoteControlDevice: connect failed to " address)))
  (setq control-type _control-type))

(define (RFRemoteControlDevice:rf-study-start)
  "Enter RF study mode (device listens for RF signals from a real remote)."
  (if (= control-type 1)
    (set-value 201 "{\"control\":\"study\"}")
    (set-value 13 "rf_study")))

(define (RFRemoteControlDevice:rf-study-end)
  "Exit RF study mode."
  (if (= control-type 1)
    (set-value 201 "{\"control\":\"study_exit\"}")
    (set-value 13 "rf_study_exit")))

(define (RFRemoteControlDevice:send-rf-key base64-code)
  "Send a learned RF code (base64-encoded)."
  (if (= control-type 1)
    (set-value 201 (string "{\"control\":\"send_rf\",\"key1\":\"" base64-code "\"}"))
    (set-value 8 base64-code)))

(define (RFRemoteControlDevice:set-rf-config-bank bank)
  "Set CMT2300A radio configuration bank for RF transmission."
  (when (and (>= bank 1) (<= bank 4))
    (if (= control-type 1)
      (set-value 202 (int bank))
      (set-value 6 (int bank)))))

(define (RFRemoteControlDevice:set-rf-frequency freq-khz)
  "Set RF frequency in kHz (e.g. 433920 for 433.92 MHz)."
  (if (= control-type 1)
    (set-value 201 (string "{\"control\":\"set_freq\",\"freq\":" freq-khz "}"))
    (set-value 9 (int freq-khz))))


;; ====================================================================
;;  WiFiDualMeterDevice (dual-channel energy meter)
;; ====================================================================
;;
;; Follows tinytuya Contrib WiFiDualMeterDevice.
;; Protocol: v3.3 (typical).
;; 27 DPs — forward/reverse energy, power, voltage, current,
;; power factor, frequency, and calibration constants — per channel.
;;
;; DP 1:   forward energy total (kWh × 100)
;; DP 2:   reverse energy total (kWh × 100)
;; DP 101: power channel A (dW, ÷10 for W)
;; DP 102: current direction A (enum: "FORWARD"/"REVERSE")
;; DP 104: current direction B (enum)
;; DP 105: power channel B (dW, ÷10 for W)
;; DP 106: forward energy A (kWh × 100)
;; DP 107: reverse energy A (kWh × 100)
;; DP 108: forward energy B (kWh × 100)
;; DP 109: reverse energy B (kWh × 100)
;; DP 110: power factor A (×100)
;; DP 111: AC frequency (Hz × 100)
;; DP 112: AC voltage (dV, ÷10 for V)
;; DP 113: current A (mA)
;; DP 114: current B (mA)
;; DP 115: total power (dW, ÷10 for W)
;; DP 116-128: calibration constants (×1000 or ×100)
;; DP 129: report rate (seconds)

(new TuyaDevice 'WiFiDualMeterDevice)

(define (WiFiDualMeterDevice:WiFiDualMeterDevice _version _address _id _local-key)
  "Constructor: connect to a dual-channel WiFi energy meter."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "WiFiDualMeterDevice: connect failed to " address))))

(define (WiFiDualMeterDevice:get-all)
  "Read all meter values.  Returns assoc-list with decoded units."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps
          (list
            (list "power_A_W"        (div (or (lookup "101" dps) 0) 10.0))
            (list "power_B_W"        (div (or (lookup "105" dps) 0) 10.0))
            (list "total_power_W"    (div (or (lookup "115" dps) 0) 10.0))
            (list "voltage_V"        (div (or (lookup "112" dps) 0) 10.0))
            (list "current_A_mA"     (or (lookup "113" dps) 0))
            (list "current_B_mA"     (or (lookup "114" dps) 0))
            (list "freq_Hz"          (div (or (lookup "111" dps) 0) 100.0))
            (list "pf_A"             (div (or (lookup "110" dps) 0) 100.0))
            (list "fwd_energy_kWh"   (div (or (lookup "1" dps) 0) 100.0))
            (list "rev_energy_kWh"   (div (or (lookup "2" dps) 0) 100.0))
            (list "fwd_energy_A_kWh" (div (or (lookup "106" dps) 0) 100.0))
            (list "rev_energy_A_kWh" (div (or (lookup "107" dps) 0) 100.0))
            (list "fwd_energy_B_kWh" (div (or (lookup "108" dps) 0) 100.0))
            (list "rev_energy_B_kWh" (div (or (lookup "109" dps) 0) 100.0))
            (list "dir_A"            (or (lookup "102" dps) "UNKNOWN"))
            (list "dir_B"            (or (lookup "104" dps) "UNKNOWN"))
            (list "report_rate_s"    (or (lookup "129" dps) 0))))))))

(define (WiFiDualMeterDevice:get-power)
  "Read total power in watts."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps (div (or (lookup "115" dps) 0) 10.0))))))

(define (WiFiDualMeterDevice:get-voltage)
  "Read AC voltage in volts."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps (div (or (lookup "112" dps) 0) 10.0))))))


;; ====================================================================
;;  TowelRailHeaterDevice (heated towel rails)
;; ====================================================================
;;
;; Follows tinytuya Contrib TowelRailHeaterDevice.
;; Protocol: v3.4 (session key negotiation).
;;
;; DP 1:   power (bool)
;; DP 2:   mode (enum: "cold", "hot", "eco", "auto")
;; DP 16:  target temperature (Celsius × 10)
;; DP 24:  current temperature (Celsius × 10, read-only)
;; DP 111: timer (Tuya units: 10 = 1 hour, 30-minute increments)

(new TuyaDevice 'TowelRailHeaterDevice)

(define (TowelRailHeaterDevice:TowelRailHeaterDevice _version _address _id _local-key)
  "Constructor: connect to a towel rail heater."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "TowelRailHeaterDevice: connect failed to " address))))

(define (TowelRailHeaterDevice:set-temp temp-c)
  "Set target temperature in Celsius (e.g. 45.0)."
  (set-value 16 (int (round (mul temp-c 10) 0))))

(define (TowelRailHeaterDevice:get-temp)
  "Read current temperature in Celsius.  Returns float or nil."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps (div (or (lookup "24" dps) 0) 10.0))))))

(define (TowelRailHeaterDevice:set-mode mode)
  "Set operating mode: \"cold\", \"hot\", \"eco\", or \"auto\"."
  (set-value 2 mode))

(define (TowelRailHeaterDevice:set-timer hours)
  "Set timer in hours (0.5 to 8, in 30-min increments).
   Converts to Tuya timer units (10 = 1 hour)."
  (let (units (int (round (mul hours 10) 0)))
    (set-value 111 units)))


;; ====================================================================
;;  AtorchTemperatureControllerDevice (ATORCH S1TW smart outlet)
;; ====================================================================
;;
;; Follows tinytuya Contrib AtorchTemperatureControllerDevice.
;; Protocol: v3.3 (typical).
;; A temperature-controlled outlet with built-in energy monitoring.
;;
;; DP 1:  power (bool)
;; DP 2:  target temperature (Celsius × 10)
;; DP 3:  current temperature (Celsius × 10, read-only)
;; DP 4:  mode (enum: "HT"=heating, "CL"=cooling, "OFF")
;; DP 5:  temperature unit (enum: "C" or "F")
;; DP 18: current (mA, read-only)
;; DP 19: power (W, read-only)  -- note: watts, not deciwatts
;; DP 20: voltage (V, read-only)
;; DP 21: accumulated energy (kWh × 100, read-only)

(new TuyaDevice 'AtorchTemperatureControllerDevice)

(define (AtorchTemperatureControllerDevice:AtorchTemperatureControllerDevice _version _address _id _local-key)
  "Constructor: connect to an ATORCH S1TW temperature controller."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "AtorchTemperatureControllerDevice: connect failed to " address))))

(define (AtorchTemperatureControllerDevice:set-temp temp-c)
  "Set target temperature in Celsius."
  (set-value 2 (int (round (mul temp-c 10) 0))))

(define (AtorchTemperatureControllerDevice:get-temp)
  "Read current temperature in Celsius.  Returns float or nil."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps (div (or (lookup "3" dps) 0) 10.0))))))

(define (AtorchTemperatureControllerDevice:set-mode mode)
  "Set operating mode: \"HT\" (heat), \"CL\" (cool), or \"OFF\"."
  (set-value 4 mode))

(define (AtorchTemperatureControllerDevice:set-unit unit)
  "Set temperature unit: \"C\" or \"F\"."
  (set-value 5 unit))

(define (AtorchTemperatureControllerDevice:get-power)
  "Read current power draw in watts."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps (or (lookup "19" dps) 0))))))

(define (AtorchTemperatureControllerDevice:get-energy)
  "Read accumulated energy in kWh.  Returns float or nil."
  (let (resp (status))
    (when resp
      (let (parsed (json-parse resp) dps (when parsed (lookup "dps" parsed)))
        (when dps (div (or (lookup "21" dps) 0) 100.0))))))


;; ====================================================================
;;  ColorfulX7Device (SP107E LED Music Controller)
;; ====================================================================
;;
;; Follows tinytuya Contrib ColorfulX7Device.
;; Protocol: v3.3.  Controls up to 1024 addressable RGB pixels with
;; 180 dynamic scenes, 22 music modes, and 30 matrix patterns.
;;
;; DP  1: power (bool)
;; DP  2: work mode (enum: "music", "scene", "auto", "static")
;; DP  3: brightness (0-100)
;; DP  4: speed (0-100)
;; DP  5: scene number (1-180)
;; DP  6: pixel count (1-1024)
;; DP  7: LED brand / chip type
;; DP  8: RGB sequence
;; DP  9: direction
;; DP 10: static colour (hex)
;; DP 11: music mode number (0-22)
;; DP 12: matrix mode number (0-30)
;; DP 13: MIC sensitivity (0-100)

(new TuyaDevice 'ColorfulX7Device)

(define (ColorfulX7Device:ColorfulX7Device _version _address _id _local-key)
  "Constructor: connect to a Colorful-X7 LED music controller."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "ColorfulX7Device: connect failed to " address))))

(define (ColorfulX7Device:set-scene n)
  "Set scene number (1-180)."
  (when (and (>= n 1) (<= n 180))
    (set-value 2 "scene")
    (set-value 5 n)))

(define (ColorfulX7Device:set-music-mode n)
  "Set music mode (0-22).  0=off, 1-22=modes."
  (when (and (>= n 0) (<= n 22))
    (set-value 2 "music")
    (set-value 11 n)))

(define (ColorfulX7Device:set-matrix-mode n)
  "Set matrix mode (0-30)."
  (when (and (>= n 0) (<= n 30))
    (set-value 12 n)))

(define (ColorfulX7Device:set-brightness pct)
  "Set brightness (0-100)."
  (when (and (>= pct 0) (<= pct 100))
    (set-value 3 pct)))

(define (ColorfulX7Device:set-speed pct)
  "Set animation speed (0-100)."
  (when (and (>= pct 0) (<= pct 100))
    (set-value 4 pct)))

(define (ColorfulX7Device:set-pixel-count n)
  "Set number of addressable LEDs (1-1024)."
  (when (and (>= n 1) (<= n 1024))
    (set-value 6 n)))

(define (ColorfulX7Device:set-mic-sensitivity pct)
  "Set microphone sensitivity (0-100)."
  (when (and (>= pct 0) (<= pct 100))
    (set-value 13 pct)))

(define (ColorfulX7Device:set-static-colour r g b)
  "Set static colour from RGB (0-255 each).  Encoded as 6-char hex."
  (set-value 2 "static")
  (set-value 10 (format "%02x%02x%02x" r g b)))

(define (ColorfulX7Device:set-led-brand brand)
  "Set LED chip type (e.g. \"WS2811\", \"WS2812\", \"SK6812\")."
  (set-value 7 brand))

(define (ColorfulX7Device:set-rgb-sequence seq)
  "Set RGB colour order (e.g. \"RGB\", \"GRB\", \"BGR\")."
  (set-value 8 seq))


;; ====================================================================
;;  SoriaInverterDevice (Soria solar micro-inverter)
;; ====================================================================
;;
;; Follows tinytuya Contrib SoriaInverterDevice.
;; Protocol: v3.3 with persistent async mode.  This device is unusual:
;; it does NOT respond to status queries — it pushes Base64-encoded
;; TLV (Type-Length-Value) binary frames every ~2 seconds (realtime)
;; and ~60 seconds (full report).  You must poll via receive() in
;; async mode to get data.
;;
;; Designed for use with persistent async mode:
;;   1. Enable async mode: (tuya:set-async-mode handle true)
;;   2. Poll: (tuya:receive handle 1024)
;;   3. Decode: (SoriaInverterDevice:decode-frame raw-bytes)
;;
;; NOTE: Base64/TLV frame decoding is application-level and left to
;; the caller.  This class manages the device connection and provides
;; the async-mode setup.  Raw frame content includes:
;;   - DC voltage (V), DC current (A)
;;   - AC voltage (V), AC current (A), AC frequency (Hz)
;;   - Device temperature (°C)
;;   - Accumulated energy (Wh)

(new TuyaDevice 'SoriaInverterDevice)

(define (SoriaInverterDevice:SoriaInverterDevice _version _address _id _local-key)
  "Constructor: connect to a Soria solar micro-inverter and enable
   persistent async mode for TLV frame reception."
  (setq id _id  address _address  local-key _local-key  version _version)
  (setq handle (tuya:create id address local-key version))
  (unless handle (throw (string "SoriaInverterDevice: connect failed to " address)))
  (tuya:set-async-mode handle true))

(define (SoriaInverterDevice:poll-frame)
  "Poll for the next async TLV frame.  Returns raw bytes or nil.
   Call this in a loop (the device pushes every ~2s)."
  (tuya:receive handle 1024))

(define (SoriaInverterDevice:is-data-available)
  "Check if async data is available without blocking."
  (tuya:is-socket-readable handle))

(define (SoriaInverterDevice:set-async flag)
  "Toggle async mode on/off."
  (tuya:set-async-mode handle (if flag 1 0)))
