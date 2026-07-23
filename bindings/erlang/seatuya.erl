%%%-------------------------------------------------------------------
%%% @doc Erlang NIF wrapper for libseatuya (Tuya local device control).
%%%
%%% Loads `seatuya_nif.so` (or `.dylib`) from the application priv dir,
%%% or from the path in the `SEATUYA_LIB` environment variable.
%%%
%%% Build the NIF:
%%% ```
%%% cc -fPIC -shared -I$ERLANG_ROOT/usr/include \
%%%     -o seatuya_nif.so seatuya_nif.c -lseatuya
%%% ```
%%% @end
%%%-------------------------------------------------------------------
-module(seatuya).

%% Lifecycle
-export([create/4, alloc/1, destroy/1]).

%% Credentials
-export([set_credentials/3,
         get_device_id/1, get_local_key/1, get_ip/1]).

%% Connection
-export([connect/2, disconnect/1, is_connected/1, reconnect/1]).

%% Retry
-export([set_retry_limit/2, set_retry_delay/2,
         get_retry_limit/1, get_retry_delay/1]).

%% Session negotiation
-export([negotiate_session/2, negotiate_session_start/2,
         negotiate_session_finalize/3]).

%% State queries
-export([get_protocol/1, get_session_state/1,
         get_socket_state/1, get_last_error/1]).

%% Async mode
-export([set_async_mode/2,
         is_socket_readable/1, is_socket_writable/1,
         set_session_ready/1]).

%% Message building / decoding / raw send-receive
-export([build_message/5, decode_message/3, generate_payload/4,
         send/2, receive/3]).

%% device22 mode
-export([set_device22/2, is_device22/1]).

%% High-level round-trip operations
-export([set_value_bool/3, set_value_int/3,
         set_value_string/3, set_value_float/3,
         turn_on/2, turn_off/2, status/1, heartbeat/1]).

%% Memory management
-export([free_string/1]).

%% Version
-export([version/0]).

%% Type-aware dispatcher
-export([set_value/3]).

-on_load(load_nif/0).

%%====================================================================
%% NIF loading
%%====================================================================

load_nif() ->
    Lib = case os:getenv("SEATUYA_LIB") of
              false -> filename:join(priv_dir(), "seatuya_nif");
              Path  -> Path
          end,
    erlang:load_nif(Lib, 0).

priv_dir() ->
    case code:priv_dir(seatuya) of
        {error, _} ->
            %% Fallback: assume priv/ is alongside the .erl source
            Ebin = filename:dirname(code:which(?MODULE)),
            filename:join(filename:dirname(Ebin), "priv");
        Dir -> Dir
    end.

%%====================================================================
%% NIF stubs (replaced at load time)
%%====================================================================

version()                     -> erlang:nif_error(not_loaded).
create(_D,_A,_K,_V)           -> erlang:nif_error(not_loaded).
alloc(_V)                     -> erlang:nif_error(not_loaded).
destroy(_D)                   -> erlang:nif_error(not_loaded).
set_credentials(_D,_I,_K)     -> erlang:nif_error(not_loaded).
get_device_id(_D)             -> erlang:nif_error(not_loaded).
get_local_key(_D)             -> erlang:nif_error(not_loaded).
get_ip(_D)                    -> erlang:nif_error(not_loaded).
connect(_D,_H)                -> erlang:nif_error(not_loaded).
disconnect(_D)                -> erlang:nif_error(not_loaded).
is_connected(_D)              -> erlang:nif_error(not_loaded).
reconnect(_D)                 -> erlang:nif_error(not_loaded).
set_retry_limit(_D,_L)        -> erlang:nif_error(not_loaded).
set_retry_delay(_D,_M)        -> erlang:nif_error(not_loaded).
get_retry_limit(_D)           -> erlang:nif_error(not_loaded).
get_retry_delay(_D)           -> erlang:nif_error(not_loaded).
negotiate_session(_D,_K)      -> erlang:nif_error(not_loaded).
negotiate_session_start(_D,_K) -> erlang:nif_error(not_loaded).
negotiate_session_finalize(_D,_B,_K) -> erlang:nif_error(not_loaded).
get_protocol(_D)              -> erlang:nif_error(not_loaded).
get_session_state(_D)         -> erlang:nif_error(not_loaded).
get_socket_state(_D)          -> erlang:nif_error(not_loaded).
get_last_error(_D)            -> erlang:nif_error(not_loaded).
set_async_mode(_D,_A)         -> erlang:nif_error(not_loaded).
is_socket_readable(_D)        -> erlang:nif_error(not_loaded).
is_socket_writable(_D)        -> erlang:nif_error(not_loaded).
set_session_ready(_D)         -> erlang:nif_error(not_loaded).
build_message(_D,_B,_C,_P,_K) -> erlang:nif_error(not_loaded).
decode_message(_D,_B,_K)      -> erlang:nif_error(not_loaded).
generate_payload(_D,_C,_I,_P) -> erlang:nif_error(not_loaded).
send(_D,_B)                   -> erlang:nif_error(not_loaded).
receive(_D,_X,_M)             -> erlang:nif_error(not_loaded).
set_device22(_D,_J)           -> erlang:nif_error(not_loaded).
is_device22(_D)               -> erlang:nif_error(not_loaded).
set_value_bool(_D,_P,_V)      -> erlang:nif_error(not_loaded).
set_value_int(_D,_P,_V)       -> erlang:nif_error(not_loaded).
set_value_string(_D,_P,_V)    -> erlang:nif_error(not_loaded).
set_value_float(_D,_P,_V)     -> erlang:nif_error(not_loaded).
turn_on(_D,_S)                -> erlang:nif_error(not_loaded).
turn_off(_D,_S)               -> erlang:nif_error(not_loaded).
status(_D)                    -> erlang:nif_error(not_loaded).
heartbeat(_D)                 -> erlang:nif_error(not_loaded).
free_string(_S)               -> erlang:nif_error(not_loaded).

