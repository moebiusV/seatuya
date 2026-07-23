// example.v -- demonstrate libseatuya via V C interop.
//
// Build: v -cflags '-L/usr/local/lib' -run example.v
// Environment variables (with fallback defaults):
//   TUYA_DEVICE_ID  (default: 0123456789abcdef01234567)
//   TUYA_LOCAL_KEY  (default: 0123456789abcdef)
//   TUYA_IP         (default: 192.168.1.100)
//   TUYA_VERSION    (default: 3.4)

module main

import os
import seatuya

fn main() {
	device_id := os.getenv('TUYA_DEVICE_ID')
	if device_id == '' {
		device_id = '0123456789abcdef01234567'
	}

	local_key := os.getenv('TUYA_LOCAL_KEY')
	if local_key == '' {
		local_key = '0123456789abcdef'
	}

	ip := os.getenv('TUYA_IP')
	if ip == '' {
		ip = '192.168.1.100'
	}

	ver := os.getenv('TUYA_VERSION')
	if ver == '' {
		ver = '3.4'
	}

	println('seatuya version: ${seatuya.version()}')

	dev := seatuya.create(device_id, ip, local_key, ver) or {
		eprintln('ERROR: Could not create device handle (check IP and credentials)')
		exit(1)
	}

	println('Connected: ${seatuya.is_connected(dev)}')

	r1 := seatuya.turn_on(dev, 1) or { 'error' }
	println('turn_on: ${r1}')

	r2 := seatuya.status(dev) or { 'error' }
	println('status: ${r2}')

	r3 := seatuya.turn_off(dev, 1) or { 'error' }
	println('turn_off: ${r3}')

	seatuya.destroy(dev)
	println('Done.')
}
