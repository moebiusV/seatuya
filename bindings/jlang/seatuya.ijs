NB. seatuya.ijs -- FFI bindings for libseatuya
NB.
NB. Uses the 'dll' addon's cd conjunction for C FFI.
NB. Library path: SEATUYA_LIB env var, or platform default.
NB.
NB. Usage:
NB.   load 'seatuya'
NB.   dev=: seatuya_create device_id;ip;local_key;ver
NB.   smoutput seatuya_turn_on dev;1
NB.   seatuya_destroy dev

require 'dll'

NB. ===================================================================
NB. Library discovery
NB. ===================================================================

libpath=: 'libseatuya.so'
env=: 2!:5 'SEATUYA_LIB'
if. _1 ~: env do.
  libpath=: env
end.
cdbind_j_ libpath

NB. ===================================================================
NB. Internal helpers
NB. ===================================================================

NB. consume: copy malloc'd C string to J string, free C memory
consume=: 3 : 0
  if. y = 0 do. '' return. end.
  r=. _1 memr y, 0 _1
  ('n';'*c') 'tuya_free_string' cd ,<y
  r
)

NB. readptr: read non-freeable C string from pointer address
readptr=: 3 : 0
  if. y = 0 do. '' else. _1 memr y, 0 _1 end.
)

NB. boolin: convert C int (0/1) to J boolean (0/1)
boolin=: 3 : '0 ~: > {. y'

NB. ===================================================================
NB. Lifecycle
NB. ===================================================================

tuya_version=: 3 : 0
  readptr > {. ('*c';'') 'tuya_version' cd 0$a:
)

tuya_create=: 3 : 0
  'device_id address local_key ver'=. y
  > {. ('*';'*c *c *c *c') 'tuya_create' cd device_id;address;local_key;ver
)

tuya_alloc=: 3 : 0
  'ver'=. y
  > {. ('*';'*c') 'tuya_alloc' cd ,<ver
)

tuya_destroy=: 3 : 0
  ('n';'*') 'tuya_destroy' cd ,<y
  EMPTY
)

NB. ===================================================================
NB. Credentials
NB. ===================================================================

tuya_set_credentials=: 3 : 0
  'dev device_id local_key'=. y
  ('n';'* *c *c') 'tuya_set_credentials' cd dev;device_id;local_key
  EMPTY
)

tuya_get_device_id=: 3 : 0
  readptr > {. ('*c';'*') 'tuya_get_device_id' cd ,<y
)

tuya_get_local_key=: 3 : 0
  readptr > {. ('*c';'*') 'tuya_get_local_key' cd ,<y
)

tuya_get_ip=: 3 : 0
  readptr > {. ('*c';'*') 'tuya_get_ip' cd ,<y
)

NB. ===================================================================
NB. Connection
NB. ===================================================================

tuya_connect=: 3 : 0
  'dev hostname'=. y
  boolin ('i';'* *c') 'tuya_connect' cd dev;hostname
)

tuya_disconnect=: 3 : 0
  ('n';'*') 'tuya_disconnect' cd ,<y
  EMPTY
)

tuya_is_connected=: 3 : 0
  boolin ('i';'*') 'tuya_is_connected' cd ,<y
)

tuya_reconnect=: 3 : 0
  boolin ('i';'*') 'tuya_reconnect' cd ,<y
)

NB. ===================================================================
NB. Retry
NB. ===================================================================

tuya_set_retry_limit=: 3 : 0
  'dev limit'=. y
  ('n';'* i') 'tuya_set_retry_limit' cd dev;limit
  EMPTY
)

tuya_set_retry_delay=: 3 : 0
  'dev ms'=. y
  ('n';'* i') 'tuya_set_retry_delay' cd dev;ms
  EMPTY
)

tuya_get_retry_limit=: 3 : 0
  > {. ('i';'*') 'tuya_get_retry_limit' cd ,<y
)

tuya_get_retry_delay=: 3 : 0
  > {. ('i';'*') 'tuya_get_retry_delay' cd ,<y
)

NB. ===================================================================
NB. Session negotiation
NB. ===================================================================

tuya_negotiate_session=: 3 : 0
  'dev local_key'=. y
  boolin ('i';'* *c') 'tuya_negotiate_session' cd dev;local_key
)

