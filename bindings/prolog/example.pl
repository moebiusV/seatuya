% example.pl -- Demonstrate libseatuya via SWI-Prolog FFI
%
% Usage:
%   swipl -l example.pl -t run
%
% Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP, TUYA_VERSION env vars.

:- use_module(seatuya).
:- use_module(library(shlib)).
:- use_module(library(prolog_stack)).

run :-
    seatuya:load_library,
    env_or('TUYA_DEVICE_ID', '0123456789abcdef01234567', DeviceId),
    env_or('TUYA_LOCAL_KEY', '0123456789abcdef', LocalKey),
    env_or('TUYA_IP',        '192.168.1.100', Ip),
    env_or('TUYA_VERSION',   '3.4', Ver),
    seatuya:version(Version),
    format('seatuya version: ~s~n', [Version]),
    (   seatuya:create(DeviceId, Ip, LocalKey, Ver, Dev)
    ->  format('Connected: ~w~n', [seatuya:is_connected(Dev)]),
        seatuya:turn_on(Dev, 1, OnResp),
        format('turn_on: ~s~n', [OnResp]),
        seatuya:status(Dev, Status),
        format('status: ~s~n', [Status]),
        seatuya:turn_off(Dev, 1, OffResp),
        format('turn_off: ~s~n', [OffResp]),
        seatuya:destroy(Dev),
        format('Done.~n')
    ;   format(user_error, 'ERROR: Could not create device~n', [])
    ).

env_or(Var, Default, Value) :-
    (   getenv(Var, Val)
    ->  Value = Val
    ;   Value = Default
    ).
