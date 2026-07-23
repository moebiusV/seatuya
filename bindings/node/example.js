#!/usr/bin/env node
/**
 * example.js — demonstrate libseatuya via Node.js FFI
 *
 * Usage: SEATUYA_LIB=../src/.libs/libseatuya.so node example.js
 *
 * Connects to a Tuya device, turns on DP 1, queries status,
 * turns off DP 1, and disconnects.
 */

'use strict';

const seatuya = require('./seatuya.js');

const DEVICE_ID  = process.env.TUYA_DEVICE_ID  || '0123456789abcdef01234567';
const LOCAL_KEY  = process.env.TUYA_LOCAL_KEY  || '0123456789abcdef';
const IP         = process.env.TUYA_IP         || '192.168.1.100';
const VERSION    = process.env.TUYA_VERSION    || '3.4';

console.log('seatuya version:', seatuya.version());

const dev = seatuya.create(DEVICE_ID, IP, LOCAL_KEY, VERSION);
if (!dev) {
  console.error('Failed to create device handle (check device IP and credentials)');
  process.exit(1);
}

console.log('Connected:', seatuya.isConnected(dev));
console.log('Protocol:', seatuya.getProtocol(dev));

// Turn on switch (data point 1)
let resp = seatuya.turnOn(dev, 1);
console.log('turn_on response:', resp);

// Query all data points
resp = seatuya.status(dev);
console.log('status response:', resp);

// Turn off switch
resp = seatuya.turnOff(dev, 1);
console.log('turn_off response:', resp);

seatuya.destroy(dev);
console.log('Done.');
