# C# / .NET Bindings for libseatuya

Pure C# binding using `[DllImport("libseatuya.so")]` for every function.
The `TuyaDevice` type derives from `SafeHandle` for automatic cleanup;
`MarshalString` manages the malloc'd C string → .NET string conversion.

## Prerequisites

- .NET 8.0 or later (or Mono with `-r:System`)
- libseatuya installed (`make install`)

## Build and run

```sh
dotnet run --project Seatuya.csproj
```

Or compile manually:
```sh
mcs -out:example.exe Seatuya.cs
mono example.exe
```

## Usage

```csharp
using var dev = SeatuyaApi.Create(deviceId, "192.168.1.100", key, "3.4");

Console.WriteLine(SeatuyaApi.TurnOn(dev, 1));
Console.WriteLine(SeatuyaApi.Status(dev));
Console.WriteLine(SeatuyaApi.TurnOff(dev, 1));
// SafeHandle disposes automatically at the end of the using block
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
All enums, constants, and functions are available through the `Seatuya`
namespace with .NET-idiomatic PascalCase naming.
