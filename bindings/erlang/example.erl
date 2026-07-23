%%%-------------------------------------------------------------------
%%% @doc Example: create a Tuya device, turn DP 1 on, print status,
%%% turn DP 1 off, clean up.
%%%
%%% Run:
%%%   erlc -o . example.erl
%%%   erl -pa . -noshell -run example main -run init stop
%%% @end
%%%-------------------------------------------------------------------
-module(example).
-export([main/0]).

main() ->
    %% Read config from environment or use placeholders
    DevId  = env("DEVICE_ID",  "0123456789abcdef0123"),
    Addr   = env("DEVICE_IP",  "192.168.1.100"),
    Key    = env("LOCAL_KEY",  "0123456789abcdef"),
    Ver    = env("VERSION",    "3.3"),

    io:format("seatuya version: ~s~n", [seatuya:version()]),

    case seatuya:create(DevId, Addr, Key, Ver) of
        {ok, Dev} ->
            io:format("Device created~n"),

            %% Turn on DP 1
            case seatuya:turn_on(Dev, 1) of
                {ok, Resp} ->
                    io:format("Turn ON response: ~s~n", [Resp]);
                {error, Reason} ->
                    io:format("Turn ON failed: ~p~n", [Reason])
            end,

            %% Query status
            case seatuya:status(Dev) of
                {ok, Status} ->
                    io:format("Device status: ~s~n", [Status]);
                {error, Reason} ->
                    io:format("Status query failed: ~p~n", [Reason])
            end,

            %% Turn off DP 1
            case seatuya:turn_off(Dev, 1) of
                {ok, Resp} ->
                    io:format("Turn OFF response: ~s~n", [Resp]);
                {error, Reason} ->
                    io:format("Turn OFF failed: ~p~n", [Reason])
            end,

            %% Cleanup
            seatuya:destroy(Dev),
            io:format("Device destroyed~n");

        {error, Reason} ->
            io:format("Create failed: ~p~n", [Reason])
    end.

env(Name, Default) ->
    case os:getenv(Name) of
        false -> Default;
        Val   -> Val
    end.
