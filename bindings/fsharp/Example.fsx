#!/usr/bin/env dotnet fsi
(*
Example: create a Tuya device, turn DP 1 on, print status, turn off.

Run:
    dotnet fsi Example.fsx

Environment variables: DEVICE_ID, DEVICE_IP, LOCAL_KEY, VERSION
*)

#r "Seatuya.dll"

open System
open Seatuya.Seatuya

let env name fallback =
    match Environment.GetEnvironmentVariable name with
    | null -> fallback
    | v    -> v

let devId = env "DEVICE_ID" "0123456789abcdef0123"
let addr  = env "DEVICE_IP" "192.168.1.100"
let key   = env "LOCAL_KEY" "0123456789abcdef"
let ver   = env "VERSION"   "3.3"

printfn "seatuya version: %s" (version ())

match create devId addr key ver with
| Some dev ->
    printfn "Device created"

    let onResp = turnOn dev 1
    printfn "Turn ON response: %s" onResp

    let st = status dev
    printfn "Device status: %s" st

    let offResp = turnOff dev 1
    printfn "Turn OFF response: %s" offResp

    destroy dev
    printfn "Device destroyed"

| None ->
    eprintfn "Create failed"
    1
