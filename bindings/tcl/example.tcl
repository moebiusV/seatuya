#!/usr/bin/env tclsh
# example.tcl — demonstrate libseatuya via Tcl FFI
#
# Usage: tclsh example.tcl
# Uses environment variables for device configuration.

lappend auto_path .
package require seatuya

set device_id [expr {[info exists ::env(TUYA_DEVICE_ID)] ? $::env(TUYA_DEVICE_ID) : "0123456789abcdef01234567"}]
set local_key [expr {[info exists ::env(TUYA_LOCAL_KEY)] ? $::env(TUYA_LOCAL_KEY) : "0123456789abcdef"}]
set ip        [expr {[info exists ::env(TUYA_IP)]        ? $::env(TUYA_IP)        : "192.168.1.100"}]
set ver       [expr {[info exists ::env(TUYA_VERSION)]    ? $::env(TUYA_VERSION)   : "3.4"}]

puts "seatuya version: [seatuya version]"

set dev [seatuya create $device_id $ip $local_key $ver]
if {$dev eq ""} {
    puts stderr "ERROR: Could not create device handle (check IP and credentials)"
    exit 1
}

puts "Connected: [seatuya is-connected $dev]"

puts "turn_on: [seatuya turn-on $dev 1]"
puts "status: [seatuya status $dev]"
puts "turn_off: [seatuya turn-off $dev 1]"

seatuya destroy $dev
puts "Done."
