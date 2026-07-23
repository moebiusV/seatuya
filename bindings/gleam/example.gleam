////
//// example.gleam -- Demonstrate libseatuya via Gleam FFI
////
//// Run:
////   gleam run   (in a Gleam project with seatuya.gleam in src/)
////
//// Set env vars TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP, TUYA_VERSION
//// or the fallback placeholders will be used.
////
import gleam/io
import gleam/erlang/os
import gleam/result
import seatuya.{TuyaDevice, create, turn_on, status, turn_off, destroy, version}

pub fn main() {
  let device_id = os.get_env("TUYA_DEVICE_ID")
    |> result.unwrap("0123456789abcdef01234567")

  let local_key = os.get_env("TUYA_LOCAL_KEY")
    |> result.unwrap("0123456789abcdef")

  let ip = os.get_env("TUYA_IP") |> result.unwrap("192.168.1.100")

  let ver = os.get_env("TUYA_VERSION") |> result.unwrap("3.3")

  io.println("seatuya version: " <> version())

  case create(device_id, ip, local_key, ver) {
    Ok(dev) -> {
      io.println("Device created, turning on DP 1...")

      case turn_on(dev, 1) {
        Ok(resp) -> io.println("Turn ON response: " <> resp)
        Error(e) -> io.println("Turn ON failed: " <> e)
      }

      case status(dev) {
        Ok(s) -> io.println("Device status: " <> s)
        Error(e) -> io.println("Status query failed: " <> e)
      }

      case turn_off(dev, 1) {
        Ok(resp) -> io.println("Turn OFF response: " <> resp)
        Error(e) -> io.println("Turn OFF failed: " <> e)
      }

      destroy(dev)
      io.println("Device destroyed.")
    }
    Error(e) -> io.println("Create failed: " <> e)
  }
}
