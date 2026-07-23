%%%-------------------------------------------------------------------
%%% @doc Erlang FFI wrapper for Gleam bindings of libseatuya.
%%%
%%% Converts NIF return values into Gleam-friendly types:
%%%   - {error, Atom}  -> {error, String}  (binary)
%%%   - string lists   -> UTF-8 binaries (Gleam String)
%%%   - ok atom        -> nil atom (Gleam Nil)
%%% @end
%%%-------------------------------------------------------------------
-module(seatuya_ffi).
-export([version/0,
         create/4, alloc/1, destroy/1,
         set_credentials/3,
         get_device_id/1, get_local_key/1, get_ip/1,
         connect/2, disconnect/1, is_connected/1, reconnect/1,
         set_retry_limit/2, set_retry_delay/2,
         get_retry_limit/1, get_retry_delay/1,
         negotiate_session/2, negotiate_session_start/2,
         negotiate_session_finalize/3,
         get_protocol/1, get_session_state/1,
         get_socket_state/1, get_last_error/1,
         set_async_mode/2,
         is_socket_readable/1, is_socket_writable/1,
         set_session_ready/1,
         build_message/4, decode_message/3, generate_payload/4,
         send/2, receive/3,
         set_device22/2, is_device22/1,
         set_value_bool/3, set_value_int/3,
         set_value_string/3, set_value_float/3,
         turn_on/2, turn_off/2, status/1, heartbeat/1]).

%%====================================================================
%% Helpers
%%====================================================================

%% Convert an Erlang term (list or binary) to a UTF-8 binary for Gleam.
to_bin([]) -> <<>>;
to_bin(L) when is_list(L) -> list_to_binary(L);
to_bin(B) when is_binary(B) -> B.

%% Convert {error, Atom} to {error, String::binary}.
err_to_bin({error, Reason}) when is_atom(Reason) ->
    {error, to_bin(atom_to_list(Reason))};
err_to_bin({error, Reason}) when is_list(Reason) ->
    {error, to_bin(Reason)};
err_to_bin(Other) -> Other.

%% Convert {ok, StringList} to {ok, StringBinary}.
ok_str_to_bin({ok, S}) -> {ok, to_bin(S)};
ok_str_to_bin(Other)   -> err_to_bin(Other).

%%====================================================================
%% FFI wrappers
%%====================================================================

%% -- Lifecycle --
version() ->
    to_bin(seatuya_nif:version()).

create(DevId, Addr, Key, Ver) ->
    err_to_bin(seatuya_nif:create(DevId, Addr, Key, Ver)).

alloc(Ver) ->
    err_to_bin(seatuya_nif:alloc(Ver)).

destroy(Dev) ->
    seatuya_nif:destroy(Dev),
    nil.

%% -- Credentials --
set_credentials(Dev, DevId, Key) ->
    seatuya_nif:set_credentials(Dev, DevId, Key),
    nil.

get_device_id(Dev) ->
    to_bin(seatuya_nif:get_device_id(Dev)).

get_local_key(Dev) ->
    to_bin(seatuya_nif:get_local_key(Dev)).

get_ip(Dev) ->
    to_bin(seatuya_nif:get_ip(Dev)).

%% -- Connection --
connect(Dev, Host) ->
    seatuya_nif:connect(Dev, Host).

disconnect(Dev) ->
    seatuya_nif:disconnect(Dev),
    nil.

is_connected(Dev) ->
    seatuya_nif:is_connected(Dev).

reconnect(Dev) ->
    seatuya_nif:reconnect(Dev).

%% -- Retry --
set_retry_limit(Dev, Lim) ->
    seatuya_nif:set_retry_limit(Dev, Lim),
    nil.

set_retry_delay(Dev, Ms) ->
    seatuya_nif:set_retry_delay(Dev, Ms),
    nil.

get_retry_limit(Dev) ->
    seatuya_nif:get_retry_limit(Dev).

get_retry_delay(Dev) ->
    seatuya_nif:get_retry_delay(Dev).

%% -- Session --
negotiate_session(Dev, Key) ->
    seatuya_nif:negotiate_session(Dev, Key).

negotiate_session_start(Dev, Key) ->
    seatuya_nif:negotiate_session_start(Dev, Key).

negotiate_session_finalize(Dev, Bin, Key) ->
    seatuya_nif:negotiate_session_finalize(Dev, Bin, Key).

%% -- State --
get_protocol(Dev) ->
    seatuya_nif:get_protocol(Dev).

get_session_state(Dev) ->
    seatuya_nif:get_session_state(Dev).

get_socket_state(Dev) ->
    seatuya_nif:get_socket_state(Dev).

get_last_error(Dev) ->
    seatuya_nif:get_last_error(Dev).

%% -- Async --
set_async_mode(Dev, Async) ->
    seatuya_nif:set_async_mode(Dev, Async),
    nil.

is_socket_readable(Dev) ->
    seatuya_nif:is_socket_readable(Dev).

is_socket_writable(Dev) ->
    seatuya_nif:is_socket_writable(Dev).

set_session_ready(Dev) ->
    seatuya_nif:set_session_ready(Dev).

%% -- Message building --
build_message(Dev, Cmd, Payload, Key) ->
    Buf = binary:copy(<<0>>, 1024),
    case seatuya_nif:build_message(Dev, Buf, Cmd, Payload, Key) of
        {ok, Buf2, Sz} when Sz > 0, Sz =< byte_size(Buf2) ->
            <<Result:Sz/binary, _/binary>> = Buf2,
            {ok, Result};
        Err ->
            err_to_bin(Err)
    end.

decode_message(Dev, Bin, Key) ->
    ok_str_to_bin(seatuya_nif:decode_message(Dev, Bin, Key)).

generate_payload(Dev, Cmd, DevId, Dps) ->
    ok_str_to_bin(seatuya_nif:generate_payload(Dev, Cmd, DevId, Dps)).

%% -- Raw send/receive --
send(Dev, Bin) ->
    case seatuya_nif:send(Dev, Bin) of
        {ok, N} -> {ok, N};
        Err     -> err_to_bin(Err)
    end.

receive(Dev, Max, Min) ->
    case seatuya_nif:receive(Dev, Max, Min) of
        {ok, _} = Ok -> Ok;
        Err          -> err_to_bin(Err)
    end.

%% -- device22 --
set_device22(Dev, Json) ->
    seatuya_nif:set_device22(Dev, Json),
    nil.

is_device22(Dev) ->
    seatuya_nif:is_device22(Dev).

%% -- High-level round-trip --
set_value_bool(Dev, Dp, Val) ->
    ok_str_to_bin(seatuya_nif:set_value_bool(Dev, Dp, Val)).

set_value_int(Dev, Dp, Val) ->
    ok_str_to_bin(seatuya_nif:set_value_int(Dev, Dp, Val)).

set_value_string(Dev, Dp, Val) ->
    ok_str_to_bin(seatuya_nif:set_value_string(Dev, Dp, Val)).

set_value_float(Dev, Dp, Val) ->
    ok_str_to_bin(seatuya_nif:set_value_float(Dev, Dp, Val)).

turn_on(Dev, Dp) ->
    ok_str_to_bin(seatuya_nif:turn_on(Dev, Dp)).

turn_off(Dev, Dp) ->
    ok_str_to_bin(seatuya_nif:turn_off(Dev, Dp)).

status(Dev) ->
    ok_str_to_bin(seatuya_nif:status(Dev)).

heartbeat(Dev) ->
    ok_str_to_bin(seatuya_nif:heartbeat(Dev)).
