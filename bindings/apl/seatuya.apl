⍝ seatuya.apl -- Dyalog APL FFI bindings for libseatuya
⍝
⍝ Uses ⎕NA (Name Association) for direct C function calls with
⍝ configurable library path (respects SEATUYA_LIB env var).
⍝
⍝ Usage:
⍝   seatuya.Init''
⍝   dev←seatuya.Create 'devid' '192.168.1.100' 'localkey' '3.4'
⍝   seatuya.Destroy dev
⍝
⍝ NOTE: C functions returning malloc'd strings (status, turn_on, etc.)
⍝ use 'T' result type (auto-converted to APL char vector). The
⍝ original C memory is leaked -- Dyalog's ⎕NA does not expose the
⍝ raw pointer after conversion.  Negligible in short-lived scripts.

:Namespace seatuya
    ⎕IO←0

    ═══════════════════════════════════════════════════════════
    ⍝ Initialization (must be called before any other function)
    ═══════════════════════════════════════════════════════════

    lib←''

    ∇ Init path;libpath
      ⍝ Initialize FFI bindings.
      ⍝ path  optional library path (default: libseatuya.so)
      :If 0=⎕NC 'path'
          path←⎕GETENV 'SEATUYA_LIB'
      :EndIf
      :If 0=⍴path ⋄ path←'libseatuya.so' ⋄ :EndIf
      libpath←path
      lib←libpath

      ⍝ Version
      ⍝ const char *tuya_version(void)
      version←⎕NA 'T' (libpath,'|tuya_version')

      ⍝ Lifecycle
      ⍝ tuya_device_t *tuya_create(const char*,const char*,const char*,const char*)
      Create←⎕NA 'P' (libpath,'|tuya_create') 'T' 'T' 'T' 'T'
      ⍝ tuya_device_t *tuya_alloc(const char*)
      Alloc←⎕NA 'P' (libpath,'|tuya_alloc') 'T'
      ⍝ void tuya_destroy(tuya_device_t*)
      Destroy←⎕NA '' (libpath,'|tuya_destroy') 'P'

      ⍝ Credentials
      ⍝ void tuya_set_credentials(tuya_device_t*,const char*,const char*)
      SetCredentials←⎕NA '' (libpath,'|tuya_set_credentials') 'P' 'T' 'T'
      ⍝ const char *tuya_get_device_id(tuya_device_t*)
      GetDeviceId←⎕NA 'T' (libpath,'|tuya_get_device_id') 'P'
      ⍝ const char *tuya_get_local_key(tuya_device_t*)
      GetLocalKey←⎕NA 'T' (libpath,'|tuya_get_local_key') 'P'
      ⍝ const char *tuya_get_ip(tuya_device_t*)
      GetIp←⎕NA 'T' (libpath,'|tuya_get_ip') 'P'

      ⍝ Connection
      ⍝ bool tuya_connect(tuya_device_t*,const char*)
      Connect←⎕NA 'I' (libpath,'|tuya_connect') 'P' 'T'
      ⍝ void tuya_disconnect(tuya_device_t*)
      Disconnect←⎕NA '' (libpath,'|tuya_disconnect') 'P'
      ⍝ bool tuya_is_connected(tuya_device_t*)
      IsConnected←⎕NA 'I' (libpath,'|tuya_is_connected') 'P'
      ⍝ bool tuya_reconnect(tuya_device_t*)
      Reconnect←⎕NA 'I' (libpath,'|tuya_reconnect') 'P'

      ⍝ Retry
      SetRetryLimit←⎕NA '' (libpath,'|tuya_set_retry_limit') 'P' 'I'
      SetRetryDelay←⎕NA '' (libpath,'|tuya_set_retry_delay') 'P' 'I'
      GetRetryLimit←⎕NA 'I' (libpath,'|tuya_get_retry_limit') 'P'
      GetRetryDelay←⎕NA 'I' (libpath,'|tuya_get_retry_delay') 'P'

      ⍝ Session
      NegotiateSession←⎕NA 'I' (libpath,'|tuya_negotiate_session') 'P' 'T'

      ⍝ State
      GetProtocol←⎕NA 'I' (libpath,'|tuya_get_protocol') 'P'
      GetSessionState←⎕NA 'I' (libpath,'|tuya_get_session_state') 'P'
      GetSocketState←⎕NA 'I' (libpath,'|tuya_get_socket_state') 'P'
      GetLastError←⎕NA 'I' (libpath,'|tuya_get_last_error') 'P'

      ⍝ Async
      SetAsyncMode←⎕NA '' (libpath,'|tuya_set_async_mode') 'P' 'I'

      ⍝ High-level round-trip (return malloc'd char* -- auto-converted via 'T')
      SetValueBool←⎕NA 'T' (libpath,'|tuya_set_value_bool') 'P' 'I' 'I'
      SetValueInt←⎕NA 'T' (libpath,'|tuya_set_value_int') 'P' 'I' 'I'
      SetValueString←⎕NA 'T' (libpath,'|tuya_set_value_string') 'P' 'I' 'T'
      SetValueFloat←⎕NA 'T' (libpath,'|tuya_set_value_float') 'P' 'I' 'F8'
      TurnOn←⎕NA 'T' (libpath,'|tuya_turn_on') 'P' 'I'
      TurnOff←⎕NA 'T' (libpath,'|tuya_turn_off') 'P' 'I'
      Status←⎕NA 'T' (libpath,'|tuya_status') 'P'
      Heartbeat←⎕NA 'T' (libpath,'|tuya_heartbeat') 'P'

      ⍝ Memory
      FreeString←⎕NA '' (libpath,'|tuya_free_string') 'P'

      ⍝ device22
      SetDevice22←⎕NA '' (libpath,'|tuya_set_device22') 'P' 'T'
      IsDevice22←⎕NA 'I' (libpath,'|tuya_is_device22') 'P'
    ∇

    ═══════════════════════════════════════════════════════════
    ⍝ Type-aware SetValue dispatcher
    ═══════════════════════════════════════════════════════════

    ∇ r←SetValue args;dev;dp;val;tp
      ⍝ args  3-element nested vector: (dev dp value)
      ⍝       where dev=device-handle, dp=datapoint, value=value to set
      (dev dp val)←3↑args
      tp←10|⎕DR val
      :Select tp
      :Case 1  ⍝ boolean (DR 11 → 1)
          r←SetValueBool dev dp val
      :Case 3  ⍝ integer (DR 83 → 3)
          r←SetValueInt dev dp val
      :Case 5  ⍝ float (DR 645 → 5)
          r←SetValueFloat dev dp val
      :Case 2  ⍝ char vector (DR 82 → 2)
          r←SetValueString dev dp val
      :Else
          r←SetValueString dev dp(⍕val)
      :EndSelect
    ∇

    ═══════════════════════════════════════════════════════════
    ⍝ Command constants
    ═══════════════════════════════════════════════════════════

    CMD_CONTROL←7 ⋄ CMD_DP_QUERY←10 ⋄ CMD_HEART_BEAT←9
    CMD_STATUS←8 ⋄ CMD_CONTROL_NEW←13 ⋄ CMD_DP_QUERY_NEW←16
    DEFAULT_PORT←6668 ⋄ BUFSIZE←1024
    DEFAULT_RETRY_LIMIT←5 ⋄ DEFAULT_RETRY_DELAY_MS←100

    PROTO_V31←0 ⋄ PROTO_V33←1 ⋄ PROTO_V34←2 ⋄ PROTO_V35←3

:EndNamespace
