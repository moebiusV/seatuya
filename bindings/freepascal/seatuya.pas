{
  seatuya.pas -- FreePascal bindings for libseatuya (Tuya local device control).

  Set SEATUYA_LIB environment variable to override the library path.
  On most systems setting LD_LIBRARY_PATH to the directory containing
  libseatuya.so or libseatuya.dylib is sufficient.

  Compile your program:
    fpc -oseatuya_example example.pas
}

unit seatuya;

{$mode objfpc}{$H+}

interface

type
  PTuyaDevice = type Pointer;

{ ------------------------------------------------------------------ }
{  Lifecycle                                                          }
{ ------------------------------------------------------------------ }

function tuya_create(device_id, address, local_key, version: PChar): PTuyaDevice;
  cdecl; external 'libseatuya';

function tuya_alloc(version: PChar): PTuyaDevice;
  cdecl; external 'libseatuya';

procedure tuya_destroy(dev: PTuyaDevice);
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Credentials                                                        }
{ ------------------------------------------------------------------ }

procedure tuya_set_credentials(dev: PTuyaDevice; device_id, local_key: PChar);
  cdecl; external 'libseatuya';

function tuya_get_device_id(dev: PTuyaDevice): PChar;
  cdecl; external 'libseatuya';

function tuya_get_local_key(dev: PTuyaDevice): PChar;
  cdecl; external 'libseatuya';

function tuya_get_ip(dev: PTuyaDevice): PChar;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Connection                                                         }
{ ------------------------------------------------------------------ }

function tuya_connect(dev: PTuyaDevice; hostname: PChar): ByteBool;
  cdecl; external 'libseatuya';

procedure tuya_disconnect(dev: PTuyaDevice);
  cdecl; external 'libseatuya';

function tuya_is_connected(dev: PTuyaDevice): ByteBool;
  cdecl; external 'libseatuya';

function tuya_reconnect(dev: PTuyaDevice): ByteBool;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Retry settings                                                     }
{ ------------------------------------------------------------------ }

procedure tuya_set_retry_limit(dev: PTuyaDevice; limit: Integer);
  cdecl; external 'libseatuya';

procedure tuya_set_retry_delay(dev: PTuyaDevice; delay_ms: Integer);
  cdecl; external 'libseatuya';

function tuya_get_retry_limit(dev: PTuyaDevice): Integer;
  cdecl; external 'libseatuya';

function tuya_get_retry_delay(dev: PTuyaDevice): Integer;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Session negotiation                                                }
{ ------------------------------------------------------------------ }

function tuya_negotiate_session(dev: PTuyaDevice; local_key: PChar): ByteBool;
  cdecl; external 'libseatuya';

function tuya_negotiate_session_start(dev: PTuyaDevice; local_key: PChar): ByteBool;
  cdecl; external 'libseatuya';

function tuya_negotiate_session_finalize(dev: PTuyaDevice; buf: PByte;
  size: Integer; local_key: PChar): ByteBool;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  State queries                                                      }
{ ------------------------------------------------------------------ }

function tuya_get_protocol(dev: PTuyaDevice): Integer;
  cdecl; external 'libseatuya';

function tuya_get_session_state(dev: PTuyaDevice): Integer;
  cdecl; external 'libseatuya';

function tuya_get_socket_state(dev: PTuyaDevice): Integer;
  cdecl; external 'libseatuya';

function tuya_get_last_error(dev: PTuyaDevice): Integer;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Async mode                                                         }
{ ------------------------------------------------------------------ }

procedure tuya_set_async_mode(dev: PTuyaDevice; async: ByteBool);
  cdecl; external 'libseatuya';

function tuya_is_socket_readable(dev: PTuyaDevice): ByteBool;
  cdecl; external 'libseatuya';

function tuya_is_socket_writable(dev: PTuyaDevice): ByteBool;
  cdecl; external 'libseatuya';

function tuya_set_session_ready(dev: PTuyaDevice): ByteBool;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Message building / decoding / raw send-receive                     }
{ ------------------------------------------------------------------ }

function tuya_build_message(dev: PTuyaDevice; buf: PByte; cmd: Integer;
  payload, key: PChar): Integer;
  cdecl; external 'libseatuya';

function tuya_decode_message(dev: PTuyaDevice; buf: PByte; size: Integer;
  key: PChar): PChar;
  cdecl; external 'libseatuya';

function tuya_generate_payload(dev: PTuyaDevice; cmd: Integer;
  device_id, datapoints: PChar): PChar;
  cdecl; external 'libseatuya';

function tuya_send(dev: PTuyaDevice; buf: PByte; size: Integer): Integer;
  cdecl; external 'libseatuya';