tuya_negotiate_session_start=: 3 : 0
  'dev local_key'=. y
  boolin ('i';'* *c') 'tuya_negotiate_session_start' cd dev;local_key
)

tuya_negotiate_session_finalize=: 3 : 0
  'dev buf local_key'=. y
  boolin ('i';'* *c i *c') 'tuya_negotiate_session_finalize' cd dev;buf;(#buf);local_key
)

NB. ===================================================================
NB. State queries
NB. ===================================================================

tuya_get_protocol=: 3 : 0
  > {. ('i';'*') 'tuya_get_protocol' cd ,<y
)

tuya_get_session_state=: 3 : 0
  > {. ('i';'*') 'tuya_get_session_state' cd ,<y
)

tuya_get_socket_state=: 3 : 0
  > {. ('i';'*') 'tuya_get_socket_state' cd ,<y
)

tuya_get_last_error=: 3 : 0
  > {. ('i';'*') 'tuya_get_last_error' cd ,<y
)

NB. ===================================================================
NB. Async mode
NB. ===================================================================

tuya_set_async_mode=: 3 : 0
  'dev flag'=. y
  ('n';'* i') 'tuya_set_async_mode' cd dev;flag
  EMPTY
)

tuya_is_socket_readable=: 3 : 0
  boolin ('i';'*') 'tuya_is_socket_readable' cd ,<y
)

tuya_is_socket_writable=: 3 : 0
  boolin ('i';'*') 'tuya_is_socket_writable' cd ,<y
)

tuya_set_session_ready=: 3 : 0
  boolin ('i';'*') 'tuya_set_session_ready' cd ,<y
)

NB. ===================================================================
NB. Low-level message operations
NB. ===================================================================

