# seatuya changes — ISV-300W local control investigation

## Bug fix (affects the device directly)

**Malformed HEARTBEAT payload for 22-character device ids.**
tuyapp's `tuyaAPI::GeneratePayload()` substitutes template tokens with
`std::string::replace()` at hardcoded byte offsets. For the HEART_BEAT
template the offsets (28, 10) are wrong; with a 22-char id the result is:

    {"gwId":"@ebecb2051a215e64e3aa5b,"devId":"@ebecb2051a215e64e3aa5b}

The '@' survives and the closing quotes are eaten — invalid JSON. This is
encrypted into a valid 3.3 frame, so the device silently drops it, which is
indistinguishable from a wrong-key drop. This invalidated the heartbeat
"key oracle" used in earlier testing.

DP_QUERY, CONTROL, DP_QUERY_NEW and CONTROL_NEW offsets happen to be correct;
only HEARTBEAT was corrupt.

**Fix:** `src/seatuya.cpp` now generates payloads natively via `gen_payload()`
using token search-and-replace (correct for any id length, cannot drift).
This replaces `dev->api->GeneratePayload()` at both call sites, so seatuya no
longer depends on tuyapp's offset bookkeeping. The fix lives in the shim, so
it survives `fetch-deps.sh` re-cloning tuyapp into deps/.

## New capability: device22 mode

Firmware on many 22-char-id devices reports protocol 3.3 but ignores
DP_QUERY (10) and CONTROL (7); status must be requested with CONTROL_NEW (13)
carrying a null-valued DP map, and writes must also use CONTROL_NEW.

- `tuya_set_device22(dev, null_dps_json)` / `tuya_is_device22(dev)` in
  `include/seatuya.h`.
- `round_trip()` in `src/seatuya.cpp` remaps commands when device22 is set,
  and also remaps DP_QUERY/CONTROL to the _NEW variants for protocol 3.4/3.5.
- Status queries now read up to a few frames (device22 answers CONTROL_NEW
  with an empty ack, then pushes DP state in a separate STATUS frame).

Enable for the ISV-300W with:

    {"101":null,"102":null,"103":null,"104":null,"105":null,
     "106":null,"107":null,"108":null,"109":null,"110":null}

## New tool: examples/tuyaprobe.c

Ground-truth TCP prober. The decisive test is phase 2: it shrinks the local
send buffer, sets a send timeout, and writes junk. If nothing reads the peer
socket the peer window closes and writes stall after a few KB — proving no
application is behind the port (LAN handler disabled in firmware). If the peer
drains indefinitely, an app IS reading and the failure is protocol/key-level.
This distinguishes "wrong key/variant" from "firmware local-control disabled",
which no amount of frame-level testing can.

- Sweeps TCP ports 6668 and 6669 by default (`-P p1,p2` or `-p one`).
  6669 is the TLS-wrapped command variant some mzj firmware uses instead of
  plaintext 6668 — untested in the original investigation.
- Phase 3 sends real frames per protocol version (fresh connection each) and
  hexdumps any reply; 3.4/3.5 are probed with session negotiation, which a
  device of that version must answer even with a wrong key.
- Key is read from a FILE, never argv (local keys contain shell metachars).
- Note: phase-3 negotiation sub-probes use tuyapp's fixed port 6668; phases
  1/2/4 and phase-3 raw frames honor each swept port.

## New tool: examples/tuyascan.c (+ prebuilt tuyascan.exe path)

Single-file, dependency-free UDP discovery scanner. Listens on 6666 (3.1
plaintext), 6667 (3.3/3.4 AES-ECB, static key MD5("yGAdlopoPVldABfn")
embedded), and 7000 (3.5 GCM presence). Cross-compiles to Win32 for running
via powershell.exe from WSL2, where the WSL NAT otherwise hides LAN
broadcasts. Native build also provided.

    x86_64-w64-mingw32-gcc -O2 -o tuyascan.exe tuyascan.c -lws2_32

## Wizard improvements (examples/wizard-common.c)

- `udp_discover()` now binds all three discovery ports and decrypts 6667
  AES-ECB broadcasts (previously bound only 6666, greppable plaintext only —
  it could never see a 3.3 device). Appends devices not in the cloud list.
- Thing Data Model (v2.0) cloud endpoints, the working DP path for "mzj"
  devices whose v1.0 status/functions return empty:
    -M  GET  /v2.0/cloud/thing/{id}/model              (schema)
    -S  GET  /v2.0/cloud/thing/{id}/shadow/properties  (read DPs)
    -I  POST /v2.0/cloud/thing/{id}/shadow/properties/issue  (write)
  `tuya_api_call()` now passes absolute (leading-'/') paths verbatim so v2.0
  endpoints are reachable; relative paths still get the /v1.0/ prefix.
- Build fix: forward declarations for tuya_api_call_r / tuya_get_token
  (were failing under the current toolchain).

## Not done (by request)

A full standalone-C rewrite (dropping the tuyapp/jsoncpp C++ link
dependency) was scoped but deferred. Only HEARTBEAT was actually broken in
the C++ payload layer; the rest of the stack is correct, so the shim is
viable as-is. The native `gen_payload()` added here is the first piece a
future C port would keep.
