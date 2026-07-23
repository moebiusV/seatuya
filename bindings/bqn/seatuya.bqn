# seatuya.bqn — BQN FFI bindings for libseatuya
#
# BQN binding using CBQN's •FFI system value.  BQN is an array-oriented
# language; this module provides a namespace of functions for controlling
# Tuya devices through libseatuya.
#
# Usage (from CBQN):
#   ⟨seatuya⟩ ← •Import "seatuya.bqn"
#   dev ← seatuya.Create device_id "192.168.1.100" local_key "3.4"
#   •Show seatuya.TurnOn dev 1
#   seatuya.Destroy dev
#
# Note: BQN's FFI requires CBQN built with libffi support.
#   https://github.com/dzaima/CBQN

# Library path
Lib ⇐ { ("SEATUYA_LIB"•env) ? •FFI.•lib (
  "libseatuya.so"     # Linux
  "libseatuya.dylib"  # macOS
  "seatuya.dll"       # Windows
)}

# ── Lifecycle ──
Version    ⇐ {•FFI.•call Lib "tuya_version" ⋄ •FFI.•str @}
Create     ⇐ {•FFI.•call Lib "tuya_create" ⋄ @}
Alloc      ⇐ {•FFI.•call Lib "tuya_alloc" ⋄ @}
Destroy    ⇐ {•FFI.•call Lib "tuya_destroy" ⋄ @}

# ── Credentials ──
SetCredentials ⇐ {•FFI.•call Lib "tuya_set_credentials" ⋄ @}
GetDeviceId    ⇐ {•FFI.•call Lib "tuya_get_device_id" ⋄ •FFI.•str @}
GetLocalKey    ⇐ {•FFI.•call Lib "tuya_get_local_key" ⋄ •FFI.•str @}
GetIp          ⇐ {•FFI.•call Lib "tuya_get_ip" ⋄ •FFI.•str @}

# ── Connection ──
Connect      ⇐ {•FFI.•call Lib "tuya_connect" ⋄ @}
Disconnect   ⇐ {•FFI.•call Lib "tuya_disconnect" ⋄ @}
IsConnected  ⇐ {•FFI.•call Lib "tuya_is_connected" ⋄ @}
Reconnect    ⇐ {•FFI.•call Lib "tuya_reconnect" ⋄ @}

# ── Retry ──
SetRetryLimit ⇐ {•FFI.•call Lib "tuya_set_retry_limit" ⋄ @}
SetRetryDelay ⇐ {•FFI.•call Lib "tuya_set_retry_delay" ⋄ @}
GetRetryLimit ⇐ {•FFI.•call Lib "tuya_get_retry_limit" ⋄ @}
GetRetryDelay ⇐ {•FFI.•call Lib "tuya_get_retry_delay" ⋄ @}

# ── Session ──
NegotiateSession ⇐ {•FFI.•call Lib "tuya_negotiate_session" ⋄ @}

# ── State queries ──
GetProtocol     ⇐ {•FFI.•call Lib "tuya_get_protocol" ⋄ @}
GetSessionState ⇐ {•FFI.•call Lib "tuya_get_session_state" ⋄ @}
GetSocketState  ⇐ {•FFI.•call Lib "tuya_get_socket_state" ⋄ @}
GetLastError    ⇐ {•FFI.•call Lib "tuya_get_last_error" ⋄ @}

# ── Async ──
SetAsyncMode       ⇐ {•FFI.•call Lib "tuya_set_async_mode" ⋄ @}
IsSocketReadable   ⇐ {•FFI.•call Lib "tuya_is_socket_readable" ⋄ @}
IsSocketWritable   ⇐ {•FFI.•call Lib "tuya_is_socket_writable" ⋄ @}
SetSessionReady    ⇐ {•FFI.•call Lib "tuya_set_session_ready" ⋄ @}

# ── Low-level ──
BuildMessage      ⇐ {•FFI.•call Lib "tuya_build_message" ⋄ @}
DecodeMessage     ⇐ {•FFI.•call Lib "tuya_decode_message" ⋄ @}
GeneratePayload   ⇐ {•FFI.•call Lib "tuya_generate_payload" ⋄ @}
Send              ⇐ {•FFI.•call Lib "tuya_send" ⋄ @}
Receive           ⇐ {•FFI.•call Lib "tuya_receive" ⋄ @}

