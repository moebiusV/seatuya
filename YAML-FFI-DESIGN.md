# YAML Parsing from newLISP via libyaml FFI — Design Analysis

## Background

seatuya vendors [tuya-local](https://github.com/make-all/tuya-local) (~1,650 device YAML files)
under `vendor/tuya-local/` and needs to parse them to generate newLISP device classes.
The goal: an idiomatic newLISP module that parses YAML files into nested association
lists — the moral equivalent of `json-parse` but for YAML.

[libyaml](https://github.com/yaml/libyaml) (MIT, pure C, zero-churn) is the obvious
parser.  The question is how to call it from newLISP.

## Option A: Pure newLISP FFI — calling libyaml directly

libyaml's C API for reading a YAML file:

```c
yaml_parser_t parser;
yaml_parser_initialize(&parser);                       // init
yaml_parser_set_input_file(&parser, file);             // source

yaml_event_t event;
do {
    yaml_parser_parse(&parser, &event);                // next event
    switch (event.type) {                              // dispatch
        case YAML_SCALAR_EVENT:
            use(event.data.scalar.value);              // union member
            break;
        case YAML_MAPPING_START_EVENT:
            use(event.data.mapping_start.anchor);
            break;
        // ... ~10 more event types
    }
    yaml_event_delete(&event);                         // cleanup
} while (event.type != YAML_STREAM_END_EVENT);

yaml_parser_delete(&parser);                           // teardown
```

To call this from newLISP, we need:

### 1. Allocate `yaml_parser_t` and pass it by reference

newLISP can allocate a byte buffer and pass a pointer to C:

```newlisp
(setq parser-buf (dup "\000" PARSER-SIZE))
(yaml_parser_initialize parser-buf)
```

**Problem:** `PARSER-SIZE` is platform-dependent.  On Linux/glibc x86_64 it's ~256 bytes.
On macOS ARM it might differ.  On BSD it's different again.  We'd need either
compile-time size discovery or a hardcoded table per platform.

**Mitigation:** Ship a tiny C helper that prints `sizeof(yaml_parser_t)` during
`make`, store the value, and use it at runtime.  Or use the vendored libyaml
source (reproducible struct across builds since it's compiled as part of seatuya).

### 2. Pass a `FILE*` to libyaml

`yaml_parser_set_input_file` takes a `FILE*`.  newLISP cannot open files as C
`FILE*` handles — it has its own I/O system (file handles are integers, not
stdio pointers).

**Alternative:** Use `yaml_parser_set_input_string(parser, str, len)` instead.
newLISP reads the file into a string with `read-file`, then passes the string
and its length:

```newlisp
(setq text (read-file "devices/kettle.yaml"))
(yaml_parser_set_input_string parser-buf text (length text))
```

This IS possible.  The string must remain alive for the entire parse duration
(libyaml holds a pointer to it internally).

### 3. Allocate `yaml_event_t` and inspect its union

After each `yaml_parser_parse()`, the `yaml_event_t` buffer is filled.  The
first field is `int type`, determining which union member is active.  newLISP
would need to:

```newlisp
(yaml_parser_parse parser-buf event-buf)
(setq event-type (unpack "lu" event-buf))  ; read first int

(case event-type
  (1  ; YAML_SCALAR_EVENT — read data.scalar.value at offset 8
      (let (ptr (unpack "Lu" (slice event-buf 8 8)))
        (setq scalar-value (get-string ptr))))
  (4  ; YAML_MAPPING_START_EVENT — read data.mapping_start.anchor at offset X
      ...)
  ; ... etc for each event type
  )
(yaml_event_delete event-buf)
```

**Problem:** Union member offsets are type-dependent and vary by platform.
On x86_64 Linux with glibc, the `yaml_event_t` layout is approximately:

| Offset | Field | Size |
|--------|-------|------|
| 0 | `type` (int) | 4 bytes |
| 4 | (padding) | 4 bytes |
| 8 | union `data` (max member ~32 bytes) | 32 bytes |
| 40 | `start_mark` | ~24 bytes |
| 64 | `end_mark` | ~24 bytes |

The union layout changes depending on which member is active:
- `data.scalar.value` (char*) at union offset 0
- `data.mapping_start.anchor` (char*) at union offset 0 (same position, different interpretation)

So OFFsets within the union are stable (all pointers start at offset 0 of the union),
but the union's position within `yaml_event_t` varies with padding.

**Mitigation:** Since libyaml is vendored and compiled as part of our build,
the struct layout is deterministic for our build.  We could generate offset
constants with a small C program during `make`.

### 4. Memory ownership

libyaml allocates event data internally.  `yaml_event_delete()` frees it.
newLISP must copy any string before calling `yaml_event_delete()`:

```newlisp
(let (scalar-ptr (unpack "Lu" ...))   ; get pointer from event
  (setq value (get-string scalar-ptr)))  ; copy to newLISP string
(yaml_event_delete event-buf)            ; free libyaml's memory
; value is now a safe newLISP string
```

This is identical to how `tuya_free_string` works in seatuya.lsp.  Doable.

## Option B: C wrapper (the seatuya pattern)

A 50-line C file links the vendored libyaml and exposes:

```c
char *yaml_parse_file(const char *path);       // → malloc'd S-expression
char *yaml_parse_string(const char *str);      // → malloc'd S-expression
```

The newLISP side is trivial:

```newlisp
(import "libyamlwrap.so" "yaml_parse_file")
(define (yaml-parse-file path)
  (let (ptr (yaml_parse_file path)
        s (get-string ptr))
    (free ptr)
    (eval-string s)))
```

### What the wrapper handles internally

1. Opens the file (`fopen`), initializes libyaml, runs the parse loop
2. Dispatches on event type, builds an S-expression string via recursive output
3. Returns a single `malloc`'d string that newLISP consumes and frees

The wrapper is 50 lines.  It compiles to a ~200KB `.so` (static link of vendored libyaml).

### Why this is the right choice for seatuya

1. **Same pattern as the project.**  seatuya wraps tuyapp (C++) behind a C ABI.
   `libyamlwrap.so` wraps libyaml (C) behind a single-function C ABI.  Both use
   the same `import → get-string → free` calling convention.

2. **Zero newLISP complexity.**  The newLISP side doesn't know about YAML events,
   unions, struct sizes, or state machines.  It calls one function and gets back
   an S-expression.

3. **Build-time determinism.**  The vendored libyaml is compiled once into the
   wrapper `.so`.  Struct sizes and offsets are the compiler's problem, never
   newLISP's.

4. **Portability.**  If struct layouts change between platforms (x86_64 vs ARM),
   the C compiler handles it.  No newLISP code changes.

## Option C: Pure newLISP YAML parser (no C dependency)

Write a YAML parser entirely in newLISP.  This is what the previous `yaml.lsp`
attempted before settling on libyaml.

**Verdict:** Rejected.  newLISP excels at consuming parsed data, not at writing
production-quality parsers for complex grammars like YAML.  The tuya-local YAML
is a subset but still requires indentation tracking, list/block/key/value
disambiguation, flow style (`[a, b]`, `{k: v}`), and multi-line scalars.

## Recommendation

**Option B (C wrapper)** is the correct architecture for seatuya.  It follows
the established project pattern (wrap C/C++ libraries behind simple C ABIs,
call from newLISP via `import`).  The line count is minimal (50 lines C, 30
lines newLISP).  The result is robust (libyaml was battle-tested across
millions of YAML documents) and maintainable (vendored libyaml has had one
commit since 2020).

Option A (pure FFI) is technically achievable but would require ~100 lines of
newLISP with hardcoded struct sizes, manual offset calculations, and platform
fragility — solving problems the C compiler already solves for us for free.

## Implementation Status

- `deps/libyaml/` — vendored MIT C library via `git clone` in `fetch-deps.sh`
- `src/libyamlwrap.so` — compiled C wrapper linking vendored libyaml statically
- `yaml.lsp` — newLISP module importing the wrapper, providing `yaml:parse-file`
  and `yaml:parse-string`
- `tools/yaml2lsp.lsp` — uses `yaml.lsp` to convert tuya-local YAMLs to
  newLISP device classes

### Current blocker

The `.so` compiles and links but `yaml_parse_file()` returns NULL at runtime.
The most likely cause: the vendored libyaml source is compiled without running
CMake, missing a generated `config.h`.  A minimal config.h was created but may
not define all the necessary platform detection macros.  The fix is either:
1. Run CMake on the vendored libyaml to generate a proper config.h, or
2. Identify and define all missing HAVE_* / YAML_* macros manually.
