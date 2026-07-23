/**
 * example.d -- demonstrate seatuya D bindings
 *
 * Usage: dmd -ofexample example.d seatuya.d && ./example
 * Environment variables: DEVICE_ID, LOCAL_KEY, IP, VERSION
 */
import std.stdio;
import std.process : environment;
import seatuya;

void main()
{
    auto device_id = environment.get("DEVICE_ID", "0123456789abcdef");
    auto local_key = environment.get("LOCAL_KEY", "0123456789abcdef");
    auto ip        = environment.get("IP",        "192.168.1.100");
    auto version   = environment.get("VERSION",   "3.3");

    writeln("seatuya version: ", tuya_version());
    writeln("Device ID: ", device_id);
    writeln("IP: ", ip);
    writeln("Protocol: ", version);
    writeln();

    auto dev = tuya_create(device_id.toStringz(),
                           ip.toStringz(),
                           local_key.toStringz(),
                           version.toStringz());
    assert(dev !is null, "Failed to create device");

    writeln("Connected! Getting status...");

    auto status = tuya_status(dev);
    if (status !is null)
        writeln("Status: ", status);
    else
        writeln("No status response");

    writeln("Turning on DP 1...");
    auto result = tuya_turn_on(dev, 1);
    if (result !is null)
        writeln("Turn-on response: ", result);
    else
        writeln("Turn-on: no response");

    status = tuya_status(dev);
    if (status !is null)
        writeln("Status after on: ", status);
    else
        writeln("No status response");

    writeln("Turning off DP 1...");
    result = tuya_turn_off(dev, 1);
    if (result !is null)
        writeln("Turn-off response: ", result);
    else
        writeln("Turn-off: no response");

    writeln();
    writeln("Using type-aware dispatcher:");
    result = tuya_set_value(dev, 1, "bool", true);
    if (result !is null)
        writeln("set-value response: ", result);
    else
        writeln("set-value: no response");

    tuya_destroy(dev);
    writeln("Done.");
}