# ── High-level round-trip ──
# Helper: consume a malloc'd C string, auto-free
_ConsumeStr ← {ptr:
  (ptr=@) ? @ ;  # NULL → return @ (null)
  s ← •FFI.•str ptr
  •FFI.•call Lib "tuya_free_string" ⋄ ptr
  s
}

SetValueBool   ⇐ {•FFI.•call Lib "tuya_set_value_bool" ⋄ _ConsumeStr @}
SetValueInt    ⇐ {•FFI.•call Lib "tuya_set_value_int" ⋄ _ConsumeStr @}
SetValueString ⇐ {•FFI.•call Lib "tuya_set_value_string" ⋄ _ConsumeStr @}
SetValueFloat  ⇐ {•FFI.•call Lib "tuya_set_value_float" ⋄ _ConsumeStr @}

# Type-aware setter
SetValue ⇐ {dev dp value:
  {𝕊: (•Type value)≡"number" ?
    {𝕊: (= value ⌊value) ? SetValueInt dev dp value ; SetValueFloat dev dp value}
    {𝕊: (•Type value)≡"string" ? SetValueString dev dp value ; SetValueBool dev dp value}
  }
}

TurnOn    ⇐ {•FFI.•call Lib "tuya_turn_on" ⋄ _ConsumeStr @}
TurnOff   ⇐ {•FFI.•call Lib "tuya_turn_off" ⋄ _ConsumeStr @}
Status    ⇐ {•FFI.•call Lib "tuya_status" ⋄ _ConsumeStr @}
Heartbeat ⇐ {•FFI.•call Lib "tuya_heartbeat" ⋄ _ConsumeStr @}

# ── device22 ──
SetDevice22 ⇐ {•FFI.•call Lib "tuya_set_device22" ⋄ @}
IsDevice22  ⇐ {•FFI.•call Lib "tuya_is_device22" ⋄ @}

# ── Constants ──
Command ⇐ [
  0‿"UDP"                     1‿"AP_CONFIG"
  2‿"ACTIVE"                  3‿"BIND"
  4‿"RENAME_GW"               5‿"RENAME_DEVICE"
  6‿"UNBIND"                  7‿"CONTROL"
  8‿"STATUS"                  9‿"HEART_BEAT"
  10‿"DP_QUERY"               11‿"QUERY_WIFI"
  12‿"TOKEN_BIND"             13‿"CONTROL_NEW"
  14‿"ENABLE_WIFI"            16‿"DP_QUERY_NEW"
  17‿"SCENE_EXECUTE"          18‿"UPDATEDPS"
  19‿"UDP_NEW"                20‿"AP_CONFIG_NEW"
  28‿"GET_LOCAL_TIME"         32‿"WEATHER_OPEN"
  33‿"WEATHER_DATA"           34‿"STATE_UPLOAD_SYN"
  35‿"STATE_UPLOAD_SYN_RECV"  37‿"HEART_BEAT_STOP"
  38‿"STREAM_TRANS"           43‿"GET_WIFI_STATUS"
  44‿"WIFI_CONNECT_TEST"      45‿"GET_MAC"
  46‿"GET_IR_STATUS"          47‿"IR_TX_RX_TEST"
  240‿"LAN_GW_ACTIVE"         241‿"LAN_SUB_DEV_REQUEST"
  242‿"LAN_DELETE_SUB_DEV"    243‿"LAN_REPORT_SUB_DEV"
  244‿"LAN_SCENE"             245‿"LAN_PUBLISH_CLOUD_CONFIG"
  246‿"LAN_PUBLISH_APP_CONFIG" 247‿"LAN_EXPORT_APP_CONFIG"
  248‿"LAN_PUBLISH_SCENE_PANEL" 249‿"LAN_REMOVE_GW"
  250‿"LAN_CHECK_GW_UPDATE"   251‿"LAN_GW_UPDATE"
  252‿"LAN_SET_GW_CHANNEL"
]

# Exported namespace
⟨Version Create Alloc Destroy
 SetCredentials GetDeviceId GetLocalKey GetIp
 Connect Disconnect IsConnected Reconnect
 SetRetryLimit SetRetryDelay GetRetryLimit GetRetryDelay
 NegotiateSession
 GetProtocol GetSessionState GetSocketState GetLastError
 SetAsyncMode IsSocketReadable IsSocketWritable SetSessionReady
 BuildMessage DecodeMessage GeneratePayload Send Receive
 SetValue SetValueBool SetValueInt SetValueString SetValueFloat
 TurnOn TurnOff Status Heartbeat
 SetDevice22 IsDevice22
 Command Lib⟩
