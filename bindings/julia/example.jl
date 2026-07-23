#!/usr/bin/env julia
# example.jl — demonstrate libseatuya via Julia ccall
#
# Usage: julia example.jl
# Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP env vars before running.

push!(LOAD_PATH, ".")
using Seatuya

device_id = get(ENV, "TUYA_DEVICE_ID", "0123456789abcdef01234567")
local_key = get(ENV, "TUYA_LOCAL_KEY", "0123456789abcdef")
ip        = get(ENV, "TUYA_IP",        "192.168.1.100")
ver       = get(ENV, "TUYA_VERSION",    "3.4")

println("seatuya version: ", Seatuya.version())

dev = Seatuya.create(device_id, ip, local_key, ver)
if dev === nothing
    println(stderr, "ERROR: Could not create device handle")
    exit(1)
end

println("Connected: ", Seatuya.is_connected(dev))
println("Protocol: ", Seatuya.get_protocol(dev))

println("turn_on: ", Seatuya.turn_on(dev, 1))
println("status: ", Seatuya.status(dev))
println("turn_off: ", Seatuya.turn_off(dev, 1))

Seatuya.destroy(dev)
println("Done.")