NB. build_message uses a string buffer; embedded nulls in binary
NB. payload may truncate the J string (known FFI limitation).
tuya_build_message=: 3 : 0
  'dev cmd payload key'=. y
  buf=. 1024 $ ' '
  n=. > {. ('i';'* *c i *c *c') 'tuya_build_message' cd dev;buf;cmd;payload;key
  if. n > 0 do. n {. buf else. '' end.
)

tuya_decode_message=: 3 : 0
  'dev buf key'=. y
  consume > {. ('*c';'* *c i *c') 'tuya_decode_message' cd dev;buf;(#buf);key
)

tuya_generate_payload=: 3 : 0
  'dev cmd device_id datapoints'=. y
  consume > {. ('*c';'* i *c *c') 'tuya_generate_payload' cd dev;cmd;device_id;datapoints
)

tuya_send=: 3 : 0
  'dev buf'=. y
  > {. ('i';'* *c i') 'tuya_send' cd dev;buf;(#buf)
)

tuya_receive=: 3 : 0
  'dev maxsize minsize'=. y
  buf=. maxsize $ ' '
  n=. > {. ('i';'* *c i i') 'tuya_receive' cd dev;buf;maxsize;minsize
  if. n > 0 do. n {. buf else. '' end.
)

NB. ===================================================================
NB. High-level round-trip operations
NB. ===================================================================

NB. set_value: type-aware dispatch (bool, int, float, or string)
NB.   y = dev;dp;value
tuya_set_value=: 3 : 0
  'dev dp val'=. y
  select. (3!:0) val
  case. 1 do.  NB. boolean (J boolean is integer 1 extended)
    consume > {. ('*c';'* i i') 'tuya_set_value_bool' cd dev;dp;val
  case. 4 do.  NB. integer
    consume > {. ('*c';'* i i') 'tuya_set_value_int' cd dev;dp;val
  case. 8 do.  NB. float (real)
    consume > {. ('*c';'* i d') 'tuya_set_value_float' cd dev;dp;val
  case. 2 do.  NB. literal (string)
    consume > {. ('*c';'* i *c') 'tuya_set_value_string' cd dev;dp;val
  case. do.
    'ERROR: unsupported type'
  end.
)

NB. Helper: detect J boolean (1 or 0 extended integer)
NB. In J, boolean is type 1 (Boolean), integer is type 4.
NB. We use (3!:0) for type detection.
NB. For boolean, we check if val is 1 or 0 and treat as bool.
NB. We handle this in set_value.

tuya_turn_on=: 3 : 0
  'dev dp'=. y
  consume > {. ('*c';'* i') 'tuya_turn_on' cd dev;dp
)

tuya_turn_off=: 3 : 0
  'dev dp'=. y
  consume > {. ('*c';'* i') 'tuya_turn_off' cd dev;dp
)

tuya_status=: 3 : 0
  consume > {. ('*c';'*') 'tuya_status' cd ,<y
)

tuya_heartbeat=: 3 : 0
  consume > {. ('*c';'*') 'tuya_heartbeat' cd ,<y
)

NB. ===================================================================
NB. device22
NB. ===================================================================

tuya_set_device22=: 3 : 0
  'dev json'=. y
  if. #json do.
    ('n';'* *c') 'tuya_set_device22' cd dev;json
  else.
    ('n';'* *c') 'tuya_set_device22' cd dev;' '
  end.
  EMPTY
)

tuya_is_device22=: 3 : 0
  boolin ('i';'*') 'tuya_is_device22' cd ,<y
)

NB. ===================================================================
NB. Constants
NB. ===================================================================

NB. Tuya command types
CMD_UDP=: 0
CMD_AP_CONFIG=: 1
CMD_ACTIVE=: 2
CMD_BIND=: 3
CMD_RENAME_GW=: 4
CMD_RENAME_DEVICE=: 5
CMD_UNBIND=: 6
CMD_CONTROL=: 7
CMD_STATUS=: 8
CMD_HEART_BEAT=: 9
CMD_DP_QUERY=: 10
CMD_QUERY_WIFI=: 11
CMD_TOKEN_BIND=: 12
CMD_CONTROL_NEW=: 13
CMD_ENABLE_WIFI=: 14
CMD_DP_QUERY_NEW=: 16
CMD_SCENE_EXECUTE=: 17
CMD_UPDATEDPS=: 18
CMD_UDP_NEW=: 19
CMD_AP_CONFIG_NEW=: 20
CMD_GET_LOCAL_TIME=: 28
CMD_WEATHER_OPEN=: 32
CMD_WEATHER_DATA=: 33
CMD_STATE_UPLOAD_SYN=: 34
CMD_STATE_UPLOAD_SYN_RECV=: 35
CMD_HEART_BEAT_STOP=: 37
CMD_STREAM_TRANS=: 38
CMD_GET_WIFI_STATUS=: 43
CMD_WIFI_CONNECT_TEST=: 44
CMD_GET_MAC=: 45
CMD_GET_IR_STATUS=: 46
CMD_IR_TX_RX_TEST=: 47
CMD_LAN_GW_ACTIVE=: 240
CMD_LAN_SUB_DEV_REQUEST=: 241
CMD_LAN_DELETE_SUB_DEV=: 242
CMD_LAN_REPORT_SUB_DEV=: 243
CMD_LAN_SCENE=: 244
CMD_LAN_PUBLISH_CLOUD_CONFIG=: 245
CMD_LAN_PUBLISH_APP_CONFIG=: 246
CMD_LAN_EXPORT_APP_CONFIG=: 247
CMD_LAN_PUBLISH_SCENE_PANEL=: 248
CMD_LAN_REMOVE_GW=: 249
CMD_LAN_CHECK_GW_UPDATE=: 250
CMD_LAN_GW_UPDATE=: 251
CMD_LAN_SET_GW_CHANNEL=: 252

NB. Protocol versions
PROTO_V31=: 0
PROTO_V33=: 1
PROTO_V34=: 2
PROTO_V35=: 3

NB. Session states
SESSION_INVALID=: 0
SESSION_STARTING=: 1
SESSION_FINALIZING=: 2
SESSION_ESTABLISHED=: 3

NB. Socket states
SOCK_NO_SUCH_HOST=: 0
SOCK_NO_SOCK_AVAIL=: 1
SOCK_FAILED=: 2
SOCK_DISCONNECTED=: 3
SOCK_CONNECTING=: 4
SOCK_CONNECTED=: 5
SOCK_READY=: 6
SOCK_RECEIVING=: 7

DEFAULT_PORT=: 6668
BUFSIZE=: 1024
DEFAULT_RETRY_LIMIT=: 5
DEFAULT_RETRY_DELAY_MS=: 100

smoutput 'seatuya.ijs loaded'
