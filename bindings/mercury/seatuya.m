% seatuya.m — Mercury FFI bindings for libseatuya
%
% Mercury is a logic/functional language that compiles to C.  FFI is
% via `:- pragma foreign_proc` with C code inline.  The opaque
% tuya_device_t* is represented as a Mercury c_pointer.
%
% Usage:
%   main(!IO) :-
%     seatuya.create("id", "192.168.1.100", "key", "3.4", Dev, !IO),
%     seatuya.turn_on(Dev, 1, Json, !IO),
%     io.write_string(Json, !IO),
%     seatuya.destroy(Dev, !IO).

:- module seatuya.
:- interface.
:- import_module io.

:- type device.
:- pragma foreign_type("C", device, "tuya_device_t*",
    [can_pass_as_mercury_type, stable]).

:- pred version(string::out, io::di, io::uo) is det.
:- pred create(string::in, string::in, string::in, string::in,
    device::out, io::di, io::uo) is det.
:- pred destroy(device::in, io::di, io::uo) is det.
:- pred connect(device::in, string::in, int::out, io::di, io::uo) is det.
:- pred disconnect(device::in, io::di, io::uo) is det.
:- pred is_connected(device::in, int::out, io::di, io::uo) is det.
:- pred reconnect(device::in, int::out, io::di, io::uo) is det.
:- pred set_credentials(device::in, string::in, string::in,
    io::di, io::uo) is det.
:- pred get_device_id(device::in, string::out, io::di, io::uo) is det.
:- pred get_local_key(device::in, string::out, io::di, io::uo) is det.
:- pred get_ip(device::in, string::out, io::di, io::uo) is det.
:- pred turn_on(device::in, int::in, string::out, io::di, io::uo) is det.
:- pred turn_off(device::in, int::in, string::out, io::di, io::uo) is det.
:- pred status(device::in, string::out, io::di, io::uo) is det.
:- pred heartbeat(device::in, string::out, io::di, io::uo) is det.
:- pred set_value_bool(device::in, int::in, int::in, string::out,
    io::di, io::uo) is det.
:- pred set_value_int(device::in, int::in, int::in, string::out,
    io::di, io::uo) is det.
:- pred set_value_string(device::in, int::in, string::in, string::out,
    io::di, io::uo) is det.
:- pred set_value_float(device::in, int::in, float::in, string::out,
    io::di, io::uo) is det.
:- pred set_device22(device::in, string::in, io::di, io::uo) is det.
:- pred is_device22(device::in, int::out, io::di, io::uo) is det.
:- pred get_protocol(device::in, int::out, io::di, io::uo) is det.
:- pred get_last_error(device::in, int::out, io::di, io::uo) is det.
:- pred set_async_mode(device::in, int::in, io::di, io::uo) is det.
:- pred negotiate_session(device::in, string::in, int::out,
    io::di, io::uo) is det.

:- func cmd_control = int. cmd_control = 7.
:- func cmd_dp_query = int. cmd_dp_query = 10.
:- func cmd_heart_beat = int. cmd_heart_beat = 9.
:- func cmd_status = int. cmd_status = 8.
:- func cmd_control_new = int. cmd_control_new = 13.
:- func cmd_dp_query_new = int. cmd_dp_query_new = 16.
:- func default_port = int. default_port = 6668.
:- func buf_size = int. buf_size = 1024.

:- implementation.
:- import_module string.

:- pragma foreign_decl("C", "#include <seatuya/seatuya.h>").

version(V, !IO) :-
    pragma foreign_proc("C",
        V::out, [will_not_call_mercury, promise_pure, thread_safe], "
        V = (MR_String) tuya_version();
    ").

create(Did, Addr, Key, Ver, Dev, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe],
        Did::in, Addr::in, Key::in, Ver::in, Dev::out, "
        Dev = tuya_create(Did, Addr, Key, Ver);
    ").

destroy(Dev, !IO) :-
    pragma foreign_proc("C",
        [will_not_call_mercury, promise_pure, thread_safe], Dev::in, "
        tuya_destroy(Dev);
    ").

connect(Dev, Host, Ok, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Host::in, Ok::out, "
        Ok = tuya_connect(Dev, Host);
    ").

disconnect(Dev, !IO) :-
    pragma foreign_proc("C",
        [will_not_call_mercury, promise_pure, thread_safe], Dev::in, "
        tuya_disconnect(Dev);
    ").

is_connected(Dev, Ok, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Ok::out, "
        Ok = tuya_is_connected(Dev);
    ").

reconnect(Dev, Ok, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Ok::out, "
        Ok = tuya_reconnect(Dev);
    ").

set_credentials(Dev, Did, Key, !IO) :-
    pragma foreign_proc("C",
        [will_not_call_mercury, promise_pure, thread_safe],
        Dev::in, Did::in, Key::in, "
        tuya_set_credentials(Dev, Did, Key);
    ").

get_device_id(Dev, S, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, S::out, "
        S = (MR_String) tuya_get_device_id(Dev);
    ").

get_local_key(Dev, S, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, S::out, "
        S = (MR_String) tuya_get_local_key(Dev);
    ").

get_ip(Dev, S, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, S::out, "
        S = (MR_String) tuya_get_ip(Dev);
    ").

turn_on(Dev, Dp, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Dp::in, Json::out, "
        Json = (MR_String) tuya_turn_on(Dev, Dp);
    ").

turn_off(Dev, Dp, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Dp::in, Json::out, "
        Json = (MR_String) tuya_turn_off(Dev, Dp);
    ").

status(Dev, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Json::out, "
        Json = (MR_String) tuya_status(Dev);
    ").

heartbeat(Dev, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Json::out, "
        Json = (MR_String) tuya_heartbeat(Dev);
    ").

set_value_bool(Dev, Dp, Val, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Dp::in, Val::in, Json::out, "
        Json = (MR_String) tuya_set_value_bool(Dev, Dp, Val);
    ").

set_value_int(Dev, Dp, Val, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Dp::in, Val::in, Json::out, "
        Json = (MR_String) tuya_set_value_int(Dev, Dp, Val);
    ").

set_value_string(Dev, Dp, Val, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Dp::in, Val::in, Json::out, "
        Json = (MR_String) tuya_set_value_string(Dev, Dp, Val);
    ").

set_value_float(Dev, Dp, Val, Json, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Dp::in, Val::in, Json::out, "
        Json = (MR_String) tuya_set_value_float(Dev, Dp, Val);
    ").

set_device22(Dev, Json, !IO) :-
    pragma foreign_proc("C",
        [will_not_call_mercury, promise_pure, thread_safe],
        Dev::in, Json::in, "
        tuya_set_device22(Dev, Json);
    ").

is_device22(Dev, Ok, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Ok::out, "
        Ok = tuya_is_device22(Dev);
    ").

get_protocol(Dev, P, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, P::out, "
        P = tuya_get_protocol(Dev);
    ").

get_last_error(Dev, E, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, E::out, "
        E = tuya_get_last_error(Dev);
    ").

set_async_mode(Dev, Flag, !IO) :-
    pragma foreign_proc("C",
        [will_not_call_mercury, promise_pure, thread_safe],
        Dev::in, Flag::in, "
        tuya_set_async_mode(Dev, Flag);
    ").

negotiate_session(Dev, Key, Ok, !IO) :-
    pragma foreign_proc("C",
        [promise_pure, thread_safe], Dev::in, Key::in, Ok::out, "
        Ok = tuya_negotiate_session(Dev, Key);
    ").
