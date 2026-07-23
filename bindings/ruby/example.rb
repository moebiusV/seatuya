#!/usr/bin/env ruby
require_relative 'seatuya'

device_id = ENV['TUYA_DEVICE_ID'] || '0123456789abcdef01234567'
local_key = ENV['TUYA_LOCAL_KEY'] || '0123456789abcdef'
ip        = ENV['TUYA_IP']        || '192.168.1.100'
ver       = ENV['TUYA_VERSION']    || '3.4'

puts "seatuya version: #{Seatuya.version}"

dev = Seatuya.create(device_id, ip, local_key, ver)
abort "ERROR: Could not create device handle" unless dev

puts "Connected: #{Seatuya.is_connected(dev)}"
puts "turn_on: #{Seatuya.turn_on(dev, 1)}"
puts "status: #{Seatuya.status(dev)}"
puts "turn_off: #{Seatuya.turn_off(dev, 1)}"

Seatuya.destroy(dev)
puts "Done."
