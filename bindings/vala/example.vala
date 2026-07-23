// example.vala -- demonstrate libseatuya via Vala C FFI bindings
//
// Usage:
//   valac --pkg glib-2.0 \
//     -X -Wl,--unresolved-symbols=ignore-in-object-files \
//     -o example example.vala seatuya.vala
//   ./example

void main() {
  var deviceId = Environment.get_variable("TUYA_DEVICE_ID") ?? "0123456789abcdef01234567";
  var localKey = Environment.get_variable("TUYA_LOCAL_KEY") ?? "0123456789abcdef";
  var ip       = Environment.get_variable("TUYA_IP")        ?? "192.168.1.100";
  var ver      = Environment.get_variable("TUYA_VERSION")    ?? "3.4";

  print("seatuya version: %s\n", Seatuya.version());

  var dev = Seatuya.create(deviceId, ip, localKey, ver);
  if (dev == null) {
    stderr.printf("ERROR: Could not create device handle\n");
    return;
  }

  print("Connected: %s\n", Seatuya.is_connected(dev).to_string());
  print("turn_on: %s\n", Seatuya.turn_on(dev, 1));
  print("status: %s\n", Seatuya.status(dev));
  print("turn_off: %s\n", Seatuya.turn_off(dev, 1));

  // Type-aware dispatcher
  print("setValue(bool):   %s\n", Seatuya.set_value(dev, 1, true));
  print("setValue(int):    %s\n", Seatuya.set_value(dev, 2, 25));
  print("setValue(float):  %s\n", Seatuya.set_value(dev, 3, 23.5));
  print("setValue(string): %s\n", Seatuya.set_value(dev, 4, "hello"));

  Seatuya.destroy(dev);
  print("Done.\n");
}