%%====================================================================
%% Type-aware dispatcher
%%====================================================================

%% @doc Set a DP value, auto-dispatching by the Erlang type of Value.
%% Booleans -> set_value_bool, integers -> set_value_int,
%% floats -> set_value_float, lists (strings) -> set_value_string.
-spec set_value(term(), non_neg_integer(), boolean() | integer()
                | float() | string()) -> {ok, string()} | {error, term()}.
set_value(Dev, Dp, Value) when is_boolean(Value) ->
    set_value_bool(Dev, Dp, Value);
set_value(Dev, Dp, Value) when is_integer(Value) ->
    set_value_int(Dev, Dp, Value);
set_value(Dev, Dp, Value) when is_float(Value) ->
    set_value_float(Dev, Dp, Value);
set_value(Dev, Dp, Value) when is_list(Value) ->
    set_value_string(Dev, Dp, Value).

%%====================================================================
%% Constants
%%====================================================================

%% Command types
-define(CMD_UDP,                 0).
-define(CMD_AP_CONFIG,           1).
-define(CMD_ACTIVE,              2).
-define(CMD_BIND,                3).
-define(CMD_RENAME_GW,           4).
-define(CMD_RENAME_DEVICE,       5).
-define(CMD_UNBIND,              6).
-define(CMD_CONTROL,             7).
-define(CMD_STATUS,              8).
-define(CMD_HEART_BEAT,          9).
-define(CMD_DP_QUERY,           10).
-define(CMD_QUERY_WIFI,         11).
-define(CMD_TOKEN_BIND,         12).
-define(CMD_CONTROL_NEW,        13).
-define(CMD_ENABLE_WIFI,        14).
-define(CMD_DP_QUERY_NEW,       16).
-define(CMD_SCENE_EXECUTE,      17).
-define(CMD_UPDATEDPS,          18).
-define(CMD_UDP_NEW,            19).
-define(CMD_AP_CONFIG_NEW,      20).
-define(CMD_GET_LOCAL_TIME,     28).
-define(CMD_WEATHER_OPEN,       32).
-define(CMD_WEATHER_DATA,       33).
-define(CMD_STATE_UPLOAD_SYN,   34).
-define(CMD_STATE_UPLOAD_SYN_RECV, 35).
-define(CMD_HEART_BEAT_STOP,    37).
-define(CMD_STREAM_TRANS,       38).
-define(CMD_GET_WIFI_STATUS,    43).
-define(CMD_WIFI_CONNECT_TEST,  44).
-define(CMD_GET_MAC,            45).
-define(CMD_GET_IR_STATUS,      46).
-define(CMD_IR_TX_RX_TEST,     47).
-define(CMD_LAN_GW_ACTIVE,     240).
-define(CMD_LAN_SUB_DEV_REQUEST, 241).
-define(CMD_LAN_DELETE_SUB_DEV, 242).
-define(CMD_LAN_REPORT_SUB_DEV, 243).
-define(CMD_LAN_SCENE,          244).
-define(CMD_LAN_PUBLISH_CLOUD_CONFIG, 245).
-define(CMD_LAN_PUBLISH_APP_CONFIG,   246).
-define(CMD_LAN_EXPORT_APP_CONFIG,    247).
-define(CMD_LAN_PUBLISH_SCENE_PANEL,  248).
-define(CMD_LAN_REMOVE_GW,      249).
-define(CMD_LAN_CHECK_GW_UPDATE, 250).
-define(CMD_LAN_GW_UPDATE,      251).
-define(CMD_LAN_SET_GW_CHANNEL, 252).

%% Protocol versions
-define(PROTO_V31, 0).
-define(PROTO_V33, 1).
-define(PROTO_V34, 2).
-define(PROTO_V35, 3).

%% Session states
-define(SESSION_INVALID,     0).
-define(SESSION_STARTING,    1).
-define(SESSION_FINALIZING,  2).
-define(SESSION_ESTABLISHED, 3).

%% Socket states
-define(SOCK_NO_SUCH_HOST,    0).
-define(SOCK_NO_SOCK_AVAIL,   1).
-define(SOCK_FAILED,          2).
-define(SOCK_DISCONNECTED,    3).
-define(SOCK_CONNECTING,      4).
-define(SOCK_CONNECTED,       5).
-define(SOCK_READY,           6).
-define(SOCK_RECEIVING,       7).

%% General constants
-define(DEFAULT_PORT,    6668).
-define(BUFSIZE,         1024).
-define(DEFAULT_RETRY_LIMIT,    5).
-define(DEFAULT_RETRY_DELAY_MS, 100).

%%====================================================================
%% Convenience API wrappers
%%====================================================================

%% @equiv create(DeviceId, Address, LocalKey, "3.3")
create(DeviceId, Address, LocalKey) ->
    create(DeviceId, Address, LocalKey, "3.3").

%% @doc Create a device and turn on switch DP, returning status.
create_and_turn_on(DeviceId, Address, LocalKey, SwitchDp) ->
    case create(DeviceId, Address, LocalKey) of
        {ok, Dev} ->
            Result = turn_on(Dev, SwitchDp),
            destroy(Dev),
            Result;
        Error -> Error
    end.

%% @doc Create a device and turn off switch DP, returning status.
create_and_turn_off(DeviceId, Address, LocalKey, SwitchDp) ->
    case create(DeviceId, Address, LocalKey) of
        {ok, Dev} ->
            Result = turn_off(Dev, SwitchDp),
            destroy(Dev),
            Result;
        Error -> Error
    end.