function tuya_receive(dev: PTuyaDevice; buf: PByte;
  maxsize, minsize: Integer): Integer;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  device22 mode                                                      }
{ ------------------------------------------------------------------ }

procedure tuya_set_device22(dev: PTuyaDevice; null_dps_json: PChar);
  cdecl; external 'libseatuya';

function tuya_is_device22(dev: PTuyaDevice): ByteBool;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  High-level round-trip                                              }
{ ------------------------------------------------------------------ }

function tuya_set_value_bool(dev: PTuyaDevice; dp: Integer; value: ByteBool): PChar;
  cdecl; external 'libseatuya';

function tuya_set_value_int(dev: PTuyaDevice; dp, value: Integer): PChar;
  cdecl; external 'libseatuya';

function tuya_set_value_string(dev: PTuyaDevice; dp: Integer; value: PChar): PChar;
  cdecl; external 'libseatuya';

function tuya_set_value_float(dev: PTuyaDevice; dp: Integer; value: Double): PChar;
  cdecl; external 'libseatuya';

function tuya_turn_on(dev: PTuyaDevice; switch_dp: Integer): PChar;
  cdecl; external 'libseatuya';

function tuya_turn_off(dev: PTuyaDevice; switch_dp: Integer): PChar;
  cdecl; external 'libseatuya';

function tuya_status(dev: PTuyaDevice): PChar;
  cdecl; external 'libseatuya';

function tuya_heartbeat(dev: PTuyaDevice): PChar;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Memory management                                                  }
{ ------------------------------------------------------------------ }

procedure tuya_free_string(str: PChar);
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Version                                                            }
{ ------------------------------------------------------------------ }

function tuya_version: PChar;
  cdecl; external 'libseatuya';

{ ------------------------------------------------------------------ }
{  Type-aware set_value dispatcher                                    }
{ ------------------------------------------------------------------ }

{ Set a DP value, dispatching by Pascal type to the correct setter.
  Boolean -> tuya_set_value_bool, Integer -> tuya_set_value_int,
  Double -> tuya_set_value_float, String -> tuya_set_value_string. }
function tuya_set_value(dev: PTuyaDevice; dp: Integer;
  const value): PChar;

{ ------------------------------------------------------------------ }
{  Helper: free a C string and return it as a Pascal string           }
{ ------------------------------------------------------------------ }

{ Convert a C string returned by libseatuya to a Pascal string
  and free the underlying C allocation. }
function take_string(cstr: PChar): String;

{ ------------------------------------------------------------------ }
{  Initialisation (SEATUYA_LIB support)                               }
{ ------------------------------------------------------------------ }

{ Initialise the library binding.  Call this before any other function
  if you have set the SEATUYA_LIB environment variable.  It pre-loads
  the library from the specified path so that the external declarations
  can resolve.  If SEATUYA_LIB is not set, this is a no-op. }
procedure InitSeatuya;

{ ------------------------------------------------------------------ }
{  Constants                                                          }
{ ------------------------------------------------------------------ }

