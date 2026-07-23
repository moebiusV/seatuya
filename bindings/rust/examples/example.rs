// example.rs — demonstrate libseatuya via Rust FFI
//
// Usage: cargo run --example example

use seatuya::Device;
use std::env;

fn main() {
    let device_id = env::var("TUYA_DEVICE_ID").unwrap_or_else(|_| "0123456789abcdef01234567".into());
    let local_key = env::var("TUYA_LOCAL_KEY").unwrap_or_else(|_| "0123456789abcdef".into());
    let ip        = env::var("TUYA_IP").unwrap_or_else(|_| "192.168.1.100".into());
    let ver       = env::var("TUYA_VERSION").unwrap_or_else(|_| "3.4".into());

    println!("seatuya version: {}", Device::version());

    let dev = Device::create(&device_id, &ip, &local_key, &ver)
        .expect("ERROR: Could not create device handle");

    println!("Connected: {}", dev.is_connected());
    println!("turn_on: {:?}", dev.turn_on(1));
    println!("status: {:?}", dev.status());
    println!("turn_off: {:?}", dev.turn_off(1));
    println!("Done.");
}
