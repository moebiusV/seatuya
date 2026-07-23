# Kotlin/JVM JNA Bindings for libseatuya

Pure Kotlin binding using [JNA (Java Native Access)](https://github.com/java-native-access/jna).
A single `Seatuya` object with typed functions wrapping the C API.

## Prerequisites

- Kotlin 1.9+ / JDK 11+
- JNA: `implementation("net.java.dev.jna:jna:5.14.0")`
- libseatuya installed (`make install`)

## Build and run

```sh
kotlinc -cp jna-5.14.0.jar Seatuya.kt Example.kt -include-runtime -d example.jar
java -cp .:jna-5.14.0.jar:example.jar ExampleKt
```

## Usage

```kotlin
val dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4")
println(Seatuya.turnOn(dev, 1))
Seatuya.destroy(dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  The `Seatuya` object exposes
every C function as a Kotlin function with camelCase naming.
