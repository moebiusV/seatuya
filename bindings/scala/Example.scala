// Example.scala -- demonstrate libseatuya via Scala/JVM JNA bindings
//
// Usage:
//   scalac -cp jna-5.14.0.jar Seatuya.scala Example.scala -d example.jar
//   scala -cp .:jna-5.14.0.jar:example.jar seatuya.Example

package seatuya

object Example {
  def main(args: Array[String]): Unit = {
    val deviceId = sys.env.getOrElse("TUYA_DEVICE_ID", "0123456789abcdef01234567")
    val localKey = sys.env.getOrElse("TUYA_LOCAL_KEY", "0123456789abcdef")
    val ip       = sys.env.getOrElse("TUYA_IP",        "192.168.1.100")
    val ver      = sys.env.getOrElse("TUYA_VERSION",    "3.4")

    println(s"seatuya version: ${Seatuya.version()}")

    val dev = Seatuya.create(deviceId, ip, localKey, ver)
    if (dev == null) {
      System.err.println("ERROR: Could not create device handle")
      sys.exit(1)
    }

    println(s"Connected: ${Seatuya.isConnected(dev)}")
    println(s"turn_on: ${Seatuya.turnOn(dev, 1)}")
    println(s"status: ${Seatuya.status(dev)}")
    println(s"turn_off: ${Seatuya.turnOff(dev, 1)}")

    // Type-aware dispatcher
    println(s"setValue(bool):   ${Seatuya.setValue(dev, 1, value = true)}")
    println(s"setValue(int):    ${Seatuya.setValue(dev, 2, value = 25)}")
    println(s"setValue(float):  ${Seatuya.setValue(dev, 3, value = 23.5)}")
    println(s"setValue(string): ${Seatuya.setValue(dev, 4, value = "hello")}")

    Seatuya.destroy(dev)
    println("Done.")
  }
}
