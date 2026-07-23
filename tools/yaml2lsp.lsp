#!/usr/bin/env newlisp
;; yaml2lsp.lsp — Convert tuya-local YAML device definitions to newLISP classes
;;
;; Usage: newlisp tools/yaml2lsp.lsp > tuya-devices-generated.lsp
;; (Does NOT need libseatuya.so — this is a pure code generator.)

(setq DEVICES-DIR (or (env "TUYA_LOCAL_DIR")
  (string (real-path ".") "/vendor/tuya-local/custom_components/tuya_local/devices")))

;; --- Minimal YAML parser for tuya-local's subset of YAML ---

(define (yaml-indent line)
  (let (n 0)
    (while (and (< n (length line)) (= (line n) " ")) (inc n))
    n))

(define (yaml-value s)
  (cond
    ((= s "true") true)   ((= s "false") false)  ((= s "null") nil)
    ((regex {^[0-9]+$} s) (int s))
    ((regex {^[0-9]+\.[0-9]+$} s) (float s))
    (true s)))

(define (yaml-parse path)
  (let (lines (parse (read-file path) "\n")  result '()  stack '()  in-list nil)
    (setq stack (list result))
    (dolist (line lines)
      (when (and line (not (starts-with (trim line) "#")) (find ":" (trim line)))
        (let (indent (yaml-indent line)  trimmed (trim line)
              is-list (starts-with trimmed "- ")
              content (if is-list (slice trimmed 2) trimmed)
              colon (find ":" content))
          (when colon
            (let (key (trim (slice content 0 colon))
                  val (trim (slice content (+ colon 1))))
              (if (empty? val)
                  ;; block-start key
                  (let (child '())
                    (push (list key child) (stack -1) -1)
                    (push child stack -1)
                    (setq in-list is-list))
                  ;; leaf key:value
                  (let (parsed (yaml-value val))
                    (if is-list
                        (push (list key parsed) (stack -1) -1)
                        (begin
                          (while (< indent (yaml-indent (string (dup " " (stack -1)))))
                            (pop stack -1))
                          (push (list key parsed) (stack -1) -1))))))))))
    result))

;; --- Category merging ---

(setq CATEGORY-MERGE '(
  ("air_purifier"       "AirPurifierDevice")
  ("air_conditioner"    "AirConditionerDevice")
  ("air_cooler"         "AirCoolerDevice")
  ("air_fryer"          "AirFryerDevice")
  ("air_quality"        "AirQualityMonitorDevice")
  ("alarm"              "AlarmDevice")
  ("siren"              "SirenDevice")
  ("aroma"              "AromaDiffuserDevice")
  ("diffuser"           "DiffuserDevice")
  ("battery"            "BatteryDevice")
  ("bbq"                "BBQDevice")
  ("blind"              "BlindDevice")
  ("curtain"            "CurtainDevice")
  ("boiler"             "BoilerDevice")
  ("breaker"            "CircuitBreakerDevice")
  ("carbon_monoxide"    "CarbonMonoxideDetectorDevice")
  ("cat_litter"         "CatLitterBoxDevice")
  ("ceiling_fan"        "CeilingFanDevice")
  ("fan"                "FanDevice")
  ("co2"                "CO2DetectorDevice")
  ("coffee"             "CoffeeMakerDevice")
  ("cooker"             "CookerDevice")
  ("cooktop"            "CooktopDevice")
  ("dehumidifier"       "DehumidifierDevice")
  ("dishwasher"         "DishwasherDevice")
  ("dryer"              "DryerDevice")
  ("ev_charger"         "EVChargerDevice")
  ("fireplace"          "FireplaceDevice")
  ("freezer"            "FreezerDevice")
  ("garage"             "GarageDoorDevice")
  ("gate"               "GateDevice")
  ("heater"             "HeaterDevice")
  ("radiator"           "RadiatorDevice")
  ("hood"               "RangeHoodDevice")
  ("hrv"                "HRVDevice")
  ("humidifier"         "HumidifierDevice")
  ("ice_maker"          "IceMakerDevice")
  ("inverter"           "InverterDevice")
  ("irrigator"          "IrrigatorDevice")
  ("kettle"             "KettleDevice")
  ("kitchen_scale"      "KitchenScaleDevice")
  ("lawn"               "LawnMowerDevice")
  ("lock"               "LockDevice")
  ("microwave"          "MicrowaveDevice")
  ("mirror"             "SmartMirrorDevice")
  ("oven"               "OvenDevice")
  ("pet_feeder"         "PetFeederDevice")
  ("cat_feeder"         "PetFeederDevice")
  ("pet_fountain"       "PetFountainDevice")
  ("pool"               "PoolDevice")
  ("power_strip"        "PowerStripDevice")
  ("refrigerator"       "RefrigeratorDevice")
  ("robot_vacuum"       "RobotVacuumDevice")
  ("vacuum"             "RobotVacuumDevice")
  ("safe"               "SafeDevice")
  ("sauna"              "SaunaDevice")
  ("shower"             "ShowerDevice")
  ("smoke"              "SmokeDetectorDevice")
  ("sprinkler"          "SprinklerDevice")
  ("steam"              "SteamDevice")
  ("thermometer"        "ThermometerDevice")
  ("toaster"            "ToasterDevice")
  ("valve"              "ValveDevice")
  ("water_dispenser"    "WaterDispenserDevice")
  ("water_heater"       "WaterHeaterDevice")
  ("water_timer"        "WaterTimerDevice")
  ("weather_station"    "WeatherStationDevice")
))

