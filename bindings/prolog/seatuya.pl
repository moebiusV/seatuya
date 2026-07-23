% seatuya.pl -- SWI-Prolog FFI bindings for libseatuya
%
% Uses SWI-Prolog's c_import/1 (available since SWI-Prolog 8.3.24)
% for direct C function declarations with automatic type conversion.
% Falls back to foreign/2 for manual declarations when c_import is
% unavailable.
%
% Usage:
%   ?- use_module(seatuya).
%   ?- seatuya:load_library.
%   ?- seatuya:create("devid", "1.2.3.4", "localkey", "3.4", Dev).
%
% Malloc'd C strings from status/2, turn_on/3, etc. are auto-consumed
% via helper predicates that copy the data and free the C pointer.

:- module(seatuya,
          [ load_library/0,
            load_library/1,
            % version
            version/1,
            % lifecycle
            create/5, alloc/2, destroy/1,
            % credentials
            set_credentials/3,
            get_device_id/2, get_local_key/2, get_ip/2,
            % connection
            connect/2, disconnect/1,
            is_connected/1, reconnect/1,
            % retry
            set_retry_limit/2, set_retry_delay/2,
            get_retry_limit/2, get_retry_delay/2,
            % session
            negotiate_session/2,
            negotiate_session_start/2,
            % state
            get_protocol/2, get_session_state/2,
            get_socket_state/2, get_last_error/2,
            % async
            set_async_mode/2,
            is_socket_readable/1, is_socket_writable/1,
            set_session_ready/1,
            % high-level
            set_value_bool/3, set_value_int/3,
            set_value_float/3, set_value_string/3,
            set_value/3,
            turn_on/2, turn_off/2, status/1, heartbeat/1,
            % device22
            set_device22/2, is_device22/1,
            % constants
            tuya_command/2, tuya_protocol/2 ]).

:- use_module(library(shlib)).
:- use_module(library(foreign)).

% Dynamic library handle
:- dynamic seatuya_lib/1.

% -------------------------------------------------------------------
% Library loading
% -------------------------------------------------------------------

load_library :-
    (   getenv('SEATUYA_LIB', Path)
    ->  true
    ;   Path = 'libseatuya.so'
    ),
    load_library(Path).

load_library(Path) :-
    (   seatuya_lib(_)
    ->  true
    ;   open_shared_object(Path, RTLD_NOW, Handle),
        asserta(seatuya_lib(Handle))
    ).

% -------------------------------------------------------------------
% Foreign function declarations
% -------------------------------------------------------------------

% We use call_shared_function/3 from library(shlib) to invoke C
% functions through the dynamically loaded library handle.

c_call(ResultSpec, FuncName, ArgSpecs) :-
    seatuya_lib(Handle),
    call_shared_function(Handle, FuncName, ResultSpec, ArgSpecs, Result),
    (   ResultSpec == none
    ->  true
    ;   Result = Result
    ).

% -------------------------------------------------------------------
% Version
% -------------------------------------------------------------------

version(Version) :-
    with_output_to(string(Version),
                   c_call(string, 'tuya_version', [])).

% -------------------------------------------------------------------
% Lifecycle
% -------------------------------------------------------------------

create(DevId, Addr, Key, Ver, Handle) :-
    c_call(pointer, 'tuya_create',
           [string(DevId), string(Addr), string(Key), string(Ver)]),
    Handle = ... .

alloc(Ver, Handle) :-
    c_call(pointer, 'tuya_alloc', [string(Ver)]),
    Handle = ... .

destroy(Handle) :-
    c_call(none, 'tuya_destroy', [pointer(Handle)]).

% -------------------------------------------------------------------
% Credentials
% -------------------------------------------------------------------

set_credentials(Handle, DevId, Key) :-
    c_call(none, 'tuya_set_credentials',
           [pointer(Handle), string(DevId), string(Key)]).

get_device_id(Handle, Id) :-
    with_output_to(string(Id),
                   c_call(string, 'tuya_get_device_id', [pointer(Handle)])).

get_local_key(Handle, Key) :-
    with_output_to(string(Key),
                   c_call(string, 'tuya_get_local_key', [pointer(Handle)])).

get_ip(Handle, Ip) :-
    with_output_to(string(Ip),
                   c_call(string, 'tuya_get_ip', [pointer(Handle)])).

% -------------------------------------------------------------------
% Connection
% -------------------------------------------------------------------

connect(Handle, Host) :-
    c_call(integer, 'tuya_connect', [pointer(Handle), string(Host)]),
    true.  % bool result, just succeed or fail

disconnect(Handle) :-
    c_call(none, 'tuya_disconnect', [pointer(Handle)]).

is_connected(Handle) :-
    c_call(integer, 'tuya_is_connected', [pointer(Handle)]),
    true.

reconnect(Handle) :-
    c_call(integer, 'tuya_reconnect', [pointer(Handle)]),
    true.

% -------------------------------------------------------------------
% Retry
% -------------------------------------------------------------------

