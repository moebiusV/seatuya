;;; @module yaml.lsp
;;; @description YAML parsing for newLISP via libyaml, pure FFI, no wrapper .so
;;; @version 1.0
;;;
;;; Requires only the stock system libyaml (Debian/Ubuntu: libyaml-0-2,
;;; Fedora: libyaml, macOS: brew install libyaml).  No compiler, no build
;;; step, no vendored source.  Uses newLISP's extended (libffi) import,
;;; so return values and arguments are marshalled by declared type.
;;;
;;; Data model mirrors json-parse:
;;;   mapping   -> assoc list  (("k" v) ("k2" v2))
;;;   sequence  -> plain list  (v1 v2 v3)
;;;   scalar    -> string, integer, float, true or nil
;;;
;;; Usage:
;;;   (load "yaml.lsp")
;;;   (YAML:parse-file "devices/kettle.yaml")
;;;   (YAML:parse-string "a: 1\nb: [x, y]\n")
;;;   (YAML:parse-all-file "multi.yaml")        ; list of documents
;;;   (YAML:refn doc "primary_entity" "dps" 0 "name")

(context 'YAML)

;;; ------------------------------------------------------------------
;;; Configuration.  Set before or between parses.
;;; ------------------------------------------------------------------

(setq raw-scalars  nil)   ; true  -> no type resolution, every scalar a string
(setq yaml11       nil)   ; true  -> YAML 1.1 resolver: yes/no/on/off as booleans,
                          ;          underscores as digit separators (1_000 -> 1000)
(setq merge-keys   true)  ; true  -> '<<' merges anchored mappings
(setq libname      nil)   ; set before load to force a specific shared object

;;; ------------------------------------------------------------------
;;; Locate and import libyaml
;;; ------------------------------------------------------------------

(setq candidates
  '("libyaml-0.so.2" "libyaml.so.2" "libyaml.so"
    "/usr/lib/x86_64-linux-gnu/libyaml-0.so.2"
    "/usr/lib/aarch64-linux-gnu/libyaml-0.so.2"
    "/usr/lib64/libyaml-0.so.2" "/usr/lib/libyaml-0.so.2"
    "/usr/local/lib/libyaml.so" "/usr/pkg/lib/libyaml.so"
    "libyaml-0.2.dylib" "libyaml.dylib"
    "/opt/homebrew/lib/libyaml.dylib" "/usr/local/lib/libyaml.dylib"
    "yaml.dll" "libyaml.dll"))

