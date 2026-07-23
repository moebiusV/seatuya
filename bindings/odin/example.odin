// example.odin -- demonstrate libseatuya via Odin FFI
//
// Build: odin build .
// Run:   ./example

package main

import "core:fmt"
import "core:os"
import s "seatuya"

main :: proc() {
    device_id := os.get_env("TUYA_DEVICE_ID") or_else "0123456789abcdef01234567"
    local_key := os.get_env("TUYA_LOCAL_KEY") or_else "0123456789abcdef"
    ip        := os.get_env("TUYA_IP")        or_else "192.168.1.100"
    ver       := os.get_env("TUYA_VERSION")   or_else "3.4"

    lib, ok := s.load()
    if !ok {
        fmt.eprintln("ERROR: Could not load libseatuya")
        os.exit(1)
    }

    // Print library version
    fmt.println("seatuya version:", string(lib.tuya_version()))

    // Allocate device handle
    dev := lib.tuya_alloc(ver)
    if dev == nil {
        fmt.eprintln("ERROR: Could not create device handle (invalid version?)")
        os.exit(1)
    }
    defer lib.tuya_destroy(dev)

    lib.tuya_set_credentials(dev, device_id, local_key)
    lib.tuya_connect(dev, ip)

    fmt.println("Connected:", s.to_bool(lib.tuya_is_connected(dev)))
    fmt.println("turn_on:", s.consume(lib, lib.tuya_turn_on(dev, 1)))
    fmt.println("status:", s.consume(lib, lib.tuya_status(dev)))
    fmt.println("turn_off:", s.consume(lib, lib.tuya_turn_off(dev, 1)))

    // Demonstrates type-aware dispatcher
    _ = s.set_value(lib, dev, 1, true)   // bool
    _ = s.set_value(lib, dev, 2, 25)     // int
    _ = s.set_value(lib, dev, 3, "hello") // string
    _ = s.set_value(lib, dev, 4, 23.5)   // float

    fmt.println("Done.")
}