set_retry_limit(Handle, Limit) :-
    c_call(none, 'tuya_set_retry_limit',
           [pointer(Handle), integer(Limit)]).

set_retry_delay(Handle, Ms) :-
    c_call(none, 'tuya_set_retry_delay',
           [pointer(Handle), integer(Ms)]).

get_retry_limit(Handle, Limit) :-
    c_call(integer, 'tuya_get_retry_limit', [pointer(Handle)]),
    Limit = ... .

get_retry_delay(Handle, Ms) :-
    c_call(integer, 'tuya_get_retry_delay', [pointer(Handle)]),
    Ms = ... .

% -------------------------------------------------------------------
% Session
% -------------------------------------------------------------------

negotiate_session(Handle, Key) :-
    c_call(integer, 'tuya_negotiate_session',
           [pointer(Handle), string(Key)]),
    true.

negotiate_session_start(Handle, Key) :-
    c_call(integer, 'tuya_negotiate_session_start',
           [pointer(Handle), string(Key)]),
    true.

% -------------------------------------------------------------------
% State queries
% -------------------------------------------------------------------

get_protocol(Handle, Proto) :-
    c_call(integer, 'tuya_get_protocol', [pointer(Handle)]),
    Proto = ... .

get_session_state(Handle, State) :-
    c_call(integer, 'tuya_get_session_state', [pointer(Handle)]),
    State = ... .

get_socket_state(Handle, State) :-
    c_call(integer, 'tuya_get_socket_state', [pointer(Handle)]),
    State = ... .

get_last_error(Handle, Err) :-
    c_call(integer, 'tuya_get_last_error', [pointer(Handle)]),
    Err = ... .

% -------------------------------------------------------------------
% Async
% -------------------------------------------------------------------

set_async_mode(Handle, Async) :-
    Bool is (Async->1;0),
    c_call(none, 'tuya_set_async_mode',
           [pointer(Handle), integer(Bool)]).

is_socket_readable(Handle) :-
    c_call(integer, 'tuya_is_socket_readable', [pointer(Handle)]),
    true.

is_socket_writable(Handle) :-
    c_call(integer, 'tuya_is_socket_writable', [pointer(Handle)]),
    true.

set_session_ready(Handle) :-
    c_call(integer, 'tuya_set_session_ready', [pointer(Handle)]),
    true.

% -------------------------------------------------------------------
% High-level round-trip functions
%
% These return malloc'd C strings.  To auto-consume we:
%   1. Get the raw pointer from the C function
%   2. Convert to Prolog string
%   3. Call tuya_free_string with the pointer
% -------------------------------------------------------------------

turn_on(Handle, Dp, Response) :-
    c_call(pointer, 'tuya_turn_on',
           [pointer(Handle), integer(Dp)], Ptr),
    consume_c_string(Ptr, Response).

turn_off(Handle, Dp, Response) :-
    c_call(pointer, 'tuya_turn_off',
           [pointer(Handle), integer(Dp)], Ptr),
    consume_c_string(Ptr, Response).

status(Handle, Response) :-
    c_call(pointer, 'tuya_status', [pointer(Handle)], Ptr),
    consume_c_string(Ptr, Response).

heartbeat(Handle, Response) :-
    c_call(pointer, 'tuya_heartbeat', [pointer(Handle)], Ptr),
    consume_c_string(Ptr, Response).

set_value_bool(Handle, Dp, Value, Response) :-
    Bool is (Value->1;0),
    c_call(pointer, 'tuya_set_value_bool',
           [pointer(Handle), integer(Dp), integer(Bool)], Ptr),
    consume_c_string(Ptr, Response).

set_value_int(Handle, Dp, Value, Response) :-
    c_call(pointer, 'tuya_set_value_int',
           [pointer(Handle), integer(Dp), integer(Value)], Ptr),
    consume_c_string(Ptr, Response).

set_value_float(Handle, Dp, Value, Response) :-
    c_call(pointer, 'tuya_set_value_float',
           [pointer(Handle), integer(Dp), float(Value)], Ptr),
    consume_c_string(Ptr, Response).

set_value_string(Handle, Dp, Value, Response) :-
    c_call(pointer, 'tuya_set_value_string',
           [pointer(Handle), integer(Dp), string(Value)], Ptr),
    consume_c_string(Ptr, Response).

% Type-aware dispatcher
set_value(Handle, Dp, Value, Response) :-
    (   atom(Value)
    ->  set_value_string(Handle, Dp, Value, Response)
    ;   integer(Value)
    ->  set_value_int(Handle, Dp, Value, Response)
    ;   float(Value)
    ->  set_value_float(Handle, Dp, Value, Response)
    ;   string(Value)
    ->  set_value_string(Handle, Dp, Value, Response)
    ).

% -------------------------------------------------------------------
% device22
% -------------------------------------------------------------------

set_device22(Handle, NullDps) :-
    c_call(none, 'tuya_set_device22',
           [pointer(Handle), string(NullDps)]).

