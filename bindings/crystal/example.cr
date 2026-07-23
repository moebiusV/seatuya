# example.cr -- demonstrate seatuya Crystal bindings
#
# Usage: crystal build --link-flags "-lseatuya" example.cr && ./example
# Or set SEATUYA_LIB for custom path.

require "./seatuya"

Seatuya.load_library

device_id = ENV["DEVICE_ID"]? || "0123456789abcdef"
local_key = ENV["LOCAL_KEY"]? || "0123456789abcdef"
ip        = ENV["IP"]?        || "192.168.1.100"
version   = ENV["VERSION"]?   || "3.3"

puts "seatuya version: #{Seatuya.version}"
puts "Device ID: #{device_id}"
puts "IP: #{ip}"
puts "Protocol: #{version}"
puts

dev = Seatuya.create(device_id, ip, local_key, version)
raise "Failed to create device" if dev.null?

puts "Connected! Getting status..."

if status = Seatuya.status(dev)
  puts "Status: #{status}"
else
  puts "No status response"
end

puts "Turning on DP 1..."
if result = Seatuya.turn_on(dev, 1)
  puts "Turn-on response: #{result}"
else
  puts "Turn-on: no response"
end

if status = Seatuya.status(dev)
  puts "Status after on: #{status}"
else
  puts "No status response"
end

puts "Turning off DP 1..."
if result = Seatuya.turn_off(dev, 1)
  puts "Turn-off response: #{result}"
else
  puts "Turn-off: no response"
end

puts
puts "Using type-aware dispatcher:"
if result = Seatuya.set_value(dev, 1, :bool, true)
  puts "set-value response: #{result}"
else
  puts "set-value: no response"
end

Seatuya.destroy(dev)
puts "Done."
