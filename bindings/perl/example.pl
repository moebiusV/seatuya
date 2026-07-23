#!/usr/bin/env perl
use strict; use warnings; use lib '.'; use Seatuya;

my $device_id = $ENV{TUYA_DEVICE_ID} // '0123456789abcdef01234567';
my $local_key = $ENV{TUYA_LOCAL_KEY} // '0123456789abcdef';
my $ip        = $ENV{TUYA_IP}        // '192.168.1.100';
my $ver       = $ENV{TUYA_VERSION}    // '3.4';

say "seatuya version: ", Seatuya::version();

my $dev = Seatuya::create($device_id, $ip, $local_key, $ver);
die "ERROR: Could not create device handle\n" unless $dev;

say "Connected: ", Seatuya::is_connected($dev) ? 'true' : 'false';
say "turn_on: ",  Seatuya::turn_on($dev, 1);
say "status: ",   Seatuya::status($dev);
say "turn_off: ", Seatuya::turn_off($dev, 1);

Seatuya::destroy($dev);
say "Done.";
