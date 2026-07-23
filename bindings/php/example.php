#!/usr/bin/env php
<?php

require_once __DIR__ . '/Seatuya.php';

$deviceId = getenv('TUYA_DEVICE_ID') ?: '0123456789abcdef01234567';
$localKey = getenv('TUYA_LOCAL_KEY') ?: '0123456789abcdef';
$ip       = getenv('TUYA_IP')        ?: '192.168.1.100';
$ver      = getenv('TUYA_VERSION')    ?: '3.4';

echo "seatuya version: ", Seatuya::version(), "\n";

$dev = Seatuya::create($deviceId, $ip, $localKey, $ver);
if ($dev === null) {
    fwrite(STDERR, "ERROR: Could not create device handle\n");
    exit(1);
}

echo "Connected: ", Seatuya::isConnected($dev) ? 'yes' : 'no', "\n";
echo "turn_on: ", Seatuya::turnOn($dev, 1), "\n";
echo "status: ", Seatuya::status($dev), "\n";
echo "turn_off: ", Seatuya::turnOff($dev, 1), "\n";

Seatuya::destroy($dev);
echo "Done.\n";
