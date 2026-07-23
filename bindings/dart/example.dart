#!/usr/bin/env dart
import 'dart:io';
import 'seatuya.dart';

void main() {
  final deviceId = Platform.environment['TUYA_DEVICE_ID'] ?? '0123456789abcdef01234567';
  final localKey = Platform.environment['TUYA_LOCAL_KEY'] ?? '0123456789abcdef';
  final ip       = Platform.environment['TUYA_IP']        ?? '192.168.1.100';
  final ver      = Platform.environment['TUYA_VERSION']    ?? '3.4';

  print('seatuya version: ${version()}');

  final dev = create(deviceId, ip, localKey, ver);
  if (dev == nullptr) {
    stderr.writeln('ERROR: Could not create device handle');
    exit(1);
  }

  print('Connected: ${isConnected(dev)}');
  print('turn_on: ${turnOn(dev, 1)}');
  print('status: ${status(dev)}');
  print('turn_off: ${turnOff(dev, 1)}');

  destroy(dev);
  print('Done.');
}