(define (merge-category cat-name)
  (let (lower (lower-case cat-name) found nil)
    (dolist (pair CATEGORY-MERGE)
      (when (and (not found) (find (pair 0) lower))
        (setq found (pair 1))))
    found))

;; --- Device loading ---

(define (load-devices dir)
  (let (cats '()  files (directory dir {\.yaml$}))
    (dolist (fname files)
      (let (path (string dir "/" fname)  data (yaml-parse path))
        (when (and data (lookup "name" data) (lookup "entities" data))
          (let (cat (merge-category (lookup "name" data)))
            (when cat
              (let (entry (assoc cat cats))
                (if entry
                    (push data (entry 1) -1)
                    (push (list cat (list data)) cats -1))))))))
    cats))

(define (extract-dps device)
  (let (dps '())
    (dolist (entity (or (lookup "entities" device) '()))
      (dolist (dp (or (lookup "dps" entity) '()))
        (let (dp-id (lookup "id" dp))
          (when dp-id
            (push (list dp-id
                        (or (lookup "name" dp) (string "dp_" dp-id))
                        (or (lookup "type" dp) "string")
                        (or (lookup "mapping" dp) '()))
                  dps -1)))))
    dps))

(define (common-dps devices)
  (let (counts '()  n (length devices)  threshold (max 1 (round (mul n 0.3) 0)))
    (dolist (dev devices)
      (let (seen '())
        (dolist (dp (extract-dps dev))
          (let (dp-id (int (dp 0)))
            (unless (find dp-id seen)
              (push dp-id seen -1)
              (let (entry (assoc dp-id counts))
                (if entry
                    (begin (setf (entry 1) (+ (entry 1) 1))
                           (when (dp 1) (setf (entry 2) (dp 1)))
                           (setf (entry 3) (dp 2)))
                    (push (list dp-id 1 (dp 1) (dp 2)) counts -1))))))))
    (filter (fn (e) (>= (e 1) threshold)) counts)))

;; --- Code generation ---

(define (kebab s)
  (let (out (lower-case (string s)))
    (replace {[^a-z0-9]+} out "-" 0)
    (trim out "-")))

(define (generate-header)
  (print {; tuya-devices-generated.lsp — Auto-generated from tuya-local YAMLs
;
; Generated by tools/yaml2lsp.lsp.  Do not edit by hand.
; Regenerate with: newlisp tools/yaml2lsp.lsp > tuya-devices-generated.lsp
; Source: vendor/tuya-local/custom_components/tuya_local/devices/
;
})

  (print {(load (string (or (env "SEATUYA_LSP_DIR") (real-path ".")) "/seatuya.lsp"))
(load (string (or (env "SEATUYA_LSP_DIR") (real-path ".")) "/tuya-devices.lsp"))

}))

(define (generate-class cat-name devices)
  (let (dps (common-dps devices)  n (length devices))
    (when (empty? dps) (return))
    (println (string ";; " (dup "=" 68)))
    (println (string ";;  " cat-name " — " n " device(s), " (length dps) " common DP(s)"))
    (println (string ";; " (dup "=" 68)))
    (println)
    (println (string "(new TuyaDevice '" cat-name ")"))
    (println)
    ;; constructor
    (println (string "(define (" cat-name ":" cat-name " _version _address _id _local-key)"))
    (println (string "  \"Constructor: " n " model(s) supported.\""))
    (println {  (setq id _id  address _address  local-key _local-key  version _version)})
    (println {  (setq handle (tuya:create id address local-key version))})
    (println (string {  (unless handle (throw (string "} cat-name {: connect failed to " address)))}))
    (println)
    ;; DP docs
    (dolist (dp dps)
      (println (string "  ;; DP " (dp 0) ": " (dp 2) " (" (dp 3) ") — "
                       (dp 1) "/" n " devices")))
    (println)
    ;; methods
    (dolist (dp dps)
      (let (dp-id (dp 0)  dp-name (kebab (or (dp 2) (string "dp-" (dp 0))))  dp-type (dp 3))
        (cond
          ((= dp-type "boolean")
           (println (string "(define (" cat-name ":set-" dp-name " flag)"))
           (println (string {  "Set } dp-name { (DP } dp-id {)."}))
           (println (string {  (set-value } dp-id { (if flag true nil))}))
           (println {)})
           (println (string "(define (" cat-name ":" dp-name "?)"))
           (println (string {  "Query } dp-name { (DP } dp-id {)."}))
           (println {  (let (resp (status) parsed (when resp (json-parse resp)) dps (when parsed (lookup "dps" parsed)))})
           (println (string {    (and dps (= (lookup "} dp-id {" dps) true)))}))
           (println {)}))
          ((= dp-type "integer")
           (println (string "(define (" cat-name ":set-" dp-name " val)"))
           (println (string {  "Set } dp-name { (DP } dp-id {)."}))
           (println (string {  (set-value } dp-id { (int val))}))
           (println {)})
           (println (string "(define (" cat-name ":" dp-name ")"))
           (println (string {  "Read } dp-name { (DP } dp-id {)."}))
           (println {  (let (resp (status) parsed (when resp (json-parse resp)) dps (when parsed (lookup "dps" parsed)))})
           (println (string {    (when dps (int (or (lookup "} dp-id {" dps) 0))))}))
           (println {)}))
          (true
           (println (string "(define (" cat-name ":set-" dp-name " val)"))
           (println (string {  "Set } dp-name { (DP } dp-id {)."}))
           (println (string {  (set-value } dp-id { (string val))}))
           (println {)})
           (println (string "(define (" cat-name ":" dp-name ")"))
           (println (string {  "Read } dp-name { (DP } dp-id {)."}))
           (println {  (let (resp (status) parsed (when resp (json-parse resp)) dps (when parsed (lookup "dps" parsed)))})
           (println (string {    (when dps (lookup "} dp-id {" dps))}))
           (println {)}))))
      (println))))

;; --- Main ---

(define (main)
  (generate-header)
  (let (cats (load-devices DEVICES-DIR)  class-count 0  total-devices 0)
    (dolist (entry (sort cats (fn (a b) (< (a 0) (b 0)))))
      (let (class-name (entry 0)  devices (entry 1))
        (generate-class class-name devices)
        (inc class-count)
        (inc total-devices (length devices))))
    (print (string ";; " class-count " classes generated from " total-devices " devices\n")))
  (exit 0))

(main)
