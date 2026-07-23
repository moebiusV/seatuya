:- module example.
:- interface.
:- import_module io.
:- pred main(io::di, io::uo) is det.
:- implementation.
:- import_module seatuya, string.

main(!IO) :-
    Did = get_env("TUYA_DEVICE_ID", "0123456789abcdef01234567"),
    Key = get_env("TUYA_LOCAL_KEY", "0123456789abcdef"),
    Ip  = get_env("TUYA_IP",        "192.168.1.100"),
    Ver = get_env("TUYA_VERSION",    "3.4"),

    version(V, !IO),
    io.format("seatuya version: %s\n", [s(V)], !IO),

    seatuya.create(Did, Ip, Key, Ver, Dev, !IO),
    ( if pointer.is_null(Dev) then
        io.write_string("ERROR: Could not create device handle\n", !IO)
    else
        is_connected(Dev, C, !IO),
        io.format("Connected: %d\n", [i(C)], !IO),
        turn_on(Dev, 1, J1, !IO),
        io.format("turn_on: %s\n", [s(J1)], !IO),
        status(Dev, J2, !IO),
        io.format("status: %s\n", [s(J2)], !IO),
        turn_off(Dev, 1, J3, !IO),
        io.format("turn_off: %s\n", [s(J3)], !IO),
        destroy(Dev, !IO),
        io.write_string("Done.\n", !IO)
    ).

:- func get_env(string, string) = string.
get_env(Name, Default) = S :-
    ( if io.get_environment_var(Name, S0) then S = S0 else S = Default ).
