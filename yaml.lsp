;; yaml.lsp — YAML parser for newLISP, backed by vendored libyaml (MIT)
;;
;; Uses libyamlwrap.so (C wrapper over libyaml) to parse YAML files
;; into newLISP nested association lists via eval of S-expression output.
;;
;; Usage:
;;   (load "yaml.lsp")
;;   (yaml-parse-file "vendor/tuya-local/.../kettle.yaml")

(context 'yaml)

;; Find and load the wrapper library
(setq libpath (or (env "YAM_LWRP_LIB")
                  (let (d (real-path (or (env "SEATUYA_HOME") ".")))
                    (if (find "libyamlwrap" (directory d "libyamlwrap.*"))
                        (string d "/libyamlwrap.so")
                        (string d "/src/libyamlwrap.so")))))

(import libpath "yaml_parse_file")
(import libpath "yaml_parse_string")

;; ── Public API ──

(define (yaml:parse-file path)
  "Parse a YAML file, returning nested assoc-lists."
  (let (ptr (yaml_parse_file path))
    (if (= ptr 0)
      (throw (string "yaml: parse failed for " path)))
    (let (s-expr (get-string ptr)
          data (eval-string s-expr))
      (free ptr)  ; free the C malloc'd string
      (unless data (throw (string "yaml: eval failed for " path)))
      data)))

(define (yaml:parse-string str)
  "Parse a YAML string, returning nested assoc-lists."
  (let (ptr (yaml_parse_string str))
    (if (= ptr 0)
      (throw "yaml: parse failed"))
    (let (s-expr (get-string ptr)
          data (eval-string s-expr))
      (free ptr)
      (unless data (throw "yaml: eval failed"))
      data)))

(context MAIN)

;; Quick inline test
(define (yaml-parse-file path) (yaml:parse-file path))
(define (yaml-parse-string s)  (yaml:parse-string s))