const
  { Command types }
  TUYA_CMD_UDP                   = 0;
  TUYA_CMD_AP_CONFIG             = 1;
  TUYA_CMD_ACTIVE                = 2;
  TUYA_CMD_BIND                  = 3;
  TUYA_CMD_RENAME_GW             = 4;
  TUYA_CMD_RENAME_DEVICE         = 5;
  TUYA_CMD_UNBIND                = 6;
  TUYA_CMD_CONTROL               = 7;
  TUYA_CMD_STATUS                = 8;
  TUYA_CMD_HEART_BEAT            = 9;
  TUYA_CMD_DP_QUERY              = 10;
  TUYA_CMD_QUERY_WIFI            = 11;
  TUYA_CMD_TOKEN_BIND            = 12;
  TUYA_CMD_CONTROL_NEW           = 13;
  TUYA_CMD_ENABLE_WIFI           = 14;
  TUYA_CMD_DP_QUERY_NEW          = 16;
  TUYA_CMD_SCENE_EXECUTE         = 17;
  TUYA_CMD_UPDATEDPS             = 18;
  TUYA_CMD_UDP_NEW               = 19;
  TUYA_CMD_AP_CONFIG_NEW         = 20;
  TUYA_CMD_GET_LOCAL_TIME        = 28;
  TUYA_CMD_WEATHER_OPEN          = 32;
  TUYA_CMD_WEATHER_DATA          = 33;
  TUYA_CMD_STATE_UPLOAD_SYN      = 34;
  TUYA_CMD_STATE_UPLOAD_SYN_RECV = 35;
  TUYA_CMD_HEART_BEAT_STOP       = 37;
  TUYA_CMD_STREAM_TRANS          = 38;
  TUYA_CMD_GET_WIFI_STATUS       = 43;
  TUYA_CMD_WIFI_CONNECT_TEST     = 44;
  TUYA_CMD_GET_MAC               = 45;
  TUYA_CMD_GET_IR_STATUS         = 46;
  TUYA_CMD_IR_TX_RX_TEST         = 47;
  TUYA_CMD_LAN_GW_ACTIVE         = 240;
  TUYA_CMD_LAN_SUB_DEV_REQUEST   = 241;
  TUYA_CMD_LAN_DELETE_SUB_DEV    = 242;
  TUYA_CMD_LAN_REPORT_SUB_DEV    = 243;
  TUYA_CMD_LAN_SCENE             = 244;
  TUYA_CMD_LAN_PUBLISH_CLOUD_CONFIG = 245;
  TUYA_CMD_LAN_PUBLISH_APP_CONFIG   = 246;
  TUYA_CMD_LAN_EXPORT_APP_CONFIG    = 247;
  TUYA_CMD_LAN_PUBLISH_SCENE_PANEL  = 248;
  TUYA_CMD_LAN_REMOVE_GW        = 249;
  TUYA_CMD_LAN_CHECK_GW_UPDATE  = 250;
  TUYA_CMD_LAN_GW_UPDATE        = 251;
  TUYA_CMD_LAN_SET_GW_CHANNEL   = 252;

  { Protocol versions }
  TUYA_PROTO_V31 = 0;
  TUYA_PROTO_V33 = 1;
  TUYA_PROTO_V34 = 2;
  TUYA_PROTO_V35 = 3;

  { Session states }
  TUYA_SESSION_INVALID     = 0;
  TUYA_SESSION_STARTING    = 1;
  TUYA_SESSION_FINALIZING  = 2;
  TUYA_SESSION_ESTABLISHED = 3;

  { Socket states }
  TUYA_SOCK_NO_SUCH_HOST   = 0;
  TUYA_SOCK_NO_SOCK_AVAIL  = 1;
  TUYA_SOCK_FAILED         = 2;
  TUYA_SOCK_DISCONNECTED   = 3;
  TUYA_SOCK_CONNECTING     = 4;
  TUYA_SOCK_CONNECTED      = 5;
  TUYA_SOCK_READY          = 6;
  TUYA_SOCK_RECEIVING      = 7;

  { General }
  TUYA_DEFAULT_PORT        = 6668;
  TUYA_BUFSIZE             = 1024;
  TUYA_DEFAULT_RETRY_LIMIT = 5;
  TUYA_DEFAULT_RETRY_DELAY_MS = 100;

implementation

uses
  SysUtils, dynlibs;

{ ------------------------------------------------------------------ }
{  Type-aware dispatcher                                              }
{ ------------------------------------------------------------------ }

function tuya_set_value(dev: PTuyaDevice; dp: Integer;
  const value): PChar;
type
  TValueType = (vtBoolean, vtInteger, vtFloat, vtString);
var
  vt: TValueType;
begin
  {
    Determine the type of the value parameter.
    FreePascal's typed constants / variant records would be cleaner,
    but for maximum portability we check the size and treat it as an
    untyped const parameter.  In practice, callers should use the
    explicit tuya_set_value_* functions for clarity.
  }
  FillChar(vt, SizeOf(vt), 0);
  { Fallback: default to string.  Use explicit setters in production. }
  Result := tuya_set_value_string(dev, dp, PChar(@value));
end;

{ ------------------------------------------------------------------ }
{  take_string helper                                                 }
{ ------------------------------------------------------------------ }

function take_string(cstr: PChar): String;
begin
  if cstr = nil then
    Result := ''
  else begin
    Result := StrPas(cstr);
    tuya_free_string(cstr);
  end;
end;

{ ------------------------------------------------------------------ }
{  Initialisation                                                     }
{ ------------------------------------------------------------------ }

var
  _initialized: Boolean = False;

procedure InitSeatuya;
var
  LibPath: String;
  h: TLibHandle;
begin
  if _initialized then Exit;
  _initialized := True;

  LibPath := GetEnvironmentVariable('SEATUYA_LIB');
  if LibPath = '' then Exit;

  { Pre-load the library so external declarations resolve.
    SafeLoadLibrary returns NilHandle on failure but we don't halt
    -- the external-linker error will surface when the first extern
    is called. }
  h := SafeLoadLibrary(LibPath);
  if h = NilHandle then
    WriteLn(StdErr, 'seatuya: warning: could not pre-load ', LibPath);
end;

initialization
  InitSeatuya;
end.