(setq lib nil)
(dolist (c (if libname (list libname) candidates) lib)
  (if (catch (import c "yaml_get_version_string" "char*" "void") 'ignored)
      (setq lib c)))

(if (not lib)
    (throw-error "yaml.lsp: libyaml shared library not found; set YAML:libname"))

;; Extended import: every pointer crosses as void*, so nothing depends on
;; newLISP's default argument coercion.  Buffers are passed as addresses.
;; Note the explicit "void" parameter above -- a zero-argument extended
;; import needs it, or newLISP silently falls back to the simple form and
;; hands back a raw pointer instead of a marshalled string.
(import lib "yaml_parser_initialize"       "int"  "void*")
(import lib "yaml_parser_set_input_string" "void" "void*" "void*" "long")
(import lib "yaml_parser_parse"            "int"  "void*" "void*")
(import lib "yaml_parser_delete"           "void" "void*")
(import lib "yaml_event_delete"            "void" "void*")

(define (version) (yaml_get_version_string))

;;; ------------------------------------------------------------------
;;; Parser and event buffers
;;;
;;; We never index into yaml_parser_t beyond its first three fields, so
;;; its exact size is irrelevant -- we simply over-allocate.  sizeof is
;;; 480 on x86_64/glibc and has not grown since 0.1.x; 4096 is proof
;;; against any future growth as well as against every ABI variant.
;;; ------------------------------------------------------------------

(setq PSIZE 4096)   ; >= sizeof(yaml_parser_t)
(setq ESIZE 512)    ; >= sizeof(yaml_event_t)  (104 on x86_64)

(define (open-parser str)
  (setq PB (dup (char 0) PSIZE))
  (setq EB (dup (char 0) ESIZE))
  (setq SRC str)              ; must stay reachable: libyaml holds the pointer
  (setq PA (address PB) EA (address EB))
  (if (= 0 (yaml_parser_initialize PA))
      (throw-error "yaml: parser initialization failed"))
  (yaml_parser_set_input_string PA (address SRC) (length SRC)))

(define (close-parser)
  (if PA (yaml_parser_delete PA))
  (setq PB nil EB nil SRC nil PA nil EA nil))

;;; ------------------------------------------------------------------
;;; Struct layout
;;;
;;; yaml_event_t is { int type; union data; yaml_mark_t start, end; }.
;;; With pointer size P the union begins at P (int padded up to pointer
;;; alignment) and every field we care about falls out of P:
;;;
;;;   scalar.anchor  P     scalar.value   3P    scalar.style  5P+8
;;;   scalar.tag     2P    scalar.length  4P    seq/map.style 3P+4
;;;
;;; Rather than trust that derivation, we determine P empirically at load
;;; time by parsing a one-scalar document and finding where libyaml put
;;; the value pointer.  The 4-byte probe is tested first: on an LP64
;;; build offset 12 is the high half of a NULL anchor and reads as 0, so
;;; it can never produce a bogus dereference.
;;; ------------------------------------------------------------------

(define (probe-layout , ty v4 v8)
  (open-parser "v")
  (setq ty 0)
  (while (and (!= ty 6) (!= ty 2))
    (if (= 0 (yaml_parser_parse PA EA))
        (begin (close-parser) (throw-error "yaml.lsp: layout probe failed")))
    (setq ty (first (unpack "ld" (slice EB 0 4))))
    (if (!= ty 6) (yaml_event_delete EA)))
  (if (!= ty 6)
      (begin (close-parser) (throw-error "yaml.lsp: layout probe found no scalar")))
  (setq v4 (first (unpack "lu" (slice EB 12 4))))
  (setq v8 (first (unpack "Lu" (slice EB 24 8))))
  (cond
    ((and (> v4 65535) (= "v" (get-string v4))) (setq P 4))
    ((and (> v8 65535) (= "v" (get-string v8))) (setq P 8))
    (true (yaml_event_delete EA) (close-parser)
          (throw-error "yaml.lsp: cannot determine libyaml struct layout")))
  (yaml_event_delete EA)
  (close-parser))

(define (set-offsets)
  (setq PFMT     (if (= P 8) "Lu" "lu")
        O-ANCHOR P
        O-TAG    (* 2 P)
        O-VALUE  (* 3 P)
        O-LEN    (* 4 P)
        O-SSTYLE (+ (* 5 P) 8)     ; scalar style
        O-CSTYLE (+ (* 3 P) 4)     ; sequence/mapping style
        O-PROBLEM P                ; yaml_parser_t.problem
        O-PLINE  (* 5 P)           ; yaml_parser_t.problem_mark.line
        O-PCOL   (* 6 P)))         ; yaml_parser_t.problem_mark.column

(probe-layout)
(set-offsets)

;;; ------------------------------------------------------------------
;;; Field readers
;;; ------------------------------------------------------------------

(define (ptr-at off)   (first (unpack PFMT (slice EB off P))))
(define (int-at off)   (first (unpack "ld" (slice EB off 4))))
(define (str-at off , a) (setq a (ptr-at off)) (if (> a 0) (get-string a)))

;; Scalar values are read by their declared byte length, not as C strings.
;; YAML permits NUL inside a double-quoted scalar (the \0 escape), and
;; newLISP strings are counted, so a NUL must survive the copy intact.
(define (scalar-val , p n)
  (setq p (ptr-at O-VALUE)
        n (first (unpack PFMT (slice EB O-LEN P))))
  (if (or (= p 0) (= n 0)) ""
      (first (unpack (string "s" n) p))))

(setq LASTERR nil)

(define (fail msg)
  (setq LASTERR msg)
  (throw-error msg))

(define (parse-error , a msg ln col)
  (setq a (first (unpack PFMT (slice PB O-PROBLEM P))))
  (setq msg (if (> a 0) (get-string a) "parse error"))
  (setq ln  (+ 1 (first (unpack PFMT (slice PB O-PLINE P)))))
  (setq col (+ 1 (first (unpack PFMT (slice PB O-PCOL P)))))
  (fail (string "yaml: " msg " at line " ln ", column " col)))

;;; Returns (kind anchor tag value style); strings are copied out of
;;; libyaml's memory before yaml_event_delete reclaims it.
(define (next-event , ty ev)
  (if (= 0 (yaml_parser_parse PA EA)) (parse-error))
  (setq ty (int-at 0))
  (setq ev
    (case ty
      (1  (list 'stream-start))
      (2  (list 'stream-end))
      (3  (list 'doc-start))
      (4  (list 'doc-end))
      (5  (list 'alias (str-at O-ANCHOR)))
      (6  (list 'scalar (str-at O-ANCHOR) (str-at O-TAG)
                (scalar-val) (int-at O-SSTYLE)))
      (7  (list 'seq-start (str-at O-ANCHOR) (str-at O-TAG)))
      (8  (list 'seq-end))
      (9  (list 'map-start (str-at O-ANCHOR) (str-at O-TAG)))
      (10 (list 'map-end))
      (true (list 'none))))
  (yaml_event_delete EA)
  ev)

;;; ------------------------------------------------------------------
;;; Scalar resolution (YAML 1.2 core schema by default)
;;; ------------------------------------------------------------------

(setq NULLS  '("" "~" "null" "Null" "NULL"))
(setq TRUES  '("true" "True" "TRUE"))
(setq FALSES '("false" "False" "FALSE"))
(setq TRUES11  '("yes" "Yes" "YES" "on" "On" "ON"))
(setq FALSES11 '("no" "No" "NO" "off" "Off" "OFF"))

(setq INF (if (catch (div 1 0) 'r) r nil))
(setq NAN (if (catch (div 0 0) 'r) r nil))

;; Integers wider than a machine int wrap silently, so round-trip every
;; conversion and promote to a bigint when it does not survive.  bigint
;; arrived in 10.5.0; on anything older the exact digits come back as a
;; string rather than a wrong number.
(setq HAVE-BIGINT (if (catch (bigint 1) 'r) true nil))

(define (norm-int s , neg body)
  (setq neg (= "-" (first s)))
  (setq body (if (find (first s) '("+" "-")) (rest s) s))
  (setq body (replace {^0+(?=[0-9])} body "" 0))
  (if (and neg (!= body "0")) (string "-" body) body))

(define (dec-int s , n)
  (setq n (int s 0 10))
  (cond
    ((= (string n) (norm-int s)) n)
    (HAVE-BIGINT (bigint s))
    (true s)))

;; bigint parses decimal only, so oversized hex/octal is accumulated by hand.
(define (big-base s base , neg body acc)
  (setq neg (= "-" (first s)))
  (setq body (lower-case (if (find (first s) '("+" "-")) (rest s) s)))
  (setq body (replace {^0[xo]} body "" 0))
  (setq acc (bigint 0))
  (dolist (c (explode body))
    (setq acc (+ (* acc (bigint base)) (bigint (find c "0123456789abcdef")))))
  (if neg (- (bigint 0) acc) acc))

(define (based-int s base , neg body n)
  (setq neg (= "-" (first s)))
  (setq body (lower-case (if (find (first s) '("+" "-")) (rest s) s)))
  (setq body (replace {^0[xo]} body "" 0))
  (setq body (replace {^0+(?=[0-9a-f])} body "" 0))
  (setq n (int body 0 base))
  ;; re-encode in the same base: the only honest overflow check
  (if (and (>= n 0) (= body (format (if (= base 16) "%x" "%o") n)))
      (if neg (- 0 n) n)
      (if HAVE-BIGINT (big-base s base) s)))

(define (resolve-plain s)
  (cond
    ((find s NULLS) nil)
    ((find s TRUES) true)
    ((find s FALSES) nil)
    ((and yaml11 (find s TRUES11)) true)
    ((and yaml11 (find s FALSES11)) nil)
    ((and yaml11 (regex {^[-+]?[0-9][0-9_]*$} s)) (dec-int (replace "_" (copy s) "")))
    ((regex {^[-+]?[0-9]+$} s) (dec-int s))
    ((regex {^[-+]?0x[0-9a-fA-F]+$} s) (based-int s 16))
    ((regex {^[-+]?0o[0-7]+$} s) (based-int s 8))
    ((regex {^[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$} s) (float s))
    ((regex {^[-+]?\.(inf|Inf|INF)$} s)
     (if (= "-" (first s)) (sub 0 INF) INF))
    ((regex {^\.(nan|NaN|NAN)$} s) NAN)
    (true s)))

;; style: 1 = plain, 2 = single-quoted, 3 = double-quoted,
;;        4 = literal, 5 = folded.  Only plain scalars are type-resolved.
(define (resolve val style tag)
  (cond
    (raw-scalars val)
    ((and tag (find tag '("tag:yaml.org,2002:str" "!!str" "!"))) val)
    ((and tag (find tag '("tag:yaml.org,2002:int" "!!int"))) (int val 0 10))
    ((and tag (find tag '("tag:yaml.org,2002:float" "!!float"))) (float val))
    ((and tag (find tag '("tag:yaml.org,2002:bool" "!!bool")))
     (if (or (find val TRUES) (find val TRUES11)) true nil))
    ((and tag (find tag '("tag:yaml.org,2002:null" "!!null"))) nil)
    ((!= style 1) val)
    (true (resolve-plain val))))

;;; ------------------------------------------------------------------
;;; Anchors and aliases
;;; ------------------------------------------------------------------

(define (anchor! name node)
  (if (and name (!= name "")) (push (list name node) ANCHORS -1))
  node)

(define (deref name , hit)
  (setq hit (assoc name ANCHORS))
  (if hit (last hit)
      (fail (string "yaml: unknown alias *" name))))

;;; ------------------------------------------------------------------
;;; Node construction
;;; ------------------------------------------------------------------

(define (put alist k v)
  (if (assoc k alist)
      (setf (assoc k alist) (list k v))
      (push (list k v) alist -1))
  alist)

(define (merge-one alist m)
  (dolist (pair m)
    (if (not (assoc (first pair) alist)) (push pair alist -1)))
  alist)

(define (merge-into alist v)
  ;; v is either a mapping (("k" x) ...) or a list of mappings
  (if (and (list? v) (list? (first v)) (list? (first (first v))))
      (dolist (m v) (setq alist (merge-one alist m)))
      (setq alist (merge-one alist v)))
  alist)

(define (build-seq ev , acc e)
  (setq acc '() e (next-event))
  (while (!= (first e) 'seq-end)
    (push (build-node e) acc -1)
    (setq e (next-event)))
  (anchor! (nth 1 ev) acc)
  acc)

(define (build-map ev , acc e k v)
  (setq acc '() e (next-event))
  (while (!= (first e) 'map-end)
    (setq k (build-node e))
    (setq v (build-node (next-event)))
    (if (and merge-keys (= k "<<"))
        (setq acc (merge-into acc v))
        (setq acc (put acc k v)))
    (setq e (next-event)))
  (anchor! (nth 1 ev) acc)
  acc)

(define (build-node ev , kind)
  (setq kind (first ev))
  (cond
    ((= kind 'scalar)    (anchor! (nth 1 ev)
                                  (resolve (nth 3 ev) (nth 4 ev) (nth 2 ev))))
    ((= kind 'alias)     (deref (nth 1 ev)))
    ((= kind 'seq-start) (build-seq ev))
    ((= kind 'map-start) (build-map ev))
    (true (fail (string "yaml: unexpected event " (string kind))))))

(define (collect-docs , docs e)
  (setq docs '() e (next-event))
  (while (!= (first e) 'stream-end)
    (if (= (first e) 'doc-start)
        (begin
          (setq ANCHORS '())
          (push (build-node (next-event)) docs -1)
          (next-event)))          ; consume doc-end
    (setq e (next-event)))
  docs)

;;; ------------------------------------------------------------------
;;; Public entry points
;;; ------------------------------------------------------------------

(define (parse-all-string str , ok res)
  (open-parser str)
  (setq LASTERR nil)
  (setq ok (catch (collect-docs) 'res))
  (close-parser)                 ; always reclaim libyaml state, error or not
  (if ok res (throw-error (or LASTERR res))))

(define (parse-string str) (first (parse-all-string str)))

(define (parse-all-file path , txt)
  (setq txt (read-file path))
  (if (not txt) (throw-error (string "yaml: cannot read " path)))
  (parse-all-string txt))

(define (parse-file path) (first (parse-all-file path)))

;;; ------------------------------------------------------------------
;;; Convenience accessors
;;; ------------------------------------------------------------------

;; (YAML:refn doc "primary_entity" "dps" 0 "name")
;; Walks a heterogeneous path: strings key into mappings, integers index
;; into sequences.  Returns nil on any miss rather than erroring, so a
;; wrong path in a batch run fails quietly instead of aborting it.
;;
;; Related but distinct from the primitives: MAIN:ref is the inverse
;; direction (value -> index vector), nth takes a positional index vector
;; only, and the nested-key forms of assoc/lookup expect flattened alists
;; where an entry's rest is itself an alist -- not the (key value) pairs
;; this parser emits, and neither indexes into sequences.
;;
;; NB: no ',' locals here -- ',' is an ordinary parameter symbol in
;; newLISP, so declaring locals that way would swallow the varargs.
(define (refn node)
  (let (n node hit nil)
    (dolist (k (args))
      (setq n
        (cond
          ((not (list? n)) nil)
          ((string? k) (if (setq hit (assoc k n)) (last hit)))
          ((number? k) (nth k n))
          (true nil))))
    n))

(define (keys node)   (map first node))
(define (vals node)   (map last node))
(define (has? node k) (if (assoc k node) true nil))

(context MAIN)
