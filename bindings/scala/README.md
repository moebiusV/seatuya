# Scala/JVM JNA Bindings for libseatuya

Pure Scala binding using [JNA (Java Native Access)](https://github.com/java-native-access/jna).
A single `Seatuya` object with typed functions wrapping the C API.

## Prerequisites

- Scala 2.13+ / JDK 11+
- JNA: `net.java.dev.jna:jna:5.14.0`
- libseatuya installed (`make install`)

## Build and run

```sh
scalac -cp jna-5.14.0.jar Seatuya.scala Example.scala -d example.jar
scala -cp .:jna-5.14.0.jar:example.jar seatuya.Example
```

Or with sbt:

```scala
libraryDependencies += "net.java.dev.jna" % "jna" % "5.14.0"
```

## Usage

```scala
import seatuya.Seatuya

val dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4")
println(Seatuya.turnOn(dev, 1))
println(Seatuya.status(dev))
Seatuya.destroy(dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  The `Seatuya` object exposes
every C function as a Scala function with camelCase naming.

### Library loading

`Seatuya` loads `libseatuya.so` (or `.dylib` on macOS, `.dll` on Windows) via
JNA.  Set the `SEATUYA_LIB` environment variable to override the library path.

### String management

Malloc'd C strings returned by `tuya_set_value_*`, `tuya_turn_on/off`,
`tuya_status`, `tuya_heartbeat`, `tuya_decode_message`, and
`tuya_generate_payload` are automatically copied to Scala strings and freed
via `tuya_free_string`.  Internal pointers returned by `tuya_get_device_id`,
`tuya_get_local_key`, and `tuya_get_ip` are exposed directly via JNA string
marshalling (no copy, no free).
