import seatuya.Seatuya

fun main() {
    val deviceId = System.getenv("TUYA_DEVICE_ID") ?: "0123456789abcdef01234567"
    val localKey = System.getenv("TUYA_LOCAL_KEY") ?: "0123456789abcdef"
    val ip       = System.getenv("TUYA_IP")        ?: "192.168.1.100"
    val ver      = System.getenv("TUYA_VERSION")    ?: "3.4"

    println("seatuya version: ${Seatuya.version()}")

    val dev = Seatuya.create(deviceId, ip, localKey, ver)
        ?: run { System.err.println("ERROR: Could not create device handle"); return }

    println("Connected: ${Seatuya.isConnected(dev)}")
    println("turn_on: ${Seatuya.turnOn(dev, 1)}")
    println("status: ${Seatuya.status(dev)}")
    println("turn_off: ${Seatuya.turnOff(dev, 1)}")

    Seatuya.destroy(dev)
    println("Done.")
}
