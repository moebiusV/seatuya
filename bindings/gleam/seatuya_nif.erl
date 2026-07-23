%%%-------------------------------------------------------------------
%%% @doc Erlang NIF module for seatuya (Gleam binding).
%%%
%%% Loads the NIF shared library (seatuya_nif.so / .dylib / .dll).
%%% The SEATUYA_LIB environment variable overrides the library path.
%%% @end
%%%-------------------------------------------------------------------
-module(seatuya_nif).
-on_load(load_nif/0).

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

%%====================================================================
%% NIF loading
%%====================================================================

load_nif() ->
    Lib = case os:getenv("SEATUYA_LIB") of
              false -> "seatuya_nif";
              Path  -> Path
          end,
    erlang:load_nif(Lib, 0).

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
