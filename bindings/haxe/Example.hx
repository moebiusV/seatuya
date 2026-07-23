// Example.hx -- demonstrate libseatuya via Haxe C++ FFI bindings
//
// Usage:
//   haxe -main Example -cpp build Example.hx Seatuya.hx
//   LD_LIBRARY_PATH=/usr/local/lib ./build/Example

package seatuya;

import seatuya.Seatuya;

class Example {
  static function main():Void {
    var deviceId = Sys.getEnv("TUYA_DEVICE_ID");
    if (deviceId == null) deviceId = "0123456789abcdef01234567";

    var localKey = Sys.getEnv("TUYA_LOCAL_KEY");
    if (localKey == null) localKey = "0123456789abcdef";

    var ip = Sys.getEnv("TUYA_IP");
    if (ip == null) ip = "192.168.1.100";

    var ver = Sys.getEnv("TUYA_VERSION");
    if (ver == null) ver = "3.4";

    Sys.println("seatuya version: " + Seatuya.version());

    var dev = Seatuya.create(deviceId, ip, localKey, ver);
    if (dev == null) {
      Sys.println("ERROR: Could not create device handle");
      Sys.exit(1);
    }

    Sys.println("Connected: " + Seatuya.isConnected(dev));
    Sys.println("turn_on: " + Seatuya.turnOn(dev, 1));
    Sys.println("status: " + Seatuya.status(dev));
    Sys.println("turn_off: " + Seatuya.turnOff(dev, 1));

    // Type-aware dispatcher
    Sys.println("setValue(bool):   " + Seatuya.setValue(dev, 1, true));
    Sys.println("setValue(int):    " + Seatuya.setValue(dev, 2, 25));
    Sys.println("setValue(float):  " + Seatuya.setValue(dev, 3, 23.5));
    Sys.println("setValue(string): " + Seatuya.setValue(dev, 4, "hello"));

    Seatuya.destroy(dev);
    Sys.println("Done.");
  }
}