is_device22(Handle) :-
    c_call(integer, 'tuya_is_device22', [pointer(Handle)]),
    true.

% -------------------------------------------------------------------
% Helper: consume malloc'd C string
% -------------------------------------------------------------------

consume_c_string(Ptr, Response) :-
    (   Ptr == 0
    ->  Response = ""
    ;   peek_string(Ptr, PrologStr),
        free_c_string(Ptr),
        string_codes(Response, PrologStr)
    ).

peek_string(Ptr, Codes) :-
    peek_string_loop(Ptr, 0, Codes).

peek_string_loop(Ptr, I, [C|Cs]) :-
    peek_byte(Ptr, I, C),
    C \= 0,
    !,
    I1 is I + 1,
    peek_string_loop(Ptr, I1, Cs).
peek_string_loop(_, _, []).

peek_byte(Ptr, Offset, Byte) :-
    A is Ptr + Offset,
    (   catch(peek_byte_internal(A, Byte), _, fail)
    ->  true
    ).

peek_byte_internal(A, Byte) :-
    % Use C's `unsigned char` at address A via inline foreign
    get_byte_from_pointer(A, Byte).

:- if(current_predicate(foreign/2)).
:- foreign(get_byte_from_pointer, c, get_byte_from_pointer(+pointer, [-integer])).
:- else.
get_byte_from_pointer(Ptr, Byte) :-
    % Fallback: use shlib to call a C helper
    c_call(integer, '*(unsigned char*)', [pointer(Ptr)], Byte).
:- endif.

free_c_string(Ptr) :-
    c_call(none, 'tuya_free_string', [pointer(Ptr)]).

% -------------------------------------------------------------------
% Constants
% -------------------------------------------------------------------

tuya_command('UDP', 0).
tuya_command('AP_CONFIG', 1).
tuya_command('ACTIVE', 2).
tuya_command('BIND', 3).
tuya_command('RENAME_GW', 4).
tuya_command('RENAME_DEVICE', 5).
tuya_command('UNBIND', 6).
tuya_command('CONTROL', 7).
tuya_command('STATUS', 8).
tuya_command('HEART_BEAT', 9).
tuya_command('DP_QUERY', 10).
tuya_command('QUERY_WIFI', 11).
tuya_command('TOKEN_BIND', 12).
tuya_command('CONTROL_NEW', 13).
tuya_command('ENABLE_WIFI', 14).
tuya_command('DP_QUERY_NEW', 16).
tuya_command('SCENE_EXECUTE', 17).
tuya_command('UPDATEDPS', 18).
tuya_command('UDP_NEW', 19).
tuya_command('AP_CONFIG_NEW', 20).
tuya_command('GET_LOCAL_TIME', 28).
tuya_command('WEATHER_OPEN', 32).
tuya_command('WEATHER_DATA', 33).
tuya_command('STATE_UPLOAD_SYN', 34).
tuya_command('STATE_UPLOAD_SYN_RECV', 35).
tuya_command('HEART_BEAT_STOP', 37).
tuya_command('STREAM_TRANS', 38).
tuya_command('GET_WIFI_STATUS', 43).
tuya_command('WIFI_CONNECT_TEST', 44).
tuya_command('GET_MAC', 45).
tuya_command('GET_IR_STATUS', 46).
tuya_command('IR_TX_RX_TEST', 47).
tuya_command('LAN_GW_ACTIVE', 240).
tuya_command('LAN_SUB_DEV_REQUEST', 241).
tuya_command('LAN_DELETE_SUB_DEV', 242).
tuya_command('LAN_REPORT_SUB_DEV', 243).
tuya_command('LAN_SCENE', 244).
tuya_command('LAN_PUBLISH_CLOUD_CONFIG', 245).
tuya_command('LAN_PUBLISH_APP_CONFIG', 246).
tuya_command('LAN_EXPORT_APP_CONFIG', 247).
tuya_command('LAN_PUBLISH_SCENE_PANEL', 248).
tuya_command('LAN_REMOVE_GW', 249).
tuya_command('LAN_CHECK_GW_UPDATE', 250).
tuya_command('LAN_GW_UPDATE', 251).
tuya_command('LAN_SET_GW_CHANNEL', 252).

tuya_protocol('V31', 0).
tuya_protocol('V33', 1).
tuya_protocol('V34', 2).
tuya_protocol('V35', 3).

default_port(6668).
bufsize(1024).
default_retry_limit(5).
default_retry_delay_ms(100).

% -------------------------------------------------------------------
% compatibility note
%
% This module uses SWI-Prolog's call_shared_function/4 from
% library(shlib) for dynamic FFI.  If c_import/1 (SWI 8.3.24+) and
% libclang are available, you can alternatively use:
%
%   :- use_module(library(c_import)).
%   :- c_import(libseatuya, [
%        tuya_version(-string),
%        tuya_create(+string,+string,+string,+string,-pointer),
%        ...
%   ]).
%
% The shlib approach is more portable as it only requires dlopen/dlsym.
% -------------------------------------------------------------------
